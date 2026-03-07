# Matchmaking — TDD Section Draft

> **Status:** DRAFT — review pending
> **Date:** 2026-03-04
> **Replaces:** "Matchmaking" section in [New-Tournament-Ratings-TDD.md](New-Tournament-Ratings-TDD.md) (lines 263–460)
> **Based on:** actual codebase state as of LBM20251201 branch

---

## Terminology

This document uses the unified terminology adopted across GDD, TDD, and code:

| Concept | Term | C# Class | JSON Key |
|---|---|---|---|
| Rating range configuration | **Bracket** | `TournamentBracket` | `"Groups"` (legacy) |
| Rating-based player pool | **Bucket** | `TournamentBucket` | — (runtime only) |
| Final match-sized unit | **Group** | `TournamentGroup` | — (runtime only) |
| Grouping rules | — | `TournamentGroupingRule` | `"Grouping"` |
| Player in matchmaking | — | `TournamentGroupParticipant` | — |

> **Note:** JSON keys `"Groups"`, `"GroupId"`, `"GroupName"` are preserved for backward compatibility
> via `[JsonProperty]` attributes. The C# property names are `Brackets`, `BracketId`, `BracketName`.
> All other JSON keys (`MinSize`, `TargetSize`, `MaxSize`, `MaxGroupCount`, `MinRating`, `MaxRating`,
> `RatingMultiplier`, `RewardMultiplier`) match their C# property names directly.

### Removed parameters

The following parameters appeared in earlier versions of this TDD but were **never implemented**
in the codebase and have been removed from the specification:

| Parameter | Original description | Reason for removal |
|---|---|---|
| `CrossMovesAllowed` | bool, default true — allow pulling players from other brackets | Behavior is always on; the flag was never implemented. |
| `CanceledIfIncomplete` | bool, default true — cancel competition for incomplete groups | Never implemented. Entire tournament is canceled if grouping fails (see Stage 4). |
| `NotRatedIfIncomplete` | bool, default false — skip rating for incomplete groups | Never implemented. `IsRated` is always `true` for all participants. |
| `IsLowRatingGroupProtectionOn` | bool, default true — protect lower brackets from strong players | Replaced by unconditional behavior: Phase B always merges upward, and the no-split rule protects the lowest bracket (see Stage 3a, No-split rule). |

> **Obsolete fields pending removal:** `TournamentGroupParticipant.IsNotRated` and
> `TournamentGroupParticipant.IsCanceled` exist in the C# model but are never set by the
> matchmaking algorithm. They are remnants of the `NotRatedIfIncomplete` / `CanceledIfIncomplete`
> design and should be removed. Similarly, the `IsRated` and `IsCanceled` columns in
> `TournamentParticipants` always contain their default values (`1` and `0` respectively).
> See Alignment Plan items DCD-004, DCD-005, CFG-003.

---

## Domain Model

### `TournamentBracket` (`Shared/ObjectModel/Tournaments/`)

The static configuration of a rating range. Deserialized from JSON as part of
`TournamentGroupingRule.Brackets`. Properties: `BracketId`, `BracketName`, `MinRating`,
`MaxRating`, `RatingMultiplier`, `RewardMultiplier`.

### `TournamentBucket` (`Shared/ObjectModel/Tournaments/`)

Extends `TournamentBracket`. A runtime container that holds the actual players assigned to a
bracket. Created by `CreateBuckets`, mutated by `BalanceBuckets`, consumed by `BuildGroups`.
Key properties beyond `TournamentBracket`:
* `Participants` — list of `TournamentGroupParticipant`, sorted by rating ascending.
* `Groups` — list of `TournamentGroup` assigned to this bucket after partitioning.
* `MinParticipantRating` / `MaxParticipantRating` — aggregate statistics, updated via
  `UpdateRatings()` after any participant movement.

