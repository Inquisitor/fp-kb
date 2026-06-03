---
jira: FP-43981
status: completed
executor: Stanislav
branch: MFT
related: FP-44228 (server), FP-44229 (client), FP-44230 (GD follow-up)
---

## Status

Investigation complete and closed. Three tech-debt follow-up stories posted under FP-32325 — FP-44228 (server data-model fix + DB migration + hint filter switch), FP-44229 (client audit of `ItemSubTypes.Sinker` usages), FP-44230 (GD revert of the temporary item-ID mitigation). All Scrum Team = FTUE; FP-44229 and FP-44230 are `is blocked by` FP-44228, all three `Relates to` FP-43981. Finding about the `IT.X == IST.X` numeric-collision pattern + OR-merge category matcher recorded in `equipment-rules/log.md`. Navigation comment posted on FP-43981 linking the trio. The GD-applied item-ID list stays in place on the tutorial mission until the trio lands; QA-side closure of FP-43981 belongs to the QA team.

## Summary

**Bug.** In tutorial *Feeder Carp Fishing*, when the player is asked to equip a sinker on the feeder rod, the inventory hint highlights every sinker variant in the player's bag — including saltwater bottom, spinning, drop, and head-starter — instead of only freshwater bottom.

**Root cause (server).** Two layers stack:

1. **Numeric-collision in the inventory data model.** `Shared/ObjectModel/Inventory/InventoryEnums.cs` defines both `ItemTypes.Sinker = 8` (the parent type) and `ItemSubTypes.Sinker = 8` (the "freshwater bottom" default subtype) with the same integer value. The DB table `dbo.InventoryCategories` mirrors this — `CategoryId = 8` is the parent row "Sinkers" and simultaneously the home of the 22 freshwater bottom items, while the four sibling subtypes own their own child rows (144 Bullet, 147 Drop, 183 Saltwater, 186 Head Starter).
2. **OR-merge category matcher.** The mission-hint engine compares each passed category ID against **both** axes of the item with `OR` semantics:
   - `Shared/ObjectModel/Hint/Hints/AssembleRodHint.cs` (`CheckRodComponent`, lines 613, 615) — `wrongCategoryId` flag.
   - `Shared/ObjectModel/Mission/Inventory/MissionInventoryContext.cs:68` (`HasItemOfTypeAtCurrentLocation`) — candidate lookup.
   Both check `(int)item.ItemSubType == typeId || (int)item.ItemType == typeId`.

The hint for a bottom rod sends `Inventory.Types.Sinkers.ToInt32Array() = [8]` at `AssembleRodHint.cs:909`. Combined with the OR-merge, any item with `ItemType == 8` is matched — every sinker.

**Mitigation (immediate, GD-owned).** Mission condition for the tutorial swapped from a category filter (`SinkerCategoryId = (int)IST.Sinker`) to an explicit list of the 22 starter freshwater sinker item IDs. Brittle but acceptable for a known-set tutorial.

**Tech-debt path (drafted).**

- *Server story* — reserve a fresh `ItemSubTypes` literal (e.g. `CommonSinker`) on a new free ID; add `InventoryCategories` child row under parent 8 via existing proc `dbo.CreateItemCategory` (created in patch `CLZ.M.2023.04.19-029`); migrate the 22 items' `ItemSubType` (and `CategoryId`) to the new value; update `Inventory_Groups.cs`; switch `AssembleRodHint` sinker branch to the new subtype-group filter; mirror enum + groups to `Win64_CodeBranch/Assets/Photon Server Networking/ObjectModel/Inventory/`; update `ListOfCompatibility` UI dict entries on the client where freshwater bottom rod entries currently list the legacy subtype; audit `Inventory_Static.cs` / `Inventory_Does.cs`; update unit tests under `Shared/ObjectModel.Tests/`.
- *Client story* — audit usages of `ItemSubTypes.Sinker` across `Assets/Scripts/` (8 files initially identified — UI hints / highlights / shop filters / rod previews / HUD); switch to the new subtype where freshwater-bottom semantics intended.
- *GD follow-up story* — once the server + client stories land, revert the tutorial mission condition from explicit IDs back to a category filter targeting the new subtype.

The legacy `ItemSubTypes.Sinker = 8` literal is kept for backward compat — after migration no items use it, but historical mission conditions may still rely on the OR-merge "any sinker" behavior through that value.

**Broader observation (out of scope here).** The same numeric-collision pattern exists for other parent/subtype pairs: `Hook = 6`, `Bobber = 7`, `Bait = 10`, `Lure = 11`, `Leader = 66`. Each pair would carry the same hint-disambiguation risk. Candidate for a separate epic that audits the whole `IT == IST` collision set.

## Plan

JIRA ticket drafts: see [artifacts/jira-drafts.md](artifacts/jira-drafts.md).
Open decisions and posting checklist: see [backlog.md](backlog.md).

## Milestones

- 2026-06-01: Investigation completed. Root cause confirmed at both code (`AssembleRodHint.cs`, `MissionInventoryContext.cs`) and data (`dbo.InventoryCategories`) layers. Tech-debt scope split into server / client / GD stories. Drafts prepared for review under `artifacts/jira-drafts.md`; awaiting approval before posting to FP-32325 epic.
- 2026-06-03: Three follow-up stories posted under FP-32325 — [FP-44228](https://fishingplanet.atlassian.net/browse/FP-44228) (server), [FP-44229](https://fishingplanet.atlassian.net/browse/FP-44229) (client), [FP-44230](https://fishingplanet.atlassian.net/browse/FP-44230) (GD revert). Links applied: each `Relates` to FP-43981; `FP-44229` and `FP-44230` `is blocked by` FP-44228. Scrum Team = FTUE on all three.
- 2026-06-03: Finding about the `IT.X == IST.X` numeric collision + OR-merge category matcher recorded in [`equipment-rules/log.md`](../../server/modules/equipment-rules/log.md) ahead of close (context fresh). Navigation [comment](https://fishingplanet.atlassian.net/browse/FP-43981?focusedId=122893) posted on FP-43981 linking the trio.
