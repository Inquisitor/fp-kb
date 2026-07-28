---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16263, merged to NPN20260602 @ r16265
jira: https://fishingplanet.atlassian.net/browse/FP-44413
---

# FP-44413: Failing and receiving mission again have inconsistent task behaviour

## Summary

When a mission fails and is immediately re-issued while the player is still on the pond, tasks that should already be satisfied by the current session state (e.g. "travel to this pond") are not counted as completed. Relogin fixes it.

Root cause: `MissionConditionWrapper.IsProcessed` is a per-request dedup flag cleared only by `ConditionMonitoringSurface.Reset`, which runs after the whole `ProcessMessagesLoop`. Everything else that must be reset across a fail/restart inside one request already was (`task.IsCompleted`, `CompleteConditionWrapper.ResetCached`, `TasksToCheck`, mission counters and variables) — `IsProcessed` was the one survivor, so `ProcessForwardMissions` skipped the restarted mission's tasks via `RegisterProcessed` returning false.

The fix clears `IsProcessed` for every task wrapper in `Core_StartMission`. The missing-mission-name half of the ticket's expected result was routed to the linked bug FP-44704.

## Scope

- **MFT20260325 r16263** — Fix restarted mission tasks skipped when failing and re-issuing in one pass
  - `Core_StartMission` unregisters the processed flag of every `mission.Tasks` complete-condition wrapper before `UpdateTasksToCheck`
  - New test `ObjectModel.Tests/Mission/FailedMissionRestartTests.cs` reproducing fail → immediate restart with a state-based travel task
- **NPN20260602 r16265** — Merge from MFT20260325 r16263

## Findings

### F-1: Fail → restart → fail livelock inside one processing request has no guard, and the fix widens the path into it [Low]

**Description:** After the fix, a task that drives the mission's `FailCondition` is re-evaluated inside the same request immediately after an `RestartFailedMissionAfterMinutes: 0` restart. If that task's condition is still true at that moment, the mission fails again on the next outer iteration of `ProcessMessagesLoop`, restarts again, and so on — the outer loop counts cycles but never caps them, and the whole loop runs under `lock (lockObject)`. Before the fix the stale `IsProcessed` incidentally suppressed exactly this path. Severity is Low because no shipped mission can currently enter it (see Investigation), not because the mechanism is unreal.

**Investigation:**
- Traced the loop-continuation condition in `ProcessMessagesLoop` (`isFirstIteration || HasAffectedMissions() || CapturedDependencies.Any()`): `ProgressOnTask` raises the mission-bound `@<TaskCode>` dependency, which `TaskCompletedCondition` monitors, and `CaptureDependencies` re-arms the loop at the end of every cycle. Wrapper `IsAffected` is cleared only by `ConditionMonitoringSurface.Reset`, which runs after the loop — so nothing damps the cycle. Conclusion: the mechanism holds at code level.
- Both delegated reviewers reached the same mechanism independently (Codex rated it High; the code-reviewer agent rated the class pre-existing and left reachability unresolved). Both explicitly deferred reachability to mission content.
- Content exposure, `[F2P] TEST` `Main.dbo.Missions` / `dbo.MissionTasks`, snapshot 2026-07-26: 11 active missions combine `FailCondition: TaskCompletedCondition` with `RestartFailedMissionAfterMinutes: 0` (3952, 3954, 3957, 3960, 3961, 3965, 3966, 3968, 3976, 3977, 3979). Read the fail task's condition for each: every one is an `AndCondition` gated on a mission counter/variable (`#iFishCountN != 0`, `#fLastWeight > 0`, `#fTarponLastWeight`/`#fSnookLastWeight`) or on another task's completion.
- Read `MissionsProfileUtils.LoadCountersAndVariablesAndInteractionsFromProfile`: called from `Api_RemoveFailedMission` with a fresh `StartedMission`, it zeroes every counter and every int/float/bool/string variable; the same method resets `task.IsCompleted` for all tasks. Both run before the restart in `Processing_TryStartMissions`. Conclusion: with current content no fail task can be true immediately after restart, so the livelock is unreachable — hypothesis refuted for shipped content.
- Constructibility check: `MissionsValidator.GetMissionValidationVisitor` validates only that a `TaskCompletedCondition` names an existing task code — nothing constrains the shape of a fail condition or its interaction with `RestartFailedMissionAfterMinutes`. Neither the outer `ProcessMessagesLoop` loop nor the inner `ProcessForwardMissions` loop caps iterations. So a fail task such as a bare `PondCondition` combined with an immediate restart passes validation and reaches the livelock.
- Second exposure path (pre-existing, independent of the fix): a mission whose `FailCondition` is a direct state condition needs no fail task at all, since `Processing_TryFailMissions` never consulted `IsProcessed`. Exactly one active mission combines that with an immediate restart — 3790 `Exploring_Dnipro_Salo`, `FailCondition: 'PondId == 0'`. Its `StartCondition` is `PondCondition { PondId: 180 }`, the logical negation of its fail condition, so it cannot restart while the fail condition holds. Self-limiting, again by authoring choice.
- Scope caveat: the exposure result binds to the TEST content snapshot on 2026-07-26. The invariant that actually protects the server — "a mission's fail condition must be false immediately after its restart" — holds across all live content by content-authoring convention only, and is enforced nowhere.

