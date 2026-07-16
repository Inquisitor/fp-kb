# STEAM STATS — Partitioning & Space-Reclaim Runbook

> JIRA: FP-44337. Second platform of the cross-platform Stats partitioning effort.
> Derived from the validated **PS runbook** (`../Runbook_PS_Stats_Partitioning.md`); same design,
> adapted to Steam's numbers. Steam is NOT a disk emergency (comfortable headroom) — this is proactive
> reclaim + long-term manageability, run at lower risk than PS.

**Scope:** Steam/EGS production `Stats` database only.
**Tables:** `dbo.StatsFact`, `dbo.MissionsFact`.
**Goal:** Convert both fact tables to monthly-partitioned + PAGE-compressed tables, drop the historical
bulk from prod (preserved as the pre-drop full backup), shrink the data file to reclaim ~2.5 TB, and
enable the monthly sliding-window job.
**Out of scope (later):** backfilling history from archive, growing to 24-month retention, rollout to XB / MOB / NX.

> Execution model: DBA + DevOps run the steps in a Steam maintenance window. This document is the
> agreed plan and script reference; the agent is on support during execution.

## Execution scripts (this folder)

Steam-specific scripts, adapted from the PS set, in run order.

| Phase | Script                                    | Server         | When                                    |
|-------|-------------------------------------------|----------------|-----------------------------------------|
| 1     | *(skipped — log already ~10 GB)*          | —              | —                                       |
| 2     | `Phase2_STEAM_Swap.sql`                   | PROD           | window (downtime)                       |
| 3     | `Phase3_STEAM_TailLoad.sql`               | PROD           | window (downtime), then START PROD      |
| 6     | `Phase6_STEAM_Drop_Shrink.sql`            | PROD           | online, only after the drop gate is met |
| 7     | `Phase7_ARCHIVE_STEAM_BuildAndLoad.sql`   | archive box    | **DEFERRABLE** — later, from the backup |
| 8     | `Phase8_STEAM_SlidingWindowJob.sql`       | PROD           | after cutover                           |

> **Phase 1 (log shrink) is skipped on Steam** — `Stats_log` is already ~10 GB (on PS it was 322 GB and
> the shrink was the first relief). The sequence is 2, 3, 6, 7, 8. Phases 4/5 (SQLSTAGING delta) do not
> exist in this design (removed as redundant on PS — preservation is {pre-drop backup} U {current tail}).

> The only irreversible step is the DROP in Phase 6. Its gate is *preservation verified*: the **STEP 0
> pre-drop full backup** captures `*_old` in full (taken in-window), is restorable & retained (>= 2 copies)
> **+** Phase 3 preload count-verified **+** `*_old` unchanged since Phase 3. The pre-drop full alone makes
> the DROP lossless (every `*_old` row is in it); the July tail on prod is for **continuity**, not
> preservation. Not dependent on EntityId order (only coarsely monotonic on prod — FP-43469 measured this
> on **Steam** prod: ~21.6% row-level skew, 1-2 id boundary interleave — absorbed by the Phase 3 100k-id
> margin). Phase 7 (analyst archive) does **not** block prod — build it later from the backup. **After the
> drop + shrink, take a fresh full backup** as the new small baseline.

---

## Current state (verified 2026-07-06, read-only)

