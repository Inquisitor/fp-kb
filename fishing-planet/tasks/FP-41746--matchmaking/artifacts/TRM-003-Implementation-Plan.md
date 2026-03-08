# TRM-003: Full DB Rename — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rename `GroupId` → `BracketId` across DB, stored procedures, JSON configs, and C# code.
Remove unused `IsRated` (DCD-004) and `IsCanceled` chain (DCD-005) alongside.

**Architecture:** Bottom-up by layer: SQL migration patch → SP files → C# code.
Atomic deployment with downtime — all changes ship together.

**Tech Stack:** SQL Server (sp_rename, REPLACE), C# 9 / .NET Framework 4.7.2, Newtonsoft.Json

**Design:** [TRM-003-DB-Rename-Design.md](TRM-003-DB-Rename-Design.md)

---

## Task 0: Diagnostic Queries (manual, on DEV/Prod)

**Purpose:** Validate assumptions before writing migration code.

Run on Prod (read-only):
```sql
-- 1. Confirm GroupId columns are empty (no data)
SELECT 'TournamentIndividualResults' AS T, COUNT(*) AS Cnt FROM TournamentIndividualResults WHERE GroupId IS NOT NULL
UNION ALL
SELECT 'TournamentParticipants',      COUNT(*) FROM TournamentParticipants      WHERE GroupId IS NOT NULL
UNION ALL
SELECT 'TournamentStats',             COUNT(*) FROM TournamentStats             WHERE GroupId IS NOT NULL
UNION ALL
SELECT 'TournamentSecondaryResult',   COUNT(*) FROM TournamentSecondaryResult   WHERE GroupId IS NOT NULL

-- 2. Row counts for UPDATE ConfigJson time estimation
SELECT 'Tournaments'         AS T, COUNT(*) AS Cnt FROM Tournaments
UNION ALL
SELECT 'TournamentTemplates',  COUNT(*) FROM TournamentTemplates
UNION ALL
SELECT 'ArchiveTournaments',   COUNT(*) FROM ArchiveTournaments
```

Run on DEV:
```sql
-- 3. Find ALL DB objects referencing GroupId (compare with 18 known SP files)
EXEC FindObjectsByText 'GroupId'

-- 4. Verify TournamentStats.GroupId exists (ArchiveTournamentStats already dropped it)
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('TournamentStats', 'ArchiveTournamentStats')
  AND COLUMN_NAME = 'GroupId'
```

**Blockers:** If GroupId has data → investigate before proceeding.
If FindObjectsByText reveals unknown objects → add to SP update list.

---

## Task 1: SQL Migration Patch

**Files:**
- Create: `SQL/Patches/LBM.M.YYYY.MM.DD-NNN.sql` (date TBD at execution time)

**Step 1: Write the migration patch**

The patch must be idempotent (IF EXISTS guards). Contents:

