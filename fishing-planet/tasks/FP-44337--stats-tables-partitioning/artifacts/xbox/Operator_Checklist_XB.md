# XB STATS Partitioning — Operator Checklist (FP-44337)

How to use this: it is a **step-by-step playbook**, NOT "run each .sql whole". Work top to bottom, tick
each box, run scripts **batch by batch** (`GO`-separated), read each verification result before proceeding,
and **record captured values in the Ledger (B)** so later phases reuse the same numbers.
Servers: **PROD** = `WIN-4J27M0I84AC\XBSTATS` (**Enterprise**, Pacific TZ) · **SPARE** = restore-verification box (TBD) · **cmd** = Windows command prompt on that box.

Scripts live next to this file. Third platform run — the playbook is PS+Steam-validated; XB specifics:
**single C: volume** (system drive, ~363 GB free at assessment), **Enterprise** (STEP 3 rebuild is ONLINE),
**Pacific time** (Phase 8 schedule = 23:00 local), tiny early-October tail.

---

## A. Pre-flight (before the window)
- [ ] **Run `Phase1_XB_LogRightsize.sql`** (online): log 136 -> 32 GB (~+105 GB on C:), growth fixes
  (log 10% -> 1 GB, mdf 1 MB -> 2 GB), `backup checksum default = 1`. Verify the output.
- [ ] **SQL Agent service -> Automatic** (was Manual!): `Set-Service 'SQLAgent$XBSTATS' -StartupType Automatic`;
  confirm it is Running.
- [ ] **Window slot = 06:05 UTC = 23:05 local (Pacific, UTC-7) on 2026-09-30.** The nightly full starts
  00:20 local = 07:20 UTC and runs ~1 h 25 m: it is NOT disabled - it becomes STEP 0 (see E1). Hard rule:
  **Phase 2 Step 3 (`ADD FILE`) must be finished before 07:20 UTC** (file ops serialize against a running
  backup, error 3023); INSERT / CREATE INDEX / sp_rename do not conflict with it.
- [ ] Pin tonight's nightly backup file against rotation (it is the pre-drop copy #1) - agree the path/name
  with DevOps before the window.
- [ ] **WINDOW TIMING (UTC month-boundary guard):** `Timestamp` is stored in UTC. STOP PROD must land at
  least ~2 h AFTER 2026-10-01 00:00 UTC, or the incremental cursor's ~1 h lag reaches back into September
  (which the `>= Oct 1` tail does not cover). The ~02:00 Pacific slot = ~09:00 UTC = safely past.
- [ ] tempdb: pre-size + cap `MAXSIZE` (8 files, 8 MB initial, 64 MB growth, no cap — the config that
  ballooned ~33 GB on Steam). Remember: `sys.master_files` shows tempdb's RESTART size, not current.
- [ ] Confirm the pre-drop backup target (backup server; nightly compressed fulls are ~590 GB, the pre-drop
  will be similar) + the SPARE box for restore-verification (~2 TB data space).
