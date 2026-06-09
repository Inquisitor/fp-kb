/* ============================================================================
   FP-44337  Phase 6  |  SERVER: PS PROD (MSSQL15.PSSTATS)
   ONLINE (prod is running; new tables already hold the June tail from Phase 3).
     1. Drop the historical *_old tables (frees ~2.5 TB INSIDE the data file).
     2. SHRINKFILE to return that space to the OS.
     3. Index maintenance on the remaining tables (shrink fragments them).

   >>> DROP GATE — lossless when ALL hold (this is irreversible): <<<
       (a) the full backup is retained in >= 2 copies and proven RESTORABLE
           (backup file on the backup server + the restored copy on SQLSTAGING), AND
       (b) the Phase 3 preload is verified complete — every post-backup row is in
           the new tables (enforced programmatically below), AND
       (c) SQLSTAGING is complete to the cutover (backup + Phase 5 delta) — this is
           the copy that survives the drop, so it is the load-bearing safety gate.
   (a) is a manual confirmation; (b) AND (c) are enforced in the script — for (c) you
   paste the SQLSTAGING MAX(EntityId) per table and the script asserts it equals *_old.
   The optimized analyst archive (Phase 7) does NOT have to exist yet — build it
   later on SQLARCHIVE.
   ============================================================================ */

USE [Stats];
GO

/* ----------------------------------------------------------------------------
   STEP 1 — Drop the historical bulk. Frees ~2.5 TB INSIDE the data file.

   Programmatic gate: re-verify (from FP44337_TailLoadControl written by Phase 3)
   that every preloaded row is present in the new tables; THROW and abort if not,
   so the DROP cannot run on an incomplete preload. The id range [TailStartId,
   MaxOldId] is the OLD-id space — live inserts have higher ids, so the counts
   stay comparable even though prod is live.

   MANUAL gate (cannot be asserted in SQL — confirm before running):
     (a) full backup retained in >= 2 copies and proven restorable.
   Gate (c) is enforced below: paste the SQLSTAGING MAX(EntityId) per table (from
   Phase 5) into @stagingMax_S/@stagingMax_M; the script aborts unless they match *_old.
   ---------------------------------------------------------------------------- */

/* ----------------------------------------------------------------------------
   STEP 0 — Heavy, RESTARTABLE: record the full row count (and MAX) of *_old, so the
   irreversible Step 1 (gate + DROP) stays fast and a Step-1 retry never re-scans
   5.8B/2B rows. Multi-hour clustered scan — run off-peak, SEPARATELY from Step 1.
   ---------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.FP44337_DropGate') IS NULL
    CREATE TABLE dbo.FP44337_DropGate (
        TableName  SYSNAME   NOT NULL PRIMARY KEY,
        OldCount   BIGINT    NOT NULL,
        OldMax     BIGINT    NOT NULL,
        RecordedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
GO
;WITH src AS (SELECT 'StatsFact' AS t, COUNT_BIG(*) AS c, MAX(EntityId) AS m FROM dbo.StatsFact_old)
MERGE dbo.FP44337_DropGate d USING src s ON d.TableName = s.t
WHEN MATCHED THEN UPDATE SET OldCount = s.c, OldMax = s.m, RecordedAt = SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT (TableName, OldCount, OldMax) VALUES (s.t, s.c, s.m);
GO
;WITH src AS (SELECT 'MissionsFact' AS t, COUNT_BIG(*) AS c, MAX(EntityId) AS m FROM dbo.MissionsFact_old)
MERGE dbo.FP44337_DropGate d USING src s ON d.TableName = s.t
WHEN MATCHED THEN UPDATE SET OldCount = s.c, OldMax = s.m, RecordedAt = SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT (TableName, OldCount, OldMax) VALUES (s.t, s.c, s.m);
GO
SELECT * FROM dbo.FP44337_DropGate;
GO

/* ----------------------------------------------------------------------------
   STEP 1 — Gate + irreversible DROP. Fast: reuses STEP 0's recorded *_old counts.
   ---------------------------------------------------------------------------- */
