# PS STATS Partitioning — Operator Checklist (FP-44337)

How to use this: it is a **step-by-step playbook**, NOT "run each .sql whole". Work top to bottom,
tick each box, run scripts **batch by batch** (`GO`-separated), read each verification result before
proceeding, and **record captured values in the Ledger (B)** so later phases reuse the same numbers.
Servers: **PROD** = MSSQL15.PSSTATS · **SQLSTAGING** = restored-backup copy · **SQLARCHIVE** = future archive · **cmd** = Windows command prompt on that box.

Scripts live next to this file. The master narrative is `Runbook_PS_Stats_Partitioning.md`.

---

## A. Pre-flight (days before — NOT in the window)
- [x] Confirm SQL Agent service is running on PROD (needed for Phase 8 later).
- [x] Confirm Instant File Initialization (perform-volume-maintenance-tasks) is granted to the SQL service account.
- [x] Confirm `Stats_log` is physically on `Z:` (else Phase 1 reclaim doesn't help the shrink headroom).
- [x] Confirm `tempdb` location. **On `Z:`** (8 data files + log, all under `Z:\...\MSSQL15.PSSTATS\MSSQL\DATA\`); no other volume available. Not a blocker: our index builds run with `SORT_IN_TEMPDB OFF` (sort space comes from the `Stats` data files, not tempdb), so tempdb's load in the window is mainly incidental prod-query spills during the online Phase 6.
- [ ] **Pre-size tempdb + cap `MAXSIZE` (before the window — needs an instance restart).** Current config is runaway-prone: each of the 8 data files is 8 MB initial, autogrow **+8 MB, no max** — on a near-full `Z:` a big spill could grow tempdb into the shrink headroom and derail Phase 6. Set a fixed initial `SIZE`, a larger `FILEGROWTH` (e.g. 512 MB, log 256 MB), and a per-file `MAXSIZE` so total tempdb cannot exceed its budget. The cap converts a silent "tempdb fills `Z:` → shrink/window derails" into a contained "a query fails with tempdb-full". Exact MB come from the staging `Z:`-budget measurement (compressed June-tail + NCI-build peak). Apply at the next planned restart **before** the window — the initial `SIZE` only takes effect on restart (`MAXSIZE`/growth apply live but won't shrink the file below its current runtime size). Per-file: `ALTER DATABASE tempdb MODIFY FILE (NAME=N'tempdev', SIZE=<N>MB, FILEGROWTH=512MB, MAXSIZE=<M>MB);` (repeat for `temp2..temp8` with the same N/M; `templog` separately).
- [x] Confirm PROD and SQLSTAGING/archive are the **same SQL major version** (backup restore needs same-or-higher; both Standard 15.0.2000.5).
- [x] Confirm no object-level GRANTs on `dbo.StatsFact`/`MissionsFact`. **Clean** — app login `farm` is a member of `db_datareader`+`db_datawriter`(+`db_ddladmin`), all DB-level roles → new tables inherit INSERT/SELECT automatically; `sys.database_permissions class=1` returned 0 rows, so nothing to carry over (no `GRANT` needed in Phase 2).
- [x] Confirm no job/proc references these tables by a hardcoded `*_old`-style or 3-part name. **Clean** — searched `sys.sql_modules` + `sys.synonyms` across all online DBs and `msdb.dbo.sysjobsteps`: 0 rows. No DB-side consumer; the one `EntityId`-cursor reader (`FishingRateStatUpdateJob`) is app-side (not an Agent job), handled by the Phase 3 tail pre-load. (Cross-instance linked-server paths from Main remain a separate backlog item.)
- [ ] Throwaway test on staging: `DATA_COMPRESSION=PAGE` on a partitioned table works on build 15.0.2000.5.
- [ ] **Measure on staging:** compressed June-tail size + NCI-build peak (sort) space → confirm `Z:` headroom covers it; size the Phase-2 June file accordingly.
- [ ] Confirm `>= 2` preserved copies exist: backup file on backup server **+** restored copy on SQLSTAGING; `RESTORE VERIFYONLY` + `DBCC CHECKDB` the SQLSTAGING copy.
- [ ] Agree the window (~2 h) and that **Phase 6 runs the same day** (don't defer; Z: exhaustion risk).
- [ ] Fix the file path in `Phase2_PROD_Swap.sql` to the real `Z:\...\MSSQL15.PSSTATS\MSSQL\DATA\`.

## B. Values ledger (fill as you go — reuse, do NOT re-derive)
| Value                                                   | StatsFact        | MissionsFact | Captured at           |
|---------------------------------------------------------|------------------|--------------|-----------------------|
| Backup point (cutoff)                                   | 2026-06-08 00:45 | (same)       | fixed                 |
| `@tailFrom`                                             | 2026-06-01       | 2026-06-01   | fixed (do NOT narrow) |
| IDENTITY seed (printed by Phase 2)                      | 1830751          | 1973685      | Phase 2 *(Test2)*     |
| MaxOldId (printed by Phase 3)                           | 830751           | 973685       | Phase 3 *(Test2)*     |

> ⚠️ Values tagged *(Test2)* are from the staging rehearsal, NOT prod. **Clear this Ledger before the
> real PROD run** — prod ids differ and must be re-captured live (Ledger is per-run, not portable).

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
- [ ] Run the **verification** block: column-compare query returns **0 rows**; partition layout = **4 partitions** (catch-all / 06 / 07 / 08 filegroups), **all empty** at this point (the June tail loads in Phase 3).
- [ ] If column-compare returns rows → STOP, resolve the schema mismatch before continuing.

### D3. Phase 3 — tail pre-load + NCI (PROD) — `Phase3_PROD_TailLoad.sql`
- [ ] Run the tail-load batch. It TRUNCATEs the new tables first (idempotent) and **THROWs** if they already hold live rows (safety against an accidental post-START run) or if counts mismatch.
- [ ] Confirm both "Tail verified: ... rows=..." lines printed (no THROW). **Record** MaxOldId per table → Ledger.
- [ ] Run the two NCI-build batches.
- [ ] Run the sanity SELECT (rows_now / min_ts / max_ts). NOTE: Phase 3 loads only `Timestamp >= 2026-06-01` (clean June partition); rows land in P2 (June), the catch-all P1 stays empty.
- [ ] If Phase 3 aborted: fix the cause and **re-run the whole script** (it is idempotent) — do NOT START PROD on a partial tail.

### D4. START PROD
- [ ] Start the writers. Confirm new inserts land in the new `StatsFact`/`MissionsFact`. **Downtime ends — stop the clock.**

> Rollback up to here is clean: STOP PROD, drop the new tables, `sp_rename *_old → *`, START PROD.

---

## E. Online cleanup (after START — no downtime)

> Phases 4-5 (SQLSTAGING delta export/import) were **removed** as redundant — the post-backup rows are
> already in the new June tail (Phase 3). Preservation = {backup} U {June tail}. See the Runbook.

### E1. Phase 6 STEP 1 — gate + DROP (PROD) — **irreversible** — `Phase6_PROD_Drop_Shrink.sql`
- [ ] **STEP 0 — pre-drop full backup (HARD gate):** take a FRESH online full backup of `Stats` (it still contains `*_old` in full) + `RESTORE VERIFYONLY`; retain >= 2 copies. ~3.2 TB → ensure backup-server space + a few hours. Do NOT run STEP 1 until this is done & verified.
- [ ] **Manual gate (a):** confirm aloud the pre-drop backup (STEP 0) is complete, verified, and retained.
- [ ] Run the STEP 1 (gate) batch. It **THROWs and does NOT drop** unless: Phase 3 preload counts match (re-counted in the tail id-range, old vs new) **AND** `*_old` MAX is unchanged since Phase 3. No staging paste-ins, no STEP 0.
- [ ] Confirm "Verification passed (preload complete + *_old unchanged). Old tables dropped." Then run the free-in-file SELECT (expect ~2.5 TB free-in-file).
- [ ] If a THROW fires: **do not retry blindly** — read the message, fix the cause (e.g. a stray writer touched `*_old` after STOP), then re-run.

### E2. Phase 6 STEP 2 — shrink (PROD, ONLINE, HOURS, off-peak) — `Phase6_PROD_Drop_Shrink.sql`
- [ ] Start a **`Z:` free-space alert (< 50 GB)** and keep it active for the whole shrink.
- [ ] Run `TRUNCATEONLY`, then the stepped-shrink loop (~50 GB/step, recomputes target, WAITFOR throttle).
  Expect it to run for hours and to briefly stall live inserts (Sch-M locks on 2019 Standard) — schedule strictly off-peak.
- [ ] **If the loop prints "Shrink made no progress ..." and stops** → the high-water mark is pinned by remaining-table pages. Sub-procedure:
  1. `ALTER INDEX ALL ON dbo.Stmt REBUILD;` (and FishFact/SilverStmt/Balance/ActionStats/... — the worst offenders from STEP 3's query) to compact them low and drop the HWM.
  2. Re-run the stepped-shrink loop. Repeat until `Z:` free reaches the target.
  3. If still stuck, move those tables to a new filegroup and shrink PRIMARY to near-empty.

### E3. Phase 6 STEP 3 — index maintenance (PROD)
- [ ] Run the fragmentation query; `ALTER INDEX ALL ON <tbl> REBUILD;` (bare — preserves compression) on the fragmented remaining tables.
- [ ] (Optional, once everything is verified) `DROP TABLE dbo.FP44337_TailLoadControl;`.

### E4. Fresh full backup (PROD) — **do not skip**
- [ ] Take a new full backup of `Stats` after the drop + shrink. Until now the post-backup June tail lived only in the live partition; this restores an independent copy of it. (Also the new baseline for the much smaller post-cleanup DB.)

---

## F. Deferred (after the cutover — separate days, no rush)
- [ ] **Phase 7 — archive build (SQLARCHIVE)** — `Phase7_SQLARCHIVE_BuildAndLoad.sql`. Build the partitioned analyst archive from the **restored backup**, loading history **< 2026-06-01** (the dropped bulk); June+ stays on prod and SWITCHes into the archive later as it ages out. Align the archive's monthly boundaries with prod. Does not block prod. Keep the backup until the archive is verified.
- [ ] **Phase 8 — sliding-window job (PROD)** — `Phase8_PROD_SlidingWindowJob.sql`. Run the dry-run (`@Debug=1`) first, then create the proc + Agent job (28th 02:00 NY-local / ~06:00 UTC trough). Confirm Agent is running.
- [ ] **Later:** backfill 11-12 months from the archive into prod partitions; grow to 24-month retention.

## G. Rollback quick-reference
- **Before Phase 6 STEP 1 (the DROP):** fully reversible — STOP PROD, drop the new tables, `sp_rename *_old → *` (restore PK/DF names), START PROD. `*_old` data intact.
- **After the DROP:** prod history is gone from prod but preserved as the full backup (backup-server file + the restored SQLSTAGING copy) and, once built, the archive; the June+ tail is in the new prod partition. **The post-backup tail (rows ~2026-06-08 00:45 → STOP) lives ONLY in the live June partition until the fresh full backup (E4) — do NOT skip E4.** Recovery = restore/backfill from those (not an in-window rollback). This is exactly why the gate must pass cleanly first.
