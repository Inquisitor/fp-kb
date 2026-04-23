# product-local-prices — Decision Log

## 2026-04-02 — Approved: Smart Beautify algorithm (FP-43177)

Replace current single-tier beautify (`rounded - unit`) with a three-tier system (gold/silver/bronze) constrained by a 3% deviation window. Direction (up/down) auto-derived from region coefficient instead of explicit `RoundingType` parameter. Fields `RoundingAmount`, `RoundingType`, `Beautify` become obsolete (kept in schema during transition). See [smart-beautify-v1](../../tasks/FP-43177--price-adjustment/artifacts/smart-beautify-v1.md), [deprecated-fields](../../tasks/FP-43177--price-adjustment/artifacts/deprecated-fields.md). Approved by GD.

## 2026-04-05 — Implemented: Smart Beautify algorithm (FP-43177)

New `CalculateRegionalPrice()` overload with 4 params (basePrice, priceRate, exchangeRate, minimalUnit). Old overload marked `[Obsolete]`. Algorithm constants extracted as named constants with XML doc. Full decision trace in report parameter. Callers updated (ProductLocalPricesModel, RegionalPriceRatesModel, HomeController). Deprecated columns hidden in UI via `[Hidden]` attribute. Tests: 38 acceptance (GD spec parity) + 13 unit (direction, cost threshold, fallbacks, guards, report). All green.

## 2026-04-13 — Implemented: Exchange Rate Snapshot (FP-43177 Phase 2)

Exchange rates in `RegionalPriceRates` switched from volatile `MonetizationCache` to persistent DB column. LiveOps manually snapshots live rates via new `VW_ExchangeRateUpdates` page. Key decision: store rate per-row (not per-currency) to allow per-platform/country granularity. `ProductLocalPrices` also switched to saved rate via `VW_ProductLocalPrices` JOIN. Game server components (`MonetizationHelper`, `PaymentHelper`) remain on live cache — intentional scope boundary. See [exchange-rate-snapshot-spec](../../tasks/FP-43177--price-adjustment/artifacts/exchange-rate-snapshot-spec.md).

## 2026-04-22 — Finding: ARS/CLP/COP price-recording bug (FP-42870)

During Xbox revenue reconciliation, `Transactions.Price` for Argentine Peso, Chilean Peso, and Colombian Peso was observed to store a USD-scaled amount instead of the local-currency amount. Scaling factors (~1/1000 for ARS, ~1/840 for CLP/COP) don't match current exchange rates — suggests stale/hardcoded divisor or a code path that substitutes USD equivalent under the local currency code. Impact is negligible at aggregate level (55 transactions, 0.33% of Xbox count, 0.046% of Xbox revenue over Nov 2025). Consistent across all 5 months surveyed for ARS; intermittent for CLP/COP. Reason not yet traced in code. Low priority — reconciliation posted on FP-42870 recommends a separate low-severity ticket.