- [ ] Confirm no object-level GRANTs on the fact tables; no job/proc hardcoded `*_old`/3-part references.
- [ ] Verify the exact data path against `sys.master_files` (scripts assume
  `C:\Program Files\Microsoft SQL Server\MSSQL15.XBSTATS\MSSQL\DATA\`).
- [ ] Finalize the **cutover month** -> scripts assume OCTOBER (`10/11/12` boundaries); shift everything
  if the window slips past October.

## B. Values ledger (fill as you go — reuse, do NOT re-derive)
| Value                                             | StatsFact        | MissionsFact     | Captured at            |
|---------------------------------------------------|------------------|------------------|------------------------|
| `@tailFrom` (cutover month 1st)                   | 2026-10-01       | 2026-10-01       | fixed (do NOT narrow)  |
| Lifetime size reference (assessment 2026-09-30)   | 3.38 B rows / 1004 GB | 3.84 B rows / 598 GB | for sizing only   |
| Tail boundary EntityId (Phase 3 print)            | _(capture live)_ | _(capture live)_ | Phase 3                |
| IDENTITY seed (printed by Phase 2)                | _(capture live)_ | _(capture live)_ | Phase 2                |
| MaxOldId (printed by Phase 3)                     | _(capture live)_ | _(capture live)_ | Phase 3                |
| Pre-drop FULL taken at                            | _(capture live)_ | (same)           | Phase 6 STEP 0         |

> Live ids start at MaxOldId+1M — Phase 3 now re-applies the identity cushion after the load
> (the Steam finding is fixed in the script). Post-START check threshold = the RE-APPLIED seed.

---

## C. Phase 1 — log right-size + instance prep (PROD, ONLINE, before the window) — `Phase1_XB_LogRightsize.sql`
- [ ] Pre-checks: SIMPLE, `log_reuse_wait_desc` NOTHING/CHECKPOINT.
- [ ] Shrink path fires (136 -> 32 GB). If it stops short (active VLF) — re-run after a few checkpoints.
- [ ] Verify: log ~32 GB, growth steps fixed-MB on log AND mdf, `backup checksum default` in use, C: free jumped ~+105 GB.

---

## D. MAINTENANCE WINDOW — DOWNTIME (early-October tail = minutes; start the clock here)

### D1. STOP PROD
- [ ] At 06:05 UTC (23:05 local): 6 h past the UTC month start (cursor guard OK) and 75 min before the 07:20 UTC nightly (see A).
- [ ] Stop ALL writers (game servers, async/ETL, FishingRate job). Confirm zero inserting connections.

### D2. Phase 2 — structural swap (PROD) — `Phase2_XB_Swap.sql`
- [ ] Step 1 (rename, both tables) -> Step 2 (drop leftovers) -> Step 3 (FGs/files Oct/Nov/Dec) -> Step 4 (PF/PS) -> Step 5/6 (create tables). Batch by batch. **Step 3 must be done before 07:20 UTC** (nightly backup blocks `ADD FILE`).
- [ ] **Record** both printed `IDENTITY start` values -> Ledger; check the StatsFact Rank-default line.
- [ ] **Verification**: column-compare **0 rows**; **4 partitions** each (catch-all / 10 / 11 / 12), all `rows = 0`.

### D3. Phase 3 — tail pre-load + NCI (PROD) — `Phase3_XB_TailLoad.sql`
- [ ] Tail-load batch (tiny for an early-October window — minutes). Wait for BOTH `Tail verified: ... rows=...` lines (THROW = stop, fix, re-run whole script; idempotent).
- [ ] **Record** boundary/MaxOldId -> Ledger. Confirm the `Identity cushion re-applied: ... reseeded to ...` prints (both tables).
- [ ] Two NCI-build batches (`(UserId, Timestamp)` aligned, PAGE).
- [ ] Sanity SELECT: `rows_now` = tail counts, `min_ts >= 2026-10-01` (UTC), `max_ts` ≈ STOP.

### D4. START PROD
- [ ] Start writers. Confirm live inserts: `MAX(EntityId) > re-applied seed` on both (the cushion WORKS on XB — threshold is seed, not MaxOldId). **Downtime ends.**

> Rollback up to here is clean: STOP PROD, drop the new tables, `sp_rename *_old -> *`, START PROD.

---

## E. Online cleanup (after START — no downtime)

### E1. Phase 6 STEP 0 — pre-drop FULL (HARD gate) = tonight's nightly full
- [ ] **STEP 0 is the 00:20-local (07:20 UTC) nightly full** - it starts AFTER START PROD, so it captures `*_old` in full (frozen since STOP) and, with Phase 1's `backup checksum default = 1`, runs WITH CHECKSUM. No manual pre-drop backup needed. Confirm in `msdb.dbo.backupset` when it finishes (~08:45 UTC): `has_backup_checksums = 1`, `is_damaged = 0`.
- [ ] **Pin that file against rotation** (pre-drop copy #1) - record path + timestamp -> Ledger.
- [ ] **Restore it on the SPARE** (Steam model = our standard) + spot-verify `*_old` against the Ledger (MAX id + tail-range count per table) = copy #2 + restorability proven.
- [ ] Fallback only if the nightly fails/skips: manual `BACKUP ... WITH COMPRESSION, CHECKSUM` from `Phase6_XB_Drop_Shrink.sql` STEP 0.

### E2. Phase 6 STEP 1 — gate + DROP (PROD) — **irreversible**
- [ ] Run the gate batch; expect `OK` both tables + `Old tables dropped.` (THROW = do not retry blindly).
- [ ] Free-in-file SELECT: mdf used drops to ~400 GB over minutes (deferred drop).

### E3. Phase 6 STEP 2 — stepped shrink (PROD, ONLINE, off-peak, hours)
- [ ] `TRUNCATEONLY`, then the stepped loop (~50 GB/step, recomputed target, no-progress guard). C: alert active.
- [ ] Expect: mdf ~2 TB -> ~500 GB; C: free -> ~1.8-1.9 TB.

### E4. Phase 6 STEP 3 — index maintenance (PROD, **ONLINE — Enterprise**)
- [ ] Frag query -> `ALTER INDEX ALL ON dbo.<tbl> REBUILD WITH (ONLINE = ON);` per offender. No downtime needed (unlike PS/Steam).
- [ ] (Optional, once verified) `DROP TABLE dbo.FP44337_TailLoadControl;`

### E5. Baseline
- [ ] The next nightly full (00:20, now checksummed) is the post-shrink baseline — verify it completed + `has_backup_checksums = 1`.

---

## F. Deferred
- [ ] **Phase 8 — sliding-window job** — `Phase8_XB_SlidingWindowJob.sql`. Agent Automatic+Running first. Dry-run (`@Debug=1`) -> job (**28th 23:00 local Pacific** = ~06:00 UTC) -> post-checks (next-run via **sysjobactivity**, not the sysjobschedules cache) -> `sp_start_job` smoke (no-op `added 0`).
- [ ] **Phase 7 — archive build** — `Phase7_ARCHIVE_XB_BuildAndLoad.sql` from the SPARE's restored copy, history `< 2026-10-01`. Keep the pre-drop backup + restored copy until verified.
- [ ] `DBCC CHECKDB` the restored copy on the SPARE (background).

## G. Rollback quick-reference
- **Before E2 (the DROP):** fully reversible — STOP PROD, drop new tables, `sp_rename *_old -> *`, START PROD.
- **After the DROP:** history preserved as the pre-drop FULL + the SPARE's restored copy; the October+ tail is live on prod. The post-STOP tail has no independent copy until the next nightly full — recovery = restore/backfill, not in-window rollback.
