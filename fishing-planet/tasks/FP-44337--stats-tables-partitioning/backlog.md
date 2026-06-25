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
- [x] Confirm SQL Agent service running on PSSTATS; set Phase 8 job owner to a service account (not `sa`) — Agent Running/Automatic; owner kept as `sa` (enabled, sysadmin ops account; service runs as `PSSTATSGOLD\Administrator`)
- [ ] SQLARCHIVE: provision disks / box for the Phase 7 archive build (deferrable)

## Confirmed with team (2026-06-08)
- STOP PROD fences ALL writers (global write-fence) — no late rows into `*_old` after the snapshot.
- `MissionsFact.Rank` is NOT NULL with no default; the app always supplies Rank (0 when empty).
- `FishingRateStatUpdateJob` cursor = `WHERE EntityId > @stored` range-scan; survives cutover and re-reads the preloaded tail.
- Safety model (simplified 2026-06-09): `@tailFrom` fixed at 2026-06-01 (never narrowed) makes **{backup} U {new June tail}** gap-free (EntityId monotonic with Timestamp), so the Phase 4/5 SQLSTAGING delta was redundant and is **removed**. Drop gate = backup restorable + Phase 3 tail count-verified + `*_old` unchanged; take a fresh full backup after the drop.
- Refined 2026-06-09 (Codex review): PROD partition boundaries now **2026-06-01 / -07-01 / -08-01** (4 partitions: empty `<Jun1` catch-all + June + July + Aug buffer) so **June is its own bounded, switchable partition**; Phase 3 loads only `Timestamp >= 2026-06-01` (clean June, late-May stays in `*_old`→backup→archive); **pre-drop full backup is now a HARD gate** (STEP 0 in Phase 6) + the post-shrink backup is the new baseline; Phase 7 boundaries align with prod's calendar; cross-server PROD↔SQLARCHIVE movement is **`SWITCH OUT` local + transfer**, not a direct SWITCH (impossible across instances).
- Permissions: app login connects as a **role member (db_owner / db_datawriter)**, so the new `StatsFact`/`MissionsFact` inherit access automatically after `sp_rename` — no object-level GRANT to carry over. (Cheap pre-flight: confirm `sys.database_permissions` has no object-level grants on the old tables.)

## Open questions for team (from DBA review)
- [ ] Is `Timestamp` server-assigned (`GETDATE()` at insert) or ever client-set/back-dated? (bounds the out-of-order tail edge)
- [ ] Any other writer to `*_old` after STOP PROD — replication / CDC / ETL / triggers? (gate asserts `*_old` unchanged, but confirm)
- [ ] Is `Stats_log` physically on `Z:`? (Phase 1's ~290 GB reclaim and the Z: headroom math depend on it)
- [ ] Measure the real max IDENTITY-assignment gap under load (sizes the Phase 3 tail margin = `@tailFrom - 100000`)
- [ ] Commit to running Phase 6 (DROP + start shrink) the SAME maintenance day — not deferred (Z: exhaustion risk)
- [ ] Rehearse the full Phase 2->3 sequence on staging INCLUDING a forced mid-load failure + idempotent re-run
- [x] Is `tempdb` on `Z:`? **YES** — 8 data files + log all on `Z:`, no other volume. Mitigation (pre-flight): pre-size + cap `MAXSIZE` so it can't grow into the shrink headroom; index builds use `SORT_IN_TEMPDB OFF` so the NCI sort hits the `Stats` data files, not tempdb. See Operator_Checklist pre-flight.
- [x] Confirm prod and SQLSTAGING/archive are the SAME SQL Server major version (backup restore for the archive needs same-or-higher) — both Standard 15.0.2000.5
- [x] Confirm no job/proc references these tables by a hardcoded 3-part / `*_old`-style name (gate (b) assumes `*_old` is untouched after STOP) — 0 rows
- [ ] Confirm `DATA_COMPRESSION=PAGE` on a partitioned table works on build 15.0.2000.5 (cheap throwaway test) + measure compressed month size

## Execution (PS) — cutover done 2026-06-12..14
- [x] Phase 1: shrink `Stats_log` (freed ~290 GB; Z: 62 -> ~352)
- [x] Phase 2: rename + create partitioned tables (4-partition + catch-all, dynamic clone); column-compare 0
- [x] Phase 3: tail load (StatsFact 58,057,797 / MissionsFact 24,811,278, clean June in P2), then START PROD
- ~~Phase 4: delta bcp out~~ / ~~Phase 5: delta bcp in~~ — **REMOVED** (redundant; preservation = {backup} U {June tail})
- [~] Phase 6: pre-drop backup + gate + DROP done; stepped shrink done (Stats 3205.6 GB -> ~740 GB, Z: -> ~2.67 TB). **PENDING: STEP 3 index REBUILD of fragmented remaining tables (in an upcoming maintenance downtime) + post-shrink baseline backup**
- [ ] Phase 7 (deferrable): build partitioned archive on SQLARCHIVE (TESTVova) from a restored backup, `< 2026-06-01`
- [x] Phase 8: monthly sliding-window Agent job CREATED & verified on PROD (2026-06-25). Proc `usp_Fact_AddNextMonth` + job `Facts_AddNextMonth`; schedule `Monthly_28th_at_02` (02:00 NY = ~06:00 UTC trough); next run 2026-06-28 02:00; smoke-test via `sp_start_job` green (both steps no-op `added 0`, run under `PSSTATSGOLD\Administrator`)

## Follow-ups (after PS stabilized)
- [ ] Decide whether to rewrite `FishingRateStatUpdateJob` cursor to `Timestamp` (or keep EntityId seek)
- [ ] Deprecate/remove `FindStatsFactIdByTimestamp` once EntityId-range backfills are migrated
- [ ] Backfill 11-12 months from archive into prod partitions; grow to 24-month retention
- [ ] Adapt runbook for Steam / XB / MOB / NX
- [ ] Confirm SQL Agent enabled on each Stats instance for the monthly sliding-window job
