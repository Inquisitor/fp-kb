# PS STATS — Partitioning & Space-Reclaim Runbook

> JIRA: FP-44337. First (most urgent) platform of the cross-platform Stats partitioning effort.

**Scope:** PlayStation (PS) production `Stats` database only — urgent relief.
**Tables:** `dbo.StatsFact`, `dbo.MissionsFact`.
**Goal:** Reclaim disk on the PS Stats volume before it fills, by converting both fact
tables to monthly-partitioned + PAGE-compressed tables, dropping the historical bulk
from prod (preserved as the full backup + the restored copy on SQLSTAGING), and shrinking
the data file.
**Out of scope (later, separate doc):** backfilling 11-12 months from archive, growing
to 24-month retention, rollout to STEAM / XB / MOB / NX.

> Execution model: DBA + DevOps run the steps in the maintenance window. This document
> is the agreed plan and script reference; the agent is on support during execution.

## Execution scripts (this folder)

Canonical, corrected scripts (paths fixed to `Z:`, small initial files, **MissionsFact included**),
in run order. Raw DevOps drafts are kept under `original-plan/` for reference.

| Phase | Script                               | Server     | When                                    |
|-------|--------------------------------------|------------|-----------------------------------------|
| 1     | `Phase1_PROD_ShrinkLog.sql`          | PROD       | before window, online                   |
| 2     | `Phase2_PROD_Swap.sql`               | PROD       | window (downtime)                       |
| 3     | `Phase3_PROD_TailLoad.sql`           | PROD       | window (downtime), then START PROD      |
| 6     | `Phase6_PROD_Drop_Shrink.sql`        | PROD       | online, only after the drop gate is met |
| 7     | `Phase7_SQLARCHIVE_BuildAndLoad.sql` | SQLARCHIVE | **DEFERRABLE** — later, from the backup  |
| 8     | `Phase8_PROD_SlidingWindowJob.sql`   | PROD       | after cutover                           |

> Phase numbers 4 and 5 (the SQLSTAGING delta export/import) were **removed** as redundant — see the
> note below and the journal. The sequence is now 1, 2, 3, 6, 7, 8 (numbers kept to avoid churn).

> The only irreversible step is the DROP in Phase 6. Its gate is *preservation verified*: full backup
> restorable & retained (>= 2 copies) **+** Phase 3 preload count-verified **+** `*_old` unchanged since
> Phase 3. Preservation = **{backup} U {new June tail}** — gap-free because `@tailFrom` (2026-06-01) <=
> the backup point and EntityId is monotonic with Timestamp on prod. No separate "complete SQLSTAGING
> copy" is required: the prod tail already holds the post-backup rows, so the former Phase 4/5
> delta-to-staging was redundant and is removed. Phase 7 (analyst archive on SQLARCHIVE) does **not**
> block prod — build it later from the backup. **After the drop + shrink, take a fresh full backup** so
> the post-backup tail (which until then lives only in the live June partition) has an independent copy.

---

## Current state (verified 2026-06-08, read-only)

| Fact                     | Value                                                                                           |
|--------------------------|-------------------------------------------------------------------------------------------------|
| Instance                 | `MSSQL15.PSSTATS` on `Z:` — SQL Server 2019 **Standard Edition** (15.0.2000.5 RTM)              |
| Recovery model           | **SIMPLE** (no log backups; DR relies on full backups)                                          |
| Data file `Stats` (ROWS) | **3190.7 GB**, used **3190.7 GB**, free-in-file **0 GB** (full)                                 |
| Log file `Stats_log`     | **322 GB** allocated, **2.6 GB** used                                                           |
| Free on `Z:` volume      | **~62.4 GB** (critical)                                                                         |
| `StatsFact`              | 1728 GB, ~5.80 B rows, clustered PK on `EntityId` (bigint IDENTITY), no secondary indexes       |
| `MissionsFact`           | 829 GB, ~1.99 B rows, clustered PK on `EntityId`, no secondary indexes                          |
| `EntityId` ↔ `Timestamp` | monotonic non-decreasing (id 10B→2024-09, 12.0B→2026-01, max→2026-06-08)                        |
| Full backup              | Today's full backup (2026-06-08 ~00:45): file on the backup server + **restored on SQLSTAGING** |

**Key facts driving the plan:**
- Standard Edition → online index rebuild and online piecemeal restore are **not** available;
  `DBCC SHRINKFILE` and table partitioning / `SWITCH` **are** available (all editions since 2016 SP1),
  as is `DATA_COMPRESSION = PAGE`.