**Resolution:** Filed → FP-45233 (Technical Debt 2026 Q3); also recorded in the missions module backlog. Not blocking for this ticket.

**Discovered by:** skill recon / Codex / code-reviewer agent (independently, same mechanism).

### F-2: The restart assertion in the new test passes for the wrong reason [Low]

**Description:** In `FailedMissionRestartTests.RestartFailedMission_state_based_travel_task_recompletes_within_same_processing_loop`, the `events` list is populated from the first `ProcessMessagesLoop()` call, where the mission starts for the first time. `Assert.IsTrue(events.Exists(e => e.EventType == MissionEventType.MissionStarted), "mission should have restarted")` is therefore already satisfied before the fail cycle runs and proves nothing about the restart. The restart is genuinely established by the neighbouring `mission.IsStarted` and `context.FailedMissions.Count` assertions, so the test still discriminates.

**Investigation:**
- Read the test as committed (`svn diff -c 16263`): `EventReceived` is subscribed before the first `ProcessMessagesLoop()` and `events` is never cleared between the two calls. Instrument: static inspection of the test source at the reviewed revision, which is the capable instrument for a claim about the test's own source shape.
- Codex raised the same point independently; re-verified against the committed source rather than the working-copy file, which later commits have extended.
- Discriminating power of the test as a whole checked separately: without the fix, `RegisterProcessed` returns false for the travel task's wrapper after the restart, so `IsCompleted` stays false and the final travel assertion fails. Both delegates traced the same. The later tests in the same file on HEAD come from a different commit and are out of scope here.

**Resolution:** Skipped — cosmetic, the test still does its job; card only, not raised in JIRA. Worth scoping events from an index taken before the fail cycle if the file is touched again.

**Discovered by:** Codex.

### F-3: The ticket's explicit request to investigate mission 3957 is not addressed [Medium]

**Description:** The description ends with a direct instruction: investigate the missions named in the comments as well, and if 3957 turns out to be a different problem, file a separate bug. The reporter's comment states that 3952 and 3954 reproduce the bug while 3957 has near-identical tasks but its fail task never completes. The executor's closing comment covers only the mission-name symptom and the task-state symptom; 3957 is not mentioned and no separate bug is linked. Whether the ticket can be closed depends on that answer.

**Investigation:**
- Read the full description and both comments, plus the issue links: FP-44704 (mission name) and FP-44761 (wrong mission restart after fail via fail task). Neither covers 3957.
- Content comparison on `[F2P] TEST`, snapshot 2026-07-26: mission 3957 (`Anniversary8_Falcon`) has the same shape as 3954 — fail task `Task_1` gated on `#iFishCount1..4 != 0` plus `(TimeOfDayCondition Hour 5 Range 15 Negate | it.PondId==0 | EndOfDayCondition)`; its `Task_4..Task_7` are the catch tasks that set those variables.
- Read `TimeOfDayCondition.CheckTime`: the window is `Hour <= h <= Hour + Range` inclusive, checked also at `h + 24`. So 3957's negated window is hours 21..04 — the same night window 3954 uses positively, i.e. the fail window is reachable and does not explain the reported "never completes". Hypothesis that `Range` covers the full day: refuted.
- Read `MissionsSerializationUtils.ParsePredicateExpression`: all `#var` occurrences in one predicate expression are registered as dependencies, so 3957's multi-variable predicate is fully monitored. Hypothesis that only the first variable is monitored: refuted.
- The cause of 3957's behaviour is therefore not established from the server side in this review; recorded unresolved.

**Resolution:** JIRA question to the executor — was 3957 checked, and if it is a separate defect, does it have its own ticket? Decision-affecting for closure.

**Discovered by:** skill recon.

## Notes

- Executor field (`customfield_11224`) is filled and matches the commit author — no hygiene issue.
- FP-44704, which the executor's comment credits with fixing the missing mission name, was Verified on 2026-07-09 but Reopened on 2026-07-22 with a new video, resolution Done → Not Done. The ticket's second expected result ("mission name is shown") is therefore not currently satisfied through that link.

## Verdict

Approve, ship-and-reopen. The change itself carries no blocking issue and ships with the release: the fix is minimal, lands on the verified root cause, and its regression test discriminates. What is unsettled is not the code but the scope — whether mission 3957 was checked, as the description asked (F-3) — and the task goes back to the executor for it. F-1 left the review as FP-45233; F-2 is card-only.

