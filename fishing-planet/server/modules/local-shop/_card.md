---
module: local-shop
---

# local-shop

Per-pond item shop shown when a player is at a water body ("local shop"), as opposed to the
global shop (full assortment on the world map). Both sell the same `InventoryItems`.

## Entry Points
- `SqlShopProvider.GetPondLocalItemInfo` (Dal/Sql.MsSql/Shop) — local rows via `VW_AllLocalItemInfo`
- `ItemCache.GetLocalItems(pondId)` — runtime local-shop items
- `LocalShopModel` (WebAdmin) — admin grid to edit local-shop rows

## Key Types
- `LocalShop` table — per-pond row: `ShopId` (PK, identity), `PondId`, `ItemId`, `Price` (+ Start/End/Discount*)
- `InventoryItems` — item catalog; owns `MinLevel`, `RaretyId`, `Currency`, `Price` (the "global" price)

## Invariants
- LocalShop stores **only `Price`** per pond. Level / rarity / currency are NOT per-shop — they
  are read from `InventoryItems` (shared with the global shop; `VW_AllLocalItemInfo` joins Currency).
  So after a catalog rework only `LocalShop.Price` is stale.
- Local price convention (holds game-wide): Premium (RaretyId=3) = global price (×1.0, GC);
  Common (RaretyId=1) = `ROUND(global × 1.5, 0)`.
- Pond **119** = FTUE tutorial pond: every item at ×1.0 (no local markup) — never apply ×1.5 there.

## Dependencies
- → `InventoryItems` (level / rarity / currency / global price)
- ~ `ItemRarety` (RaretyId 1=Common, 2=Rare, 3=Premium, 4=Unique); `Currency` (SC=Cash, GC=Gold/baitcoins, CT=Club)
- ~ [data-editing](../data-editing/_card.md) — admin edits and scripted changes write a DataChanges audit row

## Related Tasks
- FP-44465 (2026-06): recompute local prices for reworked Bass Jigs (82 IDs); Premium ×1, Common ×1.5, pond 119 excluded.
