# Decision log - product-contents

Append-only. Decisions with rationale, and findings marked as such.

## 2026-09-16 [MFT r16546] Fold rod-setup entries into the standalone stack, display path only (FP-46200)

The product information window renders the catalog `Params` of an item for every entry it receives and
discards the per-entry quantity the payload already carries, so an item a pack ships both mounted and
standalone is listed twice at the full standalone quantity. The defect is in the client
(`ProductInfoWindow.BuildItems`, added under FP-42797); the server data and the wire are correct.

Decided: correct it in the display projection on the branch whose client cannot be fixed, and nowhere
else. Alternatives rejected - editing the catalog `Params` is impossible by construction, since one
`ItemId` yields one string and the same item must show two quantities inside one product; routing the
pack to the older window keys off `TypeId`, which also drives delivery and analytics; a separate catalog
item for the mounted variant would duplicate items catalog-wide and put stacking and `ItemId`-keyed
mission and achievement conditions at risk.

Folding rather than dropping the mounted entry, because `Count` is read by the older product window and
by the promo screens; dropping would take the mounted piece off those. Only `Count` is summed - see
[quantities.md](quantities.md).

The fold keys on a **stack**: it needs a standalone entry whose `Count` is above 1 to absorb the mounted
piece. Where a pack ships single pieces the row itself is the only quantity the window shows, so folding
would hide a delivered item. An earlier form of the rule keyed on the first standalone entry instead,
which made the outcome depend on the order entries happen to be authored in.

Lesson: the eligibility test and the fold target were first written as separate copies of the same
condition, free to drift; a mutation dropping the mounted guard from one of them made a mounted stack
vanish from the window entirely. They now share the predicate `IsStandaloneStack`.

## 2026-09-16 Finding: the printed quantity and the delivered one are separate fields

`ConfigJson.Count` is what delivery hands over; `ConfigJson.ParamsLength` is the string the window
renders through `InventoryParamProducer`. Nothing keeps them in step but the author. They agree for
every line in the catalog today. Recorded because the shape invites a silent divergence that no code
would catch.
