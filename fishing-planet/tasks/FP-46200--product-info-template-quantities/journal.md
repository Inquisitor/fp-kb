---
jira: https://fishingplanet.atlassian.net/browse/FP-46200
title: "Stop packs with rod setups promising more than they deliver (MFT stopgap)"
status: completed
executor: Stanislav Samoilov
created: 2026-09-10
type: story
parent: FP-41583
related: FP-46034
---
# FP-46200: Product info window prints the catalog quantity for items that ship mounted in a rod setup

## Status
Delivered. The shop display payload folds a rod-setup entry into the standalone stack of the same item,
so a pack no longer reads as promising more than it gives. Committed to MFT as r16546, ships with the
next server hotfix, and noted on the ticket for QA and feature owners.

The defect itself is a client regression in the product information window (FP-42797): the per-entry
quantities are already on the wire and the window discards them in favour of the catalog text. FP-46034
carries the real fix and stays with the client side; this was a stopgap for the branch that gets no
further client build, and it is deliberately confined there - marked `[!!!MFT ONLY!!!]` in the code, in
the commit subject and in a warning panel on the ticket. Nothing left on the server side.

## Summary
A pack whose content includes an assembled rod setup lists the mounted line, leader, hook, bait and lure
a second time, and both rows carry the full stand-alone quantity. Reported on the Premium Shop product
window and on the advertisement surfaces that open the same window.

The chain, verified step by step:

1. **Product data is correct.** `Products.ItemJson` carries one entry per delivered item. The reported
   Valkyrie Saga Pack holds "Glowing Mono 1.4 mm" twice - `Storage: ParentItem, Count: 100, SetupId: 1`
   (spooled on a rod of the setup) and `Storage: Storage, Count: 2500` (the standalone spool). For a `Line`,
   `Count` is the length in metres, not a piece count.
2. **The wire carries the quantities.** `StoreProduct.Items` is `ProductInventoryItemBrief[]`
   (`ItemId`, `Count`, `Length`, `Amount`), built by `MonetizationHelper.GetItemBriefs` straight from the
   same `ItemJson` and sent by `GameClientPeer_Monetization.FromDto`.
3. **The client throws them away.** `ProductInfoWindow.BuildItems` maps every product entry to the
   *catalog* brief via `CacheLibrary.MapCache.GetInventoryItemBriefById(item.ItemId)` and stores that.
   Neither `Count`, `Length` nor `Amount` of the product entry is read anywhere in the method; the row
   text is `Description = iiBrief.Params`. Selecting a row calls `ItemsCache.GetItems(itemId)`, which is
   the catalog again, so the detail popup repeats the same number.
4. **`Params` is a catalog-level string.** The server composes it per item and language in
   `InventoryParamProducer.ProduceParamsForItem` (cached by `ItemCache`), delivered wholesale by
   `HandleGetItemBriefs`. For the reported line it reads `Length: 2500 m; Test: 139 kg; Diameter: 1.4 mm;
   Color: Vine Red`. One `ItemId` yields exactly one string, so the same item inside the same product
   cannot render two different quantities from the catalog.

Hence both rows print `2500 m` while the player receives a 2500 m spool plus 100 m already spooled.

### Only lines are misquoted; the rest merely duplicate
The wrong *number* appears only where the catalog `Params` embeds a stack size, and across the catalog
that is lines alone:

| Item              | `Params`                                        | Carries a stack size |
|-------------------|-------------------------------------------------|----------------------|
| Glowing Mono 1.4  | `Length: 2500 m; Test: 139 kg; ...`             | yes - the spool      |
| Fluorocarbon Leader 1.2 | `Length: 1 m; Test: 74 kg; ...`           | no - one piece is 1 m |
| Tungsten Hook #7/0 | `Size: #7/0; Type: J-Hook; ...`                | no                   |
| Bone Popper (lure) | `Weight: 14 g; Hook: #2/0; Length: 9 cm`       | no - the lure itself |
| AmperDrive reel   | `Ratio: 7.5; Max Drag: ...`                     | no                   |

For hooks, leaders, baits and lures the window prints no quantity at all, so the defect there is the
repeated row, not a false number. The ticket lists them all together, but their nature differs.

