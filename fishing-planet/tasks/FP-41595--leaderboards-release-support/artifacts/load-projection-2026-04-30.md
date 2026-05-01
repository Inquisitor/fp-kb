# Leaderboards DB load — baseline & projection (Steam PROD)

**Date:** 2026-04-30
**Scope:** Steam PROD MAIN database (`SQL2019STEAM\SQL2019STEAM`). Server-side caching layout, query cost, table sizes,
and growth projection for the new Leaderboards subsystem (`{Competitive,Global,Fish}RatingsCurrent` + History).
**Why:** Steam PROD ran Update-only flags Apr 29-30 UTC for 36h as a write-pipeline pre-flight; user planned `TRUNCATE`
of all 3 `RatingsCurrent` tables at 2026-05-01 00:00 UTC for a clean monthly start. This artifact captures the empirical
baseline and projection so we can validate ~1 week later (target 2026-05-08).

## TL;DR

- **No server-side cache for standings** — only reward rules cached (`LeaderboardsCache.{Type}LeaderboardRewards` via
  `CachedEntity<T[]>`). `TopsCache` (`DataCache`, 4-min TTL) is for the legacy `TopsAdapter.GetPlayerTops`/`GetFishTops`
  feature, **not** the new period-based Leaderboards.
- **Real query cost is small** thanks to per-dimension covering indexes that exactly match
  `ROW_NUMBER OVER ... ORDER BY` clause + SQL Server TOP-N optimization. Top-110 standings = <1 ms on 30k Global rows;
  place-for-user = <1 ms.
- **Disk growth dominated by Fish History** (~5 GB / year), then Global History (~2.3 GB / year). `*RatingsCurrent` is
  bounded by period (steady-state ~815 MB on Steam after 1 year).

## Empirical baseline (36h sample, pre-TRUNCATE)

Window: `2026-04-29 10:55 UTC → 2026-04-30 23:04:59 UTC` (~36 h 10 min)
Mode: `IsLeaderboardsOn=N`, all UI/Jobs/Rewards = `N`, only **Update flags = Y** for Competitive/Global/Fish on Steam
PROD only (other prod streams empty).

### Row counts in `*RatingsCurrent` (per period × 3 = total)

| Table                       | Per period | Total (×3 periods) |                      Unique users |
|-----------------------------|-----------:|-------------------:|----------------------------------:|
| `CompetitiveRatingsCurrent` |      1,013 |              3,039 |                             1,013 |
| `GlobalRatingsCurrent`      |     29,701 |             89,103 |                            29,701 |
| `FishRatingsCurrent`        |    233,732 |            701,196 | ≈29,701 × 7.7 (pond, fish) combos |

PeriodIds observed:

- Weekly = `20260427` (week of Apr 27 - May 3)
- Monthly = `20260401` (April 2026)
- Yearly = `20260101` (year 2026)

### Disk footprint

| Table                       |        Total | Data | NC indexes |                                                    bytes / row |
|-----------------------------|-------------:|-----:|-----------:|---------------------------------------------------------------:|
| `FishRatingsCurrent`        | **167.0 MB** | 86.9 |       79.2 |                                                           ~250 |
| `GlobalRatingsCurrent`      |  **72.0 MB** | 23.0 |       48.5 | **~830** (6 dim NC indexes dominate — 67% of total table size) |
| `CompetitiveRatingsCurrent` |   **1.0 MB** |  0.5 |        0.4 |                                                           ~330 |
| All History tables (×9)     |            0 |    — |          — |                                                              — |
| All Status tables (×3)      |            0 |    — |          — |                                                              — |
| Reward rules (×3)           |      ~0.4 MB |    — |          — |                                                              — |

**Total writeable footprint after 36h: ~240 MB on Steam.**

History/Status remained empty because Jobs flags = `N` throughout the window — no rotation, no finalization, no cleanup
ran.

## Architectural observations

### Server-side caching

| Layer                                                                          | What it caches                                                                    | TTL                                             | DB hit per `Get*` call                                                             |
|--------------------------------------------------------------------------------|-----------------------------------------------------------------------------------|-------------------------------------------------|------------------------------------------------------------------------------------|
| `LeaderboardsCache.{Comp,Global,Fish}LeaderboardRewards` (`CachedEntity<T[]>`) | Full reward-rule tables                                                           | None (refresh-on-demand via `Caches` framework) | **0** for `Get*Rewards` and `DistributeLeaderboardRewards`                         |
| `LeaderboardsAdapter` static fields                                            | Subsystem flags only (push-from-`EnvironmentVariableCache.UpdateStaticVariables`) | Refreshed on EV cache refresh                   | —                                                                                  |
| **No layer**                                                                   | Standings (top-N, place-for-user, surrounding)                                    | —                                               | **3 SQL roundtrips per call** (place + range + `GetPlayersLeaderboard` enrichment) |

