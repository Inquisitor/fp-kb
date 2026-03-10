# FishFact — Fish Generation Statistics

> Parent: [Fish Generator card](_card.md)

## Overview

`FishFact` is a lifecycle table in the `Stats` database that records every generated fish and tracks its progression through the fishing session. Unlike historical catch-based stats, it captures **all** fish — including those that never bit or escaped.

**Feature flag:** `EnvironmentVariableCache.CollectFishGenerationStats` — if false, nothing is written.
**Cleanup:** `Cleanup(horizon, batchSize)` deletes old records — data retention is not permanent.

## Schema

DB: `Stats`, Table: `dbo.FishFact`

### Fields written at generation (`SaveFishGenerated`)

| Field                          | Type                | Description                                                  |
|--------------------------------|---------------------|--------------------------------------------------------------|
| `Id`                           | uniqueidentifier PK | `fish.InstanceId`                                            |
| `PondId`                       | int                 | Pond where fish was generated                                |
| `FishId`                       | int                 | **Form-specific ID** (e.g., 4550=NilePerchY, 4560=NilePerch) |
| `Source`                       | char(1)             | Generation path code (see Source Codes below)                |
| `Weight`                       | decimal(19,3)       | Generated weight                                             |
| `GeneratedAt`                  | datetime            | UTC timestamp                                                |
| `PondTimeSeconds`              | int                 | In-game pond time                                            |
| `Weather`                      | varchar(30)         | Weather at generation                                        |
| `UserId`                       | uniqueidentifier    | Player                                                       |
| `Level`                        | int                 | Player level                                                 |
| `Slot`                         | int                 | Rod slot                                                     |
| `RodTemplate`                  | int                 | Rod template enum                                            |
| `RodId`                        | int                 | Rod item ID                                                  |
| `RodType`                      | smallint            | Rod subtype                                                  |
| `ReelId`, `LineId`, `LeaderId` | int                 | Tackle                                                       |
| `BaitOrLureId`                 | int                 | Bait/lure used                                               |
| `GenerateDistance`             | float               | Distance from player                                         |
| `HookSize`                     | float               | Hook size at generation                                      |
| `IsTrolling`, `IsFt`           | bit                 | Trolling / Fishing Together flags                            |
| `DragStyle`                    | tinyint             | Drag style enum                                              |
| `BoatType`, `BoatId`           | smallint, int       | Boat info                                                    |
| `GeneratedLocationX/Y/Z`       | decimal(19,3)       | 3D position                                                  |

### Lifecycle update fields

| Event        | Method                   | Fields updated                                                                       |
|--------------|--------------------------|--------------------------------------------------------------------------------------|
| Not hooked   | `SaveFishGone`           | `GoneAt`, `IsStriking`, `IsWrongStriking`, `FinishAttackSeconds`, `GoneReason`       |
| Hooked       | `SaveFishHooked`         | `HookedAt`, `HookedDistance`, `IsStriking`, `IsWrongStriking`, `FinishAttackSeconds` |
| Escaped      | `SaveFishEscaped`        | `EscapedAt`, `EscapedDistance`, `EscapedReason`, `FishFightDurationSeconds`          |
| Tackle break | `SaveEquipmentBroken`    | `BrokenAt`, `FishFightDurationSeconds`                                               |
| Caught       | `SaveFishCaught`         | `CaughtAt`, `FishFightDurationSeconds`, `Exp`, `Silver`                              |
| Interrupted  | `SaveFishingInterrupted` | `InterruptedAt`, `FishFightDurationSeconds`                                          |

## Source Codes

Defined in `FishGenerator.cs` (lines 26-36):

| Code  | Constant                 | Generation Path               | Weight Method                                         | Notes                       |
|-------|--------------------------|-------------------------------|-------------------------------------------------------|-----------------------------|
| **B** | `BiteSystemSource`       | `PondServer.GetFish()`        | `GenerateRandomWeight()` → `GetPossibleNormalFloat()` | **Primary production path** |
| X     | `FishBoxSource`          | FishBox selection             | `GameUtils.RandomizeFishWeight()`                     | Legacy, missions only       |
| W     | `PondWideSource`         | No FishBox available          | `GameUtils.RandomizeFishWeight()`                     | Legacy fallback             |
| C     | `ActiveCarouselSource`   | FishGenerator active carousel | `GameUtils.RandomizeFishWeight()`                     | Legacy, not BiteSystem      |
| A     | `AbsoluteCarouselSource` | FishGenerator abs. carousel   | `GameUtils.RandomizeFishWeight()`                     | Legacy, not BiteSystem      |
| M     | `MissionFishBoxSource`   | Mission FishBox               | `GameUtils.RandomizeFishWeight()`                     | Missions                    |
| S     | `ScriptedSource`         | Scripted fish                 | `RandomizeFishWeight` / `SetFishToGenerate`           |                             |
| E     | `EventSource`            | Event fish                    | Pre-set weight                                        |                             |
| P     | `PredefinesSource`       | Tutorial/predefined           | Hardcoded range                                       |                             |
| D     | `DebugSource`            | Debug                         | Debug weight                                          | Excluded from analytics     |