A leader's `Length` being per piece also explains the otherwise odd guard in the old window
(`!piiBrief.Length.HasValue || ItemType == Leader`): leaders carry a `Length` yet count in pieces.

The old window did not have this defect: `PremShopItemInfo.AddInventoryItem` collapses repeated `ItemId`s
and appends `(xN)` from the product entry's `Count`. The new window did not carry that logic over.
`ShopHelper.GetItemsList` (welcome/advertisement list) still uses the product-entry counts as well.
The window is chosen by `TypeId`: pond passes and pond-pass-category containers open the old window, the
rest open the new one.

### Why a stack is the right thing to key on
An item is either stackable or not, and packs ship a stack of a stackable one. A piece split off a stack
sits mounted on the rod; non-stackable gear such as crankbaits ships piece by piece rather than in stacks.
So `Count > 1` reads as "this entry is a stack" and `Count == 1` as "this entry is a single piece", and
the fold needs a stack to absorb the mounted piece without hiding anything. (Model as described by the
server lead, 2026-09-16, and consistent with the catalog: no product mixes single-piece and stacked
standalone rows for the same item.)

### Invariant worth keeping in mind
The shop **display** path and the **delivery** path both read `Products.ItemJson` but are otherwise
independent: display goes `GameClientPeer_Monetization.FromDto` -> `StoreProduct`, delivery goes
`MonetizationHelper.FromDto` -> `BuildInventoryItems` -> `ProfileProduct`. Filtering or collapsing
`StoreProduct.Items` therefore cannot change what a player receives - a property any server-side
mitigation depends on.

Second-order note from the same code: `BuildInventoryItems` assigns `inventoryItem.Length` from the
product entry and then calls `Init()`, and `Line.Init` overwrites `Length = Count`. For lines the entry's
`Length` field is dead weight; `Count` is the authoritative value.

## Data verification (local Main, branch snapshot)
- Valkyrie Saga Pack (product 15927): entries split `Doll` (rods, each with `RodItemIds`), `Equipment`,
  `ParentItem` (items mounted inside the setups), `Storage` (standalone items). Every `ParentItem` entry
  carries a `SetupId`.
- Across every product that declares mounted items: 10,883 (product, mounted `ItemId`) pairs, of which
  7,517 also ship the same item standalone and 3,366 ship it only mounted. The mounted-only group is
  mostly reels - the Valkyrie reels are in it - so a blanket "drop every mounted entry" filter would erase
  real content from an advertising surface.
- In **none** of those pairs is the standalone quantity smaller than the mounted one. Collapsing a
  duplicate onto the standalone entry therefore never prints less than the player gets in one piece.
- `Amount` is set on no product entry at all - none of the 68,221 - so it is not summable in practice and
  is copied through untouched.
- **The printed length and the delivered one never disagree for a line.** They live in two separate fields
  of `InventoryItems.ConfigJson` - `Count`, the metres the game hands over, and `ParamsLength`, the string
  the shop renders through `InventoryParamProducer` - kept in step by hand. All 566 lines in the catalog
  agree. Leaders differ by design there, the printed value being the length of one piece against a count
  of pieces, which is what makes them a usable control when checking the lines.
- Storage of the stack is a per-pack authoring habit, not a property of the item: 401 packs fold only into
  `Equipment`, 235 only into `Storage`, 240 use both. `Equipment` is the more common target (3,938 stacked
  pairs against 2,868), which the first reading of the data missed. `Pro Fishing Starter Pack` keeps lines
  in `Storage` and consumables in `Equipment`; `Christmas Magic Pack` puts its line spools in `Equipment`;
  `Pro Upgrade Pack` puts everything in `Storage`.
- `Doll` never holds a stack (largest `Count` is 1), and `Hands` and `Rent` appear in no pack at all,
  which matches what those places mean: items worn on the character, the active rod slot, and rentals.