### Index alignment with hot-path query

`Get*LeaderboardsBetween` issues a
`ROW_NUMBER OVER (PARTITION BY PeriodTypeId, PeriodId ORDER BY {dim} DESC, {dim}Ts ASC, {dim}Exp DESC)` ranked subquery,
then outer `WHERE Place BETWEEN @from AND @to`. Each table has covering NC indexes whose key is exactly
`(PeriodTypeId, PeriodId, {dim} DESC, {dim}Ts ASC, {dim}Exp DESC)` INCLUDE `UserId`. Result: SQL Server TOP-N
optimization triggers, scan stops at ~top-N + Key Lookups for `IsBanned` (which is **not in any index**) limited to
top-N rows.

Fish has the most efficient layout: single NC index
`(PeriodTypeId, PeriodId, PondId, FishCodeName, Weight DESC, Timestamp, Experience DESC)` INCLUDE `(UserId, FishId)`
covers the per-(pond, fish) seek pattern entirely.

### Measured query timings on Steam PROD (current data)

| Query                                                       |                             Population |                                                                                         Elapsed |
|-------------------------------------------------------------|---------------------------------------:|------------------------------------------------------------------------------------------------:|
| Global top-110 by Experience (Monthly)                      |                          29,701 ranked |                                                                                       **<1 ms** |
| Global place-for-user (full ranking inner)                  |                                 29,701 |                                                                                       **<1 ms** |
| Competitive top-110 by Rating (Monthly)                     |                                  1,013 |                                                                                       **<1 ms** |
| Fish top-110 (most-popular pond+fish: PondId=119, WCrappie) | 233,732 (small partition by pond×fish) | ~125 ms (95% of which is preliminary `GROUP BY` to find most-pop combo, not the top-110 itself) |

### Concerns

1. **Global write amplification**: 6 dim NC indexes maintained on every Update event. With ~22k DAU and current event
   rate, write latency is fine, but a 5× growth in event-rate is the inflection point.
2. **`IsBanned` not covered**: low practical impact (Key Lookups bounded by top-N), but if banned-rate grows or
   population × dim-fan-out increases, could become visible. Easy fix: add `IsBanned` to the includes of all dim NC
   indexes.
3. **Fish History grows largest**: ~5 GB / year if all weekly/monthly/yearly snapshots retained.

## Projection assumptions

Extrapolated from 36h sample (29,701 Global unique users) using typical MMO active-user ratios:

| Metric                         |              Estimate | Derivation                                                |
|--------------------------------|----------------------:|-----------------------------------------------------------|
| DAU                            |                  ~22k | 29.7k / 1.5 (saturation factor for 1.5-day-active sample) |
| WAU                            |                  ~40k | 1.8 × DAU                                                 |
| MAU                            |                  ~75k | 3.4 × DAU                                                 |
| YAU                            |                 ~180k | 8 × DAU (with churn)                                      |
| Fish diversity per user        |            7.7 combos | factual: 233,732 rows / 29,701 users                      |
| Competitive participation rate | 3.4% of Global active | factual: 1,013 / 29,701                                   |

> Plug-in target: replace these multipliers with real Steam DAU/WAU/MAU when validated 2026-05-08.

## Projection — `*RatingsCurrent` size at horizon

`*RatingsCurrent` is **bounded by period** (one row per user per active bucket; UPSERT semantics). Steady-state size =
`WAU + MAU + YAU` user-rows × 3 tables. After horizon T:

| Horizon |         Weekly bucket |     Monthly bucket |      Yearly bucket | Global rows | Global MB | Fish rows | Fish MB | Comp rows | Comp MB |
|---------|----------------------:|-------------------:|-------------------:|------------:|----------:|----------:|--------:|----------:|--------:|
| 1 week  |              ~WAU=40k | ~WAU=40k (filling) |           ~WAU=40k |       ~120k |      ~100 |     ~924k |    ~230 |       ~4k |    ~1.3 |
| 1 month | ~WAU=40k (rotates 4×) |           ~MAU=75k |           ~MAU=75k |       ~190k |      ~155 |    ~1.46M |    ~365 |     ~6.5k |    ~2.1 |
| 1 year  |              ~WAU=40k |           ~MAU=75k | ~YAU=180k (steady) |       ~295k |      ~245 |    ~2.27M |    ~565 |      ~10k |    ~3.3 |

