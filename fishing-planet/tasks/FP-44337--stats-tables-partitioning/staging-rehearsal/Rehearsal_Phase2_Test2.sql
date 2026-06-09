/* ============================================================================
   FP-44337  Phase 2  |  *** REHEARSAL COPY for TEST2 (Enterprise 15.0.2000.5) ***
   Identical to artifacts/Phase2_PROD_Swap.sql EXCEPT two rehearsal deltas:
     - @DataPath -> the Test2 instance data dir (C:\...\MSSQL15.MSSQLSERVER2019\...).
     - Partition files SIZE/FILEGROWTH 8192MB -> 64MB (Test2 C: has ~78 GB free and
       the test data is tiny; do NOT carry these sizes back to prod).
   Run directly on the tester-made Test2 [Stats] (backed up; restore after the run).
   Everything else (logic, DDL, verification) is the prod script verbatim.
   ----------------------------------------------------------------------------
   Structural swap during the maintenance window (DOWNTIME). Metadata only:
   rename old + create the new partitioned StatsFact & MissionsFact (clustered PK
   only). The aligned NCI is built in Phase 3 AFTER the tail load (faster than
   maintaining it per-row during the bulk load).

   Window order: STOP PROD -> Phase 2 (this) -> Phase 3 (tail load + build NCI) ->
   START PROD. Bulk delta/drop/shrink are Phases 4-6 (online).

   Corrections vs the original DevOps draft:
     - Real prod path on Z: (not the C:\ template).
     - Small initial files (8 GB), autogrow into the space freed in Phase 6.
     - MissionsFact added.
     - THREE month filegroups seeded (June, July, August): the sliding window must
       always keep an EMPTY trailing partition so the monthly SPLIT never moves
       data. June = current; July = next; August = the empty trailing BUFFER.
       NOTE: P1 (< 2026-07-01) is the unbounded LEFT catch-all (it holds June + anything earlier);
       never SWITCH it out as if it were "just June" in steady-state.
   ============================================================================ */

USE [Stats];
GO

-- Real prod data directory (verify once against sys.master_files for this instance).
-- Used as the @DataPath literal in each batch below.

/* ============================================================================
   STATSFACT
   ============================================================================ */

-- Step 1 — rename existing StatsFact + its PK + Rank default. Idempotent: only if not already renamed.
IF OBJECT_ID('dbo.StatsFact') IS NOT NULL AND OBJECT_ID('dbo.StatsFact_old') IS NULL
BEGIN
    EXEC sp_rename 'dbo.StatsFact', 'StatsFact_old';
    EXEC sp_rename 'PK_StatsFact',  'PK_StatsFact_old', 'OBJECT';
    -- Rank DEFAULT: rename by its ACTUAL name (prod auto-names it; some envs use the
    -- canonical DF_StatsFact_Rank). Rename whatever it is so the new table's
    -- DF_StatsFact_Rank cannot collide.
    DECLARE @dfRank SYSNAME = (
        SELECT dc.name FROM sys.default_constraints dc
        JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id
        WHERE dc.parent_object_id = OBJECT_ID('dbo.StatsFact_old') AND c.name = 'Rank');
    IF @dfRank IS NOT NULL AND @dfRank <> 'DF_StatsFact_Rank_old'
        EXEC sp_rename @dfRank, 'DF_StatsFact_Rank_old', 'OBJECT';
END
GO

-- Step 2 — drop leftover partition objects (idempotent re-run). Drop the NEW table first so the
-- scheme can be dropped/recreated. SAFETY: refuse if it already holds live rows (downtime-only script).
IF OBJECT_ID('dbo.StatsFact', 'U') IS NOT NULL
BEGIN
    IF OBJECT_ID('dbo.StatsFact_old', 'U') IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.StatsFact WHERE EntityId > (SELECT MAX(EntityId) FROM dbo.StatsFact_old))
        THROW 50050, 'New dbo.StatsFact has live rows - do not re-run Phase 2 after START PROD. Aborted.', 1;
    DROP TABLE dbo.StatsFact;
END
IF EXISTS (SELECT 1 FROM sys.partition_schemes   WHERE name = 'ps_StatsFact_Timestamp')
    DROP PARTITION SCHEME ps_StatsFact_Timestamp;
