/* ============================================================================
   FP-44337  Phase 5  |  SERVER: SQLSTAGING (holds the restored backup copy)
   Import the Phase 4 delta into the restored copy, dedup'd by EntityId, so
   SQLSTAGING = restored backup + delta = complete to the cutover. This is the
   independent backstop and a **prerequisite for the Phase 6 drop** (A+B model).

   The Phase 4 export is a SUPERSET (safety margin), so we land it in a temp table
   and INSERT only EntityIds not already present — no duplicate-key failures, and
   no row near the boundary can be missed.

   Prereq: SQLSTAGING [Stats] holds the restored (non-partitioned) dbo.StatsFact /
   dbo.MissionsFact. They are the restored backup, hence schema-identical to prod
   *_old by construction (column-count insurance below).
   ============================================================================ */

USE [Stats];   -- restored database on SQLSTAGING
GO

-- 0) Schema insurance. Native bcp is POSITIONAL, so a column-order/type drift between prod *_old
--    and this restored copy would load silently wrong. Column count is the quick check below; for
--    rigor run the strict ordinal/type/collation compare (same query as Phase 2's verification)
--    between prod dbo.StatsFact_old/MissionsFact_old and these staging tables before bcp.
SELECT 'StatsFact' AS tbl, COUNT(*) AS col_count FROM sys.columns WHERE object_id = OBJECT_ID('dbo.StatsFact')
UNION ALL SELECT 'MissionsFact', COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID('dbo.MissionsFact');
GO

-- 1) Temp landing tables matching the live schema (no rows).
IF OBJECT_ID('dbo.StatsFact_DeltaTmp')    IS NOT NULL DROP TABLE dbo.StatsFact_DeltaTmp;
IF OBJECT_ID('dbo.MissionsFact_DeltaTmp') IS NOT NULL DROP TABLE dbo.MissionsFact_DeltaTmp;
SELECT * INTO dbo.StatsFact_DeltaTmp    FROM dbo.StatsFact    WHERE 1=0;
SELECT * INTO dbo.MissionsFact_DeltaTmp FROM dbo.MissionsFact WHERE 1=0;
GO

/* ----------------------------------------------------------------------------
   bcp import into the TEMP tables — run on SQLSTAGING. Native, positional.
   -E keeps the original EntityId values from the file (the temp tables inherit the
   IDENTITY property from SELECT INTO, so without -E bcp would reseed them).
   ----------------------------------------------------------------------------
   bcp Stats.dbo.StatsFact_DeltaTmp    in "E:\Temp\statsfact_delta.dat"    -S . -T -n -E -b 100000
   bcp Stats.dbo.MissionsFact_DeltaTmp in "E:\Temp\missionsfact_delta.dat" -S . -T -n -E -b 100000
   ---------------------------------------------------------------------------- */

-- 2) Insert only rows not already present (dedup the margin overlap), keeping ids.
DECLARE @t SYSNAME, @cols NVARCHAR(MAX), @sql NVARCHAR(MAX);
DECLARE cc CURSOR LOCAL FAST_FORWARD FOR SELECT name FROM (VALUES ('StatsFact'), ('MissionsFact')) v(name);
OPEN cc; FETCH NEXT FROM cc INTO @t;
WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @cols = STRING_AGG(QUOTENAME(name), ',') WITHIN GROUP (ORDER BY column_id)
    FROM sys.columns WHERE object_id = OBJECT_ID('dbo.' + @t);
    SET @sql =
        N'SET IDENTITY_INSERT dbo.' + QUOTENAME(@t) + N' ON;' +
        N'INSERT INTO dbo.' + QUOTENAME(@t) + N' (' + @cols + N') ' +
        N'SELECT ' + @cols + N' FROM dbo.' + QUOTENAME(@t + '_DeltaTmp') + N' t ' +
        N'WHERE NOT EXISTS (SELECT 1 FROM dbo.' + QUOTENAME(@t) + N' s WHERE s.EntityId = t.EntityId);' +
        N'SET @rc = @@ROWCOUNT;' +   -- capture the INSERT rowcount (NOT @@ROWCOUNT after the batch, which = the SET OFF)
        N'SET IDENTITY_INSERT dbo.' + QUOTENAME(@t) + N' OFF;';
    DECLARE @rc BIGINT;
    EXEC sp_executesql @sql, N'@rc BIGINT OUTPUT', @rc OUTPUT;
    PRINT @t + ': inserted ' + CAST(@rc AS VARCHAR(20)) + ' new rows.';
    FETCH NEXT FROM cc INTO @t;
END
CLOSE cc; DEALLOCATE cc;
GO

-- 3) Verify: staging MAX(EntityId) must now equal prod *_old MAX (Phase 4 prod_max_id),
--    i.e. the copy reaches the cutover.
SELECT 'StatsFact'    AS tbl, COUNT_BIG(*) AS total_rows, MAX(EntityId) AS max_id FROM dbo.StatsFact
UNION ALL
SELECT 'MissionsFact',        COUNT_BIG(*),               MAX(EntityId)           FROM dbo.MissionsFact;
GO

-- 4) MANDATORY value check — automated, not eyeballed. A CHECKSUM_AGG over the imported
--    delta id-range catches a positional/column mismatch that row counts cannot. Run this
--    on SQLSTAGING, then run the IDENTICAL query on prod dbo.StatsFact_old / MissionsFact_old
--    (same id range) and confirm rows AND chk match per table.
DECLARE @fromS BIGINT = /* delta start id_S from Phase 4 (stagingMax_S - margin) */ NULL;
DECLARE @fromM BIGINT = /* delta start id_M from Phase 4 (stagingMax_M - margin) */ NULL;
IF @fromS IS NULL OR @fromM IS NULL THROW 50021, 'Set @fromS/@fromM (Phase 4 export-after ids) before the checksum check.', 1;
-- BINARY_CHECKSUM(*) covers all columns but only hashes the FIRST 255 chars of [Message]
-- (nvarchar(MAX)) — it does NOT error on the LOB, it silently truncates. So msg_chk (a SHA2_256
-- content-hash aggregate) covers [Message] in FULL; it is required, not optional.
SELECT 'StatsFact' AS tbl, COUNT_BIG(*) AS rows, CHECKSUM_AGG(BINARY_CHECKSUM(*)) AS chk,
       CAST(NULL AS INT) AS msg_chk
FROM dbo.StatsFact WHERE EntityId > @fromS
UNION ALL
SELECT 'MissionsFact', COUNT_BIG(*), CHECKSUM_AGG(BINARY_CHECKSUM(*)),
       CHECKSUM_AGG(CHECKSUM(HASHBYTES('SHA2_256', ISNULL([Message], N''))))
FROM dbo.MissionsFact WHERE EntityId > @fromM;
-- rows, chk AND msg_chk must all match the same query on prod *_old. Mismatch = positional/column drift.

-- 5) Cleanup.
DROP TABLE dbo.StatsFact_DeltaTmp;
DROP TABLE dbo.MissionsFact_DeltaTmp;
GO

/* >>> staging max_id == prod *_old max_id (Phase 4) AND the spot-check matches for
       BOTH tables → SQLSTAGING copy complete. Required before the Phase 6 drop. <<< */
