# Missions — Backlog

## Config Validation

- WebAdmin mission-config save path cannot catch silently-ignored keys: `MissionsSerializationUtils.DeserializeTask` runs without `MissingMemberHandling.Error`, `JsonKeyValidator.AreAllKeysValid` (WebAdmin) checks key-name characters only (`^[@$A-Za-z0-9_]+$`), and `MissionTasksModel.PreprocessJson` validates parse-ability then stores the submitted raw JSON untouched. A key typo (`ItemSubTypo`) or a property lacking `[JsonProperty]` on an OptIn condition class saves cleanly and yields a silently-unfiltered condition — the failure class behind FP-45032. Note for the fix: naive `MissingMemberHandling.Error` won't work — mission JSON legitimately carries preprocessor constructs (`@resources`, predicate strings, hint objects); contract-aware validation must run post-preprocessing. From FP-45032 review (F-2, pre-existing).

## Test Coverage

- `MatchFishPredicate()` has zero test coverage — all `IFishCondition` fields uncovered (HookDepth, MaxHookDepth, MinGenerationDepth, MaxGenerationDepth, Weight, Length, FishForm, etc.)
- No tests for any `FishCondition` subclass (HookFishCondition, CatchFishCondition, FightFishCondition, etc.)
- No tests for `ReleaseFishFromCageInteraction` condition matching
- No tests for daily mission lifecycle at rollover: `Container_RefreshDailyMissions`, `GetMissionsCompleted` post-rollover, `TryGenerateMissions` when `missionsManager == null` (from FP-42372 review)
- `MissionCloneTests` extension (bool/string/list types, definition-pollution assert, nested-list isolation) — tracked in FP-45154. From FP-44758 review (F-4).

## Test Assertion Strength

- `FailedMissionRestartTests.cs` (`Shared/ObjectModel.Tests/Mission/`) — when this file is next touched, strengthen the fail/restart event assertions. Two independent reviews converged on the same family: the base `RestartFailedMission_state_based...` test never scopes its `events` list, so its `MissionStarted` assertion is already satisfied by the first-start event before the fail cycle runs and proves nothing about the restart (FP-44413 F-2); the later `RestartFailedMission_variable_gated...` test fixed that with an `eventCountBeforeFail`/`GetRange` slice but its checks are still existence-only (no ordering/uniqueness) and it asserts travel re-completion from final `IsCompleted` state rather than a restart-scoped `MissionTaskCompleted` event, and its "must not re-fire" assertion is double-guarded (the transient `Transition` edge is already null on the restart cycle, so the variable wipe is not load-bearing for it — a production mission like 3968 with a stateful `TimeOfDayCondition` day-leg would exercise the wipe-as-sole-guard path the test does not). Wanted on next touch: scope the base test's events before the fail cycle; assert a restart-scoped `MissionTaskCompleted` for the travel task; gate the fail-watcher's second leg on a stateful predicate so the wipe alone holds the gate. All Low/cosmetic — the tests discriminate their target regression (FP-44761's was confirmed by an empirical revert-of-r16263 mutation run). From FP-44413 review (F-2) and FP-44761 review (F-1/F-2).

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

## Condition/Hint Caching

- `BaseHintRegular.CheckCached` (`Shared/ObjectModel/Hint/Hints/BaseHintRegular.cs`) uses the same single-barrier `RequestId`-only cache the mission conditions had before FP-44859 (r16291), with no dirty bit. Unlike conditions, `IHint` exposes no `ResetCached` at all — hints invalidate only via the coarse full `Reset()`, so hint display text can go stale for the rest of a processing pass when a monitored dependency changes mid-pass. Cosmetic (display text, single-pass, no cross-request cache), so left unpatched. If hints ever gain per-dependency invalidation, this cache needs the same dirty-bit guard the conditions got. Also noted in **FP-45234** (the condition-side residual-window task). From FP-44859 review (F-3, pre-existing).

## Fish Form Detection

- `DailyMissionGenerator_Utils.GetFishId(fishCategoryId, fishForm)` (`Shared/SharedLib/DailyMissions/DailyMissionGenerator_Utils.cs`) still picks form-specific fish from a category by `fish.CodeName.EndsWith("Y" | "T" | "U")` — the same bug shape FP-42551 fixed on the credit side. If a category contains a fish whose `Status` is `Trophy / Young / Unique` without the conventional suffix (e.g. event fish placed inside a regular `FishCategoryId`), this lookup yields `0`. `categoryFish` is sourced from `FishCache.MultilingualFish` (`ServerFish`), which has `Status` available — the fix is `f.Status == FishStatus.Trophy` etc. From FP-42551 review (F-1, pre-existing).
