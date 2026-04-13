---
module: product-local-prices
---

# Product Local Prices
> Regional pricing engine: base USD price × rate × exchange rate → three-tier smart beautify → local price.

## Entry Points
- `LocalPriceCalculator.CalculateRegionalPrice()` — `Shared/SharedLib/Monetization/LocalPriceCalculator.cs` (core formula)
- `ProductLocalPricesModel` — `WebAdmin/WebAdmin/Models/Monetization/ProductLocalPricesModel.cs` (admin UI logic)
- `RegionalPriceRatesModel` — `WebAdmin/WebAdmin/Models/Monetization/RegionalPriceRatesModel.cs` (rate config UI)
- `ExchangeRateUpdateModel` — `WebAdmin/WebAdmin/Models/Monetization/ExchangeRateUpdateModel.cs` (exchange rate snapshot UI)
- `PaymentHelper.ApplyLocalPrice()` — `Shared/SharedLib/Payments/PaymentHelper.cs` (runtime application)

## Key Types
- `ProductLocalPriceDto` — `Dal/Sql.Interface/Monetization/ProductLocalPriceDto.cs` (productId, currency, country, price, discountPrice)
- `RegionalPriceRateDto` — `Dal/Sql.Interface/Monetization/RegionalPriceRateDto.cs` (rate, minimalUnit; roundingAmount/roundingType/beautify deprecated)
- `CurrencyExchangeRateDto` — `Dal/Sql.Interface/CurrencyExchange/CurrencyExchangeRateDto.cs` (targetCurrency, exchangeRate)
- `ProductLocalPricesExt` — `WebAdmin/WebAdmin/Models/Entities.cs` (view model with suggested prices & validation)

## Dependencies
→ `IMonetizationProvider` — DAL: CRUD for local prices and regional rates
→ `ICurrencyExchangeRateProvider` — DAL: exchange rates (refreshed daily at 3 AM)
→ `MonetizationCache` — `Shared/SharedLib/Config/MonetizationCache.cs` (caches rates, applies local prices to products)
← GameServer — consumes via `MonetizationCache.GetProducts()` at runtime
← WebAdmin — admin UI for editing rates and reviewing/applying suggested prices

## Deep Dives
- [Smart Beautify algorithm](smart-beautify.md) — three-tier beautification: tiers, rules, constants, examples
- Views: `WebAdmin/WebAdmin/Views/Home/VW_ProductLocalPrices.cshtml`, `RegionalPriceRates.cshtml`
- Controller actions: `HomeController.ApplySuggestedPrices()`, `AddProductLocalPrices()` — `WebAdmin/WebAdmin/Controllers/HomeController.cs`
- DB: tables `ProductLocalPrices`, `RegionalPriceRates`, `CurrencyExchangeRates`; view `VW_ProductLocalPrices`
- Seed script: `SQL/PopulateRegionalPriceRates.sql`
- Tests: `Shared/SharedLib.Tests/Monetization/LocalPriceCalculatorTests.cs` (38 acceptance + unit tests)

## Related Tasks
- FP-43177 Phase 1: Smart Beautify algorithm (completed) — r15959+r15961+r15969
- FP-43177 Phase 2: Exchange Rate Snapshot (completed) — r15997+r15999
