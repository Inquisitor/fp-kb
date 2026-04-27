---
status: resolved
executor: Yuriy Burda
branch: LBM @ r16016, merged to MFT @ r16017
jira: https://fishingplanet.atlassian.net/browse/FP-43389
---

# FP-43389: MissionTasks id=14693: fish caught in FT is not counted

## Summary

Bug report from Test-environment QA (Steam `qa_branch` v6.0.9): mission task id=14693 ("catch 15 fish from a boat under 5 kg") does not credit fish caught in a Fishing Together (FT) session. Random sessions are unaffected. Root cause: `BoatManager` constructor's FT-session branch called `Board(...)` but never synchronised `MissionsContext.IsOnBoat` (the mission-rule signal). Fix extracts a `MissionsContext.OnBoard(boat)` helper and invokes it from the FT branch (the actual fix) plus two existing call sites (DRY refactor).

## Scope

- **LBM r16016** — Server: Sync `MissionsContext.IsOnBoat` when boarding in FT session
  - Add `MissionsContext.OnBoard(InventoryItem boat)` helper: null-guard then sets `IsOnBoat = true`, `ActiveBoatType = boat.ItemSubType`, `ActiveBoat = boat`
  - `BoatManager` ctor FT branch — new `OnBoard(boat)` call (the missing sync — root cause)
  - `BoatManager` ctor non-FT branch — refactor 3 inline assignments → `OnBoard(activeBoat)`
  - `MultiRodGameProcessor.HandleBoard` — refactor 3 inline assignments → `OnBoard(activeBoat)`
- **MFT r16017** — Merge of LBM r16016 (verified clean: byte-identical patch + `svn:mergeinfo` only)

## Investigation Journal

- 2026-04-27 — Card created. Pre-flight reads done. JIRA intake: 1 LBM commit + 1 MFT commit, both authored by Yuriy Burda per JIRA comment. `customfield_11224` (Executor) empty — flagged.
- Release status per user: fix is in Test environment, not in prod — pre-release severity rules apply.
- VCS audit: `svn log | grep "FP-43389"` confirms exactly r16016 (LBM) and r16017 (MFT). MFT was branched from LBM r15942 < 16016, so explicit merge was required (no inheritance via branch copy).
- Merge equivalence verified: `svn diff -c 16017 MFT` vs `svn diff -c 16016 LBM` differ only in hunk-header offsets (file length differs above changed lines) and `svn:mergeinfo` property — code change is byte-identical.
- Working copy at r16013 (pre-fix); HEAD content read via `svn cat -r HEAD` for verification.
- code-reviewer agent spawned for independent check — confirmed F-1 hypothesis (Verified, Confidence 82) and added the F-2 ordering-asymmetry note (which I downgraded to a non-finding after determining it is identical to the pre-existing inline pattern).
- Findings routing: F-1 Accepted inline (strict improvement, side-effect of intentional helper extraction). No triage entry — does not require release-meeting attention.

## Findings

### F-1: Non-FT `BoatManager` ctor null-boat path now leaves `MissionsContext` at defaults instead of inconsistent state [Low / Info]

**Description:** In the refactored non-FT branch of `BoatManager` constructor (the `else if (data != null)` / `if (data.IsBoarded)` path), `peer.GetBoat(false, data.LastBoatType, out _)` ultimately calls `Inventory.GetBoatOfType(false, boatType)` (in `Inventory_Does.cs`), which returns `FirstOrDefault(...)` — i.e., may return `null`. Pre-fix, the three inline assignments ran unconditionally, producing an internally inconsistent `MissionsContext` state (`IsOnBoat = true` with `ActiveBoat = null`) for any player whose `PersistentData.IsBoarded == true` but whose boat is no longer in inventory (e.g., expired rental, admin removal, data inconsistency). Post-fix, `OnBoard(null)` returns early and all three fields stay at defaults (`IsOnBoat = false`). This is a side-effect of the helper extraction, not the targeted bug fix.

**Investigation:** Verified via `Shared/ObjectModel/Inventory/Inventory_Does.cs` (`GetBoatOfType` → `FirstOrDefault`) and `GameClientPeer_Inventory.cs` (`GetBoat` does not null-guard the cast). code-reviewer agent independently flagged the same path with Confidence 82 and confirmed `BoatManager.Board` itself early-returns on null boat — so the old code's `IsOnBoat = true` signal was contradicting the actual game state.

**Resolution:** Accepted — the new behavior is strictly more consistent than the old. Note in the card; no further action.

**Discovered by:** skill recon, confirmed by code-reviewer agent.

## Notes

- Order of writes in `OnBoard(boat)` (`IsOnBoat = true` → `ActiveBoatType = ...` → `ActiveBoat = boat`) is identical to the pre-fix inline pattern at all three call sites. The agent flagged this as a latent ordering hazard (any mission evaluator triggered synchronously by `OnDependencyChanged("IsOnBoat", …)` would observe stale `ActiveBoat`); the asymmetry is real but pre-existing — this refactor neither introduces nor fixes it. Out of scope.
- FT guest path (`ftSession.HostId != peer.Profile.UserId`) also calls `OnBoard(boat)` → guests get `IsOnBoat = true`. Consistent with the existing `BoatManager.Board` design comment ("count when boarded as guest (FT) and for rented boats"). Mission task id=14693 should credit guests, so this is correct.

## Verdict

**Approve.** Single targeted fix for a clearly identified bug; the helper extraction is a clean DRY win that also incidentally tightens the inconsistent-state edge case in the non-FT path. No blocking issues, no regressions identified.
