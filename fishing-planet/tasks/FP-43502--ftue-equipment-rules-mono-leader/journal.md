---
jira: FP-43502
status: completed
executor: Stanislav
branch: MFT
related: FP-43493, FP-42964
---

## Status
Committed and posted to JIRA with @Kyrylo Rovnyi mention for client-side merge. Manual smoke passed on Telescope / Match / Spinning / Casting. Findings migrated to the new equipment-rules module.

## Summary
FTUE epic FP-42964 includes a usability change: a starter `MonoLeader` should be equippable on `Telescope`, `Match`, `Spinning`, `Casting`, `SW Spinning`, `SW Casting` rods. Server-side this is gated by `RodTemplates` -- rig templates that take a `spinLeaders` restriction (built from the `SpinLeaders` subtype group) drive every one of the six rods listed in the task. `MonoLeader` previously sat in `BottomLeaders` only, so it was accepted on bottom / feeder / saltwater-bottom rigs but rejected on the float / spinning / casting templates.

## Implementation

### Server (MFT)

`Shared/ObjectModel/Inventory/Inventory_Groups.cs` -- `MonoLeader` added to `SpinLeaders` group:

```csharp
public static readonly IST[] SpinLeaders = { MonoLeader, FlurLeader, TitaniumLeader, SaltwaterFluoroLeader, SaltwaterTitaniumLeader };
```

Effect: the nine templates that use the `spinLeaders` restriction (Float, Jig, Lure, FlippingRig, SpinnerTails, SpinnerbaitTails, OffsetJig, LivebaitTrollingRig, TrollingSkirtRig) accept `MonoLeader` on top of the existing four leader subtypes. The six rod subtypes from the task are the union of `FloatRods` (Telescope, Match) and `SpinningAndCastingRods` (Spinning, Casting, SW Spinning, SW Casting) -- exactly what those nine templates host.

### Server tests (MFT)

`Shared/ObjectModel.Tests/RodTemplatesTests.cs`:

- Updated `blockLeader.CanMove(...)` expectations in 10 scenarios to include `monoLeader`:
  `Test_Compatibility_TelescopicRod`, `Test_Compatibility_MatchRod`, `Test_Compatibility_JigHeadAndSoftBait`, `Test_Compatibility_JigHeadAndSoftBait_Saltwater`, `Test_Compatibility_FlippingRig`, `Test_Compatibility_Spoon`, `Test_Compatibility_SpinnerAndTail`, `Test_Compatibility_SpinnerbaitBuzzbaitAndSoftBaitTail`, `Test_Compatibility_LivebaitTrollingRig`, `Test_Compatibility_TrollingSkirtRig`. The implicit `_CantMove = Existing.Except(_CanMove)` machinery in `Block.CanMove()` keeps the negative assertion for other leaders (carpLeader) intact -- so the deny-side coverage is preserved without spelling it out.
- Added `Test_Compatibility_JigHeadAndSoftBait_SaltwaterSpinningRod_MonoLeader` -- direct regression for the task. Uses `rod.ItemSubType = IST.SaltwaterSpinningRod` and `.Move(monoLeader)` so the assembled rig actually equips a `MonoLeader` on a SW Spinning rod and asserts `RodTemplate.Jig`. Existing tests use `SpinningRod` (freshwater) for the Jig/Lure scenarios and were not picking up the SW path explicitly, so this test makes the SW coverage self-documenting.
- Rig-only tests (`Test_Compatibility_CarolinaRig`, `Test_Compatibility_TexasRig`, `Test_Compatibility_ThreeWayRig`) intentionally left untouched: they do not invoke `blockLeader.CanMove(...)`, so there is no implicit assertion either for or against `MonoLeader`. The rig templates take `carolinaRigs`/`texasRigs`/`threewayRigs` restrictions (rig-only leaders), not `spinLeaders`, so `MonoLeader` cannot match those templates regardless of this change.

### Client mirror (Win64_CodeBranch)

`Assets/Photon Server Networking/ObjectModel/Inventory/Inventory_Groups.cs` -- identical `SpinLeaders` edit, keeps the source-duplicated ObjectModel symmetric (see [`<kb>/reference/photon_interfaces_dll_distribution.md`](../../../reference/photon_interfaces_dll_distribution.md)).

### Client UI dictionary (Win64_CodeBranch)

