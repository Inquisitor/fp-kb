---
status: resolved
executor: Yuriy Burda
branch: NPN20260602 @ r16180, merged to MFT20260325 @ r16257
jira: https://fishingplanet.atlassian.net/browse/FP-44392
---

# Review: FP-44392 — ANNIVERSARY 2026: Server - UniqueBy doesn't work as intended

## Summary

Bug report: a `SerialAchievement` mission task declared with `UniqueBy: 'FishCategoryId'` does not count unique values as the Mission System Manual describes. Reported repro (mission 3948, task 15656, Lone Star): catching a Green Sunfish and then a White Crappie leaves the counter at 1/5 instead of 2/5.

Executor's fix is reported in two parts: the `UniqueBy` stalling fix itself, and a follow-up fixing a `StackOverflowException` in the accompanying dedup isolation test.

## Scope

### NPN20260602
- **r16180** — Fix SerialAchievement UniqueBy stalling on a repeated completion
- **r16260** — Merge of MFT r16259

### MFT20260325
- **r16257** — Merge of NPN r16180
- **r16259** — Fix StackOverflowException in UniqueBy dedup isolation test

> Audited: `svn log -r 16100:HEAD` on both branches, filtered for `FP-44392`, returns exactly these four revisions — JIRA comment matches VCS, no unposted commits.

### Mechanism of the change

`SerialAchievement.Check()` / `StepByStepAchievement.Check()` previously registered the "re-arm" monitoring dependency as a side effect of a successful `MissionsContext.IncrementCounter(counter, dependency)` — so no increment meant no re-arm. The fix extracts that into an explicit `MissionsContext.ReArm(mission, monitoringDependency)` called unconditionally after every completed occurrence, and drops the `dependency` parameter from the `IncrementCounter`/`ResetCounter` overloads.

Why re-arming matters: `SerialCondition.GetMonitoringDependencies` is dynamic — once the wrapper's dependency map is initialised it only reports the dependencies of conditions `0..lastPassedIndex+1`. After a completed occurrence the sequence is `Reset()` to `lastPassedIndex = -1`, so the monitored set collapses to the dependencies of condition index 0. For a multi-step task whose index 0 is a prerequisite (not the triggering event), nothing the player does afterwards touches the task again — it stalls permanently — unless the achievement's own `ResourceKey + "_SA"` dependency is re-raised to walk the sequence forward.

## Investigation Journal

