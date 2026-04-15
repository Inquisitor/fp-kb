# Matchmaking System — Current State (Code Audit)

> **Date:** 2026-04-14
> **Branch:** LBM20251201
> **Source:** Code audit of `MatchmakingLogic.cs` and related files after Phases 1–8

---

## 1. Lifecycle & Entry Points

**Primary Entry:**
- `MatchmakingLogic.ProcessGrouping(TournamentDto, ITournamentProvider)` — `Shared\SharedLib\Tournaments\MatchmakingLogic.cs:36`
- Called from `TournamentStartAdapter.StartTournamentAsync()` during tournament initialization
- Only **Competition** (KindId=1) supports grouping; other types return empty group array

**Flow:**
```
TournamentStartJob
  → TournamentStartAdapter.StartTournamentAsync()
    → Validate: min participants, pond active, time not expired
    → MatchmakingLogic.ProcessGrouping()
      → ProcessGroupingByRule()
        → ProcessBucketsByRule()
        │  ├─ CreateBuckets()
        │  └─ BalanceBuckets()
        └─ ProcessGroupsByRule()
           └─ BuildGroups()
              ├─ PartitionAllBuckets()
              ├─ ReassignGroupsToBuckets()
              └─ AssignGroupNames()
    → UpdateTournamentGroup()  [write BracketId + GroupName to DB]
```

**Post-Grouping (not in matchmaking code):**
- `TournamentEndAdapter` calculates results per group
- `RatingMultiplier` / `RewardMultiplier` applied at reward time, not during matchmaking

---

## 2. Configuration Model

### TournamentGroupingRule
**File:** `Shared\ObjectModel\Tournaments\TournamentGroupingRule.cs`

| Property        | Type                    | Default  | Purpose                                                      |
|-----------------|-------------------------|----------|--------------------------------------------------------------|
| `MinSize`       | `int`                   | required | Minimum participants per group                               |
| `TargetSize`    | `int?`                  | null     | Ideal avg group size                                         |
| `MaxSize`       | `int?`                  | null     | Hard cap per group; implicit default = `MinSize * 2 - 1`     |
| `MaxGroupCount` | `int?`                  | null     | Global cap on total groups; enables FFS algorithm            |
| `Brackets`      | `List<TournamentBracket>` | new()  | Rating-based bracket definitions                             |

### TournamentBracket
**File:** `Shared\ObjectModel\Tournaments\TournamentBracket.cs`

| Property            | Type     | Purpose                                        |
|---------------------|----------|-------------------------------------------------|
| `BracketId`         | `int`    | Unique ID                                      |
| `BracketName`       | `string` | Internal name (designer only)                  |
| `MinRating`         | `int`    | Lower boundary (inclusive)                     |
| `MaxRating`         | `int`    | Upper boundary (inclusive); auto-computed       |
| `RatingMultiplier`  | `double` | Applied to rating at reward time (default 1.0) |
| `RewardMultiplier`  | `double` | Applied to rewards at reward time (default 1.0)|

**`InitializeGrouping()`** (line 15–28): auto-fills MaxRating per bracket:
- Highest bracket: `MaxRating = int.MaxValue` if 0
- Others: `MaxRating = NextBracket.MinRating - 1`
- Assumes brackets pre-sorted by MinRating descending

### Removed Parameters (Phase 4 + Phase 8)
ConfigJson dead fields silently ignored on deserialization:
- `CrossMovesAllowed`, `CanceledIfIncomplete`, `NotRatedIfIncomplete`, `IsLowRatingGroupProtectionOn`

Removed via SQL patch `LBM.M.2026.03.08-028-v2`.

---

## 3. Data Types

### TournamentBucket
**File:** `Shared\ObjectModel\Tournaments\TournamentBucket.cs`

Extends `TournamentBracket` at runtime:

| Property               | Type                               | Purpose                          |
|------------------------|------------------------------------|----------------------------------|
| `Participants`         | `List<TournamentGroupParticipant>` | Players in this rating range     |
| `Groups`               | `List<TournamentGroup>`            | Subgroups created from participants |
| `MinParticipantRating` | `int?`                             | Cached min actual rating         |
| `MaxParticipantRating` | `int?`                             | Cached max actual rating         |

Methods: `UpdateRatings()`, `AvgGroupSize()`, `AvgGroupSizeRational()`

### TournamentGroup
**File:** `Shared\ObjectModel\Tournaments\TournamentGroup.cs`

| Property       | Type                                | Purpose                              |
|----------------|-------------------------------------|--------------------------------------|
| `BracketId`    | `int`                               | Parent bracket (assigned after `ReassignGroupsToBuckets()`) |
| `Name`         | `string`                            | Group ID: A, B, C, ..., AA, AB, ...  |
| `Participants` | `IList<TournamentGroupParticipant>` | Final group members                  |

