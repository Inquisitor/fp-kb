# PS STATS Partitioning — Operator Checklist (FP-44337)

How to use this: it is a **step-by-step playbook**, NOT "run each .sql whole". Work top to bottom,
tick each box, run scripts **batch by batch** (`GO`-separated), read each verification result before
proceeding, and **record captured values in the Ledger (B)** so later phases reuse the same numbers.
Servers: **PROD** = MSSQL15.PSSTATS · **SQLSTAGING** = restored-backup copy · **SQLARCHIVE** = future archive · **cmd** = Windows command prompt on that box.

Scripts live next to this file. The master narrative is `Runbook_PS_Stats_Partitioning.md`.

---

## A. Pre-flight (days before — NOT in the window)
- [ ] Confirm SQL Agent service is running on PROD (needed for Phase 8 later).
- [ ] Confirm Instant File Initialization (perform-volume-maintenance-tasks) is granted to the SQL service account.
- [ ] Confirm `Stats_log` is physically on `Z:` (else Phase 1 reclaim doesn't help the shrink headroom).
- [ ] Confirm `tempdb` location (if on `Z:`, the Phase 3 NCI build + Phase 6 shrink contend for the same volume).
- [ ] Confirm PROD and SQLSTAGING are the **same SQL major version** (native `bcp -n` is version-sensitive).
- [ ] Confirm no object-level GRANTs on `dbo.StatsFact`/`MissionsFact` (app login is role member db_owner/db_datawriter → new tables inherit; nothing to carry over).
- [ ] Confirm no job/proc references these tables by a hardcoded `*_old`-style or 3-part name.
- [ ] Throwaway test on staging: `DATA_COMPRESSION=PAGE` on a partitioned table works on build 15.0.2000.5.
- [ ] **Measure on staging:** compressed June-tail size + NCI-build peak (sort) space → confirm `Z:` headroom covers it; size the Phase-2 June file accordingly.
- [ ] Confirm `>= 2` preserved copies exist: backup file on backup server **+** restored copy on SQLSTAGING; `RESTORE VERIFYONLY` + `DBCC CHECKDB` the SQLSTAGING copy.
- [ ] Decide a Temp path with free space for the delta `.dat` files on PROD and SQLSTAGING (NOT the full `Z:`).
- [ ] Agree the window (~2 h) and that **Phase 6 runs the same day** (don't defer; Z: exhaustion risk).
- [ ] Fix the file path in `Phase2_PROD_Swap.sql` to the real `Z:\...\MSSQL15.PSSTATS\MSSQL\DATA\`.

## B. Values ledger (fill as you go — reuse, do NOT re-derive)
| Value                                                   | StatsFact        | MissionsFact | Captured at           |
|---------------------------------------------------------|------------------|--------------|-----------------------|
| Backup point (cutoff)                                   | 2026-06-08 00:45 | (same)       | fixed                 |
| `@tailFrom`                                             | 2026-06-01       | 2026-06-01   | fixed (do NOT narrow) |
| IDENTITY seed (printed by Phase 2)                      |                  |              | Phase 2               |
| MaxOldId (printed by Phase 3)                           |                  |              | Phase 3               |
| **SQLSTAGING MAX(EntityId)** (one-shot, BEFORE Phase 5) |                  |              | Phase 4 STEP A        |
| delta export-after id (= stagingMax − margin)           |                  |              | Phase 4               |
| **SQLSTAGING COUNT_BIG(*)** (after Phase 5 import)      |                  |              | Phase 6 prep          |

> The SQLSTAGING MAX is captured ONCE before Phase 5 and reused everywhere. Re-reading it after the
> import moves the export floor forward and would skip rows.

---

## C. Phase 1 — log shrink (PROD, ONLINE, before the window) — `Phase1_PROD_ShrinkLog.sql`
- [ ] Run the pre-check batch; confirm `recovery_model_desc = SIMPLE` and `log_reuse_wait_desc IN (NOTHING, CHECKPOINT)`.
- [ ] Run the shrink batch (it hard-stops if the log is pinned). Log → ~32 GB.
- [ ] Verify `xp_fixeddrives`: `Z:` free jumped to ~352 GB. **Do not proceed to the window until this is true.**

---

## D. MAINTENANCE WINDOW — DOWNTIME (target ~2 h; start the clock here)

### D1. STOP PROD
- [ ] Stop ALL writers (game servers, async/ETL, FishingRate job). Confirm zero connections inserting into Stats.

### D2. Phase 2 — structural swap (PROD) — `Phase2_PROD_Swap.sql`
- [ ] Run Step 1 (rename, both tables) → Step 2 (drop new+leftover partition objects) → Step 3 (FGs/files June/July/Aug) → Step 4 (PF/PS) → Step 5/6 (create partitioned tables). Run batch by batch.
- [ ] **Record** the printed `IDENTITY start` for each table → Ledger.
- [ ] Run the **verification** block: column-compare query returns **0 rows**; partition layout = 3 partitions on the 06/07/08 filegroups; the Aug partition has 0 rows.
- [ ] If column-compare returns rows → STOP, resolve the schema mismatch before continuing.

### D3. Phase 3 — tail pre-load + NCI (PROD) — `Phase3_PROD_TailLoad.sql`
- [ ] Run the tail-load batch. It TRUNCATEs the new tables first (idempotent) and **THROWs** if they already hold live rows (safety against an accidental post-START run) or if counts mismatch.
- [ ] Confirm both "Tail verified: ... rows=..." lines printed (no THROW). **Record** MaxOldId per table → Ledger.
- [ ] Run the two NCI-build batches.
- [ ] Run the sanity SELECT (rows_now / min_ts / max_ts look like June).
- [ ] If Phase 3 aborted: fix the cause and **re-run the whole script** (it is idempotent) — do NOT START PROD on a partial tail.

### D4. START PROD
- [ ] Start the writers. Confirm new inserts land in the new `StatsFact`/`MissionsFact`. **Downtime ends — stop the clock.**

> Rollback up to here is clean: STOP PROD, drop the new tables, `sp_rename *_old → *`, START PROD.

---

## E. Online cleanup (after START — no downtime)

### E1. Phase 4 — delta export (PROD + cmd) — `Phase4_PROD_DeltaExport.sql`
- [ ] **STEP A (SQLSTAGING):** `SELECT MAX(EntityId) FROM dbo.StatsFact;` and `... MissionsFact;` → **Record SQLSTAGING MAX** → Ledger. (Capture ONCE, before Phase 5.)
- [ ] Paste those into `@stagingMax_S/@stagingMax_M`, run the SELECT batch (it THROWs if left NULL). **Record** `export_after_id` and `prod_max_id` per table → Ledger.
- [ ] From **cmd on PROD**, run the two `bcp ... queryout` commands with the printed `export_after_id`. Copy both `.dat` files to SQLSTAGING.

### E2. Phase 5 — delta import to SQLSTAGING (SQLSTAGING + cmd) — `Phase5_STAGING_DeltaImport.sql`
- [ ] Run step 0 (col-count) and step 1 (create temp tables).
- [ ] From **cmd on SQLSTAGING**, run the two `bcp ... in` commands **with `-E`** (keeps original EntityIds).
- [ ] Run step 2 (dedup INSERT WHERE NOT EXISTS). Confirm "inserted N new rows" looks right.
- [ ] Run step 3 (verify): SQLSTAGING `MAX(EntityId)` now **equals prod `prod_max_id`** (Ledger) for both tables.
- [ ] Run step 4 checksum (paste `export_after_id` into `@fromS/@fromM`); record `rows / chk / msg_chk`. **Run the identical query on PROD `*_old`** (same id range) and confirm all three match per table.
- [ ] Run step 5 (drop temp tables).
- [ ] **Record SQLSTAGING COUNT_BIG(*)**: `SELECT COUNT_BIG(*) FROM dbo.StatsFact;` / `... MissionsFact;` → Ledger.

### E3. Phase 6 STEP 0 — record *_old counts (PROD, off-peak, heavy) — `Phase6_..._Drop_Shrink.sql`
- [ ] Run **STEP 0** only (the MERGE batches into `FP44337_DropGate`). This is a multi-hour clustered scan — run off-peak. It records `COUNT`+`MAX` of each `*_old`.
- [ ] Confirm `SELECT * FROM dbo.FP44337_DropGate` shows both tables with sane counts.

### E4. Phase 6 STEP 1 — gate + DROP (PROD) — **irreversible** — `Phase6_..._Drop_Shrink.sql`
- [ ] **Manual gate (a):** confirm aloud the backup is retained (>= 2 copies) and proven restorable.
- [ ] Paste into STEP 1: `@stagingMax_S/M` (Ledger) and `@stagingCnt_S/M` (Ledger).
- [ ] Run the STEP 1 (gate) batch. It **THROWs and does NOT drop** unless: preload counts match, `*_old` unchanged since Phase 3 and STEP 0, and SQLSTAGING `MAX` **and** `COUNT` both equal `*_old`.
- [ ] Confirm "Verification passed. Old tables dropped." Then run the free-in-file SELECT (expect ~2.5 TB free-in-file).
- [ ] If any THROW fires: **do not retry blindly** — read the message, fix the cause (e.g. re-run Phase 5 / STEP 0), then re-run STEP 1.

### E5. Phase 6 STEP 2 — shrink (PROD, ONLINE, HOURS, off-peak) — `Phase6_..._Drop_Shrink.sql`
- [ ] Start a **`Z:` free-space alert (< 50 GB)** and keep it active for the whole shrink.
- [ ] Run `TRUNCATEONLY`, then the stepped-shrink loop (~50 GB/step, recomputes target, WAITFOR throttle).
  Expect it to run for hours and to briefly stall live inserts (Sch-M locks on 2019 Standard) — schedule strictly off-peak.
- [ ] **If the loop prints "Shrink made no progress ..." and stops** → the high-water mark is pinned by remaining-table pages. Sub-procedure:
  1. `ALTER INDEX ALL ON dbo.Stmt REBUILD;` (and FishFact/SilverStmt/Balance/ActionStats/... — the worst offenders from STEP 3's query) to compact them low and drop the HWM.
  2. Re-run the stepped-shrink loop. Repeat until `Z:` free reaches the target.
  3. If still stuck, move those tables to a new filegroup and shrink PRIMARY to near-empty.

### E6. Phase 6 STEP 3 — index maintenance (PROD)
- [ ] Run the fragmentation query; `ALTER INDEX ALL ON <tbl> REBUILD;` (bare — preserves compression) on the fragmented remaining tables.
- [ ] (Optional, once everything is verified) `DROP TABLE dbo.FP44337_DropGate; DROP TABLE dbo.FP44337_TailLoadControl;`.

---

## F. Deferred (after the cutover — separate days, no rush)
- [ ] **Phase 7 — archive build (SQLARCHIVE)** — `Phase7_SQLARCHIVE_BuildAndLoad.sql`. Build the partitioned analyst archive from a complete copy (SQLSTAGING or a fresh backup of it) once hardware/disks are ready. Does not block prod. Keep the SQLSTAGING copy until this is done and verified.
- [ ] **Phase 8 — sliding-window job (PROD)** — `Phase8_PROD_SlidingWindowJob.sql`. Run the dry-run (`@Debug=1`) first, then create the proc + Agent job (28th 23:00). Confirm Agent is running.
- [ ] **Later:** backfill 11-12 months from the archive into prod partitions; grow to 24-month retention.

## G. Rollback quick-reference
- **Before Phase 6 STEP 1 (the DROP):** fully reversible — STOP PROD, drop the new tables, `sp_rename *_old → *` (restore PK/DF names), START PROD. `*_old` data intact.
- **After the DROP:** prod history is gone from prod but preserved as the full backup + the SQLSTAGING copy. Recovery = restore/backfill from those (not an in-window rollback). This is exactly why the STEP 1 gate must pass cleanly first.
