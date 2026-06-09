# Backlog — FP-44337 Stats tables partitioning

## Pre-flight (before PS window)
- [ ] Measure current-month (June) tail row counts (StatsFact, MissionsFact) — sizes the Phase 3 load
- [ ] Measure delta row count since backup point (~2026-06-08 00:45)
- [ ] Confirm Instant File Initialization enabled for the SQL service account
- [ ] Confirm `log_reuse_wait_desc = NOTHING` so the Phase 1 log shrink is immediate
- [ ] Confirm exact prod data path and free space on `Z:` at window time
- [ ] Confirm >= 2 preserved copies: backup file on backup server + restored copy on SQLSTAGING
- [ ] Measure per-row insert rate on staging (PAGE-compressed inserts + NCI build may exceed the ~40 min window — bump if so)
- [ ] Prove the backup: `RESTORE VERIFYONLY` + `DBCC CHECKDB` on the SQLSTAGING copy
- [ ] Confirm SQL Agent service running on PSSTATS; set Phase 8 job owner to a service account (not `sa`)
- [ ] SQLARCHIVE: provision disks / box for the Phase 7 archive build (deferrable)

## Confirmed with team (2026-06-08)
- STOP PROD fences ALL writers (global write-fence) — no late rows into `*_old` after the snapshot.
- `MissionsFact.Rank` is NOT NULL with no default; the app always supplies Rank (0 when empty).
- `FishingRateStatUpdateJob` cursor = `WHERE EntityId > @stored` range-scan; survives cutover and re-reads the preloaded tail.
- Safety model **A+B**: `@tailFrom` fixed at 2026-06-01 (never narrowed); Phase 5 delta on SQLSTAGING is a **drop prerequisite**.
- Permissions: app login connects as a **role member (db_owner / db_datawriter)**, so the new `StatsFact`/`MissionsFact` inherit access automatically after `sp_rename` — no object-level GRANT to carry over. (Cheap pre-flight: confirm `sys.database_permissions` has no object-level grants on the old tables.)

## Open questions for team (from DBA review)
- [ ] Is `Timestamp` server-assigned (`GETDATE()` at insert) or ever client-set/back-dated? (bounds the out-of-order tail edge)
- [ ] Is there a linked server / cross-instance path PROD -> SQLSTAGING? (would let the Phase 6 gate (c) auto-query staging instead of operator-paste)
- [ ] Any other writer to `*_old` after STOP PROD — replication / CDC / ETL / triggers? (gate asserts `*_old` unchanged, but confirm)
- [ ] `E:\Temp` (or chosen path) capacity on PROD and SQLSTAGING for the delta `.dat` files
- [ ] Is `Stats_log` physically on `Z:`? (Phase 1's ~290 GB reclaim and the Z: headroom math depend on it)
- [ ] Measure the real max IDENTITY-assignment gap under load (sizes the Phase 3/4 margins; gate (c) COUNT is the hard backstop regardless)
- [ ] Commit to running Phase 6 (DROP + start shrink) the SAME maintenance day — not deferred (Z: exhaustion risk)
- [ ] Rehearse the full Phase 2->3 sequence on staging INCLUDING a forced mid-load failure + idempotent re-run
- [ ] Is `tempdb` on `Z:`? (the Phase 3 NCI build sort + Phase 6 shrink would then contend for the same near-full volume)
- [ ] Confirm prod and SQLSTAGING are the SAME SQL Server major version (native `bcp -n` format is version-sensitive)
- [ ] Confirm no job/proc references these tables by a hardcoded 3-part / `*_old`-style name that survives the rename (gate (b) assumes `*_old` is untouched after STOP)
- [ ] Confirm whether `MissionsFact.[Message]` ever exceeds 255 chars (drives whether the Phase 5 SHA2_256 `msg_chk` is load-bearing)
- [ ] Confirm `DATA_COMPRESSION=PAGE` on a partitioned table works on build 15.0.2000.5 (cheap throwaway test) + measure compressed month size

## Execution (PS)
- [ ] Phase 1: shrink `Stats_log` (~+314 GB)
- [ ] Phase 2: rename + create partitioned tables (path/file-size/IDENTITY fixes baked in)
- [ ] Phase 3: pre-load June tail (records control counts), then START PROD
- [ ] Phase 4: delta bcp out (PROD)
- [ ] Phase 5: delta bcp in + verify on SQLSTAGING
- [ ] Phase 6: gated drop (requires Phase 5 verified) + **stepped `SHRINKFILE` as a multi-hour off-peak grind** + index maintenance
- [ ] Phase 7 (deferrable): build partitioned archive on SQLARCHIVE
- [ ] Phase 8: enable monthly sliding-window Agent job

## Follow-ups (after PS stabilized)
- [ ] Decide whether to rewrite `FishingRateStatUpdateJob` cursor to `Timestamp` (or keep EntityId seek)
- [ ] Deprecate/remove `FindStatsFactIdByTimestamp` once EntityId-range backfills are migrated
- [ ] Backfill 11-12 months from archive into prod partitions; grow to 24-month retention
- [ ] Adapt runbook for Steam / XB / MOB / NX
- [ ] Confirm SQL Agent enabled on each Stats instance for the monthly sliding-window job
