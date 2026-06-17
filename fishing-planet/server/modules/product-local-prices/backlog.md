# product-local-prices — Backlog

- [ ] Remove deprecated code after GD validates Smart Beautify: old `CalculateRegionalPrice` overload, `RoundingRule` enum, `Round()` method. See [deprecated-fields.md](../../../tasks/FP-43177--price-adjustment/artifacts/deprecated-fields.md)
- [ ] Remove deprecated DB columns (`RoundingAmount`, `RoundingType`, `Beautify`) from `RegionalPriceRates` table, DTO, view, seed script — separate task after stabilization
- [ ] Fix XSS in `ProductLocalPricesModel.AddPriceInfo()` — double quotes not escaped before injection into `onclick="alert('...')"`. Pre-existing, low practical risk (report is server-generated, no user input), but formally exploitable
- [ ] (FP-43192) Re-run all three UWP price data-fix scripts after the 2026.4 UWP release — Main (`R202606-ConvertTransactionPrices-UWP-Main.sql`), Stats facts (`R202606-ConvertTransactionPrices-UWP-Stats.sql`), then the `/Stats/Payments` aggregate (`R202606-RecomputePaymentsBuckets-UWP-Stats.sql`, `@FromTs='2000-01-01'`). All idempotent; run Main BEFORE the Payments recompute (it reads corrected Main). Then confirm 0 inflated remaining in all three.
- [ ] (FP-43192) Merge `MFT r16148` (+ the later `R202606-RecomputePaymentsBuckets-UWP-Stats.sql` revision) → `NPN` (new Code branch) so the parser test mirror + all UWP data-fix SQL land on Code; verify against the release process
- [ ] (FP-43192) Confirm DKK UWP parsing correct on prod with positive recent samples (only absence of purchases observed so far)
- [ ] (FP-43192) Under-direction sweep: UWP micro-prices < $0.50 conversion correctness (ARS/TRY under-direction already tracked in [crashed-currency-region-switching.md](crashed-currency-region-switching.md))
