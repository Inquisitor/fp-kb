# Leaderboards — data model and read path

How leaderboards events are written, where they live, and what each `Get*Leaderboards` query actually costs. Covers the storage layout and read-path mechanics that aren't obvious from individual files.

## Producer entry points

What gameplay events trigger writes:

| Event                                 | Producer site                                                                              | Update calls                                                                                                                            |
|---------------------------------------|--------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| Tournament ends (rated kinds)         | `TournamentEndAdapter` (`Shared/SharedLib/Tournaments/`)                                   | `UpdateCompetitiveLeaderboards(kind, results)`                                                                                          |
| Player catches a fish                 | `GameProcessor.HandleCatchFish` (`Photon/.../GameLogic/`)                                  | `UpdateGlobalLeaderboards` (full increments + `source: template?.Source`) **and** `UpdateFishLeaderboards` (best-weight by pond × fish) |
| Player gains experience without catch | `GameClientPeer_Game.IncrementExperience` (caller passes `updateGlobalLeaderboards: true`) | `UpdateGlobalLeaderboards(experienceIncrement)` only — no `source` arg                                                                  |

### Source filter

Fish-counter increments (`UpdateGlobalLeaderboards` when `totalFishIncrement > 0`) and all `UpdateFishLeaderboards` calls reject the event if its `source` isn't in `FishLeaderboardsAcceptedFishSources`. Source values are fish-generation mechanism codes — full code table in [`fish-generator/fish-fact.md` § Source Codes](../fish-generator/fish-fact.md#source-codes). On prod the accepted set is `B,P` (BiteSystem + Predefines); other generators (Scripted, Mission, Event, etc.) are excluded. Original motivation was FP-40520 ("Mission fish is included to Global Leaderboards") — note the filter operates on the generation source, not gameplay context.

## One event = three UPSERTs

Each `Update{Competitive,Global,Fish}Leaderboards` call writes **one row per `LeaderboardPeriodType` value**, in a single batch — currently Weekly + Monthly + Yearly. The adapter enumerates `LeaderboardPeriodType` to build period descriptors via `new LeaderboardPeriod(periodTypeId, now)`, then the provider does an UPSERT per period via `MERGE ... WHEN MATCHED THEN UPDATE / WHEN NOT MATCHED THEN INSERT` (see `SQL/Patches/Main/Procedures/Update{Type}Leaderboards.sql`).

**Implications:**
- One catch event with `Source ∈ FishLeaderboardsAcceptedFishSources` triggers UPSERTs in **two tables** (`GlobalRatingsCurrent` + `FishRatingsCurrent`), one row per period type per table.
- One tournament finish triggers UPSERTs in `CompetitiveRatingsCurrent`, one row per period type.
- Per-row write cost includes maintaining the per-dimension NC indexes (see § Index alignment below).

## PeriodId encoding

`PeriodId` is the **period's start date encoded as a decimal integer**: `10000·Year + 100·Month + Day` (per `LeaderboardPeriod.GetPeriodId`). Not sequential, not opaque — int chosen for compactness in DB + direct readability when debugging.

The "start date" depends on period type (`LeaderboardPeriod.CurrentPeriodStartDate`):
- Weekly → Monday of the week (`StartOfWeek(DayOfWeek.Monday)`)
- Monthly → 1st of the month
- Yearly → Jan 1 of the year

So `20260427` decodes as Apr 27 2026 (a Monday) for Weekly, `20260501` as May 1 2026 for Monthly, etc. Lets you read PeriodId values directly when debugging (`SELECT DISTINCT PeriodId FROM CompetitiveRatingsCurrent`), without joining to a periods table.

**In C# tests / hardcoded literals:** prefer digit-group separators for readability — `2026_05_01` parses identically to `20260501` and the Y/M/D parts are visible at a glance.

## Storage layout

Three triplets of tables per LB type:

| Purpose                             | Competitive                                       | Global                                       | Fish                                       |
|-------------------------------------|---------------------------------------------------|----------------------------------------------|--------------------------------------------|
| Open period (UPSERT target)         | `CompetitiveRatingsCurrent`                       | `GlobalRatingsCurrent`                       | `FishRatingsCurrent`                       |
| Status state machine                | `CompetitiveLeaderboardStatus`                    | `GlobalLeaderboardStatus`                    | `FishLeaderboardStatus`                    |
| Reward rules (read-only config)     | `CompetitiveLeaderboardRewards`                   | `GlobalLeaderboardRewards`                   | `FishLeaderboardRewards`                   |
| Finalized history (per period type) | `CompetitiveRating{Weekly,Monthly,Yearly}History` | `GlobalRating{Weekly,Monthly,Yearly}History` | `FishRating{Weekly,Monthly,Yearly}History` |

That's **9 history tables total**. Names are built dynamically as `"*Rating" + period.PeriodTypeName + "History"` — so direct grep for the literal name from one period type misses the other eight. When tracing reads, look for `period.PeriodTypeName` interpolation in `Sql{Type}LeaderboardsProvider`.

`PeriodTypeName` is provided by `LeaderboardPeriod.PeriodTypeName` (returns "Weekly" / "Monthly" / "Yearly").

## Index alignment with hot-path queries

`Get*LeaderboardsBetween` and `Get*LeaderboardPlaceForUser` execute:

```sql
SELECT TOP 1 [Place] FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY [PeriodTypeId], [PeriodId]
        ORDER BY [{dim}] DESC, [{dim}Ts] ASC, [{dim}Exp] DESC) AS Place
  FROM {Type}RatingsCurrent WITH (NOLOCK)
  WHERE [IsBanned] = 0 AND [{dim}] > 0 AND [PeriodTypeId] = @x AND [PeriodId] = @y
) l WHERE [UserId] = @userId  -- or [Place] BETWEEN @from AND @to
```