```sql
USE [Main]
GO

-- Idempotency guard
IF EXISTS (SELECT 1 FROM [dbo].[AppliedPatches] WHERE [PatchName] = 'LBM.M.YYYY.MM.DD-NNN')
BEGIN
    PRINT 'Script was already applied, canceling execution!'
    SET NOEXEC ON
END
GO

-- ============================================================
-- TRM-003: Rename [GroupId] → [BracketId]
-- ============================================================

-- Active tables
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_NAME = 'TournamentIndividualResults' AND COLUMN_NAME = 'GroupId')
    EXEC sp_rename 'TournamentIndividualResults.GroupId', 'BracketId', 'COLUMN';
GO

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_NAME = 'TournamentParticipants' AND COLUMN_NAME = 'GroupId')
    EXEC sp_rename 'TournamentParticipants.GroupId', 'BracketId', 'COLUMN';
GO

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_NAME = 'TournamentSecondaryResult' AND COLUMN_NAME = 'GroupId')
    EXEC sp_rename 'TournamentSecondaryResult.GroupId', 'BracketId', 'COLUMN';
GO

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_NAME = 'TournamentStats' AND COLUMN_NAME = 'GroupId')
    EXEC sp_rename 'TournamentStats.GroupId', 'BracketId', 'COLUMN';
GO

-- Archive tables
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_NAME = 'ArchiveTournamentIndividualResults' AND COLUMN_NAME = 'GroupId')
    EXEC sp_rename 'ArchiveTournamentIndividualResults.GroupId', 'BracketId', 'COLUMN';
GO

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_NAME = 'ArchiveTournamentParticipants' AND COLUMN_NAME = 'GroupId')
    EXEC sp_rename 'ArchiveTournamentParticipants.GroupId', 'BracketId', 'COLUMN';
GO

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_NAME = 'ArchiveTournamentSecondaryResult' AND COLUMN_NAME = 'GroupId')
    EXEC sp_rename 'ArchiveTournamentSecondaryResult.GroupId', 'BracketId', 'COLUMN';
GO

-- Note: ArchiveTournamentStats.GroupId was already dropped in GRM.M.2024.05.30-019

-- ============================================================
-- TRM-003: Update JSON configs
-- ============================================================

UPDATE [Tournaments] SET [ConfigJson] =
    REPLACE(REPLACE(REPLACE([ConfigJson],
        '"Groups"',    '"Brackets"'),
        '"GroupId"',   '"BracketId"'),
        '"GroupName"', '"BracketName"')
WHERE [ConfigJson] LIKE '%"Groups"%';
GO

UPDATE [TournamentTemplates] SET [ConfigJson] =
    REPLACE(REPLACE(REPLACE([ConfigJson],
        '"Groups"',    '"Brackets"'),
        '"GroupId"',   '"BracketId"'),
        '"GroupName"', '"BracketName"')
WHERE [ConfigJson] LIKE '%"Groups"%';
GO

UPDATE [ArchiveTournaments] SET [ConfigJson] =
    REPLACE(REPLACE(REPLACE([ConfigJson],
        '"Groups"',    '"Brackets"'),
        '"GroupId"',   '"BracketId"'),
        '"GroupName"', '"BracketName"')
WHERE [ConfigJson] LIKE '%"Groups"%';
GO

-- ============================================================
-- DCD-004: Drop [IsRated] from TournamentParticipants
-- ============================================================

IF EXISTS (SELECT 1 FROM sys.default_constraints
           WHERE name = 'DF_TournamentParticipants_IsRated')
    ALTER TABLE [TournamentParticipants] DROP CONSTRAINT [DF_TournamentParticipants_IsRated];
GO

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_NAME = 'TournamentParticipants' AND COLUMN_NAME = 'IsRated')
    ALTER TABLE [TournamentParticipants] DROP COLUMN [IsRated];
GO

IF EXISTS (SELECT 1 FROM sys.default_constraints
           WHERE name = 'DF_ArchiveTournamentParticipants_IsRated')
    ALTER TABLE [ArchiveTournamentParticipants] DROP CONSTRAINT [DF_ArchiveTournamentParticipants_IsRated];
GO

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_NAME = 'ArchiveTournamentParticipants' AND COLUMN_NAME = 'IsRated')
    ALTER TABLE [ArchiveTournamentParticipants] DROP COLUMN [IsRated];
GO

-- ============================================================
-- Register patch
-- ============================================================

INSERT INTO [dbo].[AppliedPatches] VALUES ('LBM.M.YYYY.MM.DD-NNN');
GO

SET NOEXEC OFF
GO
```

**Notes:**
- `sp_rename` is metadata-only — instant regardless of table size
- `UPDATE ConfigJson` speed depends on row count (estimated from Task 0)
- DCD-005 (IsCanceled) — add to this patch after scope investigation

---

## Task 2: Update Stored Procedures (18 files)

**Files:** All in `SQL/Patches/Main/Procedures/`

