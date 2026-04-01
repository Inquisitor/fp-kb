# product-local-prices — Decision Log

## 2026-04-01 — Draft: Smart Beautify algorithm (FP-43177)

Finding: Task author proposes replacing current single-tier beautify (`rounded - unit`) with a three-tier system (strong/elite/scale) constrained by a 3% deviation window. Direction (up/down) is auto-derived from region coefficient instead of explicit `RoundingType` parameter. This would make `RoundingAmount`, `RoundingType`, and `Beautify` fields in `RegionalPriceRates` obsolete. See [smart-beautify-v1](../../tasks/FP-43177--price-adjustment/artifacts/smart-beautify-v1.md). Draft — pending refinement.