SET XACT_ABORT ON;
BEGIN TRY
    IF OBJECT_ID('dbo.FP44337_TailLoadControl') IS NULL
        THROW 50010, 'FP44337_TailLoadControl missing - Phase 3 did not record the preload. DROP aborted.', 1;

    IF OBJECT_ID('dbo.FP44337_DropGate') IS NULL
        THROW 50018, 'FP44337_DropGate missing - run STEP 0 (record *_old counts) first. DROP aborted.', 1;

    IF (SELECT COUNT(*) FROM dbo.FP44337_TailLoadControl WHERE TableName IN ('StatsFact','MissionsFact')) < 2
        THROW 50011, 'Control set incomplete - expected StatsFact and MissionsFact. DROP aborted.', 1;

    DECLARE @t SYSNAME, @start BIGINT, @maxOld BIGINT, @recNew BIGINT, @oldNow BIGINT, @newNow BIGINT;
    DECLARE @bad INT = 0, @sql NVARCHAR(MAX);

    DECLARE v CURSOR LOCAL FAST_FORWARD FOR
        SELECT TableName, TailStartId, MaxOldId, NewCount FROM dbo.FP44337_TailLoadControl
        WHERE TableName IN ('StatsFact','MissionsFact');
    OPEN v; FETCH NEXT FROM v INTO @t, @start, @maxOld, @recNew;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = N'SELECT @c=COUNT_BIG(*) FROM dbo.' + QUOTENAME(@t + '_old') + N' WHERE EntityId BETWEEN @a AND @b;';
        EXEC sp_executesql @sql, N'@a BIGINT,@b BIGINT,@c BIGINT OUTPUT', @start, @maxOld, @oldNow OUTPUT;
        SET @sql = N'SELECT @c=COUNT_BIG(*) FROM dbo.' + QUOTENAME(@t) + N' WHERE EntityId BETWEEN @a AND @b;';
        EXEC sp_executesql @sql, N'@a BIGINT,@b BIGINT,@c BIGINT OUTPUT', @start, @maxOld, @newNow OUTPUT;

        IF @oldNow <> @newNow OR @newNow <> @recNew
        BEGIN
            SET @bad += 1;
            PRINT 'MISMATCH ' + @t + ': old_now=' + CAST(@oldNow AS VARCHAR(20))
                + ' new_now=' + CAST(@newNow AS VARCHAR(20)) + ' recorded_new=' + CAST(@recNew AS VARCHAR(20));
        END
        ELSE PRINT 'OK ' + @t + ': ' + CAST(@newNow AS VARCHAR(20)) + ' rows preserved in new table.';

        FETCH NEXT FROM v INTO @t, @start, @maxOld, @recNew;
    END
    CLOSE v; DEALLOCATE v;

    IF @bad > 0
        THROW 50012, 'Preload verification FAILED - at least one table mismatched. DROP aborted.', 1;

    /* Gate (c): SQLSTAGING completeness — the copy that survives the drop. Paste the
       MAX(EntityId) read on SQLSTAGING after Phase 5 (SELECT MAX(EntityId) FROM dbo.StatsFact /
       dbo.MissionsFact on SQLSTAGING). The script aborts unless staging reaches *_old's max. */
    DECLARE @stagingMax_S BIGINT = /* <MAX(EntityId) on SQLSTAGING.StatsFact> */ NULL;
    DECLARE @stagingMax_M BIGINT = /* <MAX(EntityId) on SQLSTAGING.MissionsFact> */ NULL;
    IF @stagingMax_S IS NULL OR @stagingMax_M IS NULL
        THROW 50013, 'SQLSTAGING MAX(EntityId) not provided (gate c). DROP aborted.', 1;

    DECLARE @oldMaxS BIGINT = (SELECT MAX(EntityId) FROM dbo.StatsFact_old   );
    DECLARE @oldMaxM BIGINT = (SELECT MAX(EntityId) FROM dbo.MissionsFact_old);
    DECLARE @recMaxS BIGINT = (SELECT MaxOldId FROM dbo.FP44337_TailLoadControl WHERE TableName = 'StatsFact');
    DECLARE @recMaxM BIGINT = (SELECT MaxOldId FROM dbo.FP44337_TailLoadControl WHERE TableName = 'MissionsFact');

    -- _old must be unchanged since Phase 3 (no stray writer touched it post-STOP).
    IF @oldMaxS <> @recMaxS OR @oldMaxM <> @recMaxM
        THROW 50014, '*_old MAX(EntityId) changed since Phase 3 - investigate before dropping. DROP aborted.', 1;
    -- SQLSTAGING must reach the cutover (its max == *_old max) for both tables.
    IF @stagingMax_S <> @oldMaxS OR @stagingMax_M <> @oldMaxM
        THROW 50015, 'SQLSTAGING is NOT complete to cutover (staging max <> *_old max). DROP aborted.', 1;

    /* Stronger than MAX: full row-count equality catches a missing row ANYWHERE (a middle hole),
       not just the top. *_old counts come from STEP 0 (recorded) so this batch stays fast. Paste
       COUNT_BIG(*) read on SQLSTAGING per table (after Phase 5). */
    DECLARE @stagingCnt_S BIGINT = /* <COUNT_BIG(*) on SQLSTAGING.StatsFact> */ NULL;
    DECLARE @stagingCnt_M BIGINT = /* <COUNT_BIG(*) on SQLSTAGING.MissionsFact> */ NULL;
    IF @stagingCnt_S IS NULL OR @stagingCnt_M IS NULL
        THROW 50016, 'SQLSTAGING COUNT not provided (gate c). DROP aborted.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.FP44337_DropGate WHERE TableName = 'StatsFact')
       OR NOT EXISTS (SELECT 1 FROM dbo.FP44337_DropGate WHERE TableName = 'MissionsFact')
        THROW 50018, 'STEP 0 *_old counts not recorded (dbo.FP44337_DropGate) - run STEP 0 first. DROP aborted.', 1;
    DECLARE @oldCntS BIGINT = (SELECT OldCount FROM dbo.FP44337_DropGate WHERE TableName = 'StatsFact');
    DECLARE @oldCntM BIGINT = (SELECT OldCount FROM dbo.FP44337_DropGate WHERE TableName = 'MissionsFact');
    DECLARE @gMaxS   BIGINT = (SELECT OldMax   FROM dbo.FP44337_DropGate WHERE TableName = 'StatsFact');
    DECLARE @gMaxM   BIGINT = (SELECT OldMax   FROM dbo.FP44337_DropGate WHERE TableName = 'MissionsFact');
    -- STEP 0's recorded MAX must still equal live *_old MAX (i.e. *_old unchanged since the count).
    IF @gMaxS <> @oldMaxS OR @gMaxM <> @oldMaxM
        THROW 50019, '*_old changed since STEP 0 count - re-run STEP 0. DROP aborted.', 1;
    IF @stagingCnt_S <> @oldCntS OR @stagingCnt_M <> @oldCntM
        THROW 50017, 'SQLSTAGING row count <> *_old row count - copy incomplete (a row is missing). DROP aborted.', 1;

    PRINT 'Gate (c) OK: SQLSTAGING matches *_old on MAX(EntityId) AND COUNT for both tables.';

    -- Verified (b)+(c): every row of *_old is preserved (new tables + SQLSTAGING). Safe to drop.
    DROP TABLE dbo.StatsFact_old;
    DROP TABLE dbo.MissionsFact_old;
    PRINT 'Verification passed. Old tables dropped.';
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','v') >= 0 BEGIN CLOSE v; DEALLOCATE v; END
    PRINT 'DROP ABORTED: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO

