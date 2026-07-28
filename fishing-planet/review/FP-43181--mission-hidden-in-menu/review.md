---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16049
jira: https://fishingplanet.atlassian.net/browse/FP-43181
---

# FP-43181: Parameter that allows to hide tasks even in menu

## Summary

Adds a mission-task flag that hides a queued task not only on the HUD but also in the missions
menu. Implemented by introducing `FullyHiddenWhileQueued` and splitting the existing single
`IsHidden` notion into two per-surface flags (`IsHiddenInHud` / `IsHiddenInMenu`), mirrored on
the client side. Hide-state application was centralised into a new
`MissionTask.ApplyHideStateForBarrier`, still invoked from inside each barrier condition's `Check()`.

Design doc: FTUE REWORK - Mission System Improvements, section 7 (Confluence page 5258379266).

## Scope

- **MFT20260325 r16049** — Add FullyHiddenWhileQueued mission flag and split IsHidden into HUD/menu surfaces
- **CodeBranch r53540** — Mirror IsHiddenInHud/IsHiddenInMenu surface split on mission task types

VCS audit: `svn log | grep` over MFT from r15943 to HEAD returns exactly this one server commit;
NPN20260602 carries none (inherited via branch copy at r16131 from MFT:16130).

## Post-commit rework (governs every finding below)

The core of r16049 did not survive:

- **r16124** (FP-43871, 2026-05-27) deleted `MissionTask.ApplyHideStateForBarrier` entirely and moved
  hide-state to `MissionsUtils.ApplyHideStateFromBarriers`, called from `CheckCondition` right after
  `CheckCached`, iterating **all** barriers with OR-aggregation. Introduced `IVisibilityBarrierCondition`.
- **r16279** rewrote `FullyHiddenWhileQueuedTests` to drive the real `MissionsManager.ProcessMessagesLoop()`.
- Later touches: `MissionsUtils.cs`/`MissionClientUtils.cs` at r16273, `MissionsManager_Processing.cs`
  at r16283 (FP-44716), `MissionsManager_Start.cs` at r16271.

Still unchanged since r16049 (per `svn info --show-item last-changed-revision`):
`MissionsManager_{Complete,Fail,Archived}.cs`, `MissionTaskOnClient.cs`, `MissionTaskTrackedOnClient.cs`.

Both reworks landed **before** the FTUE release (2026-06-11), so no r16049-era defect reached players
through that release.

## Findings

### F-1: Hide-state applied per-condition inside `Check()` is order-dependent and not aggregated across barriers [High]

**Description:** `MissionTask.ApplyHideStateForBarrier` is invoked from inside each barrier condition's
`Check()` with only that condition's own gating result. Two failure modes follow. When a task carries
more than one barrier, whichever `Check()` runs last overwrites the flags — last-writer-wins instead of
OR-aggregation. And because evaluation goes through `CheckCached()`, a cache hit or a short-circuited
sibling never re-runs `Check()`, so the flags go stale. r16049 did not introduce the pattern, but it
routed a second, more visible surface (`IsHiddenInMenu`) through the same flawed mechanism while
touching all three condition classes.

**Investigation:**
- Read `svn diff -c 16049` directly: all three of `TaskCompletedCondition` / `MissionCompletedCondition` /
  `MissionStartedCondition` call `task.ApplyHideStateForBarrier(context, result, …)` from within `Check()`,
  each passing only its own `result`. No cross-barrier aggregation exists anywhere in the diff.
- Read `MissionConditionWrapper.Initialize` (`Conditions/MissionConditionWrapper.cs:36-56`): `BarrierTaskConditions`
  is a `List<IMissionBarrierCondition>` filled by a `MissionVisitor` walking the whole condition tree.
  Conclusion: multiple barriers per task is a representable configuration, not hypothetical.
- Read `BaseCondition.CheckCached` (`Conditions/BaseCondition.cs:155-173`): guarded by
  `if (RequestId != context.RequestId || checkResultDirty)`; on a cache hit it returns without calling
  `Check()`. Conclusion: the hide-state side effect is skippable.
- Read `MissionsUtils.EnumerateMonitoringDependecies` (`MissionsUtils.cs:144-150`): calls
  `c.CheckCached(context)` on barrier conditions before the main evaluation pass, which warms the
  per-request cache. Conclusion: a concrete path that suppresses the later `Check()`.
- Cross-checked the outcome against the KB review of the follow-up commit
  (`review/FP-43871--mission-hud-gated-tasks/review.md`): it documents this exact mechanism as the root
  cause of a reported bug — completing prerequisites out of order left `IsHiddenInHud = true` stale, so
  unlocked tasks never appeared in the HUD until mission tracking was toggled.
- Verified the fix: `svn diff -c 16124` replaces the per-`Check()` writes with
  `MissionsUtils.ApplyHideStateFromBarriers`, which loops all barriers and ORs `unmet` into both flags.

**Resolution:** `Skipped — superseded by r16124`. Fixed before the FTUE release; no action against r16049.

**Discovered by:** skill recon / code-reviewer agent / Codex (independently, all three).

### F-2: `Negate` ignored when deriving hide-state for the two mission-scoped barriers [Medium]

