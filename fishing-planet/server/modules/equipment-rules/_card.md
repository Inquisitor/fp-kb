---
name: equipment-rules
system: inventory
code_paths:
  - Shared/ObjectModel/Inventory/
  - Shared/ObjectModel/Inventory/TerminalTackle/
---

# equipment-rules

Composition rules for what tackle items can be equipped on which rods, and what valid rig configurations exist. Two-layer: a server-side declarative template catalog (source of truth) and a parallel client-side UI compatibility dictionary that must be hand-synced. Runtime validation lives in `CanMove` / `CanEquipSetup`.

## Entry Points

| Class / file                             | Path                                                                                  | Role                                                                                                                                                                                                  |
|------------------------------------------|---------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Inventory.Types` / `Inventory.SubTypes` | `Shared/ObjectModel/Inventory/Inventory_Groups.cs`                                    | Static subtype groups (`SpinLeaders`, `BottomLeaders`, `FloatRods`, `SpinningAndCastingRods`, ...). Each group is just an `IST[]` used by template restrictions.                                      |
| `RodTemplates`                           | `Shared/ObjectModel/Inventory/TerminalTackle/RodTemplates.cs`                         | Declarative `Templates[]` catalog of valid rig setups (`Float`, `Jig`, `Lure`, `Bottom`, `CarolinaRig`, ...). Drives `MatchedTemplate` / `MatchedTemplatePartial`.                                    |
| `Inventory.CanMove` / `CanEquipSetup`    | `Shared/ObjectModel/Inventory/Inventory_Can.cs`                                       | Runtime "is this move allowed" check. Calls template matcher, then layered constraints (Doll / Hands / Equipment / Shore).                                                                            |
| `Rod.CanAggregate`                       | `Shared/ObjectModel/Inventory/Main/Rod.cs`                                            | Per-rod aggregation guard (e.g. `HeadStarterSinker` rule at L190 — sinker allowed only when rod children are reel/line/SpinLeader).                                                                   |
| `ListOfCompatibility` (client)           | `Assets/Scripts/UI/2D/Inventory/TackleBehaviors/ListOfCompatibility.cs` (client repo) | **Parallel client-only** static `Dictionary<rodSubType, List<itemSubTypes>>` used by inventory filter / shop / FTUE highlight. Independent from `SpinLeaders` / `RodTemplates` — must be hand-synced. |

## Key Types

| Type                    | Role                                                                                                                                                                                                                                                                                                                                                           |
|-------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `RodTemplate` (enum)    | Rig setup kinds: `Float`, `Jig`, `Lure`, `Bottom`, `ClassicCarp`, `MethodCarp`, `PVACarp`, `Spod`, `FlippingRig`, `SpinnerTails`, `SpinnerbaitTails`, `CarolinaRig`, `TexasRig`, `ThreewayRig`, `OffsetJig`, `SquidChain`, `SaltwaterBottomCast`, `SaltwaterBottomSpin`, `LivebaitTrollingRig`, `TrollingSkirtRig`, `TorchRig`, `ElectricSaltwaterBottomCast`. |
| `RodTemplateDesc`       | One row in the catalog: `(template, rodTypes[], restrictions[], isPartial)`.                                                                                                                                                                                                                                                                                   |
| `ItemRestriction` (`R`) | Single slot constraint: `(itemTypes[], optional itemSubTypes[], optional predicate)`. Restrictions are reused as named statics (`spinLeaders`, `bottomLeaders`, `commonHooks`, ...).                                                                                                                                                                           |
| Subtype groups          | Named `IST[]` arrays in `Inventory.SubTypes` -- compatibility axes for templates: rod families (`FloatRods`, `SpinningAndCastingRods`, `CarpRods`, ...), leader families (`SpinLeaders`, `BottomLeaders`, `CarpLeaders`, rig leaders), hook families, etc.                                                                                                     |

## Dependencies

- → `ObjectModel` core (`InventoryItem`, `Rod`, `Leader`, `Reel`, `Line`, ...)
- → `bite-system` / `RodInGameConfig` consume the matched `RodTemplate` to drive bite logic
- ← `wear` -- `LeaderBreaker.cs` uses `IsMonoLeader()` for break-rate physics (subtype identity, not template membership)
- ← `missions` / `Hint` -- `AssembleRodCondition.cs` / `AssembleRodHint.cs` read `RodsWithLeader` / `BottomLeaders` to propose items in FTUE assemble-rod missions. Note: `RodsWithLeader` is currently narrower than the template catalog (excludes float / spin / cast rods even though templates accept leaders there).
- ~ `ObjectModel/Inventory/` is **source-duplicated** to the client (see [`<kb>/reference/photon_interfaces_dll_distribution.md`](../../../reference/photon_interfaces_dll_distribution.md)). Group / restriction edits must be mirrored.
- ~ Client `ListOfCompatibility.cs` is a **parallel compatibility source** for UI -- not driven by `SpinLeaders`, must be hand-synced. Drift between the two is invisible to the server.

## Deep Dives

(none yet -- candidates queued in `backlog.md`)

## Related Tasks

- FP-43502 (2026-05) -- Extended `SpinLeaders` to include `MonoLeader`; mirrored on client; updated `ListOfCompatibility` entries for six rods covered by the task. See `tasks/FP-43502--ftue-equipment-rules-mono-leader/journal.md`.
- FP-43981 (2026-06) -- Investigation of the *Feeder Carp Fishing* tutorial sinker highlight surfaced the `IT.X == IST.X` numeric collision combined with the OR-merge category matcher in `AssembleRodHint` / `MissionInventoryContext`. GD applied a temporary item-ID mitigation on the mission; tech-debt split into follow-up stories [FP-44228](https://fishingplanet.atlassian.net/browse/FP-44228) (server), [FP-44229](https://fishingplanet.atlassian.net/browse/FP-44229) (client), [FP-44230](https://fishingplanet.atlassian.net/browse/FP-44230) (GD revert). See `tasks/FP-43981--ftue-sinker-subtype/journal.md` and `log.md` Finding 2026-06-03.