| Fact                     | Value                                                                                                                       |
|--------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| Instance                 | `WIN-3HO01NN5VO4\STEAMSTATS` on `Z:` — SQL Server 2019 **Standard Edition** (15.0.2000.5 RTM)                               |
| Server time zone         | **NY** (local 11:42 / UTC 15:42 = UTC−4 EDT) — same as PS; the Phase 8 02:00-local schedule = ~06:00 UTC trough             |
| Recovery model           | **SIMPLE** (no log backups; DR relies on full backups)                                                                       |
| Data file `Stats` (ROWS) | **3238 GB** (near-full); the two fact tables are **2548 GB** of it (~79%)                                                    |
| Log file `Stats_log`     | **9.77 GB** (already small → Phase 1 skipped)                                                                                |
| Free on `Z:` volume      | **~307 GB** (comfortable — NOT the ~62 GB crisis PS was)                                                                     |
| `StatsFact`              | 1669 GB, ~5.37 B rows, clustered PK on `EntityId` (bigint IDENTITY), **no secondary indexes**                               |
| `MissionsFact`           | 879 GB, ~6.14 B rows, clustered PK on `EntityId`, **no secondary indexes**                                                   |
| `EntityId` ↔ `Timestamp` | **coarsely** monotonic; fine skew per FP-43469 (measured on Steam prod): ~21.6% row-level, 1-2 id interleave at date boundaries (absorbed by Phase 3 Timestamp filter + 100k margin) |
| July tail (at 2026-07-06)| `StatsFact` ~40.4 M rows (id 14,945,287,783 → 14,985,656,189); `MissionsFact` ~26.1 M (id 3,500,490,596 → 3,526,572,528); combined rate ~11 M rows/day |
| Preservation source      | Weekly FULL (SIMPLE). The DROP's safety net is the **Phase 6 STEP 0 pre-drop FULL** (in-window, contains all of `*_old`)     |

**Key facts driving the plan:**
- Standard Edition → online index rebuild and online piecemeal restore are **not** available;
  `DBCC SHRINKFILE` and partitioning / `SWITCH` / `DATA_COMPRESSION = PAGE` **are**.
- These tables are **write-only at runtime** (game servers only `INSERT`); reads are analytics/batch.
  The one ongoing `EntityId`-cursor consumer (`FishingRateStatUpdateJob`) keeps working because the new
  clustered key leads with `EntityId`.
- `DROP TABLE` frees pages **inside** the data file only; only `DBCC SHRINKFILE` returns space to the OS.
  SIMPLE recovery means the (small) log will **not** balloon during the shrink.
- **Cut over early in a month.** The Phase 3 tail = the current-month rows = the window's variable cost
  (~11 M rows/day). Cutting over on the 2nd-3rd of a month = a tiny tail; late in the month = 100 M+ rows.

---

## Target schema (both tables)

- Partition function `pf_<Table>_Timestamp` `RANGE RIGHT` on `DATETIME`, monthly boundaries.
- Partition scheme `ps_<Table>_Timestamp` — **one filegroup + one file per month**
  (`FG_<Table>_YYYY_MM` → `<Table>_YYYY_MM.ndf`), so a drained month's file can be deleted later to return
  OS space without `SHRINKFILE`.
- **Boundaries 2026-07-01 / -08-01 / -09-01 → four partitions** (WORKING ASSUMPTION = July cutover; shift
  if the window lands in another month): an empty `< 2026-07-01` **catch-all** (own small FG), **July** (its
  OWN bounded partition — SWITCH-able when it ages into the archive), **August**, and an empty **September**
  trailing buffer (so the monthly SPLIT in Phase 8 only ever splits an empty partition). The catch-all stays
  empty (Phase 3 loads only `Timestamp >= 2026-07-01`); it is never SWITCHed out.
- PK `PRIMARY KEY CLUSTERED (EntityId, [Timestamp]) WITH (DATA_COMPRESSION = PAGE)` on the scheme.
  - Leading `EntityId` preserves clustered seeks for `WHERE EntityId > @cursor` consumers.
  - Partition elimination on `Timestamp` still works (depends on the partition column, not key order).
- Aligned NCI `(UserId, [Timestamp]) WITH (DATA_COMPRESSION = PAGE)` — **replicated from PS** (Steam's old
  tables have no NCI; this adds one for per-UserId time-range lookups) — built in **Phase 3 after the tail
  load** (cheaper than maintaining it during the bulk insert).
- `EntityId` stays `IDENTITY`; new table seeds at `MAX(old.EntityId) + 1,000,000`.
- StatsFact Rank default is re-created by **capturing the old definition** (robust to any value); MissionsFact
  Rank is NOT NULL with no default (app supplies it).
