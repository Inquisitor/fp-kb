/* ============================================================================
   FP-44337  Phase 7  |  SERVER: SQLARCHIVE (the ample archive box)  — DEFERRABLE
   Build the monthly-partitioned + PAGE-compressed history tables on SQLARCHIVE and
   load all history. This is the durable, analyst-facing home; build it later, when
   the SQLARCHIVE hardware (disks / box) is ready. Does NOT block prod.

   Assumptions:
     - A complete copy (restored backup + Phase 5 delta) is available to load from
       — e.g. the SQLSTAGING copy, or a fresh backup taken from it — as a database
       with non-partitioned dbo.StatsFact and dbo.MissionsFact.
     - Run this ON SQLARCHIVE, in that restored database.

   PARAMETERS:
     - @ArchiveDataPath : data directory for the archive filegroup file.
   Per-platform layout (decided): one DB/schema per platform; this builds the PS
   set. All partitions go to a single ARCHIVE_DATA filegroup (archive is not
   space-pressured and we never drop archive partitions).
   ============================================================================ */

USE [Stats];   -- <-- restored archive database (change if different)
GO

DECLARE @ArchiveDataPath NVARCHAR(260) = N'D:\StatsArchive\DATA\';   -- <-- set for SQLARCHIVE
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
   Build per table: rename restored -> *_import, generate monthly boundaries
   from the data, create partitioned+compressed table, load (keep EntityId),
   verify, drop *_import.
   ---------------------------------------------------------------------------- */
DECLARE @tables TABLE (name SYSNAME);
INSERT INTO @tables VALUES ('StatsFact'), ('MissionsFact');

