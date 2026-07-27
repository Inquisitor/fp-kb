---
status: resolved
executor: Yuriy Burda
branch: MFT @ r16291, merged to NPN @ r16292
jira: https://fishingplanet.atlassian.net/browse/FP-44859
---

# Review: FP-44859 — ANNIVERSARY 2026: Server - Some conditions doesn't refresh properly

## Summary

Mission task conditions could return stale results: within a single client signal, conditions are evaluated once, but mission-side effects of that same pass (item grant, removing fish from the cage) mutate the state the earlier condition results were computed from. A task whose `OrCondition` flips composition mid-pass (e.g. `FishCageCondition` true→false while `TaskCompletedCondition` false→true) fails to complete until client restart or cache refresh. Fix per executor: re-evaluate condition results after mid-pass cache invalidation.

## Scope

- **MFT r16291** — Fix stale condition result after mid-pass cache invalidation
- **NPN r16292** — Merge of r16291
- **MFT r16371** — Add `BaseConditionMidPassRefreshTests` (F-1 leaf-coverage regression test, added during this review)
- **NPN r16373** — Merge of r16371

## Findings

### F-1: New tests cover only the AndCondition half of the fix [Low]

**Description:** The fix touches two independent cache holders — `BaseCondition` (leaf conditions) and `AndCondition` (composites: OrCondition/SerialCondition). All four `OrConditionSimultaneousFlipTests` exercise only the `AndCondition` half: the sole mid-pass invalidation is a sibling task completing (`@Trigger` → composite reset), while the rising leg is a cache-bypassing `TaskCompletedCondition` and the leaf `FishCage`/`Inventory` state-changes land before `ProcessMessagesLoop`. The real JIRA scenario (item granted as part of the mission, mid-pass) invalidates a leaf (`InventoryCondition`) and relies on the `BaseCondition` half, which no test guarded — a future regression of only that half would ship green.

**Investigation:** Discovered by Codex; confirmed by own static trace (test state-changes precede the pass; `TaskCompletedCondition.CheckCached` is cache-free). Delegate disagreement on whether the 4 tests are discriminating was resolved empirically: reverse-merge r16291 on both prod files → 2/4 fail (Codex correct, hunt-agent trace disproven). Gap closed this cycle: added `BaseConditionMidPassRefreshTests` (leaf-level unit test, `ResetCached` mid-pass within one RequestId). Discriminating power proven: reverse-merge r16291 on BaseCondition.cs **only** → new test fails while old 4 pass; revert → 5/5 green.

**Resolution:** `Resolved → r16371` — test added within this review cycle (`BaseConditionMidPassRefreshTests.cs`), committed MFT r16371, merged NPN r16373. The underlying fix (r16291) is correct in both halves and non-blocking.

**Discovered by:** Codex.

### F-2: Residual stale-cache window on re-entrant invalidation [Low]

**Description:** In both patched `CheckCached` bodies, `checkResultDirty = false` is cleared before `Check()` (correctly protecting the RequestId gate), but the granular cache line `checkResultCached = Check(context)` unconditionally overwrites the `null` that a re-entrant `ResetCached()` set mid-`Check`. Net effect: when a condition (or a sibling under the same composite) synchronously invalidates itself while its own `Check` is on the stack, `checkResultDirty` stays `true` but `checkResultCached` holds a pre-change value; the next `CheckCached` consumes dirty, sees `checkResultCached != null`, and serves the stale value without re-evaluating. Symptom = a task can stay mis-evaluated until the next external invalidation of that condition (bounded, not until restart).

**Investigation:** H1 hypothesis (skill recon), delegated to general-purpose agent → CONFIRMED-REACHABLE with full trace. Re-verified by own reads: `SerialAchievement.Check` calls `UpdateVariables`/`ResetVariables` (MissionsUtils.cs:392/416/430 → `context.OnDependencyChanged("#var/<mid>")`) and `IncrementCounter` (MissionsContext.cs:1081 → `OnMissionDependencyChanged`), both synchronous, both mid-`Check`; `OnDependencyChanged` under lock → `Affect` → `ResetCached`. `FishCageCondition.Check` raises `OnMissionDependencyChanged` on progress change mid-`Check`. Triggering content pattern (child sets `#var`, sibling predicate reads it in the same SerialAchievement) exists in `ResetOnFailTests`. **Assessed PRE-EXISTING, not a regression:** before r16291 the same overwrite latched the stale value until the next RequestId (a *wider* window); the fix narrows it (closes on the next external invalidation) but does not fully eliminate it. Worst variant is composite: a late child's mid-`Check` raise resets the parent And/Serial plus an earlier-evaluated sibling; the parent caches a composite result embedding the sibling's pre-change value. Full fix would be to not overwrite `checkResultCached` when `checkResultDirty` was re-raised during `Check` — a hot-path semantic change, out of this ticket's scope.

