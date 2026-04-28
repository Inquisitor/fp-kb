---
status: resolved
executor: Yuriy Burda
branch: IMV20250220 @ r15620
jira: https://fishingplanet.atlassian.net/browse/FP-41491
---

# Review: FP-41491 — [Fishing] [Wear] server spams into logs after rod was fully weared and broken

## Summary

Backport of the FP-30194 crash fix (NRE in `GameProcessor.UpdateXmas2017Stats` reachable from the `HandleFightFish` → `UpdateWearSystem` → `ApplyWear` chain when a rod or reel breaks during Fight in a New Year event) from LBM/KNW down to IMV (OldStable) for hot-fix release. On prod the bug manifests as `HandleFightFish` aborting on every wear event, leaving the client without a breakage signal and producing log/global-chat spam.

## Scope

- **IMV20250220 r15620** — backport of the LBM r15574 fix to OldStable (IMV)

### Context (source fix, FP-30194)
- **LBM20251201 r15574** (2025-12-18) — "Fix disconnect when cutting line with no fish during new year event"
- **KNW20250723 r15578** — merge of LBM r15574 (Stable hotfix)

Review focus is "verify on LBM": the backport is mechanical, but its correctness depends on whether the LBM source fix is sound and still present at LBM HEAD.

## Verdict

**Approve mechanically — root cause not established.**

**Verification scope:**
- Source (LBM r15574): adds `if (fish == null) return` at the top of `GameProcessor.UpdateXmas2017Stats(stats)`. Reordering of subsequent guards is behaviorally equivalent.
- Backport (IMV r15620): byte-identical change to `UpdateXmas2017Stats`; `svn:mergeinfo` records both `KNW20250723:r15578` and `LBM20251201:r15574`.
- LBM HEAD: method body at `GameProcessor.cs:4961-4981` matches post-fix shape; `Last Changed Rev` 16010 (4+ months, not reverted).
- Call site `ApplyWear` (`GameProcessor.cs:1133` — `if (anyBreaks) UpdateXmas2017Stats(peer.Profile.Stats);`) is the same path that produced the JIRA crash and is now safe under the null-fish case.

**NOT verified:**
- Why `fish` becomes null mid-chain. The fix is a defensive null-guard on the symptom site; the mechanism that nullifies the field between `HandleFightFish` and `UpdateXmas2017Stats` was not pinned down. The executor explicitly noted in JIRA that the obvious repro path does not produce the NRE (rod/reel break during Fight does not nullify the fish — it is reset later), so root cause is genuinely open.

## Closing Decision

Closed as `resolved` despite the unestablished root cause, on the following rationale:

1. **Fix is in prod for ~4 months.** LBM r15574 → KNW r15578 shipped in `2025.8.0.2 Server Patch (concurrency and xmass)` released 2025-12-24. No recurrences reported in the interval.
2. **No fresh repro to drive root-cause work.** Without a new prod incident or a reproducible STR, any further investigation is speculative — keeping the issue open without new input is not a productive use of time. If the symptom resurfaces, the fresh stack trace becomes the new starting point and the issue is reopened.
3. **Backport itself is correct.** The IMV r15620 commit faithfully carries the LBM fix; nothing about the backport is in question.
4. **Fix Version moved off hotfix track.** Switched from `Next Server Hotfix` to `2026.3 Leaderboards` on 2026-04-28 — implicit team decision that no separate IMV hotfix is needed; the backport rides the regular release.

## Mechanism Investigation (speculative, no conclusion)

Captured after the closing decision, to record what is known and what is not.

