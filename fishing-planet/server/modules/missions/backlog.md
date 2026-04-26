# Missions — Backlog

## Test Coverage

- `MatchFishPredicate()` has zero test coverage — all `IFishCondition` fields uncovered (HookDepth, MaxHookDepth, MinGenerationDepth, MaxGenerationDepth, Weight, Length, FishForm, etc.)
- No tests for any `FishCondition` subclass (HookFishCondition, CatchFishCondition, FightFishCondition, etc.)
- No tests for `ReleaseFishFromCageInteraction` condition matching
- No tests for daily mission lifecycle at rollover: `Container_RefreshDailyMissions`, `GetMissionsCompleted` post-rollover, `TryGenerateMissions` when `missionsManager == null` (from FP-42372 review)

## Test Scaffolding

- `TestPondSettingsService.fishCategoryToIdsMap` (`Shared/SharedLib.Tests/DailyMissions/CatchFishTasks/TestSettings/`) populated by ctor, never read — only the forward `fishIdToCategoryMap` is consumed by `GetPondFish` / `GetPondFishCategoryIds`. Dead reverse map; remove or wire up if a future test needs category→ids lookup. From FP-42190 review (F-3).

## Concurrency

- `Container_RefreshDailyMissions` does not enter `lock (lockObject)` — other `Container_*` methods (`Container_AddNewMission`, `Container_RemoveMission`, `Container_RefreshMissions`) do. Likely safe under the peer's single-threaded execution fiber, but the pattern is inconsistent. Decide: enforce locking everywhere, or document why this method is intentionally lock-free. From FP-42372 review (F-5).

## Client Conversion

- `MissionsManager_Client.GetMissionsArchived` and `GetMissionsFailed` (`Shared/ObjectModel/Mission/MissionsManager_Client.cs`) pass profile entry to `ConvertToMissionOnClient`, then force `IsCompleted = false` post-call. With FP-42974's gate `!isMissionCompleted` reading `missionInProfile?.IsCompleted` (typically `false` for archived/failed entries), a previously-completed Club/Premium mission whose owner has since lost eligibility can re-emerge with `IsLocked=true` in the Archived/Failed lists. Visibility depends on whether the client's archived/failed UI tabs render the padlock — verify client-side before any patch. From FP-42974 review (F-1, pre-existing).

## Fish Form Detection

- `DailyMissionGenerator_Utils.GetFishId(fishCategoryId, fishForm)` (`Shared/SharedLib/DailyMissions/DailyMissionGenerator_Utils.cs`) still picks form-specific fish from a category by `fish.CodeName.EndsWith("Y" | "T" | "U")` — the same bug shape FP-42551 fixed on the credit side. If a category contains a fish whose `Status` is `Trophy / Young / Unique` without the conventional suffix (e.g. event fish placed inside a regular `FishCategoryId`), this lookup yields `0`. `categoryFish` is sourced from `FishCache.MultilingualFish` (`ServerFish`), which has `Status` available — the fix is `f.Status == FishStatus.Trophy` etc. From FP-42551 review (F-1, pre-existing).
