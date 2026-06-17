---
jira: FP-44465
title: Fix bass-jig levels and prices in local shops
status: completed
executor: Stanislav Samoilov
created: 2026-06-16
type: bug
---

## Status
Completed. Local-shop bass-jig prices recomputed (28 rows; Premium ×1.0 / Common ×1.5; pond 119 untouched) and applied + verified on real DEV (`[F2P] DEV`) with full DataChanges audit (28 rows, 0 remaining mismatches). Item Breaks currency-vs-rarity validator added (MFT r16199 → NPN r16200). Game-design (Andrii) approved the item changes.

## Summary
The Bass Jigs economy was reworked in `InventoryItems` (new MinLevel / RaretyId / Price). Two pieces of work followed:

1. **Local-shop prices** — recompute `LocalShop.Price` for the 82 reworked bass-jig IDs: Premium (RaretyId=3) = global price (×1.0), Common (RaretyId=1) = ROUND(global×1.5). Pond 119 (FTUE tutorial) excluded — it is intentionally ×1.0 for everything. Only `LocalShop.Price` changes; level/rarity/currency are read from `InventoryItems`, so they are already correct. See [local-shop](../../server/modules/local-shop/_card.md).
2. **Item Breaks currency validator** — flag items whose currency does not match rarity (Common→SC, Rare≠GC, Premium→GC; Unique unchecked), over all active items. Added `ItemRarity` enum.

The apply script reproduces the admin DataChanges audit (one commit-log row per change). See [data-editing](../../server/modules/data-editing/_card.md) for the capture gotcha.

## Plan / artifacts
- `artifacts/apply-local-shop-bass-jig-prices.sql` — local-shop price fix: read-only PREVIEW + transactional APPLY (DataChanges audit + price update + validation).
- `artifacts/audit-local-shop-prices.sql` — read-only audit of the whole LocalShop (markup x1.0/x1.5/other) + rarity x currency distribution across InventoryItems.
- `report.md` — game-design-facing change report (28-row change set + validation evidence).
- Apply order: review PREVIEW -> game-design sign-off -> run APPLY (local copy first, then real DEV).

## Milestones
- 2026-06-17 [MFT r16199 → NPN r16200] Item Breaks currency-vs-rarity check + `ItemRarity` enum (InventoryEnums.cs); checks run over all active items.
- 2026-06-17 Local-shop bass-jig prices applied on the local DEV copy (28 rows, ponds 102/106/111/113/115/123) + 28 DataChanges audit rows.
- 2026-06-17 Applied on real DEV (`[F2P] DEV`) via `apply-local-shop-bass-jig-prices.sql`: 28 LocalShop prices + 28 DataChanges audit rows; verified 0 remaining mismatches (ShopIds matched the local rehearsal).
