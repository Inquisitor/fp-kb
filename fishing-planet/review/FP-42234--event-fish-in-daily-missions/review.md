---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15850, r15875
jira: https://fishingplanet.atlassian.net/browse/FP-42234
related: FP-42233
---

# Review: FP-42234 — DAILY MISSIONS: Server - Event fish in daily missions (double check)

## Summary

Daily-mission generation occasionally selected event fish on accounts where leftover event-fish missions survived a profile reset (related to FP-42233 regeneration gap). Fix adds a defensive filter so that any fish not currently defined in the bite system is excluded from mission generation — guards both the canonical "event fish removed from bite system" case and the residual leftovers from broken cleanup.

## Scope

### LBM
- **r15850** — Daily missions: additional rules for tasks generation when recent pond/fish lists are empty *(not posted to JIRA — see F-1)*
  - Wires `CurrentPondId` into `ProfileContext` (`[JsonIgnore]`, callback over `profile.PondId`)
  - `TaskBuilderFirst`: fallback chain when `RecentFish` empty → fish from current pond, else random from available ponds
  - `TaskBuilderFirst`: fallback chain when `RecentPondId` empty → current pond, else random
  - `TaskBuilderSecond`: same fallback for empty `recentPondIds`
  - Adds parameterized ctor for both Builders (testability); parameterless retains production wiring via `TaskBuilderBase` singletons
  - Adds `TaskBuilderFirstTests` (new file) and 2 tests in `TaskBuilderSecondTests`
- **r15875** — Daily missions: ensure that fish not defined in bite system will not be selected for mission
  - Single-line defensive filter on `recentCaughtFish`: requires `(PondId, FishCategoryId)` to still be present in current bite-system catalog of the pond
  - Adds 2 tests covering stale entry filtering + all-stale fallback to random

### MFT (inherited via branch copy)
- Both r15850 and r15875 are present in MFT via the LBM:r15942 → MFT:r15943 copy point (no explicit merge)

## Investigation Journal

- 2026-04-26 — Card created at intake. Pre-release context (feature in Test environment, not production) — affects severity calibration. `customfield_11224` (Executor) empty in JIRA — detect-only nudge per Phase 1 step 1a; no auto-fill.
- 2026-04-26 — VCS audit (`svn log --search "FP-42234"`) returned r15850 + r15875; only r15875 was posted in the JIRA comment. Cross-checked FP-42233 via separate search to confirm r15850 isn't a mis-tag (FP-42233 owns r15833 separately). r15850 is genuinely scoped to FP-42234. Surfaced as F-1 (executor-quality).
- 2026-04-26 — Verified branch-copy inheritance for MFT: both r15850 and r15875 appear in `svn log` on `DailyMissionUtils.cs` and `TaskBuilderFirst.cs` at the MFT URL. Per ancestry (MFT base r15942), both are inherited; no explicit merge required, JIRA comment must omit `Merged → MFT` line.
- 2026-04-26 — Hypothesis: `TaskBuilderSecond` may share the same RecentFish vulnerability. Disproven by reading `TaskBuilderSecond.GenerateByRecentPonds` — `recentFishCategoryIds` is used as EXCLUSION (`.Except(recentFishCategoryIds)`), not selection; actual fish is sourced from live `GetPondFishCategoryIds`. Stale entries can only over-exclude (no-op for fish missing from current catalog). Fix scope of r15875 is correct.
- 2026-04-26 — Hypothesis: parameterless `TaskBuilderFirst()` introduced in r15850 might be dead. Disproven via `Grep "new TaskBuilderFirst\(\)"` → `MissionBuilderCatch.cs:19` uses it in production; `TaskBuilderBase()` parameterless ctor wires cached singletons. Parameterized ctor is for tests. Pattern is symmetric with TaskBuilderSecond.
- 2026-04-26 — HEAD-verification of r15875 fix: filter `pondSettingsService.GetPondFishCategoryIds(f.PondId, context.Level).Contains(f.FishCategoryId)` is preserved on HEAD with an added `context.Level` parameter (acceptable refactor). Tests added in r15875 still present at `TaskBuilderFirstTests.cs:445,478`.

## Findings

### F-1: Commit `r15850` is part of FP-42234 but was not posted in the JIRA comment [Info]

**Description**: The executor's JIRA comment lists only `LBM @ r15875`. VCS audit (`svn log --search "FP-42234"`) found a second commit `r15850` by the same author, also tagged `FP-42234` ("Daily Missions - additional rules for tasks generation when recent pond/fish lists are empty"). r15850 is the larger of the two — it introduces the `CurrentPondId` infrastructure, fallback chains for empty Recent* lists, and a new test file. Without seeing it from JIRA alone, the reviewer (or future archaeology on this ticket) misses substantial scope. Recurring pattern (FP-42924 had the same shape with `MonetizationCache.cs`).

**Investigation**: `svn log --search "FP-42234" -r 15000:HEAD` on LBM working copy returned both revisions. Cross-checked FP-42233 has its own commit (r15833) so r15850 is not a mis-tag. Both commits are functionally complementary parts of the same fix surface (TaskBuilderFirst / TaskBuilderSecond fish-and-pond selection).

**Resolution**: `Accepted` — non-blocking executor-quality nudge to be surfaced in the LGTM comment as a non-blocking note.

**Discovered by**: VCS audit (Phase 2 step 1)

## Verdict

LGTM. r15875 is a small, correctly scoped defense-in-depth filter that prevents stale (incl. event) fish from leaking into daily mission generation; r15850 introduces solid empty-list fallback rules with adequate test coverage. Both are inherited in MFT via branch copy — no explicit merge required. One non-blocking executor-quality note (F-1) for visibility.

