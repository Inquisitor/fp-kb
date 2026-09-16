# Backlog - product-contents

- [ ] Drop `GetStoreItemBriefs` and its predicate once the MFT branch retires - the fold exists only to
      compensate for a client that branch cannot update, and the whole footprint is greppable as
      `[!!!MFT ONLY!!!]`. (Bubbled from FP-46200 on close.)
- [ ] Map the remaining shop surfaces. The card covers the product information window and names the older
      window and the promo screens, but their selection rules and what each reads from the payload are
      only partly written down - the window choice keys off `TypeId`, with pond passes and
      pond-pass-category containers going to the older one.
- [ ] Decide whether `ProductInventoryItem.Length` should exist at all. Delivery overwrites it for lines
      and never reads it for anything else, and the client uses only its presence; it is a field kept
      alive by habit.