After 1 year all 3 buckets at steady state; further time does not grow `*RatingsCurrent`.

## Projection — `*RatingHistory` cumulative growth

History tables grow linearly with finalized periods. Per single Weekly/Monthly/Yearly snapshot:

| Type        |                            Per Weekly snapshot | Per Monthly | Per Yearly |
|-------------|-----------------------------------------------:|------------:|-----------:|
| Competitive | WAU × 2 kinds × 3 dims × 0.5 fill = ~120k rows |       ~225k |      ~540k |
| Global      |           WAU × 6 dims × 0.8 fill = ~192k rows |       ~360k |      ~864k |
| Fish        |                  WAU × 7.7 combos = ~308k rows |       ~578k |     ~1.39M |

Cumulative after 1 year (52 weekly + 12 monthly + 1 yearly finalizations):

| Type        | Total rows | bytes/row |         History MB |
|-------------|-----------:|----------:|-------------------:|
| Competitive |      ~9.2M |       150 |            ~1.4 GB |
| Global      |     ~15.2M |       150 |            ~2.3 GB |
| Fish        |     ~24.4M |       200 |            ~4.9 GB |
| **Total**   |   **~49M** |           | **~8.6 GB / year** |

## Combined disk projection

| Horizon             | `*RatingsCurrent` |                   `*RatingHistory` |   Total |
|---------------------|------------------:|-----------------------------------:|--------:|
| Now (post-TRUNCATE) |              0 MB |                               0 MB |    0 MB |
| 1 week              |           ~330 MB | ~50 MB (1 partial weekly snapshot) | ~380 MB |
| 1 month             |           ~520 MB |     ~280 MB (4 weekly + 1 monthly) | ~800 MB |
| 1 year              |           ~815 MB |                            ~8.6 GB | ~9.4 GB |

## Validation protocol (re-check 2026-05-08)

Run the following on Steam PROD MAIN to compare against projection:

### Row counts and date ranges

```sql
-- Per-period row counts and timestamp range
SELECT 'Competitive'            AS T,
       PeriodTypeId,
       PeriodId,
       COUNT(*)                 AS Rows,
       MIN(CompetitionRatingTs) AS MinTs,
       MAX(CompetitionRatingTs) AS MaxTs
FROM CompetitiveRatingsCurrent WITH (NOLOCK)
GROUP BY PeriodTypeId, PeriodId
UNION ALL
SELECT 'Global',
       PeriodTypeId,
       PeriodId,
       COUNT(*),
       MIN(ExperienceTs),
       MAX(ExperienceTs)
FROM GlobalRatingsCurrent WITH (NOLOCK)
GROUP BY PeriodTypeId, PeriodId
UNION ALL
SELECT 'Fish',
       PeriodTypeId,
       PeriodId,
       COUNT(*),
       MIN([Timestamp]),
       MAX([Timestamp])
FROM FishRatingsCurrent WITH (NOLOCK)
GROUP BY PeriodTypeId, PeriodId
ORDER BY T, PeriodTypeId, PeriodId;
```

### Disk footprint

```sql
SELECT t.name                                                                   AS TableName,
       SUM(CASE WHEN i.index_id < 2 THEN p.rows ELSE 0 END)                     AS Rows,
       SUM(a.total_pages) * 8 / 1024.0                                          AS TotalMB,
       SUM(CASE WHEN i.index_id < 2 THEN a.data_pages ELSE 0 END) * 8 / 1024.0  AS DataMB,
       SUM(CASE WHEN i.index_id >= 2 THEN a.used_pages ELSE 0 END) * 8 / 1024.0 AS NCIndexMB
FROM sys.tables t WITH (NOLOCK)
         JOIN sys.indexes i WITH (NOLOCK) ON i.object_id = t.object_id
         JOIN sys.partitions p WITH (NOLOCK) ON p.object_id = i.object_id AND p.index_id = i.index_id
         JOIN sys.allocation_units a WITH (NOLOCK) ON a.container_id = p.partition_id
WHERE t.name IN ('CompetitiveRatingsCurrent', 'GlobalRatingsCurrent', 'FishRatingsCurrent',
                 'CompetitiveRatingWeeklyHistory', 'CompetitiveRatingMonthlyHistory', 'CompetitiveRatingYearlyHistory',
                 'GlobalRatingWeeklyHistory', 'GlobalRatingMonthlyHistory', 'GlobalRatingYearlyHistory',
                 'FishRatingWeeklyHistory', 'FishRatingMonthlyHistory', 'FishRatingYearlyHistory',
                 'CompetitiveLeaderboardStatus', 'GlobalLeaderboardStatus', 'FishLeaderboardStatus')
GROUP BY t.name
ORDER BY TotalMB DESC;
```