Related extension methods (defined in `MatchmakingLogic.cs`, not members of `TournamentBucket`):
* `AvgGroupSize(groupCount)` / `AvgGroupSizeRational(groupCount)` — used by the FFS algorithm
  for distance-to-target calculations.

### `TournamentGroup` (`Shared/ObjectModel/Tournaments/`)

The final match-sized unit. Players within a single group compete against each other.
Properties: `BracketId` (parent bracket), `Name` (e.g. `"A"`, `"B"` — maps to `GroupName`
column in DB), `Participants` (list of `TournamentGroupParticipant`).

### `TournamentGroupParticipant` (`Shared/ObjectModel/Tournaments/`)

A player in the matchmaking process. Properties: `UserId`, `CompetitionRating`,
`IsMoved` (set when participant's rating is outside their group's parent bracket range).

---

## DB

The following schema changes have been applied to support matchmaking:

### `TournamentParticipants` / `TournamentIndividualResults`

| Column | Type | Table(s) | Notes |
|---|---|---|---|
| `GroupId` | `INT NULL` | Both | Bracket ID the participant was assigned to. Was `UNIQUEIDENTIFIER` in `TournamentIndividualResults` — changed to `INT`. |
| `GroupName` | `CHAR(2) NULL` | Both | Group name (e.g. `"A"`, `"B"`). |
| `IsRated` | `BIT NOT NULL DEFAULT 1` | `TournamentParticipants` only | Always `1` in current implementation (see "Obsolete fields" above). |
| `IsCanceled` | `BIT NOT NULL DEFAULT 0` | `TournamentParticipants` only | Always `0` in current implementation (see "Obsolete fields" above). |

Identical changes were applied to `ArchiveTournamentParticipants` and
`ArchiveTournamentIndividualResults`. The archival process copies these columns correctly.

---

## JSON Configuration

Grouping rules apply **only to Competitions** (`KindId = Competition`). They are ignored for
Tournaments. If the tournament type is not Competition, or if no `Grouping` section is present
in the config, the matchmaking process is skipped entirely and the competition runs without
player grouping.

### Top-level parameters (`TournamentGroupingRule`)

