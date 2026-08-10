# STEAM STATS Partitioning — Operator Checklist (FP-44337)

How to use this: it is a **step-by-step playbook**, NOT "run each .sql whole". Work top to bottom, tick
each box, run scripts **batch by batch** (`GO`-separated), read each verification result before proceeding,
and **record captured values in the Ledger (B)** so later phases reuse the same numbers.
Servers: **PROD** = `WIN-3HO01NN5VO4\STEAMSTATS` · **ARCHIVE** = future archive box (TBD) · **cmd** = Windows command prompt on that box.

Scripts live next to this file. The master narrative is `Runbook_STEAM_Stats_Partitioning.md`.
Derived from the validated PS run. **`Z:` has tightened: 307 GB (2026-07-06) → ~91 GB (2026-08-10)** — near-PS urgency: cut over ASAP, buffer files start small, Phase 6 the same day.

---

## A. Pre-flight (days before — NOT in the window)
- [ ] Confirm SQL Agent service is running on PROD (STEAMSTATS) — needed for Phase 8.
- [ ] Confirm Instant File Initialization (perform-volume-maintenance-tasks) is granted to the SQL service account.
- [ ] **Confirm `tempdb` location (UNKNOWN on Steam — verify).** If its data files are on `Z:`, pre-size + cap
  per-file `MAXSIZE` (before the window — initial `SIZE` needs a restart; `MAXSIZE`/growth apply live) so a spill
  can't grow tempdb into the shrink headroom, and keep STEP 3 rebuilds as bare `REBUILD` (`SORT_IN_TEMPDB OFF`).
  If tempdb is on another volume, no action.
