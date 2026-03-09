# TRM-003: Full DB Rename — Design

> **Date:** 2026-03-08 \
> **Branch:** LBM20251201 \
> **Related:** [Matchmaking-Alignment-Plan.md](Matchmaking-Alignment-Plan.md), [Terminology-Rename-Plan.md](Terminology-Rename-Plan.md)

## Decision

Instead of enhancing the DAL mapper (`RestoreObjectFromReader`) with column mapping attributes,
rename `GroupId` → `BracketId` directly in the database. The matchmaking feature is deployed to
production but disabled — columns exist but contain no data (NULL). This eliminates the
terminology mismatch at all layers: DB, stored procedures, DTOs, models, JSON configs, and code.

Deployment is atomic (downtime). All stored procedures are recreated on any DB change deploy.

---

## Scope

### TRM-003: Rename `GroupId` → `BracketId`

**Tables** (rename column via `sp_rename`):

| Table                                | Column      | Action              |
|--------------------------------------|-------------|---------------------|
| `TournamentIndividualResults`        | `GroupId`   | → `BracketId`       |
| `TournamentParticipants`             | `GroupId`   | → `BracketId`       |
| `TournamentSecondaryResult`          | `GroupId`   | → `BracketId`       |
| `ArchiveTournamentIndividualResults` | `GroupId`   | → `BracketId`       |
| `ArchiveTournamentParticipants`      | `GroupId`   | → `BracketId`       |
| `ArchiveTournamentSecondaryResult`   | `GroupId`   | → `BracketId`       |

> **Note:** `GroupName` in result tables stores the final group name (correct in unified
> terminology) and is NOT renamed.
>
> `TournamentStats.GroupId` and `ArchiveTournamentStats.GroupId` were already dropped
> (GRM.M.2024.05.22-013, GRM.M.2024.05.30-019). Not part of this migration.

**Stored Procedures** (18 known files in `SQL/Patches/Main/Procedures/`):
- All `[GroupId]` → `[BracketId]`, `@GroupId` → `@BracketId`
- Full list to be confirmed via `EXEC FindObjectsByText 'GroupId'` on DEV

**JSON Configs** (`ConfigJson` column in `Tournaments`, `TournamentTemplates`, `ArchiveTournaments`):
```sql
UPDATE <table> SET ConfigJson =
  REPLACE(REPLACE(REPLACE(ConfigJson,
    '"Groups"',    '"Brackets"'),
    '"GroupId"',   '"BracketId"'),
    '"GroupName"', '"BracketName"')
WHERE ConfigJson LIKE '%"Groups"%'
```
Validated safe: `"GroupId"`, `"GroupName"`, `"Groups"` appear only inside the `Grouping` section
of `TournamentJsonConfig` / `TournamentTemplateJsonConfig`. No collisions with other config keys.

**C# Code:**
- Rename `GroupId` → `BracketId` in 9 classes (P6-P14 from [Terminology-Rename-Plan](Terminology-Rename-Plan.md))
- Remove `[JsonProperty("GroupId")]`, `[JsonProperty("GroupName")]` from `TournamentBracket`
- Remove `[JsonProperty("Groups")]` from `TournamentGroupingRule`
- Update XML doc comments

### DCD-004: Remove `IsRated` (alongside TRM-003)

Since we're already modifying the DB, remove the unused `IsRated` column added for the
never-released CrossMovesAllowed/NotRatedIfIncomplete feature.

| Layer | What to remove                                                                                  |
|-------|-------------------------------------------------------------------------------------------------|
| DB    | `TournamentParticipants.IsRated` + `DF_TournamentParticipants_IsRated` constraint               |
| DB    | `ArchiveTournamentParticipants.IsRated` + `DF_ArchiveTournamentParticipants_IsRated` constraint |
| Code  | `TournamentParticipantDto.IsRated` and all consumers                                            |

### DCD-005: Remove `IsCanceled` for participants (alongside TRM-003)

Remove the per-participant cancellation status introduced for matchmaking grouping scenarios.
Scope to be refined by SVN history (GRM-branch fields). Known chain:

```
TournamentParticipants.IsCanceled (DB)
  → GetPlayerTournaments.sql: p.IsCanceled AS IsCanceledForUser
  → GetTournamentsDynamic.sql: p.IsCanceled AS IsCanceledForUser
    → TournamentDto.IsCanceledForUser
      → Tournament.IsCanceledForUser
      → SportEventsModel.IsCanceledForUser
      → TournamentsCache.cs
  → TournamentIndividualResultsDto.IsCanceled
  → TournamentParticipantDto.IsCanceled
```

Also: `TournamentGroupParticipant.IsNotRated`, `TournamentGroupParticipant.IsCanceled` (code-only).

Reference SVN commits: r13282, r13286.

### Out of Scope

- `GroupName` in result tables (correct terminology, not renamed)
- `Tournaments.IsCanceled` (tournament-level cancellation, actively used)
- Phase 5 (CFG-007 — MaxRating refactoring)
- Phase 7 (documentation cleanup on Confluence)

---

## Execution Plan

### Step 0: Reconnaissance (manual, on DEV/Prod)

1. Validate no data: `SELECT COUNT(*) WHERE GroupId IS NOT NULL` per table on Prod
2. `EXEC FindObjectsByText 'GroupId'` on DEV — discover all DB objects, compare with 18 known SP files
3. Row counts for migration time estimation
4. Verify `TournamentStats.GroupId` vs `ArchiveTournamentStats` state (potential archivation bug)