- **Where the field becomes null.** Stack trace shows `fish.IsElectricOverload` succeeds at `HandleFightFish` (line 3958) but `fish` is null by the time `UpdateXmas2017Stats` runs (line 4961). The nullification must occur somewhere in the call chain between those two points: `UpdateWearSystem` (line 3966) → `wear.Update` → `ApplyWear` → 9 × `ApplyWearTo*` → `UpdateXmas2017Stats` (called from `ApplyWear:1133` if `anyBreaks`).
- **Why this is suspicious.** None of `ApplyWearToRod/Reel/Line/...` directly touch the `fish` field. They mutate `rod`, `reel`, `line`, etc. and call `OnEquipmentBroken` (which reads `fish` for stats and broadcasts an event) but don't write `fish`. Reaching null in this window would have to come from an indirect side effect — a callback or event broadcast triggering `ResetFish()` re-entry. That would be unusual for the codebase's fiber model.
- **`fish = null` only happens in `ResetFish()`** (`GameProcessor.cs:5618`). Called from 12 sites, mostly state-machine transition handlers (e.g., `DoReset` at 1619, triggered on `NeedClientReset` — Dmytro's desync-recovery event) and `Transitions.EscapeFish` at 2050.
- **Existing partial guard at `UpdateWearSystem:1001`.** `wear.ToothSharpness = action == FishingAction.Fight && fish != null ? fish.ToothSharpness ?? 0 : 0;`. So the team has hit `fish == null during Fight` before and patched it site-by-site rather than addressing the underlying race.
- **Possible angles if symptom recurs.** (a) Audit remaining unguarded `fish.<X>` derefs in the Fight chain. (b) Snapshot `fish` at `HandleFightFish` entry and use the snapshot through the chain instead of re-reading the field. (c) Read `wear.Update` source (Shared/BiteSystem area) to check whether it can synchronously trigger transitions via events.

## Notes

- **Fix lineage timing.** LBM r15574 (2025-12-18) → KNW r15578 (2025-12-19) → IMV r15620 (2025-12-29).
- **Branch-copy inheritance.** MFT (Code) was created from LBM @ r15942; r15574 ≤ r15942, so MFT inherits the fix automatically — no upward merge needed.
- **Out-of-scope concerns from executor's JIRA comment.** Executor notes the broader desync issue ("client doesn't get breakage signal → continues sending `FightFish`") and that newer branches than IMV emit a state-machine reset event added as part of desync recovery. Those are not addressed by this fix and remain a separate concern.
- **Commit-message JIRA reference.** All three revisions reference `FP-30194` only; nothing references `FP-41491`. This is per `<kb>/CLAUDE.md` SVN merge format (verbatim source message) — informational, not a defect.

## Investigation Journal

- 2026-04-28: opened review. JIRA FP-41491 (Resolution: Done since 2025-12-29; Status: In Review; Fix Version flipped 2026-04-28 from `Next Server Hotfix` → `2026.3 Leaderboards`).
- Source fix lineage assembled from FP-30194 comments: `LBM r15574` (2025-12-18), merge to `KNW r15578` (2025-12-19), QA verified on qa branch (2025-12-22). Backport request to IMV came 2025-12-26, executed as IMV r15620.
- SVN audit on IMV/KNW/LBM via `svn log | grep` — three revisions found, matching intake exactly; no orphan commits.
- Diffed LBM r15574 and IMV r15620 — same hunk modulo line offset (LBM @4878, IMV @4533). `svn:mergeinfo` on IMV records both KNW r15578 and LBM r15574 (chained merge).
- LBM HEAD (`GameProcessor.cs` Last Changed Rev 16010) inspected at `UpdateXmas2017Stats` and the `ApplyWear` call site — fix intact, call path safe.
- Recon-only path chosen; code-reviewer agent delegation declined given the change is single-method, single-hunk, and verified end-to-end on LBM HEAD.
- 2026-04-29: initial "fix is correct" framing was challenged — recon had only verified mechanical equivalence, not root cause. Re-ran a mechanism dig (call-chain trace, `ResetFish` callers, partial-guard discovery at `UpdateWearSystem:1001`) and tightened the verdict scope. Conclusion: nullification mechanism between `HandleFightFish:3958` and `UpdateXmas2017Stats:4961` not pinned down; closing on pragmatic grounds (no repro in 4 months, fix in prod), not on "the bug is understood".
