/* ============================================================================
   FP-44337  Phase 1  |  SERVER: XB PROD (MSSQL15.XBSTATS)
   Pre-window prep - ONLINE, no downtime. Run BEFORE the cutover window (same day is fine).

   XB deltas vs PS/Steam Phase 1 (assessment 2026-09-30):
     - Stats_log is 136.58 GB with 10% PERCENT growth -> this is the PS-style SHRINK path
       (136 -> 32 GB frees ~105 GB on C:) PLUS growth-config fixes: percent log growth means
       ~13+ GB zero-init per autogrow (log growth is never IFI) - switch to a fixed 1 GB step.
     - Stats.mdf growth was 1 MB (!) - micro-autogrow churn; switch to a fixed 2 GB step.
     - Instance-level prep bundled here: `backup checksum default` (was 0; PAGE_VERIFY is
       already CHECKSUM on XB so backups become page-verified), and the SQL Agent service
       startup type is MANUAL - set it to Automatic (Windows-side) or the Phase 8 job
       silently dies on the next server reboot:
         Set-Service 'SQLAgent$XBSTATS' -StartupType Automatic
   Idempotent; safe to re-run.
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

-- Current file sizes + growth config (data + log).
SELECT name AS logical_name, type_desc,
       CAST(size * 8.0 / 1024 / 1024 AS DECIMAL(18,1)) AS size_gb,
       CAST(FILEPROPERTY(name, 'SpaceUsed') * 8.0 / 1024 / 1024 AS DECIMAL(18,1)) AS used_gb,
       CASE WHEN is_percent_growth = 1 THEN CAST(growth AS VARCHAR(10)) + '%'
            ELSE CAST(CAST(growth*8.0/1024 AS DECIMAL(10,1)) AS VARCHAR(20)) + ' MB' END AS growth_step
FROM sys.database_files;
GO

-- Right-size action: SHRINK / GROW / no-op depending on the live size (converges to ~32 GB).
DECLARE @targetMB  BIGINT = 32768;   -- PS/Steam-validated window headroom for the Phase 3
                                     -- NCI builds + batched tail inserts. Do NOT go smaller.
DECLARE @currentMB BIGINT = (SELECT CAST(size * 8.0 / 1024 AS BIGINT)
                             FROM sys.database_files WHERE name = N'Stats_log');
IF @currentMB IS NULL
    THROW 50002, 'Log file ''Stats_log'' not found in sys.database_files - check the logical name.', 1;

IF @currentMB > @targetMB + 8192
BEGIN
    -- Expected XB path: shrink 136 -> 32 GB (frees ~105 GB on C:).
    DECLARE @wait NVARCHAR(60) = (SELECT log_reuse_wait_desc FROM sys.databases WHERE name = 'Stats');
    IF @wait NOT IN ('NOTHING', 'CHECKPOINT')
        THROW 50001, 'Log not shrinkable now (log_reuse_wait_desc <> NOTHING/CHECKPOINT). Resolve the blocker, then retry.', 1;
    PRINT 'Shrinking Stats_log ' + CAST(@currentMB AS VARCHAR(20)) + ' MB -> '
        + CAST(@targetMB AS VARCHAR(20)) + ' MB...';
    DBCC SHRINKFILE (N'Stats_log', 32768);
    -- If it stops short of the target (active VLF high in the file), re-run after a few
    -- checkpoints - the Steam first pass stuck at ~29 GB and the retry finished the job.
END
ELSE IF @currentMB < @targetMB
BEGIN
    PRINT 'Growing Stats_log ' + CAST(@currentMB AS VARCHAR(20)) + ' MB -> '
        + CAST(@targetMB AS VARCHAR(20)) + ' MB (zero-init runs now, online)...';
    ALTER DATABASE [Stats] MODIFY FILE (NAME = N'Stats_log', SIZE = 32768MB);
END
ELSE
    PRINT 'Stats_log already right-sized (' + CAST(@currentMB AS VARCHAR(20)) + ' MB) - nothing to do.';
GO

-- Growth-config fixes (idempotent; apply regardless of the branch above):
--   log: 10% percent growth -> fixed 1 GB (percent growth on a 136 GB log = 13+ GB zero-init per grow)
--   mdf: 1 MB micro-growth -> fixed 2 GB (Steam lesson: audit growth configs; XB mdf at least GROWS)
ALTER DATABASE [Stats] MODIFY FILE (NAME = N'Stats_log', FILEGROWTH = 1024MB);
ALTER DATABASE [Stats] MODIFY FILE (NAME = N'Stats',     FILEGROWTH = 2048MB);
GO

-- Instance-level: page-verified backups from the next run on (PAGE_VERIFY already CHECKSUM on XB).
EXEC sp_configure 'backup checksum default', 1;
RECONFIGURE;
GO

-- Verify: log ~32 GB, growth steps fixed-MB, checksum default in use.
SELECT name AS logical_name,
       CAST(size * 8.0 / 1024 / 1024 AS DECIMAL(18,1)) AS size_gb,
       CASE WHEN is_percent_growth = 1 THEN CAST(growth AS VARCHAR(10)) + '%'
            ELSE CAST(CAST(growth*8.0/1024 AS DECIMAL(10,1)) AS VARCHAR(20)) + ' MB' END AS growth_step
FROM sys.database_files;
SELECT name, value_in_use FROM sys.configurations WHERE name = N'backup checksum default';
EXEC xp_fixeddrives;
GO

/* Reminder (Windows-side, not T-SQL): Set-Service 'SQLAgent$XBSTATS' -StartupType Automatic */
