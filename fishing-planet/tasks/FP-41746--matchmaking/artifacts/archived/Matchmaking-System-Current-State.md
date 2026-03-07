# Matchmaking System – Current State of Implementation

> **Date:** 2026-02-16
> **Branch:** LBM20251201
> **Status:** In development

### Sources

**Documentation (Confluence):**
- [MatchMaking System - 1st Iteration GDD](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/4067721271/MatchMaking+System+-+1st+Iteration+GDD)
- [New tournament ratings, competitive leaderboards and matchmaking system server technical design](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/4009033759)

**Local copies (.md):**
- [MatchMaking-System-1st-Iteration-GDD.md](MatchMaking-System-1st-Iteration-GDD.md)
- [New-Tournament-Ratings-TDD.md](New-Tournament-Ratings-TDD.md)

**Key source files:**
- `Shared/SharedLib/Tournaments/MatchmakingLogic.cs`
- `Shared/ObjectModel/Tournaments/TournamentGroupingRule.cs`
- `Shared/ObjectModel/Tournaments/TournamentGroupSettings.cs`
- `Shared/ObjectModel/Tournaments/TournamentGroup.cs`
- `Shared/ObjectModel/Tournaments/TournamentSubgroup.cs`
- `Shared/ObjectModel/Tournaments/TournamentGroupParticipant.cs`
- `Shared/SharedLib/Helpers/PingPongTraversalIterator.cs`
- `Shared/SharedLib/Tournaments/TournamentStartAdapter.cs`

**Related:**
- [Matchmaking-Alignment-Plan.md](Matchmaking-Alignment-Plan.md)

---

## Table of Contents