**Replacement rules:**
- `[GroupId]` → `[BracketId]` (column references)
- `@GroupId` → `@BracketId` (parameters and local variables)
- Do NOT rename `[GroupName]` (stays as is — correct terminology)

### Files with actual changes (15):

| File | Changes |
|------|---------|
| `SaveTournamentResult.sql` | Param `@GroupId` → `@BracketId`, column refs |
| `CalcAndGetBiggestFishSecondaryResult.sql` | Column refs in INSERT, SELECT, PARTITION BY |
| `GetPlayerPlace.sql` | PARTITION BY |
| `GetCurrentPlayerPlace.sql` | 2× PARTITION BY |
| `EndTournamentAndCalculateResults.sql` | PARTITION BY |
| `GetTournamentResultHistory.sql` | 2× SELECT projection |
| `GetTournamentIndividualResultHistory.sql` | 2× SELECT projection |
| `GetTournamentResultHistoryTopN.sql` | 2× SELECT projection |
| `GetTournamentSecondaryResultHistory.sql` | 2× SELECT projection |
| `GetTournamentSecondaryResult.sql` | SELECT projection |
| `GetTournamentResultTopN.sql` | PARTITION BY, SELECT, ORDER BY |
| `GetTournamentResult.sql` | SELECT, ORDER BY |
| `GetCurrentTournamentResultTopN.sql` | Local var `@GroupId`, assignments, PARTITION BY, SELECT, WHERE, ORDER BY |
| `GetCurrentTournamentResultHud.sql` | Local var `@GroupId`, assignments, PARTITION BY, SELECT, WHERE |
| `GetCurrentTournamentResult.sql` | PARTITION BY, SELECT, ORDER BY |

### Files with only commented-out references (3):

| File | Action |
|------|--------|
| `GetTeamPlace.sql` | Rename in comment: `-- , [GroupId]` → `-- , [BracketId]` |
| `GetCurrentTournamentTeamResult.sql` | Same |
| `CalculateFinalTeamResult.sql` | Same |

**Step 1:** For each file, do find-replace `GroupId` → `BracketId` (case-sensitive).
Leave `GroupName` untouched.

**Step 2:** Review each file after replacement to verify correctness.

---

## Task 3: C# Code — TRM-003 (rename GroupId → BracketId)

### 3a. Rename properties in P6-P14 (9 classes)

**DTO classes (P9-P12):**

| File | Property | Line |
|------|----------|------|
| `Dal/Sql.Interface/Tournaments/ParticipantItemDto.cs` | `GroupId` → `BracketId` | ~15 |
| `Dal/Sql.Interface/Tournaments/TournamentIndividualResultsDto.cs` | `GroupId` → `BracketId` | ~40 |
| `Dal/Sql.Interface/Tournaments/TournamentParticipantDto.cs` | `GroupId` → `BracketId` | ~29 |
| `Dal/Sql.Interface/Tournaments/TournamentSecondaryResultDto.cs` | `GroupId` → `BracketId` | ~18 |

**Model classes (P6-P8):**

| File | Property | Line |
|------|----------|------|
| `Shared/ObjectModel/Tournaments/TournamentFinalResult.cs` | `PlayerFinalResult.GroupId` → `BracketId` | ~54 |
| `Shared/ObjectModel/Tournaments/TournamentIndividualResults.cs` | `GroupId` → `BracketId` | ~34 |
| `Shared/ObjectModel/Tournaments/TournamentSecondaryResult.cs` | `GroupId` → `BracketId` | ~18 |

**Runtime classes (P13-P14):**

| File | Property | Line |
|------|----------|------|
| `Shared/ObjectModel/Profile/ProfileTournament.cs` | `GroupId` → `BracketId` | ~21 |
| `WebAdmin/WebAdmin/Models/Tools/ReviewTournamentModel.cs` | `ParticipantItem.GroupId` → `BracketId` | ~194 |

