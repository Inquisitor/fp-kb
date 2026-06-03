# JIRA ticket drafts — FP-43981 follow-up

Common fields for all three:
- Project: FP
- Issue type: **Story**
- Epic / parent: **FP-32325** (FTUE - Optimization and Rework)
- Scrum Team: **FTUE** (`customfield_11001 = 10636`)
- Link → FP-43981: **Relates**

---

## Draft 1 — Server

**Title:** `FTUE. Missions: Server - Introduce distinct subtype for freshwater bottom sinker`

**Description:**

> **Background**
>
> Bug FP-43981 surfaced a long-standing structural conflation in the inventory data model: `ItemTypes.Sinker` (parent type) and `ItemSubTypes.Sinker` (the "freshwater bottom" subtype) share the same numeric value. The mission-hint matcher (`AssembleRodHint.CheckRodComponent` + `MissionInventoryContext.HasItemOfTypeAtCurrentLocation`) compares each category ID against both `item.ItemType` and `item.ItemSubType` with OR semantics — so when the assemble-rod hint targets the parent type ID, the highlight cannot distinguish the "common bottom" subtype from its siblings (Spinning / Drop / Saltwater / HeadStarter). For the tutorial mission *Feeder Carp Fishing* the immediate user-visible bug was already mitigated at the data level by GD (mission condition switched to explicit item IDs); this story addresses the underlying data-model gap so future missions can target the "common bottom sinker" by category, and the GD-side workaround can be reverted.
>
> **Scope**
>
> - Reserve a fresh `ItemSubTypes` enum literal (e.g. `CommonSinker`) in `Shared/ObjectModel/Inventory/InventoryEnums.cs`. Pick the next free ID at implementation time.
> - Adjust subtype groups in `Inventory_Groups.cs` so the new split is reflected (e.g. `CommonSinkers`, updated `BottomSinkers`). Update related extension methods if their semantics change.
> - SQL patch (`Main` DB, idempotent): add a new `InventoryCategories` row under parent 8 via the existing `dbo.CreateItemCategory` proc; migrate the affected `InventoryItems` to the new subtype; update `InventorySortingGroups` so the new subtype lands under the Terminal Tackle UI group.
> - Switch the sinker branch in `AssembleRodHint` from the parent-type filter to the new subtype-group filter.
> - Mirror enum + groups to `Win64_CodeBranch/Assets/Photon Server Networking/ObjectModel/Inventory/`. Update the `ListOfCompatibility` UI dictionary on the client wherever it currently lists the legacy subtype for freshwater bottom rod entries.
> - Audit `Inventory_Static.cs` (`basicTerminalTackleConstraint`) and `Inventory_Does.cs` (lurebox / hat tackle-kit counters) and decide per-call whether to migrate to the new subtype.
> - Update affected unit tests under `Shared/ObjectModel.Tests/` (sinker construction).
> - Keep the legacy `ItemSubTypes.Sinker = 8` literal for backward compat — after migration no items use it, but historical mission conditions may rely on the OR-merge "any sinker" behavior via that value.
>
> **Out of scope**
>
> - The same numeric-collision pattern likely exists for other parent/subtype pairs (Hook, Bobber, Bait, Lure, Leader, …). Worth assessing as a separate epic.
> - Client-side audit beyond the source-duplicated ObjectModel mirror and `ListOfCompatibility` — owned by the sibling client story.
> - Reverting the tutorial mission condition from item IDs back to the new category — owned by GD follow-up.
>
> **Acceptance**
>
> - New subtype exists in server + client mirrored enums.
> - Migration patch is idempotent and applied to QA cleanly.
> - With the category condition restored on the tutorial mission, only freshwater bottom sinkers are highlighted — not saltwater / spinning / drop / head-starter variants.
> - Unit tests green.

---

## Draft 2 — Client

**Title:** `FTUE. Missions: Client - Adopt new freshwater bottom sinker subtype`

**Description:**

> **Background**
>
> Bug FP-43981 (tutorial mission *Feeder Carp Fishing*) surfaced a data-model conflation where the "common bottom sinker" subtype shared its numeric value with the parent type `ItemTypes.Sinker`. Server side is introducing a distinct `ItemSubTypes.CommonSinker` to separate them. The mirrored enum + group definitions will land in `Win64_CodeBranch/Assets/Photon Server Networking/ObjectModel/Inventory/` together with the server change, alongside an update of `ListOfCompatibility` for freshwater bottom rod entries.
>
> **Scope**
>
> Audit how `ItemSubTypes.Sinker` is used across the client code outside the mirrored ObjectModel folder. Wherever the call site semantically means "freshwater bottom sinker" — UI hints, highlights, shop filters, rod-assembly previews, etc. — switch to `ItemSubTypes.CommonSinker` and adjust behavior accordingly. Where the call site genuinely means "any sinker by type", leave it; the legacy literal is being retained for backward compat.
>
> **Why**
>
> After the data migration, items previously typed as freshwater bottom sinkers will carry `ItemSubType = CommonSinker`. Any client code that special-cases the legacy subtype literal with freshwater-bottom intent will silently miss those items until updated.
>
> **Acceptance**
>
> - Identified call sites updated.
> - Tutorial mission *Feeder Carp Fishing* highlight, inventory compatibility surfaces, and shop filters behave correctly with the new subtype.

---

## Draft 3 — GD follow-up

**Title:** `FTUE. Missions: GD - Restore category-based sinker condition in Feeder Carp Fishing tutorial`

**Description:**

> **Background**
>
> Bug FP-43981 was mitigated by replacing the sinker mission condition in *Feeder Carp Fishing* with an explicit list of starter sinker item IDs. Once the server and client tech-debt stories land (new `CommonSinker` subtype + category), switch the condition back to category-based filtering so the highlight scales naturally as new starter sinkers are added — without per-mission edits.
>
> **Scope**
>
> - Switch the *Feeder Carp Fishing* sinker condition from item IDs to a category condition targeting the new `CommonSinker` subtype.
> - Sanity-check the tutorial flow.
