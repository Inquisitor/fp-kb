/* ============================================================================
   FP-44337  Phase 7  |  SERVER: STEAM ARCHIVE box  — DEFERRABLE
   Build the monthly-partitioned + PAGE-compressed history tables for Steam and load all
   dropped history. Durable, analyst-facing home; build it later, when the archive hardware
   is ready. Does NOT block prod.

   SOURCE (Steam-specific choice): restore the Phase 6 STEP 0 PRE-DROP FULL backup. It is
   guaranteed complete (taken in-window, HARD gate) and, being post-Phase-2, its FULL history
   lives in the *_old tables (dbo.StatsFact_old / dbo.MissionsFact_old). The restored DB also
   contains the prod-partitioned dbo.StatsFact/MissionsFact (July tail only) + prod's pf/ps -
   those are NOT the archive; this script drops them and builds the archive from *_old.
     (A pre-cutover weekly FULL could be used instead ONLY if taken AFTER 2026-07-01, so that
      < 2026-07-01 is complete in the original non-partitioned dbo.StatsFact; the pre-drop FULL
      avoids depending on weekly-backup timing.)

   SCOPE: load ONLY history < 2026-07-01 (the bulk dropped from prod in Phase 6). July and later
   stay on prod as live partitions and move to the archive LATER as they age out. A direct
   cross-server ALTER TABLE ... SWITCH PROD->archive is NOT possible (SWITCH is metadata-only
   within one DB/instance). The real later-flow is: on prod, SWITCH OUT the aged month into a local
   staging table (metadata-only), then transfer it here (backup/restore or bulk-load) and SWITCH it
   into the matching EMPTY archive partition. So the archive's monthly RANGE RIGHT boundaries must
   ALIGN with prod's calendar and keep EMPTY [Jul1,Aug1), [Aug1,Sep1), [Sep1,...) landing slots.
   (Finalize the exact boundary set when the archive is actually built - prod may have more live months by then.)

   PARAMETERS:
     - @ArchiveDataPath : data directory for the archive filegroup file.
   Per-platform layout (decided): one DB/schema per platform; this builds the STEAM set.
   All partitions go to a single ARCHIVE_DATA filegroup (archive is not space-pressured and
   we never drop archive partitions).
   ============================================================================ */

USE [Stats];   -- <-- restored archive database (change if different)
GO

DECLARE @ArchiveDataPath NVARCHAR(260) = N'D:\StatsArchive\Steam\DATA\';   -- <-- set for the Steam archive box
DECLARE @db SYSNAME = DB_NAME();

-- Single archive filegroup + file (sized generously; archive has space).
IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name = 'ARCHIVE_DATA')
BEGIN
    EXEC (N'ALTER DATABASE [' + @db + N'] ADD FILEGROUP [ARCHIVE_DATA];');
    DECLARE @f NVARCHAR(MAX) = N'ALTER DATABASE [' + @db + N'] ADD FILE (NAME=N''ArchiveData_1'','
        + N'FILENAME=N''' + @ArchiveDataPath + N'ArchiveData_1.ndf'','
        + N'SIZE=51200MB, FILEGROWTH=20480MB) TO FILEGROUP [ARCHIVE_DATA];';
    EXEC sp_executesql @f;
END
GO

/* ----------------------------------------------------------------------------
   Build per table: drop the restored prod-partitioned table + its pf/ps (July tail, not
   the archive), source history from *_old, generate monthly boundaries from the data,
   create partitioned+compressed archive table, load < 2026-07-01 (keep EntityId), verify,
   drop *_old.
   ---------------------------------------------------------------------------- */
DECLARE @tables TABLE (name SYSNAME);
INSERT INTO @tables VALUES ('StatsFact'), ('MissionsFact');

