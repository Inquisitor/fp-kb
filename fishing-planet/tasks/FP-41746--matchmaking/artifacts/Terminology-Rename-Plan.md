# TRM-001 + TRM-002: Terminology Unification — Full Rename

> **Date:** 2026-02-18
> **Branch:** LBM20251201
> **Related:** [Matchmaking-Alignment-Plan.md](Matchmaking-Alignment-Plan.md)

## Context

The matchmaking system uses inconsistent terminology across GDD, TDD, and code. Decision: rename everything
in code + documentation, preserving JSON compatibility via `[JsonProperty]`.

| Concept                | Unified term | Code (current)            | Code (new)          |
|------------------------|--------------|---------------------------|---------------------|
| Rating range config    | **Bracket**  | `TournamentGroupSettings` | `TournamentBracket` |
| Rating-based container | **Bucket**   | `TournamentGroup`         | `TournamentBucket`  |
| Final competition unit | **Group**    | `TournamentSubgroup`      | `TournamentGroup`   |

---

## Part 1: Code Renames (ReSharper Refactor-Rename)

### IMPORTANT: Rename order (name collision!)

`TournamentGroup` is currently taken. Must rename in two steps:

1. **Step 1:** `TournamentGroup` → `TournamentBucket`
2. **Step 2:** `TournamentSubgroup` → `TournamentGroup`

---

### A. Types (classes)

| #  | Current name                 | New name            | File                                                  | Affected files |
|----|------------------------------|---------------------|-------------------------------------------------------|----------------|
| T1 | `TournamentGroupSettings`    | `TournamentBracket` | ObjectModel/Tournaments/TournamentGroupSettings.cs    | 4 files        |
| T2 | `TournamentGroup`            | `TournamentBucket`  | ObjectModel/Tournaments/TournamentGroup.cs            | 5 files        |
| T3 | `TournamentSubgroup`         | `TournamentGroup`   | ObjectModel/Tournaments/TournamentSubgroup.cs         | 5 files        |
| T4 | `TournamentGroupParticipant` | **keep**            | ObjectModel/Tournaments/TournamentGroupParticipant.cs | —              |
| T5 | `TournamentGroupingRule`     | **keep**            | ObjectModel/Tournaments/TournamentGroupingRule.cs     | —              |

---

### B. Properties and fields

| #  | Class (current)               | Property (current) | New name      | JSON?                             | Notes                                       |
|----|-------------------------------|--------------------|---------------|-----------------------------------|---------------------------------------------|
| P1 | `TournamentGroupSettings`     | `GroupId`          | `BracketId`   | `[JsonProperty("GroupId")]`       | Also a DB column — **do not change in SQL** |
| P2 | `TournamentGroupSettings`     | `GroupName`        | `BracketName` | `[JsonProperty("GroupName")]`     | Also a DB column                            |
| P3 | `TournamentGroupingRule`      | `Groups`           | `Brackets`    | `[JsonProperty("Groups")]`        | List of brackets                            |
| P4 | `TournamentGroup` (→Bucket)   | `Subgroups`        | `Groups`      | No (not serialized)               | List of final groups                        |
| P5 | `TournamentSubgroup` (→Group) | `GroupId`          | `BracketId`   | Map in DAL to DB column `GroupId` | FK to parent bracket                        |

### Additional `GroupId`/`GroupName` properties in other classes (DB/Results):

**Decision: rename + add column mapping attributes.**
**Update:** DEFERRED during execution — see Execution Status below.