-- Free space now sitting inside the data file (expect ~2.5 TB free-in-file).
SELECT name AS logical_name,
       CAST(size * 8.0/1024/1024 AS DECIMAL(18,1)) AS size_gb,
       CAST(FILEPROPERTY(name,'SpaceUsed') * 8.0/1024/1024 AS DECIMAL(18,1)) AS used_gb,
       CAST((size - FILEPROPERTY(name,'SpaceUsed')) * 8.0/1024/1024 AS DECIMAL(18,1)) AS free_in_file_gb
FROM sys.database_files WHERE type = 0;
GO

/* ----------------------------------------------------------------------------
   STEP 2 — Return space to the OS. ONLINE, but EXPECT HOURS, not minutes:
   SHRINKFILE relocates every interior page below the target one at a time,
   competing with live insert I/O — and on 2019 Standard the page moves take Sch-M locks that can
   BLOCK live inserts (WAIT_AT_LOW_PRIORITY is 2022+), so this is NOT transparent: run strictly
   OFF-PEAK as a stepped grind (~50 GB/step) so each DBCC is bounded, it's interruptible (shrink is
   restartable), live-writer stalls stay short, and you can watch free space climb between steps.

   TRUNCATEONLY first is near-instant but reclaims LITTLE here — the freed ~2.5 TB
   is interior/scattered pages, not a free tail; the stepped shrink does the real
   work. New fact data lives in the per-month FG files, NOT in PRIMARY, so PRIMARY
   now holds only the remaining smaller tables (Stmt/FishFact/...). Final target
   ~= actual used * 1.15.
   ---------------------------------------------------------------------------- */
