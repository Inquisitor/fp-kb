---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16124
jira: https://fishingplanet.atlassian.net/browse/FP-43871
---

# FP-43871: New mission tasks not displayed in HUD after last fish caught

## Summary

Server bug in mission HUD updates. When a mission has gated tasks (tasks unlocked by prerequisites) and the player completes them out of order — e.g. completes the last task before its prerequisite — the server keeps `updatedTasks[i].IsHiddenInHud = true` for the newly-unlocked tasks. The client therefore never displays them in the HUD until the player toggles mission tracking, which forces a full refresh. Fix lives on the Code branch (MFT20260325) at r16124.

Per JIRA comment (Ivan Dobra, id:121494): completing tasks in order sends `false` in `IsHiddenInHud`; completing the last task first then the first leaves the flag `true`.

## Scope

- **MFT20260325 r16124** — Fix gated tasks staying hidden when prerequisites complete out of order

## Mechanism

- **Before:** each barrier condition (`TaskCompletedCondition` / `MissionCompletedCondition` / `MissionStartedCondition`) set hide-state inside its own `Check()` via `MissionTask.ApplyHideStateForBarrier`. With multiple barriers wrapped in a `SerialCondition`, the result was last-writer-wins and depended on which conditions actually got evaluated (short-circuit). Completing prereqs out of order left `IsHiddenInHud = true` stale.
- **After:** hide-state moved to a centralized `MissionsUtils.ApplyHideStateFromBarriers`, called from `CheckCondition` right after `wrapper.Condition.CheckCached`. It iterates **all** `wrapper.BarrierTaskConditions` (collected recursively at `Initialize` time by `MissionVisitor`, so nested barriers are included), explicitly calls each barrier's `CheckCached`, and OR-aggregates: `IsHiddenInHud = any visibility-barrier unmet`; `IsHiddenInMenu = any FullyHiddenWhileQueued barrier unmet`. Order-independent by construction.
- New `IVisibilityBarrierCondition : IMissionBarrierCondition` carries `HiddenWhileQueued` / `FullyHiddenWhileQueued`; the three barrier conditions now implement it.

## Notes

- **N-1 (verified):** `ApplyHideStateForBarrier` fully removed from `MissionTask`; no remaining callers (grep). Clean removal.
- **N-2 (verified):** `ApplyHideStateFromBarriers` guards `wrapper.Task == null`, so it only affects task complete-conditions, not StartCondition wrappers. `CheckCached` is the same cached call already used in `EnumerateMonitoringDependecies` — re-invoking per barrier returns cached results, no side-effect risk.
- **N-3 (verified):** Semantic parity with old single-barrier behavior preserved — both-flags → both hidden (Fully wins), HiddenWhileQueued-only → menu untouched (`newIsHiddenInMenu` stays null, not written). Renamed tests confirm.
- **N-4 (info):** `ApplyHideStateFromBarriers` does not filter by `IsBarrierActive` — consistent with the old `ApplyHideStateForBarrier` (which also ignored it). Not a regression.
- **N-5 (question for verdict):** LBM20251201 (Content) carries an older, structurally-different implementation — only `HiddenWhileQueued`, applied inline in `Check`, no `FullyHiddenWhileQueued`/`ApplyHideStateForBarrier`. The fix lives on Code (MFT); merge direction is Content→Code, so it does not propagate down. Whether the out-of-order defect needs a separate fix on a release branch depends on which branch the QA bug ships against — out of scope for this commit, flag for release planning.
- **N-6 (info, pre-existing — found by code-reviewer agent):** A visibility barrier nested inside an `OrCondition` is still collected into `BarrierTaskConditions` and evaluated independently by `ApplyHideStateFromBarriers`, ignoring OR short-circuit — so a task could stay hidden even when the OR is satisfied via another branch. Structural limitation of the barrier-visibility model; the old `Check()`-side-effect approach had the same (or worse, last-writer-wins) behavior. Not introduced by this fix; no current mission uses this shape per recon. Recorded only.

## Verdict

**APPROVE.** Single-commit fix on the Code branch (MFT20260325 r16124) that correctly addresses FP-43871. Root cause — order-dependent, short-circuit-sensitive per-`Check()` application of HUD/menu hide-state — replaced by an order-independent, OR-aggregated centralized pass over all collected barriers. No defects in the diff. Independently validated by a code-reviewer agent (clean, no high-confidence issues; two pre-existing edge cases noted, neither a regression). Tests directly cover the reported out-of-order scenario and the broader `FullyHiddenWhileQueued` contract.

N-5 resolved at closure: no parallel fix on the release branch — the MFT (Code) release is imminent, so the fix ships with it; LBM's older implementation is not patched.

## Tests

- New `HiddenWhileQueuedOutOfOrderTests`: two `HiddenWhileQueued` barriers gating Task_12/Task_13, asserts unhidden after both prereqs complete in BOTH orders, and that `MissionProgress` fires with `IsHiddenInHud=false`. Directly covers the reported bug.
- `FullyHiddenWhileQueuedTests` rewritten from direct `condition.Check()` calls to driving through the real `MissionsManager.ProcessMessagesLoop()` — necessary because `Check()` no longer owns hide-state; the old form would test a dead path.

## Investigation Journal

- Intake: Executor field empty (`⚠ expected: Yuriy Burda`); executor = commit author per JIRA comment id:121620. Single commit on Code branch (MFT20260325). No cross-branch merge noted in JIRA.
- Verified `BarrierTaskConditions` is populated recursively via `MissionVisitor` in `MissionConditionWrapper.Initialize` — the fix's order-independence rests on this, confirmed by reading the wrapper, not assumed.
- Hypothesis "explicit per-barrier `CheckCached` in `ApplyHideStateFromBarriers` could double-evaluate / have side effects" — ruled out: same cached call already used at `EnumerateMonitoringDependecies`; barriers are the same tree instances evaluated by the main `CheckCached`.
- Grep on LBM confirmed Content branch has the older single-flag implementation; informs N-5.
- code-reviewer agent dispatched (independent validation of clean-LGTM): confirmed correctness on all five probe axes (OR/null-coalescing, every-call invocation safety, recursive barrier collection + cache freshness, removed-method callers, edge cases). Surfaced N-6 (OrCondition-nested barrier), assessed pre-existing.