- **No pack promises more line than it delivers.** An earlier reading of this data claimed 11 such
  entries - `Catfish Moustache Line` in the platform variants of `Supernatural Explorer Pack`, 1200 m
  against 1300 m printed - and that was an artefact of the query, which selected non-`ParentItem` entries
  and compared their `Count` against the full catalog nominal, that is compared a part against the whole.
  Those packs carry a `ParentItem` entry of 100 m as well, so they deliver exactly the 1300 m the catalog
  prints, and the fold reaches them like any other pair.
  Recounted cleanly with [artifacts/catalog-recheck.sql](artifacts/catalog-recheck.sql): of 2,338 line
  pairs where the item ships both mounted and standalone, 2,327 give a whole spool plus extra metres on
  the reel, 11 divide one spool between reel and bag - the `Supernatural Explorer Pack` variants - and
  none delivers less than it prints. None has a standalone side of a single piece either, so the stack
  gate never declines a line.
  Traps that caught this analysis, all the same shape. `Params LIKE 'Length: % m'` sweeps in **rods**,
  whose `Length` is the physical blank length against a `Count` of 1. Comparing a standalone entry against
  the catalog nominal ignores the mounted portion, which the nominal covers as well. And the
  `Length`/`Test`/`Diameter` parameter template is not a line detector: **leaders render the same
  template**, so metres get compared with piece counts. Each produced a confident number that pointed at
  content authors, and none survived a look at the actual rows. The discriminator that does work is
  structural: a leader carries `LeaderLength` in its `ConfigJson`, a line does not.

## Ownership
- Client: the new product information window is FP-42797, written by the client programmer
  (Sergii Karchavets, SVN `sk`) - file created 2026-05-15 on `Unity_Fishing_CodeBranch`, last functional
  change 2026-06-10. `MainClient` commits for it are merges by the client lead, not authorship.
- Server: FP-42798, by the server developer (Yuriy Burda) - `ProductComponentGroups`,
  `InventorySortingGroups.ProductInfoOrder`, `Products.VerticalImageBID`. That work orders and groups the
  sections of the window and has no bearing on quantities.
- FP-46034 is currently assigned to the client lead; the ticket comments ask for display rules for items
  that come inside rod templates, and state that they should be shown in the quantity in which the DLC
  issues them.

## Fix decided
**Server, display path, MFT only.** `MonetizationHelper.GetStoreItemBriefs` folds every `ParentItem`
entry into the first standalone stack of the same item, adding its `Count`; a mounted item the product
ships in no standalone entry is kept as its own. Original entry order is preserved, because the window renders
entries in the order it receives them. `GameClientPeer_Monetization.FromDto` is the single call site,
which covers the shop list, the single-product fetch behind advertisements, and the PlayStation
composite path. `GetItemBriefs` stays untouched - WebAdmin's product image model calls it.

Folding rather than dropping the mounted entry, because `Count` is read by two live surfaces on this
branch: the old window (`PremShopItemInfo.AddInventoryItem`, reached by pond passes and pond-pass-category
containers) and the welcome list (`ShopHelper.GetItemsList`). A folded leader shows `(x13)` instead of
today's `(x12)` plus a bare row; dropping would have taken the mounted piece off those surfaces.

Only `Count` is summed. `Length` is a spool size for lines but the length of a single piece for leaders,
so adding it would claim a two-metre leader.

### Why the Code branch must not get it
The payload today is a faithful one-to-one projection of `ItemJson`; the fold deliberately distorts it
to compensate for a client defect. MFT ships its remaining releases with the current client and will get
no client build carrying the window fix - the client fix lives on the client Code branch, and merges run
upward, so it cannot reach the Content client. The Australia release (NPN) ships a fixed client behind a
protocol bump and a forced update, so server and client move together there; distorting the payload for
that client would only destroy information it can use correctly. MFT spawned NPN at r16131 and will
spawn nothing else, so the divergence terminates with the branch and the mitigation never needs removal.

Guard against an accidental sweep: MFT merges into NPN routinely while it lives, and this distortion is
invisible to compiler and tests. Every piece of the change carries the literal token `[!!!MFT ONLY!!!]`
in a comment - the method, its private helper, the call site and the test class - and the commit subject
leads with it, so `grep -rn "\[!!!MFT ONLY!!!\]"` lists the whole footprint and must come back empty on
any branch it was merged into. The form follows the `archive/GRM20240409` precedent and is now written
down in `reference/commit_message_format.md`. `--record-only` on NPN was rejected:
`feedback/mergeinfo_root_only.md` allows it only after verifying the content is present in the target,
and here it is deliberately absent - a false "merged" record would mask the real state.

