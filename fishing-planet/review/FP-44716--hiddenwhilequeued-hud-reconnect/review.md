---
status: reopened
executor: Yuriy Burda
branch: MFT20260325 @ r16283, merged to NPN20260602 @ r16284
jira: https://fishingplanet.atlassian.net/browse/FP-44716
---

# FP-44716: ANNIVERSARY 2026 — Completing dynamic tasks doesn't update queued tasks in HUD

## Summary

Bug report: mission tasks marked `HiddenWhileQueued` that depend on a dynamic task do not appear in the
HUD after the dynamic task is completed on a pond. Reproduced on yellowtest with mission 3978 on
CONGO RIVER: the player boards a kayak (completing the dynamic task), exits the game while still in the
kayak, logs back in — the catch tasks never surface in the HUD. QA later confirmed the same symptom on a
plain internet reconnect (no client restart), which points at room re-entry rather than at the client
session boundary.

An early triage comment from the client side states that `HandleMissionEvent` does not fire after login
while on the kayak.

The fix is titled "Fix HiddenWhileQueued tasks missing from HUD after reconnect (room change)".

## Scope

- **MFT20260325 r16283** — Fix HiddenWhileQueued tasks missing from HUD after reconnect (room change)
- **NPN20260602 r16284** — Merge from MFT20260325 r16283

Audited: `svn log -r 16200:HEAD | grep FP-44716` on both branches returns exactly these two revisions — no
unposted commits, branch attribution in the JIRA comment matches commit metadata.

## Mechanism

`ProcessForwardMissions` (`MissionsManager_Processing.cs`) delivers task state to the client only on a diff:
it snapshots `IsCompleted` / `IsHiddenInHud` / `IsHiddenInMenu` / progress before `CheckTaskCondition`, then
fires `MissionProgress` if any of them flipped. The `HiddenWhileQueued` flag itself is written inside that
call — `ApplyHideStateFromBarriers` (`MissionsUtils.cs`) recomputes `IsHiddenInHud` from the barrier's
`CheckCached` result.

After a re-initialization (new peer → new `MissionsManager` → `Container_Initialize`) the mission objects are
rebuilt from the template, so the "old" values the first pass diffs against are freshly-initialized ones. When
the gate task is restored as already-completed, the barrier is met from the very first evaluation, the
recomputed `IsHiddenInHud` equals the initial value, the diff is empty and nothing is delivered — while the
client still holds the pre-reconnect HUD state.

The fix adds a first-pass re-assert: on `isFirstIteration`, every incomplete task of the *active* mission
fires `MissionProgress` regardless of a diff. `hasProgressInsideTasks` is deliberately left driven by the real
diff only, so the synthetic re-send does not suppress `OnMissionIdle`.

## Investigation Journal

- Phase 1 intake: JIRA read via `jira-read-issue`; executor identified as Yuriy Burda (commit author per
  JIRA comment), matching the `Executor` field — no hygiene gap.
- Fix Version `2026.5 Anniversary (ex.Fathers Day)`, release date 2026-07-29, `released: false` — the change
  is pre-release, which bounds any data-integrity severity assessment (no live bad-state surface yet).
- Parent epic FP-41670; issue linked to FP-44704.
- Related mission-subsystem reviews by the same executor already on file (FP-44761, FP-44859, FP-44413,
  FP-44667) — check for overlapping code paths before finalizing findings.
- WC freshness: `svn info --show-item revision` on the working copy returns r16364, above the reviewed r16283;
  `svn log -r 16283:HEAD` on `MissionsManager_Processing.cs` returns only r16283 itself, so disk state equals
  the reviewed state and no stale-WC fallback was needed. Same check doubles as the HEAD-verification required
  for commits older than two weeks (r16283 is from 2026-07-08): the change has not been superseded.
- Boolean-extraction equivalence checked by inspection of the diff text: the extracted `progressed` initializer
  is character-identical to the original `if` condition; `&&` binds tighter than `||` in both, and the operands
  are side-effect-free reads, so short-circuit behavior is unchanged.
