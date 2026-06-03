# FP-44184 backlog

## Closeout
- [x] Commit the change set (MFT r16139)
- [x] Merge r16139 up MFT -> NPN (Content -> Code) at NPN r16140 (clean, byte-identical)
- [x] Post JIRA comment to FP-44184 (combined commit MFT + merge NPN, tagged Rudakov + Maslennykov, GDD edit request) — comment 122894

## Documentation update (docs owner)
- [~] GDD "Personal Offers - 1st iteration" (page 3803578462): unlimited-offer / ShowTimer behavior — **handed off to GD** (owner Mykola Maslennykov), flagged in JIRA comment 122894. Not tracked in KB (external owner).
- [x] TDD "Personal Offers - Server Technical Design" (`/wiki/x/LYCl5Q`, v12): "Default 1" removed; all property lists (Additional TA properties + Global Variables) converted to canonical-name tables; all old short names replaced with canonical (incl. `OfferPreserveTimeout` and `NumberOfActiveOffers`); dead `NumberOfPersonalOfferShowsPerDay` flagged "not implemented". Fully consistent.

## Deferred / bubble-up
- [x] Testability of the PO state machine and `TargetedAdsManager` refactor -> **bubbled to FP-32370** (its backlog: replace the `InternalsVisibleTo` stopgap with a real seam; remove the dead `NumberOfPersonalOfferShowsPerDay` global)