Each `*RatingsCurrent` table has per-dimension covering NC indexes whose key is exactly the ORDER BY:

```
IX_{Type}RatingsCurrent_{Dim} = (PeriodTypeId, PeriodId, {Dim} DESC, {Dim}Ts ASC, {Dim}Exp DESC) INCLUDE UserId
```

- Competitive: one such NC index per value in `CompetitiveLeaderboardDimensionType`
- Global: one such NC index per value in `GlobalLeaderboardDimensionType`
- Fish: a single specialised NC index `(PeriodTypeId, PeriodId, PondId, FishCodeName, Weight DESC, Timestamp, Experience DESC) INCLUDE (UserId, FishId)` covering the per-(pond, fish) seek pattern (no per-dimension indexes — Fish ranks by Weight only)

**Design intent:** the index keys mirror the query's ORDER BY one-to-one, and `UserId` is in INCLUDE. This makes a sort-free plan with seek + forward-scan possible. Whether the optimizer takes this path on a given run depends on stats, parameter sniffing, fragmentation, and current data scale — periodic measurements live in [`tasks/FP-41595--leaderboards-release-support/artifacts/load-projection-2026-04-30.md`](../../tasks/FP-41595--leaderboards-release-support/artifacts/load-projection-2026-04-30.md) § Measured query timings.

## `IsBanned` not in any NC index

`WHERE [IsBanned] = 0` is in the predicate but `IsBanned` is **not** in the key or includes of any NC index — only in the clustered PK row. Under plans that seek through a dim NC index, satisfying the `IsBanned` filter requires a per-row Key Lookup back to the clustered index.

Lookup count under such plans is bounded by the rows the seek returns: small for top-N reads, comparable to period population for full scans (finalize-time `SaveCompetitiveLeaderboardHistory` MERGE source).

**Cheap remediation if it ever surfaces in profiling:** add `IsBanned` to the includes of all dim NC indexes. ALTER-only, no schema migration.

## Per-`Get*Leaderboards` read cost

Three SQL roundtrips per client request:

1. **`Get{Type}LeaderboardPlaceForUser(period, userId)`** — full ROW_NUMBER subquery, top-1 filter to user.
2. **`Get{Type}LeaderboardsBetween(period, fromPlace, toPlace, fromPlace2, toPlace2, userId)`** — same subquery, range filter `[Place] BETWEEN ... OR [Place] BETWEEN ... OR UserId = ...` returns top-100 + (user ± `LeaderboardsSurroundingPlacesBefore/After`) + user's row.
3. **`GetPlayersLeaderboard(@userIds)`** stored procedure — enrichment join: pulls UserName, ExternalId, Level, Rank, Experience, Avatar, Club info from Profiles + Clubs for the ~107 returned UserIds. Called inside `LoadPlayerDataIntoStandings`.

So a single client tab-open in the UI ≈ 3 SQL roundtrips × the number of (kind/dimension/period) views the user clicks through.

`Get{Type}LeaderboardRewards` is **0 SQL roundtrips** — served from `LeaderboardsCache.{Type}LeaderboardRewards.Cache` (in-memory), see `Shared/SharedLib/Config/LeaderboardsCache_*.cs`.

## Client cannot request past periods

Client-facing `Get{Type}Leaderboards` SubOps accept `(kind, dimensionType, periodType)` — period **type** (Weekly/Monthly/Yearly enum), never a `PeriodId`. Server constructs the period from current UTC:

```csharp
// Photon/src-server/Loadbalancing/LoadBalancing/GameServer/GameClientPeer_Leaderboards.cs
var period = new CompetitiveLeaderboardPeriod(kind, dimensionType, periodType, DT.Helper.UtcNow);
```

So historical viewing (e.g. "show me last week's top-100") is not part of the player API. Only the currently-open period of each type is queryable. WebAdmin has separate models (`Stats/Leaderboards/*HistoryModel.cs`) that read History tables directly — that's admin-only, doesn't ride on the player API.

## `TopsCache` vs `LeaderboardsCache` — disambiguation

Two same-named-prefix caches coexist; they cover different features. Don't confuse them:

| Cache class                                                            | Module                                                                                  | Scope                                                                                                 | TTL                      |
|------------------------------------------------------------------------|-----------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|--------------------------|
| `LeaderboardsCache` (`Shared/SharedLib/Config/LeaderboardsCache_*.cs`) | **this module** (period-based Leaderboards)                                             | Reward rules only — `{Comp,Global,Fish}LeaderboardRewards` arrays loaded once via `CachedEntity<T[]>` | None (refresh-on-demand) |
| `TopsCache` (`Shared/SharedLib/Config/TopsCache.cs`)                   | **legacy** `TopsAdapter` feature (`TopPlayers` / `TopFish`, no `LeaderboardPeriodType`) | Top-players and top-fish queries via `DataCache` framework                                            | 4 minutes                |

Standings of the new period-based Leaderboards are **not cached at all** — every `Get*Leaderboards` hits SQL.

## See also

- [`_card.md`](_card.md) — module overview and entry points
- [`control-variables.md`](control-variables.md) — flag semantics
- [`lifecycle-and-jobs.md`](lifecycle-and-jobs.md) — period state machine, jobs, reward delivery channel
- `Dal/Sql.MsSql/Leaderboards/SqlLeaderboardsProvider_{Competitive,Global,Fish}.cs` — exact SQL for every read/write
- `tasks/FP-41595--leaderboards-release-support/artifacts/load-projection-2026-04-30.md` — empirical sizes, projections, validation queries
