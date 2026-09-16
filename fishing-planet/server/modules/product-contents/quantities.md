# Quantities in a product's contents

What the quantity fields of a `ProductInventoryItem` mean, why the number a shop window prints is
not the number a purchase grants, and which comparisons between them are traps.

## The two paths never meet

Both start from `Products.ItemJson` and share nothing else:

- **display** - `GameClientPeer_Monetization.FromDto` -> `StoreProduct.Items`, an array of
  `ProductInventoryItemBrief`
- **delivery** - `MonetizationHelper.FromDto` -> `BuildInventoryItems` -> `ProfileProduct.Items`, an array
  of `InventoryItem`

A change to the display projection cannot alter what a player receives. The reverse holds too: a display
defect is invisible in the inventory, which is why one survived unnoticed until QA read the window.

## Count, Length, Amount

`Count` is the only additive field, and its unit depends on the item:

- for a **line**, metres. `Line.Count` is documented as "length of line in pack when bought", and
  `Line.Init()` copies it into `Length` on delivery
- for everything else, pieces

`Length` is **not** additive and is close to dead:

- for a line it mirrors `Count`, and delivery overwrites it in `Init()` anyway
- for a **leader** it is the length of one piece, while `Count` counts pieces. Summing it would claim a
  two-metre leader
- no consumer reads the value. The client reads only `Length.HasValue`, as the flag deciding whether to
  print a `(xN)` suffix - so turning a null into a zero silently removes counts from the welcome list and
  the older product window

`Amount` is a proxy over another field for every `IsStockableByAmount` type - `Length` for `Line`,
`Weight` for `Chum` and `ChumIngredient`, `Capacity` for `BoatFuel` - and no product populates it.

## The printed number comes from the catalog, not from the pack

A window prints `Params`, a string built per item and language by `InventoryParamProducer` and cached by
`ItemCache`. `InventoryItems` has no `Params` column; `VW_AllItems` exposes the rendered result. For a
line it reads `Length: 2500 m; Test: ...`, and the metres in it come from `ConfigJson.ParamsLength`, a
hand-authored string sitting beside the numeric `ConfigJson.Count` that delivery uses. They are kept in
step by hand and currently agree for every line.

One `ItemId` therefore yields exactly one string. An item appearing twice in the same product - mounted
and standalone - cannot render two different quantities from the catalog, which is the whole reason a
server-side correction has to change the entry list rather than the text.

Only lines carry a stack size in `Params` at all. For hooks, leaders, baits and lures it holds
per-piece properties, so a window showing them twice is duplicating a row rather than misquoting a
number.

## Traps when counting this from SQL

Each of these produced a confident figure that pointed at content authors, and none survived a look at
the rows:

- `Params LIKE 'Length: % m'` also matches **rods**, whose `Length` is the physical blank length against
  a `Count` of 1
- the `Length`/`Test`/`Diameter` template is **not** a line detector: leaders render the same template,
  and their counts are pieces. The discriminator that works is structural - a leader carries
  `LeaderLength` in `ConfigJson`, a line does not
- comparing a standalone entry against the catalog nominal ignores the mounted portion, which the nominal
  covers as well; a pack splitting one spool between reel and bag then reads as under-delivering

Reusable queries: `tasks/FP-46200--product-info-template-quantities/artifacts/catalog-recheck.sql`.

## How packs are authored

An item is either stackable or not. A pack ships a stack of a stackable one, and a piece split off a
stack sits mounted on the rod; non-stackable gear ships piece by piece. So a `Count` above 1 reads as
"this entry is a stack" and a `Count` of 1 as "a single piece".

Where the stack sits is the pack author's habit rather than a property of the item: some packs put it in
`Equipment`, some in `Storage`, some mix both within one pack, and `Equipment` is the more common of the
two. `Doll` never holds a stack, and `Hands` and `Rent` do not appear in packs at all.
