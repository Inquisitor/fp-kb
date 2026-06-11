---
status: resolved
executor: Yevhenii Shust
branch: MFT @ r16059, r16096
jira: https://fishingplanet.atlassian.net/browse/FP-43411
---

# FP-43411: FTUE. Server - Add "ID" field to Leaderboards tables

## Summary

WebAdmin task: add an `ID` column to the Leaderboards admin-panel tables so that
point-wise data transfers ("переливки") are easier to operate. Cloned from FP-43300.
During implementation the executor also reworked the PK-getter format in
`DataPumpModel`, which caused a regression reported by QA and required a follow-up fix.

## Scope

- **MFT r16059** — Implemented ID field for Leaderboards tables
  - Added `ID` column to the relevant admin-panel tables
  - "Improved" the getter format for PK in `DataPumpModel` (scope creep — not requested)
  - Added non-existent `TournamentKindId = None` to `CompetitiveLeaderboardRewards`
    and `CompetitiveLeaderboardStatus` dropdowns as a temporary workaround
- **MFT r16096** — Fix for QA regression on PK button
  - Removed default `=` appended to each key
  - Replaced `,` separator for composite keys with `AND` operator

## Investigation Journal

- Intake from JIRA comments: executor = Yevhenii Shust (commit author), assignee = Stanislav (reviewer).
- ⚠ Executor field (customfield_11224) empty in JIRA — expected "Yevhenii Shust".
- Risk areas identified pre-diff: (1) `DataPumpModel` PK getter SQL `WHERE` generation
  (r16059 + r16096), (2) `TournamentKindId = None` dropdown hack, (3) scope creep that
  triggered the QA regression.

## Phase 2 — Audit results

SVN audit: `svn log | grep FP-43411` on MFT → exactly r16059, r16096, both by `yevhenii.shust`.
Matches JIRA. No missing/extra commits. WC at r16168 (ahead of both) — disk = post-fix state.

### Files touched (r16059)
- 3 reward DTOs (`Competitive/Fish/GlobalLeaderboardRewardDto.cs`) — added `int Id`
- `SQL/Patches/MFT.M.2026.05.04-013 [LeaderboardRewards].sql` — table rebuild migration
- `WebAdmin/Models/DataPumpModel.cs` — PK getter format rework (scope creep)
- `WebAdmin/Models/Leaderboards/Entities.cs` — Id PK/Identity + `0=None` enum hack

### Crit-risk hypotheses — all cleared
- **(A) `SELECT *` ordinal-mapping break:** `DtoExtensions.RestoreObjectFromReader` maps
  **by column name** (`reader.GetName(i)` → `GetProperty`), unknown cols skipped. Adding `Id`
  is safe; forward/backward deploy-order compatible (old code skips Id col, new code reads it).
- **(B) IDENTITY breaks INSERTs:** all three `Populate*LeaderboardRewards` SPs use **explicit
  column lists** (no `Id`) → IDENTITY auto-generates. MERGE `ON` clause keys on the old composite,
  now backed by the new UNIQUE constraint. No count mismatch.
- **(C) Inbound FK breaks table rebuild:** no `REFERENCES ...LeaderboardRewards` anywhere in SQL.
  Rename+drop+recreate is safe. Migration is transactional (XACT_ABORT), guarded, idempotent,
  row-count-validated. QA empirically applied it on the test build.

### DataPump PK getter — not a crit
`GetDataPumpStringPrimaryColumns` ("pkcolumns") output is inserted into an **editable textarea**
(`#TableName`) as an authoring hint for super-admin only; the real transfer runs an external
`DataPump.exe` over a hand-edited script. No auto-execution path. Format churn `", "` → `"A AND B"`
(r16059 `+" ="` reverted in r16096 after QA complaint) is cosmetic. Tester (Volodymyr Kryzhovets)
accepted the r16096 result.

## Findings

### F-1: Unrequested DataPump getter rework caused a QA regression round-trip [Low / Info]
**Description:** Task was "add Id column to 3 reward tables". The PK-getter format in `DataPumpModel`
(`", "` → `" AND " + " ="`) was also reworked. Not part of the task; broke the existing operator
workflow (QA comment 118479) and required a second commit r16096 to partially revert. No release impact.
**Investigation:** Diff read of r16059/r16096; confirmed getter is a super-admin UI helper with no
auto-exec path; tester (Volodymyr Kryzhovets) accepted r16096.
**Resolution:** Accepted. No release impact.
**Discovered by:** skill recon.

### F-2: "Temporary" `TournamentKindId = 0=None` enum option left in for release [Low]
**Description:** To work around a WebAdmin dropdown that blocked adding new rows (grid inits int to
0, not in the `3=Competition` enum), `0=None` was added to the enum in both
`CompetitiveLeaderboardRewards` and `CompetitiveLeaderboardStatus`. Marked "temporary" in JIRA.
Risk: an operator can persist a reward row with `TournamentKindId=0`.
**Investigation:** Read `Entities.cs` diff; traced read path. Reward distribution
(`DistributeLeaderboardRewards`) filters by `GetSupportedTournamentKinds()` which returns only
`Competition (3)` → a `TournamentKindId=0` row never matches and is inert (no crash). Independent
code-reviewer agent corroborated. Sole theoretical reachability: a `0`-row with NULL `RewardName`
could hit `RewardsCache.GetReward(null)` → `ArgumentNullException`, but only if an admin deliberately
saves such a row — not a release-day path. UNIQUE constraint permits the row at DB level.
**Resolution:** Accepted for release (low risk). Recommend a follow-up ticket to fix the grid
dropdown default properly instead of the sentinel enum value.
**Discovered by:** executor's comment + diff.

### F-3: Minor code-quality nits [Info]
**Description:** r16096 leaves redundant `list.Select(x => x)` (no-op projection — should be plain
`string.Join(" AND ", list)`). r16059 mixes the functional change with churn: SQL re-indentation and
a partial `using`-declaration refactor applied to only one of the two command blocks in the file
(inconsistent style). Cosmetic.
**Investigation:** Diff inspection only.
**Resolution:** Skipped (cosmetic).
**Discovered by:** skill recon.

## Open question (completeness, non-blocking)
Task description references "наступних таблиць" (the following tables) with screenshots not
readable here. `Id` was added to the 3 reward tables. Whether the intended scope included
additional tables (e.g. Status tables) is unverifiable from the diff — assignee/QA to confirm
coverage. Not a crit.

## Verdict — APPROVE for release

No critical, release-breaking, or data-corrupting issue found. The schema change is backward/
forward compatible (by-name DTO mapping; explicit-column INSERTs in all SPs; AutoIncrement skipped
by the WebAdmin CRUD helper). Migration is transactional, guarded, idempotent, row-count-validated,
with no inbound FK on the rebuilt tables. The DataPump getter change is a super-admin UI text helper
with no auto-execution path. QA played on a build with this change with no blocking issues.

Independent code-reviewer agent (separate context) reached the same conclusion and additionally
verified the WebAdmin CRUD INSERT/UPDATE paths and the reward-distribution filter.

Findings F-1..F-3 are Low/Info, none blocking. Recommended (non-blocking) follow-up: a ticket to
replace the `0=None` sentinel enum (F-2) with a proper grid dropdown default.

Investigation journal addendum:
- All 3 crit hypotheses (ordinal-mapping, IDENTITY INSERT, inbound FK) verified false via code reads.
- Independent agent corroboration obtained; no divergence from skill recon.