- `isFirstIteration` is NOT once-per-session. Grep over `Shared/ObjectModel` shows it re-armed by
  `Container_OnLevelGained`, `Container_RefreshMissions`, `Container_RefreshDailyMissions`,
  `Container_RefreshDailyMission` (`MissionsManager.cs`) and by every admin mutation in
  `MissionsManager_Admin.cs`. `Container_RefreshMissions` is reachable from the live game loop —
  `ProcessMissions` (`GameClientPeer_Missions.cs`) calls it when the mission cache version advances. So the
  re-assert recurs on those events, not only on room entry.
- `MissionProgress` production subscriber is single: `MissionsManager_MissionProgress`
  (`GameClientPeer_Missions.cs`). It only appends to `missionProgressTasks` and records a progress tuple — no
  persistence, analytics or other side effect — and it already filters on `mission == context.ActiveMission`.
  Delivery goes through `SendMissionProgressMessages`, which applies `.Distinct()`, so a task re-asserted and
  then genuinely progressed within the same processing loop is sent once.
- Client-side consumption verified in the paired Content-role checkout (`Win64_MainClient`):
  `PhotonServerConnection_Missions.cs` routes `ProgressMessages` into
  `ClientMissionsManager.UpdateCurrentMissionTasks`, which copies `IsHiddenInHud` / `IsHiddenInMenu` /
  `IsCompleted` / `Progress` onto the already-tracked task and raises `TrackedMissionUpdated`. It matches by
  `TaskId` inside `CurrentTrackedMission` only — it never creates rows — so the re-assert cannot surface a task
  that should stay hidden; it can only correct the flags of a row the HUD already has.
- Cross-repo mirror (skill Step 6) not required: the client's source copy of `ObjectModel`
  (`Assets/Photon Server Networking/ObjectModel/Mission/`) contains the context, conditions and client DTOs but
  no `MissionsManager*` — the processing loop is server-only, so there is no client twin of the changed code.
- Executor claim "(room change)" verified structurally: `missionsManager` is constructed once in
  `InitMissionsManager` per peer initialization and nulled in `UnloadMissions`, so entering another pond
  yields a fresh manager with `isFirstIteration` re-armed.
- Tests build and pass on HEAD: `dotnet test --filter FullyQualifiedName~ReloginHiddenWhileQueuedTests` →
  3 passed. `ObjectModel.Tests.csproj` is SDK-style, so the new file needs no `Compile Include` registration
  (the old-style-csproj gotcha does not apply here).
- Delegated review (skill Step 7) ran blind on both channels — `code-reviewer` agent and Codex — neither
  pre-loaded with recon. Both independently reproduced the test-coverage finding (F-1) and the recurring-flag
  observation (F-3), matching recon; every delegated claim was re-verified locally before acceptance.
- Delegated claim re-verified and REJECTED as a defect of this commit: Codex flagged that `IsInvisible` tasks
  are excluded from the snapshot (`ConvertToMissionOnClient`) but not from the re-assert set. Checked both
  halves — `MissionTask.IsInvisible` exists and `UpdateTasksToCheck` does not filter on it, but the pre-fix
  code fired `MissionProgress` for the same unfiltered set whenever a diff occurred, so the commit introduces
  no new message class. Client effect ruled out directly: `UpdateCurrentMissionTasks` matches by `TaskId`
  inside `CurrentTrackedMission.Tasks` and never inserts, and the only other consumer,
  `HintSystem.Instance_MissionProgressReceived`, just repaints the widget from that same list. Pre-existing,
  no exposure.
- Delegated hypothesis (agent: unresolved; Codex: Medium) that completed tasks are never re-asserted —
  investigated and promoted to F-2 at reduced severity after verifying both halves the delegates could not:
  `StartedMissionTask` persists `IsCompleted`/`Progress` but not the visibility flags, and on the client
  `RefreshActiveMission` (`HintSystem.cs`) is reached only from `Awake` and `ActiveMissionChanged`, so a
  Photon-level reconnect that keeps the scene alive never re-pulls the snapshot.
- Findings routing: F-1 returned to the executor (non-blocking), F-2 → missions module backlog (HUD Delivery),
  F-3 accepted inline. Card status `reopened` until the executor's test round lands.
- Merge to the Code branch verified by content, not by mergeinfo: `svn cat -r HEAD` on
  `NPN20260602/.../MissionsManager_Processing.cs` shows the `resendOnFirstPass` lines, and r16284 lists the
  test file as added from the MFT path. Inheritance did not apply — NPN was copied at MFT:16130, below r16283 —
  so the explicit merge was required and is present. The executor performed it, so the close comment carries no
  `Merged →` line.