DBCC SHRINKFILE (N'Stats', TRUNCATEONLY);
EXEC xp_fixeddrives;
GO

-- Stepped shrink: recompute used/target EACH step (live inserts into PRIMARY-resident
-- tables grow `used` during this multi-hour run, so a once-computed target would drift),
-- and WAITFOR between steps so live insert I/O isn't starved. You may also run each
-- DBCC SHRINKFILE manually instead of the loop.
DECLARE @stepMB BIGINT = 50000, @cmd NVARCHAR(200);   -- ~50 GB/step: small enough not to outrun the 32 GB log; raise only if log stays calm
DECLARE @currentMB BIGINT, @usedMB BIGINT, @targetMB BIGINT, @next BIGINT;
WHILE 1 = 1
BEGIN
    SELECT @currentMB = CAST(size * 8.0 / 1024 AS BIGINT) FROM sys.database_files WHERE name = 'Stats';
    SET @usedMB   = (SELECT CAST(FILEPROPERTY('Stats','SpaceUsed') * 8.0 / 1024 AS BIGINT));
    SET @targetMB = CAST(@usedMB * 1.15 AS BIGINT);          -- ~15% over actual used, recomputed
    IF @currentMB <= @targetMB BREAK;

    SET @next = @currentMB - @stepMB;
    IF @next < @targetMB SET @next = @targetMB;
    SET @cmd = N'DBCC SHRINKFILE (N''Stats'', ' + CAST(@next AS NVARCHAR(20)) + N');';
    PRINT 'used=' + CAST(@usedMB AS VARCHAR(20)) + ' target=' + CAST(@targetMB AS VARCHAR(20)) + '  ' + @cmd;
    EXEC sp_executesql @cmd;
    EXEC xp_fixeddrives;
    -- No-progress guard: SHRINKFILE returns success even when it CANNOT reach the target (e.g.
    -- unmovable pages near the file end). Without this the loop would re-issue the same step
    -- forever (30s each). If the file didn't actually shrink, stop and surface it.
    DECLARE @afterMB BIGINT = (SELECT CAST(size * 8.0 / 1024 AS BIGINT) FROM sys.database_files WHERE name = 'Stats');
    IF @afterMB >= @currentMB - 1024   -- < ~1 GB progress this step
    BEGIN
        PRINT 'Shrink made no progress (likely unmovable pages high in the file). Stopping at '
            + CAST(@afterMB AS VARCHAR(20)) + ' MB. Investigate: rebuild/move the remaining PRIMARY tables'
            + ' (Stmt/FishFact/...) so the file tail is empty, then resume.';
        BREAK;
    END
    WAITFOR DELAY '00:00:30';   -- breathe between steps so live inserts aren't I/O-starved
END
PRINT 'Shrink complete.';
EXEC xp_fixeddrives;
GO

/* ----------------------------------------------------------------------------
   STEP 3 — Index maintenance on the remaining (non-partitioned) tables that
   SHRINKFILE fragmented: Stmt, FishFact, SilverStmt, Balance, ActionStats, etc.
   REBUILD is OFFLINE on Standard Edition, but these tables are far smaller than
   the facts we removed. Identify the worst offenders, then rebuild/reorganize.
   ---------------------------------------------------------------------------- */
SELECT OBJECT_NAME(ips.object_id) AS tbl, i.name AS index_name,
       ips.avg_fragmentation_in_percent AS frag_pct, ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
JOIN sys.indexes i ON i.object_id = ips.object_id AND i.index_id = ips.index_id
WHERE ips.page_count > 1000 AND ips.avg_fragmentation_in_percent > 30
  AND OBJECT_NAME(ips.object_id) NOT IN ('StatsFact','MissionsFact')
ORDER BY ips.page_count DESC;
GO
-- Example (run per identified index). A bare REBUILD PRESERVES existing compression;
-- do NOT add DATA_COMPRESSION unless you intend to change these tables' settings.
-- ALTER INDEX ALL ON dbo.Stmt     REBUILD;
-- ALTER INDEX ALL ON dbo.FishFact REBUILD;
GO

-- Optional cleanup once the cutover is fully verified and complete:
-- DROP TABLE dbo.FP44337_TailLoadControl;
-- GO
