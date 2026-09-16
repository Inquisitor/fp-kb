# Backlog - FP-46200

- [x] Decide the fix shape: fold the mounted entry into the standalone one, server side, MFT only.
- [x] Scope it to the `StoreProduct` path with its own helper - `GetItemBriefs` stays as it is, because
      WebAdmin's product image model calls it too.
- [x] Committed to MFT as r16546.
- [x] Handed the client fix back to FP-46034, which the client lead owns, with a comment stating what the
      server workaround does and where it stops. `PremShopItemInfo.AddInventoryItem` is the working
      reference there: it already collapses repeated `ItemId`s and appends the product-entry count.
- [x] Keeping r16546 out of any upward merge is left to the markers themselves - `[!!!MFT ONLY!!!]` in
      the code, in the commit subject and in a warning panel on the ticket, with the form written down in
      `reference/commit_message_format.md`. `--record-only` on NPN was rejected: it would assert content
      that is deliberately absent.
- [x] Dropped: there was no GD question. The `Supernatural Explorer Pack` discrepancy was an artefact of
      comparing a standalone entry against a nominal that also covers the mounted portion; the pack
      delivers exactly what it prints.
- [ ] Consider a module for the Premium Shop product display path once a second task touches it. Nothing
      in `server/modules/` covers it today (`local-shop` is the per-pond shop, `product-local-prices` is
      regional pricing), and the durable facts are the display/delivery split, the catalog-level nature of
      `Params`, and `Length` meaning a stack size for lines but a piece size for leaders. Do not create it
      pre-emptively.
