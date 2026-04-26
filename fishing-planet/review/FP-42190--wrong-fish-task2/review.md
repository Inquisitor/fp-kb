---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15808
jira: https://fishingplanet.atlassian.net/browse/FP-42190
---

# Review: FP-42190 — DAILY MISSIONS: Server - wrong fish in task 2

## Summary

Bug fix for daily missions task generation: when a specific pond is chosen for a "second-kind" task (`RecentPonds` carries a fixed pond), the fish selection must be restricted to that pond. Before the fix, fish from sibling ponds in `RecentFish` could leak in (e.g. for pond 220 the task could ask for fish from pond 255). The feature is currently in Test environment, not yet in production — relevant for severity calibration of any post-fix concerns.

## Scope

- **LBM r15808** — DailyMissions - reduce fish selection to specific pond in tasks of second kind when specific pond was selected for task

## Investigation Journal

- 2026-04-26 — Phase 1 intake: created card before any VCS/diff inspection per `review-workflow-draft.md`. JIRA hygiene: `customfield_11224` (Executor) empty — expected `Yuriy Burda` per the commit comment; detect-only nudge, not blocking.
- 2026-04-26 — Inheritance verified: r15808 appears in `svn log` on `Shared/SharedLib/DailyMissions/CatchFishTasks/TaskBuilderSecond.cs` in MFT branch URL → fix is already inherited into MFT via branch copy (LBM r15808 ≤ MFT base r15942). No `svn merge` needed; `Merged → MFT` line will be omitted from JIRA comment.
- 2026-04-26 — VCS audit: `svn log --search "FP-42190" -r 1:HEAD` on LBM working copy returned a single commit r15808 by `yuriy.burda`. Matches JIRA comment — no extra/missing commits.
- 2026-04-26 — Verified default ctor of `TaskBuilderSecond()`: `MissionBuilderCatch.GenerateTask` instantiates via `new TaskBuilderSecond()`. Initial hypothesis "default ctor leaves `pondSettingsProvider` null → NRE on `pondSettingsProvider.GenerationSettings`" disproven: `TaskBuilderBase` default ctor (read at r15807) populates the field from `CachedPondSettingsProvider.Shared` singleton.
- 2026-04-26 — Verified dead-code claim for `fishCategoryToIdsMap`: `grep -rn "fishCategoryToIdsMap"` returns only writes (4 occurrences in `TestPondSettingsProvider`/`TestPondSettingsService`), no reads. Forward map `fishIdToCategoryMap` is read by `GetPondLocalFish` and `GetPondFishCategoryIds`; reverse map is unused.
- 2026-04-26 — Feature is in Test environment, not yet in production (per user). Severity calibration for behavioural-distribution findings (F-5) skewed toward Info — content team can tune in Test before release.
- 2026-04-26 — HEAD-verification pass on `TaskBuilderSecondTests.cs` and `TaskBuilderSecond.cs`: r15835 (FP-42281) fixed the four predicates (F-1 superseded), reshaped `GetFishCategoryAndPond` away from 50/50 toward settings-driven weights (F-2 / F-5 superseded). F-3 (dead `fishCategoryToIdsMap`) and F-4 (`DeterministicRandom` `public`) remain unchanged on HEAD. Lesson: when a commit is months old, verify finding survival on HEAD before routing — author may have already addressed the issue in a follow-up.

## Findings

### F-1: Test `should_return_different_variations_of_task` — copy-paste in 3 of 4 filter predicates [Low]

**File:** `Shared/SharedLib.Tests/DailyMissions/CatchFishTasks/TaskBuilderSecondTests.cs` (added in this commit).

**Description:** Four bucket filters are written as:

```csharp
var resultsWithPondAndFish     = results.Where(t => t is { PondId: > 0, FishCategoryid: > 0 }).ToList();
var resultsWithPondAndNoFish   = results.Where(t => t is { PondId: > 0, FishCategoryid: 0 }).ToList();
var resultsWithNoPondAndFish   = results.Where(t => t is { PondId: > 0, FishCategoryid: 0 }).ToList();
var resultsWithNoPondAndNoFish = results.Where(t => t is { PondId: > 0, FishCategoryid: 0 }).ToList();
```

The third and fourth buckets share the same predicate as the second (`PondId: > 0, FishCategoryid: 0`); their names imply `PondId: 0`. Net effect: the test never validates the `randomPond == 0` outcome, which is one of the new branches introduced by the fix (`else` arm in `GetFishCategoryAndPond`). The four `Assert.IsTrue(... > iterationsCount / 10)` calls all pass against the same overlap, so the test is green while not validating what its bucket names claim.

**Investigation:**
- Read the new test; counted predicates by hand.
- Re-read `TaskBuilderSecond.GetFishCategoryAndPond` to confirm both branches (specific pond / any pond) are reachable: `pondSelectionRules` includes a `(0, recentPondIds.Count)` row that reaches `randomPond == 0` ~ 50% of the time within the upper conditional.
- Concluded: the "any pond" branch is producible but not asserted by name in any of the four buckets.

