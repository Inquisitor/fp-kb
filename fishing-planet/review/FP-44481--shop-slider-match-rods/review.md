---
status: resolved
executor: Yuriy Burda
branch: MFT @ r16187, merged to NPN @ r16189
jira: https://fishingplanet.atlassian.net/browse/FP-44481
---

# FP-44481: [FTUE][UI][Shop] Not compatible items listed for sliders/wagglers

## Summary

In the shop tackle catalog, browsing sliders/wagglers (Shop > TERMINAL TACKLE > BOBBERS > select slider/waggler > RODS button) listed incompatible rods — Telescopic rods appeared, but only Match rods should be compatible. Part of FTUE REWORK shop controls (parent FP-43819, shares design note with FP-44411 / FP-44470).

Expected: sliders/wagglers -> Match rods only.

## Scope

- **MFT r16187** — List only Match rods for sliders/wagglers in shop catalog
- **NPN r16189** — Merge from MFT (combined r16185-r16187 for FP-44411 / FP-44470 / FP-44481)

## Findings

### F-1: slider/waggler->Match restriction has no SERVER equip/hint parity — but the CLIENT enforces it independently [Info, resolved]

**Description (hypothesis):** The slider/waggler->Match rule is introduced only in the server shop cache — `RodsWithSliderWaggler = MatchRods` / `IsRodWithSliderWaggler` are new here and used solely by `IsTackleAllowedOnRod` (-> `DeriveCompatibleRodTypes` -> `TackleCompatibilityCache`). On the server the rig-assembly path is broader (Float template uses broad `bobbers`), and `AssembleRodHint` suggests the whole `ItemTypes.Bobber` for float rods. Initial concern: the shop would hide a slider/waggler for a Telescopic rod that the game actually lets you equip.

**Investigation:** Grepped server usages of `IsRodWithSliderWaggler`/`RodsWithSliderWaggler` (shop-only). Both server `IsRodWithBobber` call sites are LeaderLength semantics, not equip gates. code-reviewer agent corroborated the server-side divergence. Then investigated the CLIENT (`Win64_CodeBranch`) via Explore agent: equip gate is `DropMeDollTackle`/`DropMeDollReel.TransferItem()` -> `InventoryHelper.IsBlocked2Equip()` -> `ListOfCompatibility.GetCompatibilityEquipment(rodType)`, a hardcoded per-rod allow-list. `MatchRod -> {Bobber, Slider, Waggler}`, `TelescopicRod -> {Bobber}` only; cast/spin reel rows match server `CastReels`/`SpinReels`. The new server symbols do NOT exist in the client — it uses its own hardcoded list. User empirically confirmed: equipping a slider on a non-Match rod is blocked in the running client.

**Resolution:** Accepted. The slider->Match (and spin/cast) rule IS enforced client-side at equip time via `ListOfCompatibility`. The shop fix brings the server catalog into line with actual game behavior — it does NOT introduce a divergence (the hidden combo is genuinely non-equippable). No JIRA clarification needed. Residual Info note: compatibility is now encoded in three independent places (server shop templates+overlay, client hardcoded `ListOfCompatibility`, server `AssembleRodHint`); they must be kept in sync by hand — pre-existing architecture, not a defect of this work.

**Discovered by:** skill recon; resolved via code-reviewer + Explore agents + user client test.

### F-2: `IsTackleAllowedOnRod` is public static without a null guard on `item` [Info]

**Description:** New `public static` method dereferences `item.ItemType`/`item.ItemSubType` without a null check. Only caller is `DeriveCompatibleRodTypes`, which null-checks first, so no current exposure.

**Resolution:** Skipped — too minor; note only.

**Discovered by:** code-reviewer agent.

## Verdict

**Approve.** The slider/waggler->Match narrowing and the refactor into the unified `IsTackleAllowedOnRod` overlay are correct: plain Bobber -> {Telescopic, Match}, Slider/Waggler -> {Match}; the overlay only narrows (uncovered tackle returns true) and is paired with the structural `Templates.Compatible` check. 41 tests pass. F-1 investigated and resolved: the client enforces slider->Match (and spin/cast) at equip time via its own hardcoded `ListOfCompatibility`, so the shop fix matches actual game behavior rather than diverging from it. Residual is only an Info note about the duplicated compatibility source-of-truth (pre-existing).

## Investigation Journal

- Phase 1 intake: commit and branch from JIRA comment (author Yuriy Burda); Executor field (`customfield_11224`) empty in JIRA.
- This commit also refactors the reel->rod direction (FP-44470): r16186's inline filter replaced by the unified `IsTackleAllowedOnRod` overlay over `Templates.Compatible(item)`. Reel test expectations unchanged and still pass.
- Verified `SliderWagglers = {Slider, Waggler}`, `RodsWithSliderWaggler = MatchRods = {MatchRod}`, `FloatRods = {Telescopic, Match}` in `Inventory_Groups.cs`. Slider -> Float template (broad `bobbers`) -> {Telescopic, Match} -> overlay drops Telescopic -> {Match}. Matches tests.
- Hypothesis "slider->Match has equip parity like the reel rule" -> disproven: `RodsWithSliderWaggler`/`IsRodWithSliderWaggler` are shop-only; `AssembleRodHint` bobber slot uses the whole `ItemTypes.Bobber`. Became F-1.
- Consumer check: `TackleCompatibilityCache` stores only `CompatibleRodTypes`/`CompatibleReelTypes` — there is no rod->bobber direction, so no symmetric missing-direction bug.
- Branch-copy: NPN forked at MFT:16130; r16187 later -> explicit merge r16189 required and done.
- code-reviewer agent (deep delegation) confirmed correctness; corroborated F-1, added F-2 (null guard).
- Client investigation (Explore agent on `Win64_CodeBranch` + user empirical test): equip gate `ListOfCompatibility.GetCompatibilityEquipment` enforces slider->Match and spin/cast via a hardcoded per-rod allow-list, independent of the new server symbols. Resolves F-1 to Accepted — shop now matches client equip behavior; no divergence.
