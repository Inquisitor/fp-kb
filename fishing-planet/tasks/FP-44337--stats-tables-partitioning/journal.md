---
jira: FP-44337
title: Partition StatsFact/MissionsFact and reclaim disk space
status: in-progress
executor: Stanislav Samoilov
created: 2026-06-08
type: project
platforms: [PS, Steam, XB, MOB, NX]
---

## Status

Plan and PS runbook drafted; JIRA FP-44337 created (Story, Highest). Awaiting the PS
maintenance window. Execution by DBA + DevOps; agent on support. Next: confirm pre-flight
measurements (current-month tail rows, delta since backup, IFI enabled, `log_reuse_wait_desc`)
and schedule the window.

## Summary

Prod `Stats` fact tables `StatsFact` / `MissionsFact` grow unbounded and dominate every
platform's Stats DB. Convert both to monthly-partitioned + PAGE-compressed tables (one
filegroup/file per month), offload history to a dedicated archive (SQLARCHIVE), keep ~24 months hot,
and automate monthly roll-off. SQL Server 2019 **Standard**, SIMPLE recovery.

**PS is first and urgent** — its Stats data file is full (3190 GB used / 3190 GB; ~62 GB free
on the volume). Today's full PS backup is preserved twice: file on the backup server + a restored copy on SQLSTAGING.

Key verified facts (2026-06-08): StatsFact 1728 GB / 5.8 B rows; MissionsFact 829 GB / 2 B rows;
both clustered PK on `EntityId` only, no secondary indexes; `EntityId` monotonic with `Timestamp`;
tables write-only at runtime (the one `EntityId`-cursor consumer is `FishingRateStatUpdateJob`).

## Design decisions

- Partition on `Timestamp`, monthly; PK `(EntityId, Timestamp)` PAGE-compressed (leading
  `EntityId` keeps cursor consumers working AND allows date partition elimination); aligned NCI
  `(UserId, Timestamp)`.
- One filegroup/file per month so a drained month's file can be deleted to reclaim OS space.
- Migration via rename + new partitioned table + short-window cutover (no in-place rebuild —
  Standard has no online index rebuild). June tail is pre-loaded **in the window** before START
  (continuity for incremental consumers, esp. `FishingRateStatUpdateJob`); delta/drop/shrink run
  online after restart. Downtime ~24-39 min (baseline + 50% reserve).
- Archive build (Phase 1) is **deferrable** — does not block prod. Drop is lossless when:
  (a) full backup restorable & kept in >= 2 copies, and (b) the June preload is count-verified vs
  `*_old`. Because the preload starts before the backup point (June 1 < June 8 00:45) and runs to
  the last pre-stop row, `{backup} ∪ {new tables}` has no gap — the post-backup tail (which is not
  in the backup) is preserved in the new prod tables. So delta (Phase 4/5, to SQLSTAGING) is for
  archive completeness, **not** a drop blocker. Invariant: keep `@tailFrom` ≤ the backup point.
- PS first cutover keeps only ~1 month hot; backfill 11-12 months from archive later, grow to 24.

## Plan / artifacts

- `artifacts/Runbook_PS_Stats_Partitioning.md` — master PS runbook (phases, scripts, rollback, risks).
- Execution scripts (canonical, corrected, MissionsFact included), run order 1-8:
  - `artifacts/Phase1_PROD_ShrinkLog.sql` — log shrink (PROD, online).
  - `artifacts/Phase2_PROD_Swap.sql` — rename + create partitioned StatsFact & MissionsFact (PROD, downtime).
  - `artifacts/Phase3_PROD_TailLoad.sql` — pre-load June tail + counts to `FP44337_TailLoadControl`, then START (PROD, downtime).
  - `artifacts/Phase4_PROD_DeltaExport.sql` — delta bcp out (PROD, online).
  - `artifacts/Phase5_STAGING_DeltaImport.sql` — delta bcp in + verify, completes restored copy (SQLSTAGING, online).
  - `artifacts/Phase6_PROD_Drop_Shrink.sql` — gated drop (asserts preload via control table), shrink, index maint (PROD, online).
  - `artifacts/Phase7_SQLARCHIVE_BuildAndLoad.sql` — build + load partitioned analyst archive (SQLARCHIVE, deferrable).
  - `artifacts/Phase8_PROD_SlidingWindowJob.sql` — monthly `usp_Fact_AddNextMonth` + Agent job (PROD).
- `artifacts/original-plan/` — raw DevOps-authored materials (reference):
  - `DevOps_Original_Plan.md` — original high-level sequence (superseded by the runbook phasing).
  - `01_Create_Partitioned_Tables_And_Job.sql` — rename, PF/PS/FG, DDL, `usp_..AddNextMonth`, Agent job.
  - `02_Delta_Sync_BCP.sql` — post-backup delta export/import + verification.
  - `03_Drop_Old_Tables_And_Shrink.sql` — drop old tables + `SHRINKFILE`.

