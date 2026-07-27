---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16287, merged to NPN20260602 @ r16288
jira: https://fishingplanet.atlassian.net/browse/FP-44761
---

# Review: FP-44761 — Wrong mission restart after fail via fail task

## Summary

Bug: when a mission fail is executed via a dedicated fail task, the mission does not work after restart — even the travel task does not complete although the player is on the correct pond; only a game reload helps. Per the executor's JIRA comment, the underlying fix landed in linked FP-44413; this task adds a variable-gated fail-task restart regression test (the affected mission is scripted differently, so new tests cover this case too).

## Scope

- **MFT20260325 r16287** — Add variable-gated fail-task restart regression test
- **NPN20260602 r16288** — Merge from MFT r16287

## Investigation Journal

- Intake from JIRA comment at face value: fix itself attributed to linked FP-44413; this task's scope is test-only (r16287 + merge r16288). To verify in Phase 2 via `svn log`/`svn diff`.
- VCS audit: `svn log` MFT r16000:HEAD and NPN r16131:HEAD grepped for FP-44761 → exactly r16287 (MFT, `FailedMissionRestartTests.cs` only) and r16288 (NPN merge of it). Matches the JIRA comment; no unposted commits, branch labels correct.
- WC freshness: WC at r16351 ≥ r16287 → disk reads trustworthy, no stale-WC fallback needed.
- Fix context from file history: r16263 (FP-44413) added the `UnregisterProcessed` loop in `MissionsManager_Start.cs` plus the base test file; r16271 (FP-44667) added the KeepTrackedOnRestart tests; r16287 appends the variable-gated scenario.
- Variable-wipe claim verified (control-flow trace, file reads): immediate-restart path `Processing_TryFailMissions` → `Api_FailMission` → `Api_RemoveFailedMission` (`MissionsManager_Fail.cs`) calls `LoadCountersAndVariablesAndInteractionsFromProfile(new StartedMission())`; `MissionsProfileUtils.LoadCountersAndVariablesAndInteractionsFromProfile` resets int variables to 0 when absent from the empty `StartedMission`. The "variable wiped on auto-restart" assert reflects a real engine mechanism, not test-only behavior.
- Mission 3968 mirror claim verified against local Main DB (`Missions` + `MissionTasks` ConfigJson, MissionId 3968 = `Anniversary15_SanJoaq`): `FailCondition` = TaskCompletedCondition Task_1, `RestartFailedMissionAfterMinutes: 0`; Task_1 = AND( OR(#iFishCount1..3 != 0), OR(TimeOfDayCondition, PondId==0, EndOfDayCondition) ); travel task = SerialCondition + PondCondition; catch tasks = SerialAchievement + `VariableSet '#iFishCountN = #iFishCountN + 1'`. The test simplifies to one variable and a Transition-predicate stand-in for the day-end leg (explicitly commented in the test); mirrored semantics hold.
- `EndOfDayCondition.Check` = `context.WasEndOfDayOccured` (`ConditionsGame/TimeConditions.cs`) — stateful within the pass, same as the test's `Transition` edge: the AND's second leg stays true at restart, so only the wiped variable holds the gate. Stand-in is faithful on the property that matters.
- Empirical run: built `ObjectModel.Tests` (MSBuild exit 0) and ran the `FailedMissionRestartTests` suite — 5/5 passed on HEAD build of the r16351 WC.
- Client-mirror check (Step 6): diff touches `Shared/ObjectModel.Tests/` only — test code is not distributed to the client; no mirror needed.
- No KB review card exists for FP-44413 — the base fix r16263 (and its base test) was not separately reviewed; this review's scope stays the r16287 test.
- Hypothesis disproven (own recon): "the Transition edge stays active at restart, so only the wiped variable holds the fail-watcher gate". Actually `AfterProcessingCycle` fires after EVERY internal processing cycle (`MissionsManager_Processing.cs` line ~168, inside the while loop), and the test's wire calls `ctx.AfterProcessingCycle()` which nulls `Transition` (`MissionsContext.cs`); the fail→restart happens on the second internal cycle, when Transition is already null. So the "must not re-fire" assert would hold even without the variable wipe; the wipe itself is covered by the direct `GetIntVariable == 0` assert instead.
- `TimeOfDayCondition.Check` verified stateful (pure function of `Profile.PondTimeSpent`, `ConditionsGame/TimeConditions.cs`): in real mission 3968 the day-leg OR can stay true across the restart via TimeOfDay(Hour 21, Range 20), making wiped variables the only guard against an immediate re-fail — a scenario the test's transient-Transition stand-in cannot reproduce. Coverage survives via the direct wipe assert; the behavioral consequence (no re-fail under a sustained second leg) is not exercised.
- Codex delegation (blind hunt) returned: no high-severity defects, test is a discriminating regression guard; four Low observations (state-assert instead of MissionTaskCompleted event for travel; event asserts don't check ordering/uniqueness; "Mirrors mission 3968" wording stronger than the stand-in fidelity; `context.Fish` is dependency noise — predicate reads only Transition). Re-verified its mechanism claims by reading `ProcessForwardMissions` (`RegisterProcessed` skip at `MissionsManager_Processing.cs`), `ConditionMonitoringSurface.RegisterProcessed/UnregisterProcessed`, `MissionsManager_Events.AddEvent` (synchronous), and `MissionsContext.AfterProcessingCycle` (clears `CaughtFish`, not `Fish`) — all four mechanisms match the code. Codex could not see mission 3968 content (DB-only) — covered by own DB verification above.
- Empirical mutation test (user-approved, clean baseline confirmed, no concurrent WC use): reverse-merged r16263 on `MissionsManager_Start.cs` only (`svn merge -c -16263 <file>` — the `UnregisterProcessed` loop removed; r16271's later edit to the same file does not overlap, applied cleanly), rebuilt, reran. Result: `FailedMissionRestartTests` → **2 failed / 3 passed** — both travel-bearing tests failed (`RestartFailedMission_variable_gated...` on the final travel assert line 272; base `RestartFailedMission_state_based...` on line 121), the three KeepTracked tests passed (they don't assert travel re-completion). Crucially the variable-gated test failed on the travel assert, NOT on the wipe assert (270) or re-fire assert (271) — those passed, empirically confirming F-2 (wipe is independent of r16263; re-fire is double-guarded). Then `svn revert` on the file (status clean, mergeinfo elided), rebuilt, reran → 5/5 green. WC restored. This upgrades the discrimination claim from deductive to empirically demonstrated.
- code-reviewer agent delegation (blind hunt, independent of Codex): no findings at its confidence bar. Independently confirmed discrimination via the `IsProcessed` bookkeeping trace (dynamic travel task stays in `TasksToCheck` while completed per `MissionsUtils.UpdateTasksToCheck`; its wrapper is re-marked processed in the same outer pass before the fail is detected; `Api_RemoveFailedMission` resets `IsCompleted` but not `IsProcessed`; without the r16263 loop the travel condition is silently skipped) and manually walked the no-collateral-state-change condition (VarCatcher / VarNeverComplete evaluate false→false post-wipe, nothing else re-arms travel). Sub-threshold notes: redundant `Level = 5` (helper already sets it — re-verified `MissionsTestHelper.cs`), `context.Fish` noise, and the same double-guarded re-fire observation as own recon.
- Re-verified agent's minor claims before accepting: `MissionsTestHelper.CreateMissionsManager` constructs the profile with `Level = 5`; `UpdateTasksToCheck` keeps `IsDynamic` tasks in `TasksToCheck` regardless of completion. Both match.
- Phase 3 executor-claims sweep (JIRA comment): "Fixed with another task (linked)" → r16263 diff read (fix in `MissionsManager_Start.cs`); "this mission scripted in a bit different way" → mission 3968 ConfigJson read from local Main DB (variable-gated fail vs the base test's bare transient edge); "new tests also will cover this case" → discrimination trace above; "MFT @ r16287, Merged => NPN r16288" → `svn log` both branches. All claims verified, none taken at face value.
- Merge verification at close: `svn cat` on the NPN copy of `FailedMissionRestartTests.cs` returns the variable-gated test content (token match), so r16288 carried content, not just mergeinfo. `Merged → NPN` is a truthful audit line. No merge performed by this review (executor already merged); JIRA re-fetch at close: status In Review, executor field filled = Yuriy Burda, `customfield_11323` empty and n/a (test-only diff derives no release-step option).

## Findings

### F-1: Event asserts are existence-only; travel re-completion asserted as state, not behavior [Low]

**Description:** In `RestartFailedMission_variable_gated_fail_watcher_wipes_variable_and_recompletes_travel`, the fail-loop slice is checked only via `Exists(MissionFailed)` / `Exists(MissionStarted)` — no ordering or uniqueness — and travel re-completion is asserted from final `IsCompleted` state rather than a `MissionTaskCompleted` event scoped to the restart. The test stays discriminating for the r16263 revert, but a hypothetical defect that preserved the stale `IsCompleted` flag (instead of re-evaluating) would still pass it.

**Investigation:** Codex claimed the discrimination mechanism and the state-vs-event gap; re-verified the mechanism by reading `ProcessForwardMissions` (processed-wrapper skip via `RegisterProcessed` returning false), `ConditionMonitoringSurface.RegisterProcessed`/`UnregisterProcessed`, and `Api_RemoveFailedMission` (resets `IsCompleted`, not `IsProcessed`): reverting r16263 leaves the travel wrapper processed and the assert fails — confirmed discriminating. `AddEvent` read in `MissionsManager_Events.cs` — events fire synchronously, so the `GetRange` slice scoping itself is sound (both delegates agree).

**Resolution:** Accepted — non-blocking test-strength observation; worth folding in on the next edit of this file (assert a restart-scoped `MissionTaskCompleted` for the travel task). **Follow-up pending:** at close, decide whether a small "strengthen mission-restart test asserts" follow-up is worth filing (candidate consolidation of F-1 + F-2 stronger-variant).

**Discovered by:** Codex

### F-2: Re-fire assert is double-guarded — the transient stand-in makes the variable wipe not load-bearing for it [Low]

**Description:** The assert "wiped variable → fail-watcher must not immediately re-fire" holds for two independent reasons: the wipe AND the fact that `Transition` is already null on the restart cycle (the test's `AfterProcessingCycle` wire clears it after every internal cycle, and fail→restart happens on the second one). In real mission 3968 the day-leg OR includes `TimeOfDayCondition` (pure function of `Profile.PondTimeSpent`) which survives the restart — there the wipe is the only guard against an immediate re-fail. That production-shaped scenario (sustained second leg) is not exercised; wipe coverage survives only via the direct `GetIntVariable == 0` state assert.

**Investigation:** Own recon initially assumed the Transition edge stays active at restart — disproven by reading `MissionsManager_Processing.cs` (`AfterProcessingCycle` fires inside the internal while loop) and `MissionsContext.AfterProcessingCycle` (nulls `Transition`). `TimeOfDayCondition.Check` read in `ConditionsGame/TimeConditions.cs` — stateful, computed from `PondTimeSpent`, no transient dependency. Mission 3968 day-leg composition read from local Main DB ConfigJson. The code-reviewer agent independently reported the same double-guard observation.

**Resolution:** Accepted — the wipe is still directly asserted, so the regression is caught, just via state rather than behavior. A stronger variant would gate the second leg on a stateful predicate (e.g. a profile property) so the wipe alone holds the gate. **Follow-up pending:** companion to F-1 in the same potential "strengthen mission-restart test asserts" follow-up — decide at close.

**Discovered by:** skill recon + code-reviewer agent (independently)

### F-3: "Mirrors mission 3968" doc-comment overstates stand-in fidelity [Info]

**Description:** The factory's XML-doc says it mirrors mission 3968, while the build simplifies: one variable instead of OR over three, a `Transition` predicate instead of the `TimeOfDayCondition`/`PondId==0`/`EndOfDayCondition` OR-leg, `PredicateCondition` instead of `CatchFishCondition`. The inline comment does flag the stand-in ("stands in for 3968's TimeOfDay/EndOfDay leg"), so the reader is warned; topology and fail/restart semantics match the real content.

**Investigation:** Mission 3968 `Missions.ConfigJson` + `MissionTasks.ConfigJson` read from local Main DB (Anniversary15_SanJoaq) and compared leg-by-leg against the factory; `EndOfDayCondition.Check` = `context.WasEndOfDayOccured` — also cleared by `AfterProcessingCycle`, so of the real day-leg only `TimeOfDayCondition` differs in restart behavior (see F-2).

**Resolution:** Skipped — comment already carries the caveat; wording precision is not worth a follow-up commit on its own.

**Discovered by:** Codex (fidelity wording) + skill recon (DB comparison)

### F-4: Minor test noise — unused `context.Fish`, redundant `Level = 5` [Info]

**Description:** `context.Fish = new Fish { FishId = 1 }` is read by no condition in this mission (the catch predicate reads only `Transition`), and `context.GetProfile().Level = 5` duplicates the helper default. Both harmless; `Fish` is explicitly nulled before the EndOfDay edge, so no leakage either.

**Investigation:** Predicate expressions of the factory re-read; `MissionsTestHelper.CreateMissionsManager` read — profile constructed with `Level = 5`; `MissionsContext.AfterProcessingCycle` read — clears `CaughtFish` but not `Fish`, hence the explicit null assignment in the test is what prevents leakage.

**Resolution:** Skipped — cosmetic; not worth a commit.

**Discovered by:** Codex + code-reviewer agent

## Verdict

**Approve.** r16287 is a test-only commit that adds a discriminating regression guard for the FP-44413 fix (r16263); r16288 is its clean merge to NPN. No defects at or above Low that block: the four findings are two Low test-strength observations (F-1, F-2, both Accepted) and two Info cosmetics (F-3, F-4, Skipped). The test compiles, runs green (5/5) on the HEAD build, follows the established sibling-test pattern, and matches `.editorconfig` conventions.

**Verification scope:** the fix itself (r16263, FP-44413) is out of this review's scope and was not separately reviewed — this review covers only the test. The test's discriminating power against a r16263 revert is **empirically demonstrated** (mutation test: reverse-merge r16263 → 2 travel-bearing tests fail → revert → 5/5 green; see Investigation Journal), corroborating the deductive traces (skill recon + code-reviewer agent + Codex converge on the `IsProcessed` bookkeeping mechanism). Fidelity to the real mission 3968 is partial by design (F-2/F-3): the day-end leg is a transient `Transition` stand-in, not the stateful `TimeOfDayCondition` of production, so the "sustained second leg → wipe is the sole guard" scenario is not exercised (the wipe is still directly asserted, and the mutation test showed the wipe assert is independent of the r16263 fix).

**Follow-up (decided):** no JIRA ticket. Recorded as a single "touch-if-here" item in the missions module backlog (Test Assertion Strength), merged with the sibling FP-44413 F-2 observation — both reviews converged on weak fail/restart event asserts in `FailedMissionRestartTests.cs`. All Low/cosmetic; the file's next edit strengthens them. Decision made in the context of the FP-44413 review (closed ship-and-reopen; reopen reason is content mission 3957, unrelated to this test).