DECLARE @t SYSNAME;
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT name FROM @tables;
OPEN cur; FETCH NEXT FROM cur INTO @t;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @imp SYSNAME = @t + '_old';                 -- SOURCE = full history from the pre-drop backup
    DECLARE @pf  SYSNAME = N'pf_' + @t + N'_Timestamp';
    DECLARE @ps  SYSNAME = N'ps_' + @t + N'_Timestamp';
    DECLARE @sql NVARCHAR(MAX);

    -- 0) Remove the restored prod-partitioned table (July tail) so we can rebuild dbo.<t> as the
    --    archive. Its pf/ps are prod's and are dropped next (recreated with archive boundaries).
    IF OBJECT_ID('dbo.' + @t, 'U') IS NOT NULL
    BEGIN SET @sql = N'DROP TABLE dbo.' + QUOTENAME(@t) + N';'; EXEC sp_executesql @sql; END

    -- 2) Monthly boundary list from the data: first month .. (aligned with prod calendar).
    DECLARE @minTs DATETIME, @maxTs DATETIME;
    SET @sql = N'SELECT @a=MIN([Timestamp]), @b=MAX([Timestamp]) FROM dbo.' + QUOTENAME(@imp) + N' WHERE [Timestamp] < ''2026-07-01'';';
    EXEC sp_executesql @sql, N'@a DATETIME OUTPUT,@b DATETIME OUTPUT', @minTs OUTPUT, @maxTs OUTPUT;

    -- Boundaries from the first data month through 2026-09-01 (aligned with prod's calendar), so the
    -- last LOADED partition is June 2026 and [Jul1,Aug1), [Aug1,Sep1), [Sep1,...) stay EMPTY - the
    -- landing slots that prod's aged July+ months are transferred into later.
    DECLARE @cursor DATETIME = DATEFROMPARTS(YEAR(@minTs), MONTH(@minTs), 1);
    DECLARE @stop   DATETIME = '2026-10-01';   -- loop adds boundaries while < @stop -> last = 2026-09-01 (Jul1/Aug1/Sep1 included)
    DECLARE @vals NVARCHAR(MAX) = N'';
    WHILE @cursor < @stop
    BEGIN
        SET @vals += CASE WHEN @vals = N'' THEN N'' ELSE N',' END
                   + N'''' + CONVERT(NVARCHAR(23), @cursor, 121) + N'''';
        SET @cursor = DATEADD(MONTH, 1, @cursor);
    END

    -- 3) Partition function + scheme (all partitions on ARCHIVE_DATA). Drops the restored prod
    --    pf/ps first (same names) now that the table using them is gone.
    IF EXISTS (SELECT 1 FROM sys.partition_schemes   WHERE name = @ps)
    BEGIN SET @sql = N'DROP PARTITION SCHEME '   + QUOTENAME(@ps) + N';'; EXEC sp_executesql @sql; END
    IF EXISTS (SELECT 1 FROM sys.partition_functions WHERE name = @pf)
    BEGIN SET @sql = N'DROP PARTITION FUNCTION ' + QUOTENAME(@pf) + N';'; EXEC sp_executesql @sql; END
    SET @sql = N'CREATE PARTITION FUNCTION ' + QUOTENAME(@pf) + N' (DATETIME) AS RANGE RIGHT FOR VALUES (' + @vals + N');';
    EXEC sp_executesql @sql;
    SET @sql = N'CREATE PARTITION SCHEME '   + QUOTENAME(@ps) + N' AS PARTITION ' + QUOTENAME(@pf) + N' ALL TO ([ARCHIVE_DATA]);';
    EXEC sp_executesql @sql;

    -- 4) Build the new partitioned+compressed table by copying the source (*_old) definition.
    --    SELECT INTO a heap, then build the clustered PK on the scheme. (Archive load is offline-friendly.)
    SET @sql = N'SELECT * INTO dbo.' + QUOTENAME(@t) + N' FROM dbo.' + QUOTENAME(@imp) + N' WHERE 1=0;';
    EXEC sp_executesql @sql;

    -- EntityId is loaded as plain values (history is static; no reseed needed). Load all rows (batched)
    -- preserving EntityId. SELECT INTO preserved the IDENTITY property, so IDENTITY_INSERT is required.
    DECLARE @cols NVARCHAR(MAX);
    SELECT @cols = STRING_AGG(QUOTENAME(name), ',') WITHIN GROUP (ORDER BY column_id)
    FROM sys.columns WHERE object_id = OBJECT_ID('dbo.' + @imp);

    DECLARE @lo BIGINT, @hi BIGINT;
    -- Bound the id range to the ARCHIVED scope (< 2026-07-01) so the batch loop doesn't iterate
    -- the whole post-June id space with empty-result batches (pointless I/O on a multi-TB source).
    SET @sql = N'SELECT @x=MIN(EntityId),@y=MAX(EntityId) FROM dbo.' + QUOTENAME(@imp) + N' WHERE [Timestamp] < ''2026-07-01'';';
    EXEC sp_executesql @sql, N'@x BIGINT OUTPUT,@y BIGINT OUTPUT', @lo OUTPUT, @hi OUTPUT;

    DECLARE @batch BIGINT = 5000000, @from BIGINT = @lo, @to BIGINT;
    WHILE @from <= @hi
    BEGIN
        SET @to = @from + @batch - 1;
        SET @sql = N'SET IDENTITY_INSERT dbo.' + QUOTENAME(@t) + N' ON;'
                 + N'INSERT INTO dbo.' + QUOTENAME(@t) + N' (' + @cols + N') SELECT ' + @cols
                 + N' FROM dbo.' + QUOTENAME(@imp) + N' WHERE EntityId BETWEEN @f AND @tt'
                 + N'   AND [Timestamp] < ''2026-07-01'';'   -- archive only the dropped history; July+ via SWITCH later
                 + N'SET IDENTITY_INSERT dbo.' + QUOTENAME(@t) + N' OFF;';
        EXEC sp_executesql @sql, N'@f BIGINT,@tt BIGINT', @from, @to;
        SET @from = @to + 1;
    END

    -- 5) Clustered PK on the partition scheme (physically partitions the heap), PAGE compressed,
    --    then aligned NCI on (UserId, Timestamp).
    SET @sql = N'ALTER TABLE dbo.' + QUOTENAME(@t) + N' ADD CONSTRAINT ' + QUOTENAME(N'PK_' + @t)
        + N' PRIMARY KEY CLUSTERED (EntityId, [Timestamp]) WITH (DATA_COMPRESSION = PAGE) ON '
        + QUOTENAME(@ps) + N'([Timestamp]);';
    EXEC sp_executesql @sql;
    SET @sql = N'CREATE NONCLUSTERED INDEX ' + QUOTENAME(N'IX_' + @t + N'_UserId_Aligned')
        + N' ON dbo.' + QUOTENAME(@t) + N' (UserId, [Timestamp]) WITH (DATA_COMPRESSION = PAGE) ON '
        + QUOTENAME(@ps) + N'([Timestamp]);';
    EXEC sp_executesql @sql;

    -- 6) Verify row counts match (same < 2026-07-01 scope), then drop the source *_old.
    DECLARE @cNew BIGINT, @cImp BIGINT;
    SET @sql = N'SELECT @c=COUNT_BIG(*) FROM dbo.' + QUOTENAME(@t) + N';';
    EXEC sp_executesql @sql, N'@c BIGINT OUTPUT', @cNew OUTPUT;
    SET @sql = N'SELECT @c=COUNT_BIG(*) FROM dbo.' + QUOTENAME(@imp) + N' WHERE [Timestamp] < ''2026-07-01'';';
    EXEC sp_executesql @sql, N'@c BIGINT OUTPUT', @cImp OUTPUT;
    PRINT @t + ': archived(<Jul1)=' + CAST(@cNew AS VARCHAR(20)) + ' source(<Jul1)=' + CAST(@cImp AS VARCHAR(20));
    IF @cNew = @cImp BEGIN SET @sql = N'DROP TABLE dbo.' + QUOTENAME(@imp) + N';'; EXEC sp_executesql @sql; END
    ELSE PRINT '*** COUNT MISMATCH for ' + @t + ' (< 2026-07-01) - investigate before dropping ' + @imp;

    FETCH NEXT FROM cur INTO @t;
END
CLOSE cur; DEALLOCATE cur;
GO

-- Partition layout sanity (rows per month).
SELECT OBJECT_NAME(p.object_id) AS tbl, p.partition_number, p.rows, prv.value AS upper_boundary
FROM sys.partitions p
JOIN sys.indexes i ON i.object_id = p.object_id AND i.index_id = p.index_id AND i.index_id IN (0,1)
JOIN sys.partition_schemes ps ON ps.data_space_id = i.data_space_id
LEFT JOIN sys.partition_range_values prv ON prv.function_id = ps.function_id AND prv.boundary_id = p.partition_number
WHERE p.object_id IN (OBJECT_ID('dbo.StatsFact'), OBJECT_ID('dbo.MissionsFact'))
ORDER BY tbl, p.partition_number;
GO