IF EXISTS (SELECT 1 FROM sys.partition_functions WHERE name = 'pf_StatsFact_Timestamp')
    DROP PARTITION FUNCTION pf_StatsFact_Timestamp;
GO

-- Step 3 — filegroups + files: June (current), July (next), August (empty buffer).
-- SIZE 8 GB / GROWTH 8 GB is a starting point; before the window raise the CURRENT-month
-- (2026_06) file SIZE to the measured compressed June-tail size to avoid autogrow churn.
-- July/August stay small (they hold no rows until those months).
DECLARE @DataPath NVARCHAR(260) = N'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER2019\MSSQL\DATA\';
DECLARE @db SYSNAME = DB_NAME();
DECLARE @sql NVARCHAR(MAX);
DECLARE @m TABLE (suffix CHAR(7));
INSERT INTO @m VALUES ('2026_06'), ('2026_07'), ('2026_08');

DECLARE @s CHAR(7);
DECLARE fg CURSOR LOCAL FAST_FORWARD FOR SELECT suffix FROM @m;
OPEN fg; FETCH NEXT FROM fg INTO @s;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name = 'FG_StatsFact_' + @s)
    BEGIN
        EXEC (N'ALTER DATABASE [' + @db + N'] ADD FILEGROUP [FG_StatsFact_' + @s + N'];');
        SET @sql = N'ALTER DATABASE [' + @db + N'] ADD FILE (NAME=N''StatsFact_' + @s + N''','
                 + N'FILENAME=N''' + @DataPath + N'StatsFact_' + @s + N'.ndf'','
                 + N'SIZE=64MB, FILEGROWTH=64MB) TO FILEGROUP [FG_StatsFact_' + @s + N'];';
        EXEC sp_executesql @sql;
    END
    FETCH NEXT FROM fg INTO @s;
END
CLOSE fg; DEALLOCATE fg;
GO

-- Step 4 — partition function + scheme. Two boundaries -> three partitions:
--   P1 (< 2026-07-01) = June ; P2 [Jul,Aug) = July ; P3 (>= 2026-08-01) = EMPTY buffer.
CREATE PARTITION FUNCTION pf_StatsFact_Timestamp (DATETIME)
AS RANGE RIGHT FOR VALUES ('2026-07-01T00:00:00', '2026-08-01T00:00:00');
GO
CREATE PARTITION SCHEME ps_StatsFact_Timestamp
AS PARTITION pf_StatsFact_Timestamp
TO ([FG_StatsFact_2026_06], [FG_StatsFact_2026_07], [FG_StatsFact_2026_08]);
GO

-- Step 5 + 6 — IDENTITY start from old table, then create the new partitioned table
--              (clustered PK only; NCI is built in Phase 3 after the tail load).
DECLARE @startFrom BIGINT;
SELECT @startFrom = CASE WHEN MAX(EntityId) > CAST(IDENT_CURRENT('dbo.StatsFact_old') AS BIGINT)
                         THEN MAX(EntityId) ELSE CAST(IDENT_CURRENT('dbo.StatsFact_old') AS BIGINT) END + 1000000
FROM dbo.StatsFact_old WITH (NOLOCK);
PRINT 'StatsFact IDENTITY start = ' + CAST(@startFrom AS VARCHAR(20));

-- Build the new partitioned table by STRUCTURE-COPYING the old one (SELECT INTO reproduces
-- the exact column order/types/nullability/identity -> immune to per-platform schema drift:
-- EntityId is column 1 on PS/Steam/XB but column 58 on Mob/Nx & this Test2 box). Then add the
-- clustered PK on the scheme (PAGE), reseed identity, re-create the Rank DEFAULT.
SELECT * INTO dbo.StatsFact FROM dbo.StatsFact_old WHERE 1 = 0;
ALTER TABLE dbo.StatsFact ADD CONSTRAINT PK_StatsFact
    PRIMARY KEY CLUSTERED (EntityId, [Timestamp])
    WITH (DATA_COMPRESSION = PAGE)
    ON ps_StatsFact_Timestamp([Timestamp]);
DBCC CHECKIDENT('dbo.StatsFact', RESEED, @startFrom);
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints
               WHERE name = 'DF_StatsFact_Rank' AND parent_object_id = OBJECT_ID('dbo.StatsFact'))
    ALTER TABLE dbo.StatsFact ADD CONSTRAINT DF_StatsFact_Rank DEFAULT (0) FOR [Rank];