| Field | Type | Required | Description |
|---|---|---|---|
| `MinSize` | `int` | Yes | Minimum number of participants per group. Must be ≥ 1. |
| `TargetSize` | `int?` | No | Ideal group size. When null, groups are not subdivided (all matching players compete together), unless `MaxSize` is set. Must be ≥ `MinSize` when specified. |
| `MaxSize` | `int?` | No | Maximum number of participants per group. When null, no explicit upper limit on group size is enforced. Must be ≥ `2 × MinSize − 1` when specified (this lower bound ensures oversized groups can always be split). Mutually exclusive with `MaxGroupCount`. |
| `MaxGroupCount` | `int?` | No | Global cap on the total number of groups across all buckets. When set, activates the FFS (Free-Fill-Swap) budget allocation algorithm. Must be ≥ 1 and ≥ number of brackets. Hard limit: ≤ 100 (overflow guard for exact rational arithmetic). Mutually exclusive with `MaxSize` (see validation check #4). |
| `Groups` | `list` | Yes | List of bracket definitions. Order in JSON does not affect algorithm behavior — brackets are sorted by `MinRating` internally. |

### Bracket parameters (`TournamentBracket`, serialized as `Groups[i]`)

| Field | Type | Description |
|---|---|---|
| `GroupId` | `int` | Unique bracket ID. |
| `GroupName` | `string` | Internal bracket name (designer-facing, never shown to players). |
| `MinRating` | `int` | Lower rating boundary (inclusive). |
| `MaxRating` | `int` | Upper rating boundary (inclusive). Can be omitted (0) — `InitializeGrouping` will compute it automatically from adjacent brackets. |
| `RatingMultiplier` | `double` | Multiplier applied to the rating awarded to participants in this bracket. Default: 1.0. Applied during reward distribution, not during matchmaking. |
| `RewardMultiplier` | `double` | Multiplier applied to monetary rewards for participants in this bracket. Default: 1.0. Applied during reward distribution, not during matchmaking. |

### Example

```json
{
  "Grouping": {
    "MinSize": 15,
    "TargetSize": 20,
    "Groups": [
      { "GroupId": 1, "GroupName": "Newbies", "MinRating": 0, "MaxRating": 499,        "RatingMultiplier": 1.0, "RewardMultiplier": 1.0 },
      { "GroupId": 2, "GroupName": "Middles", "MinRating": 500, "MaxRating": 1999,      "RatingMultiplier": 1.5, "RewardMultiplier": 1.5 },
      { "GroupId": 3, "GroupName": "Tops",    "MinRating": 2000, "MaxRating": 2147483647, "RatingMultiplier": 2.0, "RewardMultiplier": 2.0 }
    ]
  }
}
```

`MaxRating` in the example is explicitly set for clarity. When omitted (0), `InitializeGrouping`
computes boundaries automatically: the highest bracket gets `int.MaxValue`, each subsequent
bracket gets `next bracket's MinRating − 1`.

### Example with MaxGroupCount

```json
{
  "Grouping": {
    "MinSize": 20,
    "TargetSize": 30,
    "MaxGroupCount": 6,
    "Groups": [
      { "GroupId": 1, "GroupName": "Newbies", "MinRating": 0, "MaxRating": 499 },
      { "GroupId": 2, "GroupName": "Middles", "MinRating": 500, "MaxRating": 1999 },
      { "GroupId": 3, "GroupName": "Tops",    "MinRating": 2000, "MaxRating": 2147483647 }
    ]
  }
}
```

In this mode, the system distributes exactly 6 groups (or fewer, if not enough players) across
all buckets using the FFS algorithm. `MaxSize` is not needed and would be rejected if specified.

---

## Admin Validation Rules

Validation is performed in [CompetetiveActivityBreaks](https://dev.fishingplanet.com/Stats/CompetetiveActivityBreaks)
(`CheckGroupingRule` method). All checks are evaluated at config save time. Checks are listed
in **execution order** — the first failing check produces the error and stops validation.

> **Note:** Error messages shown below are simplified templates. The actual messages in code
> include concrete parameter values (e.g. `"MaxSize (25) must be at least 2*MinSize-1 (29)..."`).

### 1. Parameter checks

| # | Rule | Error message (template) |
|---|---|---|
| 1 | Grouping kind must be `Competition` | "Grouping rules are not supported for [{kind}] kind." |
| 2 | `MinSize ≥ 1` | "MinSize should be greater than 0." |
| 3 | `TargetSize ≥ MinSize` (when `TargetSize` is set) | "TargetSize should not be less than MinSize." |
| 4 | `MaxGroupCount` and `MaxSize` cannot both be set | "MaxGroupCount and MaxSize are mutually exclusive. Remove one of them (MaxGroupCount takes priority over MaxSize)." |
| 5 | `MaxSize ≥ 2 × MinSize − 1` (when `MaxSize` is set) | "MaxSize ({value}) must be at least 2\*MinSize-1 ({computed}) to allow splitting oversized groups." |
| 6 | `TargetSize ≤ MaxSize` (when both are set; `MaxGroupCount` is necessarily absent due to check #4) | "TargetSize ({value}) should not exceed MaxSize ({value})." |

### 2. Bracket structure checks

| # | Rule | Error message (template) |
|---|---|---|
| 7 | At least 1 bracket defined | "No brackets specified." |
| 8 | First bracket starts at `MinRating = 0`; last bracket ends at `MaxRating == int.MaxValue` | "Brackets do not cover the entire rating range. Error in bracket #{id} '{name}' or bracket #{id} '{name}'." |
| 9 | No overlaps between consecutive brackets (sorted by `MinRating`): rejects when `bracket[i].MaxRating >= bracket[i+1].MinRating` | "There are gaps or overlaps between brackets. Error in bracket #{id} '{name}' and bracket #{id} '{name}'." |

> **⚠ Known issue:** Check #9 rejects **overlaps** (where `MaxRating ≥ next MinRating`) but does
> **not** detect **gaps** (where `MaxRating < next MinRating − 1`). Gaps at the edges of the
> rating range are prevented by check #8; only gaps between consecutive interior brackets are
> undetected. For example, brackets
> `[0–499]` and `[501–max]` pass validation, but rating 500 would not be covered — players with
> that rating would be excluded from all buckets. The error message text mentions "gaps or overlaps"
> but only overlaps are actually detected. In practice, gaps are avoided by either omitting
> `MaxRating` (letting `InitializeGrouping` compute exact boundaries) or by carefully setting
> adjacent values. **This should be fixed** — the check should enforce exact contiguity:
> `bracket[i].MaxRating == bracket[i+1].MinRating − 1`.

### 3. MaxGroupCount checks

| # | Rule | Error message (template) |
|---|---|---|
| 10 | `MaxGroupCount ≥ 1` (when set) | "MaxGroupCount must be at least 1." |
| 11 | `MaxGroupCount ≥` number of brackets (when set) | "MaxGroupCount ({value}) must be at least equal to the number of brackets ({count})." |
| 12 | `MaxGroupCount ≤ 100` (when set) | "MaxGroupCount should not exceed 100." |

---

## Matchmaking Process

Matchmaking is invoked only for **Competitions** (`KindId = Competition`). For all other
tournament types, or when no `Grouping` section is present in the config,
`ProcessGrouping` returns an **empty array** (`TournamentGroup[] {}`), the tournament starts
normally without any player grouping, and all participants compete together.

When grouping **is** configured for a Competition, the process is orchestrated by
`ProcessGrouping` in `MatchmakingLogic.cs`. It proceeds in a configuration extraction step
(Stage 0) followed by four algorithm stages (Stages 1–4):

```
ProcessGrouping                          (public entry point)
  ├── ProcessGroupingForTournament       (extract config, fetch participants)
  │   └── ProcessGroupingByRule          (core algorithm, testable)
  │       ├── ProcessBucketsByRule       (Stage 1-2: bucket creation & balancing)
  │       │   ├── CreateBuckets          (Stage 1)
  │       │   └── BalanceBuckets         (Stage 2)
  │       │       ├── Phase A: PingPongTraversalIterator
  │       │       │   └── RefreshBucket
  │       │       └── Phase B: linear merge
  │       │           └── RefreshBucket
  │       └── ProcessGroupsByRule        (Stage 3: group creation)
  │           └── BuildGroups
  │               ├── PartitionAllBuckets
  │               │   ├── IsNoSplitBucket        (no-split evaluation)
  │               │   ├── ComputeGroupCount      (per-bucket mode)
  │               │   ├── AllocateGroupBudget    (MaxGroupCount mode / FFS)
  │               │   │   └── IsNoSplitBucket    (no-split evaluation)
  │               │   └── PartitionBucket        (split bucket → N groups)
  │               ├── ReassignGroupsToBuckets    (re-evaluate parent brackets)
  │               └── GetGroupNameByIndex        (assign A, B, C... names)
  └── AssignGroupsToParticipants         (Stage 4: persist to DB)
```

**Return value semantics:**
* **Empty array** (`TournamentGroup[] {}`) — grouping is not applicable (non-Competition kind
  or no `Grouping` config). Tournament starts normally without groups.
* **Non-empty array** — grouping succeeded. Each element is a `TournamentGroup` with participants.
* **`null`** — grouping was configured but failed (e.g. not enough players to form even one
  valid group). This value originates in `ProcessGroupsByRule`, which converts an empty array
  from `BuildGroups` into `null`. The calling code cancels the entire tournament.

### Stage 0: Extracting Configuration

1. The system verifies that the tournament type (`KindId`) is `Competition` and that a valid
   `TournamentGroupingRule` is present. If either condition is not met, an empty array is
   returned — no grouping is needed.
2. **`InitializeGrouping`** computes bracket boundaries when `MaxRating` is omitted (0): it
   processes brackets in descending `MinRating` order (via a local sorted copy — the original
   list order is preserved), assigns `int.MaxValue` to the highest bracket, and
   `(next bracket's MinRating − 1)` to each subsequent one. Brackets with explicitly set
   `MaxRating` are left unchanged.

   > **Execution path note:** `InitializeGrouping` is called only from
   > `TournamentsHelper.FromDto(TournamentTemplateDto)` — the WebAdmin template-loading path
   > (used by validation and config editing). The **runtime matchmaking path**
   > (`ProcessGrouping` → `FromDto(TournamentDto)`) does **not** call `InitializeGrouping`.
   > This means the JSON config stored in the database must contain explicit `MaxRating` values
   > for all brackets. In practice, this is ensured by always specifying `MaxRating` in the
   > tournament configuration (including the sentinel `2147483647` for the highest bracket).
3. The full list of tournament participants is fetched via `ITournamentProvider`.
4. Participants are sorted in **ascending** order by `CompetitionRating`.
5. Participants are mapped into `TournamentGroupParticipant` objects, retaining `UserId` and
   `CompetitionRating`.

### Stage 1: Creating Buckets (`CreateBuckets`)

The algorithm distributes participants into `TournamentBucket` objects based on the defined
rating brackets:

* A `TournamentBucket` is created for each bracket defined in the configuration, ordered by
  `MinRating` ascending.
* Participants are assigned to a bucket if their `CompetitionRating` falls within the bucket's
  `[MinRating, MaxRating]` range (inclusive).
* Assigned participants are removed from the candidate pool to prevent double-assignment if
  brackets overlap.
* Within each bucket, participants are sorted by rating ascending, and the bucket's aggregate
  rating statistics (`MinParticipantRating`, `MaxParticipantRating`) are computed.

### Stage 2: Balancing Buckets (`BalanceBuckets`)

A balancing mechanism ensures every bucket meets the `MinSize` requirement. Balancing is
skipped when there is only one bracket.

#### Phase A: Ping-Pong Traversal

The system uses a `PingPongTraversalIterator` to traverse the buckets in an outside-in pattern:

* Each bucket is visited exactly once.
* The algorithm visits the first bucket, then the last, then the second, then the second-to-last,
  and so on.
* **Skipped buckets:** Empty buckets and buckets already at or above `MinSize` are skipped
  (no action needed).
* **Incomplete bucket processing:** If a bucket is non-empty but below `MinSize`:
    * The algorithm looks for participants in **adjacent unvisited** buckets and pulls them
      one at a time.
    * The selection direction is driven by the iterator's `CurrentIsOnTheLeft` property:
      when `true` (current bucket is on the weaker/left side), the algorithm takes the
      participant at index 0 (lowest rating) from the stronger neighbor; when `false`,
      it takes the last participant (highest rating) from the weaker neighbor. In both
      cases, this selects the participant closest to the current bucket's rating range.
    * Participants are pulled one at a time from the adjacent bucket until it is fully
      drained or the current bucket reaches `MinSize`. If the adjacent bucket is exhausted
      and the current bucket is still incomplete, the search advances to the **next adjacent**
      bucket in the same direction.
    * If an already-visited bucket is encountered during the search, the search **stops**
      (visited buckets are considered complete and sealed).
    * This continues until the current bucket reaches `MinSize` or no more unvisited adjacent
      participants are available.
* After any participant movement, the affected bucket is **refreshed**: participants are re-sorted
  by rating and aggregate statistics are recalculated.
* At most one bucket may remain incomplete after Phase A — the last one visited in the traversal.

**Example 1:** Three brackets: `[1]`, `[2]`, `[3]`.

| Visit order | Bucket visited | Can pull from (unvisited) |
|---|---|---|
| #1 | `[1]` | `[2]`, `[3]` |
| #2 | `[3]` | `[2]` |
| #3 | `[2]` | — (all visited) |

**Example 2:** Four brackets: `[1]`, `[2]`, `[3]`, `[4]`.

| Visit order | Bucket visited | Can pull from (unvisited) |
|---|---|---|
| #1 | `[1]` | `[2]`, `[3]`, `[4]` |
| #2 | `[4]` | `[3]`, `[2]` |
| #3 | `[2]` | `[3]` |
| #4 | `[3]` | — (all visited) |

**Example 3:** Five brackets: `[1]`, `[2]`, `[3]`, `[4]`, `[5]`.

| Visit order | Bucket visited | Can pull from (unvisited) |
|---|---|---|
| #1 | `[1]` | `[2]`, `[3]`, `[4]`, `[5]` |
| #2 | `[5]` | `[4]`, `[3]`, `[2]` |
| #3 | `[2]` | `[3]`, `[4]` |
| #4 | `[4]` | `[3]` |
| #5 | `[3]` | — (all visited) |

#### Phase B: Final Merging of Incomplete Buckets

After the traversal, if any bucket still has players but fewer than `MinSize`, it must be merged:

* The system iterates through all buckets and finds any that are incomplete
  (0 < count < `MinSize`).
* **Merge direction:** The incomplete bucket's participants are moved to the nearest **stronger**
  (higher-rated) non-empty bucket. This ensures weaker brackets are not filled with strong
  players — instead, the few remaining weak players "compete up."
* **Fallback:** If no stronger non-empty bucket exists, the system merges into the nearest
  **weaker** bucket.
* All participants are moved; the source bucket becomes empty.
* Both source and target buckets are refreshed after the merge.

At the conclusion of this stage, all non-empty buckets are guaranteed to have at least `MinSize`
participants.

### Stage 3: Creating Groups (`BuildGroups`)

After bucket balancing, each non-empty bucket is subdivided into one or more match-sized
**groups**. The system operates in one of two modes, determined by the `MaxGroupCount` parameter.

#### 3a. Determining Group Count

##### Per-Bucket Mode (when `MaxGroupCount` is not set)

Each bucket independently determines its group count via `ComputeGroupCount`:

1. **With `TargetSize`:** The algorithm computes a projected group count as
   `⌈participants / TargetSize⌉`, then uses a sequential override pattern starting from
   `projected + 1` (preferring more groups — smaller group sizes increase individual win
   probability):
    * Start with `projected + 1`.
    * Replace with `projected` if the increased count violates `MinSize` or is farther
      from `TargetSize`.
    * Replace with `projected − 1` (minimum 1) if `projected` itself violates
      `MinSize` or is farther from `TargetSize`. Note: this second check always
      compares the average for `projected` groups against `projected − 1`,
      regardless of what the first check decided.
    * If `MaxSize` is set, a final floor is enforced: at least
      `⌈participants / effectiveMaxSize⌉` groups, where
      `effectiveMaxSize = max(MaxSize, 2 × MinSize − 1)`.

2. **Without `TargetSize`, with `MaxSize`:** Group count =
   `max(1, ⌈participants / effectiveMaxSize⌉)`.

3. **Without `TargetSize` or `MaxSize`:** 1 group (no subdivision).

**No-split rule:** The lowest bracket (`MinRating = 0`) is never split into multiple groups if
it contains participants whose rating exceeds the bracket's `MaxRating` (i.e., players moved down
from stronger brackets during balancing). This prevents further fragmentation of mixed-rating
groups. Such buckets always get exactly 1 group, regardless of size.

##### MaxGroupCount Mode — FFS Algorithm (when `MaxGroupCount` is set)

When a global group cap is configured, the `AllocateGroupBudget` method distributes the available
group "budget" across all non-empty buckets using a three-phase optimization:

**Phase 1 — Maximize:** Start with the maximum possible groups per bucket:
`⌊participants / MinSize⌋` (minimum 1). No-split-locked buckets (lowest bracket containing
participants moved down from stronger brackets; see no-split rule above) are fixed at 1 group.

**Phase 2 — Reduce:** If total groups exceed `MaxGroupCount`, iteratively remove 1 group from
the bucket with the **smallest average group size** (the one with the most to gain from
consolidation). Tie-break: the **strongest** bucket (highest `MinRating`) is reduced first,
keeping weaker groups smaller. This continues until the total fits within the budget, or all
remaining buckets are at 1 group.

**Phase 3 — Rebalance (FFS: Free-Fill-Swap):** Iteratively optimize group distribution toward
`TargetSize`. Each iteration runs three sub-steps, repeating until no sub-step finds improvement:

* **Free:** In below-target buckets (average group size < `TargetSize`), reduce group count as
  long as each reduction brings the average closer to `TargetSize`. Each removed group frees
  1 budget slot.
* **Fill:** Give freed slots to above-target buckets (average group size > `TargetSize`) where
  an extra group would bring the average closer to `TargetSize`. The bucket **farthest** from
  target receives first. Tie-break: weaker bucket wins (buckets are ordered weakest-first;
  first match is kept). New groups must still meet `MinSize`.
* **Swap:** Transfer 1 group slot from a donor to a recipient if it reduces their combined
  distance to `TargetSize`. Budget-neutral (total group count unchanged). Uses exact rational
  arithmetic (`Rational` struct) to avoid floating-point precision loss. Cascading tie-break:
  (1) largest improvement, (2) weaker recipient preferred, (3) stronger donor preferred.

Convergence is mathematically guaranteed (total distance strictly decreases each iteration).
A safety cap of 100 iterations is enforced as a defensive measure.

#### 3b. Partitioning Buckets into Groups (`PartitionBucket`)

Once the group count for each bucket is determined, participants are distributed evenly:

* Participants are kept in their existing order (sorted by rating, weakest first).
* Base group size: `⌊participants / groupCount⌋`.
* Remainder participants (`participants mod groupCount`) are distributed to the **last**
  (stronger) groups — each receives 1 extra participant.

This means weaker groups are slightly smaller, stronger groups slightly larger — a deliberate
design choice that gives weaker players marginally better odds.

#### 3c. Reassigning Groups to Buckets (`ReassignGroupsToBuckets`)

After partitioning, group–bucket assignments are re-evaluated based on actual participant
composition:

1. All bucket participant lists are cleared.
2. For each group, the **upper-median** participant rating is computed (index `Count / 2`
   in the ascending-sorted list; for even-sized groups this picks the higher of the two
   middle values).
3. The group is assigned to the bracket whose `[MinRating, MaxRating]` range contains the median.
4. The `IsMoved` flag is set on any participant whose individual rating falls outside their
   group's new parent bracket range.
5. All bucket participants are re-sorted by rating and statistics are recalculated.

This handles the case where bucket balancing moved players across bracket boundaries — after
splitting, a group's composition may naturally belong to a different bracket.

#### 3d. Group Naming (`GetGroupNameByIndex`)

Groups are named sequentially in the order they appear (weakest bracket first, within each
bracket from weakest to strongest group): `A`, `B`, `C`, ..., `Z`, `AA`, `AB`, ..., following
the Excel column naming pattern.

### Stage 4: Assigning Groups to Participants (`AssignGroupsToParticipants`)

The final stage persists the grouping results to the database:

* For each group and each participant in that group, `ITournamentProvider.UpdateTournamentGroup`
  is called with 4 arguments: tournament ID, user ID, bracket ID (`BracketId`), and group name.
* The `UpdateTournamentGroup` method signature also accepts optional `isRated` (default `true`)
  and `isCanceled` (default `false`) parameters, but `AssignGroupsToParticipants` does not pass
  them — defaults are always used. See "Obsolete fields" note above.

**Edge cases:**
* If `ProcessGrouping` returns **`null`** (grouping was configured but failed), the assignment
  step is skipped, and the calling code (`TournamentStartAdapter`) cancels the entire tournament
  via `provider.CancelTournament()`. There is no partial cancellation — either all groups are
  formed, or the tournament does not start.
* If `ProcessGrouping` returns an **empty array** (grouping not applicable — non-Competition
  kind or no config), `AssignGroupsToParticipants` is still called (the `null` guard passes for
  empty arrays) but iterates over zero groups — effectively a no-op with no DB calls.

---

## Tournament Lifecycle Changes

### Start competition (`TournamentStartAdapter.StartTournaments`)

> The public entry point is `StartTournaments`, called by the tournament scheduler.
> Actual per-tournament processing happens in the private `StartTournamentAsync` method.

* Run the matchmaking process (Stages 0–4 above) via `MatchmakingLogic.ProcessGrouping`.
  Bracket assignment to participants is persisted to the database in Stage 4
  (`AssignGroupsToParticipants`).
* If `ProcessGrouping` returns `null` **or throws an exception**: cancel the entire tournament
  via `provider.CancelTournament()`.
* If `ProcessGrouping` returns an empty array: tournament starts normally without grouping
  (this is the case for non-Competition types or missing `Grouping` config).

### In competition (`GetCurrentTournamentResult`)

* The HUD shows standings **only within the player's own group**.
* The `GetCurrentTournamentResultHud` stored procedure determines the player's `GroupId` and
  `GroupName`, then filters results using a null-safe pattern:
  `WHERE (@GroupId IS NULL OR GroupId = @GroupId) AND (@GroupName IS NULL OR GroupName = @GroupName)`.
  When the player has no group assignment (both values are `NULL`), all results are returned
  (non-grouped competition). Ranks are computed within the group via
  `RANK() OVER (PARTITION BY GroupId, GroupName ...)`.
* If the player navigates to the competition menu, current results across all groups are shown.

### End competition (`TournamentEndAdapter.EndTournaments`)

* Calculate score, places, and rewards **inside each group** — the
  `EndTournamentAndCalculateResults` procedure computes ranks per group via
  `RANK() OVER (PARTITION BY GroupId, GroupName ...)`.
* Set rating increment for the place. Per-bracket `RatingMultiplier` and `RewardMultiplier`
  (see Bracket parameters above) are applied at this stage.
* Non-participating player handling: last place, no reward, penalty according to settings.
* Send results for all groups specifying Group ID and Name, sorted by group ascending,
  place descending.

### Results / Archive — Hall of Fame

* `GetFinalTournamentResult` / `GetTournamentSecondaryResult`: send results for all groups
  specifying the group in results, sorted by group ascending, place descending.

---

## Supporting Infrastructure

### `PingPongTraversalIterator<T>` (`Shared/SharedLib/Helpers/`)

A generic iterator that traverses an array in outside-in order: first, last, second,
second-to-last, etc. Provides `TryGetNextAdjacent()` for looking up neighboring elements from
the current position, and `IsIndexVisited()` for checking whether an element has already been
processed as a main traversal step. `CurrentIsOnTheLeft` indicates the direction of the current
element, which drives the adjacent-search direction and participant selection in `BalanceBuckets`.

### `Rational` struct (`Shared/SharedLib/Helpers/`)

An exact rational number representation as a numerator/denominator pair. Supports comparison
via cross-multiplication (avoiding floating-point precision loss) and basic arithmetic (`+`, `−`).
Used in the FFS algorithm's swap improvement calculation (`ComputeSwapImprovement`) and Phase 2
average comparison. Overflow-safe for numerators and denominators up to ~10⁹ (cross-products
fit in `long`); `checked` arithmetic throws `OverflowException` if exceeded. In the context
of the FFS algorithm, this translates to safe operation for group counts up to ~130 per bucket
(the `MaxGroupCount ≤ 100` validation guard provides additional margin).