**Resolution:** `Filed → FP-45234` (Bug, Tech Debt Q3 epic FP-44818, Relates FP-44859). Not blocking; r16291 stands as a net improvement.

**Discovered by:** skill recon (H1), confirmed by code-reviewer/general-purpose agent.

### F-3: BaseHintRegular carries the same unpatched RequestId-only cache [Info]

**Description:** `BaseHintRegular.CheckCached` (`Hint/Hints/BaseHintRegular.cs`) uses the exact single-barrier `if (RequestId == context.RequestId) return checkResult;` pattern the conditions had before r16291 — no dirty bit. Unlike conditions, `IHint` exposes no `ResetCached()` at all (`IHint.cs` — only `Check`/`CheckCached`/`Reset`), so hints are invalidated only by the coarse full `Reset()` (zeroes RequestId), not by per-dependency `Affect`. Blast radius is therefore far smaller than the condition bug: the hint cache (`checkResult`) is single-level (no cross-request `checkResultCached`), so staleness is bounded to one processing pass and affects only displayed hint text, not task-completion logic.

**Investigation:** Discovered by code-reviewer agent (blind hunt). Verified by own read of `IHint.cs` (no `ResetCached` member) and `BaseHintRegular.cs` (single RequestId gate, no granular cache). Pre-existing — r16291 does not touch this file.

**Resolution:** `Pre-existing` — noted in FP-45234 (Related paragraph) and in the missions module backlog. Cosmetic, single-pass, non-blocking.

**Discovered by:** code-reviewer agent.

## Verdict (draft — not yet published)

**Approve (ship).** r16291 is mechanically correct in both cache halves (leaf `BaseCondition` + composite `AndCondition`); the granular-caching-disabled branch is equally gated; serialization is clean (runtime fields carry no `[JsonProperty]` under `OptIn`); no mid-request re-evaluation regression found in progress counters / `ShouldResetSerial` / processing loops. The new tests are discriminating (reverse-merge experiment: 2/4 fail without the fix), and the F-1 leaf-coverage gap was closed within this cycle.

**Verification scope:** verified — the ticket's primary mid-pass scenario (a leaf or composite invalidated *between* evaluations within one RequestId) is closed; discriminating tests prove red/green. NOT fully closed — the re-entrant sub-case where a condition invalidates itself *during* its own `Check` (F-2) leaves a residual stale window; this is pre-existing (the fix narrows, not widens it) and non-blocking.

