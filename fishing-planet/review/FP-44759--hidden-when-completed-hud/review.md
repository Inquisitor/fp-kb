---
status: resolved
executor: Yuriy Burda
branch: MFT @ r16279, merged to NPN @ r16280
jira: https://fishingplanet.atlassian.net/browse/FP-44759
---

# Review: FP-44759 — Task with "Is Hidden When Completed" inconsistent behaviour in Menu/HUD

## Summary

Bug (yellowtest, mission 3979): Task_15 with `IsHiddenWhenCompleted` was shown in Menu but hidden in HUD while uncompleted. Root cause is mission data, not server code: Task_15 carried `{ type: 'TaskCompletedCondition', TaskCode: 'Task_16', Negate: true, HiddenWhileQueued: true }` — `HiddenWhileQueued` means "hide while condition unmet", and `Negate: true` inverts it into "hide once Task_16 is completed", the opposite of the intended "show once Task_16 is completed". Data fix (content side): drop `HiddenWhileQueued`; post-completion hiding is already covered by the `IsHiddenWhenCompleted` flag, and `Negate: true` stays for task logic.

Server-side change is tests only — pinning the Negate+HiddenWhileQueued inverted HUD-hide semantics; executor states no behavioral server change.

## Scope

- **MFT r16279** — Add tests for Negate+HiddenWhileQueued inverted HUD hide
  - Tests only; no server behavior change (executor's claim, to be verified against the diff)
- **NPN r16280** — Merge of r16279

## Investigation Journal

- VCS audit: `svn log -r 15943:HEAD` on MFT + `-r 16131:HEAD` on NPN, grep FP-44759 — exactly r16279 (MFT, yuriy.burda) and r16280 (NPN merge of 16279); matches JIRA comment, no unposted commits. WC at r16351 ≥ r16279 — fresh, disk reads trustworthy.
- Diff r16279: single file `Shared/ObjectModel.Tests/Mission/FullyHiddenWhileQueuedTests.cs` (+`BuildOrGatedMission` helper, +2 tests). Executor claim "tests only, no server behavior change" — verified by the diff itself.
- Barrier mechanism claim verified: `MissionsUtils.ApplyHideStateFromBarriers` — `unmet = !barrier.CheckCached()`, `IsHiddenInHud = unmet` (OR over barriers), menu touched only when `FullyHiddenWhileQueued`; barriers with neither flag are skipped (fields untouched) — pins test 2's expectation.
- Negate inversion claim verified: `TaskCompletedCondition.Check` = `Any(t => t.Code == TaskCode && Negate ^ t.IsCompleted)`, `CheckCached` = `Check` — with `Negate: true`, `unmet` becomes "referenced task IS completed" → HUD hides exactly when Task_16 completes. Matches executor's JIRA diagnosis and test 1.
- Barrier collection inside `OrCondition` verified: `MissionConditionWrapper.Initialize` collects `IMissionBarrierCondition` via visitor over the whole condition tree — nesting in `OrCondition[barrier, FalseCondition]` is picked up.
- Dynamic-task claim in helper comment verified: `MissionsUtils.CheckTaskCondition` — `IsDynamic` task reports completed when all other `IsMissionTask` tasks are done; the never-completing KeepAlive task is genuinely required for the reminder to revert to active.
- Tests-pass claim verified empirically: `dotnet test ObjectModel.Tests.csproj --filter FullyHiddenWhileQueuedTests` — 12/12 passed (includes both new tests), net472.
- Executor claim "task still hides after completion via `IsHiddenWhenCompleted`" verified cross-repo (client is the capable instrument — server only serializes the flag via `MissionClientUtils.ConvertToMissionOnClient`): MainClient (Content client checkout) `ActiveQuestDetails.cs` and `HudMissionTasksSRIA.cs` hide on `IsHiddenWhenCompleted && IsCompleted` independent of `HiddenWhileQueued`.
- Client-side manifestation consistency: HUD consumes server-computed `IsHiddenInHud` in `HudMissionHandler.cs` / `HUDMissionHandlerMobile.cs`; menu (`ActiveQuestDetails.cs`) has `IsHiddenInHud` commented out — explains "visible in menu, hidden in HUD" STR exactly.
- Branch-copy inheritance: NPN based on MFT:16130 (`_index.md` ancestry); r16279 > 16130 → explicit merge required and present (r16280). No inheritance shortcut applies.
- Mission 3979 Task_15 data fix (drop `HiddenWhileQueued`) is content-side, not in the reviewed commits; applied by GD per JIRA thumbs-up. Not verifiable from the server repo — explicitly out of this review's verification scope (see Verdict).
- Independent delegation (blind hunt, in parallel): code-reviewer agent and Codex both returned zero code-backed defects; both independently confirmed the recon engine traces (barrier collection through `OrCondition` via visitor, Negate math, keep-alive necessity, per-test manager isolation, task-order independence via wrapper invalidation). Codex additionally confirmed `OrCondition` evaluates every child (barrier evaluated despite constant-false sibling) and non-serial missions keep tasks in `TasksToCheck`.
- Agent's unresolved hypothesis (missing `MissionException += Assert.Fail` net) re-verified: premises TRUE (`MissionsTestHelper.cs` Console-only handler; `OrConditionSimultaneousFlipTests.cs` sibling adds `Assert.Fail` for the same dynamic+OrCondition idiom), but the vacuous-pass consequence DISPROVEN — both new tests anchor on `IsCompleted` before/after `CompletePrereq`; a mission fault freezes `IsCompleted` and fails those asserts loudly, and reversion implies `CheckCondition` ran, which itself invokes `ApplyHideStateFromBarriers`. Residual consequence: only a less-clear failure message on a hypothetical future fault → F-1 Low/Skipped.

## Findings

### F-1: New tests lack the `MissionException → Assert.Fail` safety net the sibling file uses for the same mission idiom [Low]

**Description:** `FullyHiddenWhileQueuedTests` relies on `MissionsTestHelper.CreateMissionsManager`, whose `MissionException` handler only `Console.WriteLine`s; `OrConditionSimultaneousFlipTests` — which established the dynamic-reminder + `OrCondition` + keep-alive idiom that `BuildOrGatedMission` copies — explicitly adds `manager.MissionException += Assert.Fail` so a faulted mission cannot be mistaken for an assertion-level failure. A future engine fault in these two tests would surface as a confusing flag/IsCompleted assert failure instead of "Mission faulted".

**Investigation:** Premise check — Read `MissionsTestHelper.cs` (Console-only handler) and grep `MissionException` in `OrConditionSimultaneousFlipTests.cs` (Assert.Fail + rationale comment present). Consequence check — traced fault propagation through `CheckTaskCondition`/`CheckCondition` (`MissionsUtils.cs`): the delegated worst case (silent vacuous pass of the no-flag test) is disproven because both tests assert `IsCompleted` transitions that a fault would freeze, and barrier application happens inside the same `CheckCondition` call that produces the reversion. Empirical run: 12/12 tests green, so no fault occurs at the reviewed revision.

**Resolution:** Skipped — the vacuous-pass risk does not materialize for these assertions; residual value is a clearer failure message. Worth adopting the sibling's one-liner if this file is touched again; not worth a rework round.

**Discovered by:** code-reviewer agent (consequence corrected by skill recon).

## Notes

1. Executor field (`customfield_11224`) empty in JIRA — expected Yuriy Burda per commit comment. Still empty at close (re-flagged in closure summary).
2. Mission 3979 Task_15 data change (content side) and in-game verification are outside the reviewed server commits; PM waived QA testing (reviewer closes the ticket directly).

## Verdict

**Approve.** Tests-only commit; the two new tests accurately pin the engine's Negate x HiddenWhileQueued inversion (the mechanism behind the reported Menu/HUD inconsistency) and the no-flag control shape, with every code comment claim verified against the engine. Merge path complete for the FPA release (MFT r16279 -> NPN r16280; NPN base is MFT:16130, so no inheritance shortcut applied). F-1 is Low/Skipped and does not block.

**Verification scope:** verified — commit contents (tests-only), engine mechanism trace, empirical test run (12/12 green), client-side consumption of `IsHiddenInHud` (HUD handlers) / `IsHiddenWhenCompleted` (menu + HUD, hides completed tasks independently of `HiddenWhileQueued`), commit/merge audit. NOT verified — the mission 3979 Task_15 data fix itself (content-side change outside the server repo; GD acknowledged in JIRA) and end-to-end behavior on yellowtest (QA testing explicitly waived by PM).
