# local-shop — decision log

2026-06-17 [MFT] FP-44465: Bass Jigs economy reworked in `InventoryItems`; propagated to local shops.
- Decision: only `LocalShop.Price` needs changing. Level/rarity/currency live on `InventoryItems` and
  are shared, so they were already correct once the catalog was reworked. The bug report's "wrong level"
  resolves itself; "wrong price" is the per-pond stale value.
- Pricing rule = the existing game-wide convention, verified against all non-bass-jig local rows
  (Premium/GC all ×1.0; Common/SC ~all ×1.5). Not an ad-hoc FP-44465 rule.
- Pond 119 left untouched per game design: it is the FTUE tutorial pond and is intentionally ×1.0 for
  everything (no local markup). Confirmed in data — every 119 row equals the global price.

2026-06-17 Finding: `LocalShop.ShopId` is an identity PK. The dev→prod DataChanges replay keys rows by
PK, so if dev and prod assigned different ShopId to the same (PondId, ItemId), a replay can mis-target.
Not fixed here — property of the sync mechanism; flagged for awareness.