- These tables are **write-only at runtime** (game servers only `INSERT`); all reads are analytics
  / batch. The one ongoing `EntityId`-cursor consumer (`FishingRateStatUpdateJob`) keeps working
  because the new clustered key leads with `EntityId` (see Target schema).
- `DROP TABLE` frees pages **inside** the data file only; it does **not** return space to the OS.
  Only `DBCC SHRINKFILE` returns space to the OS. SIMPLE recovery means the log will **not**
  balloon during the shrink.

---

## Target schema (both tables)

Per the DevOps draft (`original-plan/01_Create_Partitioned_Tables_And_Job.sql`), with corrections
baked into `Phase2_PROD_Swap.sql`:

- Partition function `pf_<Table>_Timestamp` `RANGE RIGHT` on `DATETIME`, monthly boundaries.
- Partition scheme `ps_<Table>_Timestamp` — **one filegroup + one file per month**
  (`FG_<Table>_YYYY_MM` → `<Table>_YYYY_MM.ndf`). This is what lets a drained month's file be
  **deleted** later to return OS space without `SHRINKFILE`.
- **Boundaries 2026-06-01 / -07-01 / -08-01 → four partitions:** an empty `< 2026-06-01` **catch-all**
  (its own small FG), **June** (its OWN bounded partition, so it can be SWITCHed OUT cleanly when it
  ages into the archive), **July**, and an empty **August** trailing buffer (so the monthly SPLIT in
  Phase 8 only ever splits an empty partition — no data movement). The catch-all stays empty because
  Phase 3 loads only `Timestamp >= 2026-06-01`; it is never SWITCHed out.
- PK `PRIMARY KEY CLUSTERED (EntityId, [Timestamp]) WITH (DATA_COMPRESSION = PAGE)` on the scheme.
  - Leading `EntityId` preserves clustered seeks for `WHERE EntityId > @cursor` consumers.
  - Partition elimination on `Timestamp` still works (depends on the partition column, not key order).
- Aligned NCI `(UserId, [Timestamp]) WITH (DATA_COMPRESSION = PAGE)` — built in **Phase 3 after the
  tail load** (cheaper than maintaining it during the bulk insert).
- `EntityId` stays `IDENTITY`; new table seeds at `MAX(old.EntityId) + 1,000,000` (any positive cushion is collision-proof since new ids only ascend from the seed and all tail ids are below it; the large value just removes doubt).
- Monthly maintenance: generic `usp_Fact_AddNextMonth` + SQL Agent job (28th 23:00) — Phase 8.

---

## Phases

### Phase 1 — Log shrink (PROD, online, no downtime) — **do this first**

The log is 322 GB on disk but only 2.6 GB used. In SIMPLE recovery this is safe to reclaim now.

```sql
USE [Stats];
-- (the script also hard-stops if log_reuse_wait_desc <> NOTHING/CHECKPOINT)
DBCC SHRINKFILE (N'Stats_log', 32768);  -- ~32 GB: frees ~290 GB, keeps headroom for the Phase 3 NCI build
EXEC xp_fixeddrives;                     -- confirm free space jumped (~62 GB -> ~352 GB)
```

**Outcome:** crisis defused; room created for the new partition files. **No downtime.**
If the log refuses to shrink, check `log_reuse_wait_desc` in `sys.databases` and resolve first.

### Phase 2 — Structural swap (PROD, DOWNTIME)

> Metadata-only changes; the bounded tail pre-load is Phase 3 (also in the window).

1. **STOP PROD** — stop the writers so no new rows land during the swap.
2. **Rename** existing objects (`Phase2_PROD_Swap.sql`), for **both** tables: `StatsFact → StatsFact_old`
   (+ its PK and the Rank default — the default is renamed by its **ACTUAL catalog name**, since prod
   auto-names it `DF__StatsFact__Rank__…`, not the canonical name); same for `MissionsFact` (no default).
3. **Create** the FGs/files (**catch-all + June + July + August**), the partition function/scheme
   (boundaries **2026-06-01 / -07-01 / -08-01** → 4 partitions; June is its OWN bounded partition), and
   the new partitioned tables **by structural clone**: `SELECT * INTO … WHERE 1=0` from `*_old`, then add
   the clustered PK on the scheme, `DBCC CHECKIDENT RESEED` to `MAX(*_old)+1,000,000`, re-add the Rank
   default. Real `Z:` path; small initial files (months `SIZE=8192MB`, catch-all small); PAGE; IFI on.
   Run the column-match verification (sanity — passes by construction since the new table is a clone) — must be 0.