1. [Glossary](#1-glossary)
2. [High-Level Architecture](#2-high-level-architecture)
3. [Data Model](#3-data-model)
4. [Algorithm](#4-algorithm)
5. [JSON Configuration](#5-json-configuration)
6. [Integration Points](#6-integration-points)
7. [Test Coverage](#7-test-coverage)
8. [Differences Between Documentation and Code](#8-differences-between-documentation-and-code)

---

## 1. Glossary

There is a terminology conflict between the GDD and the Technical Design documents. This section uses **unified terminology** with mappings to both documents.

| Unified Term   | GDD Term   | Tech Design Term  | Code Identifier                                      | Description                                                                                                                             |
|----------------|------------|-------------------|------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| **Bracket**    | Bracket    | (rating range)    | `MinRating`/`MaxRating` in `TournamentGroupSettings` | Rating range definition (e.g. 0-499, 500-1999, 2000+). A static configuration from JSON.                                                |
| **Bucket**     | Bucket     | Group             | `TournamentGroup`                                    | A container of players assigned by bracket. Gets balanced by the algorithm.                                                             |
| **Group**      | Group      | Subgroup          | `TournamentSubgroup`                                 | The final unit of competition. Players within a group compete against each other and share a reward pool. Named A, B, C... for display. |
| **PCR**        | PCR        | CompetitionRating | `CompetitionRating`                                  | Personal Competitive Rating - the player's rating used for matchmaking.                                                                 |
| **MinSize**    | MinSize    | MinSize           | `TournamentGroupingRule.MinSize`                     | Minimum number of players required for a bucket/group to be considered valid.                                                           |
| **TargetSize** | TargetSize | TargetSize        | `TournamentGroupingRule.TargetSize`                  | Target number of players per group when splitting buckets into subgroups.                                                               |
| **MaxSize**    | -          | MaxSize           | Calculated: `MinSize * 2 - 1`                        | Maximum group size, derived from MinSize. Not stored in config.                                                                         |

---

## 2. High-Level Architecture

### Component Diagram

```
TournamentStartAdapter.StartTournaments()
    |
    |  (at competition start time)
    v
MatchmakingLogic.ProcessGrouping(tournament, provider)
    |
    |-- ProcessGroupingByRule(groupingRule, participants)
    |       |
    |       |-- ProcessTopLevelGroupsByRule()    [Bucket formation]
    |       |       |-- CreateGroups()           [Distribute players into buckets by rating]
    |       |       |-- BalanceGroups()           [Balance buckets to meet MinSize]
    |       |       |       |-- Phase A: Ping-Pong Traversal
    |       |       |       |-- Phase B: Final Merging
    |       |       |
    |       |-- ProcessSubgroupsByRule()          [Group formation]
    |               |-- MakeSubgroups()
    |                       |-- CreateSubgroups() [Split buckets into groups by TargetSize]
    |                       |-- Re-evaluate parent groups by median rating
    |                       |-- Assign names: A, B, C...
    |
    |-- AssignGroupsToParticipants()              [Persist to DB]
            |-- ITournamentProvider.UpdateTournamentGroup()
                    |-- UPDATE TournamentParticipants SET GroupId, GroupName, IsRated
```

### File Locations

| File                  | Path (relative to repo root)                                                         |
|-----------------------|--------------------------------------------------------------------------------------|
| Main Algorithm        | `Shared/SharedLib/Tournaments/MatchmakingLogic.cs`                                   |
| PingPong Iterator     | `Shared/SharedLib/Helpers/PingPongTraversalIterator.cs`                              |
| Integration (Start)   | `Shared/SharedLib/Tournaments/TournamentStartAdapter.cs`                             |
| Config Init           | `Shared/SharedLib/Tournaments/TournamentsHelper.cs` (calls `InitializeGrouping`)     |
| Grouping Rule Model   | `Shared/ObjectModel/Tournaments/TournamentGroupingRule.cs`                           |
| Group Settings Model  | `Shared/ObjectModel/Tournaments/TournamentGroupSettings.cs`                          |
| Bucket Model          | `Shared/ObjectModel/Tournaments/TournamentGroup.cs`                                  |
| Group Model           | `Shared/ObjectModel/Tournaments/TournamentSubgroup.cs`                               |
| Participant Model     | `Shared/ObjectModel/Tournaments/TournamentGroupParticipant.cs`                       |
| JSON Config Base      | `Shared/ObjectModel/Tournaments/TournamentBase.cs` (`TournamentJsonConfig.Grouping`) |
| DB Provider Interface | `Dal/Sql.Interface/Tournaments/ITournamentProvider.cs`                               |
| DB Provider Impl      | `Dal/Sql.MsSql/Tournaments/SqlTournamentProvider.cs`                                 |
| Tests                 | `Shared/SharedLib.Tests/Tournaments/MatchmakingLogicTests.cs`                        |
| Test Helpers          | `Shared/SharedLib.Tests/Tournaments/Helpers/MatchmakingTestCase.cs`                  |

---

## 3. Data Model

### 3.1. Configuration Models

#### `TournamentGroupingRule`
The top-level configuration object, deserialized from the competition JSON `"Grouping"` section.

| Property     | Type                            | Description                                                                    |
|--------------|---------------------------------|--------------------------------------------------------------------------------|
| `MinSize`    | `int`                           | Minimum bucket/group size.                                                     |
| `TargetSize` | `int?`                          | Target group size for subgroup creation. If `null` - no subgroups are created. |
| `Groups`     | `List<TournamentGroupSettings>` | List of bracket definitions.                                                   |

#### `TournamentGroupSettings`
Defines a single bracket (rating range) for bucket formation.

| Property           | Type     | Description                                                                           |
|--------------------|----------|---------------------------------------------------------------------------------------|
| `GroupId`          | `int`    | Unique bracket identifier.                                                            |
| `GroupName`        | `string` | Internal name (e.g. "Newbies", "Tops"). Never shown to players.                       |
| `MinRating`        | `int`    | Lower boundary of rating range (inclusive).                                           |
| `MaxRating`        | `int`    | Upper boundary of rating range (inclusive). Auto-filled by `InitializeGrouping` if 0. |
| `RatingMultiplier` | `double` | Multiplier for rating awarded to players in this bracket. Default `1.0`.              |
| `RewardMultiplier` | `double` | Multiplier for money rewards in this bracket. Default `1.0`.                          |

### 3.2. Runtime Models

#### `TournamentGroup` (extends `TournamentGroupSettings`)
Represents a bucket during the matchmaking process. Created at runtime by `CreateGroups()`.

| Property               | Type                               | Description                                             |
|------------------------|------------------------------------|---------------------------------------------------------|
| `Participants`         | `List<TournamentGroupParticipant>` | Players currently assigned to this bucket.              |
| `Subgroups`            | `List<TournamentSubgroup>`         | Groups created from this bucket by `MakeSubgroups`.     |
| `MinParticipantRating` | `int?`                             | Min rating among actual participants (after balancing). |
| `MaxParticipantRating` | `int?`                             | Max rating among actual participants (after balancing). |

#### `TournamentSubgroup`
Represents the final group for competition. This is what players see as "Group A", "Group B", etc.

| Property       | Type                                | Description                                                       |
|----------------|-------------------------------------|-------------------------------------------------------------------|
| `GroupId`      | `int`                               | ID of the parent bucket this group belongs to.                    |
| `Name`         | `string`                            | Display name: "A", "B", ... "Z", "AA", "AB"...                    |
| `Participants` | `IList<TournamentGroupParticipant>` | Players in this group.                                            |
| `IsNotRated`   | `bool`                              | **[Obsolete]** If true, no rating changes for this group.         |
| `IsCanceled`   | `bool`                              | **[Obsolete]** If true, participation is canceled for this group. |

#### `TournamentGroupParticipant`
A player participating in the matchmaking.

| Property            | Type   | Description                                                               |
|---------------------|--------|---------------------------------------------------------------------------|
| `UserId`            | `Guid` | Player ID.                                                                |
| `CompetitionRating` | `int`  | Player's current PCR.                                                     |
| `IsMoved`           | `bool` | True if the player was reassigned to a different bucket during balancing. |
| `IsNotRated`        | `bool` | True if rating should not be applied.                                     |
| `IsCanceled`        | `bool` | True if participation was canceled.                                       |

### 3.3. Database

`UpdateTournamentGroup` writes the following fields to `TournamentParticipants`:

| Column       | Source                                          |
|--------------|-------------------------------------------------|
| `GroupId`    | `TournamentSubgroup.GroupId` (parent bucket ID) |
| `GroupName`  | `TournamentSubgroup.Name` ("A", "B", etc.)      |
| `IsRated`    | `!TournamentSubgroup.IsNotRated`                |
| `IsCanceled` | `TournamentSubgroup.IsCanceled`                 |

---

## 4. Algorithm

### 4.0. Initialization (`InitializeGrouping`)

Called from `TournamentsHelper.FromDto()` before matchmaking. Fills in `MaxRating` gaps in bracket definitions:
- Sorts brackets by `MinRating` descending.
- The highest bracket gets `MaxRating = int.MaxValue`.
- Each lower bracket gets `MaxRating = nextBracket.MinRating - 1`.

This ensures continuous, non-overlapping rating ranges.

### 4.1. Create Buckets (`CreateGroups`)

1. Sort bracket definitions by `MinRating` ascending.
2. For each bracket, select participants where `MinRating <= CompetitionRating <= MaxRating`.
3. Sort participants within each bucket by rating ascending.
4. Remove assigned participants from the candidate list.

**Result:** An array of `TournamentGroup[]` with participants distributed by their rating bracket.

### 4.2. Balance Buckets (`BalanceGroups`)

The goal is to ensure every bucket has at least `MinSize` players or is empty.

#### Phase A: Ping-Pong Traversal

Uses `PingPongTraversalIterator` to visit buckets in ping-pong order:

```
For 3 buckets [1,2,3]:  visit order: 1, 3, 2
For 4 buckets [1,2,3,4]: visit order: 1, 4, 2, 3
For 5 buckets [1,2,3,4,5]: visit order: 1, 5, 2, 4, 3
```

For each visited bucket:
- **Skip** if empty or already has >= `MinSize` players.
- If below `MinSize`, pull players from **adjacent unvisited** buckets:
  - If the current bucket is on the **left** side: take the player with the **lowest** rating from the adjacent (stronger) bucket (index 0).
  - If the current bucket is on the **right** side: take the player with the **highest** rating from the adjacent (weaker) bucket (last index).
  - If the adjacent bucket is exhausted, look at the next adjacent bucket behind it.
  - **Stop pulling** if the adjacent bucket has already been visited (considered complete).
- Continue until the bucket reaches `MinSize` or no more adjacent players are available.

#### Phase B: Final Merging

After Phase A, at most one bucket can still be below `MinSize`. This bucket is merged:

1. **Prefer merging upward** (into the nearest stronger bucket with players) – protects low-rated groups from getting flooded with strong players.
2. **Fallback:** merge into the nearest weaker bucket.
3. All participants from the incomplete bucket are moved to the target bucket.

> **BUG:** The code comment says "closest complete group", but the implementation iterates without `break` and overwrites `targetGroup` on each match. As a result, it finds the **farthest (strongest)** non-empty bucket, not the nearest. The fallback similarly finds the **farthest (weakest)** bucket. The intended behavior is to merge into the **nearest** stronger/weaker bucket.

> **NOTE:** Phase B does not skip empty buckets (unlike Phase A). For a bucket with 0 participants, the inner `while` loop simply does not execute. Not a bug, but suboptimal – should be fixed with an early `continue`.

> **NOTE:** Phase B does not call `RefreshGroup()` on the target bucket after merging. This means `MinParticipantRating`/`MaxParticipantRating` and sort order are stale. Mitigated by `MakeSubgroups` re-sorting later, but fragile.

**Important:** After Phase B, the incomplete bucket's `Participants` list is emptied, but the bucket object itself remains in the array (with 0 players).

### 4.3. Create Groups (`MakeSubgroups` / `CreateSubgroups`)

#### `MakeSubgroups` orchestration:

1. For each non-empty bucket, call `CreateSubgroups` to split it into groups.
2. **Re-evaluate parent buckets:** Each group's parent bucket is determined by the **median rating** of the group's participants (not by the original bucket assignment).
3. Set `IsMoved = true` on participants whose rating falls outside their assigned parent bucket's range.
4. **Assign sequential names:** "A", "B", "C"... "Z", "AA", "AB"...
5. If **all** groups are `IsCanceled`, return `null` (matchmaking failed).

#### `CreateSubgroups` per bucket:

When `TargetSize` is configured:

1. **Constraints check:**
   - `TargetSize >= MinSize` (throws `ArgumentException` otherwise)
   - `TargetSize <= MaxSize` where `MaxSize = MinSize * 2 - 1` (throws otherwise)

2. **Calculate candidate group counts:**
   - `projectedGroupCount = ceil(totalParticipants / TargetSize)`
   - `increasedGroupCount = projectedGroupCount + 1`
   - `decreasedGroupCount = max(1, projectedGroupCount - 1)`

3. **Select group count** (prefer smaller groups):
   - Start with `increasedGroupCount`.
   - Fall back to `projectedGroupCount` if the average size would be below `MinSize` or if it's closer to `TargetSize`.
   - Fall back to `decreasedGroupCount` if the previous average is still below `MinSize` or farther from `TargetSize`.

4. **Distribute participants** evenly across groups:
   - Base size: `totalParticipants / groupCount`
   - Remainder `totalParticipants % groupCount` is distributed to the first groups (+1 each).
   - Participants are taken sequentially (already sorted by rating), so each group has a contiguous rating range.

When `TargetSize` is `null`:
- `projectedGroupCount = 1` - all participants go into a single group.

### 4.4. Naming (`GetGroupNameByIndex`)

Excel-style column naming: 0→"A", 1→"B", ..., 25→"Z", 26→"AA", 27→"AB", etc.

### 4.5. Persistence (`AssignGroupsToParticipants`)

For each group, for each participant:
- Calls `ITournamentProvider.UpdateTournamentGroup(tournamentId, userId, groupId, groupName, isRated, isCanceled)`.
- Executes `UPDATE TournamentParticipants SET GroupId=@groupId, GroupName=@groupName, IsRated=@isRated` per player.

---

## 5. JSON Configuration

### Current model in code (`TournamentGroupingRule`)

```json
{
  "Grouping": {
    "MinSize": 15,
    "TargetSize": 20,
    "Groups": [
      { "GroupId": 1, "GroupName": "Newbies", "MinRating": 0, "MaxRating": 499, "RatingMultiplier": 1.0, "RewardMultiplier": 1.0 },
      { "GroupId": 2, "GroupName": "Middles", "MinRating": 500, "MaxRating": 1999, "RatingMultiplier": 1.5, "RewardMultiplier": 1.5 },
      { "GroupId": 3, "GroupName": "Tops", "MinRating": 2000, "MaxRating": 2147483647, "RatingMultiplier": 2.0, "RewardMultiplier": 2.0 }
    ]
  }
}
```

### Properties supported by code

| Property                    | Present in Model | Used in Algorithm                                                   |
|-----------------------------|------------------|---------------------------------------------------------------------|
| `MinSize`                   | Yes              | Yes - core parameter                                                |
| `TargetSize`                | Yes              | Yes - drives subgroup creation                                      |
| `Groups[].GroupId`          | Yes              | Yes                                                                 |
| `Groups[].GroupName`        | Yes              | Yes (internal label)                                                |
| `Groups[].MinRating`        | Yes              | Yes                                                                 |
| `Groups[].MaxRating`        | Yes              | Yes (auto-filled by `InitializeGrouping` if 0)                      |
| `Groups[].RatingMultiplier` | Yes              | Not used in `MatchmakingLogic`. Applied during reward distribution. |
| `Groups[].RewardMultiplier` | Yes              | Not used in `MatchmakingLogic`. Applied during reward distribution. |

---

## 6. Integration Points

### 6.1. Start Flow (`TournamentStartAdapter.StartTournamentAsync`)

```
1. Wait for StartDate
2. Check participant count >= MinParticipants
3. Check EndDate not passed
4. Check pond is active
5. Call MatchmakingLogic.ProcessGrouping()
   - Returns null -> reason += "grouping-failed" -> cancel tournament
   - Returns subgroups -> check for IsCanceled subgroups -> notify those players
6. Start tournament (provider.StartTournament)
7. Notify players about start
```

### 6.2. Grouping Config Initialization

`TournamentsHelper.FromDto(tournament)` is called before `ProcessGrouping`. It:
1. Deserializes tournament from DTO.
2. Calls `MatchmakingLogic.InitializeGrouping(result.Grouping)` to fill `MaxRating` gaps.

---

## 7. Test Coverage

### Test file: `MatchmakingLogicTests.cs`

| Test Method                                                          | What it tests                                                                                                                 | # of cases                           |
|----------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------|--------------------------------------|
| `Test_CreateGroups_WorksProperly`                                    | Basic bracket distribution                                                                                                    | 1                                    |
| `Test_MakingTopLevelGroups_With_3_Groups_Min_15_Participants`        | Bucket balancing with 3 brackets, MinSize=15                                                                                  | ~70 DataRow                          |
| `Test_MakingTopLevelGroups_With_3_Groups_Min_20_Participants`        | Bucket balancing with 3 brackets, MinSize=20 (uses string format parser)                                                      | ~68 DataRow                          |
| `Test_MakingTopLevelGroups_With_4_Groups_Min_20_Participants`        | Bucket balancing with 4 brackets, MinSize=20                                                                                  | ~60 DataRow (17 commented out)       |
| `Test_MakeSubgroups`                                                 | End-to-end subgroup creation                                                                                                  | 2                                    |
| `Test_CreateSubgroups_With_Average_WorksProperly`                    | Subgroup size distribution by TargetSize                                                                                      | ~100 DataRow (1 to 100 participants) |
| `Test_CreateSubgroups_Without_TargetSize_CreatesOneGroup`            | No TargetSize -> single group                                                                                                 | 1                                    |
| `CreateSubgroups_LowRatingProtectionIsOn_AddsMinimalPossiblePlayers` | MinSize-1 low-rated + many mid-rated. **Note:** tests a removed flag `IsLowRatingGroupProtectionOn`; needs rework or removal. | 1                                    |
| `Test_Demo_MatchmakingLogic`                                         | Visual output demo                                                                                                            | ~14 DataRow                          |
| `InitializeGrouping_sets_max_rating_properly`                        | `MaxRating` auto-fill                                                                                                         | 1                                    |

### Test helper: `MatchmakingTestCase`

Parses compact string format:
- `[40/0/10] => [20/0/30]` - 3 buckets input -> 3 buckets output
- Supports subgroups: `[20+20/0/15]` - first bucket has 2 subgroups of 20
- Used in the Min_20 test set for cleaner test case representation.

### Commented-out and potentially incorrect tests

**4-group set:** 29 test cases are commented out in `Test_MakingTopLevelGroups_With_4_Groups_Min_20_Participants` (cases 18-31, 39, 47, 48, 54, 61, 64, 66, 69, 77, 80, 88-93). These represent cases where expected behavior was not yet finalized or the algorithm does not handle them correctly.

**3-group min-20 set:** Multiple active test cases are annotated "Potentially false case" in their descriptions (cases [008], [016], [022]-[026], [031]-[033], [038], [045]-[050], [051]-[053], [057]-[059], [067]). Expected values in these cases need review and correction.

### Dead code in `MatchmakingLogic`

`FindFirstAdjacentIncompleteGroupsCombination` (lines 435-465) is a `private static` method that is **never called**. It appears to be leftover from an earlier iteration of the algorithm.

---

## 8. Differences Between Documentation and Code

### 8.1. Terminology Mismatch

| Concept                 | GDD Term | Tech Design Term | Code Term                 |
|-------------------------|----------|------------------|---------------------------|
| Rating-based container  | Bucket   | Group            | `TournamentGroup`         |
| Final competition unit  | Group    | Subgroup         | `TournamentSubgroup`      |
| Rating range definition | Bracket  | (rating range)   | `TournamentGroupSettings` |

This is the most significant source of confusion. The GDD and Tech Design use inverted terminology for the two key concepts (Group/Bucket vs. Group/Subgroup).

### 8.2. Configuration Parameters: Documented but Not in Code Model

The following parameters are described in the GDD and/or Tech Design but are **absent from `TournamentGroupingRule`** in code:

| Parameter                      | Documented In     | Status in Code                                                                                                            |
|--------------------------------|-------------------|---------------------------------------------------------------------------------------------------------------------------|
| `CrossMovesAllowed`            | GDD + Tech Design | **Not in model.** Tech Design says "deprecated, will be removed". Algorithm always allows cross-moves.                    |
| `CanceledIfIncomplete`         | Tech Design       | **Not in model.** `TournamentSubgroup.IsCanceled` exists (marked `[Obsolete]`) but no rule drives it.                     |
| `NotRatedIfIncomplete`         | Tech Design       | **Not in model.** `TournamentSubgroup.IsNotRated` exists (marked `[Obsolete]`) but no rule drives it.                     |
| `IsLowRatingGroupProtectionOn` | Tech Design       | **Removed from codebase.** Referenced only in a commented-out test line and a stale test name. Test needs rework/removal. |
| `MaxGroupCount`                | GDD               | **Not in model.** Not implemented.                                                                                        |
| `MaxGroupSize`                 | GDD               | **Not in model.** Not implemented.                                                                                        |

### 8.3. Algorithm Differences: GDD vs Code

| Aspect                      | GDD Description                                              | Actual Code Behavior                                                                                                                                                                                                   |
|-----------------------------|--------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Bucket fill priority**    | "Priority: fill Newbies first, then Tops, then Middles last" | Ping-pong traversal: first bucket, last bucket, second, second-to-last, etc. The priority is positional, not semantic. For 3 groups with standard order (Newbies=1, Middles=2, Tops=3) the result is similar: 1, 3, 2. |
| **Merging direction**       | "Middles serve as filler for other buckets"                  | Any bucket can serve as a donor. The algorithm pulls from adjacent **unvisited** buckets regardless of their semantic name.                                                                                            |
| **Incomplete bucket merge** | Not clearly specified                                        | Code merges upward (into a stronger bucket), with fallback to weaker.                                                                                                                                                  |
| **Minimum to start**        | "< 20 players -> competition doesn't start"                  | Handled outside of `MatchmakingLogic`, in `TournamentStartAdapter` via `MinParticipants` check. Matchmaking logic itself has no minimum check.                                                                         |
| **Single group threshold**  | "If < MinSize*2 -> single group"                             | Not enforced in `MatchmakingLogic`. The algorithm will naturally produce one group if there aren't enough players for two, but there's no explicit check for `MinSize*2`.                                              |

### 8.4. Algorithm Differences: Tech Design vs Code

| Aspect                    | Tech Design Description                                                                                                  | Actual Code Behavior                                                                                                       |
|---------------------------|--------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------|
| **`MaxRating` in config** | Explicitly specified per bracket with validation checks                                                                  | Auto-calculated by `InitializeGrouping` from `MinRating` values. Works if `MaxRating` is 0 or absent.                      |
| **Validation checks**     | Extensive: MinSize < TargetSize < MaxSize, rating overlaps, CanceledIfIncomplete + NotRatedIfIncomplete mutual exclusion | Only `TargetSize` range validation exists in `CreateSubgroups` (throws `ArgumentException`). No rating overlap validation. |
| **Subgroups**             | Marked as "[TBD]"                                                                                                        | Fully implemented in code: `CreateSubgroups` with TargetSize-based splitting.                                              |
| **Phase B merging**       | "prioritizes merging into a stronger group"                                                                              | Code implementation matches: iterates from `currentGroupIndex+1` to find a stronger target, falls back to weaker.          |

### 8.5. Obsolete / Dead Code

| Item                                           | Status                | Notes                                                                                                                           |
|------------------------------------------------|-----------------------|---------------------------------------------------------------------------------------------------------------------------------|
| `TournamentSubgroup.IsNotRated`                | Marked `[Obsolete]`   | No logic sets it to `true`. Always `false`. Still written to DB as `IsRated = !IsNotRated`.                                     |
| `TournamentSubgroup.IsCanceled`                | Marked `[Obsolete]`   | No logic sets it to `true`. Always `false`. `ProcessGrouping` returns `null` only if all subgroups are canceled (can't happen). |
| `FindFirstAdjacentIncompleteGroupsCombination` | Dead code             | Private method, never called. Was likely part of an earlier algorithm version.                                                  |
| `TournamentGroupParticipant.IsNotRated`        | Unused                | Never set or checked in `MatchmakingLogic`.                                                                                     |
| `TournamentGroupParticipant.IsCanceled`        | Unused                | Never set or checked in `MatchmakingLogic`.                                                                                     |

### 8.6. Features Described but Not Implemented

| Feature                                              | Source                                     | Status                                                                                  |
|------------------------------------------------------|--------------------------------------------|-----------------------------------------------------------------------------------------|
| Separate rewards per group (different values)        | GDD ("in next iterations")                 | Not implemented. `RewardMultiplier` is in the model but not applied during matchmaking. |
| Splitting friends/club members into different groups | GDD ("not implemented in first iteration") | Not implemented.                                                                        |
| `MaxGroupCount` - limit on number of groups          | GDD                                        | Not in model, not implemented.                                                          |
| `MaxGroupSize` - soft limit on group size            | GDD                                        | Not in model, not implemented.                                                          |
| Low-rating group protection flag                     | Tech Design                                | Removed from codebase. Stale test references remain.                                    |
| Incomplete group cancellation/not-rated logic        | Tech Design                                | Model fields exist but marked obsolete, no business logic drives them.                  |

---

## Appendix A: PingPongTraversalIterator

The `PingPongTraversalIterator<T>` is a generic helper that traverses an array in ping-pong order.

### Traversal Pattern

```
Array:       [0] [1] [2] [3] [4] [5] [6]
Visit order:  1   3   5   7   6   4   2
             ^^^         ^^^         ^^^
             left       middle      right
```

### Key API

| Method                               | Description                                                                                                          |
|--------------------------------------|----------------------------------------------------------------------------------------------------------------------|
| `MoveNext()`                         | Advances to next element in ping-pong order. Resets adjacent offset.                                                 |
| `TryGetNextAdjacent(out T, out int)` | Gets the next adjacent element from the current position. Called repeatedly to traverse toward array edges.          |
| `IsIndexVisited(int)`                | Checks if an index was already visited as a `Current` element. Used to protect completed buckets from being drained. |
| `CurrentIsOnTheLeft`                 | Indicates whether the current element was taken from the left side. Determines pull direction in `BalanceGroups`.    |