- Intake from JIRA: executor = Yuriy Burda (commit author per JIRA comment), matches the `Executor` field.
- Verified the two merge revisions are content-identical to their sources: `svn diff -c 16257 --summarize` (MFT) lists the same six paths as r16180, `svn diff -c 16260 --summarize` (NPN) lists the single test file of r16259. No hand-edits smuggled into the merges.
- WC freshness: `svn info --show-item revision` = r16364, ahead of every reviewed revision, so disk reads are safe for architecture; `MissionsContext.cs` was touched again in r16273 (unrelated task), so all "what the diff did" claims are taken from `svn diff -c`, not disk.
- Verified the claim in the `ReArm` code comment that the raised change value is never read: `CurrentValue` / `.OldValue` / `.NewValue` have no consumer anywhere in the repo outside `Mission/DependencyChange.cs` (repo-wide grep over `.cs` and `.cshtml`; the only hits are unrelated same-named members in `ObjectModel.Tests/Core/AssertedValue.cs`, `TestCounter.cs` and SQL/DTO code). `MissionsContext.OnDependencyChanged` reads only `IsChanged` and `Name`; the `changes` list is consumed exclusively via `OfType<DependencyChangeCollectionItem<...>>`, which a `DependencyChangeInt` never matches. Synthetic `Updated(0, 1)` is therefore safe.
- Verified the key-shape change from `context.SelfMission.MissionId` to the condition's own `mission.MissionId` is not merely equivalent but strictly more correct: `ConditionMonitoringSurface.RegisterMonitoringDependecies` registers mission-bound dependencies under `dependency + "/" + wrapper.Mission.MissionId`, i.e. the owning mission — exactly what `BaseCondition.mission` holds (`Mission.Init` passes `this` down through `task.Init` to `CompleteCondition.Init`). The old code depended on `SelfMission` happening to be set to the same mission at call time.
- Verified `ResourceKey + "_SA"` is in fact mission-bound: `ConditionMonitoringSurface.IsMissionBoundDependency` returns true for keys starting with `@`, and `SerialAchievement.Init` defaults `ResourceKey` to `@SerialAchievement_<taskId>`. Content check (local `Main`): no achievement task declares a `ResourceKey` whose value does not start with `@` — caveat, the query tests the whole `ConfigJson` string, so a task mixing an `@`-prefixed and a bare key would not be caught.
- Verified production termination safety by trace: `MissionsManager_Processing.ProcessMessagesLoop` fires `AfterProcessingCycle` (line ~196) *before* draining `dependenciesToRaiseAfterProcessing` (line ~199), and the only production owner of a `MissionsManager` is `GameClientPeer_Missions` (`new MissionsManager` repo-wide is otherwise test-only), which both subscribes `AfterProcessingCycle` → `profile.MissionsContext.AfterProcessingCycle()` and sets a non-recursive `ScheduleProcessing = () => executePostProcessing = true`. Per-rod contexts are cleared by `GameProcessor.MissionsManager_AfterProcessingCycle`. So the re-raise cannot re-trigger the same occurrence: `Transition`/`Fish` are already cleared.
- Verified no `Collection was modified` hazard on the drain loop: `MissionsContext.OnDependencyChanged` only records into `dependenciesChanged`/`changes`; the re-entrant `ScheduleProcessing?.Invoke()` happens after the `foreach` completes.
- Ran the full `ObjectModel.Tests` suite at HEAD after an MSBuild Debug build: 687 passed, 1 skipped, 0 failed. This rules out the standing regression risk that tests built via `MissionsTestHelper.CreateMissionsManager` (synchronous `ScheduleProcessing`, no `AfterProcessingCycle` subscription) would now recurse into `StackOverflowException`.
- Content exposure (local `Main`, `MissionTasks.ConfigJson`): 892 tasks use `SerialAchievement`, 1 uses `StepByStepAchievement`, 1 uses `UniqueBy`. The re-arm path is therefore exercised by essentially the whole mission catalogue, not just the reported task.
- Confirmed the reported task's shape from content rather than from the commit message: task 15656 (`Task_4`) is a `SerialAchievement { Count: 5, UniqueBy: 'FishCategoryId' }` whose sequence starts with `TaskCompletedCondition { TaskCode: 'Task_3' }` and ends with `CatchFishCondition { BaitId: 434 }` — a multi-step sequence, matching the shape the new regression test models and the one that stalls when the monitored set collapses.
- Hypothesis "the reporter's two fish were the same `FishCategoryId`, so the stall was really a post-duplicate stall" — DISPROVEN by data: `Fish` rows give GreenSunfish → CategoryId 66, WCrappie → CategoryId 71. The STR describes two distinct categories, so the reported symptom is a stall that occurred without any duplicate, which the "stalling on a repeated completion" framing of the commit message does not by itself explain.
- Correction to an earlier reading of my own: the `Missions.cshtml` change looked like it touched only one of four rendering sections — that was an artefact of truncating `svn diff` output with `head`. The full per-file diff shows all four sections got the `ListVariables` block.
- Correction to an earlier reading of my own: I first recorded production `ScheduleProcessing` as a deferred flag and therefore non-recursive. It is not — `GameClientPeer_Missions.ProcessMissions()` ends with `if (executePostProcessing) { executePostProcessing = false; ProcessMissions(); }`, i.e. synchronous self-recursion on the same stack, same shape as the test harness. The delegated agent caught this. It does not change the termination verdict (state is cleared before the drain) but it does change the cost of getting the contract wrong: an unbounded re-arm loop would be an uncatchable `StackOverflowException` taking down the GameServer process, not a slow tick.
- Empirical discriminating-power check (user-approved, WC mutated and restored): reverse-merged r16257 across the four ObjectModel code files only, keeping the new tests; resolved one conflict in `MissionsContext.cs` against the later r16273 hunk by keeping r16273's `RecordChangedMissionVariable`/`GetChangedMissionVariables` and restoring the pre-fix `ResetCounter(..., string dependency = null)` signature. Rebuilt, ran `UniqueByTests`. Result: `UniqueBy_two_step_serial_different_categories_should_increment` FAILED (`Expected:<2>. Actual:<1>`) — the new regression test genuinely discriminates. The debug trace shows the mechanism directly: after the duplicate catch the sequence logs `SerialPROGRESS: 1, to 1 (DONE)` with no `CounterIncremented` and no subsequent `SerialPROGRESS: 0, to 0`, i.e. the sequence completed, did not count, and was never re-armed.
- Resolved the STR discrepancy empirically with a throwaway probe test (added, run, reverted — not part of any commit): the literal ticket STR (catch category 66, then category 71, no duplicate in between) PASSES against the pre-fix code. So the reported symptom is not reproducible as stated; the stall requires a duplicate `FishCategoryId` occurrence in between, exactly as the commit message says. Afterwards `svn revert` on all five files, rebuild, full suite green (687 passed, 1 skipped).