- [x] Confirm PROD is Standard 15.0.2000.5 (same major version as the archive target — restore needs same-or-higher). **Confirmed** (assessment 2026-07-06).
- [ ] Confirm no object-level GRANTs on `dbo.StatsFact`/`MissionsFact` (app login is a role member → new tables inherit access; check `sys.database_permissions class=1` returns 0 rows).
- [ ] Confirm no job/proc references these tables by a hardcoded `*_old`-style or 3-part name (search `sys.sql_modules` + `sys.synonyms` across online DBs and `msdb.dbo.sysjobsteps`).
- [ ] (Optional) Throwaway test: `DATA_COMPRESSION=PAGE` on a partitioned table works on 15.0.2000.5 (already proven on PS prod — skip if trusting PS).
- [ ] **Re-measure the August tail the day of cutover** (binary-search boundary script) → size the `2026_08` file and the Phase 3 load time. Cut over **early in the month** to keep the tail small (~11 M rows/day).
- [ ] Confirm the pre-drop backup target (backup-server space for ~3.2 TB) and a 2nd retained copy plan.
- [ ] **Audit `Z:` (tight: ~91 GB on 2026-08-10, was 307)** — ~100 GB of the drop is unaccounted (data-file growth explains only ~109 GB): check tempdb / other DBs / backup files parked on `Z:`, delete or move quick wins, re-check `xp_fixeddrives` daily until the window.
- [ ] Agree the window (~2 h) and that **Phase 6 runs the same day** (`Z:` is tight — do NOT leave the file at ~3.35 TB).
- [ ] Confirm the file path in `Phase2_STEAM_Swap.sql` = real `Z:\Microsoft SQL Server\MSSQL15.STEAMSTATS\MSSQL\DATA\`.
- [ ] Finalize the **cutover month** → if NOT August, shift Phase 2 boundaries + FG suffixes and Phase 3 `@tailFrom` to that month.

> Phase 1 on Steam is a log **right-size** (pre-grow to ~32 GB), not the PS emergency shrink — see section C.

## B. Values ledger (fill as you go — reuse, do NOT re-derive)
| Value                                             | StatsFact                     | MissionsFact                | Captured at            |
|---------------------------------------------------|-------------------------------|-----------------------------|------------------------|
| `@tailFrom` (cutover month 1st)                   | 2026-08-01                    | 2026-08-01                  | fixed (do NOT narrow)  |
| Tail sizing reference (July assessment)           | ~40.4 M rows / id ~14,945,287,783..14,985,656,189 | ~26.1 M rows / id ~3,500,490,596..3,526,572,528 | 2026-07-06 (re-measure the AUGUST tail at cutover) |
| IDENTITY seed (printed by Phase 2)                | _(capture live)_              | _(capture live)_            | Phase 2                |
| MaxOldId (printed by Phase 3)                     | _(capture live)_              | _(capture live)_            | Phase 3                |
| Pre-drop FULL taken at                            | _(capture live)_              | (same)                      | Phase 6 STEP 0         |

> The pre-drop FULL (taken in-window, Phase 6 STEP 0) is the preservation source — it contains all of `*_old`,
> so there is no separate weekly-backup "cutoff" to track (unlike PS). Ledger is per-run — capture ids live.

---

## C. Phase 1 — log right-size (PROD, ONLINE, days before the window) — `Phase1_STEAM_LogRightsize.sql`
- [ ] Run the pre-checks: recovery model **SIMPLE**, `log_reuse_wait_desc` = NOTHING/CHECKPOINT, current file sizes.
- [ ] Run the right-size batch. Expected Steam path: **GROW** `Stats_log` ~9.77 GB → 32 GB (PS-validated headroom for the Phase 3 NCI builds + batched tail inserts) — the zero-init happens now, online, NOT mid-window. The shrink path fires only if the log ballooned since assessment (guarded by `log_reuse_wait_desc`, PS-style).
- [ ] Verify: log ~32 GB; on the grow path `Z:` free **drops** ~22 GB (at 2026-08-10 levels: ~91 → ~69 GB — budgeted). While here: check the `Stats` data file FILEGROWTH is a fixed MB step, not percent (the file is near-full at ~3.35 TB — a percent autogrow could overrun `Z:` and fail prod inserts).

> ✅ Script validated on **SQLSTAGING** 2026-08-10: pre-checks SIMPLE/NOTHING, grow path 9.8 → 32.0 GB, verify OK. Boxes above are for the PROD run.

---

## D. MAINTENANCE WINDOW — DOWNTIME (target ~2 h; start the clock here)

### D1. STOP PROD
- [ ] Stop ALL writers (game servers, async/ETL, FishingRate job). Confirm zero connections inserting into Stats.

### D2. Phase 2 — structural swap (PROD) — `Phase2_STEAM_Swap.sql`
- [ ] Run Step 1 (rename, both tables) → Step 2 (drop new+leftover partition objects) → Step 3 (FGs/files August/Sep/Oct) → Step 4 (PF/PS) → Step 5/6 (create partitioned tables). Batch by batch.
- [ ] **Record** the printed `IDENTITY start` for each table → Ledger.
- [ ] Confirm the StatsFact Rank-default line printed (re-created from `*_old`, or "no Rank default to re-create").
- [ ] Run the **verification** block: column-compare query returns **0 rows**; partition layout = **4 partitions** (catch-all / 08 / 09 / 10 filegroups), **all empty** at this point (the August tail loads in Phase 3).
- [ ] If column-compare returns rows → STOP, resolve the schema mismatch before continuing.

### D3. Phase 3 — tail pre-load + NCI (PROD) — `Phase3_STEAM_TailLoad.sql`
- [ ] Run the tail-load batch. It TRUNCATEs the new tables first (idempotent) and **THROWs** if they already hold live rows (safety against an accidental post-START run) or if counts mismatch.
- [ ] Confirm both "Tail verified: ... rows=..." lines printed (no THROW). **Record** MaxOldId per table → Ledger.
- [ ] Run the two NCI-build batches (`(UserId, Timestamp)` aligned, PAGE).
- [ ] Run the sanity SELECT (rows_now / min_ts / max_ts). Phase 3 loads only `Timestamp >= 2026-08-01` (clean August partition, P2); catch-all P1 stays empty.
- [ ] If Phase 3 aborted: fix the cause and **re-run the whole script** (idempotent) — do NOT START PROD on a partial tail.

### D4. START PROD
- [ ] Start the writers. Confirm new inserts land in the new `StatsFact`/`MissionsFact`. **Downtime ends — stop the clock.**

> Rollback up to here is clean: STOP PROD, drop the new tables, `sp_rename *_old → *`, START PROD.

---

## E. Online cleanup (after START — no downtime)

### E1. Phase 6 STEP 1 — gate + DROP (PROD) — **irreversible** — `Phase6_STEAM_Drop_Shrink.sql`
- [ ] **STEP 0 — pre-drop full backup (HARD gate):** take a FRESH online full backup of `Stats` (it still contains `*_old` in full) + `RESTORE VERIFYONLY`; retain >= 2 copies. ~3.2 TB → ensure backup-server space + a few hours. Do NOT run STEP 1 until this is done & verified. **Record** the backup timestamp → Ledger.
- [ ] **Confirm tempdb pre-flight done** (location known; capped if on `Z:`).
- [ ] **Manual gate (a):** confirm aloud the pre-drop backup (STEP 0) is complete, verified, and retained.
- [ ] Run the STEP 1 (gate) batch. It **THROWs and does NOT drop** unless: Phase 3 preload counts match (re-counted in the tail id-range, old vs new, `Timestamp >= 2026-08-01` filter) **AND** `*_old` MAX is unchanged since Phase 3.
- [ ] Confirm "Verification passed (preload complete + *_old unchanged). Old tables dropped." Then run the free-in-file SELECT (expect ~2.5 TB free-in-file).
- [ ] If a THROW fires: **do not retry blindly** — read the message, fix the cause, then re-run.

### E2. Phase 6 STEP 2 — shrink (PROD, ONLINE, HOURS, off-peak) — `Phase6_STEAM_Drop_Shrink.sql`
- [ ] Start a **`Z:` free-space alert** and keep it active for the whole shrink.
- [ ] Run `TRUNCATEONLY`, then the stepped-shrink loop (~50 GB/step, recomputes target, WAITFOR throttle). Expect hours and brief live-insert stalls (Sch-M locks on 2019 Standard) — strictly off-peak. Steam log is ~10 GB (SIMPLE) — lower `@stepMB` if it autogrows.
- [ ] **If the loop prints "Shrink made no progress ..." and stops** → HWM pinned by remaining-table pages:
  1. `ALTER INDEX ALL ON dbo.Stmt REBUILD;` (and FishFact/ActionStats/Balance/TargetedAdFact/... — worst offenders from STEP 3's query) to compact them low.
  2. Re-run the stepped-shrink loop. Repeat until `Z:` free reaches the target (~2.5 TB).
  3. If still stuck, move those tables to a new filegroup and shrink PRIMARY.

### E3. Phase 6 STEP 3 — index maintenance (PROD, in a maintenance downtime)
- [ ] Run the fragmentation query; `ALTER INDEX ALL ON <tbl> REBUILD;` (bare — preserves compression) on the fragmented remaining tables (offline on Standard → do in a downtime).
- [ ] (Optional, once everything is verified) `DROP TABLE dbo.FP44337_TailLoadControl;`.

### E4. Fresh full backup (PROD) — **do not skip**
- [ ] Take a new full backup of `Stats` after the drop + shrink (new small baseline; independent copy of the post-STOP August tail).

---

## F. Deferred (after the cutover — separate days, no rush)
- [ ] **Phase 7 — archive build (ARCHIVE box)** — `Phase7_ARCHIVE_STEAM_BuildAndLoad.sql`. Build the partitioned analyst archive from the **restored STEP 0 pre-drop FULL** (`*_old` = complete source), loading history **< 2026-08-01**; August+ stays on prod and SWITCHes into the archive later as it ages out. Align the archive's monthly boundaries with prod (empty Aug/Sep/Oct landing slots). Keep the backup until the archive is verified.
- [ ] **Phase 8 — sliding-window job (PROD)** — `Phase8_STEAM_SlidingWindowJob.sql`. Confirm Agent running + owner login enabled on STEAMSTATS. Run the dry-run (`@Debug=1`) first, then create the proc + Agent job (28th 02:00 NY-local / ~06:00 UTC trough). After an August cutover the first real add is 28 September (November). Month files start at 1 GB (`@InitSizeMB` default; `Z:` tight) — autogrow is IFI-instant; optionally pass 8192 post-shrink.
- [ ] **Steady-state backup:** adopt read-only aged-FG + partial backup (mark an aged month `READ_ONLY`, back it up once, switch the weekly job to `BACKUP ... READ_WRITE_FILEGROUPS`).
- [ ] **Later:** backfill history from the archive into prod partitions; grow retention.

## G. Rollback quick-reference
- **Before Phase 6 STEP 1 (the DROP):** fully reversible — STOP PROD, drop the new tables, `sp_rename *_old → *` (restore PK/DF names), START PROD. `*_old` data intact.
- **After the DROP:** prod history is gone from prod but preserved as the pre-drop full backup and, once built, the archive; the August+ tail is in the new prod partition. **The post-STOP tail lives ONLY in the live August partition until the fresh full backup (E4) — do NOT skip E4.** Recovery = restore/backfill (not an in-window rollback). This is why the gate must pass cleanly first.
