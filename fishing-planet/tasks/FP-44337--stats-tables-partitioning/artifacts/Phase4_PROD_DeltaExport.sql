/* ============================================================================
   FP-44337  Phase 4  |  SERVER: PS PROD (MSSQL15.PSSTATS)
   ONLINE (prod already restarted). Export the post-backup delta from the renamed
   *_old tables so the SQLSTAGING copy can be completed to the cutover.

   Boundary by EntityId, NOT Timestamp. The delta = rows whose EntityId is greater
   than what the restored SQLSTAGING copy already holds, **minus a safety margin**
   to cover any transaction that was in-flight at backup time (an early-assigned
   IDENTITY that committed after the backup LSN, so its id can be below the backup's
   max). The margin makes the export a strict SUPERSET; Phase 5 dedups on import
   (`INSERT ... WHERE NOT EXISTS`), so the overlap is harmless and nothing near the
   boundary can be lost. This avoids the Timestamp-vs-EntityId edge entirely.

   STEP A — on SQLSTAGING, read the high-water mark already in the restored copy:
       SELECT MAX(EntityId) FROM dbo.StatsFact;     -- -> @stagingMax_S
       SELECT MAX(EntityId) FROM dbo.MissionsFact;  -- -> @stagingMax_M
   Plug those values in below.
   IMPORTANT: capture these ONCE, BEFORE Phase 5 imports (Phase 5 raises staging MAX). On any RE-RUN,
   reuse the SAME recorded values — do NOT re-read staging, or the floor jumps forward and skips the
   rows imported by the partial run. (If in doubt, re-restore the backup on SQLSTAGING and redo 4+5.)
   ============================================================================ */

USE [Stats];
GO

DECLARE @stagingMax_S BIGINT = /* <MAX(EntityId) on SQLSTAGING.StatsFact> */ NULL;
DECLARE @stagingMax_M BIGINT = /* <MAX(EntityId) on SQLSTAGING.MissionsFact> */ NULL;
DECLARE @margin BIGINT = 10000000;  -- generous safety overlap (dedup'd on import in Phase 5).
-- The overlap only affects whether Phase 5 needs a re-export; CORRECTNESS is guaranteed by the
-- Phase 6 gate's full COUNT(*) equality (staging is a subset of *_old by construction, so equal
-- counts <=> complete). If the gate ever fails, lower this floor and re-run Phase 4/5.

-- Guard: a forgotten value would otherwise export the WHOLE table (EntityId > -margin).
IF @stagingMax_S IS NULL OR @stagingMax_M IS NULL
    THROW 50020, 'Set @stagingMax_S/@stagingMax_M from SQLSTAGING (STEP A) before running Phase 4.', 1;

SELECT 'StatsFact' AS tbl,
       @stagingMax_S - @margin AS export_after_id,
       (SELECT COUNT_BIG(*)  FROM dbo.StatsFact_old    WITH (NOLOCK) WHERE EntityId > @stagingMax_S - @margin) AS export_rows,
       (SELECT MAX(EntityId) FROM dbo.StatsFact_old    WITH (NOLOCK)) AS prod_max_id
UNION ALL
SELECT 'MissionsFact',
       @stagingMax_M - @margin,
       (SELECT COUNT_BIG(*)  FROM dbo.MissionsFact_old WITH (NOLOCK) WHERE EntityId > @stagingMax_M - @margin),
       (SELECT MAX(EntityId) FROM dbo.MissionsFact_old WITH (NOLOCK));
GO

/* ----------------------------------------------------------------------------
   bcp export — run on the PROD box. Substitute (stagingMax - margin) per table.
   Record export_rows and prod_max_id (above) for the Phase 5 verification.
   ----------------------------------------------------------------------------
   bcp "SELECT * FROM Stats.dbo.StatsFact_old    WITH (NOLOCK) WHERE EntityId > <id_S> ORDER BY EntityId" ^
       queryout "E:\Temp\statsfact_delta.dat"    -S . -T -n
   bcp "SELECT * FROM Stats.dbo.MissionsFact_old WITH (NOLOCK) WHERE EntityId > <id_M> ORDER BY EntityId" ^
       queryout "E:\Temp\missionsfact_delta.dat" -S . -T -n

   Then copy both .dat files to SQLSTAGING and run Phase 5 there.
   (Temp path on a volume with free space, NOT the full Z:.)
   ---------------------------------------------------------------------------- */