**Resolution:** Skipped — already fixed in r15835 (FP-42281): four predicates corrected to `{PondId: 0, FishCategoryId: > 0}` / `{PondId: 0, FishCategoryId: 0}` for the last two buckets; the typo `FishCategoryid → FishCategoryId` was rectified in the same commit. Initial Medium downgraded first to Low (test-only), then to Skipped after HEAD verification.

**Discovered by:** skill recon.

### F-2: Test `should_return_fish_available_on_pond` — covers only `randomPond > 0` [Low]

**File:** `Shared/SharedLib.Tests/DailyMissions/CatchFishTasks/TaskBuilderSecondTests.cs`.

**Description:** The test asserts that when `PondId > 0` and `FishCategoryid > 0`, the chosen fish category is among `pondData[pondId]`. The `randomPond == 0` branch (fish from any recent pond) is reachable but unasserted. The fix's primary goal (specific-pond constraint) is covered; the secondary "any-pond" path is not.

**Investigation:**
- File inspection only; cross-referenced against the `else` branch in `GetFishCategoryAndPond`.
- HEAD verification: test was rewritten in r15835 (FP-42281) to drive `BuildTask` instead of `GetFishCategoryAndPond`; the `randomPond > 0` vs `== 0` dichotomy itself was removed in the same commit (probability now governed by `BasicConditionPondSelectionPool` / `BasicConditionFishSelectionPool` weights). Original framing of the finding no longer applies to HEAD code.

**Resolution:** Skipped — superseded by r15835 reshape. The branch this finding referred to no longer exists on HEAD; any related coverage concern belongs to FP-42281 review scope, not FP-42190.

**Discovered by:** skill recon.

### F-3: `TestPondSettingsProvider.fishCategoryToIdsMap` — written, never read [Low]

**File:** `Shared/SharedLib.Tests/DailyMissions/CatchFishTasks/TestSettings/TestPondSettingsProvider.cs` (added in this commit).

**Description:** The constructor populates `fishCategoryToIdsMap : Dictionary<int, List<int>>` (reverse map fish-category → fish-ids) alongside the forward map `fishIdToCategoryMap`. The forward map is consumed by `GetPondLocalFish` and `GetPondFishCategoryIds`; the reverse map has no readers anywhere in the tree. Test-only code — no runtime effect.

**Investigation:**
- `grep -rn "fishCategoryToIdsMap"` → 4 hits, all writes in `TestPondSettings*` (later renamed to `TestPondSettingsService` at r15838).
- HEAD verification: still dead — confirmed by reading `TestPondSettingsService.cs` on HEAD.

**Resolution:** Filed → `modules/missions/backlog.md` → Test Scaffolding. Test-only, no decision-affecting question for the author — pure tech-debt for future scaffolding cleanup.

**Discovered by:** skill recon.

### F-4: `DeterministicRandom`: `internal → public` [Info]

**File:** `Shared/ObjectModel/Randomization/DeterministicRandom.cs`.

**Description:** Visibility widening to allow direct construction from a sibling test assembly. Alternative: `[InternalsVisibleTo("SharedLib.Tests")]` on the defining assembly, which keeps the production API surface unchanged. Not a defect — observation only.

**Investigation:** File inspection only. HEAD verification: still `public`.

**Resolution:** Accepted — Info-only, card record. Stylistic choice; no JIRA mention (raising a 2-month-old visibility nit would be noise).

### F-5: Distribution shift in `(fish, pond)` outcomes [Info]

**File:** `Shared/SharedLib/DailyMissions/CatchFishTasks/TaskBuilderSecond.cs`.

**Description:** Behavioural shift relative to r15807:
- "no fish" arm is now an unconditional 50% (`if (rnd.NextDouble() < 0.5d) return (0, randomPond)`), no longer gated on `recentPondIds.Any() && pondFish.Any()`.
- A new "fish + any pond" outcome (`randomPond == 0` with non-empty `recentPondIds`) becomes reachable; previously this branch always returned `(0, randomPond)`.

Net effect on task-mix is content-design territory. Feature is in Test, content team can re-tune before release.

**Investigation:**
- Read `r15807` and `r15808` versions of `GetFishCategoryAndPond`; reasoned about the random pool weights (`(pondId, 1)` per recent + `(0, recentPondIds.Count)`) to estimate the post-fix distribution: ≈ 50% no-fish, ≈ 25% fish-on-specific-pond, ≈ 25% fish-on-any-pond.
- HEAD verification: r15835 (FP-42281) replaced the hard-coded 50/50 with settings-driven weights via `BasicConditionPondSelectionPool` / `BasicConditionFishSelectionPool` per difficulty — distribution is now content-tunable, not a code constant.

**Resolution:** Skipped — superseded by r15835. The observed distribution shift was a transient code-level behaviour; mechanism has since moved out of code into settings.