**Description:** `ApplyHideStateForBarrier` receives the raw `Check()` result, but `Negate` is applied one
level up, in `CheckCached`. `TaskCompletedCondition.Check()` folds `Negate` into its own predicate, while
`MissionCompletedCondition.Check()` and `MissionStartedCondition.Check()` return the un-negated value. For
those two, a barrier declared with `Negate: true` drives visibility by the inverse of its effective result —
the task is hidden exactly when it should be shown.

**Investigation:**
- Read `svn diff -c 16049`: `MissionCompletedCondition.Check()` computes
  `result = context.CompletedMissions.Contains(MissionCode)` and passes `result` straight into
  `ApplyHideStateForBarrier`; `MissionStartedCondition.Check()` follows the same shape. Neither references `Negate`.
- Read `BaseCondition.CheckCached` (`Conditions/BaseCondition.cs:172`): returns `Negate ^ checkResultRequest`.
  Conclusion: `Negate` is applied outside `Check()`, so the value handed to the hide-state call is pre-inversion.
- Compared with `TaskCompletedCondition.Check()` in the same diff: `Any(t => t.Code == TaskCode && Negate ^ t.IsCompleted)` —
  folds `Negate` in itself. Conclusion: the two shapes disagree, and only the mission-scoped pair is affected.
- Checked provenance with `svn diff -c 16049` context lines: the pre-image was
  `task.IsHidden = !result` over the same un-negated `result`. Conclusion: pre-existing, inherited rather than introduced.
- Verified the fix: r16124's `ApplyHideStateFromBarriers` derives `unmet` from `barrier.CheckCached(context)`,
  which has `Negate` already applied.

**Resolution:** `Skipped — superseded by r16124`.

**Discovered by:** Codex (confirmed independently by skill recon against `BaseCondition.cs`).

### F-3: New tests exercise a path that cannot catch the mechanism's real failure modes [Low]

**Description:** `FullyHiddenWhileQueuedTests` calls `condition.Check()` directly and asserts the resulting
flags. That form pins the single-barrier happy path only — it cannot observe last-writer-wins between two
barriers, cache-suppressed re-evaluation, or `Negate` handling, which are the ways this mechanism actually
broke. The commit shipped a new content-facing flag with no coverage of the multi-barrier shape.

**Investigation:**
- Read the full new test file in `svn diff -c 16049`: every test constructs one condition and calls
  `condition.Check(BuildContextFor(mission))`. No test builds two barriers over one task; none drives
  `MissionsManager`.
- Cross-checked the follow-up: the FP-43871 review records that `FullyHiddenWhileQueuedTests` had to be
  rewritten to drive `MissionsManager.ProcessMessagesLoop()` because "`Check()` no longer owns hide-state;
  the old form would test a dead path", and that a separate `HiddenWhileQueuedOutOfOrderTests` was added for
  the two-barrier scenario. Conclusion: the gap was real and was closed only by the follow-up.
- Confirmed the current file is no longer the reviewed one: `svn info --show-item last-changed-revision`
  on the test file returns r16279.

**Resolution:** `Skipped — superseded by r16124/r16279`.

**Discovered by:** Codex.

### F-4: Client DTO field renamed with no compatibility alias [Info]

**Description:** `MissionTaskOnClient` and `MissionTaskTrackedOnClient` drop `[JsonProperty] IsHidden` and
expose only the two new fields. A client built against the old shape silently deserialises `false` for both,
making every gated task visible. The server change and its client mirror shipped 19 days apart.

**Investigation:**
- Read `svn diff -c 16049` on both DTOs: `IsHidden` removed outright; no `[JsonProperty("IsHidden")]` alias,
  no `[Obsolete]` shim.
- Established the client mirror timing: `svn log | awk` over the client repo shows CodeBranch r53540
  (2026-04-29, same day as the server commit) and MainClient r54243 (2026-05-18). Verified content rather
  than trusting the merge range — `svn cat -r 54243` of `MissionTaskOnClient.cs` in MainClient shows both
  new fields present. Conclusion: the release-branch client carried the mirror before the 2026-06-11 release.
- Checked persistence, since the same class family is `[JsonObject(OptIn)]`: the profile-side DTO
  `StartedMissionTask` (`Mission/Profile/StartedMission.cs:75-88`) carries only
  `TaskId/Code/Definition/Name/IsCompleted/Progress` — no visibility flag. Conclusion: no stored-data
  migration was required by the rename.
- Deployment regime per KB: prod ships all components as one batch and protocol bumps happen behind a
  downtime, so the skew window is a test-environment concern, not a live one.

**Resolution:** `Accepted`.

**Discovered by:** skill recon (raised as an unresolved hypothesis by Codex).

### F-5: Server half shipped a feature with no client consumer for two and a half months [Info]

**Description:** r16049 emits `IsHiddenInMenu` over the wire, but nothing on the client read it until the
paired client task landed. The FTUE release (2026-06-11) therefore carried a server flag that changed
nothing observable — which is what the GD hit on 2026-06-30 when `FullyHiddenWhileQueued: true` "did not work".

