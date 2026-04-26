---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15914
jira: https://fishingplanet.atlassian.net/browse/FP-42683
---

# Review: FP-42683 — DAILY MISSIONS: Server - create AB test

## Summary

Adds AB-test (Id=21) that overrides daily-missions `MinLevel` for selected players with a lower value (new generation setting `AbTestMinLevel`, default `3`). Default behavior (variant A) — unchanged; selected players (variant B) — lower min level. Bonus: hard floor (`GlobalVariablesCache.ClubMinLevel`) so club missions never generate below clubs-unlock level even when configured lower.

Context for severity grading: **feature lives only in Test environment, not in production** (per author of this review).

## Scope

- **LBM r15914** — Create AB test to override daily missions min level
  - SQL patch `LBM.M.2026.03.12-034`: insert AB test row (Id=21, Probability=0.5, DefaultValue=0, **IsActive=0**); add `AbTestMinLevel:3` to `DailyMissions.GenerationSettings` JSON
  - Constant `SharedConsts.DailyMissionsMinLevelAbTestId = 21`
  - Field `GenerationSettings.AbTestMinLevel`
  - `ProfileContext.GetMinLevelAbTestSelection: Func<bool>`
  - `DailyMissionGenerator.IsLevelSufficient` (extracted method) — encodes `max(configured.MinLevel, ClubMinLevelFloor)` + AB-override branch
  - `DailyMissionAdapter` catch-up loop refactored to use `IsLevelSufficient`
  - `DailyMissionUtils.BindContextToProfile` wires `Lazy<bool>` over `AbTestCache.GetTestSelection(UserId, 21)`
  - 7 new tests + 1 repurposed test in `AdapterTests_MinLevel.cs`

## Notes

- **Club floor is currently non-binding.** Local DB: `GlobalVariables.ClubMinLevel` row absent → defaults to `5`; `JsonVariables.DailyMissions.GenerationSettings.MissionKinds.Club.MinLevel = 10`. `max(10, 5) = 10`, identical to pre-refactor. Refactor locks the invariant for future configs but doesn't change current behavior.
- **Catch-up corner-case fix.** Old `DailyMissionAdapter` catch-up used `kvp.Value.MinLevel > 0 && Context.Level >= kvp.Value.MinLevel`, which skipped kinds with `MinLevel = 0`. New `IsLevelSufficient` covers that branch (returns `true` for `minLevel <= 0`). Incidental but correct.
- **`Lazy<bool>` in `BindContextToProfile` is perf, not correctness.** `AbTestCache.GetTestSelection` calls `SqlSysProvider.ReflectAbTestSelection` on every roll, which persists the first selection and returns the persisted value on subsequent calls — so AB selection is stable per `(userId, testId)` regardless of caller-side caching. Lazy avoids the SP roundtrip per generation cycle within one binding.
- **Naming nit.** Field `AbTestMinLevel` on `GenerationSettings` is generic for what it does (override min level only). Future AB tests on other settings would have to add parallel fields. Acceptable in this scope; flag for refactor if more AB-overrides come.

## Investigation Journal

- ⚠ JIRA `customfield_11224` (Executor) is empty; commit author (Yuriy Burda) used as executor.
- VCS audit: only `r15914` on LBM matches FP-42683; visible in MFT history (inherited via branch-copy: MFT was branched from LBM:r15942 ≥ 15914) — no explicit merge needed; absent on KNW (correct, AB-test doesn't go to Stable).
- Hypotheses verified: H1 `DailyMissionsMinLevelAbTestId = 21` slot free (between `HidePondPassesFromPremShopTestId = 20` and `SkipCustomizationAbTestId = 22`); H2 `AbTestCache.GetTestSelection` returns `DefaultValue` when `IsActive=false` → SQL inserts `IsActive=0, DefaultValue=0` → AB branch never enters by default; H3 prod config Club floor non-binding (see Notes); H4 `ReflectAbTestSelection` persists first roll, stabilizes AB membership across sessions.
- Code-reviewer agent: declined per author of review (Phase 2 step 6).
- Triage routing file pre-noted: `<kb>/fishing-planet/server/modules/missions/triage-2026-04.md` — no findings of "author clarification, decision-affecting" type emerged, so no triage entries needed.

## Verdict

**Approve.** Logic is clean, default-off, no regression in current prod config, AB-selection stability guaranteed by persistence layer, test coverage thorough. Notes capture incidental observations and future-refactor flags but none rise to a Finding.