**Results (2026-03-08, Prod):**

Data validation — all zeros, safe to rename:

| Table                              | Rows with GroupId IS NOT NULL |
|------------------------------------|-------------------------------|
| TournamentIndividualResults        | 0                             |
| TournamentParticipants             | 0                             |
| TournamentSecondaryResult          | 0                             |
| ArchiveTournamentIndividualResults | 0                             |
| ArchiveTournamentParticipants      | 0                             |
| ArchiveTournamentSecondaryResult   | 0                             |

Row counts:

| Table                              | Rows      | Migration impact         |
|------------------------------------|-----------|--------------------------|
| TournamentIndividualResults        | 104,173   | sp_rename (instant)      |
| TournamentParticipants             | 107,714   | sp_rename + DROP IsRated |
| TournamentSecondaryResult          | 15        | sp_rename (instant)      |
| ArchiveTournamentIndividualResults | 4,308,583 | sp_rename (instant)      |
| ArchiveTournamentParticipants      | 4,491,107 | sp_rename + DROP IsRated |
| ArchiveTournamentSecondaryResult   | 509       | sp_rename (instant)      |
| Tournaments                        | 6,756     | UPDATE ConfigJson        |
| TournamentTemplates                | 272       | UPDATE ConfigJson        |
| ArchiveTournaments                 | 251,005   | UPDATE ConfigJson        |

Time estimate: `sp_rename` is metadata-only (instant). `DROP COLUMN` is fast.
`UPDATE ConfigJson` scans ~258K rows — seconds.

FindObjectsByText — 18 SPs match known list exactly. No unknown objects.
Non-tournament hits: `MissionGroups.GroupId`, `Missions.GroupId`, `InventoryItems.InventorySortingGroupId`,
`VW_AllTexts`/`VW_AllTextsMetadata` (localization views, reference MissionGroups, auto-regenerated on deploy).

`TournamentStats.GroupId` — dropped in GRM.M.2024.05.22-013. `ArchiveTournamentStats.GroupId` — dropped
in GRM.M.2024.05.30-019. Both excluded from migration.

IsRated confirmed: `TournamentParticipants.IsRated BIT NOT NULL`, `ArchiveTournamentParticipants.IsRated BIT NOT NULL`.

**Verdict: no blockers. Proceed with implementation.**

### Step 1: SQL Migration Patch

Single patch file following project conventions. Idempotent checks throughout.

1. `sp_rename` columns `[GroupId]` → `[BracketId]` in 6 tables (with `IF EXISTS` guards)
2. DROP `[IsRated]` + default constraints from `TournamentParticipants` and `ArchiveTournamentParticipants`
3. Handle `TournamentParticipants.IsCanceled` chain (DCD-005, scope per SVN history)
4. `REPLACE()` on `ConfigJson` in `Tournaments`, `TournamentTemplates`, `ArchiveTournaments`

### Step 2: Stored Procedures

Update all SP files in `SQL/Patches/Main/Procedures/`:
- `[GroupId]` → `[BracketId]`
- `@GroupId` → `@BracketId`
- Remove `IsCanceledForUser` alias and `p.IsCanceled` filters (DCD-005)
- Remove `IsRated` references (DCD-004)

### Step 3: C# Code

- Rename `GroupId` → `BracketId` in P6-P14 (ReSharper rename or manual)
- Remove `[JsonProperty]` attributes from `TournamentBracket` and `TournamentGroupingRule`
- Remove `IsRated` from DTOs and consumers
- Remove `IsCanceled`/`IsCanceledForUser` chain (DCD-005)
- Update boundary points (Type A/D from [Terminology-Rename-Plan](Terminology-Rename-Plan.md)):
  - A1: `b.BracketId == result.GroupId` → `b.BracketId == result.BracketId`
  - A2: `b.BracketId == tournamentFinalResult.CurrentPlayerResult.GroupId` → `.BracketId`
  - D1-D3: `GroupId = participant.GroupId` → `BracketId = participant.BracketId`

### Step 4: Validate on DEV

1. Run migration patch on DEV DB
2. Deploy updated SPs
3. Build solution
4. Run matchmaking tests (`dotnet test --no-build`)
5. Verify archivation procedure works

---

## Technical Notes

### `sp_rename` is metadata-only
Column rename via `sp_rename` is instant regardless of table size — no data movement,
no table rebuild. Row counts are relevant only for `UPDATE ConfigJson` (needs to scan rows).

### `PerformArchivation` uses dynamic column list
`PerformArchivation` reads column names from `INFORMATION_SCHEMA.COLUMNS` at runtime
(source table), then `INSERT INTO Archive<table> SELECT <columns> FROM <table>`.
Source and Archive tables must have matching column names. After rename, both sides
will have `BracketId` — archivation continues to work.

### JSON backward compatibility not needed
Atomic deployment with downtime. Old code never runs against new DB. `[JsonProperty]`
attributes can be removed immediately — no fallback period.

### `GroupName` is NOT renamed
`GroupName CHAR(2)` in result tables stores the final competition group name (e.g. "A", "B").
In unified terminology, "Group" is the correct term for this concept. Not part of TRM-003.