### TournamentGroupParticipant
**File:** `Shared\ObjectModel\Tournaments\TournamentGroupParticipant.cs`

| Property            | Type   | Purpose                                          |
|---------------------|--------|--------------------------------------------------|
| `UserId`            | `Guid` | Player identifier                                |
| `CompetitionRating` | `int`  | Player's rating                                  |
| `IsMoved`           | `bool` | Participant moved out of native bracket during balancing |

### Rational (helper)
**File:** `Shared\SharedLib\Helpers\Rational.cs`

Exact rational arithmetic for FFS swap comparisons. Avoids floating-point precision loss. Safe for numerators/denominators up to ~10^9.

---

## 4. Core Algorithm

**File:** `Shared\SharedLib\Tournaments\MatchmakingLogic.cs`

### Stage 1: Bucket Creation & Balancing

#### CreateBuckets() (line 349–371)
1. Create one bucket per bracket (inherits MinRating, MaxRating, multipliers)
2. Distribute sorted participants (by rating ascending) into buckets by bracket range
3. Call `UpdateRatings()` on each bucket

#### BalanceBuckets() (line 95–203)

**Phase A — Ping-Pong Traversal (line 95–146):**
- Uses `PingPongTraversalIterator<TournamentBucket>` — order: `[0], [n-1], [1], [n-2], [2], ...`
- For each bucket with `0 < count < MinSize`:
  - Pull participants from adjacent unvisited buckets
  - From stronger neighbor: take participant with **lowest** rating first
  - From weaker neighbor: take participant with **highest** rating first
  - Stop when current bucket reaches MinSize
- Already-visited buckets are closed — cannot be pulled from

**Phase B — Incomplete Bucket Merge (line 151–202):**
- For each remaining incomplete bucket (0 < count < MinSize):
  - Prefer merging into nearest **stronger** bucket (higher MinRating)
  - Fallback: nearest **weaker** bucket
  - Move all participants, re-sort, re-rate both buckets
- Protects low-level brackets from strong player overflow

### Stage 2: Group Creation

#### BuildGroups() (line 233–251)
1. Filter non-empty buckets
2. `PartitionAllBuckets()` — split into groups
3. `ReassignGroupsToBuckets()` — finalize bracket assignments by median rating
4. Assign group names (A, B, C, ..., AA, AB, ...)

#### PartitionAllBuckets() — Two Modes (line 258–287)

**Mode 1: Per-Bucket (no MaxGroupCount):**
- Apply **NSR**: lowest bracket (MinRating=0) with moved participants → exactly 1 group
- Otherwise: `ComputeGroupCount(participants, MinSize, TargetSize, MaxSize)` per bucket

**Mode 2: Global Budget (MaxGroupCount set):**
- `AllocateGroupBudget()` — FFS algorithm distributes total groups across buckets
- Each bucket partitioned into its allocated count

#### ComputeGroupCount() — Per-Bucket Logic (line 387–435)

With TargetSize:
1. `projected = ⌈total / TargetSize⌉`
2. Try `increased = projected + 1` (prefer smaller groups)
3. If increased avg < MinSize or not close to target → use projected
4. If projected avg < MinSize or not close to target → use `decreased = max(1, projected - 1)`
5. With MaxSize: enforce min count `⌈total / effectiveMaxSize⌉` where `effectiveMaxSize = max(MaxSize, 2*MinSize - 1)`

Without TargetSize: split by MaxSize only; fallback to 1 group.

#### AllocateGroupBudget() — FFS Algorithm (line 446–685)

**Phase 1 — Maximize (line 459–467):**
- Each non-NSR bucket: `groupCount = max(1, participants / MinSize)`
- NSR buckets: `groupCount = 1` (locked)

**Phase 2 — Reduce (line 469–506):**
- While `totalGroups > MaxGroupCount`:
  - Find bucket with smallest avg group size (≥2 groups)
  - Tie-break: strongest bucket loses first (**WSR**)
  - Decrement count
  - Uses `Rational` for exact comparison

**Phase 3 — Optimize (line 508–682), repeats until convergence (max 100 iterations):**

- **Free Step** (line 519–558): below-target buckets reduce group count (frees slots)
- **Fill Step** (line 560–611): above-target buckets receive freed slots; weaker bucket gets priority (**WSR**)
- **Swap Step** (line 613–680): budget-neutral transfers between donor/recipient pairs
  - `ComputeSwapImprovement()` with exact Rational math (line 714–744)
  - Tie-break cascade: largest improvement → weaker recipient → stronger donor

#### PartitionBucket() (line 751–777)
- Divide participants evenly into `groupCount` groups
- Extra participants go to last (strongest) groups

