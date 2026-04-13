# product-local-prices — Decision Log

## 2026-04-02 — Approved: Smart Beautify algorithm (FP-43177)

Replace current single-tier beautify (`rounded - unit`) with a three-tier system (gold/silver/bronze) constrained by a 3% deviation window. Direction (up/down) auto-derived from region coefficient instead of explicit `RoundingType` parameter. Fields `RoundingAmount`, `RoundingType`, `Beautify` become obsolete (kept in schema during transition). See [smart-beautify-v1](../../tasks/FP-43177--price-adjustment/artifacts/smart-beautify-v1.md), [deprecated-fields](../../tasks/FP-43177--price-adjustment/artifacts/deprecated-fields.md). Approved by GD.

## 2026-04-05 — Implemented: Smart Beautify algorithm (FP-43177)

New `CalculateRegionalPrice()` overload with 4 params (basePrice, priceRate, exchangeRate, minimalUnit). Old overload marked `[Obsolete]`. Algorithm constants extracted as named constants with XML doc. Full decision trace in report parameter. Callers updated (ProductLocalPricesModel, RegionalPriceRatesModel, HomeController). Deprecated columns hidden in UI via `[Hidden]` attribute. Tests: 38 acceptance (GD spec parity) + 13 unit (direction, cost threshold, fallbacks, guards, report). All green.

## 2026-04-13 — Implemented: Exchange Rate Snapshot (FP-43177 Phase 2)

Exchange rates in `RegionalPriceRates` switched from volatile `MonetizationCache` to persistent DB column. LiveOps manually snapshots live rates via new `VW_ExchangeRateUpdates` page. Key decision: store rate per-row (not per-currency) to allow per-platform/country granularity. `ProductLocalPrices` also switched to saved rate via `VW_ProductLocalPrices` JOIN. Game server components (`MonetizationHelper`, `PaymentHelper`) remain on live cache — intentional scope boundary. See [exchange-rate-snapshot-spec](../../tasks/FP-43177--price-adjustment/artifacts/exchange-rate-snapshot-spec.md).