**Investigation:**
- Read `svn diff -c 53540` (client CodeBranch mirror): in `ActiveQuestDetails.cs` and `HudMissionTasksSRIA.cs`
  — the menu-side list builders — the visibility check is **commented out** both before and after, the
  edit only renaming the identifier inside the comment (`/*task.IsHidden || */` → `/*task.IsHiddenInHud || */`).
  No menu-side consumer was added.
- Grepped the MainClient checkout for `IsHiddenInMenu`: three hits only — the two DTO declarations and one
  assignment in `ClientMissionsManager`. No UI script reads it. Conclusion: the field was transported, never consumed.
- Located the real client implementation: `svn log | awk` shows FP-42951 committed to client CodeBranch at
  r56066 (2026-07-06) and merged to MainClient at r56304 (2026-07-13) — after the FTUE release.
- Checked the paired ticket: FP-42951 is Closed/Done, fixVersion `2026.5 Anniversary` (unreleased,
  release date 2026-07-29). Conclusion: the menu behaviour becomes observable only with 2026.5.

**Resolution:** `Accepted` — split delivery tracked by FP-42951, not a code defect in r16049.

**Discovered by:** skill recon.

## Verdict

**APPROVE.** The feature is implemented correctly at the content-model and wire level: the flag is added to
all three barrier condition types, both surfaces are forwarded to the client, every lifecycle reset site
pairs the two flags, and the `IsAdministrationRequest` guard is preserved. The defects this review found in
the hide-state application mechanism (F-1, F-2) are inherited from the pre-existing per-`Check()` design
rather than introduced here, and all of them were already rewritten by r16124 — before the FTUE release, so
nothing reached players through it. No rework is requested against r16049.

The reopen on the ticket traces to F-5, not to a server defect: the menu behaviour had no client consumer
until MainClient r56304 and becomes observable only with 2026.5.

**Verification scope:** root cause for F-1 is established, not merely symptom-level — the mechanism was
traced statically (barrier collection, `CheckCached` cache semantics, pre-warm path) and corroborated by the
QA repro recorded in the FP-43871 review. Not verified: nothing was built or executed, so no finding rests on
a test run; and live mission content was not queried, so the production prevalence of the affected shapes
(multi-barrier tasks, `Negate` on mission-scoped barriers, `FullyHiddenWhileQueued` usage) is unknown. That
gap does not affect routing here, since every code-rooted finding is superseded regardless of prevalence.

## Considered and rejected

- **Serial-tracking ignores `IsHiddenInMenu`.** `MissionsUtils.UpdateTasksToCheck` force-sets
  `firstIncompleted.IsHiddenInHud = false` and hides the other incomplete tasks in the HUD, never touching the
  menu flag — still true at HEAD (`MissionsUtils.cs:96-106`). Rejected as a defect: serial tracking implements
  "HUD shows one current task", whereas the menu is specified to list the whole mission and hide only
  `FullyHiddenWhileQueued` tasks (FP-42951 description). The asymmetry is the requirement, not a bug.
- **Rename breaks stored profile data.** Rejected — `StartedMissionTask` persists no visibility flag (see F-4).
- **`IsAdministrationRequest` guard duplicated across the three condition classes and possibly omitted in one**
  (raised as an unresolved hypothesis by the code-reviewer agent). Rejected by reading the diff: the guard is
  centralised as the first statement of `ApplyHideStateForBarrier`, appearing once, so no per-class copy-paste
  omission is possible.

## Notes

- Codex reported a missing `MissionProgress` push for an unchanged-but-visible HUD task after
  reconnect. That surface is FP-44716 (`MissionsManager_Processing.cs` @ r16283), which has its own open
  review card — not re-adjudicated here.
- Both delegated reviewers ran without repository access: Codex's sandbox had no SVN credentials and the
  code-reviewer agent had no shell, so both reasoned from on-disk r16373 plus secondary sources. Every
  finding above was re-grounded against the actual `svn diff -c 16049` before being recorded.

## Investigation Journal

- Intake from JIRA. Ticket reopened once: on 2026-06-30 the GD reported that
  `{ type: 'TaskCompletedCondition', TaskCode: 'Task_1', FullyHiddenWhileQueued: true }` did not work; the
  executor answered that client-side support was required (FP-42951) and the ticket went on hold until the
  2026-07-22 LGTM. That report is explained by F-5, not by a server defect.
- Initial hypothesis "the client never received the mirror, so the rename broke `HiddenWhileQueued` on prod"
  disproven: MainClient r54243 (2026-05-18) carries both fields, verified by `svn cat` on the file rather
  than by the merge range.
- Second hypothesis "the rename breaks previously stored profile rows" disproven by reading the profile DTO.
- Reviewed WC is at r16373, far ahead of r16049, and r16124 deleted the central method — all reviewed-code
  claims were therefore grounded via `svn diff -c 16049` / `svn cat -r 16049`, never from disk. This was
  passed to both delegates explicitly; both still hit access limits and fell back to on-disk state.
- Findings routing: F-1/F-2/F-3 Skipped as superseded by r16124/r16279, F-4/F-5 Accepted; no module-backlog
  entry needed since the mechanism was already rewritten.