| #   | Project       | Namespace                   | Class                            | Property  | New name    | Column mapping             |
|-----|---------------|-----------------------------|----------------------------------|-----------|-------------|----------------------------|
| P6  | ObjectModel   | *(global)*                  | `PlayerFinalResult`              | `GroupId` | `BracketId` | map to DB column `GroupId` |
| P7  | ObjectModel   | `ObjectModel`               | `TournamentIndividualResults`    | `GroupId` | `BracketId` | map to DB column `GroupId` |
| P8  | ObjectModel   | `ObjectModel.Tournaments`   | `TournamentSecondaryResult`      | `GroupId` | `BracketId` | map to DB column `GroupId` |
| P9  | Sql.Interface | `Sql.Interface.Tournaments` | `ParticipantItemDto`             | `GroupId` | `BracketId` | map to DB column `GroupId` |
| P10 | Sql.Interface | `Sql.Interface.Tournaments` | `TournamentIndividualResultsDto` | `GroupId` | `BracketId` | map to DB column `GroupId` |
| P11 | Sql.Interface | `Sql.Interface.Tournaments` | `TournamentParticipantDto`       | `GroupId` | `BracketId` | map to DB column `GroupId` |
| P12 | Sql.Interface | `Sql.Interface.Tournaments` | `TournamentSecondaryResultDto`   | `GroupId` | `BracketId` | map to DB column `GroupId` |
| P13 | ObjectModel   | `ObjectModel`               | `ProfileTournament`              | `GroupId` | `BracketId` | populated from DTO in code |
| P14 | WebAdmin      | `WebAdmin.Models`           | `ParticipantItem`                | `GroupId` | `BracketId` | populated from DTO in code |

> **Note 1:** The mapping mechanism depends on the ORM/DAL pattern. If DTOs are read via DataReader, the mapping
> may live in `SqlTournamentProvider` code rather than via an attribute.
>
> **Note 2:** All classes P6-P14 also have a `GroupName` property. Despite the name, `GroupName` stores
> the name of the **final group** (not the bracket). In the unified terminology "Group" is the correct
> term for this concept, so `GroupName` does **not** need to be renamed to `BracketName` — it should
> stay as `GroupName` or be left for separate consideration during TRM-003.

---

### C. Methods

| #   | Class/File            | Current name                                     | New name                 | Notes                                      |
|-----|-----------------------|--------------------------------------------------|--------------------------|--------------------------------------------|
| M1  | `MatchmakingLogic`    | `CreateGroups()`                                 | `CreateBuckets()`        | Creates buckets                            |
| M2  | `MatchmakingLogic`    | `BalanceGroups()`                                | `BalanceBuckets()`       | Balances buckets                           |
| M3  | `MatchmakingLogic`    | `RefreshGroup()`                                 | `RefreshBucket()`        | Refreshes a bucket                         |
| M4  | `MatchmakingLogic`    | `MakeSubgroups()`                                | `MakeGroups()`           | Creates groups from buckets                |
| M5  | `MatchmakingLogic`    | `CreateSubgroups()`                              | `CreateGroups()`         | Creates groups for a single bucket         |
| M6  | `MatchmakingLogic`    | `ProcessTopLevelGroupsByRule()`                  | `ProcessBucketsByRule()` |                                            |
| M7  | `MatchmakingLogic`    | `ProcessSubgroupsByRule()`                       | `ProcessGroupsByRule()`  |                                            |
| M8  | `MatchmakingLogic`    | `ProcessGroupingByRule()`                        | keep                     | "Grouping" is a neutral term               |
| M9  | `MatchmakingLogic`    | `ProcessGrouping()`                              | keep                     | Neutral                                    |
| M10 | `MatchmakingLogic`    | `InitializeGrouping()`                           | keep                     | Neutral                                    |
| M11 | `MatchmakingLogic`    | `AssignGroupsToParticipants()`                   | keep                     | "Groups" is correct — assigns final groups |
| M12 | `MatchmakingLogic`    | `FindFirstAdjacentIncompleteGroupsCombination()` | N/A                      | Dead code (DCD-003), will be deleted       |
| M13 | `ITournamentProvider` | `UpdateTournamentGroup()`                        | keep                     | "Group" is correct in new terminology      |

---

### D. Local variables and parameters (manual edits)

Key patterns that ReSharper will rename:

