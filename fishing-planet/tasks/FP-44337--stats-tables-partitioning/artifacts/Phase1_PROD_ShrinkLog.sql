/* ============================================================================
   FP-44337  Phase 1  |  SERVER: PS PROD (MSSQL15.PSSTATS)
   Immediate transaction-log shrink — ONLINE, no downtime. DO THIS FIRST.

   Why: the log file is ~322 GB on disk but only ~2.6 GB is used. Recovery model
   is SIMPLE, so this space is safe to return to the OS right now. Shrinking to
   ~32 GB (NOT smaller) frees ~290 GB to Z: (~62 -> ~352 GB) while leaving headroom
   for the single large transactions later in the window — the Phase 3 NCI build
   and the batched tail inserts. Over-shrinking the log forces a mid-window autogrow
   (log growth is always zero-initialized, not IFI-instant) and can stall the cutover.
   ============================================================================ */

USE [Stats];
GO

-- Pre-check: confirm SIMPLE recovery and nothing is pinning the log.
SELECT name,
       recovery_model_desc,
       log_reuse_wait_desc          -- expect NOTHING (or CHECKPOINT)
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

-- Hard stop if the log is pinned, so we don't waste the window on a no-op shrink.
DECLARE @wait NVARCHAR(60) = (SELECT log_reuse_wait_desc FROM sys.databases WHERE name = 'Stats');
IF @wait NOT IN ('NOTHING', 'CHECKPOINT')
    THROW 50001, 'Log not shrinkable now (log_reuse_wait_desc <> NOTHING/CHECKPOINT). Resolve the blocker, then retry.', 1;

-- Shrink the log to ~32 GB (leaves headroom for the Phase 3 NCI build / tail inserts).
DBCC SHRINKFILE (N'Stats_log', 32768);
GO

-- Verify free space on the volume jumped (~62 GB -> ~352 GB).
EXEC xp_fixeddrives;
GO

/* If the log did not shrink, re-check log_reuse_wait_desc above and resolve the
   blocker (e.g. an open transaction), then re-run the DBCC SHRINKFILE. */