> Cross-platform rollout (Steam/XB/MOB/NX) and steady-state (24-month retention, sliding-window
> job) are tracked here but executed after PS is stabilized; a separate adapted runbook per platform.

## Milestones

- 2026-06-08 — Investigated PS prod Stats sizing; chose Timestamp partitioning + per-month files;
  drafted PS runbook; created JIRA FP-44337; consolidated DevOps artifacts into task `artifacts/`.
- 2026-06-08 — Authored per-phase execution scripts (PROD/ARCHIVE split, paths fixed, MissionsFact
  added). Decisions: tail-load moved into the downtime window (Phase 3) for consumer continuity;
  archive build (Phase 7, SQLARCHIVE) deferred — drop gated on backup + preload, not on archive built.
- 2026-06-08 — Renumbered phases to sequential run order 1-8; archive build = Phase 7 on SQLARCHIVE,
  delta import target = SQLSTAGING (Phase 5); added programmatic drop gate (control table + THROW).
- 2026-06-08 — Senior-DBA review + fixes applied: B2 (Phase 5 verify by EntityId range, not Timestamp);
  B5 (seed empty trailing partition — June/July/Aug — so monthly SPLIT never moves data); M4 (build NCI
  in Phase 3 after the tail load); M1 (strict ordinal/type/collation column-match in Phase 2); M6 (Phase 7
  sp_executesql concat fix); B1 (Phase 6 shrink target from measured SpaceUsed*1.15, not a guessed ladder);
  m1 (Phase 1 hard-stop on log_reuse_wait); m5 (bare REBUILD preserves compression); removed `:setvar`.
  Safety model locked to A+B: `@tailFrom` fixed 2026-06-01 + Phase 5 a drop prerequisite (gate a+b+c).
  Team confirmed Q1/Q2/Q3 (Rank, FishingRate cursor, global write-fence); Q4/Q5/Q6 in pre-flight backlog.
- 2026-06-08 — Second review round (verification agent + fresh independent agent). Verification: 9/10
  fixes confirmed; my M1 column-compare had regressed (broken FULL JOIN) — rewrote it to two filtered
  CTEs (N1 fixed). Fresh agent found real hardening, applied: delta boundary reworked to
  `staging MAX(EntityId) - margin` + temp-table import with NOT EXISTS dedup (Phase 4/5, kills the
  Timestamp edge and dup-key risk); Phase 6 shrink made stepped/off-peak/"expect hours"; Phase 1 log
  shrink to 32 GB (headroom for NCI build); Phase 3 NCI build after load; Phase 8 proc gained a
  catch-up loop (2-month buffer) + event-log failure notify. Runbook/backlog updated; window announced
  only after staging measurement. Accepted-with-rationale: explicit DDL (guarded by fixed verify);
  manual gate (a)/(c) with strengthened checklist.
- 2026-06-08 — Third review round (verification + fresh). Verification: all 6 of the round-2 fixes
  confirmed, no regressions. Fresh agent's key find (B1): the load-bearing data-safety gate (SQLSTAGING
  completeness) was a manual checkbox. Reframed + hardened: `{backup} U {SQLSTAGING delta}` is the
  complete copy of `*_old`, so **gate (c) is now enforced** in Phase 6 (operator pastes SQLSTAGING
  MAX(EntityId); script THROWs unless == `*_old` max) + asserts `*_old` unchanged since Phase 3.
  Also applied: Phase 6 shrink recomputes target each step + `WAITFOR` throttle (M2); Phase 5 value
  check automated via CHECKSUM_AGG (M3); Phase 8 proc refuses a non-empty SPLIT (M5); Phase 3 tail
  gets a lower margin for FishingRate continuity (B2, reclassified non-loss); Phase 4 `@stagingMax`
  NULL+THROW (N2); P1 catch-all documented (M4). Downtime window agreed at 2 hours. Team questions
  (Timestamp source, linked-server path, other `*_old` writers, Temp capacity) added to backlog.
- 2026-06-08 — Fourth review round. Verification: round-3 fixes all confirmed, no regressions. Fresh
  agent found a real bug + hardening, applied: Phase 3 mismatch now `THROW`s (was `RAISERROR`, which
  does NOT abort -> could START PROD on a bad tail) [B2]; Phase 3 made idempotent (`TRUNCATE` + `DROP
  INDEX IF EXISTS`) for safe re-run [B1]; Phase 6 gate (c) strengthened with full `COUNT(*)` equality
  `*_old` vs SQLSTAGING (catches a mid-range hole, not just MAX) [B3]; Phase 8 empty-check made exact
  (`IF EXISTS ... Timestamp >= maxBoundary` instead of estimated `sys.partitions.rows`) [M5]; runbook
  Z:-exhaustion warning — do NOT defer Phase 6, Z: alert during shrink [B4]; Phase 2 catch-all comment
  fixed [M1]; Phase 5 cross-server schema-compare note [M3]. Plan: iterate fix->review until a clean
  round, THEN staging rehearsal (user: rehearse once script bugs stop).