Considered and rejected:
- **Editing catalog `Params`** - one `ItemId` yields one string; the same item must show two different
  quantities inside one product. Impossible by construction.
- **Routing packs to the old window from the server** - the window choice keys off `TypeId`, which is
  server data, but `TypeId` also drives delivery, categories and analytics.
- **A separate catalog item for the mounted variant** - the only content-only route to a correct number,
  but it means a duplicate item per line/leader/hook per pack (7,517 pairs would qualify) and puts stacking,
  mission conditions and achievements keyed on `ItemId` at risk.
- **Client fix on this branch** - `ProductInfoWindow.BuildItems` collapsing by `ItemId` and printing the
  product-entry quantity, mirroring `PremShopItemInfo.AddInventoryItem`. The real fix, and the only route
  to the quantity actually issued, but it belongs to the branch that still ships clients.

## Review findings (settled 2026-09-16)
Reviewed adversarially by the reviewer agent and by Codex, both tasked to refute. What held up under
attack: delivery isolation, `FromDto` as the single producer of `StoreProduct.Items`, `GetItemBriefs`
untouched for its WebAdmin caller, order preservation, and the agreement between the eligibility set and
the registered fold target.

Each fix below was checked by mutation - the code broken deliberately in the way the test claims to
catch, to confirm the test fails on it.

Applied:
- **The fold hid a piece where the row itself was the quantity.** 855 (product, item) pairs have a
  standalone side whose largest `Count` is 1 - feeders, floats, sinkers, crankbaits - so two rows read as two pieces
  while one folded row reads as one. Closed by gating the fold on a stack.
- **`ItemJson` holding the literal `null` threw.** The old `GetItemBriefs` returned null for it; the new
  method deserialized to a null list and fell over in the first `Where`, and a null array element hit
  `IsMountedInRodSetup`. Latent - the catalog carries neither shape - but the whole shop response is
  serialized in one pass, so one malformed product would take the entire list down.
- **The tests pinned almost nothing.** Every fixture held a single `ItemId` and a `Storage` target, so
  choosing the last standalone entry, reordering the output, or misclassifying storages all passed. Closed by
  tests for order across several items, fold-target choice, a target in `Equipment`, a stack of exactly
  2 at the threshold, and the counts on the single-piece case.

Declined, each after checking rather than on principle:
- **Unchecked `Count` summation.** `checked` would throw inside that same single-pass serialization and
  take down the product list, while wrapping would corrupt one display row. The path carries no money and
  no inventory, `Count` runs 1..2500 with no negatives, and the largest achievable fold sum is 2600.
- **`Amount` pass-through untested.** The field is set in none of the 68,221 pack entries, and for every
  `IsStockableByAmount` type it is a proxy over another field - `Length` for `Line`, `Weight` for `Chum`
  and `ChumIngredient`, `Capacity` for `BoatFuel`. Any fixture would pin a shape that does not exist.
- **`Length` as a number untested.** The value itself is read by nobody: the window checks only whether
  it is set. The existing leader assertion is kept and annotated in place as documentation of the
  line/leader difference rather than a guard on observed behaviour.
  Narrowed on the fourth pass, from an earlier and too broad decline of `Length` coverage altogether.
  Its *presence* turned out to be observable: `Length = productItem.Length ?? 0.0` passed the whole suite
  and flipped `HasValue` from false to true, which is exactly the flag `ShopHelper.GetItemsList` and
  `PremShopItemInfo.AddInventoryItem` consult before printing `(xN)` - a stack of hooks would have lost
  its count. Now asserted. The first half of the original rationale, that delivery overwrites `Length` in
  `Init()`, was beside the point as well: that happens to the delivered `InventoryItem`, a different
  object from the brief this path returns.
- **A string comparison replacing `Enum.TryParse` untested.** Such an edit would misread a numeric
  `Storage`, but no product carries one, so the test would pin a shape that does not exist - the same
  bar that ruled out the `Amount` fixture.

### The duplicated predicate was the root, not the missing test
A mounted entry that itself holds a quantity above 1 and has no standalone entry to absorb it was
uncovered: dropping the mounted guard from the eligibility set made such an item foldable, skipped its
row and registered no target, so it vanished from the window entirely. The shape is real - seven such
entries in the catalog - and the mutation reproduced it as `Sequence contains no elements`.