- Release-step field (`customfield_11323`) read explicitly at close: empty, and correctly so — the diff touches
  only `Shared/ObjectModel` and its test project, with no `SQL/`, `NoSql/`, WebHooks/Twitch, profile-conversion
  or DataPump-content artifact to derive an option from. Gate satisfied without an entry, no waiver needed.
- JIRA workflow transition left to the user by their explicit direction; the rework request rides on the
  comment.
- Re-assert frequency bounded: `RegisterProcessed` (`ConditionMonitoringSurface.cs`) is checked before the
  re-assert and `processedWrappersSet` is only cleared by `Reset`, called after the `while` loop in
  `ProcessMessagesLoop` — so a task re-asserts at most once per `ProcessMessagesLoop`, and
  `SendMissionProgressMessages` applies `.Distinct()` on top. This bounds F-3 to one extra payload entry per
  incomplete tracked task per re-armed pass.

## Findings

### F-1: Two of the three new tests cannot fail if the fix is reverted [Medium]

**Description:** In `ReloginHiddenWhileQueuedTests.cs`, only
`Relogin_GateStateAlreadySatisfied_TrackedTaskVisibleInHud` subscribes to `MissionProgress` and asserts on
what was delivered. The other two —
`Relogin_BarrierBehindUnsatisfiedSerialStep_GateCompletionReRevealsTracked` and
`Relogin_GateStateRestoredAfterFirstProcess_TrackedTaskVisibleInHud` — assert only server-side task state
(`IsHiddenInHud`, `IsCompleted`), which this commit does not touch. The commit changes event *delivery*
only. This matters because the first test's comment claims the second one "Reproduces the real bug", so the
file reads as three-fold regression protection while carrying one-fold: a later refactor dropping
`resendOnFirstPass` would still leave two of the three green.

**Investigation:**
- Read the two tests in the r16283 diff: neither contains `MissionProgress +=`; grep for `MissionProgress\s*\+=`
  across the repo returns three test files and one production subscriber, confirming no implicit subscription
  exists inside `MissionsManager` itself.
- Traced the guard in `ProcessForwardMissions`: the new path is
  `if ((progressed || resendOnFirstPass) && MissionProgress != null)`. With no subscriber the delegate is
  null, so in those two tests the added code evaluates a boolean and does nothing else — it cannot influence
  any asserted value. `resendOnFirstPass` is read nowhere else in the method (it does not feed
  `hasProgressInsideTasks` or `hasProgressOnTaskCompletion`), so there is no indirect path either.
- Conclusion: reverting the production hunk leaves both tests green. Independent confirmation from both
  delegated reviewers, each reaching it from the same observable-based argument.

**Resolution:** Returned to the executor, non-blocking (ship-and-reopen). Either subscribe to
`MissionProgress` in both tests and assert delivery, or restate their comments so they read as
barrier-behavior regression tests rather than as coverage of this fix. The change itself ships — the fix is
correct and test 1 does pin it.

**Discovered by:** skill recon (confirmed independently by code-reviewer agent and Codex)

### F-2: Task completion is not re-asserted, so a stale client keeps a completed task shown as incomplete [Low]

**Description:** `resendOnFirstPass` excludes completed tasks (`!task.IsCompleted`). Visibility desync is
repaired on the first pass; completion desync is not. The asymmetry is defensible in itself — visibility is
recomputed from barriers on every init while completion is restored from the profile — but it leaves the
mirror-image of the reported bug unaddressed for a client that only ever receives increments.

**Investigation:**
- Inspected the persisted DTO `StartedMissionTask` (`StartedMission.cs`): it carries `TaskId`, `Code`,
  `Definition`, `Name`, `IsCompleted`, `Progress` — and no `IsHiddenInHud`/`IsHiddenInMenu`. This is exactly
  why visibility is the flag that gets lost across re-initialization and completion is not, and it justifies
  the `!task.IsCompleted` filter for the reported scenario.
- Checked whether the snapshot covers the remaining case on the client side: `RefreshActiveMission`
  (`HintSystem.cs`, `Win64_MainClient`) is the only caller of the `GetActiveMission` coroutine, and it is
  reached from `Awake` and from `ActiveMissionChanged` only (the third call site is a retry inside
  `OnGotActiveMissionFailed`). A Photon reconnect that does not rebuild the scene therefore never re-pulls
  the snapshot — consistent with QA's report that the bug also reproduces on a plain internet reconnect.