**For each class:**
1. Rename property `GroupId` → `BracketId`
2. Update XML doc comment: remove "Corresponds to ... DB column [GroupId]" (DB column is now also BracketId)
3. Do NOT rename `GroupName` (correct terminology)

### 3b. Remove [JsonProperty] attributes

**File:** `Shared/ObjectModel/Tournaments/TournamentBracket.cs`
- Line 14: Remove `[JsonProperty("GroupId")]` from `BracketId`
- Line 20: Remove `[JsonProperty("GroupName")]` from `BracketName`

**File:** `Shared/ObjectModel/Tournaments/TournamentGroupingRule.cs`
- Line 38: Remove `[JsonProperty("Groups")]` from `Brackets`

After removal, check if `using Newtonsoft.Json;` is still needed in each file (may have other
JsonProperty usages or may be removable).

### 3c. Update boundary points (from Terminology-Rename-Plan §Implications)

**Type A — Direct comparisons (now both sides BracketId):**

| File | Line | Before | After |
|------|------|--------|-------|
| `SharedLib/Tournaments/TournamentsHelper.cs` | ~160 | `b.BracketId == result.GroupId` | `b.BracketId == result.BracketId` |
| `SharedLib/Tournaments/TournamentEndAdapter.cs` | ~817 | `b.BracketId == ...CurrentPlayerResult.GroupId` | `...CurrentPlayerResult.BracketId` |

**Type D — Internal deferred assignments (now both sides BracketId):**

| File | Line | Before | After |
|------|------|--------|-------|
| `SharedLib/Tournaments/TournamentAdapter.cs` | ~434 | `profileTournament.GroupId = participant.GroupId` | `.BracketId = participant.BracketId` |
| `SharedLib/Tournaments/TournamentEndAdapter.cs` | ~501 | `GroupId = place.GroupId` | `BracketId = place.BracketId` |
| `SharedLib/Tournaments/TournamentEndAdapter.cs` | ~726 | `GroupId = participant.GroupId` | `BracketId = participant.BracketId` |

**Type E — MakeCloneOf/MakeEqualTo (reflection-based, auto-resolved by rename):**
No code changes needed — reflection matches by property name automatically.

### 3d. Update SqlTournamentProvider inline SQL

**File:** `Dal/Sql.MsSql/Tournaments/SqlTournamentProvider.cs`
- Line ~365: SQL UPDATE statement — `[GroupId] = @groupId` → `[BracketId] = @bracketId`
- Update parameter name and binding accordingly

Search for any other `GroupId` references in `SqlTournamentProvider.cs`.

---

## Task 4: C# Code — DCD-004 (remove IsRated)

### 4a. Remove property declarations

| File | Line | Remove |
|------|------|--------|
| `Dal/Sql.Interface/Tournaments/TournamentParticipantDto.cs` | ~37 | `public bool IsRated { get; set; }` |
| `Shared/ObjectModel/Tournaments/TournamentFinalResult.cs` | ~66 | `PlayerFinalResult.IsRated` |

### 4b. Remove from SqlTournamentProvider UPDATE

**File:** `Dal/Sql.MsSql/Tournaments/SqlTournamentProvider.cs`
- Line ~365: Remove `[IsRated] = @isRated` from UPDATE and corresponding parameter binding

### 4c. Remove mapping in TournamentEndAdapter

**File:** `Shared/SharedLib/Tournaments/TournamentEndAdapter.cs`
- Line ~507: Remove `IsRated = participantDto.IsRated,`

### 4d. Simplify ternary in ProcessTournamentResult

**File:** `Photon/src-server/Loadbalancing/LoadBalancing/GameServer/GameClientPeer_Tournaments.cs`

Before (~line 771-773):
```csharp
ratingGained = tournamentFinalResult.CurrentPlayerResult.IsRated
    ? tournamentFinalResult.CurrentPlayerResult.Rating ?? 0
    : 0;
```

