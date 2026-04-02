# product-local-prices — Decision Log

## 2026-04-02 — Approved: Smart Beautify algorithm (FP-43177)

Replace current single-tier beautify (`rounded - unit`) with a three-tier system (strong/elite/scale) constrained by a 3% deviation window. Direction (up/down) auto-derived from region coefficient instead of explicit `RoundingType` parameter. Fields `RoundingAmount`, `RoundingType`, `Beautify` become obsolete (kept in schema during transition). See [smart-beautify-v1](../../tasks/FP-43177--price-adjustment/artifacts/smart-beautify-v1.md), [deprecated-fields](../../tasks/FP-43177--price-adjustment/artifacts/deprecated-fields.md). Approved by GD.