## Findings

### F-1: Unconditional re-arm has no termination bound; the contract that stops it is external and unasserted [Low]

**Description:** `SerialAchievement.Check()` / `StepByStepAchievement.Check()` now call `context.ReArm(...)` after every completed occurrence, including occurrences that make no progress (`UniqueBy` duplicate, or `IncrementCounter` returning false). Nothing in either class bounds how many no-progress re-arms may happen. Termination rests entirely on `MissionsContext.AfterProcessingCycle()` having cleared the triggering state before the drain — a contract the achievement neither enforces nor asserts. It matters because production `ScheduleProcessing` is synchronous self-recursion (`GameClientPeer_Missions.ProcessMissions`), so a runaway loop is an uncatchable `StackOverflowException` that kills the GameServer process and every player on the node, not a degraded tick.

**Investigation:**
- Traced the loop: `ReArm` → `dependenciesToRaiseAfterProcessing` → drain in `MissionsManager_Processing.ProcessMessagesLoop` → `OnDependencyChanged` → `ConditionMonitoringSurface.OnDependencyChanged` (exact-key match on `@<ResourceKey>_SA/<missionId>`) → `dependenciesChanged` → `ScheduleProcessing`. Conclusion: the re-raise does reach the wrapper, so the loop is real, not theoretical.
- Read `GameClientPeer_Missions.ProcessMissions` at HEAD: `if (executePostProcessing) { executePostProcessing = false; ProcessMissions(); }` — synchronous recursion inside a `catch (Exception)` that cannot catch `StackOverflowException`. Conclusion: cost of a runaway loop is process death.
- Reachability, content instrument (local `Main`, `MissionTasks.ConfigJson`): `UniqueBy` is declared by exactly one task (15656), and its terminal step is `CatchFishCondition`. Read `BaseFishCondition.Check`: it returns false immediately when `Transition != context.Transition`, and `AfterProcessingCycle()` nulls `Transition`. Conclusion: the sequence cannot re-complete without a fresh catch, so no unbounded loop is reachable on the current content.
- For non-`UniqueBy` achievements (892 tasks) `Achieved` advances on every occurrence, so `Achieved >= Count` short-circuits `Check()` — bounded by `Count`. Conclusion: latent, not live.
- Scope caveat: this binds to the current content snapshot. A future `SerialAchievement` + `UniqueBy` whose terminal step is satisfiable from state surviving `AfterProcessingCycle()` (`Fish`, `PondId`, `IsOnBoat`, inventory, mission variables, task-completed flags are NOT cleared) would make it live, with no code change and no test to catch it.

**Resolution:** `Filed → FP-45259`. Not blocking this review. Carries both the guard work and the structural option: stop narrowing the monitored set for a re-arming achievement — override `GetMonitoringDependencies` in `SerialAchievement`/`StepByStepAchievement` to always report every step's dependencies — which removes the need for `ReArm` and its unbounded feedback edge entirely.

**Discovered by:** code-reviewer agent (raised as High; severity reduced to Low after the content-reachability check above).

### F-2: The ticket's STR is not reproducible as a defect; the fixed scenario is a different one [Info]

**Description:** The reported repro — catch Green Sunfish then White Crappie, expect 2/5, observe 1/5 — passes against the pre-fix code. The two fish are genuinely different categories (`Fish` rows: GreenSunfish → 66, WCrappie → 71), so the reporter's expectation was right, but the pre-fix code satisfies it. The actual defect needs a duplicate-category catch in between, which is what the commit message says and what the new regression test encodes. It matters because the ticket will be verified by QA against an STR that does not fail even on the broken build.

