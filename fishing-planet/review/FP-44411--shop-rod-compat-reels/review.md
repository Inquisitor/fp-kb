---
status: resolved
executor: Yuriy Burda
branch: MFT @ r16185, merged to NPN @ r16189
jira: https://fishingplanet.atlassian.net/browse/FP-44411
---

# FP-44411: [FTUE][UI][Shop] Not compatible items listed for casting and spinning rods

## Summary

In the shop tackle catalog, browsing a casting or spinning rod (Shop > RODS > select rod > RODS button) listed incompatible reels among the compatible items. Only compatible reels should appear per rod type. Part of FTUE REWORK shop controls (parent FP-43819, shares design note with FP-44470 / FP-44481).

Expected rod -> reel compatibility (from JIRA):
- Spinning, Saltwater Spinning, Saltwater Bottom Spinning -> Spin Reels, Saltwater Spin Reels
- Casting, Saltwater Casting, Saltwater Bottom Casting, Saltwater Bottom Casting E-Rods -> Cast Reels, Saltwater Cast Reels, Saltwater Cast E-Reels

## Scope

- **MFT r16185** — List only compatible reels per rod in shop tackle catalog
- **NPN r16189** — Merge from MFT (combined r16185-r16187 for FP-44411 / FP-44470 / FP-44481)

## Findings

### F-1: rod->reel and reel/bobber->rod use two parallel narrowing implementations [Low/Info]

**Description:** `DeriveCompatibleReelTypes` (rod->reel, this commit) short-circuits with `CastReels`/`SpinReels` arrays chosen by `IsRodWithCastReel()`, independent of the rod's actual per-template reel restrictions. The sibling direction `DeriveCompatibleRodTypes` (r16187) instead applies the unified `IsTackleAllowedOnRod` overlay over structural `Templates.Compatible`. The two are verified consistent today, but the rod->reel path's exactness is not enforced — a future rod whose template carries a narrower reel restriction than the full cast/spin set would be over-reported, and the guard test only checks non-emptiness.

**Investigation:** Traced all rod subtypes against `RodsWithCastReel = {CastingRod, SaltwaterCastingRod, SaltwaterBottomRod, SaltwaterBottomCastERod}`; every current rod's structural reel restriction matches the cast/spin array returned. code-reviewer agent independently reached the same conclusion (intentional broadening, no current over-report).

**Resolution:** Accepted — correct for all current rods; maintainability note only. Optional: unify rod->reel through the same structural-intersection overlay.

**Discovered by:** skill recon.

## Verdict

**Approve.** rod->reel narrowing matches the design-note matrix (spin rods -> SpinReels, cast rods -> CastReels), symmetric with the reel->rod direction, FlyRod correctly empty. 41 TackleCompatibilityTests pass on the current build. Only a Low/Info maintainability note (F-1).

## Investigation Journal

- Phase 1 intake: commit and branch from JIRA comment (author Yuriy Burda); Executor field (`customfield_11224`) empty in JIRA.
- VCS audit: `svn log | grep` on MFT confirms exactly r16185-16187 for the three FP IDs; NPN r16189 is the combined merge of all three (same two files). No commit-discovery discrepancies.
- Symmetry verified by tracing `Inventory_Groups.cs`: `IsCastReel/IsSpinReel(x) => x in CastReels/SpinReels` — the same arrays the rod->reel path returns, so rod<->reel is symmetric by construction.
- `dotnet test --no-build` on `ObjectModel.Tests` (TackleCompatibilityTests): 41/41 pass; new symbols compiled => build reflects HEAD.
- Branch-copy: NPN forked at MFT:16130; r16185-87 are later, so not inherited via copy — explicit merge r16189 was required and done. Content->Code is the top of the merge chain; no further merge needed.
- code-reviewer agent (deep delegation) independently confirmed correctness and symmetry; no blocking issues.
