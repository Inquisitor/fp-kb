# XB STATS — Partitioning & Space-Reclaim Runbook

> JIRA: FP-44337. Third platform of the cross-platform Stats partitioning effort.
> Derived from the PS + Steam production runs (both live at parity since 2026-08); same design,
> adapted to XB's numbers. XB is NOT a disk emergency — proactive reclaim + parity, run at the
> lowest risk of the three (tiny early-October tail, comfortable headroom, Enterprise edition).

**Scope:** Xbox production `Stats` database only.
**Tables:** `dbo.StatsFact`, `dbo.MissionsFact`.
**Goal:** Convert both fact tables to monthly-partitioned + PAGE-compressed tables, drop the historical
bulk (preserved as the verified pre-drop full backup + a restored copy on the spare), shrink the data
file (~1.5 TB back to C:), and enable the monthly sliding-window job.

> Execution model: DBA + DevOps run the steps; the agent is on support. Operator playbook:
> `Operator_Checklist_XB.md` (step-by-step, ledger, rollback).

## Execution scripts (this folder)

| Phase | Script                                | Server | When                                    |
|-------|---------------------------------------|--------|-----------------------------------------|
| 1     | `Phase1_XB_LogRightsize.sql`          | PROD   | online, before the window               |
| 2     | `Phase2_XB_Swap.sql`                  | PROD   | window (downtime)                       |
| 3     | `Phase3_XB_TailLoad.sql`              | PROD   | window (downtime), then START PROD      |
| 6     | `Phase6_XB_Drop_Shrink.sql`           | PROD   | online, only after the drop gate is met |
| 7     | `Phase7_ARCHIVE_XB_BuildAndLoad.sql`  | spare/archive | **DEFERRABLE** — from the restored pre-drop FULL |
| 8     | `Phase8_XB_SlidingWindowJob.sql`      | PROD   | after cutover                           |

> Phase 1 on XB is a log **shrink** (136 -> 32 GB, PS-style) **plus growth-config fixes** — the log had
> 10% percent growth and the mdf a 1 MB micro-step. Phases 4/5 do not exist in this design.

---

## Current state (verified 2026-09-30, read-only)

| Fact                     | Value                                                                                   |
|--------------------------|------------------------------------------------------------------------------------------|
| Instance                 | `WIN-4J27M0I84AC\XBSTATS` — SQL Server 2019 **ENTERPRISE** (15.0.2000.5)                 |
| Server time zone         | **Pacific** (local 10:06 / UTC 17:06 = UTC-7 PDT) — NOT NY like PS/Steam                 |
| Volume                   | single **C:** (system drive), free **~363 GB**                                           |
| Recovery model           | SIMPLE; `PAGE_VERIFY = CHECKSUM` already; `log_reuse_wait_desc = NOTHING`                |
| Data file `Stats`        | ~2 TB; growth was **1 MB** (fixed by Phase 1 to 2 GB)                                    |
| Log `Stats_log`          | **136.58 GB**, growth was **10%** (Phase 1: shrink to 32 GB + fixed 1 GB step)           |
| `StatsFact`              | 1004 GB, ~3.38 B rows, clustered PK on `EntityId` only, no NCI                           |
| `MissionsFact`           | 598 GB, ~3.84 B rows, clustered PK on `EntityId` only, no NCI                            |
| TDE                      | **NOT on Stats** (`is_encrypted=0`, no DEK/certs) — TDE is Main-only; no plan impact     |
| Backups                  | nightly full 00:20-~01:45 local, ~590 GB compressed, were checksum-less (Phase 1 fixes the default) |
| SQL Agent                | Running but startup **Manual** — set Automatic before Phase 8                            |
| IFI                      | enabled; `sa` enabled                                                                     |

**Enterprise bonus:** STEP 3 index rebuild runs `WITH (ONLINE = ON)` — no downtime (on PS/Steam that
item still waits for a maintenance window).

---

## Target schema (both tables) — identical to PS/Steam

- PF `pf_<Table>_Timestamp` RANGE RIGHT monthly; PS `ps_<Table>_Timestamp`; FG + file per month.
- **Boundaries 2026-10-01 / -11-01 / -12-01** (October cutover assumption): empty `< Oct 1` catch-all,
  **October** (own bounded partition), November, empty December trailing buffer.
- PK `(EntityId, Timestamp)` PAGE-compressed on the scheme; aligned NCI `(UserId, Timestamp)` PAGE
  (built in Phase 3 after the load); `EntityId` IDENTITY reseeded +1M — **and Phase 3 re-applies the
  cushion after its idempotency TRUNCATE** (the Steam finding, fixed in-script).
- StatsFact Rank default re-created by capturing the old definition; MissionsFact.Rank NOT NULL no default.
- Monthly job `usp_Fact_AddNextMonth` + Agent job, **28th 23:00 local Pacific** (= ~06:00 UTC trough).

---

## Phases (deltas only — mechanics are the PS/Steam runbooks')

- **Phase 1 (online, pre-window):** log shrink 136→32 GB (~+105 GB on C:), growth fixes (log 1 GB step,
  mdf 2 GB step), `backup checksum default = 1`, Agent → Automatic.
- **Phase 2+3 (window):** swap + tail load + NCIs. **Early-October tail is tiny (hours of data) — the
  window is minutes.** Slot: **06:05 UTC = 23:05 local (Pacific) on 2026-09-30** — 6 h past the UTC
  month start (`Timestamp` is UTC; the incremental cursor's ~1 h lag must stay inside October — guard
  satisfied) and 75 min before the 07:20 UTC nightly full. Hard rule inside the window: **Phase 2
  Step 3 (`ADD FILE`) done before 07:20 UTC** (file ops serialize vs a running BACKUP, error 3023);
  INSERT / CREATE INDEX / rename do not conflict with it.
- **Phase 6 (online):** STEP 0 = **tonight's 07:20 UTC nightly full** — it starts after START PROD, so
  it holds `*_old` in full (frozen since STOP) and runs WITH CHECKSUM thanks to Phase 1's default; pin
  that file against rotation → **restore-verify on the spare + Ledger
  spot-check** (Steam model = standard) → gate + DROP (frees ~1.6 TB in-file; kills nothing the backup
  does not hold) → stepped shrink off-peak (mdf ~2 TB → ~500 GB, C: → ~1.8-1.9 TB free) → STEP 3
  rebuild **ONLINE** (Enterprise). Baseline = the next checksummed nightly full.
- **Phase 7 (deferred):** archive from the spare's restored copy, history `< 2026-10-01`; landing slots
  Oct/Nov/Dec. Keep the pre-drop backup + restored copy until verified.
- **Phase 8 (after cutover):** dry-run → job (`Monthly_28th_at_23`, 23:00 Pacific) → post-checks via
  **sysjobactivity** (the sysjobschedules cache lags — Steam lesson) → `sp_start_job` smoke.

## Rollback & risks

- Before the DROP: fully reversible (STOP, drop new, `sp_rename *_old → *`, START).
- After the DROP: history = pre-drop FULL + spare's restored copy; recovery = restore/backfill.
- Risk register mirrors Steam's with XB weights: single system C: volume (free-space alert during the
  shrink), tempdb runaway config (pre-size + cap in pre-flight), nightly-backup serialization (window
  timing), UTC month-boundary cursor guard (window timing). No TDE, no disk crisis, tiny tail —
  the lowest-risk run of the three.