Root cause is established, not merely the symptom: `MissionConditionWrapper.IsProcessed` was the only piece of per-request state that survived the fail/restart transition, and every sibling reset (`task.IsCompleted`, `CompleteConditionWrapper.ResetCached`, `TasksToCheck`, counters and variables) was already in place.

The posted comment also records that FP-44704, credited with the missing-mission-name half of the expected result, has since been reopened.

## Round 2

### Scope

No new commits. The round is the executor's answer to the returned follow-up, posted 2026-07-28.

### Investigation

- Mechanism claim verified in code: `MissionsUtils.CheckTaskCondition` short-circuits to complete only when the task is `IsDynamic` and every other `IsMissionTask` in the mission is done. A non-dynamic task never takes that path, so a hidden non-dynamic fail-watcher blocks `Tasks.All(IsCompleted)` — the executor's mechanism as stated.
- Preconditions verified in content: mission 3957 carries `Task_3` as its `IsMissionTask` objective, and its fail-watcher `Task_1` is dynamic in the current data.
- Historical claim verified through the admin change history (`DataChanges` on the Dev authoring environment, keyed by the task's primary key): `Task_1` was created 2026-06-10 with `IsDynamic=false`, made invisible 2026-06-11, and the dynamic flag was set 2026-07-07 by the mission author. The reporter's "never completes" comment is dated 2026-06-23, i.e. while the task was hidden and non-dynamic — exactly the state the executor described. Round 1's note that the mission configuration does not explain the symptom was wrong: the config snapshot it rested on was taken 2026-07-26, after the correction.
- FP-44704: the executor's statement was accurate when written; the ticket was moved from the Anniversary release to 2026.6 Australia later the same day, and currently sits Resolved. The mission-name half of the expected result therefore lands in the following release, not this one.
- Release-population recheck: round 1's content sweep queried the TEST copy, but the copy promoted to production is QA. Re-ran on QA — the same eleven missions combine a fail task with an immediate restart, every fail driver is gated on a mission counter and is dynamic, and the 3957 correction is present. The zero-exposure conclusion now binds to the population that actually ships.
- Ship-risk assessment for the release: condition side effects (`VariableSet` counter increments on catch conditions) cannot re-fire after the restart, because the transients they key on (`CaughtFish`, `Transition`) are cleared by `MissionsContext.AfterProcessingCycle` at the end of each inner cycle, and the fail check runs at the top of the next one. Duplicate completion events and rewards are excluded by the `!task.IsCompleted` gate in `ProcessForwardMissions`. Reverting the change would reintroduce the defect across the whole Anniversary mission set, which is the content that depends on it.

### Findings

None new.

### Verdict

Resolved. The returned question is answered and verified as far as the available instruments allow; the change stands as approved.

## Notes (round 2)

- The ticket's Fix Version was moved to `Internal/Async` on 2026-07-28 and is being returned to the Anniversary release — the tag contradicted the change's own content, since its code ships with the Photon stack. Handled outside the review as a misunderstanding.

## Investigation Journal

- VCS audit: `svn log | grep` over MFT20260325 and NPN20260602 from r16150 returns exactly the two commits named in JIRA — no unposted commits, no branch mismatch.
- Working copy is at r16351, past the reviewed revision, so file reads from disk are valid; the new test file on disk has since been extended by a later commit, and both delegates read that extended version. Findings were re-verified against `svn diff -c 16263` rather than the working-copy file.
- Branch-copy inheritance check: NPN20260602 was created at r16131 from MFT20260325:16130, and the fix is r16263 > 16130, so the explicit merge at r16265 was required and is present. No further merge target: FTUE and 2026.5 Anniversary both ship from MFT20260325, and 2026.6 ships from NPN20260602.
- Cross-repo client-mirror check: the diff touches `Shared/ObjectModel/Mission/`, but the change is server-side processing-loop bookkeeping with no combinatorial or client-visible contract change, so no client mirror is required.
- Ran the new test at HEAD (`dotnet test --filter FullyQualifiedName~FailedMissionRestartTests`): 5 passed, 0 failed — 1 test from r16263 plus 4 added by a later commit.
- Hypothesis "the fix can turn fail/restart into an unbounded loop for shipped content" was formed during recon, confirmed as a code mechanism by both delegates, then refuted at the content level by the mission/variable-reset evidence in F-1.
- The DataGrip result view truncates rows, which at one point made mission 3957 look like it had no fail task at all. Aggregate the result into a single row (`STRING_AGG`) whenever completeness of the row set is what the conclusion rests on.
- Findings routing: F-1 → FP-45233 plus missions module backlog, F-2 → card only, F-3 → returned to the executor in the closing comment.
- Merge verification at close: `svn cat` on the NPN copy of `MissionsManager_Start.cs` shows the new loop in place, so the executor's r16265 carried content, not just mergeinfo. No merge performed by this review, hence no `Merged → ` lines in the comment.
- Release-step field `customfield_11323` is empty and stays empty: the diff touches only `Shared/ObjectModel` sources and a test, so no option in the closure gate's derivation table applies.
