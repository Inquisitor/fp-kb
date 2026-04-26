---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15844
jira: https://fishingplanet.atlassian.net/browse/FP-42230
---

# Review: FP-42230 — Daily Missions: difficulty array changes provoke generation errors

## Summary

Bug: when the daily-missions JSON config drops a difficulty (e.g. removes "Hard" from a premium mission), `GenerateMissions` crashes with `KeyNotFoundException` in `MissionBuilderBase.BuildMission` at `Tasks[missionDifficulty]`. Fix: replace hard-coded `DailyMissionDifficulty.Hard`/`.Easy` clamps with `Tasks.Keys.Min()`/`.Max()`, and add an upper-clamp in `GetCurrentMissionDifficulty` so the stored value never escapes `[min, max]`. Two new tests cover top-removal scenarios. Feature is in Test, not yet in production.

## Scope

- **LBM r15844** — Daily Missions - Check for min/max difficulty on mission difficulty changes or getting mission difficulty to generate
  - `DailyMissionGenerator_MissionDifficulty.cs`: replaced hard-coded `Hard`/`Easy` clamps with `Tasks.Keys.Min()`/`.Max()`; moved empty-config check to top; added upper-clamp in `GetCurrentMissionDifficulty`
  - `GeneratorTests_MissionDifficulty.cs`: 2 new tests for stored-difficulty clamping when top entries removed

## Investigation Journal

- 2026-04-26: Card created from JIRA intake. Branch `LBM @ r15844` taken from executor's JIRA comment as-is.
- 2026-04-26: VCS audit — `svn log --search FP-42230 -r 15396:HEAD` confirms 1 commit on LBM (matches JIRA). MFT inheritance check: r15844 ≤ 15942 (MFT source-rev), so commit is inherited via branch copy — no explicit merge needed.
- 2026-04-26: Read full diff and HEAD copy. Fix is intact at HEAD.
- 2026-04-26: Hypothesis H-1 (gap-in-middle latent issue) — verified via `DailyMissionDifficulty` enum (5 values: Easy, EasyMedium, Medium, MediumHard, Hard) and `Tasks` dictionary structure. Confirmed real: `currentMissionDifficulty++/--` lands on intermediate enum values that may not be in `Tasks.Keys` if config is non-contiguous; `[min,max]` clamps don't catch this. Pre-existing — old code was equally broken for gap configs.
- 2026-04-26: Hypothesis H-2 (other consumers of `Tasks[difficulty]`) — only one: `MissionBuilderBase.BuildMission` line 28. Sibling adjustment site at `DailyMissionAdapter.RegenerateMission` (line 283-287) computes `newDifficulty = currentDifficulty - DecreaseDifficultyOnRegeneration` and clamps only on min — also vulnerable to gap-in-middle, also pre-existing, also unchanged by this commit.
- 2026-04-26: HEAD-verification (commit older than 2 weeks): `svn log -r 15844:HEAD` on `DailyMissionGenerator_MissionDifficulty.cs` shows one follow-up (r15890, FP-42232 — moved required-completions/fails to per-kind settings; consecutive-missions semantics fix). r15890 does NOT address gap-in-middle. F-1 stands at HEAD.
- 2026-04-26: F-1 routing decision — finding is decision-affecting BUT not introduced by this commit (pre-existing) → routes to `modules/missions/backlog.md`, NOT to the release triage-file (criterion 2 fails). Cosmetic notes (F-2, F-3) stay card-only.
- 2026-04-26: F-1 reclassified to **Skipped** after user input — gap-config is treated as a config bug by domain policy, not a code-side concern; supporting non-contiguous configs would require rework far beyond this code path (e.g. UI/admin validation, semantics for "skipped" levels). No module backlog entry needed.

## Findings

### F-1: Gap-in-middle of `Tasks.Keys` still throws `KeyNotFoundException` [Low (latent, pre-existing)]

**Description.** Both `DailyMissionGenerator_MissionDifficulty.AdjustCurrentMissionDifficulty` (`++` / `--` paths) and `DailyMissionAdapter.RegenerateMission` (subtract `DecreaseDifficultyOnRegeneration`) mutate `currentMissionDifficulty` by integer arithmetic on the underlying enum (`DailyMissionDifficulty` has 5 contiguous values: Easy, EasyMedium, Medium, MediumHard, Hard). Resulting value is then clamped to `[Tasks.Keys.Min(), Tasks.Keys.Max()]` of the current config. If the config is non-contiguous — e.g. `Tasks = {Easy, Hard}` (`Medium` and surrounding levels removed) — an intermediate value (`EasyMedium` / `Medium` / `MediumHard`) lies inside `[Min, Max]` and the clamp does not fire. `MissionBuilderBase.BuildMission` (line 28) then does `missionKindSetting.Tasks[missionDifficulty]` and throws `KeyNotFoundException`, the original symptom.

**Investigation.** Diff inspection; enum has 5 values; `Tasks` is `Dictionary<DailyMissionDifficulty, …>` allowing arbitrary subsets; `MissionBuilderBase` is the only consumer of `Tasks[difficulty]`; sibling regeneration path at `DailyMissionAdapter.cs:283-287` shares the pattern; HEAD-verified via `svn log -r 15844:HEAD` — follow-up r15890 also does not address gap-in-middle.

**Resolution.** Skipped — gap-config is a config bug by domain policy, not a code-side concern. Supporting non-contiguous configs would require coordinated changes well beyond this code path (admin/UI validation, semantics for "skipped" levels in adjustment arithmetic). The reported bug (top-removal) is correctly fixed by this commit; that is the in-scope change.

**Discovered by:** skill recon.

### F-2: Final two clamps after the up/down branch in `AdjustCurrentMissionDifficulty` are redundant [Info]

**Description.** Lines 65-73 re-clamp `currentMissionDifficulty` to `[minDifficulty, maxDifficulty]` after the if/else-if block. The up branch already clamps `> maxDifficulty`, the down branch already clamps `< minDifficulty`, and `GetCurrentMissionDifficulty` itself returns a value in `[min, max]`. The trailing pair is defensive belt-and-braces — not harmful, but adds visual noise.

**Resolution.** Skipped. Defensive style is acceptable; collapsing into a single trailing `Math.Clamp`-style pair would be cleaner but not warranted now.

### F-3: Empty-Tasks check style inconsistency [Info]

**Description.** `AdjustCurrentMissionDifficulty` uses `!missionKindSetting.Tasks.Keys.Any()` (line 21); `GetCurrentMissionDifficulty` uses `!missionKindSetting.Tasks.Any()` (line 91). Same semantic on a `Dictionary`. Cosmetic.

**Resolution.** Skipped.

## Verdict

LGTM. Original repro (top-removal of a difficulty) is correctly fixed at the source — `GetCurrentMissionDifficulty` now clamps the stored value to the actual upper bound from config, and `AdjustCurrentMissionDifficulty` no longer relies on hard-coded `Hard`/`Easy` enum values. Tests cover the two relevant paths. Cross-branch merge to MFT is automatic via branch-copy inheritance — no explicit merge needed.
