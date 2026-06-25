/* ============================================================================
   FP-44337  Phase 8  |  *** REHEARSAL COPY for TEST2 ***
   Rehearsal deltas vs prod: @DataPath = Test2 dir; init/growth 64 MB; and the SQL Agent
   JOB CREATION IS OMITTED (this only creates the proc + runs the @Debug=1 dry-runs, which
   PRINT what they would do and execute nothing). Do NOT create the Agent job on Test2.
   ----------------------------------------------------------------------------
   Monthly sliding-window automation: pre-create next month's filegroup+file and
   SPLIT the partition function so the next month lands in its own file.

   One generic procedure handles any fact table following the naming convention
     pf_<T>_Timestamp / ps_<T>_Timestamp / FG_<T>_YYYY_MM / <T>_YYYY_MM.ndf.
   A single Agent job runs it for StatsFact and MissionsFact on the 28th at 02:00 server-local (NY) = ~06:00 UTC daily online trough.

   Resilience: the proc maintains a buffer of @MonthsAhead empty future partitions
   (default 2) by adding as many months as needed in one run — so a MISSED monthly
   run is caught up next time without ever splitting a partition that already holds
   data (the split target is always a future, empty partition). With a 2-month
   buffer the window survives one skipped run. (NOTE: if the job is down long enough
   to fully deplete the buffer, the first catch-up split will hit the now-non-empty
   catch-all once — alert on job failure so this never happens silently.)

   (Archiving aged-out months — SWITCH OUT + export + drop file — is separate
   steady-state work.)
   ============================================================================ */

USE [Stats];
GO

