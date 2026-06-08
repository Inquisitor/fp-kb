# product-local-prices — Backlog

- [ ] Remove deprecated code after GD validates Smart Beautify: old `CalculateRegionalPrice` overload, `RoundingRule` enum, `Round()` method. See [deprecated-fields.md](../../../tasks/FP-43177--price-adjustment/artifacts/deprecated-fields.md)
- [ ] Remove deprecated DB columns (`RoundingAmount`, `RoundingType`, `Beautify`) from `RegionalPriceRates` table, DTO, view, seed script — separate task after stabilization
- [ ] Fix XSS in `ProductLocalPricesModel.AddPriceInfo()` — double quotes not escaped before injection into `onclick="alert('...')"`. Pre-existing, low practical risk (report is server-generated, no user input), but formally exploitable
- [ ] (FP-43192) Re-run UWP price data-fix scripts (Main + Stats, `SQL/Releases/R202606-ConvertTransactionPrices-UWP-*.sql`) after the 2026.4 UWP release — idempotent, then confirm 0 inflated remaining in both DBs
- [ ] (FP-43192) Merge `MFT r16148` → `NPN` (new Code branch) so the parser test mirror + UWP data-fix SQL land on Code; verify against the release process
- [ ] (FP-43192) Confirm DKK UWP parsing correct on prod with positive recent samples (only absence of purchases observed so far)
- [ ] (FP-43192) Under-direction sweep: UWP micro-prices < $0.50 conversion correctness (ARS/TRY under-direction already tracked in [crashed-currency-region-switching.md](crashed-currency-region-switching.md))