The gap existed because the same rule was written out twice, at the eligibility set and at target
registration, free to drift apart. It is now one predicate, `IsStandaloneStack`, used at both. The
regression test is kept alongside: the predicate makes the divergence inexpressible, the test says what
it would cost a player.

Those mounted entries above 1 are lines and braids without exception - 60 to 375 metres spooled on the
reel - so "stack" is the wrong word for them; what they carry is a length.

### When to stop reviewing this kind of change
Only the first pass found a fault in the code. Everything after it found surviving mutants - gaps in the
tests, not faults - and those were worth taking only because each named a failure a player would see: an
item vanishing from the window, a count disappearing. A finding that a mutant survives without such a
consequence is the signal to stop, since surviving mutants exist for any finite suite.

### Terminology
An entry is **standalone** (the package the item is sold in) or **mounted** (a piece taken out of such a
package and fitted into a rod setup). The earlier draft said "loose", which reads as unsecured rather
than as sold-as-its-own-unit; `standalone` also matches the wording already in the FP-46200 description.

### The rule changed under review
The gate first read "the first standalone entry decides", which made the outcome depend on the order the
entries happen to be authored in: the same set of entries folded or did not fold depending on which
standalone row came first. It now reads "the fold target is the first standalone stack; with no such
entry nothing folds". No product exhibits the divergent shape today, so this is a choice of rule rather than a
fix.

## Plan / artifacts
- [x] Root cause traced from `ItemJson` to the rendered row; client HEAD checked on both `MainClient` and
      `Unity_Fishing_CodeBranch` (the only delta there is the namespace decomposition refactor - no fix exists).
- [x] Data verification of the filter predicate across every product with mounted items, recounted in
      [artifacts/catalog-recheck.sql](artifacts/catalog-recheck.sql) once the line detector proved wrong.
- [x] `Supernatural Explorer Pack` authorship checked in `DataChanges` on DEV: created 2024-09-10 under
      FP-32843 with the line already in the rod setup, then edited by several hands. Who set the 1200 m
      specifically was not established and is not being chased - the premise was a suspected typo, and
      there is none. Query in `catalog-recheck.sql`; anchor it on the entry rather than on the item id,
      whose first occurrence falls in the rod's `RodItemIds` list.
- [x] Ownership established from SVN history.
- [x] Fix shape decided: fold on the server, MFT only; the window fix itself belongs to the Code branch.
- [x] Implemented, with `MonetizationHelperStoreBriefsTests` written before the method and watched to
      fail. Covers the fold and its stack gate, the gate boundary, target choice and entry order, a target
      outside `StoragePlaces.Storage`, single pieces, a mounted stack nothing can absorb, items folding
      independently of each other, and the malformed-JSON shapes.
- [x] Reviewed adversarially until a pass returned nothing that changes what a player sees.
- [x] Server story filed as FP-46200, linked `Relates` to the client ticket.
- [x] Settle the open review findings above.
- [x] Committed to MFT as r16546 and noted on the ticket, the note written for QA and feature owners
      rather than for server developers, with a warning panel against merging it upward. Not merged to
      NPN and not to be.
- [x] Commented on FP-46200 with the two rationales the Story format keeps out of a brief: why single
      pieces are left as two rows, which is what QA will otherwise report as a new bug, and why the
      mounted entry is merged rather than dropped. The rest of the investigation stays here - the ticket
      description already carries the root cause, and the commit note will carry what shipped.
- [x] Commented on FP-46034: a workaround is coming from MFT, it removes the doubled row, it does not
      make the printed figure right. Kept to that - the client side works out its own scope, and the
      per-item-kind breakdown was cut as analysis they did not ask for.

## Milestones
- 2026-09-10: Investigation complete. Defect identified as a client regression in the FP-42797 product
  information window: `StoreProduct.Items` carries the per-entry quantities, `ProductInfoWindow.BuildItems`
  renders the catalog `Params` instead. Server data confirmed correct on the reported pack. Server-side
  mitigation shaped and its safety verified (display path is independent of delivery; the collapse never
  understates below a single delivered piece). No code written, nothing posted to the ticket.