- `groups` → `buckets` (in `BalanceGroups` → `BalanceBuckets`, `MakeSubgroups` → `MakeGroups`, `CreateGroups` →
  `CreateBuckets`)
- `group` → `bucket` (in loops)
- `subgroup` / `subgroups` → `group` / `groups`
- `currentGroup` → `currentBucket` (in `BalanceGroups` → `BalanceBuckets`)
- `targetGroup` → `targetBucket` (in Phase B)
- `adjacentGroup` → `adjacentBucket`
- `parentGroup` → `parentBucket` (in `MakeSubgroups` → `MakeGroups`)
- `groupsList` → `bucketsList`
- `modifiedGroup` → `modifiedBucket` (in `RefreshGroup` → `RefreshBucket`)

---

### E. Tests

Affected test files:

- `SharedLib.Tests/Tournaments/MatchmakingLogicTests.cs` — all test methods with "Group"/"Subgroup" in names
- `SharedLib.Tests/Tournaments/Helpers/MatchmakingTestCase.cs` — test helper

Test methods to rename:

- `Test_CreateGroups_WorksProperly` → `Test_CreateBuckets_WorksProperly`
- `Test_MakingTopLevelGroups_*` → `Test_MakingBuckets_*`
- `Test_MakeSubgroups` → `Test_MakeGroups`
- `Test_CreateSubgroups_*` → `Test_CreateGroups_*`
- `CreateSubgroups_LowRatingProtectionIsOn_*` → (will be deleted/renamed — TST-003)
- `InitializeGrouping_*` → keep

---

## Part 2: JSON Preservation (`[JsonProperty]`)

Add `[JsonProperty]` to properties serialized in JSON config:

```csharp
// TournamentBracket (was TournamentGroupSettings)
[JsonProperty("GroupId")]
public int BracketId { get; set; }

[JsonProperty("GroupName")]
public string BracketName { get; set; }

// TournamentGroupingRule
[JsonProperty("Groups")]
public List<TournamentBracket> Brackets { get; set; }
```

Requires: `using Newtonsoft.Json;`

---

## Part 3: DB Boundary — No changes in SQL

SQL stored procedures (17 total) and DB column names (`GroupId`, `GroupName`, `IsRated`) — **do not change**.
DTO/Results classes (P6-P12) — **deferred** (see Execution Status and TRM-003
in [Alignment Plan](Matchmaking-Alignment-Plan.md)).

---

## Part 4: TDD — Replacement list for Confluence

*(~39 replacements — detailed list to be prepared separately. TODO, part of TRM-001 TDD action.)*

---

## Execution Order

1. [x] **Approve** names (this table)
2. [x] **Step 1:** ReSharper Rename `TournamentGroup` → `TournamentBucket` (+ properties, methods)
3. [x] **Step 2:** ReSharper Rename `TournamentSubgroup` → `TournamentGroup` (+ properties, methods)
4. [x] **Step 3:** ReSharper Rename `TournamentGroupSettings` → `TournamentBracket` (+ properties)
5. [x] **Manual edits:** `[JsonProperty]` attributes, local variables, comments
6. [x] **Build + Tests**
7. [ ] **TDD on Confluence** — apply replacement list (Part 4)
8. [ ] **Update local .md** copies
9. [x] **Alignment Plan** → TRM-001/TRM-002 statuses updated

## Execution Status

> **Executed:** 2026-02-18
> **Build:** Passed
> **Tests:** All matchmaking tests passed

### A. Types — DONE

| #  | Rename                                          | Status | Method                 |
|----|-------------------------------------------------|--------|------------------------|
| T1 | `TournamentGroupSettings` → `TournamentBracket` | DONE   | ReSharper + SVN rename |
| T2 | `TournamentGroup` → `TournamentBucket`          | DONE   | ReSharper + SVN rename |
| T3 | `TournamentSubgroup` → `TournamentGroup`        | DONE   | ReSharper + SVN rename |
| T4 | `TournamentGroupParticipant` — keep             | N/A    | —                      |
| T5 | `TournamentGroupingRule` — keep                 | N/A    | —                      |

