# Missions — Backlog

## Config Validation

- WebAdmin mission-config save path cannot catch silently-ignored keys: `MissionsSerializationUtils.DeserializeTask` runs without `MissingMemberHandling.Error`, `JsonKeyValidator.AreAllKeysValid` (WebAdmin) checks key-name characters only (`^[@$A-Za-z0-9_]+$`), and `MissionTasksModel.PreprocessJson` validates parse-ability then stores the submitted raw JSON untouched. A key typo (`ItemSubTypo`) or a property lacking `[JsonProperty]` on an OptIn condition class saves cleanly and yields a silently-unfiltered condition — the failure class behind FP-45032. Note for the fix: naive `MissingMemberHandling.Error` won't work — mission JSON legitimately carries preprocessor constructs (`@resources`, predicate strings, hint objects); contract-aware validation must run post-preprocessing. From FP-45032 review (F-2, pre-existing).

## Test Coverage

- `MatchFishPredicate()` has zero test coverage — all `IFishCondition` fields uncovered (HookDepth, MaxHookDepth, MinGenerationDepth, MaxGenerationDepth, Weight, Length, FishForm, etc.)
- No tests for any `FishCondition` subclass (HookFishCondition, CatchFishCondition, FightFishCondition, etc.)
- No tests for `ReleaseFishFromCageInteraction` condition matching
- No tests for daily mission lifecycle at rollover: `Container_RefreshDailyMissions`, `GetMissionsCompleted` post-rollover, `TryGenerateMissions` when `missionsManager == null` (from FP-42372 review)
- `MissionCloneTests` extension (bool/string/list types, definition-pollution assert, nested-list isolation) — tracked in FP-45154. From FP-44758 review (F-4).

## Test Scaffolding

- `TestPondSettingsService.fishCategoryToIdsMap` (`Shared/SharedLib.Tests/DailyMissions/CatchFishTasks/TestSettings/`) populated by ctor, never read — only the forward `fishIdToCategoryMap` is consumed by `GetPondFish` / `GetPondFishCategoryIds`. Dead reverse map; remove or wire up if a future test needs category→ids lookup. From FP-42190 review (F-3).

## Clone Isolation

- Mission `Clone()` isolation gaps beyond the FP-44758 variable-dictionary fix — `BuyItemsHint` shared index sets (+ carrier conditions), `AssembleRodHint` shared component conditions (cross-player `CheckCached` bleed), `TasksToCheck` not reset, `RandomArray` shallow-copied arrays, `MissionCloneTests` extension — tracked in **FP-45154** (Technical Debt epic). Sibling audit of the remaining BaseHint/condition family found no other shared-mutation defects. From FP-44758 review (F-1..F-4).

## Processing Loop

- `MissionsManager.ProcessMessagesLoop` caps neither its outer cycle nor the inner `ProcessForwardMissions` loop, so a mission whose fail condition is still true immediately after an immediate restart (`RestartFailedMissionAfterMinutes: 0`) drives fail → restart → fail without bound, all under `lock (lockObject)`. Nothing enforces the invariant that currently protects the server: `MissionsValidator` checks only that a `TaskCompletedCondition` names an existing task, and live content stays safe by authoring convention alone — fail tasks are gated on mission counters that `Api_RemoveFailedMission` zeroes before the restart, and the one mission with a direct state-based fail condition has a start condition that is its logical negation. Wanted: an iteration cap, or a "restarted in this request" guard on fail evaluation. Tracked in **FP-45233**. From FP-44413 review (F-1).

## Concurrency

- `Container_RefreshDailyMissions` does not enter `lock (lockObject)` — other `Container_*` methods (`Container_AddNewMission`, `Container_RemoveMission`, `Container_RefreshMissions`) do. Likely safe under the peer's single-threaded execution fiber, but the pattern is inconsistent. Decide: enforce locking everywhere, or document why this method is intentionally lock-free. From FP-42372 review (F-5).

## Client Conversion

- `MissionsManager_Client.GetMissionsArchived` and `GetMissionsFailed` (`Shared/ObjectModel/Mission/MissionsManager_Client.cs`) pass profile entry to `ConvertToMissionOnClient`, then force `IsCompleted = false` post-call. With FP-42974's gate `!isMissionCompleted` reading `missionInProfile?.IsCompleted` (typically `false` for archived/failed entries), a previously-completed Club/Premium mission whose owner has since lost eligibility can re-emerge with `IsLocked=true` in the Archived/Failed lists. Visibility depends on whether the client's archived/failed UI tabs render the padlock — verify client-side before any patch. From FP-42974 review (F-1, pre-existing).

## Fish Form Detection

- `DailyMissionGenerator_Utils.GetFishId(fishCategoryId, fishForm)` (`Shared/SharedLib/DailyMissions/DailyMissionGenerator_Utils.cs`) still picks form-specific fish from a category by `fish.CodeName.EndsWith("Y" | "T" | "U")` — the same bug shape FP-42551 fixed on the credit side. If a category contains a fish whose `Status` is `Trophy / Young / Unique` without the conventional suffix (e.g. event fish placed inside a regular `FishCategoryId`), this lookup yields `0`. `categoryFish` is sourced from `FishCache.MultilingualFish` (`ServerFish`), which has `Status` available — the fix is `f.Status == FishStatus.Trophy` etc. From FP-42551 review (F-1, pre-existing).