**Closed at finalization:**
- F-1 test committed MFT r16371, merged NPN r16373 (symmetric to the fix's r16291/r16292).
- F-2 filed as FP-45234 (Tech Debt Q3); F-3 noted there + missions backlog.
- Verdict comment posted to FP-44859 (LGTM + Verification-scope warning panel citing FP-45234); JIRA status/transition left to the assignee.

## Investigation Journal

- Intake from JIRA comment 129213 (executor Yuriy Burda): commits taken at face value, pending Phase 2 svn audit.
- VCS audit: `svn log -r 15943:HEAD` (MFT) and `-r 16131:HEAD` (NPN) piped through grep FP-44859 → exactly two commits, r16291 (fix) + r16292 (merge), matching the JIRA comment. No executor-quality notes.
- WC freshness: `svn info --show-item revision` → r16351 ≥ r16291; disk reads trustworthy.
- Mechanism grounding (read BaseCondition.cs, AndCondition.cs, MissionConditionWrapper.cs, ConditionMonitoringSurface.cs): invalidation chain is `OnDependencyChanged` → `wrapper.Affect(dependency)` → `condition.ResetCached()`, reachable mid-pass; the RequestId gate previously swallowed it within the same request; `checkResultDirty` pierces the gate. `dirty = false` is set *before* `Check()`, so an invalidation arriving during evaluation is not lost.
- Pattern coverage: grep `private int RequestId` in Shared/ObjectModel → three holders: BaseCondition (patched), AndCondition (patched), BaseHintRegular (unpatched — but it has no cross-request granular cache, so hint staleness is bounded by a single request, unlike the reported bug). Composite conditions covered via inheritance: OrCondition : AndCondition, SerialCondition : AndCondition (grep of class declarations).
- Cross-repo mirror check (Step 6): client ObjectModel copy (`Win64_MainClient/Assets/Photon Server Networking/ObjectModel/Mission/Conditions/`) holds only BaseCondition.cs + IMissionClientCondition.cs; grep for RequestId/CheckCached/ResetCached in the client BaseCondition.cs → only an empty `ResetCachedAutoHints` hook. Server-side condition-cache machinery is not source-mirrored → no client mirror needed for this fix.
- Empirical test run: `dotnet test ObjectModel.Tests --filter OrConditionSimultaneousFlip` on WC r16351 → 4/4 passed (net472).
- Hypothesis H1 (recorded unverified, delegated for targeted verification): if `ResetCached()` fires re-entrantly *during* the same condition's `Check()`, the post-Check assignment `checkResultCached = result` repopulates the just-nulled cache; the next dirty-triggered CheckCached would serve `checkResultCached.Value` without re-evaluating — a residual stale window. Reachability unknown (requires a synchronous dependency-raise inside a Check stack).
- Delegated (Step 7): blind defect hunt — code-reviewer agent + Codex (gpt-5.6-sol) in parallel; targeted H1 reachability trace — general-purpose agent.
- Codex claim "TaskCompletedCondition bypasses the cache" verified by reading MissionConditions.cs: TaskCompletedCondition / MissionCompletedCondition / MissionStartedCondition override `CheckCached` to live-evaluate `Check(context)` — no cache, immune by construction.
- Codex claim "tests don't cover the BaseCondition half" verified by own static trace: both test state-changes land before `ProcessMessagesLoop`; the only mid-pass invalidation is `@Trigger` → composite (AndCondition-path) reset; the rising leaf is the cache-bypassing TaskCompletedCondition. The real JIRA scenario (item granted as part of the mission, mid-pass) invalidates a leaf (InventoryCondition) and needs the BaseCondition half, which no test guards.
- H1 delegated verdict CONFIRMED-REACHABLE; every chain link re-verified by own reads: `MissionsContext.OnDependencyChanged` is synchronous (`checkMonitoredDependencies` under lock); `SerialAchievement.Check` calls `UpdateVariables`/`IncrementCounter`/`ResetVariables` mid-Check; `FishCageCondition.Check` raises `OnMissionDependencyChanged` on progress change mid-Check; composites self-register for children's dependencies (AndCondition.GetMonitoringDependencies, SerialAchievement.GetMonitoringDependencies); `SerialAchievement : SerialCondition : AndCondition`. Assessed as PRE-EXISTING, not a regression: before r16291 the same re-entrant overwrite latched stale results across request boundaries too; the fix neither created nor widened the window.
- Delegate disagreement (decision-affecting, surfaced to user): Codex — tests `cage_leg_falls_as_task_leg_rises` + `without_further_processing_passes` are discriminating (fail without fix); hunt-agent static trace — Subject↔Trigger pair should settle both-incomplete regardless of fix (flagged by the agent itself as unexecuted hypothesis). Resolved empirically (user-approved reverse-merge experiment): `svn merge -c -16291` file-scoped on the two production files → test run 2 Failed / 2 Passed (matching Codex) → `svn revert` both → control run 4/4 Passed, `svn status` clean. Hunt-agent trace disproven.
- Hunt-agent claim "IHint has no ResetCached" verified by reading IHint.cs: interface exposes Check/CheckCached/Reset only — hints have no granular invalidation; BaseHintRegular staleness is bounded by a single request (no cross-request cache), display-only.
- Hunt-agent facts accepted after verification: `context.RequestId` incremented only in `ProcessMessagesLoop` outer loop (grep — two sites in MissionsManager_Processing.cs); `IsGranularCachingEnabled` never set false anywhere (declared/read only) — dead flag, both cache modes correctly gated by dirty anyway.
- F-1 remediation (test-coverage gap closed this cycle): wrote leaf-level unit test `BaseConditionMidPassRefreshTests.Leaf_condition_reevaluates_after_reset_within_same_request` (InventoryCondition, `ResetCached` mid-pass within one RequestId, no `MissionsManager` machinery). Discriminating power proven empirically: `svn merge -c -16291` on **BaseCondition.cs only** (AndCondition left patched) → new test fails, old 4 Or-flip tests pass (proving they never touched the BaseCondition half); `svn revert` → control run 5/5 green.
- Closure: test committed MFT r16371, merged to NPN r16373 (user-directed run-authorization). F-2 filed FP-45234 (Bug, parent Tech Debt Q3 epic FP-44818, Relates FP-44859); F-3 → missions backlog + noted in FP-45234. Verdict comment (id 132771) posted to FP-44859.