### B. Properties P1-P5 — DONE

| #  | Rename                                       | Status | Notes                                |
|----|----------------------------------------------|--------|--------------------------------------|
| P1 | `GroupId` → `BracketId`                      | DONE   | + `[JsonProperty("GroupId")]`        |
| P2 | `GroupName` → `BracketName`                  | DONE   | + `[JsonProperty("GroupName")]`      |
| P3 | `Groups` → `Brackets`                        | DONE   | + `[JsonProperty("Groups")]`         |
| P4 | `Subgroups` → `Groups`                       | DONE   | Not serialized                       |
| P5 | `GroupId` → `BracketId` (on TournamentGroup) | DONE   | Mapped in DAL to DB column `GroupId` |

### B (cont.). Properties P6-P14 — DEFERRED

**Decision:** NOT renamed. Kept as `GroupId` / `GroupName`.

**Reason (DTO classes P9-P12):** The custom DAL mapper `RestoreObjectFromReader` in `DtoExtensions.cs`
uses reflection to map DB column names to C# property names by **exact name match**. It does not support
any mapping attributes (no `[Column]`, no `[JsonProperty]`). Renaming DTO properties to `BracketId` would
break all DAL reads because the DB column remains `GroupId`.

**Reason (model classes P6-P8, P13-P14):** These classes are not read from DB directly, but populated
from DTOs via `MakeCloneOf` / `MakeEqualTo`, which also use reflection with **exact property name
matching**. Renaming model properties without renaming corresponding DTO properties would silently
break the copy.

**To unblock P6-P14:** The DAL mapper must be enhanced to support column mapping attributes (e.g.
`[Column("GroupId")]`), or the DB columns must be renamed (which requires SQL migration + stored
procedure updates). Both options are out of scope for TRM-002 and should be a separate work item.
The question requires detailed investigation as part of TRM-003.

| #   | Project       | Namespace                   | Class                            | Property  | Status   |
|-----|---------------|-----------------------------|----------------------------------|-----------|----------|
| P6  | ObjectModel   | *(global)*                  | `PlayerFinalResult`              | `GroupId` | DEFERRED |
| P7  | ObjectModel   | `ObjectModel`               | `TournamentIndividualResults`    | `GroupId` | DEFERRED |
| P8  | ObjectModel   | `ObjectModel.Tournaments`   | `TournamentSecondaryResult`      | `GroupId` | DEFERRED |
| P9  | Sql.Interface | `Sql.Interface.Tournaments` | `ParticipantItemDto`             | `GroupId` | DEFERRED |
| P10 | Sql.Interface | `Sql.Interface.Tournaments` | `TournamentIndividualResultsDto` | `GroupId` | DEFERRED |
| P11 | Sql.Interface | `Sql.Interface.Tournaments` | `TournamentParticipantDto`       | `GroupId` | DEFERRED |
| P12 | Sql.Interface | `Sql.Interface.Tournaments` | `TournamentSecondaryResultDto`   | `GroupId` | DEFERRED |
| P13 | ObjectModel   | `ObjectModel`               | `ProfileTournament`              | `GroupId` | DEFERRED |
| P14 | WebAdmin      | `WebAdmin.Models`           | `ParticipantItem`                | `GroupId` | DEFERRED |

> **Note:** All classes P6-P14 also have a `GroupName` property. `GroupName` stores the name of
> the **final group** (not the bracket), so it is already correct in the unified terminology and
> does **not** need to be renamed. See Note 2 in Part 1.
>
> **XML doc (2026-02-21):** Added `/// <summary>` XML doc comments to `GroupId` and `GroupName`
> on all 9 classes (P6-P14), explaining their semantic meaning in unified terminology:
> `GroupId` → bracket ID (with `see cref` to `TournamentBracket.BracketId` where resolvable);
> `GroupName` → final group name, not bracket name.

#### Implications: Boundary points between `BracketId` (renamed) and `GroupId` (deferred)

