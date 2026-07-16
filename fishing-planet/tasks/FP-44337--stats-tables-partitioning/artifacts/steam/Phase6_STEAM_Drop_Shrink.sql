/* ============================================================================
   FP-44337  Phase 6  |  SERVER: STEAM PROD (MSSQL15.STEAMSTATS)
   ONLINE (prod is running; new tables already hold the July tail from Phase 3).
     1. Drop the historical *_old tables (frees ~2.5 TB INSIDE the data file).
     2. SHRINKFILE to return that space to the OS (Steam Stats.mdf ~3238 GB -> ~1 TB expected).
     3. Index maintenance on the remaining tables (shrink fragments them).

   PRE-FLIGHT (Steam-specific, confirm before STEP 2/3):
     - Where is tempdb? On PS it shared Z: and we capped its MAXSIZE live so it could not grow
       into the shrink headroom. Check Steam: if tempdb data files are on Z:, pre-cap MAXSIZE and
       run STEP 3 rebuilds so their sort hits the data files, not tempdb (SORT_IN_TEMPDB defaults
       OFF for a bare REBUILD - keep it that way). If tempdb is on another volume, no action.
     - Comfortable headroom (307 GB free at cutover) - this is NOT the knife-edge PS was.

   >>> DROP GATE - lossless when BOTH hold (this is irreversible): <<<
       (a) the STEP 0 pre-drop FULL backup - taken AFTER STOP PROD, so it contains *_old IN FULL -
           is completed, proven RESTORABLE, and retained in >= 2 copies. HARD gate.
       (b) the Phase 3 preload is verified complete AND *_old is unchanged since Phase 3
           (both enforced programmatically in STEP 1).
   WHY the DROP is lossless: the STEP 0 pre-drop FULL captures *_old in its ENTIRETY (every row, every
   timestamp) in-window, so nothing is lost by the drop regardless of id/time skew. The July tail on
   prod is for CONTINUITY of incremental consumers, not preservation. EntityId is only COARSELY
   monotonic with Timestamp - FP-43469 measured this ON STEAM PROD (~21.6% row-level skew, 1-2 id
   interleave at date boundaries); the Phase 3 100k-id scan-floor margin absorbs it and it does not
   affect losslessness. There is NO SQLSTAGING-copy gate (the former Phase 4/5 delta was removed).
   AFTER the drop + shrink, take ANOTHER full backup as the new small baseline (it no longer contains
   *_old, so it does NOT replace the pre-drop backup for history).
   The analyst archive (Phase 7) does NOT have to exist yet - build it later from a backup.
   ============================================================================ */

USE [Stats];
GO

/* ----------------------------------------------------------------------------
   STEP 0 - PRE-DROP FULL BACKUP (HARD GATE). Run + verify BEFORE STEP 1.
   Online full backup of the whole DB while *_old still exists -> the irreversible DROP is
   safe even if an id/time-skew edge slipped past the tail load (*_old is captured in full
   here). ~3.2 TB: ensure backup-server space + a few hours; it runs online (no downtime).
   ----------------------------------------------------------------------------
   BACKUP DATABASE [Stats] TO DISK = N'<backup-server path>\Stats_STEAM_predrop_YYYYMMDD.bak'
       WITH COMPRESSION, CHECKSUM, STATS = 5;
   RESTORE VERIFYONLY FROM DISK = N'<...>\Stats_STEAM_predrop_YYYYMMDD.bak' WITH CHECKSUM;
   -- Confirm success + a >= 2nd retained copy, THEN proceed to STEP 1.
   ---------------------------------------------------------------------------- */

/* ----------------------------------------------------------------------------
   STEP 1 - Gate + irreversible DROP of the historical bulk (frees ~2.5 TB INSIDE the
   data file). The gate re-verifies (from FP44337_TailLoadControl, written by Phase 3)
   that every preloaded row is present in the new tables, and that *_old is unchanged
   since Phase 3; THROW and abort otherwise. The id range [TailStartId, MaxOldId] is the
   OLD-id space - live inserts have higher ids, so the counts stay comparable even though
   prod is live. Preservation is the STEP 0 pre-drop FULL, see the header.

   MANUAL gate (a) - confirm before running: STEP 0 pre-drop backup completed & verified
   (and retained in >= 2 copies).
   ---------------------------------------------------------------------------- */
