# FP-43177 Backlog

## Immediate

- [x] Study current RegionalPriceRates table implementation in WebAdmin
- [x] Study current VW_ProductLocalPrices table implementation in WebAdmin
- [x] Create module card `product-local-prices`
- [x] Review Google Sheets spec for price calculation logic
- [x] Consult with Stanislav Rudakov for detailed requirements
- [x] Extract algorithm constants as named constants with documentation
- [x] Implement new algorithm in `LocalPriceCalculator`
- [x] Mark old API as `[Obsolete]`
- [x] Update callers (ProductLocalPricesModel, RegionalPriceRatesModel, HomeController)
- [x] Hide deprecated columns in RegionalPriceRates grid (`[Hidden]` attribute)
- [x] Write acceptance tests (38 regions from GD spec)
- [x] Write unit tests (direction, cost threshold, fallbacks, guards)
- [x] GD validation in browser
- [x] Deviation column in RegionalPriceRates grid (signed %, red/bold >3%)
- [x] Details column with Smart Beautify decision trace
- [x] BaseAmount locale fix (`InvariantCulture` parsing + rendering)
- [x] Additional UI/UX features

## Deferred

- [ ] Remove deprecated fields (`RoundingAmount`, `RoundingType`, `Beautify`) from DB, DTO, UI — bubbled up to module backlog
