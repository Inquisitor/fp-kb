/* ============================================================================
   FP-44337  Phase 1  |  SERVER: STEAM PROD (MSSQL15.STEAMSTATS)
   Transaction-log RIGHT-SIZE - ONLINE, no downtime. Run DAYS BEFORE the window.

   Steam delta vs PS: on PS the log was ~322 GB with ~2.6 GB used - Phase 1 there
   was an emergency SHRINK (freed ~290 GB to the volume). On Steam Stats_log is only
   ~9.77 GB (assessment 2026-07-06) - there is nothing to reclaim. The risk is the
   OPPOSITE: the window's big log consumers (the Phase 3 NCI builds + batched tail
   inserts) could outgrow a ~10 GB log and force a MID-WINDOW autogrow - and log
   growth is always zero-initialized (IFI never applies to the log), which can
   stall the cutover.

   So this script CONVERGES Stats_log to the PS-validated ~32 GB from either side:
     - log < 32 GB (the expected Steam path) -> pre-GROW it now, online, before
       the window, where the zero-init costs nothing;
     - log ballooned since assessment        -> shrink it back to 32 GB
       (PS-style, guarded by log_reuse_wait_desc);
     - already ~32 GB                        -> no-op.
   Idempotent; safe to re-run. On the grow path Z: free DROPS by ~22 GB - budget for
   it: Z: is TIGHT (~91 GB free on 2026-08-10 -> ~69 GB after the grow).
   ============================================================================ */

USE [Stats];
GO

-- Pre-check: confirm SIMPLE recovery and nothing is pinning the log.
SELECT name,
       recovery_model_desc,          -- expect SIMPLE (the whole runbook relies on it)
       log_reuse_wait_desc           -- expect NOTHING (or CHECKPOINT)
FROM sys.databases
WHERE name = 'Stats';
GO

-- Current file sizes (data + log).
SELECT name AS logical_name,
       type_desc,
       CAST(size * 8.0 / 1024 / 1024 AS DECIMAL(18,1)) AS size_gb,
       CAST(FILEPROPERTY(name, 'SpaceUsed') * 8.0 / 1024 / 1024 AS DECIMAL(18,1)) AS used_gb
FROM sys.database_files;
GO

-- Right-size action: GROW / SHRINK / no-op depending on the live size.
DECLARE @targetMB  BIGINT = 32768;   -- PS-validated window headroom. Do NOT go smaller:
                                     -- over-shrinking forces a mid-window zero-init autogrow.
DECLARE @currentMB BIGINT = (SELECT CAST(size * 8.0 / 1024 AS BIGINT)
                             FROM sys.database_files WHERE name = N'Stats_log');
IF @currentMB IS NULL
    THROW 50002, 'Log file ''Stats_log'' not found in sys.database_files - check the logical name.', 1;

IF @currentMB < @targetMB
BEGIN
    -- Expected Steam path: pre-grow so the window never autogrows the log.
    -- The zero-init of the added ~22 GB happens NOW (online), not mid-window.
    PRINT 'Growing Stats_log ' + CAST(@currentMB AS VARCHAR(20)) + ' MB -> '
        + CAST(@targetMB AS VARCHAR(20)) + ' MB (zero-init runs now, online)...';
    ALTER DATABASE [Stats] MODIFY FILE (NAME = N'Stats_log', SIZE = 32768MB);
END
ELSE IF @currentMB > @targetMB + 8192   -- ballooned since assessment: shrink back, PS-style
BEGIN
    -- Hard stop if the log is pinned, so we don't waste time on a no-op shrink.
    DECLARE @wait NVARCHAR(60) = (SELECT log_reuse_wait_desc FROM sys.databases WHERE name = 'Stats');
    IF @wait NOT IN ('NOTHING', 'CHECKPOINT')
        THROW 50001, 'Log not shrinkable now (log_reuse_wait_desc <> NOTHING/CHECKPOINT). Resolve the blocker, then retry.', 1;
    PRINT 'Shrinking Stats_log ' + CAST(@currentMB AS VARCHAR(20)) + ' MB -> '
        + CAST(@targetMB AS VARCHAR(20)) + ' MB...';
    DBCC SHRINKFILE (N'Stats_log', 32768);
END
ELSE
    PRINT 'Stats_log already right-sized (' + CAST(@currentMB AS VARCHAR(20)) + ' MB) - nothing to do.';
GO

-- Verify: log at ~32 GB. NOTE: on the grow path Z: free DROPS by the grown amount
-- (~91 -> ~69 GB at 2026-08-10 levels) - that is the point (space claimed and zeroed up front).
SELECT name AS logical_name,
       CAST(size * 8.0 / 1024 / 1024 AS DECIMAL(18,1)) AS size_gb,
       CAST(FILEPROPERTY(name, 'SpaceUsed') * 8.0 / 1024 / 1024 AS DECIMAL(18,1)) AS used_gb
FROM sys.database_files WHERE type = 1;
EXEC xp_fixeddrives;
GO

/* If the SHRINK path did not shrink, re-check log_reuse_wait_desc above, resolve the
   blocker (e.g. an open transaction), then re-run this script (idempotent). */