### Phase 3 — Tail pre-load + START PROD (PROD, DOWNTIME)

1. **Pre-load the June tail** (`Phase3_PROD_TailLoad.sql`) old → new, with `IDENTITY_INSERT`
   (old ids `< MAX(old)+1,000,000` → no collision). The insert filters **`Timestamp >= 2026-06-01`**
   (loads only June+ → the June partition is clean and SWITCH-able; the id-range margin only sets the
   scan floor so no June row is missed). Done IN the window, before START, so incremental
   consumers see continuous recent history — especially `FishingRateStatUpdateJob`, whose cursor
   lags ~1h; without this its unprocessed recent rows are stranded in `*_old` and the job skips
   them (gap in fishing-rate stats). Records per-table counts in `FP44337_TailLoadControl` for the
   Phase 6 gate; **`THROW` (aborts the batch)** in-window on mismatch — and idempotent on re-run (`TRUNCATE` + `DROP INDEX IF EXISTS`).
   - **Data-safety invariant:** `@tailFrom` is **fixed at 2026-06-01** — a week of margin before the
     backup point (2026-06-08 00:45) — and **must not be narrowed**: keeping it ≤ the backup point is
     what makes `{backup} ∪ {new tables}` gap-free for the Phase 6 drop.
2. **Build the aligned NCI** (both tables) — after the tail load, before START (cheaper than per-row
   maintenance during the bulk load; offline on Standard, still in-window).
3. **START PROD** — writers resume, inserting into the new same-named tables (no app change).
   **Downtime ends here.**

### Phases 4-5 — REMOVED (were: SQLSTAGING delta export/import)

The former delta-to-SQLSTAGING sync was **redundant** and is removed. Reason: Phase 3 loads the June
tail (from `@tailFrom` = 2026-06-01) into the new prod table, so the **post-backup rows are already
preserved on prod**. With `@tailFrom` <= the backup point and EntityId monotonic with Timestamp,
**{backup} ∪ {new June tail}** already covers every `*_old` row gap-free. The SQLSTAGING delta only
duplicated the post-backup rows. (Independent off-prod copy of those rows is restored by the
post-cutover full backup — see Phase 6.) This also removes the only `bcp` step in the plan.

### Phase 6 — Drop + shrink (PROD, online) — **gated**

`Phase6_PROD_Drop_Shrink.sql`. **Drop gate (lossless when BOTH hold):**
- (a) **STEP 0 — a FRESH pre-drop full backup** taken after STOP PROD (so it contains `*_old` in full,
  incl. the post-backup tail), proven restorable (`RESTORE VERIFYONLY`), retained in **>= 2 copies**.
  HARD gate, manual. This makes the irreversible DROP bulletproof even against an undetected id/time-skew
  edge. ~3.2 TB online backup (backup-server space + a few hours).
- (b) Phase 3 preload **verified complete** AND `*_old` **unchanged since Phase 3** — **enforced**:
  re-reads `FP44337_TailLoadControl`, re-counts the tail id-range old-vs-new (with the same
  `Timestamp >= 2026-06-01` filter as the load), and checks live `*_old` MAX == the recorded MAX;
  `THROW`s on any mismatch. (No SQLSTAGING gate, no full-table count — preservation is {backup} ∪ {prod tail}.)

**After the drop + shrink, take ANOTHER full backup** as the new small baseline (it no longer contains
`*_old`, so it does NOT replace the pre-drop backup for history).

Then: `DROP TABLE *_old` (each its own statement; deferred-drop, fast) → `DBCC SHRINKFILE(N'Stats',
TRUNCATEONLY)` (reclaims little — freed space is interior) → **stepped** `SHRINKFILE` (~50 GB/step,
target recomputed from `SpaceUsed*1.15` each step, `WAITFOR DELAY` between steps to spare live I/O).
**Expect HOURS; run off-peak** — restartable, so step it. Then index maintenance on the remaining
fragmented tables (Stmt, FishFact, …; bare `REBUILD` preserves their compression).