CREATE OR ALTER PROCEDURE dbo.usp_Fact_AddNextMonth
    @Table       SYSNAME,
    @DataPath    NVARCHAR(260) = N'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER2019\MSSQL\DATA\',  -- REHEARSAL: Test2 path
    @InitSizeMB  INT           = 64,     -- REHEARSAL (prod 8192)
    @GrowthMB    INT           = 64,     -- REHEARSAL (prod 4096)
    @MonthsAhead INT           = 2,      -- keep at least this many empty future partitions
    @Debug       BIT           = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @pf SYSNAME = N'pf_' + @Table + N'_Timestamp';
    DECLARE @ps SYSNAME = N'ps_' + @Table + N'_Timestamp';
    DECLARE @db SYSNAME = DB_NAME();
    DECLARE @sql NVARCHAR(MAX);

    -- Target: a boundary at start-of-this-month + @MonthsAhead must exist.
    DECLARE @target DATETIME =
        DATEADD(MONTH, @MonthsAhead, DATEFROMPARTS(YEAR(SYSUTCDATETIME()), MONTH(SYSUTCDATETIME()), 1));
    DECLARE @maxBoundary DATETIME, @added INT = 0;

    WHILE 1 = 1
    BEGIN
        SELECT @maxBoundary = MAX(CAST(prv.value AS DATETIME))
        FROM sys.partition_range_values prv
        JOIN sys.partition_functions pf ON pf.function_id = prv.function_id
        WHERE pf.name = @pf;

        IF @maxBoundary IS NULL BEGIN PRINT 'Partition function ' + @pf + ' not found.'; RETURN; END
        IF @maxBoundary >= @target BREAK;                       -- buffer already satisfied

        DECLARE @nextMonth DATETIME = DATEADD(MONTH, 1, @maxBoundary);
        DECLARE @suffix NVARCHAR(7) = FORMAT(@nextMonth, 'yyyy_MM');
        DECLARE @fg SYSNAME = N'FG_' + @Table + N'_' + @suffix;
        DECLARE @fn SYSNAME = @Table + N'_' + @suffix;

        IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name = @fg)
        BEGIN
            SET @sql = N'ALTER DATABASE [' + @db + N'] ADD FILEGROUP [' + @fg + N'];';
            PRINT @sql; IF @Debug = 0 EXEC sp_executesql @sql;
            SET @sql = N'ALTER DATABASE [' + @db + N'] ADD FILE (NAME=N''' + @fn + N''','
                     + N'FILENAME=N''' + @DataPath + @fn + N'.ndf'','
                     + N'SIZE=' + CAST(@InitSizeMB AS NVARCHAR(10)) + N'MB,'
                     + N'FILEGROWTH=' + CAST(@GrowthMB AS NVARCHAR(10)) + N'MB) TO FILEGROUP [' + @fg + N'];';
            PRINT @sql; IF @Debug = 0 EXEC sp_executesql @sql;
        END

        SET @sql = N'ALTER PARTITION SCHEME ' + QUOTENAME(@ps) + N' NEXT USED [' + @fg + N'];';
        PRINT @sql; IF @Debug = 0 EXEC sp_executesql @sql;

        -- Safety: the SPLIT must hit an EMPTY partition (the future buffer). sys.partitions.rows
        -- is only an estimate, so check EXACTLY: any rows at/above the current max boundary (the
        -- open-ended rightmost partition)? Partition elimination makes this touch only that partition.
        DECLARE @rightHasRows BIT = 0;
        SET @sql = N'IF EXISTS (SELECT 1 FROM dbo.' + QUOTENAME(@Table) + N' WHERE [Timestamp] >= @mb) SET @x = 1;';
        EXEC sp_executesql @sql, N'@mb DATETIME, @x BIT OUTPUT', @maxBoundary, @rightHasRows OUTPUT;
        IF @Debug = 0 AND @rightHasRows = 1
            THROW 50030, 'Sliding-window buffer depleted: rightmost partition has rows; SPLIT would move data on a live table. Investigate and split off-peak.', 1;

        SET @sql = N'ALTER PARTITION FUNCTION ' + QUOTENAME(@pf) + N'() SPLIT RANGE ('''
                 + CONVERT(NVARCHAR(23), @nextMonth, 121) + N''');';
        PRINT @sql; IF @Debug = 0 EXEC sp_executesql @sql;
        PRINT '+++ ' + @Table + ': added ' + @suffix;

        SET @added += 1;
        IF @Debug = 1 BREAK;                                    -- dry-run: one pass only (nothing was committed)
        IF @added > 60 BEGIN RAISERROR('usp_Fact_AddNextMonth: added > 60 months — aborting (safety).', 16, 1); RETURN; END
    END
    PRINT @Table + ': buffer OK through ' + CONVERT(NVARCHAR(10), @target, 23) + ' (added ' + CAST(@added AS VARCHAR(10)) + ').';
END
GO

-- Dry runs (PRINT only; @Debug=1 executes nothing).
-- (1) Default @MonthsAhead=2: today is June -> target boundary = Aug 1, which already exists
--     (the Aug buffer) -> expect "buffer OK through 2026-08" (the no-op path).
EXEC dbo.usp_Fact_AddNextMonth @Table = 'StatsFact',    @Debug = 1;
EXEC dbo.usp_Fact_AddNextMonth @Table = 'MissionsFact', @Debug = 1;
GO
-- (2) @MonthsAhead=3: target = Sep 1 (> the current max boundary Aug 1) -> exercises the ADD path:
--     prints ADD FILEGROUP/FILE + ALTER PARTITION SCHEME NEXT USED + the emptiness check on the
--     rightmost (Aug) partition + SPLIT RANGE ('2026-09-01'). Still PRINT-only (nothing committed).
EXEC dbo.usp_Fact_AddNextMonth @Table = 'StatsFact', @MonthsAhead = 3, @Debug = 1;
GO

/* ----------------------------------------------------------------------------
   SQL Agent job creation is INTENTIONALLY OMITTED here — do NOT create a scheduled job on
   Test2. On PROD, run the Agent-job block from the canonical Phase8_PROD_SlidingWindowJob.sql
   (28th 02:00 NY-local / ~06:00 UTC, owner sa, event-log on failure).
   ---------------------------------------------------------------------------- */