- 2026-09-14: Mitigation shape settled on folding rather than dropping the mounted entry, after finding
  that `Count` is read by the old window and the welcome list, and that `Length` is per piece for leaders
  so it cannot be summed. Branch scope decided: MFT only, on the grounds that the payload is a faithful
  projection of `ItemJson` and the Code branch keeps it that way for its fixed client. Implemented in
  `MonetizationHelper.GetStoreItemBriefs` with the single call site in `GameClientPeer_Monetization.FromDto`;
  `MonetizationHelperStoreBriefsTests` written first, watched to fail on the three folding cases, then
  green on all six. Also recorded that the same root cause misquotes lines outside rod setups, which the
  server mitigation does not reach.
- 2026-09-15: Server story filed as FP-46200 ("[PremiumShop] Stop packs with rod setups promising more
  than they deliver (MFT stopgap)"), Story under Prod Bugs_2026, Scrum Team Other, fixVersion
  Next Server Hotfix, component Server, priority High, `Relates` to the client ticket, which the brief
  names as the real fix. Both adversarial reviews returned; the catalog audit confirmed the reviewer's
  conditional risk that the fold hides a piece for single-piece items, and a `Count > 1` gate closes it
  without touching the reported line case. Findings recorded above, none applied yet.
- 2026-09-16: All review findings settled over two further adversarial rounds. Applied, each proved by
  mutation: the stack gate and its boundary, the malformed-JSON guard, coverage of entry order, target
  choice, a target outside `StoragePlaces.Storage`, and a mounted stack nothing can absorb. Declined with
  reasons recorded: the unchecked summation, the `Amount` and `Length` fixtures, and the string-comparison
  storage test. The gate rule itself changed under review, from "the first standalone entry decides" to
  "the target is the first standalone stack", removing a dependence on the order entries are authored in.
  The duplicated eligibility condition, which was the root of the last gap, became the single predicate
  `IsStandaloneStack`. Terminology settled on standalone against mounted. Catalog facts gathered along the
  way: the stack sits in `Equipment` more often than in `Storage`, which storage is a per-pack habit, and
  every mounted entry above 1 is line or braid measured in metres. Code complete and green, nothing
  committed.
- 2026-09-16: Retracted the claim, recorded on 09-15 and repeated since, that the same root cause
  misquotes lines in packs without a rod setup and that `Supernatural Explorer Pack` promises 1300 m
  while delivering 1200. It does deliver 1300: the query behind the claim selected non-`ParentItem`
  entries and compared them against a nominal that covers the mounted portion as well. No pack in the
  catalog promises more line than it delivers, and the GD question this raised is dropped. Nothing had
  been posted outside KB on it.
- 2026-09-16: Committed to MFT as r16546 - the helper, its single call site and the test file, with the
  concurrent club edits in the working copy left alone. Ticket note written for QA and feature owners
  rather than for server developers: what changes in the window, that single-piece items keeping two rows
  is deliberate, that the printed number is still the catalog one until the client fix, and that nothing
  about what a purchase delivers changes. A warning panel carries the do-not-merge-upward constraint.
- 2026-09-16: Catalog figures recounted from scratch after a third detector error surfaced - the
  parameter template used to spot lines matches leaders just as well, so nearly half of what was counted
  as lines were leaders. Conclusions all survived, numbers did not: 2,338 line pairs rather than 3,198,
  none of them declined by the stack gate, 2,327 delivering a whole spool plus extra against 11 dividing
  one, and none delivering less than printed. The recheck also settled an open worry: the printed length
  and the delivered one live in different fields but agree for every line in the catalog. Queries kept in
  `artifacts/catalog-recheck.sql`.
- 2026-09-16: A fifth round, run with an explicit stopping bar - report only what changes what a player
  sees, and say plainly when nothing does - came back empty from both reviewers, neither padding with
  surviving mutants. Review cycle closed at 16 tests.
- 2026-09-16: Card corrected on closing. The merge-guard paragraph still named the token `MFT branch ONLY`
  from an earlier draft, so the grep it prescribed would have found nothing in code carrying
  `[!!!MFT ONLY!!!]`; the round count said three where it was five.
