---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15874
jira: https://fishingplanet.atlassian.net/browse/FP-42373
---

# Review: FP-42373 — Daily Missions: difficulty raised on day 4 instead of day 3

## Summary

Bug fix: difficulty progression in daily missions advanced one day later than configured. Per JIRA description (UA): "Складність підвищилась на 4 день а не на 3". Root cause: `AdjustCurrentMissionDifficulty` ran AFTER `GenerateMissions`, so the adjusted difficulty took effect on the NEXT day's generation — classic off-by-one. Fix reorders the steps inside `DailyMissionAdapter.GenerateAllMissions` so adjustment happens BEFORE generation, with the just-completed missions already moved into `RecentMissions` and `IsCompleted` set.

Environment: Test (not production).

## Scope

- **LBM r15874** — Daily Missions - fix order of logic for difficulty update and mission generation order
  - Reorder steps in `Shared/SharedLib/DailyMissions/DailyMissionAdapter.cs` → `GenerateAllMissions`: move-to-recent + IsCompleted → adjust difficulty → generate (was: generate → move-to-recent + IsCompleted → adjust difficulty)
  - Add 2 boundary tests in new `Shared/SharedLib.Tests/DailyMissions/AdapterTests_DifficultyProgression.cs` (raise on day 3 with 2 completions; lower on day 3 with 2 fails)
  - Pass `adjustCurrentMissionDifficulty: false` to 5 existing calls in `Shared/SharedLib.Tests/DailyMissions/AdapterTests_Identifiers.cs` to keep identifier tests deterministic under the new ordering

## Findings

### F-1: UTF-8 BOM missing on new test file [Low]

**Description**: `Shared/SharedLib.Tests/DailyMissions/AdapterTests_DifficultyProgression.cs` (added in r15874) starts without UTF-8 BOM (`head -c 3` shows `usi` from `using`). Other files touched by the commit preserve BOM. `.editorconfig` enforces `charset = utf-8-bom` for `*.cs`. Same hygiene pattern as FP-42308 F-1 from the same author.

**Investigation**:
- `head -c 3` on HEAD: `AdapterTests_DifficultyProgression.cs` → `usi` (no BOM); `AdapterTests_Identifiers.cs` and `DailyMissionAdapter.cs` → `EF BB BF u` (BOM present).
- Issue still on HEAD; not fixed by any follow-up.

**Resolution**: Skipped — hygiene only, no user impact, fix on Test, trivial to restore alongside future edits. Recurring pattern surfaces in module backlog.

### F-2: `adjustCurrentMissionDifficulty: false` in 5 identifier-test calls is functionally required but undocumented [Info]

**Description**: r15874 added `adjustCurrentMissionDifficulty: false` to 5 existing `TryGenerateMissions` calls in `AdapterTests_Identifiers.cs`. Rationale is not in a code comment. The parameter is NOT cosmetic test isolation — under the new ordering, `AdjustCurrentMissionDifficulty` runs BEFORE generation and reads `RecentMissions` filtered by `!IsAccounted`. The identifier tests never complete missions, so by the 2nd generation `recentMissionToCheck.Length = 3` with all `!IsCompleted` → `requiredFails=2` threshold met → difficulty drops + `IsAccounted=true` set. A different difficulty bucket can yield different mission/task counts, shifting the asserted negative-decrementing identifier sequence. Without the parameter, identifier tests become coupled to difficulty-config particulars.

**Investigation**:
- Read `DailyMissionGenerator_MissionDifficulty.cs::AdjustCurrentMissionDifficulty` to confirm it reads `RecentMissions` (not `CurrentMissions`) and writes `IsAccounted`.
- Walked `AdapterTests_Identifiers.cs` HEAD: `Verify_Generated_Mission_and_Task_Identifiers` runs 3 generations from a profile starting at Hard, never marks `IsCompleted` → matches threshold conditions on gen 2.
- Independent review by `feature-dev:code-reviewer` agent confirmed the same chain.

**Resolution**: Skipped — author handled the case correctly; just no comment explaining why. No production impact (production code doesn't see this coupling). Note for the recurring author-attention list.

**Discovered by**: `feature-dev:code-reviewer` agent recon (reframing of an initial "defensive isolation" hypothesis).

## Investigation Journal

- ⚠ JIRA `customfield_11224` (Executor) empty; expected `Yuriy Burda` per the SVN comment. Detect-only — not blocking.
- VCS audit: `svn log` over LBM showed exactly one commit referencing FP-42373 (r15874). Matches JIRA comment. Files: `DailyMissionAdapter.cs` (M), `AdapterTests_DifficultyProgression.cs` (A), `AdapterTests_Identifiers.cs` (M).
- Branch ancestry: r15874 ≤ MFT base r15942 → fix inherited via branch copy in MFT. No cross-merge required; comment will omit `Merged → MFT`.
- Hypothesis-then-verification round (3 hypotheses, all disproven before drafting):
  - **H1 (partial state on exception)**: feared the new ordering commits state mutations (RecentMissions++, IsCompleted, difficulty++) before generation, then leaves them on exception. Verified: try/catch at `DailyMissionAdapter.cs:153-161` sets `missions=[]` and proceeds; the OLD flow ran the same mutations after the catch via `Context.GenerationTime`/`RecentMissions` block. Final state in failure path is equivalent — no new partial-state risk.
  - **H2 (similarity check pollution)**: feared that `RecentMissions` containing today's missions before generation would alter similarity check. Verified: `DailyMissionGenerator_Similarity.GetMissionsToCheckSimilarity` reads BOTH `RecentMissions` (date-filtered) AND `CurrentMissions`. New flow has today's missions in both → duplicate inclusion. `HasSimilarTask` is purely boolean → no functional change, only minor extra iteration.
  - **H3 (AdjustCurrentMissionDifficulty sees wrong CurrentMissions)**: feared the function reads stale CurrentMissions in the new ordering. Verified: it reads `RecentMissions` only. The new ordering is in fact the ONLY correct one (function needs Recent populated with today's IsCompleted, AND its difficulty mutation needs to precede generation).
- Severity context (FP-42164): feature on Test environment → release-status gate collapses any data-integrity flavor. F-1 stays Low (hygiene), F-2 stays Info.
- HEAD verification per FP-42190 (commit ~2 months old): reorder preserved on HEAD; r15890 (FP-42232) followed up with config-schema migration (`RequiredCompletionsToRaiseDifficulty` moved from top-level `GenerationSettings` to per-kind `MissionKinds[kind]`) and 3 additional consecutive-counting tests. r15903/r15914/r15950/r15957 didn't undo the reorder. r15890 also adapted r15874's two tests to the new schema; assertions intact.
- Triage routing for `missions/triage-2026-04.md`: zero new entries — F-1 (hygiene, no decision needed) and F-2 (no actionable Q to author) both fail the 3-way AND.