**Investigation:**
- Queried `Fish` for both species: distinct `CategoryId` (66 vs 71) — ruled out the "same category, so 1/5 was correct" reading.
- Read the reported task's content (`MissionTasks` 15656): `SerialAchievement { Count: 5, UniqueBy: 'FishCategoryId' }` over `TaskCompletedCondition → … → CatchFishCondition { BaitId: 434 }` — a multi-step sequence, the shape the fix targets.
- Empirical: with the fix reverse-merged, a probe test replaying the literal STR passed, while the author's duplicate-containing test failed with `Expected:<2>. Actual:<1>`. Conclusion: STR incomplete, mechanism confirmed.

**Resolution:** `Accepted` — no code consequence. Card-only: raising it with QA was considered and dropped during the findings discussion (QA is aware of the real scenario).

**Discovered by:** skill recon.

### F-3: The test factory still ships the crash-prone default, so the same omission was fixed twice [Low]

**Description:** `MissionsTestHelper.CreateMissionsManager` sets `ScheduleProcessing = () => manager.ProcessMessagesLoop()` (synchronous recursion) but does not subscribe `AfterProcessingCycle`, so every test that exercises a re-arming achievement must remember to add the subscription by hand. r16180 added it to several tests; r16259 exists solely because one more test was missed and stack-overflowed. The next such test will hit the same trap, and the failure mode is an aborted test host rather than a red assertion.

**Investigation:**
- Read `MissionsTestHelper.cs`: recursive `ScheduleProcessing`, no `AfterProcessingCycle` subscription. `MissionsTest_Missions.PrepareMissionsManager` and `ReloginHiddenWhileQueuedTests.BuildManager` have the same shape.
- Counted the hand-added subscriptions across the two commits — the same one-line idiom repeated per test.
- Ran the full `ObjectModel.Tests` suite at HEAD: 687 passed, 0 failed. Conclusion: no test is broken today; this is about the default, not a live failure.
- Caveat on the obvious fix: moving the subscription into the factory would break `ConditionVariableSetTests`, which asserts the harness-only outcome that all counts fire within one `ProcessMessagesLoop` because the transition is never cleared. That test encodes a harness artefact as expected behaviour and would need its expectation corrected alongside.

**Resolution:** `Filed → FP-45259` (item 2 of that ticket). Not blocking.

**Discovered by:** skill recon and code-reviewer agent independently.

### F-4: `StepByStepAchievement` repeats the `"_PA"` suffix as a literal in two places [Low]

**Description:** `GetMonitoringDependencies` and `Check` each build `ResourceKey + "_PA"` from a string literal, while `SerialAchievement` uses a `CounterDependencySuffix` constant for the same purpose. The two literals must stay byte-identical or the re-arm silently no-ops — no exception, no log, the achievement just stalls, which is precisely the bug under review.

**Investigation:** Read both files at HEAD; confirmed `SerialAchievement` declares `private const string CounterDependencySuffix = "_SA"` and uses it in both places, while `StepByStepAchievement` does not. The commit touched both call sites in `StepByStepAchievement` without extracting the constant.

**Resolution:** `Filed → FP-45259` (item 3). Cosmetic on its own, but the failure mode of a literal mismatch is silent, so it rides along with the re-arm cleanup.

**Discovered by:** skill recon and code-reviewer agent independently.

### F-5: The `ReArm` comment overstates "never read" [Info]

**Description:** The comment says the raised value is "only a change-trigger (never read)". The value is never read for any behaviour, but it is stringified by `GameClientPeer_Missions.Context_DependencyChanged` when the dependency is admin-tuned, so a diagnostic log line can print the synthetic `0 -> 1`.

**Investigation:** Repo-wide grep established no functional consumer of `CurrentValue`/`OldValue`/`NewValue`; reading `Context_DependencyChanged` showed the `ToString()` path for `#`-prefixed and `tunedDependencies` keys. No gameplay effect.

**Resolution:** `Filed → FP-45259` (item 4) — a one-line comment correction to make while the surrounding code is open.

**Discovered by:** Codex.

> Severity rationale for F-6/F-7, set during the findings discussion: exposure is not the yardstick. `ResetOnFail`, `UniqueBy` and `it.<property>` predicates are public, documented configuration surface, and nothing in the schema or validation forbids the combinations below. A reasonable configuration that silently does not work is an engine defect regardless of whether current content happens to use it — the absence of such a mission today is luck, not correctness. Both are therefore filed as bugs, not backlog notes.

### F-6: `it.FishCategoryId` predicates are registered under a dependency nothing raises [Low]

