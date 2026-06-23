---
status: resolved
executor: Yuriy Burda
branch: MFT @ r16186, merged to NPN @ r16189
jira: https://fishingplanet.atlassian.net/browse/FP-44470
---

# FP-44470: [FTUE][UI][Shop] Not compatible items listed for reels

## Summary

In the shop tackle catalog, browsing a reel (Shop > REELS > select reel > RODS button) listed incompatible rods among the compatible items. Only compatible rods should appear per reel type. Part of FTUE REWORK shop controls (parent FP-43819, shares design note with FP-44411 / FP-44481). Inverse direction of FP-44411 (rod -> reel).

Expected reel -> rod compatibility (from JIRA):
- Spinning Reel / Saltwater Spin Reels -> Spinning Rod, Telescopic, Match, Feeder, Bottom, Carp, Spod, Saltwater Spinning, Saltwater Bottom Spinning
- Casting Reel / Saltwater Cast Reel / Saltwater Cast E-Reel -> Casting Rod, Saltwater Casting, Saltwater Bottom Casting, Saltwater Bottom Casting E-Rods

## Scope

- **MFT r16186** — List only compatible rods per reel in shop tackle catalog
- **NPN r16189** — Merge from MFT (combined r16185-r16187 for FP-44411 / FP-44470 / FP-44481)

## Findings

### F-1: reels that are neither cast nor spin are not narrowed [Info, pre-existing]

**Description:** This commit narrows the reel->rod direction for cast/spin reels only (`IsCastReel() || IsSpinReel()`). `FlyReel` and `LineRunningReel` (in `Inventory.SubTypes.Reels` but not in `CastReels`/`SpinReels`) skip the narrowing branch and fall through to structural-only matching via the broad `reels` restriction, so they resolve to all spinning/casting rods un-narrowed. Not introduced here (pre-commit shop had no narrowing at all) and FlyRod/FlyReel are not really part of the template system; the guard test deliberately iterates only `CastReels.Concat(SpinReels)`.

**Investigation:** Confirmed `IsCastReel/IsSpinReel` membership in `Inventory_Groups.cs`; traced `IsTackleAllowedOnRod` fall-through for non-cast/non-spin reels. code-reviewer agent reached the same conclusion (pre-existing, not a regression).

**Resolution:** Pre-existing — noted, not addressed in this review. Out of scope of the three FTUE shop tickets.

**Discovered by:** skill recon + code-reviewer agent.

## Verdict

**Approve.** reel->rod narrowing matches the design-note matrix: spin reels -> {Spinning, Telescopic, Match, Feeder, Bottom, Carp, Spod, Saltwater Spinning, Saltwater Bottom Spinning}; cast reels (incl. E-Reel) -> {Casting, Saltwater Casting, Saltwater Bottom, Saltwater Bottom Cast E-Rod}. Symmetric with rod->reel. The E-Reel broadening (deleted "electric reel on non-electric rod" comment) is a deliberate reversal explicitly listed in the FP-44470 EXP. 41 tests pass. Only an Info pre-existing note (F-1).

## Investigation Journal

- Phase 1 intake: commit and branch from JIRA comment (author Yuriy Burda); Executor field (`customfield_11224`) empty in JIRA.
- This commit's inline reel filter (`Templates.SelectMany(RodTypes)` filtered by `IsRodWithCastReel`) was superseded by r16187, which routes through `Templates.Compatible(item)` + `IsTackleAllowedOnRod`. Reviewed final HEAD state; reel test expectations from r16186 still hold under r16187's refactor (tests unchanged, pass).
- Matrix traced against `Inventory_Groups.cs` sets; reverse direction symmetric with rod->reel (r16185) by construction (same arrays back the predicates).
- E-Reel: `SaltwaterCastEReel in CastReels`, and `SaltwaterBottomCastRods` includes the E-rod, so the SaltwaterBottomCast (`castReels`) template yields the symmetric cast-rod set. Matches FP-44470 EXP.
- Branch-copy: NPN forked at MFT:16130; r16186 later -> explicit merge r16189 required and done.
- code-reviewer agent (deep delegation) independently confirmed correctness/symmetry; flagged FlyReel/LineRunningReel (F-1) as pre-existing only.