DECLARE @t SYSNAME;
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT name FROM @tables;
OPEN cur; FETCH NEXT FROM cur INTO @t;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @imp SYSNAME = @t + '_import';
    DECLARE @pf  SYSNAME = N'pf_' + @t + N'_Timestamp';
    DECLARE @ps  SYSNAME = N'ps_' + @t + N'_Timestamp';
    DECLARE @sql NVARCHAR(MAX);

    -- 1) Rename the restored table out of the way.
    IF OBJECT_ID('dbo.' + @imp) IS NULL
        EXEC sp_rename @objname = @t, @newname = @imp;     -- dbo.StatsFact -> dbo.StatsFact_import

    -- 2) Monthly boundary list from the data: first month .. (max month + 1).
    DECLARE @minTs DATETIME, @maxTs DATETIME;
    SET @sql = N'SELECT @a=MIN([Timestamp]), @b=MAX([Timestamp]) FROM dbo.' + QUOTENAME(@imp) + N';';
    EXEC sp_executesql @sql, N'@a DATETIME OUTPUT,@b DATETIME OUTPUT', @minTs OUTPUT, @maxTs OUTPUT;

    DECLARE @cursor DATETIME = DATEFROMPARTS(YEAR(@minTs), MONTH(@minTs), 1);
    DECLARE @stop   DATETIME = DATEADD(MONTH, 2, DATEFROMPARTS(YEAR(@maxTs), MONTH(@maxTs), 1)); -- one buffer month past max
    DECLARE @vals NVARCHAR(MAX) = N'';
    WHILE @cursor < @stop
    BEGIN
        SET @vals += CASE WHEN @vals = N'' THEN N'' ELSE N',' END
                   + N'''' + CONVERT(NVARCHAR(23), @cursor, 121) + N'''';
        SET @cursor = DATEADD(MONTH, 1, @cursor);
    END

    -- 3) Partition function + scheme (all partitions on ARCHIVE_DATA).
    IF EXISTS (SELECT 1 FROM sys.partition_schemes   WHERE name = @ps)
    BEGIN SET @sql = N'DROP PARTITION SCHEME '   + QUOTENAME(@ps) + N';'; EXEC sp_executesql @sql; END
    IF EXISTS (SELECT 1 FROM sys.partition_functions WHERE name = @pf)
    BEGIN SET @sql = N'DROP PARTITION FUNCTION ' + QUOTENAME(@pf) + N';'; EXEC sp_executesql @sql; END
    SET @sql = N'CREATE PARTITION FUNCTION ' + QUOTENAME(@pf) + N' (DATETIME) AS RANGE RIGHT FOR VALUES (' + @vals + N');';
    EXEC sp_executesql @sql;
    SET @sql = N'CREATE PARTITION SCHEME '   + QUOTENAME(@ps) + N' AS PARTITION ' + QUOTENAME(@pf) + N' ALL TO ([ARCHIVE_DATA]);';
    EXEC sp_executesql @sql;

    -- 4) Build the new partitioned+compressed table by copying the import table's
    --    definition. SELECT INTO cannot target a partition scheme, so we create
    --    via a clustered index on the scheme over a structural copy.
    --    Simplest robust path: SELECT * INTO a heap, then build the clustered PK
    --    on the partition scheme. (Archive load is offline-friendly.)
    SET @sql = N'SELECT * INTO dbo.' + QUOTENAME(@t) + N' FROM dbo.' + QUOTENAME(@imp) + N' WHERE 1=0;';
    EXEC sp_executesql @sql;

    -- Re-establish IDENTITY is not needed on archive (history is static); EntityId
    -- is loaded as plain values. Load all rows (batched) preserving EntityId.
    DECLARE @cols NVARCHAR(MAX);
    SELECT @cols = STRING_AGG(QUOTENAME(name), ',') WITHIN GROUP (ORDER BY column_id)
    FROM sys.columns WHERE object_id = OBJECT_ID('dbo.' + @imp);

    DECLARE @lo BIGINT, @hi BIGINT;
    SET @sql = N'SELECT @x=MIN(EntityId),@y=MAX(EntityId) FROM dbo.' + QUOTENAME(@imp) + N';';
    EXEC sp_executesql @sql, N'@x BIGINT OUTPUT,@y BIGINT OUTPUT', @lo OUTPUT, @hi OUTPUT;

    DECLARE @batch BIGINT = 5000000, @from BIGINT = @lo, @to BIGINT;
    WHILE @from <= @hi
    BEGIN
        SET @to = @from + @batch - 1;
        -- SELECT * INTO preserved the IDENTITY property on EntityId, so IDENTITY_INSERT is required.
        SET @sql = N'SET IDENTITY_INSERT dbo.' + QUOTENAME(@t) + N' ON;'
                 + N'INSERT INTO dbo.' + QUOTENAME(@t) + N' (' + @cols + N') SELECT ' + @cols
                 + N' FROM dbo.' + QUOTENAME(@imp) + N' WHERE EntityId BETWEEN @f AND @tt;'
                 + N'SET IDENTITY_INSERT dbo.' + QUOTENAME(@t) + N' OFF;';
        EXEC sp_executesql @sql, N'@f BIGINT,@tt BIGINT', @from, @to;
        SET @from = @to + 1;
    END

    -- 5) Clustered PK on the partition scheme (this physically partitions the heap),
    --    PAGE compressed, then aligned NCI on (UserId, Timestamp).
    SET @sql = N'ALTER TABLE dbo.' + QUOTENAME(@t) + N' ADD CONSTRAINT ' + QUOTENAME(N'PK_' + @t)
        + N' PRIMARY KEY CLUSTERED (EntityId, [Timestamp]) WITH (DATA_COMPRESSION = PAGE) ON '
        + QUOTENAME(@ps) + N'([Timestamp]);';
    EXEC sp_executesql @sql;
    SET @sql = N'CREATE NONCLUSTERED INDEX ' + QUOTENAME(N'IX_' + @t + N'_UserId_Aligned')
        + N' ON dbo.' + QUOTENAME(@t) + N' (UserId, [Timestamp]) WITH (DATA_COMPRESSION = PAGE) ON '
        + QUOTENAME(@ps) + N'([Timestamp]);';
    EXEC sp_executesql @sql;

    -- 6) Verify row counts match, then drop the import copy.
    --    (Build the statement into @sql first — sp_executesql's first argument cannot be
    --     a string-concatenation expression.)
    DECLARE @cNew BIGINT, @cImp BIGINT;
    SET @sql = N'SELECT @c=COUNT_BIG(*) FROM dbo.' + QUOTENAME(@t) + N';';
    EXEC sp_executesql @sql, N'@c BIGINT OUTPUT', @cNew OUTPUT;
    SET @sql = N'SELECT @c=COUNT_BIG(*) FROM dbo.' + QUOTENAME(@imp) + N';';
    EXEC sp_executesql @sql, N'@c BIGINT OUTPUT', @cImp OUTPUT;
    PRINT @t + ': new=' + CAST(@cNew AS VARCHAR(20)) + ' import=' + CAST(@cImp AS VARCHAR(20));
    IF @cNew = @cImp BEGIN SET @sql = N'DROP TABLE dbo.' + QUOTENAME(@imp) + N';'; EXEC sp_executesql @sql; END
    ELSE PRINT '*** COUNT MISMATCH for ' + @t + ' — investigate before dropping ' + @imp;

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