Since the rename was partial, the codebase now has both `BracketId` and `GroupId` referring to
the same DB column value. The following is an exhaustive list of all boundary points.
Verified as safe on 2026-02-18; validated point-by-point on 2026-02-21.

**Type A — Direct comparisons `BracketId == GroupId` (renamed vs deferred):**

| #  | File                      | Line | Expression                                                         | Left (renamed)         | Right (deferred)                     |
|----|---------------------------|------|--------------------------------------------------------------------|------------------------|--------------------------------------|
| A1 | `TournamentsHelper.cs`    | 160  | `b.BracketId == result.GroupId`                                    | `TournamentBracket` P1 | `TournamentIndividualResultsDto` P10 |
| A2 | `TournamentEndAdapter.cs` | 817  | `b.BracketId == tournamentFinalResult.CurrentPlayerResult.GroupId` | `TournamentBracket` P1 | `PlayerFinalResult` P6               |

**Type B — Write path: `BracketId` → DB column `GroupId`:**

| #  | File                  | Line | Expression                                                     | Notes                                                                               |
|----|-----------------------|------|----------------------------------------------------------------|-------------------------------------------------------------------------------------|
| B1 | `MatchmakingLogic.cs` | 448  | `UpdateTournamentGroup(..., group.BracketId, group.Name, ...)` | `TournamentGroup.BracketId` (P5) → param `groupId` → SQL `SET [GroupId] = @groupId` |

**Type C — Internal renamed code (`BracketId` ← `BracketId`):**

| #  | File                  | Line | Expression                                             |
|----|-----------------------|------|--------------------------------------------------------|
| C1 | `MatchmakingLogic.cs` | 258  | `group.BracketId = parentBucket.BracketId`             |
| C2 | `MatchmakingLogic.cs` | 401  | `new TournamentGroup { BracketId = bucket.BracketId }` |

**Type D — Internal deferred code (`GroupId` ← `GroupId`, explicit assignments):**

| #  | File                      | Line    | Expression                                          | Classes (deferred) |
|----|---------------------------|---------|-----------------------------------------------------|--------------------|
| D1 | `TournamentAdapter.cs`    | 434–435 | `profileTournament.GroupId = participant.GroupId`   | P13 ← P11          |
| D2 | `TournamentEndAdapter.cs` | 501–502 | `GroupId = place.GroupId` (PlayerFinalResult init)  | P6 ← P10           |
| D3 | `TournamentEndAdapter.cs` | 726–727 | `GroupId = participant.GroupId` (secondary winners) | P6 ← P10           |

**Type E — Implicit copy via `MakeCloneOf` / `MakeEqualTo` (deferred ← deferred):**

| #  | File                                                         | Line(s)            | Copy                                           | Classes (deferred) |
|----|--------------------------------------------------------------|--------------------|------------------------------------------------|--------------------|
| E1 | `GameClientPeer_Tournaments.cs`                              | 367, 463, 553, 594 | `TournamentIndividualResults.MakeCloneOf(dto)` | P7 ← P10           |
| E2 | `TournamentAdapter.cs`                                       | 1721, 1735         | `TournamentSecondaryResult.MakeEqualTo(dto)`   | P8 ← P12           |
| E3 | `ReviewTournamentModel.cs` / `ReviewUserCompetitionModel.cs` | 65 / 175           | `ParticipantItem.MakeEqualTo(dto)`             | P14 ← P9           |
| E4 | `TournamentEndAdapter.cs`                                    | 565                | `PlayerFinalResult.MakeCloneOf(playerResult)`  | P6 ← P6            |

**Summary:**

| Type | Count | Description                                     | Status    |
|------|-------|-------------------------------------------------|-----------|
| A    | 2     | `BracketId == GroupId` (cross-terminology)      | Validated |
| B    | 1     | `BracketId` → DB `GroupId` (write path)         | Validated |
| C    | 2     | `BracketId` ← `BracketId` (internal renamed)    | Validated |
| D    | 3     | `GroupId` ← `GroupId` (internal deferred)       | Validated |
| E    | 5+    | `MakeCloneOf`/`MakeEqualTo` (internal deferred) | Validated |