After:
```csharp
ratingGained = tournamentFinalResult.CurrentPlayerResult.Rating ?? 0;
```

`IsRated` was always `true` (DB DEFAULT 1, never set to false). Removing the ternary
preserves existing behavior.

### 4e. Test JSON configs — do NOT touch

`TournamentComplexTest.cs` and `TournamentScoringTest.cs` have `"IsRated": true` in
**Places** config — this is `TournamentPlace.IsRated`, a DIFFERENT property. Leave as is.

---

## Task 5: C# Code — DCD-005 (remove IsCanceled chain) — INVESTIGATE FIRST

**Prerequisite:** Check SVN history for GRM-branch origin of each field. Determine full scope.

Known chain to remove (from design doc):
- DB: `TournamentParticipants.IsCanceled`, `ArchiveTournamentParticipants.IsCanceled` (if GRM-origin)
- SP: `GetPlayerTournaments.sql` alias `IsCanceledForUser`, `GetTournamentsDynamic.sql` alias, filter `p.IsCanceled = 0`
- Code: `TournamentDto.IsCanceledForUser`, `Tournament.IsCanceledForUser`, `SportEventsModel.IsCanceledForUser`,
  `TournamentsCache.cs`, `TournamentIndividualResultsDto.IsCanceled`, `TournamentParticipantDto.IsCanceled`
- Code: `TournamentGroupParticipant.IsCanceled`, `TournamentGroupParticipant.IsNotRated`

**Action:** Investigate SVN history first (commits r13282/r13286), then write detailed steps.
Add DB changes to the migration patch from Task 1.

---

## Task 6: Build and Test

**Step 1:** Ask user to build solution (build from CLI not supported)

**Step 2:** Run matchmaking tests:
```
dotnet test --no-build Photon/src-server/LoadBalancing.Tests/LoadBalancing.Tests.csproj
dotnet test --no-build Shared/SharedLib.Tests/SharedLib.Tests.csproj
```

**Step 3:** Run DAL tests (if applicable):
```
dotnet test --no-build Dal/Sql.MsSql.Tests/Sql.MsSql.Tests.csproj
```

**Step 4:** Grep for any remaining `GroupId` in C# code (excluding GroupName):
```
grep -r "GroupId" --include="*.cs" | grep -v GroupName | grep -v "// " | grep -v "/// "
```
Should return zero results in tournament-related code.

---

## Task 7: Commit

Commit message format per project conventions:
```
FP-41746: [TRM-003] Rename GroupId → BracketId in DB, SPs, and code
= Renamed `[GroupId]` → `[BracketId]` in 7 DB tables via `sp_rename`
= Updated 18 stored procedures: column refs + parameters
= Renamed `GroupId` → `BracketId` in 9 C# classes (P6-P14)
- Removed `[JsonProperty]` backward-compat attributes from `TournamentBracket`, `TournamentGroupingRule`
= Updated JSON configs in `Tournaments`, `TournamentTemplates`, `ArchiveTournaments` via REPLACE()
- Removed `IsRated` from `TournamentParticipantDto`, `PlayerFinalResult`, DB column, and `ProcessTournamentResult()` ternary
(Task: Matchmaking alignment — terminology unification)
https://fishingplanet.atlassian.net/browse/FP-41746
```

---

## Dependencies and Order

```
Task 0 (diagnostic) ──→ Task 1 (SQL patch)
                          ↓
                        Task 2 (SP files) ──→ Task 6 (build/test) ──→ Task 7 (commit)
                          ↓
                        Task 3 (C# TRM-003)
                          ↓
                        Task 4 (C# DCD-004)
                          ↓
                        Task 5 (C# DCD-005, investigate)
```

Tasks 1-4 can be written in any order (atomic deploy), but logical flow is bottom-up.
Task 5 requires investigation before execution.
Task 6 requires build (user action).