GO

/* ============================================================================
   MISSIONSFACT  (same design; Rank is NOT NULL with NO default — the app always
   supplies Rank (0 when empty), so this matches the original schema.)
   ============================================================================ */

-- Step 1 — rename existing MissionsFact + its PK. Idempotent: only if not already renamed.
IF OBJECT_ID('dbo.MissionsFact') IS NOT NULL AND OBJECT_ID('dbo.MissionsFact_old') IS NULL
BEGIN
    EXEC sp_rename 'dbo.MissionsFact', 'MissionsFact_old';
    EXEC sp_rename 'PK_MissionsFact',  'PK_MissionsFact_old', 'OBJECT';
END
GO

-- Step 2 — drop leftover partition objects (idempotent re-run). Drop the NEW table first so the
-- scheme can be dropped/recreated. SAFETY: refuse if it already holds live rows (downtime-only script).
IF OBJECT_ID('dbo.MissionsFact', 'U') IS NOT NULL
BEGIN
    IF OBJECT_ID('dbo.MissionsFact_old', 'U') IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.MissionsFact WHERE EntityId > (SELECT MAX(EntityId) FROM dbo.MissionsFact_old))
        THROW 50050, 'New dbo.MissionsFact has live rows - do not re-run Phase 2 after START PROD. Aborted.', 1;
    DROP TABLE dbo.MissionsFact;
END
IF EXISTS (SELECT 1 FROM sys.partition_schemes   WHERE name = 'ps_MissionsFact_Timestamp')
    DROP PARTITION SCHEME ps_MissionsFact_Timestamp;
IF EXISTS (SELECT 1 FROM sys.partition_functions WHERE name = 'pf_MissionsFact_Timestamp')
    DROP PARTITION FUNCTION pf_MissionsFact_Timestamp;
GO

-- Step 3 — filegroups + files: June, July, August (empty buffer).
DECLARE @DataPath NVARCHAR(260) = N'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER2019\MSSQL\DATA\';
DECLARE @db SYSNAME = DB_NAME();
DECLARE @sql NVARCHAR(MAX);
DECLARE @m TABLE (suffix CHAR(7));
INSERT INTO @m VALUES ('2026_06'), ('2026_07'), ('2026_08');

DECLARE @s CHAR(7);
DECLARE fg CURSOR LOCAL FAST_FORWARD FOR SELECT suffix FROM @m;
OPEN fg; FETCH NEXT FROM fg INTO @s;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name = 'FG_MissionsFact_' + @s)
    BEGIN
        EXEC (N'ALTER DATABASE [' + @db + N'] ADD FILEGROUP [FG_MissionsFact_' + @s + N'];');
        SET @sql = N'ALTER DATABASE [' + @db + N'] ADD FILE (NAME=N''MissionsFact_' + @s + N''','
                 + N'FILENAME=N''' + @DataPath + N'MissionsFact_' + @s + N'.ndf'','
                 + N'SIZE=64MB, FILEGROWTH=64MB) TO FILEGROUP [FG_MissionsFact_' + @s + N'];';
        EXEC sp_executesql @sql;
    END
    FETCH NEXT FROM fg INTO @s;
END
CLOSE fg; DEALLOCATE fg;
GO

-- Step 4 — partition function + scheme (June / July / August-buffer).
CREATE PARTITION FUNCTION pf_MissionsFact_Timestamp (DATETIME)
AS RANGE RIGHT FOR VALUES ('2026-07-01T00:00:00', '2026-08-01T00:00:00');
GO
CREATE PARTITION SCHEME ps_MissionsFact_Timestamp
AS PARTITION pf_MissionsFact_Timestamp
TO ([FG_MissionsFact_2026_06], [FG_MissionsFact_2026_07], [FG_MissionsFact_2026_08]);
GO

-- Step 5 + 6 — IDENTITY start + create new partitioned table (clustered PK only).
DECLARE @startFrom BIGINT;
SELECT @startFrom = CASE WHEN MAX(EntityId) > CAST(IDENT_CURRENT('dbo.MissionsFact_old') AS BIGINT)
                         THEN MAX(EntityId) ELSE CAST(IDENT_CURRENT('dbo.MissionsFact_old') AS BIGINT) END + 1000000
FROM dbo.MissionsFact_old WITH (NOLOCK);
PRINT 'MissionsFact IDENTITY start = ' + CAST(@startFrom AS VARCHAR(20));