SET XACT_ABORT ON;
BEGIN TRY
    IF OBJECT_ID('dbo.FP44337_TailLoadControl') IS NULL
        THROW 50010, 'FP44337_TailLoadControl missing - Phase 3 did not record the preload. DROP aborted.', 1;

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
        -- old-count carries the SAME Timestamp >= '2026-07-01' filter as Phase 3's load, so it
        -- matches the new table (which holds only July+ rows in this id range). Without it the
        -- late-June rows still in *_old would inflate @oldNow and the gate would falsely THROW.
        SET @sql = N'SELECT @c=COUNT_BIG(*) FROM dbo.' + QUOTENAME(@t + '_old') + N' WHERE EntityId BETWEEN @a AND @b AND [Timestamp] >= ''2026-07-01'';';
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

    -- Gate (b) cont.: *_old must be UNCHANGED since Phase 3 (no stray writer after STOP PROD).
    -- Compare the live *_old MAX(EntityId) to the value Phase 3 recorded in the control table.
    DECLARE @oldMaxS BIGINT = (SELECT MAX(EntityId) FROM dbo.StatsFact_old   );
    DECLARE @oldMaxM BIGINT = (SELECT MAX(EntityId) FROM dbo.MissionsFact_old);
    DECLARE @recMaxS BIGINT = (SELECT MaxOldId FROM dbo.FP44337_TailLoadControl WHERE TableName = 'StatsFact');
    DECLARE @recMaxM BIGINT = (SELECT MaxOldId FROM dbo.FP44337_TailLoadControl WHERE TableName = 'MissionsFact');
    IF @oldMaxS <> @recMaxS OR @oldMaxM <> @recMaxM
        THROW 50014, '*_old MAX(EntityId) changed since Phase 3 - a writer touched it after STOP. DROP aborted.', 1;

    -- Verified (b): every *_old row is preserved by the STEP 0 pre-drop FULL. Safe to drop.
    -- (Manual gate (a) - backup retained & restorable - must also be confirmed; see header.)
    DROP TABLE dbo.StatsFact_old;
    DROP TABLE dbo.MissionsFact_old;
    PRINT 'Verification passed (preload complete + *_old unchanged). Old tables dropped.';
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
   STEP 2 - Return space to the OS. ONLINE, but EXPECT HOURS, not minutes:
   SHRINKFILE relocates every interior page below the target one at a time,
   competing with live insert I/O - and on 2019 Standard the page moves take Sch-M locks that can
   BLOCK live inserts (WAIT_AT_LOW_PRIORITY is 2022+), so this is NOT transparent: run strictly
   OFF-PEAK as a stepped grind (~50 GB/step) so each DBCC is bounded, it's interruptible (shrink is
   restartable), live-writer stalls stay short, and you can watch free space climb between steps.

   TRUNCATEONLY first is near-instant but reclaims LITTLE here - the freed ~2.5 TB
   is interior/scattered pages, not a free tail; the stepped shrink does the real
   work. New fact data lives in the per-month FG files, NOT in PRIMARY, so PRIMARY
   now holds only the remaining smaller tables (Stmt/FishFact/ActionStats/Balance/...).
   Final target ~= actual used * 1.15.
   ---------------------------------------------------------------------------- */
DBCC SHRINKFILE (N'Stats', TRUNCATEONLY);
EXEC xp_fixeddrives;
GO

-- Stepped shrink: recompute used/target EACH step (live inserts into PRIMARY-resident
-- tables grow `used` during this multi-hour run, so a once-computed target would drift),
-- and WAITFOR between steps so live insert I/O isn't starved. You may also run each
-- DBCC SHRINKFILE manually instead of the loop.
DECLARE @stepMB BIGINT = 50000, @cmd NVARCHAR(200);   -- ~50 GB/step. Steam log is ~10 GB (SIMPLE) - it truncates
                                                       -- between steps; if it autogrows during a step, lower @stepMB.
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
            + ' (Stmt/FishFact/ActionStats/...) so the file tail is empty, then resume.';
        BREAK;
    END
    WAITFOR DELAY '00:00:30';   -- breathe between steps so live inserts aren't I/O-starved
END
PRINT 'Shrink complete.';
EXEC xp_fixeddrives;
GO

/* ----------------------------------------------------------------------------
   STEP 3 - Index maintenance on the remaining (non-partitioned) tables that
   SHRINKFILE fragmented. On Steam the big residents in PRIMARY are (from the size
   breakdown): Stmt ~224 GB, FishFact ~177 GB, ActionStats ~77 GB, Balance ~72 GB,
   TargetedAdFact ~45 GB, DisconnectStats ~19 GB, ... REBUILD is OFFLINE on Standard
   Edition, so run this in a maintenance DOWNTIME, table by table. If tempdb is on Z:,
   keep a bare REBUILD (SORT_IN_TEMPDB OFF by default) so the sort hits the data file.
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
-- ALTER INDEX ALL ON dbo.Stmt        REBUILD;
-- ALTER INDEX ALL ON dbo.FishFact    REBUILD;
-- ALTER INDEX ALL ON dbo.ActionStats REBUILD;
GO

-- Optional cleanup once the cutover is fully verified and complete:
-- DROP TABLE dbo.FP44337_TailLoadControl;
-- GO