> **Do NOT defer Phase 6.** Run the DROP and begin the shrink the same day the gate is met. Until the
> shrink returns the ~2.5 TB to the OS, the data file is still ~3.2 TB on a near-full `Z:` while live
> inserts autogrow the month files against only ~350 GB free — deferring risks exhausting `Z:` (prod
> outage, the very crisis we're fixing). Keep a `Z:` free-space alert (< 50 GB) active for the whole
> shrink; confirm the 32 GB log absorbs the per-step page-move logging (use smaller steps if it
> autogrows); and confirm `Stats_log` is on `Z:` so Phase 1's reclaim actually helps here. On 2019
> Standard the shrink's page moves take **Sch-M locks that can briefly BLOCK live inserts** (not just
> compete for I/O — `WAIT_AT_LOW_PRIORITY` is 2022+), so it is **not** transparent: strictly off-peak,
> small (~50 GB) steps. The loop self-stops if a step makes no progress (unmovable high pages).

### Phase 7 — Archive build (SQLARCHIVE, **DEFERRABLE**)

`Phase7_SQLARCHIVE_BuildAndLoad.sql` — build the monthly-partitioned + PAGE-compressed analyst archive
on **SQLARCHIVE** and load history **< 2026-06-01** (the dropped bulk) from the **restored backup**
(SQLSTAGING's copy or a fresh restore). June and later stay on prod and arrive in the archive later via
partition **SWITCH** as they age out — so align the archive's monthly RANGE RIGHT boundaries with prod's.
Build it whenever SQLARCHIVE hardware is ready; it does not block prod.

### Phase 8 — Sliding-window job (PROD, after cutover)

`Phase8_PROD_SlidingWindowJob.sql` — generic `usp_Fact_AddNextMonth` + SQL Agent job (28th 23:00) for
both tables. The proc keeps a **2-month buffer of empty future partitions** (Phase 2 seeds July+August
empty) and **catches up** if a run was missed (adds as many months as needed in one pass), so `SPLIT`
always targets an empty partition → metadata-only. If the buffer was **fully depleted** (job down for
months), the proc **refuses** the SPLIT (`THROW`, after an exact `IF EXISTS` emptiness check) rather than silently moving data on a
live multi-TB table — so alert on job failure and split off-peak. The job logs failures to the event
log (wire a mail operator if available) and should be owned by a service account, not `sa`.

### Later — steady state (separate doc, not this window)

Backfill 11-12 months from the archive into prod, grow to 24-month retention, and add aged-out-month
archiving. **Cross-server caveat:** PROD and SQLARCHIVE are separate instances, so a direct
`ALTER TABLE … SWITCH` between them is **impossible** (SWITCH is metadata-only within one DB). The real
flows are: archive→prod backfill = bulk-load/restore into a staging table then `SWITCH IN`; prod→archive
aging = `SWITCH OUT` the aged month locally into a staging table, then transfer (backup/restore or
bulk-load) to the archive and `SWITCH IN` there.

> Note: P1 (`< 2026-06-01`) is an **unbounded left catch-all** and stays EMPTY (Phase 3 loads only
> `Timestamp >= 2026-06-01`). Aged-out-month archiving `SWITCH OUT`s from the **bounded month partitions
> (June onward)**, never P1. June is its own bounded partition specifically so it can be switched cleanly.

---

## Downtime estimate (Phases 2 + 3)

| Step                                                     | Estimate          |
|----------------------------------------------------------|-------------------|
| Stop prod                                                | ~0 (operational)  |
| Rename old objects (both tables)                         | < 1 min           |
| Create PF/PS/FG + 3 small files + tables, clustered PK   | 3-6 min (IFI on)  |
| Pre-load June tail, both tables (~44 M rows, batched)    | 8-12 min          |
| Build aligned NCI on both (after the load)               | 4-8 min           |
| Sanity / verification checks                             | 2-3 min           |
| Start prod                                               | ~0                |
| **Baseline critical path**                               | **~16-26 min**    |
| **+ 50% reserve**                                        | **~24-39 min**    |

**Agreed maintenance window: 2 hours.** Comfortable margin over the ~16-39 min baseline+reserve — absorbs a slower NCI build / tail load with no time pressure. (Still measure on staging to know the real number, but the 2 h budget removes window risk.)

> Pre-flight (before the window, off-peak): measure the June tail row counts AND the per-row insert
> rate on staging to size Phase 3 realistically — PAGE-compressed inserts + the NCI build can exceed
> these estimates; bump the window if measurement says so. Also measure the delta since backup; confirm
> IFI enabled and `log_reuse_wait_desc = NOTHING`. `@tailFrom` stays fixed at 2026-06-01 (do not narrow).
> The binding constraint is **space, not time**: measure the compressed June-tail size + the NCI-build
> peak (tempdb / PRIMARY sort space) on staging and confirm Z: headroom covers it before the window.

---

## Rollback

- **Before DROP (Phase 6):** fully reversible. Stop prod, drop the new tables (only the June tail),
  `sp_rename StatsFact_old → StatsFact` (restore PK/DF names), start prod. Old data intact.
- **After DROP:** prod history is gone from prod but preserved as the full backup (and, once built, the
  archive); the June+ tail is in the new prod partition. Recovery is restore/backfill from those — not an
  in-window rollback. **Take a fresh full backup right after the drop + shrink.** Therefore **do not run
  Phase 6 until the drop gate is met.**

## Risk register

| Risk                                                        | Mitigation                                                                                                                                                                                       |
|-------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| New FG files can't be created (disk)                        | Phase 1 log shrink first (+~290 GB → ~352 free); small initial file sizes (8 GB)                                                                                                                 |
| New files autogrow exhausts disk before shrink frees space  | Phase 1 first; small files; step the Phase 6 shrink; monitor `xp_fixeddrives`                                                                                                                    |
| Wrong file path (template `C:\...` in draft)                | Use real `Z:\...\MSSQL15.PSSTATS\...DATA\`                                                                                                                                                       |
| Log too small for NCI build → mid-window autogrow stall     | Shrink log to ~32 GB (NOT 8); log growth is zero-init (not IFI); SIMPLE bounds steady-state                                                                                                      |
| PK collision on tail load                                   | New IDENTITY seeds at `MAX(old)+1,000,000`; tail uses `IDENTITY_INSERT` with old ids `< base`                                                                                                    |
| Incremental consumer gap at cutover (FishingRate)           | Phase 3 pre-loads the recent tail BEFORE START so the job's cursor stays continuous                                                                                                              |
| Drop before preservation verified → data loss               | Gate: (a) backup >=2 copies manual; (b) enforced — preload counts + `*_old` unchanged. Preservation = {backup} U {prod June tail}, gap-free (`@tailFrom` <= backup point). Fresh full backup after the drop |
| Post-backup rows (backup point..STOP) lost on drop          | They are in the new prod June tail — Phase 3 loads from `@tailFrom` <= backup point, count-verified; the post-drop full backup then gives an independent copy                                     |
| Z: exhausted between DROP and shrink completion → outage    | Don't defer Phase 6; `Z:` alert < 50 GB during the (multi-hour) shrink; size month-file autogrowth; measure insert GB/day                                                                        |
| Phase 3 re-run after a partial failure duplicates the tail  | Phase 3 is idempotent: `TRUNCATE` new table at start + `DROP INDEX IF EXISTS`; mismatch `THROW`s (not `RAISERROR`)                                                                               |
| Stray writer touches `*_old` after STOP PROD                | Gate (b) asserts `*_old` MAX(EntityId) still equals the value recorded in Phase 3                                                                                                                |
| Tail-load start after the backup point → gap → loss         | `@tailFrom` fixed at 2026-06-01 (≤ backup point) — never narrowed                                                                                                                                |
| Pre-June history lives only in the backup until archived    | Keep >= 2 backup copies; build the Phase 7 archive (< 2026-06-01) from the backup; don't discard the backup until the archive is verified                                                        |
| Monthly SPLIT moves data (non-empty catch-all)              | 2-month empty buffer (Jul+Aug) + catch-up loop; proc **THROWs** if the split target isn't empty; alert on job failure                                                                            |
| Shrink target wrong / multi-hour grind under live I/O       | Target `SpaceUsed*1.15` **recomputed each step**; stepped ~50 GB/step with `WAITFOR` throttle; off-peak, expect hours                                                                            |
| Shrink fragments remaining tables                           | Phase 6 index maintenance (bare `REBUILD`, preserves compression)                                                                                                                                |
| Schema drift new vs old                                     | Strict column-match verification at the end of `Phase2_PROD_Swap.sql` — must be 0                                                                                                                |

## Referenced DevOps artifacts (in `original-plan/`)

- `original-plan/01_Create_Partitioned_Tables_And_Job.sql` — rename, PF/PS/FG, new table DDL, `usp_..AddNextMonth`, Agent job.
- `original-plan/02_Delta_Sync_BCP.sql` — original delta export/import (was Phases 4/5; **REMOVED** as redundant — preservation is {backup} U {prod tail}).
- `original-plan/03_Drop_Old_Tables_And_Shrink.sql` — drop old + `SHRINKFILE` (now Phase 6).
- `original-plan/DevOps_Original_Plan.md` — original high-level sequence (superseded by the phasing here).