## Key Queries (existing)

### `GetFishWeightDistributionStats` — histogram by weight buckets

Groups by `PondId, FishId, CAST(Weight / @WeightStep AS int) * @WeightStep`. **Filters `Source = 'B'` only** (BiteSystem). Returns per-bucket: GeneratedCount, HookedCount, CaughtCount, BrokenCount, InterruptedCount, MedianFightDuration, TotalExp, TotalSilver.

Parameters: startDate, endDate, fishIds (TVP), pondId, minLevel, maxLevel, minWeight, maxWeight, weightStep.

### `GetFishFacts` — raw data

Returns all fields. No source filter. Same date/fish/pond/level/weight filters.

## Code Path

```
GameProcessor (GameLogic/GameProcessor.cs:3508)
  └─ FishStatsAdapter.SaveFishGenerated(fish, template.Source, config, ...)
       └─ IFishStatsProvider.SaveFishGenerated(...)  [if isEnabled]
            └─ SqlFishStatsProvider: INSERT INTO FishFact

GameProcessor (various lifecycle events)
  └─ FishStatsAdapter.SaveFishGone / SaveFishHooked / SaveFishEscaped / SaveFishCaught / ...
       └─ SqlFishStatsProvider: UPDATE FishFact SET ... WHERE Id = @id
```

## Files

| File | Role |
|------|------|
| `SQL/Patches/KNW.S.2025.08.06-001.sql` | Initial CREATE TABLE |
| `SQL/Patches/KNW.S.2025.08.12-002.sql` | Added BaitOrLureId, RodTemplate, IsStriking, IsWrongStriking, FinishAttackSeconds |
| `SQL/Patches/KNW.S.2025.09.17-005.sql` | Column reorder (recreate table) |
| `SQL/Patches/KNW.S.2025.11.27-007 [FishFactStats].sql` | Added IsTrolling, IsFt, DragStyle, BoatType, BoatId, HookSize |
| `SQL/Patches/LBM.S.2025.12.12-002 [FishFactStats].sql` | Added GeneratedLocationX/Y/Z |
| `SQL/Patches/LBM.S.2025.12.16-003 [FishFactStats].sql` | Added GoneReason |
| `SQL/Patches/LBM.S.2025.12.31-008 [FishFactStats].sql` | Added RodType |
| `Photon/src-server/GameModel/Stats/FishStatsAdapter.cs` | Adapter: Fish → IFishStatsProvider calls |
| `Dal/Sql.Interface/Stats/IFishStatsProvider.cs` | Interface with all Save*/Get* methods |
| `Dal/Sql.Interface/Stats/FishFactDto.cs` | DTO for raw FishFact rows |
| `Dal/Sql.MsSql/Stats/SqlFishStatsProvider.cs` | SQL implementation |
| `WebAdmin/WebAdmin/Models/Stats/FishCatch/FishWeightDistributionStatsModel.cs` | WebAdmin model + query orchestration |

## WebAdmin Integration

`FishWeightDistributionStatsModel` provides two views:
- **Stats view** (`GetStatsData`) — calls `GetFishWeightDistributionStats`, returns bucketed histogram
- **Raw view** (`GetRawData`) — calls `GetFishFacts`, returns individual records

Supports filtering by: FishParentCategory, FishCategory, FishId, FishForm, Pond, Level range, Weight range, WeightStep.

## Key Observations

1. **FishId = form ID** — filtering by form is trivial (e.g., `WHERE FishId = 4550` = NilePerchY only)
2. **Source = 'B' filter in histogram** — existing WebAdmin analytics already isolate BiteSystem path
3. **All generated fish recorded** — not just caught ones, which gives complete weight distribution picture
4. **Data is ephemeral** — Cleanup removes old records, so data depth depends on retention policy
5. **Debug fish excluded** — most analytics queries filter `Source <> 'D'`