- Exposure is nonetheless narrow: the desync requires the client to have missed the completion event itself
  (i.e. the disconnect landed between the server completing the task and the message arriving). It
  self-corrects on the next progress event for that mission, on an active-mission change, or on any scene
  reload.

**Resolution:** Pre-existing → recorded in `<kb>/fishing-planet/server/modules/missions/backlog.md`
(HUD Delivery) citing this review. Not a change to this commit: the gap predates it and widening the
delivery semantics two days before the release is not warranted by the exposure.

**Discovered by:** Codex (raised as Medium; agent raised the same as an unresolved hypothesis) — severity
reduced after local verification of persistence and client snapshot behavior

### F-3: "First pass" is a recurring flag, so the re-assert also fires on events unrelated to reconnect [Info]

**Description:** The added comment frames the re-assert as a re-initialization concern, but `isFirstIteration`
is re-armed by `Container_OnLevelGained`, `Container_RefreshMissions`, `Container_RefreshDailyMissions`,
`Container_RefreshDailyMission` and by every mutating method in `MissionsManager_Admin.cs`.
`Container_RefreshMissions` sits on the live path — `ProcessMissions` (`GameClientPeer_Missions.cs`) calls it
when the mission cache version advances, immediately before `ProcessMessagesLoop`. So a content publish, a
daily-mission refresh or a level-up re-broadcasts the active mission's incomplete tracked tasks for every
affected online player.

**Investigation:**
- Grepped all `isFirstIteration = true` sites and read each context; confirmed the reset happens once per
  `ProcessMessagesLoop` (end of the first `while` cycle).
- Bounded the cost rather than assuming it: `RegisterProcessed` short-circuits a second visit to the same
  task within one `ProcessMessagesLoop`, and `SendMissionProgressMessages` applies `.Distinct()`, so the
  effect is one extra payload entry per incomplete tracked task of the active mission, once per re-armed
  pass — not a per-cycle multiplier.
- Values carried are freshly recomputed (`CheckTaskCondition` runs before the re-assert on the same pass), so
  no stale data is broadcast.

**Resolution:** Accepted — correct-but-broader-than-described. Worth a one-line comment amendment if the
executor touches this code again; no functional change warranted.

**Discovered by:** skill recon (confirmed independently by code-reviewer agent and Codex)

## Verdict

**Approve, with non-blocking rework returned to the executor (ship-and-reopen).**

The fix is correct and targeted. It repairs a real delivery gap: task visibility is not persisted, so after a
re-initialization the first pass has nothing to diff against and the client keeps its pre-reconnect HUD. The
re-assert is safe by construction — values are freshly recomputed before it fires, the sole subscriber only
buffers, `RegisterProcessed` bounds it to once per task per pass, `.Distinct()` collapses duplicates, and the
client applies progress messages by `TaskId` onto an already-tracked mission without ever inserting rows, so
nothing that should stay hidden can surface. No cross-repo client mirror is required.

Returned for rework: F-1 — two of the three added tests cannot fail if the fix is reverted, while the file
presents itself as covering the fix. This does not hold up the release.

F-2 is routed to the missions module backlog as a pre-existing gap; F-3 is accepted as correct-but-broader
than its comment describes.

**Verification scope:** the mechanism was verified statically end-to-end (server processing loop, persistence
DTO, client consumption in the paired MainClient checkout) and empirically at unit level — the delivery test
pins exactly the no-transition case, and the suite is green on HEAD. NOT verified: the original STR was not
reproduced on a live environment, and mission 3978's actual task graph was not compared against the structure
modelled in the tests. So the approve covers the delivery defect and its fix, not a runtime reproduction of
the QA scenario.

## Notes

- Progress messages for `IsInvisible` tasks are possible but pre-existing and inert on the client (see the
  rejected delegated claim in the Investigation Journal).
- `missionTaskProgresses` is keyed by `TaskId` alone (`GameClientPeer_Missions.cs`); Codex flagged a
  theoretical collision if two batched tasks shared an ID. Pre-existing, unchanged by this commit, and both
  the buffer and the dictionary are written under the same active-mission guard.
