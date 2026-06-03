# equipment-rules -- log

## 2026-05-18 [MFT r16102] FP-43502 -- MonoLeader admitted to SpinLeaders

`SpinLeaders` group extended with `MonoLeader`. The nine templates that gate on `spinLeaders` (`Float`, `Jig`, `Lure`, `FlippingRig`, `SpinnerTails`, `SpinnerbaitTails`, `OffsetJig`, `LivebaitTrollingRig`, `TrollingSkirtRig`) now accept `MonoLeader` for the six rods called out by the FTUE task (Telescope, Match, Spinning, Casting, SW Spinning, SW Casting).

**Lesson:** the audit principle "wherever `FlurLeader` + `TitaniumLeader` are listed for a rod, `MonoLeader` should be there too" was load-bearing for sweeping both server and client. It caught the client `ListOfCompatibility.cs` drift that the ObjectModel mirror alone did not cover.

## 2026-05-18 Finding -- ListOfCompatibility is a parallel compatibility source

Client `Assets/Scripts/UI/2D/Inventory/TackleBehaviors/ListOfCompatibility.cs` (in `Win64_CodeBranch`) is a static `Dictionary<rodSubType, List<compatibleItemSubTypes>>` used by inventory filter / shop / FTUE next-slot highlight. It is **not** driven by `SpinLeaders` / `RodTemplates` and has its own hand-maintained list per rod entry. Bottom-family rod entries already listed `MonoLeader`; spin / cast / float entries did not -- this drift was invisible from the server side. Any group / template change that affects player-visible compatibility must also touch this file.

## 2026-05-18 Finding -- ManyTimeLeaders is a material-property axis, not a compatibility axis

`Inventory.SubTypes.ManyTimeLeaders` lists leaders that survive a fish fight (reusable). `MonoLeader` and `CarpLeader` are deliberately absent -- they belong to `CuttableLeaders` (single-use, cut on landing). When auditing leader-group memberships against the "FlurLeader+TitaniumLeader present" heuristic, exempt `ManyTimeLeaders`. Same axis split surfaces in `LeaderBreaker.cs` (`IsMonoLeader` triggers a separate `monoBreakRate`).

## 2026-05-18 Finding -- AssembleRodCondition / AssembleRodHint use a narrower rod set than templates

`AssembleRodCondition.cs` and `AssembleRodHint.cs` propose a leader to the player only when the rod is in `RodsWithLeader = U(CarpRods, FreshwaterBottomAndFeederRods, SaltwaterBottomCastRods, SaltwaterBottomSpinRods)` -- which excludes Float / Spinning / Casting rods even though the equip-rule templates already accept leaders on those rods (optional slot). The FTUE next-slot highlight (FP-43493) is the surface that compensates client-side. If a future task wants missions to teach `MonoLeader` placement on Float / Spin / Cast, `RodsWithLeader` will need extension -- separate concern from equipment rules.

## 2026-06-03 Finding -- `IT.X == IST.X` numeric collision combined with OR-merge category matching

In `InventoryEnums.cs` the parent `ItemTypes.X` and the "default" `ItemSubTypes.X` literals share the same numeric value for several pairs: `Sinker = 8`, `Hook = 6`, `Bobber = 7`, `Bait = 10`, `Lure = 11`, `Leader = 66`, and others. The mission-hint matcher (`AssembleRodHint.CheckRodComponent` lines 613, 615 and `MissionInventoryContext.HasItemOfTypeAtCurrentLocation:68`) compares the supplied category ID against **both** axes with OR semantics: `item.ItemSubType == id || item.ItemType == id`. The combination means a hint that targets the parent type ID highlights every subtype under it -- the "default" subtype cannot be addressed in isolation through a single integer. Surfaced by FP-43981 (tutorial *Feeder Carp Fishing* sinker highlight). Follow-up split into [FP-44228](https://fishingplanet.atlassian.net/browse/FP-44228) (server: introduce a distinct `IST.CommonSinker` literal and migrate the affected items), [FP-44229](https://fishingplanet.atlassian.net/browse/FP-44229) (client audit), [FP-44230](https://fishingplanet.atlassian.net/browse/FP-44230) (GD revert of the temporary item-ID mitigation). The same pattern very likely needs cleanup for the other collision pairs -- broader audit deferred as a separate epic candidate; tracked from the FP-43981 task backlog.