-- Structure-copy from old, clustered PK on scheme, reseed. No Rank default on MissionsFact.
SELECT * INTO dbo.MissionsFact FROM dbo.MissionsFact_old WHERE 1 = 0;
ALTER TABLE dbo.MissionsFact ADD CONSTRAINT PK_MissionsFact
    PRIMARY KEY CLUSTERED (EntityId, [Timestamp])
    WITH (DATA_COMPRESSION = PAGE)
    ON ps_MissionsFact_Timestamp([Timestamp]);
DBCC CHECKIDENT('dbo.MissionsFact', RESEED, @startFrom);
GO

/* ============================================================================
   VERIFICATION (run before proceeding) — strict old-vs-new column compare:
   name, ordinal position, type+length, nullability, collation. Expect 0 rows.
   bcp (Phases 4/5) is positional, so ordinal drift must be caught here.
   ============================================================================ */
;WITH oldc AS (
    SELECT CASE OBJECT_NAME(c.object_id) WHEN 'StatsFact_old' THEN 'StatsFact'
                                         ELSE 'MissionsFact' END AS base,
           c.name, c.column_id, ty.name AS tn, c.max_length, c.precision, c.scale,
           c.is_nullable, ISNULL(c.collation_name, '') AS coll
    FROM sys.columns c JOIN sys.types ty ON ty.user_type_id = c.user_type_id
    WHERE c.object_id IN (OBJECT_ID('dbo.StatsFact_old'), OBJECT_ID('dbo.MissionsFact_old'))
), newc AS (
    SELECT OBJECT_NAME(c.object_id) AS base,
           c.name, c.column_id, ty.name AS tn, c.max_length, c.precision, c.scale,
           c.is_nullable, ISNULL(c.collation_name, '') AS coll
    FROM sys.columns c JOIN sys.types ty ON ty.user_type_id = c.user_type_id
    WHERE c.object_id IN (OBJECT_ID('dbo.StatsFact'), OBJECT_ID('dbo.MissionsFact'))
)
SELECT COALESCE(o.base, n.base) AS tbl, COALESCE(o.name, n.name) AS col,
       CASE WHEN o.name IS NULL THEN 'only in NEW'
            WHEN n.name IS NULL THEN 'only in OLD'
            WHEN o.column_id <> n.column_id THEN 'ordinal differs'
            ELSE 'type/length/null/collation differs' END AS status
FROM oldc o
FULL JOIN newc n ON n.base = o.base AND n.name = o.name
WHERE o.name IS NULL OR n.name IS NULL
   OR o.column_id <> n.column_id OR o.tn <> n.tn OR o.max_length <> n.max_length
   OR o.precision <> n.precision OR o.scale <> n.scale OR o.is_nullable <> n.is_nullable
   OR o.coll <> n.coll;
-- Expect 0 rows. Any row = a mismatch to resolve before the tail load / bcp.
GO

-- IDENTITY seeds + partition layout (expect 3 partitions each: 06/07/08 filegroups,
-- the 08 partition empty).
SELECT 'StatsFact' AS tbl, IDENT_CURRENT('dbo.StatsFact') AS curr
UNION ALL SELECT 'MissionsFact', IDENT_CURRENT('dbo.MissionsFact');

SELECT OBJECT_NAME(p.object_id) AS tbl, p.partition_number, p.rows, fg.name AS filegroup, prv.value AS upper_boundary
FROM sys.partitions p
JOIN sys.indexes i ON i.object_id = p.object_id AND i.index_id = p.index_id
JOIN sys.partition_schemes ps ON ps.data_space_id = i.data_space_id
JOIN sys.destination_data_spaces dds ON dds.partition_scheme_id = ps.data_space_id AND dds.destination_id = p.partition_number
JOIN sys.filegroups fg ON fg.data_space_id = dds.data_space_id
LEFT JOIN sys.partition_range_values prv ON prv.function_id = ps.function_id AND prv.boundary_id = p.partition_number
WHERE p.object_id IN (OBJECT_ID('dbo.StatsFact'), OBJECT_ID('dbo.MissionsFact')) AND i.index_id IN (0,1)
ORDER BY tbl, p.partition_number;
GO

-- >>> If verification is clean: proceed to Phase 3 (tail load + build NCI), then START PROD. <<<
