# FP-43177 Backlog

## Immediate

- [x] Study current RegionalPriceRates table implementation in WebAdmin
- [x] Study current VW_ProductLocalPrices table implementation in WebAdmin
- [x] Create module card `product-local-prices`
- [x] Review Google Sheets spec for price calculation logic
- [x] Consult with Stanislav Rudakov for detailed requirements
- [ ] Extract algorithm constants as named constants with documentation
- [ ] Implement new algorithm in `LocalPriceCalculator`
- [ ] Update WebAdmin UI (RegionalPriceRates page — hide deprecated columns)
- [ ] Update WebAdmin UI (ProductLocalPrices page — new suggested price logic)

## Deferred

- [ ] Remove deprecated fields (`RoundingAmount`, `RoundingType`, `Beautify`) from DB, DTO, UI — separate task after GD validates new logic in production. See [deprecated-fields.md](artifacts/deprecated-fields.md)