#### ReassignGroupsToBuckets() (line 297–341)
1. For each group: compute median participant rating
2. Find bracket containing median → assign group's `BracketId`
3. Mark participants outside bracket range as `IsMoved = true`
4. Re-sort and re-rate all buckets

### Key Rules

**No-Split Rule (NSR)** — `IsNoSplitBucket()` (line 378–381):
- `MinRating == 0` AND has participants AND `MaxParticipantRating > bucket.MaxRating`
- Highest priority — overrides MaxSize, MaxGroupCount, TargetSize

**Weak-Small Rule (WSR):**
- FFS Reduce: strongest bucket loses group first
- FFS Fill: weakest bucket gets group first
- FFS Swap: weaker recipient preferred in tie-break

---

## 5. Database Layer

### Tables
- `TournamentParticipants` — `BracketId` (int, nullable), `GroupName` (char(2), nullable)
- `TournamentIndividualResults` — same columns
- `TournamentSecondaryResult` — same columns
- Archive tables mirror the above

### Write: UpdateTournamentGroup()
**File:** `Dal\Sql.MsSql\Tournaments\SqlTournamentProvider.cs:358–383`

```sql
UPDATE TournamentParticipants
SET BracketId = @bracketId, GroupName = @groupName
WHERE TournamentId = @tournamentId AND UserId = @userId;

UPDATE TournamentIndividualResults
SET BracketId = @bracketId, GroupName = @groupName
WHERE TournamentId = @tournamentId AND UserId = @userId;
```

### Read: GetTournamentParticipants()
Returns `IEnumerable<TournamentParticipantDto>` with UserId, CompetitionRating.

### Removed DB Columns (Phase 8)
- `IsRated`, `IsCanceled` — dropped from TournamentParticipants and Archive tables

---

## 6. Validation (Current State)

### Implemented
- Pre-grouping: participant count ≥ MinParticipants, pond active, time not expired
- `InitializeGrouping()`: auto-fills MaxRating to ensure bracket continuity
- `Debug.Assert` checks (debug builds only): maxGroupCount ≥ 1, minSize ≥ 1, sorted brackets

### Not Implemented
- `MinSize > 0` (no runtime check)
- `TargetSize >= MinSize` (no check)
- `MaxGroupCount` vs `MaxSize` mutual exclusivity (no check)
- Bracket rating overlap detection (no check)
- `InitializeGrouping()` assumes MinRating sorted descending — no verification

---

## 7. Tests

**File:** `Shared\SharedLib.Tests\Tournaments\MatchmakingLogicTests.cs`

- 70+ DataTestMethod cases for 3-bracket balancing
- 4-bracket test cases
- FFS algorithm test cases (MaxGroupCount)
- Test helper: `MatchmakingTestCase.cs` — compact string notation parser

---

## 8. Helper Components

| Component                  | File                                                    | Purpose                           |
|----------------------------|---------------------------------------------------------|-----------------------------------|
| PingPongTraversalIterator  | `Shared\SharedLib\Helpers\PingPongTraversalIterator.cs` | Alternating left↔right traversal  |
| Rational                   | `Shared\SharedLib\Helpers\Rational.cs`                  | Exact rational arithmetic for FFS |
| TournamentsHelper.FromDto  | `Shared\SharedLib\Tournaments\TournamentsHelper.cs`     | Calls InitializeGrouping()        |

---

## 9. File Map

| Component        | Path                                                                  |
|------------------|-----------------------------------------------------------------------|
| Main Logic       | `Shared\SharedLib\Tournaments\MatchmakingLogic.cs`                    |
| Data Models      | `Shared\ObjectModel\Tournaments\Tournament{Bracket,Bucket,Group,GroupParticipant,GroupingRule}.cs` |
| Entry Point      | `Shared\SharedLib\Tournaments\TournamentStartAdapter.cs`              |
| Helper           | `Shared\SharedLib\Tournaments\TournamentsHelper.cs`                   |
| Rational Math    | `Shared\SharedLib\Helpers\Rational.cs`                                |
| Traversal        | `Shared\SharedLib\Helpers\PingPongTraversalIterator.cs`               |
| DB Interface     | `Dal\Sql.Interface\Tournaments\ITournamentProvider.cs`                |
| DB Implementation| `Dal\Sql.MsSql\Tournaments\SqlTournamentProvider.cs`                  |
| Tests            | `Shared\SharedLib.Tests\Tournaments\MatchmakingLogicTests.cs`         |
| Test Helpers     | `Shared\SharedLib.Tests\Tournaments\Helpers\MatchmakingTestCase.cs`   |
| Async Job        | `AsyncProcessor\AsyncProcessor\Jobs\TournamentStartJob.cs`           |
| DB Cleanup Patch | `SQL\Patches\LBM.M.2026.03.08-028-v2 [Matchmaking] [Cleanup].sql`   |