- Monthly maintenance: generic `usp_Fact_AddNextMonth` + SQL Agent job (28th 02:00 NY-local / ~06:00 UTC trough) — Phase 8.

---

## Phases

### Phase 1 — Log shrink — **SKIPPED on Steam**

`Stats_log` is already 9.77 GB. Nothing to reclaim; skip straight to the window.

### Phase 2 — Structural swap (PROD, DOWNTIME) — `Phase2_STEAM_Swap.sql`

> Metadata-only changes; the bounded tail pre-load is Phase 3 (also in the window).

1. **STOP PROD** — stop the writers so no new rows land during the swap.
2. **Rename** existing objects, both tables: `StatsFact → StatsFact_old` (+ its PK and the Rank default —
   renamed by its **ACTUAL catalog name**); same for `MissionsFact` (no default).
3. **Create** the FGs/files (**catch-all + July + Aug + Sep**), the partition function/scheme (boundaries
   **2026-07-01 / -08-01 / -09-01** → 4 partitions; July is its OWN bounded partition), and the new
   partitioned tables **by structural clone**: `SELECT * INTO … WHERE 1=0` from `*_old`, add the clustered PK
   on the scheme, `DBCC CHECKIDENT RESEED` to `MAX(*_old)+1,000,000`, re-add the StatsFact Rank default
   (captured from `*_old`). Real `Z:\...\MSSQL15.STEAMSTATS\...DATA\` path; months `SIZE=8192MB` (bump the
   current-month `2026_07` file to the measured tail size if cutting over late in the month), catch-all small;
   PAGE; IFI on. Run the column-match verification (must be 0).

### Phase 3 — Tail pre-load + START PROD (PROD, DOWNTIME) — `Phase3_STEAM_TailLoad.sql`

1. **Pre-load the July tail** old → new, with `IDENTITY_INSERT`. The insert filters **`Timestamp >= 2026-07-01`**
   (clean July partition; the id-range margin only sets the scan floor). Done IN the window, before START,
   so incremental consumers see continuous recent history — especially `FishingRateStatUpdateJob` (cursor
   lags ~1h). Records per-table counts in `FP44337_TailLoadControl` for the Phase 6 gate; **`THROW`** on
   mismatch; idempotent on re-run (`TRUNCATE` + `DROP INDEX IF EXISTS`).
   - **`@tailFrom` = 2026-07-01** (current-month 1st) — keeps July clean. Preservation of everything older is
     the Phase 6 STEP 0 pre-drop FULL, not a narrowed tail.
2. **Build the aligned NCI** (both tables, `(UserId, [Timestamp])`) — after the tail load, before START.
3. **START PROD** — writers resume, inserting into the new same-named tables. **Downtime ends here.**

### Phases 4-5 — do not exist (removed on PS as redundant)

Preservation = {pre-drop FULL} U {July tail}, gap-free by Timestamp. No `bcp` / staging delta.

### Phase 6 — Drop + shrink (PROD, online) — **gated** — `Phase6_STEAM_Drop_Shrink.sql`

**Pre-flight (Steam-specific):** confirm where **tempdb** lives — if its data files are on `Z:`, pre-cap
`MAXSIZE` (so a spill can't grow into the shrink headroom) and keep STEP 3 rebuilds as bare `REBUILD`
(`SORT_IN_TEMPDB OFF`, sort hits the data file). If tempdb is on another volume, no action.

**Drop gate (lossless when BOTH hold):**
- (a) **STEP 0 — a FRESH pre-drop full backup** taken after STOP PROD (contains `*_old` in full), proven
  restorable (`RESTORE VERIFYONLY`), retained in **>= 2 copies**. HARD gate, manual. ~3.2 TB online.
- (b) Phase 3 preload **verified complete** AND `*_old` **unchanged since Phase 3** — enforced: re-reads
  `FP44337_TailLoadControl`, re-counts the tail id-range old-vs-new (same `Timestamp >= 2026-07-01` filter),
  checks live `*_old` MAX == recorded MAX; `THROW`s on mismatch.

**After the drop + shrink, take ANOTHER full backup** as the new small baseline.

Then: `DROP TABLE *_old` (deferred-drop, fast) → `SHRINKFILE(TRUNCATEONLY)` (reclaims little) → **stepped**
`SHRINKFILE` (~50 GB/step, target `SpaceUsed*1.15` recomputed each step, `WAITFOR` between steps). **Expect
HOURS; off-peak** — restartable. Then index maintenance on the remaining fragmented tables (Stmt, FishFact,
ActionStats, Balance, TargetedAdFact, …; bare `REBUILD` preserves compression).

> Steam has **comfortable headroom** (307 GB free), so this is NOT the knife-edge PS was — but still run the
> DROP + start the shrink the same day the gate is met (until the shrink returns ~2.5 TB, the file is still
> ~3.2 TB while live inserts autogrow the month files). Keep a `Z:` free-space alert active during the shrink.
> On 2019 Standard the shrink's page moves take **Sch-M locks that can briefly BLOCK live inserts** — strictly
> off-peak, ~50 GB steps. The loop self-stops if a step makes no progress (unmovable high pages).

Expected result: `Stats.mdf` 3238 GB → ~1 TB; `Z:` free 307 GB → ~2.5 TB.

### Phase 7 — Archive build (archive box, **DEFERRABLE**) — `Phase7_ARCHIVE_STEAM_BuildAndLoad.sql`

Build the monthly-partitioned + PAGE-compressed analyst archive and load history **< 2026-07-01** (the
dropped bulk) from the **restored STEP 0 pre-drop FULL** (its `*_old` tables are the complete source). July
and later stay on prod and arrive in the archive later via partition **SWITCH** as they age out — so align the
archive's monthly boundaries with prod's and keep empty `[Jul1,Aug1)`, `[Aug1,Sep1)`, `[Sep1,…)` landing
slots. Build whenever the archive hardware is ready; does not block prod.

### Phase 8 — Sliding-window job (PROD, after cutover) — `Phase8_STEAM_SlidingWindowJob.sql`

Generic `usp_Fact_AddNextMonth` (`@DataPath` = STEAMSTATS) + SQL Agent job (28th 02:00 NY-local / ~06:00 UTC
trough) for both tables. 2-month empty buffer + catch-up; the proc **THROWs** rather than split a non-empty
partition. Pre-flight: Agent running on STEAMSTATS + owner login enabled (default `sa`). After a July cutover
the first real action is **28 August** (adds October).

### Later — steady state (separate doc)

Backfill history from the archive, grow retention, add aged-out-month archiving + the read-only-filegroup /
partial-backup steady state (mark an aged month `READ_ONLY`, back it up once, exclude it from the weekly
partial backup; keep it queryable on prod and drop only when space is needed). **Cross-server caveat:** PROD
and the archive are separate instances → a direct `ALTER TABLE … SWITCH` between them is impossible; the flows
are `SWITCH OUT` locally + transfer (backup/restore or bulk-load) + `SWITCH IN`.

> Note: P1 (`< 2026-07-01`) is an unbounded left catch-all and stays EMPTY. Aged-out-month archiving
> `SWITCH OUT`s from the bounded month partitions (July onward), never P1. July is its own bounded partition
> so it can be switched cleanly.

---

## Downtime estimate (Phases 2 + 3)

Tail size scales with the cutover date (~11 M rows/day). Numbers below assume an **early-month cutover**
(~66 M rows total, close to the 2026-07-06 measurement). A late-month cutover multiplies the tail-load and
NCI-build rows — cut early.

| Step                                                     | Estimate          |
|----------------------------------------------------------|-------------------|
| Stop prod                                                | ~0 (operational)  |
| Rename old objects (both tables)                         | < 1 min           |
| Create PF/PS/FG + 3 small files + tables, clustered PK   | 3-6 min (IFI on)  |
| Pre-load July tail, both tables (~66 M rows, batched)    | 12-18 min         |
| Build aligned NCI on both (after the load)               | 6-12 min          |
| Sanity / verification checks                             | 2-3 min           |
| Start prod                                               | ~0                |
| **Baseline critical path (early-month cutover)**         | **~23-40 min**    |
| **+ 50% reserve**                                        | **~35-60 min**    |

**Suggested maintenance window: 2 hours.** Comfortable margin. (Measure on staging to firm up, and re-measure
the tail the day of cutover to size the July file and the load time.)

> Pre-flight (before the window): re-measure the July tail the day of cutover; confirm IFI enabled and
> `log_reuse_wait_desc = NOTHING`; confirm the tempdb location + cap. `@tailFrom` = current-month 1st.

---

## Rollback

- **Before DROP (Phase 6):** fully reversible. Stop prod, drop the new tables (only the July tail),
  `sp_rename StatsFact_old → StatsFact` (restore PK/DF names), start prod. Old data intact.
- **After DROP:** prod history is gone from prod but preserved as the pre-drop full backup (and, once built,
  the archive); the July+ tail is in the new prod partition. Recovery is restore/backfill — not an in-window
  rollback. **Take a fresh full backup right after the drop + shrink.** Do not run Phase 6 until the gate is met.

## Risk register

| Risk                                                        | Mitigation                                                                                                                                    |
|-------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| New files autogrow eats disk before shrink frees space      | Comfortable headroom (307 GB); small initial files (8 GB); step the Phase 6 shrink; monitor `xp_fixeddrives`                                   |
| tempdb on `Z:` grows into the shrink headroom                | **Confirm tempdb location (pending on Steam)**; if on `Z:`, pre-cap `MAXSIZE`; STEP 3 rebuilds `SORT_IN_TEMPDB OFF`                            |
| PK collision on tail load                                   | New IDENTITY seeds at `MAX(old)+1,000,000`; tail uses `IDENTITY_INSERT` with old ids `< base`                                                  |
| Incremental consumer gap at cutover (FishingRate)           | Phase 3 pre-loads the recent tail BEFORE START so the job's cursor stays continuous                                                            |
| Drop before preservation verified → data loss               | Gate: (a) pre-drop backup >=2 copies manual; (b) enforced — preload counts + `*_old` unchanged. Pre-drop FULL holds all of `*_old`. Fresh backup after |
| Late-month cutover → huge tail → window overrun             | Cut over early in the month (~11 M rows/day); re-measure the tail the day of cutover and size the window/file                                  |
| Z: dips during the multi-hour shrink                        | `Z:` free-space alert during the shrink; size month-file autogrowth; run off-peak                                                             |
| Phase 3 re-run after a partial failure duplicates the tail  | Phase 3 is idempotent: `TRUNCATE` new table + `DROP INDEX IF EXISTS`; mismatch `THROW`s                                                        |
| Stray writer touches `*_old` after STOP PROD                | Gate (b) asserts `*_old` MAX(EntityId) still equals the value recorded in Phase 3                                                             |
| Rank default value/existence differs from PS                | Phase 2 captures the old default's definition and replicates it verbatim (no-op if absent); column-compare surfaces schema drift              |
| Monthly SPLIT moves data (non-empty catch-all)              | 2-month empty buffer (Aug+Sep) + catch-up loop; proc **THROWs** if the split target isn't empty; alert on job failure                          |
| Shrink target wrong / multi-hour grind under live I/O       | Target `SpaceUsed*1.15` **recomputed each step**; stepped ~50 GB/step with `WAITFOR` throttle; off-peak, expect hours                          |
| Shrink fragments remaining tables                           | Phase 6 STEP 3 index maintenance (bare `REBUILD`, preserves compression) — in a maintenance downtime                                           |
| Schema drift new vs old                                     | Strict column-match verification at the end of `Phase2_STEAM_Swap.sql` — must be 0                                                             |
