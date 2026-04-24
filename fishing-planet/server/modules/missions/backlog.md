# Missions — Backlog

## Test Coverage

- `MatchFishPredicate()` has zero test coverage — all `IFishCondition` fields uncovered (HookDepth, MaxHookDepth, MinGenerationDepth, MaxGenerationDepth, Weight, Length, FishForm, etc.)
- No tests for any `FishCondition` subclass (HookFishCondition, CatchFishCondition, FightFishCondition, etc.)
- No tests for `ReleaseFishFromCageInteraction` condition matching
- No tests for daily mission lifecycle at rollover: `Container_RefreshDailyMissions`, `GetMissionsCompleted` post-rollover, `TryGenerateMissions` when `missionsManager == null` (from FP-42372 review)

## Concurrency

- `Container_RefreshDailyMissions` does not enter `lock (lockObject)` — other `Container_*` methods (`Container_AddNewMission`, `Container_RemoveMission`, `Container_RefreshMissions`) do. Likely safe under the peer's single-threaded execution fiber, but the pattern is inconsistent. Decide: enforce locking everywhere, or document why this method is intentionally lock-free. From FP-42372 review (F-5).