**Description:** `MissionsContext.dependenciesMap` maps `FishId`, `FishCode`, `FishName`, `FishWeight` to `"Fish"` but has no entry for `FishCategoryId`, while the `Fish` setter raises only `"Fish"`. A predicate written as `it.FishCategoryId == N` would therefore be registered under a key that is never raised and would not be re-evaluated when the fish changes. Pre-existing, not introduced here, but adjacent to this ticket's subject.

**Investigation:**
- Read `MissionsContext.dependenciesMap` and confirmed the missing entry, and `MissionsContext.FishCategoryId` is a derived property over `Fish`.
- Content instrument (local `Main`): predicate-style usage (`.FishCategoryId`) appears in zero tasks and zero missions; all 878 task hits and 139 mission hits are the condition-property form (`CatchFishCondition { FishCategoryId: … }` / `FishCategoryIds: [ … ]`), whose dependency is `"Fish"`. Conclusion: latent, no current exposure. Binds to the current content snapshot — new content could activate it with no code change.

**Resolution:** `Filed → FP-45260`, `Pre-existing`. Kept separate from F-7: different code area, different fix.

**Discovered by:** Codex.

### F-7: `ResetOnFail` clears the counter but keeps the `UniqueBy` dedup list [Medium]

**Description:** The `ResetOnFail` branch of `SerialAchievement.Check()` sets `Achieved = 0` and resets condition variables, but never clears or re-stores `#l_unique_<taskId>`. A task combining both flags would be permanently unwinnable after the first reset: every previously counted value stays deduplicated, so the counter can never climb back. Pre-existing, not introduced here.

**Investigation:**
- Read the `ResetOnFail` branch at HEAD and confirmed it touches only `Achieved` and control-object variables.
- Content instrument (local `Main`): `ResetOnFail` appears in zero tasks; overlap with `UniqueBy` is zero. Conclusion: latent, no current exposure, same snapshot caveat.

**Resolution:** `Filed → FP-45261`, `Pre-existing`. Medium rather than Low: the broken contract fails silently and terminally — the task is unwinnable while looking like the player simply did not finish it, so it would surface from prod complaints rather than from testing.

**Discovered by:** Codex, independently raised by the code-reviewer agent as an unresolved hypothesis.

## Verdict

**Approve.** The fix is correct and addresses the real defect. Re-arming is the right mechanism given that `SerialCondition` narrows its monitored dependency set to `0..lastPassedIndex+1`, and making the re-arm unconditional is what closes the stall: a `UniqueBy` duplicate completes an occurrence without incrementing, and under the old code that meant no re-arm and a permanent stall for any multi-step sequence. Moving the key from `SelfMission.MissionId` to the condition's own `mission.MissionId` is strictly more correct, and the synthetic change value is safe. No finding blocks approval.

**Verification scope.** Verified: the mechanism, empirically — with the fix reverse-merged, the new regression test fails (`Expected:<2>. Actual:<1>`) and the debug trace shows the completed-but-not-re-armed occurrence directly; production termination, by trace through the single `MissionsManager` owner and the multi-rod contexts; the "value never read" premise, by repo-wide grep; content exposure of every latent finding, by query against local `Main`; the suite, green at HEAD. Not verified: that the reporter's own session matched the duplicate-catch mechanism — the STR as written passes against pre-fix code (F-2), so the ticket's symptom description is not the thing that was fixed. Contract-level risks that content could activate without any code change (F-1, F-6, F-7) are filed rather than closed.

**Follow-up work created at close:** FP-45259 carries F-1 (bound the re-arm / remove the need for it), F-3 (test factory default) and F-4/F-5 (suffix constant, comment wording); FP-45260 and FP-45261 are the standalone bugs for F-6 and F-7. All three under the Technical Debt epic FP-44818.

**Cross-branch merge:** none performed. r16180 is native to the Code branch and reached Content as r16257; r16259 is native to Content and reached Code as r16260 — both branches already carry both changes, and the release ships from Content.

**KB written back:** the condition-monitoring mechanism this review had to reconstruct from scratch is now a module deep dive — [`server/modules/missions/condition-monitoring.md`](../../server/modules/missions/condition-monitoring.md) (draft), linked from the module card.

## Notes

- `Executor` field is populated (Yuriy Burda) and matches the commit author — no hygiene gap.
- Fix Version `2026.5 Anniversary (ex.Fathers Day)`, release date 2026-07-29, not yet released at review time.
