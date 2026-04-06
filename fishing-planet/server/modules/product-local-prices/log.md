# product-local-prices — Decision Log

## 2026-04-02 — Approved: Smart Beautify algorithm (FP-43177)

Replace current single-tier beautify (`rounded - unit`) with a three-tier system (gold/silver/bronze) constrained by a 3% deviation window. Direction (up/down) auto-derived from region coefficient instead of explicit `RoundingType` parameter. Fields `RoundingAmount`, `RoundingType`, `Beautify` become obsolete (kept in schema during transition). See [smart-beautify-v1](../../tasks/FP-43177--price-adjustment/artifacts/smart-beautify-v1.md), [deprecated-fields](../../tasks/FP-43177--price-adjustment/artifacts/deprecated-fields.md). Approved by GD.

## 2026-04-05 — Implemented: Smart Beautify algorithm (FP-43177)

New `CalculateRegionalPrice()` overload with 4 params (basePrice, priceRate, exchangeRate, minimalUnit). Old overload marked `[Obsolete]`. Algorithm constants extracted as named constants with XML doc. Full decision trace in report parameter. Callers updated (ProductLocalPricesModel, RegionalPriceRatesModel, HomeController). Deprecated columns hidden in UI via `[Hidden]` attribute. Tests: 38 acceptance (GD spec parity) + 13 unit (direction, cost threshold, fallbacks, guards, report). All green.

