# product-local-prices — Decision Log

## 2026-04-02 — Approved: Smart Beautify algorithm (FP-43177)

Replace current single-tier beautify (`rounded - unit`) with a three-tier system (gold/silver/bronze) constrained by a 3% deviation window. Direction (up/down) auto-derived from region coefficient instead of explicit `RoundingType` parameter. Fields `RoundingAmount`, `RoundingType`, `Beautify` become obsolete (kept in schema during transition). See [smart-beautify-v1](../../tasks/FP-43177--price-adjustment/artifacts/smart-beautify-v1.md), [deprecated-fields](../../tasks/FP-43177--price-adjustment/artifacts/deprecated-fields.md). Approved by GD.

## 2026-04-05 — Implemented: Smart Beautify algorithm (FP-43177)

New `CalculateRegionalPrice()` overload with 4 params (basePrice, priceRate, exchangeRate, minimalUnit). Old overload marked `[Obsolete]`. Algorithm constants extracted as named constants with XML doc. Full decision trace in report parameter. Callers updated (ProductLocalPricesModel, RegionalPriceRatesModel, HomeController). Deprecated columns hidden in UI via `[Hidden]` attribute. Tests: 38 acceptance (GD spec parity) + 13 unit (direction, cost threshold, fallbacks, guards, report). All green.

## 2026-04-13 — Implemented: Exchange Rate Snapshot (FP-43177 Phase 2)

Exchange rates in `RegionalPriceRates` switched from volatile `MonetizationCache` to persistent DB column. LiveOps manually snapshots live rates via new `VW_ExchangeRateUpdates` page. Key decision: store rate per-row (not per-currency) to allow per-platform/country granularity. `ProductLocalPrices` also switched to saved rate via `VW_ProductLocalPrices` JOIN. Game server components (`MonetizationHelper`, `PaymentHelper`) remain on live cache — intentional scope boundary. See [exchange-rate-snapshot-spec](../../tasks/FP-43177--price-adjustment/artifacts/exchange-rate-snapshot-spec.md).

## 2026-04-22 — Finding: ARS/CLP/COP price-recording bug (FP-42870)

During Xbox revenue reconciliation, `Transactions.Price` for Argentine Peso, Chilean Peso, and Colombian Peso was observed to store a USD-scaled amount instead of the local-currency amount. Scaling factors (~1/1000 for ARS, ~1/840 for CLP/COP) don't match current exchange rates — suggests stale/hardcoded divisor or a code path that substitutes USD equivalent under the local currency code. Impact is negligible at aggregate level (55 transactions, 0.33% of Xbox count, 0.046% of Xbox revenue over Nov 2025). Consistent across all 5 months surveyed for ARS; intermittent for CLP/COP. Reason not yet traced in code. Low priority — reconciliation posted on FP-42870 recommends a separate low-severity ticket.

## 2026-06-06 — Finding: UWP price-parser saga + data-fix must cover Main AND Stats (FP-43192)

UWP/Win10 parses Microsoft Store locale-formatted price strings client-side (`UwpManager.GetFloatPrice`); Xbox/GDK uses numeric `XStorePrice.Price` and is immune. Parser history: old `decimalChar` heuristic → FP-40470 (r50247) rewrite that introduced "single separator + 3 trailing digits = thousands" with no locale awareness → FP-39539 (r53528) added the 3-decimal-currency exception → FP-43192 generalised to role-based separator mapping (`NormalizeSeparatorChars`) + N-occurrence decimal resolution. See [review/FP-40470](../../review/FP-40470--win10-currency-parser/review.md), [review/FP-39539](../../review/FP-39539--kwd-currency-conversion/review.md), [tasks/FP-43192](../../tasks/FP-43192--win10-price-parsing/journal.md).

**Release-cut gotcha:** a client parser fix reaches prod only with the next UWP *release-branch snapshot*, not when it merges to trunk. FP-39539 merged to content trunk 4 days after the 2026.3 cut, so it shipped only with 2026.4.

**Data-fix gotcha (recurring):** `/Stats/Money` and producer reports read the **Stats DB** (`VW_TransactionFact_Bundled` over `TransactionFact` + `TransactionFactBundle`), a separate ETL copy — NOT `Main.Transactions`. Every historical price data-fix (FP-39539 and earlier) corrected Main only and never Stats, so the `/Stats/Money` spike persisted until FP-43192. **A transaction-price data-fix MUST update both Main and Stats and be verified in Stats.** Stats facts carry their own `ProductPriceUsd`, so the inflation signature `EquivalentPrice / ProductPriceUsd` is self-contained there. Detect by magnitude signature, not by currency list — the bug is device-locale-driven and can hit any currency.