- 2026-06-09 — Fifth review round. Verification: round-4 fixes all confirmed. Fresh agent flagged a
  `DECLARE`-in-loop "bug" (B2) — REJECTED as a false alarm (DECLARE-with-initializer re-assigns each
  iteration in T-SQL; pushed back, no change). Applied the real items: removed `NOLOCK` from the Phase 6
  gate `_old` reads (accuracy of the load-bearing check) [B4]; Phase 5 checksum now also covers the
  `[Message]` LOB via `SUM(DATALENGTH)` [M2]; Phase 6 shrink step 200->50 GB (log headroom) [M4]; Phase 8
  step1 `on_fail` 3->2 so the safety THROW surfaces [M5]; Phase 2 `FILEGROWTH` 4->8 GB + size-current-month
  note [B3]; Phase 3 clamps `@jStart` to MIN [N1]; runbook RAISERROR->THROW wording [N2]. Remaining open
  items are pre-flight measurements (compressed size, PAGE-on-partitioned on 15.0.2000.5, Stats_log on Z:),
  which the staging rehearsal answers.
- 2026-06-09 — Applied round-5 review batch. Verification clean (7/7 + the DECLARE-in-loop "bug"
  confirmed a non-issue). Fixes: Phase 6 shrink loop got a no-progress guard (was an infinite-loop
  risk on unmovable high pages) [B2-shrink]; the heavy full `COUNT(*)` of `*_old` moved to a separate
  restartable STEP 0 (records into `FP44337_DropGate`), so the irreversible DROP batch is fast [M5];
  delta export margin 100k -> 10M (gate's COUNT equality is the real guarantee; staging ⊆ *_old) [B1];
  IDENTITY cushion +1000 -> +1,000,000 [M2, cosmetic — collision-proof at any cushion]; runbook now
  states the shrink takes Sch-M locks that can block writers on 2019 Standard [M1] and that the window's
  binding constraint is space not time [M3]. REJECTED with rationale: fresh agent's B1-as-data-loss
  (gate is fail-safe, not silent loss) and the "operator forgets bcp -E" guard (over-engineering, per user).
  Convergence reached: review rounds now yield only polish + overstated blockers -> next step is the
  staging rehearsal (gated on "script bugs stopped").
- 2026-06-09 — Sixth review round. **Both reviewers now say NO BLOCKERS / "ship it"** — convergence.
  Verification 6/6 confirmed. Fresh agent explicitly tried to break the 3 critical paths (drop gate
  completeness, RANGE RIGHT routing, THROW-before-DROP) and they hold. Applied final polish: friendly
  THROW 50018 if STEP 0's `FP44337_DropGate` is missing (was a cryptic 208); Phase 5 `[Message]` now
  validated by a full SHA2_256 `msg_chk` (BINARY_CHECKSUM only hashes first 255 chars of nvarchar(MAX)
  and does NOT error — corrected the wrong comment); Phase 4 documents capturing `@stagingMax` once
  pre-Phase-5 (re-reading after a partial import would move the floor forward). Backlog got the
  remaining pre-flight (tempdb location, native-bcp version match, no hardcoded *_old refs, Message>255,
  PAGE-on-partition test). Static review has converged -> next step is the staging rehearsal.
- 2026-06-09 — External review (Codex / GPT-5) — operational lens, caught real footguns my data-safety
  agents under-weighted. Applied: [#1] runbook self-contradiction fixed (top note said Phase 5 "does not
  block prod / NOT delta imported" while Phase 5 is a drop prerequisite); [#3] Phase 3 refuses TRUNCATE
  if the new table has live rows (EntityId > MAX(old)) — guards against an accidental run after START PROD;
  [#4] Phase 2 made re-runnable (rename guards + drop-new-table-first in Step 2, with a live-row safety
  THROW); [#6] Phase 5 logs the real INSERT rowcount via OUTPUT param (was @@ROWCOUNT after the SET OFF =0).
  [#2] permissions: app login is a role member (db_owner/db_datawriter) per user, so new tables inherit -
  moot, noted in backlog. [#5] job owner sa is the ops account here - comment softened. Codex's own verdict
  matched: staging-rehearsal-ready after #1-#4. Convergence holds; next step is the rehearsal.
