---
module: product-contents
system: monetization
---

# product-contents

What a purchasable product contains, and the two independent paths that content takes out of
`Products.ItemJson` - one to the shop windows, one to the player's inventory. The two never meet, which
is what makes a display-only correction possible and a display-only bug invisible to delivery.

## Entry Points

| Class / file                                                      | Path                                                              | Role                                                                                 |
|-------------------------------------------------------------------|-------------------------------------------------------------------|--------------------------------------------------------------------------------------|
| `MonetizationHelper.GetItemBriefs` / `GetStoreItemBriefs`          | `Shared/SharedLib/Monetization/MonetizationHelper.cs`             | `ItemJson` -> display briefs. `GetStoreItemBriefs` is the MFT-only fold, see Related |
| `MonetizationHelper.FromDto` -> `BuildInventoryItems`              | same file                                                          | `ItemJson` -> the inventory a purchase actually grants                               |
| `GameClientPeer_Monetization.FromDto(ProductDto)`                  | `Photon/src-server/Loadbalancing/LoadBalancing/GameServer/`       | the only producer of `StoreProduct.Items`; serves list, single fetch and PS composites |
| `GameClientPeer_Monetization.HandleGetItemBriefs`                  | same file                                                          | ships the whole item catalog to the client, per language                             |
| `InventoryParamProducer.ProduceParamsForItem`                      | `Shared/SharedLib/Shop/InventoryParamProducer.cs`                 | builds the `Params` string a window prints for an item                               |
| `ProductInfoWindow.BuildItems` (client)                            | `Assets/Scripts/UI/2D/ModalForms/` (client repo)                  | renders a product's contents; ignores the per-entry quantities                       |

## Key Types

| Type                        | Role                                                                                                       |
|-----------------------------|------------------------------------------------------------------------------------------------------------|
| `ProductInventoryItem`      | one `ItemJson` row: `ItemId`, `Storage`, `Count`, `Length`, `Amount`, `SetupId`, `RodItemIds`                |
| `ProductInventoryItemBrief` | the display projection carried in `StoreProduct.Items`                                                       |
| `StoreProduct`              | what a shop window receives. Distinct from `ProfileProduct`, which is what delivery builds                   |
| `StoragePlaces`             | `ParentItem` means mounted inside a rod setup; every other value means the item ships as its own package     |

## Dependencies

- -> `ItemCache` / the item catalog for names and `Params`
- -> `dal` for `Products` rows
- <- WebAdmin's product image model calls `GetItemBriefs`
- ~ the shop windows live in the client repo; their behaviour is recorded here because it cannot be read from this one

## Deep Dives

- [quantities.md](quantities.md) - what `Count`, `Length` and `Amount` mean per item kind, and why the printed number is not the delivered one

## Related Tasks

- FP-46200 (2026-09) - MFT-only fold of rod-setup entries into the standalone stack, to stop packs reading as promising more than they give. Display path only; `[!!!MFT ONLY!!!]`, must not be merged upward. See `tasks/FP-46200--product-info-template-quantities/`.
- FP-42797 / FP-42798 (2026-05) - the product information window itself and the server-side grouping and ordering behind it.
- FP-46034 - the client fix for the window; until it ships, the printed quantity stays the catalog one.
