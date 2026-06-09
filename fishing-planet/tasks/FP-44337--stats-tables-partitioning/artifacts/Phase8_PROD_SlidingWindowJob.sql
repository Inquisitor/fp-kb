/* ============================================================================
   FP-44337  Phase 8  |  SERVER: PS PROD (MSSQL15.PSSTATS)
   Monthly sliding-window automation: pre-create next month's filegroup+file and
   SPLIT the partition function so the next month lands in its own file.

   One generic procedure handles any fact table following the naming convention
     pf_<T>_Timestamp / ps_<T>_Timestamp / FG_<T>_YYYY_MM / <T>_YYYY_MM.ndf.
   A single Agent job runs it for StatsFact and MissionsFact on the 28th, 23:00.

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
    @DataPath    NVARCHAR(260) = N'Z:\Microsoft SQL Server\MSSQL15.PSSTATS\MSSQL\DATA\',
    @InitSizeMB  INT           = 8192,
    @GrowthMB    INT           = 4096,
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

-- Dry run (prints what it would do; executes nothing).
EXEC dbo.usp_Fact_AddNextMonth @Table = 'StatsFact',    @Debug = 1;
EXEC dbo.usp_Fact_AddNextMonth @Table = 'MissionsFact', @Debug = 1;
GO

/* ----------------------------------------------------------------------------
   SQL Agent job — 28th of each month, 23:00. Two steps (one per table).
   Requires SQL Server Agent to be running on the instance.
   ---------------------------------------------------------------------------- */
USE msdb;
GO

IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = N'Facts_AddNextMonth')
    EXEC dbo.sp_delete_job @job_name = N'Facts_AddNextMonth';
GO

DECLARE @jobId UNIQUEIDENTIFIER;
EXEC dbo.sp_add_job
    @job_name           = N'Facts_AddNextMonth',
    @enabled            = 1,
    @description        = N'Maintain a 2-month empty partition buffer for StatsFact and MissionsFact',
    @owner_login_name   = N'sa',         -- sa is the ops account here; if sa is ever disabled, switch to a db_owner service account
    @notify_level_eventlog = 2,          -- write to Windows event log on failure (wire a mail operator too if available)
    @job_id             = @jobId OUTPUT;

EXEC dbo.sp_add_jobstep
    @job_id        = @jobId,
    @step_name     = N'StatsFact AddNextMonth',
    @subsystem     = N'TSQL',
    @command       = N'EXEC dbo.usp_Fact_AddNextMonth @Table = ''StatsFact'';',
    @database_name = N'Stats',
    @on_success_action = 3,            -- go to next step (MissionsFact)
    @on_fail_action    = 2,            -- quit WITH FAILURE so the safety THROW surfaces (eventlog alert);
                                       -- a skipped MissionsFact add is recovered next run by the catch-up loop.
                                       -- (For full independence, split into two per-table jobs.)
    @retry_attempts = 2, @retry_interval = 5;

EXEC dbo.sp_add_jobstep
    @job_id        = @jobId,
    @step_name     = N'MissionsFact AddNextMonth',
    @subsystem     = N'TSQL',
    @command       = N'EXEC dbo.usp_Fact_AddNextMonth @Table = ''MissionsFact'';',
    @database_name = N'Stats',
    @on_success_action = 1,            -- quit with success
    @retry_attempts = 2, @retry_interval = 5;

EXEC dbo.sp_add_schedule
    @schedule_name          = N'Monthly_28th_at_23',
    @freq_type              = 16,      -- monthly
    @freq_interval          = 28,      -- 28th
    @freq_recurrence_factor = 1,
    @active_start_time      = 230000;  -- 23:00:00

EXEC dbo.sp_attach_schedule @job_name = N'Facts_AddNextMonth', @schedule_name = N'Monthly_28th_at_23';
EXEC dbo.sp_add_jobserver   @job_name = N'Facts_AddNextMonth', @server_name = N'(LOCAL)';
GO