`Assets/Scripts/UI/2D/Inventory/TackleBehaviors/ListOfCompatibility.cs` -- separate, client-only static `Dictionary<rodSubType, List<compatibleSubTypes>>` that declares which items the UI filter / shop / FTUE highlight should treat as compatible with each rod. It is independent from `SpinLeaders` / `RodTemplates` and has to be kept in sync manually.

Added `ItemSubTypes.MonoLeader` to the leader portion of six rod entries: `TelescopicRod`, `MatchRod`, `SpinningRod`, `CastingRod`, `SaltwaterSpinningRod`, `SaltwaterCastingRod`. Bottom-family rod entries already listed `MonoLeader` and were untouched. Without this edit the server would allow the equip but the client UI would not surface `MonoLeader` as compatible for these rods -- found in deep review.

Side-effect: the file had mixed line endings (some lines LF, most CRLF); the edit normalised the entire file to CRLF, matching `.editorconfig`. Diff therefore looks larger than the six semantic changes.

## Out of scope (verified)
- `RodsWithLeader` (used by `AssembleRodCondition.cs:710` / `AssembleRodHint.cs:941`) -- pre-existing list that excludes Float / Spinning / Casting rods. Mission/hint UX for these rods does not propose a leader; this is the state before FP-43502 and is not part of "equipment rules" work. The client FTUE highlight (FP-43493) covers the UX side.
- `SaltwaterMonoLeader` -- does not exist as a subtype; the task literally asks for the existing `MonoLeader` (freshwater) on saltwater spin/cast rods. Treated as intentional FTUE simplification.
- `ManyTimeLeaders` group -- `MonoLeader` deliberately absent there (mono is single-use / cuttable, see `CuttableLeaders`); this is a material-property axis, not a rod-compatibility axis. Not extended.
- `LeaderBreaker.cs:125` -- already special-cases `IsMonoLeader()` for break rate; physics carry over to the new rod combinations automatically.
- `Rod.cs:190` (HeadStarterSinker + Reel/Line/SpinLeader aggregation rule) -- naturally extends to include `MonoLeader`; consistent with `LivebaitTrollingRig` template combining `headStarterSinker` + `spinLeaders`.

## Deep-review notes
- The audit principle "wherever FlurLeader+TitaniumLeader are listed for a rod, MonoLeader should be there too" was used to sweep both repos. All server compatibility groups (`Leaders`, `SpinLeaders`, `BottomLeaders`) satisfy it after the edit. `ManyTimeLeaders` is intentionally exempt (different axis -- see Out of scope).
- The client `ListOfCompatibility.cs` was the only drift point against that principle and was the load-bearing finding of the review.
- `DollHighlightHint.cs:185`, `HintSystem.cs:772,942` -- match `MonoLeader` by subtype identity (not group membership), already aware of it. No change needed.
- Shop / inventory filters (`MonoLeadersFilter`, `LeaderFilter`, `LineAndLeadersFilter`) -- categorisation filters, not rod-compatibility gates. No change needed.

## Milestones
- 2026-05-18: KB-task created; plan agreed (minimal scope -- extend `SpinLeaders` only; freshwater `MonoLeader` on SW spin/cast left as the task literally asks).
- 2026-05-18: Server edit applied; `RodTemplatesTests` updated for the 10 affected scenarios; SW Spinning regression test added. Build + tests green locally.
- 2026-05-18: Client mirror applied. Deep code review surfaced `ListOfCompatibility.cs` UI dictionary as a parallel client-only compatibility source; six rod entries updated. File EOL normalised to CRLF as a side effect.
- 2026-05-20: Manual smoke on Telescope / Match / Spinning / Casting rods -- MonoLeader equips and the UI compatibility list now shows it.
- 2026-05-20: Server committed at [MFT r16102]; client committed at [Win64_CodeBranch r54342].
- 2026-05-20: JIRA note posted ([comment 120516](https://fishingplanet.atlassian.net/browse/FP-43502?focusedId=120516&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-120516)) with @Kyrylo Rovnyi mention; awaiting client-lead review and merge.
- 2026-05-20: KB reference [`jira_comment_formats.md`](../../../reference/jira_comment_formats.md) restructured for server / client symmetry (URL segments and branch labels now declared in a Repos table; client URL `#CLN` codified). KB module created at [`server/modules/equipment-rules/`](../../server/modules/equipment-rules/_card.md) with card / log / backlog; findings surfaced during this task migrated there. FP-43424 backlog updated with the ad-hoc module-candidate observation.