All boundary points validated. The partial rename does not break any data flow.

### C. Methods — DONE

| #   | Rename                                                     | Status |
|-----|------------------------------------------------------------|--------|
| M1  | `CreateGroups()` → `CreateBuckets()`                       | DONE   |
| M2  | `BalanceGroups()` → `BalanceBuckets()`                     | DONE   |
| M3  | `RefreshGroup()` → `RefreshBucket()`                       | DONE   |
| M4  | `MakeSubgroups()` → `MakeGroups()`                         | DONE   |
| M5  | `CreateSubgroups()` → `CreateGroups()`                     | DONE   |
| M6  | `ProcessTopLevelGroupsByRule()` → `ProcessBucketsByRule()` | DONE   |
| M7  | `ProcessSubgroupsByRule()` → `ProcessGroupsByRule()`       | DONE   |
| M8  | `ProcessGroupingByRule()` — keep                           | N/A    |
| M9  | `ProcessGrouping()` — keep                                 | N/A    |
| M10 | `InitializeGrouping()` — keep                              | N/A    |
| M11 | `AssignGroupsToParticipants()` — keep                      | N/A    |
| M12 | Dead code (DCD-003) — not renamed                          | N/A    |
| M13 | `UpdateTournamentGroup()` — keep                           | N/A    |

### D. Local variables — DONE

All local variables, constants, lambda parameters, and comments renamed manually in:

- `MatchmakingLogic.cs` — all methods
- `MatchmakingLogicTests.cs` — all test methods, constants, helper methods
- `MatchmakingTestCase.cs` — inner classes, properties, methods
- `TournamentStartAdapter.cs` — `StartTournamentAsync`
- `TournamentEndAdapter.cs` — reward calculation section
- `TournamentsHelper.cs` — rating calculation section

### E. Tests — DONE

All 9 test methods renamed. Helper methods renamed. Constants renamed (12 `*GroupId` → `*BracketId`).

**Note:** `[DataRow]` description strings (e.g. `"[001] 20/20/20"`) were intentionally left as-is.
They will be updated in a separate comment cleanup pass.

### JSON Preservation (Part 2) — DONE

`[JsonProperty]` attributes added to `BracketId`, `BracketName`, and `Brackets` properties.

### Files modified

- `ObjectModel/Tournaments/TournamentBracket.cs` (was TournamentGroupSettings.cs)
- `ObjectModel/Tournaments/TournamentBucket.cs` (was TournamentGroup.cs)
- `ObjectModel/Tournaments/TournamentGroup.cs` (was TournamentSubgroup.cs)
- `ObjectModel/Tournaments/TournamentGroupingRule.cs`
- `SharedLib/Tournaments/MatchmakingLogic.cs`
- `SharedLib/Tournaments/TournamentStartAdapter.cs`
- `SharedLib/Tournaments/TournamentEndAdapter.cs`
- `SharedLib/Tournaments/TournamentsHelper.cs`
- `SharedLib.Tests/Tournaments/MatchmakingLogicTests.cs`
- `SharedLib.Tests/Tournaments/Helpers/MatchmakingTestCase.cs`

---

## Decisions on Open Questions

1. **T4:** `TournamentGroupParticipant` — **keep** (correct in new terminology)
2. **T5:** `TournamentGroupingRule` — **keep** (neutral name)
3. **P5:** `TournamentSubgroup.GroupId` → **`BracketId`** (map in DAL to DB column `GroupId`)
4. **P6-P12:** `GroupId`/`GroupName` in Results/DTOs — **DEFERRED** (custom DAL mapper has no column mapping attribute
   support; see Execution Status above)
5. **M13:** `UpdateTournamentGroup()` — **keep** ("Group" is correct in new terminology)