### Comparison points to record

- **Actual unique users in Yearly bucket** vs projected (proxy for YAU)
- **Actual Fish row count / Global row count** ratio vs projected 7.7 diversity factor
- **Actual Competitive row count / Global row count** ratio vs projected 3.4%
- **Per-row size deltas** (esp. Global vs projected ~830 b/row) — write amplification can shift if row gets wider
- **Whether Jobs ran** (Status table populated, History rows present): if yes, validate first finalization ran cleanly

### Failure modes to watch for

- **Global NC index size grows non-linearly**: signals write skew (one period bucket disproportionately larger than
  others)
- **Fish row count grows >10× expected**: indicates user diversity (more pond/fish exploration than baseline)
- **History rows present but Status table doesn't reflect**: indicates Jobs ran partially / with errors
- **Top-110 query latency >10ms**: signals plan regression (e.g. Key Lookup expansion if banned-rate spikes); run actual
  EXPLAIN to confirm

## Snapshot + TRUNCATE script (executed at ~2026-05-01 00:00 UTC)

Pre-flight `TRUNCATE` is preceded by a `SELECT INTO` snapshot so the 36h write-window data remains queryable for
post-mortem reference. Snapshot tables: same name + `_Backup_20260430` suffix, in the same database and schema.

```sql
-- 1. Snapshot to *_Backup_20260430 tables (heap, no PK/indexes — read-only reference)
SELECT *
INTO [CompetitiveRatingsCurrent_Backup_20260430]
FROM [CompetitiveRatingsCurrent] WITH (NOLOCK);
SELECT *
INTO [GlobalRatingsCurrent_Backup_20260430]
FROM [GlobalRatingsCurrent] WITH (NOLOCK);
SELECT *
INTO [FishRatingsCurrent_Backup_20260430]
FROM [FishRatingsCurrent] WITH (NOLOCK);

-- 2. Verify backup row counts match originals (must equal: 3039 / 89103 / 701196)
SELECT 'Comp_orig' AS T, COUNT(*) AS Rows
FROM [CompetitiveRatingsCurrent] WITH (NOLOCK)
UNION ALL
SELECT 'Comp_bak', COUNT(*)
FROM [CompetitiveRatingsCurrent_Backup_20260430] WITH (NOLOCK)
UNION ALL
SELECT 'Global_orig', COUNT(*)
FROM [GlobalRatingsCurrent] WITH (NOLOCK)
UNION ALL
SELECT 'Global_bak', COUNT(*)
FROM [GlobalRatingsCurrent_Backup_20260430] WITH (NOLOCK)
UNION ALL
SELECT 'Fish_orig', COUNT(*)
FROM [FishRatingsCurrent] WITH (NOLOCK)
UNION ALL
SELECT 'Fish_bak', COUNT(*)
FROM [FishRatingsCurrent_Backup_20260430] WITH (NOLOCK);

-- 3. After verification: truncate originals
-- Pre-conditions verified: 0 FK constraints, 0 triggers, 0 rows in History/Status
TRUNCATE TABLE [CompetitiveRatingsCurrent];
TRUNCATE TABLE [GlobalRatingsCurrent];
TRUNCATE TABLE [FishRatingsCurrent];
```

Reward-rule tables (`*LeaderboardRewards`) and `LeaderboardsCache` static fields are not touched — they hold deployed
configs that should persist.

**Note on snapshot tables:** `SELECT INTO` creates heap tables (no PK, no indexes). They take ~240 MB extra space until
dropped. Suitable for analytical reference (full-table scan, ad-hoc joins). If specific row lookup performance matters
later, add a covering NC index on the same key as the original PK. Drop with `DROP TABLE [..._Backup_20260430]` once no
longer needed.

## References

- Module documentation: [
  `<kb>/fishing-planet/server/modules/leaderboards/_card.md`](../../../server/modules/leaderboards/_card.md), [control-variables](../../../server/modules/leaderboards/control-variables.md)
- Source code path: `Shared/SharedLib/Leaderboards/`, `Dal/Sql.MsSql/Leaderboards/`, `AsyncProcessor/Jobs/Leaderboards/`
- JIRA: [FP-41595](https://fishingplanet.atlassian.net/browse/FP-41595)
