# product-local-prices — Backlog

- [ ] Remove deprecated code after GD validates Smart Beautify: old `CalculateRegionalPrice` overload, `RoundingRule` enum, `Round()` method. See [deprecated-fields.md](../../../tasks/FP-43177--price-adjustment/artifacts/deprecated-fields.md)
- [ ] Remove deprecated DB columns (`RoundingAmount`, `RoundingType`, `Beautify`) from `RegionalPriceRates` table, DTO, view, seed script — separate task after stabilization
- [ ] Fix XSS in `ProductLocalPricesModel.AddPriceInfo()` — double quotes not escaped before injection into `onclick="alert('...')"`. Pre-existing, low practical risk (report is server-generated, no user input), but formally exploitable
