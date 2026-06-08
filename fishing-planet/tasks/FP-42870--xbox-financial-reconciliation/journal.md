---
task: FP-42870
title: "Xbox. Compare financial indicators by platform"
status: completed
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-42870
related:
  - FP-41929
---

## Status

Closed 2026-04-22. Investigation scope completed: 5-month reconciliation (Jul–Nov 2025) against Microsoft royalty, 5 gap factors identified and quantified, producer report posted as JIRA comment 115966 on FP-42870 with 7 ranked improvement proposals. No code changes under this task — any follow-up work will be scoped as separate tickets.

## Summary

Live ops producer wants to understand how well our system estimates revenue. In parallel, we need to verify whether purchases are registered correctly (related to suspected Xbox exploit in FP-41929).

## Data Sources

### Source A: Our Database — Transactions table

```sql
CREATE TABLE [dbo].[Transactions] (
    [TransactionId]       UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    [ProductId]           INT              NOT NULL REFERENCES [dbo].[Products],
    [Timestamp]           DATETIME         NOT NULL,
    [UserId]              UNIQUEIDENTIFIER NOT NULL,
    [ForegnTransactionId] VARCHAR(255),      -- order number; empty for MS purchases
    [PaymentSystemId]     VARCHAR(16)      NOT NULL,  -- "XBox", "Win10", "WebAdmin"
    [Status]              VARCHAR(16)      NOT NULL,  -- always "Complete" for Xbox
    [ErrorMessage]        VARCHAR(256),
    [Price]               DECIMAL(19, 3),   -- original currency
    [Currency]            CHAR(3),
    [EquivalentPrice]     DECIMAL(19, 3)    -- USD, after platform fee deduction
)
```

- `EquivalentPrice = Price × (1 - FeePercent / 100)`, where FeePercent = 38 for Xbox (from `Platforms` table)
- `PaymentSystemId` values for Xbox: `"XBox"` and `"Win10"` (both count together). `"WebAdmin"` = admin-created, excluded from comparison
- `ForegnTransactionId` is the order number, **not** the product mapping key. MS does not provide order IDs — field is empty for Xbox purchases. No way to match individual transactions with MS data.

### Product mapping

Product mapping is in a separate table `ProductMappings`:
- `ForeignProductId` — alphanumeric string (e.g. `"BNQSGPT638M1"`, `"C5GQPPL601SH"`), visible in Microsoft Partner Center after product creation
- These IDs are **not present** in the Microsoft Royalty Statement XLS

### Additional fields

For Starter Kit products, the ProductId is saved to:
- `StartersOwned` — comma-separated list in player profile (purchased starters)
- `StartersGiven` — comma-separated list in player profile (delivered starters)

### Source B: Microsoft Royalty Statement (.xlsm)

Monthly files. Sheet: **ILS** (International Licensing Statement). Data starts at **row 10** (rows 1-9 are header with report title and company name).

**Columns (row 10):**

| Column                           | Notes                                                                          |
|----------------------------------|--------------------------------------------------------------------------------|
| Product License Type             | `Consumable`, `Durable`, `Game`                                                |
| Title ID                         | Always "Non English Title ID" — useless                                        |
| Transaction Type                 | Regular sales + `Amounts Uncollectable` + `RETURNS` (TBD)                      |
| Title Name                       | "Fishing Planet: ..." prefix                                                   |
| Product Name                     | Has numeric suffixes (e.g. `_OGP_22819`, `_222162`) — **not** ForeignProductId |
| Offer Name                       | Shorter, sometimes with "Fishing Planet: " prefix, sometimes without           |
| Payment Method                   | `CREDITCARD`, `PAYPALPAYIN` — must sum across for comparison                   |
| Remittance Rate                  | 0.0000                                                                         |
| Royalty Rate                     | 0.70 for sales, -1 for Amounts Uncollectable                                   |
| Retail Price Per Unit            | Original currency                                                              |
| Wholesale Price Per Unit         | = Retail × 0.70                                                                |
| Transaction Currency Code        | Full name ("US Dollar", "Canadian Dollar", etc.)                               |
| Contract Currency Code           |                                                                                |
| Exchange Rate (Contract)         |                                                                                |
| Sum of Purchase Units            | Count                                                                          |
| Sum of Earned Royalty            |                                                                                |
| Sum of Earned Royalty (Contract) |                                                                                |
| Sum of Royalty USD               |                                                                                |

**Structure:** Hierarchical with collapsible groups (Product License Type → Title ID → products). Rows grouped by product + currency + payment method.

### Hidden sheet: AlliantStripData (raw data)

The .xlsm contains 3 sheets: **AlliantStripData** → **ILS** → **Royalty Summary** (pivot table chain).

AlliantStripData is the raw data source (4760 rows for Nov 2025), with per-country granularity and — critically — **Offer GUID** column for product mapping. "Alliant" is likely Microsoft's royalty accounting system; "Strip Data" = raw export.

Key additional columns vs ILS:

| Column           | Notes                                                    |
|------------------|----------------------------------------------------------|
| Country          | e.g. `CTY_United States`, `CTY_United Kingdom`           |
| Region           | e.g. `REG_United States`, `REG_UK`                       |
| Offer GUID       | e.g. `9PMM7SDK746M:0010` — maps to our ForeignProductId  |
| Transaction Type | `Purchase`, `RETURNS`, `Amounts Uncollectable` — per row |
| Purchase Units   | Per row (not aggregated like ILS)                        |
| Royalty USD      | Per row                                                  |
| Title Name       | Without numeric suffixes (cleaner than Product Name)     |

32 currencies, 113 unique products in Nov 2025.

## Key Findings (2026-03-27)

### 1. Fee discrepancy: 38% vs 30%

Our `EquivalentPrice` uses FeePercent=38 (we keep 62%). Microsoft Royalty Rate = 0.70 (we get 70%).

Example — Chamaeleon Cruiser Pack at $59.99:
- MS Wholesale: $59.99 × 0.70 = **$41.99**
- Our EquivalentPrice: $59.99 × 0.62 = **$37.19**
- Difference: ~13%

**Hypothesis (confirmed):** FeePercent=38 was set empirically to compensate for multiple factors, biggest being **local VAT that MS strips before royalty calc** (see Finding #13 — typical EU VAT 20–27%). Also contributing: bundle expansion (#8), Amounts Uncollectable / RETURNS (#3), and currency conversion / regional pricing (#7).

### 2. "Amounts Uncollectable" — invisible to us

MS XLS contains negative entries (Transaction Type = "Amounts Uncollectable", Royalty Rate = -1) — chargebacks, failed payments. We have **no record** of these in Transactions (Status is always "Complete"). This could be a significant hidden loss.

### 3. RETURNS and Amounts Uncollectable — quantified (Nov 2025)

AlliantStripData breakdown by Transaction Type (Nov 2025):

| Transaction Type      | % of Purchase Royalty | % of Purchase Units |
|-----------------------|-----------------------|---------------------|
| Purchase              | 100%                  | 100%                |
| RETURNS               | -1.4%                 | -1.0%               |
| Amounts Uncollectable | -0.7%                 | -0.3%               |
| **Total losses**      | **-2.1%**             | **-1.3%**           |

RETURNS include product refunds (e.g., "1 day of Premium Account", Money Packs, various fishing packs). Amounts Uncollectable are mostly expensive items (Money Packs). STOREDVALUE payment method also appears in RETURNS (purchases via MS account balance).

Royalty Summary shows return cap: Jul-Sep 2025 quarter had ~1.4% returns (cap 1% — exceeded).

### 4. Product mapping — SOLVED via AlliantStripData

**ILS sheet** does not contain ForeignProductId — mapping appeared unsolved.

**AlliantStripData** (hidden sheet, raw data behind the ILS pivot table) contains **Offer GUID** column with values like `9PMM7SDK746M:0010`. The base part before `:` matches our `ProductMappings.ForeignProductId` — confirmed for `9PMM7SDK746M` and `9PPP4R43JC8F`.

113 unique Offer GUIDs in Nov 2025 file. Mapping: strip `:0010` suffix → match to `ForeignProductId`.

**Fallback** (if AlliantStripData is unavailable in some files):
1. Client price-loading logs at login — may contain both our ProductId and Xbox product identifier/name substrings
2. Parse distinctive product names and match by keywords (fuzzy matching)

### 5. Rare currencies available for detailed matching

Spotted in XLS: Kuwaiti Dinar (KWD), Swiss Franc (CHF), Australian Dollar (AUD). Low transaction volume = ideal for verifying per-product match accuracy before scaling to USD.

### 6. Xbox + Win10 = one bucket

MS does not separate Xbox and Win10 in royalty statements. We should query `PaymentSystemId IN ('XBox', 'Win10')` and aggregate together. Exclude `'WebAdmin'`.

### 7. Regional pricing — prices are NOT USD-equivalent

Microsoft has regional pricing tiers where local currency prices are set far below the USD equivalent. Examples:
- Argentina (ARS): a $100 USD product costs ~$7.50 equivalent in pesos
- Brazil (BRL): ~55% of USD equivalent

This means the same ProductId generates vastly different revenue per unit depending on the buyer's region/currency. **Implications:**
- `EquivalentPrice` calculation needs investigation — what exchange rate is used, and does it account for regional pricing?
- Comparing aggregated USD totals across all currencies will be misleading
- **Must compare within the same currency** (our Price in currency X vs MS Retail Price in currency X), not via USD conversion
- Regional pricing losses could be another factor in the 38% FeePercent (on top of Amounts Uncollectable and Returns)

### 8. Bundle expansion — inflates our revenue (MAJOR finding, 2026-04-21)

On Microsoft Store side, bundles are **atomic products** with their own Offer GUID and bundle price. Microsoft records 1 sale per bundle purchase.

On our side, the Xbox client SDK expands the bundle into its component purchases **on the client**, sending N separate purchase events to our server. Our Transactions table writes N component rows, each with the component's base price — not the bundle's price.

**Example — Ultimate Sport Bundle** (`9PPP4R43JC8F`, bundle price $27.49):
- MS Partner Center lists 10 included products (Sport Bottom/Carp/Casting Bass/Feeder/Float/Heavy Casting/Outfit/Spinning Trout/Topwater Night/Ultralight Panfish Packs), verified against `Products.BundleProductIdsJson`
- MS records: 1 transaction, revenue = bundle price
- Our DB records: 10 transactions, revenue = sum of component prices (~$54.90 for this bundle — ~2x inflation)

**Consequences:**
1. **Transaction count** in our DB is not directly comparable with MS Purchase Units when bundles are involved (+N-1 rows per bundle sale)
2. **Revenue in our DB is systematically inflated** for any period where bundles were sold. Sum of `Price`/`EquivalentPrice` over-reports actual money received
3. **Bundles with Price=0 in our Products** (Starter Packs, Christmas/Halloween Bundles) cause even worse distortion — MS shows real sales and revenue, our DB shows zero-revenue components
4. This likely accounts for a significant portion of the 38%-vs-30% fee gap
5. For FP-41929: bundle expansion can make a single bundle purchase look like "10 purchases in 1 second". Not to be confused with the real exploit where **the same ProductId** is duplicated — bundle expansion produces N **different** ProductIds

**Correction formula for reconciliation:**
```
over_counted_revenue = ms_bundle_sales × (sum_of_component_prices - bundle_price)
true_revenue          = ms_bundle_sales × bundle_price
```

**Open architectural issue:** server does not detect bundles at purchase time. Potential future fix: detect `BundleProductIdsJson` at purchase registration and write one bundle-level transaction instead of N component transactions. Trade-off: may break downstream analytics that rely on per-component data.

**Bundle discount rates (from live-ops):**
- Ultimate Sport Bundle — 50% off components sum
- Lucky Bundle — 40% off components sum

### 9. ProductMappings structure validated (2026-04-21)

- 1742 entries, 928 unique `ForeignProductId` strings — each ForeignProductId maps to 2 ProductIds (XBox PlatformId=3, Win10 PlatformId=4)
- Some legacy numeric IDs exist for XBox/Win10 products (~100 each) alongside newer alphanumeric ones — MS migrated its catalog to alphanumeric; Nov 2025 AlliantStripData has **only** alphanumeric Offer GUIDs
- **100% mapping coverage**: all 113 Offer GUIDs from Nov 2025 XLS found in ProductMappings; all 16,554 transactions in prod for Nov 2025 mapped to a ForeignProductId

### 10. ProductTypeId=2 ("Starter Kit") is a legacy label, not a function

Originally, when FP was Steam-only, non-consumable DLC products were marked `TypeId=2 Starter Kit` (because first products were literally "starter helper" packs). After other platforms were added, the tag stayed but lost functional meaning — it now covers Sport Packs, Lucky Bundle, Starter Packs, Christmas/Halloween Bundles, etc.

`StartersOwned`/`StartersGiven` profile fields are **Steam-specific** tracking; not related to Transactions or Xbox flow.

### 11. "MS-only" products — mostly zero-priced starter packs (2026-04-21)

7 products appeared in MS Nov 2025 but had 0 transactions on our side. All are `TypeId=2`. Two categories:

**Bundles with populated `BundleProductIdsJson` (detected via component expansion):**
- Ultimate Sport Bundle — 10 components
- Lucky Bundle — 2 components
- Christmas Bundle — 4 components

**"Invisible" products (`Price=0`, no `BundleProductIdsJson`, no Transactions records at all):**
- Advanced Starter Pack, Deluxe Starter Pack, Halloween Bundle — Price=0 on our side, sold for real money on MS
- **BIG HOLIDAY BUNDLE** — anomaly: Price=$27.99 but empty `BundleProductIdsJson`. Likely a misconfigured bundle in our catalog

Hypotheses for why they don't produce any Transactions at all:
- Components already owned by most players → MS SDK doesn't resend them post-purchase → client sees no "new" purchases to forward
- Delivered via entitlement mechanism that bypasses Transactions

### 12. Bundle detection pipeline in Stats DB (KEY FINDING, 2026-04-21)

Bundle detection **does exist** — but in Stats DB (analytics), not Main DB. Pipeline:

```
Transactions (Main) → TransactionFact (Stats)
                           ↓ hourly xx:25
                      DetectBundlePurchasesJob
                           ↓
              INSERT TransactionFactBundle + UPDATE TransactionFact.BundleTransactionId
                           ↓
                  VW_TransactionFact_Bundled (collapses N components → 1 bundle row)
                           ↓
                /Stats/Money → GetStatsTransactions()
```

**Key source files:**
- `AsyncProcessor\Jobs\Monetization\DetectBundlePurchasesJob.cs` — hourly ETL
- `Dal\Sql.MsSql\Monetization\SqlMonetizationProvider.cs` → `MarkAsBundle`, `GetStatsTransactions`
- `SQL\Patches\Stats\Views\VW_TransactionFact_Bundled.sql` — rollup view

**Detection algorithm:**
- Groups transactions per user within a 30-second window
- Matches group against bundles that satisfy: `ProductPriceUsd > 0 AND InnerProductsPrice > 0 AND InnerProductIds.Count > 0`
- Requires **all** bundle components to be present (partial-purchase case fails)
- Bundle's `EquivalentPrice` stored as: `sum(component.EquivalentPrice) × (bundle.ProductPriceUsd / bundle.InnerProductsPrice)` — proportional scaling, preserves local-currency proportions

**Detection gaps** (undetected bundles remain inflated in producer's view):
- Partial-purchase case: if player already owns N-1 components, SDK sends only 1 → won't match bundle
- BIG HOLIDAY BUNDLE (empty InnerProducts) — never detected
- Price=0 bundles (Halloween, Advanced/Deluxe Starter Pack) — filtered out by `ProductPriceUsd > 0` check, but they also don't produce Transactions rows, so this doesn't matter in practice
- 30-second window — legitimate bundle purchases with delayed component delivery fall through

### 13. VAT is the main contributor to the 38%-vs-30% gap (MAJOR, 2026-04-21)

Microsoft's `Retail Price Per Unit` in AlliantStripData is **net of local VAT/GST** (what goes into royalty calc). Our `Price` is **gross** (what the player paid). For matched-count product×currency pairs (bundle-free, no anomalies), the ratio `ours/MS` matches the local VAT rate almost perfectly:

| Currency(s)                  | Implied rate | Country rate                                                                 |
|------------------------------|--------------|------------------------------------------------------------------------------|
| HUF                          | 27.0%        | 27% (Hungary)                                                                |
| SEK, NOK, DKK                | 25.0%        | 25%                                                                          |
| PLN                          | 22.9%        | 23% (Poland)                                                                 |
| CZK, RON, EUR(avg)           | 21.0%        | 21%                                                                          |
| GBP, TRY, UAH                | 19.9–20.0%   | 20%                                                                          |
| COP, CLP(MS)                 | 19.0%        | 19%                                                                          |
| MXN                          | 16.0%        | 16% (Mexico)                                                                 |
| ZAR, NZD                     | 15.0%        | 15%                                                                          |
| BRL                          | 14.8%        | ~15% (ICMS mix)                                                              |
| AUD, KRW                     | 10.0%        | 10%                                                                          |
| CHF                          | 8.3%         | 8.1% (Switzerland)                                                           |
| SGD                          | 9.0%         | 9% (GST)                                                                     |
| MYR                          | 8.0%         | 8% (SST)                                                                     |
| THB                          | 7.0%         | 7% (Thailand)                                                                |
| USD, CAD, HKD, KWD, SAR, ILS | 0%           | MS does not strip (US/CA state-level tax; SAR/ILS: unclear; HKD/KWD: no VAT) |

**Implication for 38%-vs-30% gap:** MS takes 30% of **net-of-VAT**. We apply 38% to **gross**. For a European sale in HUF, MS nets ≈ `gross × (1/1.27) × 0.70 ≈ 55.1% of gross`. Our calc: `gross × 0.62 = 62% of gross`. So our `EquivalentPrice` over-states MS revenue by ~7 p.p. for HUF sales. This likely combines with bundle inflation and currency conversion to make up the full gap.

**Correct formula for our side to match MS net royalty:**
```
ms_royalty_estimate = gross_price / (1 + vat_rate) × 0.70
```

### 14. Quantification of factors (Nov 2025, aggregate)

All figures relative to **MS Purchase royalty = 100%** (gross royalty MS records before returns/uncollectable):

| Metric                                               | % of MS Purchase |
|------------------------------------------------------|------------------|
| MS Purchase royalty                                  | 100.0%           |
| MS RETURNS                                           | -1.4%            |
| MS Uncollectable                                     | -0.7%            |
| **MS Net royalty (bottom line)**                     | **97.9%**        |
| Our EquivalentPrice @38% fee                         | 95.8%            |
| Our gross @30% fee (hypothetical, no VAT correction) | 108.2%           |
| Our @30% fee + VAT correctly stripped                | 101.6%           |

**Contribution of each factor to the 38%-vs-30% gap:**

| Factor                                    | Direction              | Magnitude                                   |
|-------------------------------------------|------------------------|---------------------------------------------|
| 38% vs 30% fee difference                 | Reduces our estimate   | ≈ 12 p.p. (dominates at portfolio level)    |
| VAT not stripped on our side              | Inflates our estimate  | ≈ +6.6 p.p. (weighted by currency mix)      |
| Bundle expansion inflation                | Inflates our estimate  | ≈ +1.6 p.p. (residual after VAT correction) |
| RETURNS + Uncollectable (invisible to us) | MS subtracts, we don't | -2.1 p.p.                                   |
| ARS/CLP/COP bugs                          | Reduce our estimate    | Unknown, small                              |

**Conclusion:** FeePercent=38 is an empirical fit that compensates for the sum of all these offsetting factors. At aggregate level our @38% under-reports MS Net royalty by only ~2% — but this hides significant per-currency/per-product distortions.

### 15. Currency data bugs (2026-04-21)

**ARS (Argentine Peso):** 15 products show ratio `ours/MS ≈ 1/1000` — we store USD-scaled amount instead of ARS. Example: ours=1.60 "ARS" vs MS=1599 ARS. Exception: `9NJ7MWVKNKQZ` shows ratio ~0.17 (likely correct record among the buggy ones — needs investigation).

**CLP (Chilean Peso):** 5 products show ratio ≈ 1/840 (close to CLP/USD exchange rate).

**COP (Colombian Peso):** 1 product with similar 1/840 ratio.

**Not a currency conversion issue** — the factor is constant per currency, not dependent on exchange rate fluctuations. Looks like hardcoded scaling or a code path that substitutes USD-equivalent under the local currency code. Current rates in our system (as of 2026-04-21): ARS=1376.5, CLP=882.9, COP=3575.4 per USD — the buggy factors (~1000 for ARS, ~840 for CLP/COP) don't match exact current rates; may be stale rates or a deeper bug in regional pricing logic.

**Impact is negligible:** ARS + CLP + COP combined = 55 transactions out of 16,554 (0.33% of count, 0.046% of revenue) for Nov 2025. Low priority — file as a separate low-severity bug, not blocking for FP-42870.

> **Follow-up (2026-06-08):** investigated. Mostly **not** a code bug — the low ARS/CLP/COP values are real **crashed-currency** prices, and a large share of ARS/TRY purchases are **region-switching** from outside the region (Country = IP geo; ARS 17% non-Argentine, TRY 61% non-Turkish; concrete "hunter" UserIds captured). A residual near-zero `/1000` subset (this finding's literal `1.60` vs `1599`) is likely **old-parser under-direction** (Win10, fixed forward by FP-40470, data uncorrected) — still open. Full analysis: [crashed-currency-region-switching](../../server/modules/product-local-prices/crashed-currency-region-switching.md). Warrants a separate liveops ticket.

### 16. Bundle detection quality — measured against MS Nov 2025 (2026-04-21)

Queried `Stats.TransactionFact` (+ `TransactionFactBundle`) for Nov 2025 XBox+Win10. Compared to known MS bundle sales.

**Detection rates:**

| Bundle (our ProductId)                                         | MS sales | Detected |                            Rate |
|----------------------------------------------------------------|---------:|---------:|--------------------------------:|
| Ultimate Sport Bundle (9010/9020)                              |      104 |      101 |                           97.1% |
| Lucky Bundle (9560/9570)                                       |       40 |       40 |                            100% |
| Christmas Bundle (13350/13360)                                 |       10 |        0 |           0% (Price=0 → filter) |
| BIG HOLIDAY BUNDLE (8750/8760)                                 |        2 |        0 |        0% (empty InnerProducts) |
| Starter Packs, Halloween (no components / not in Transactions) |       42 |        0 | N/A (architecturally invisible) |
| **Configured bundles (detectable by design)**                  |  **144** |  **141** |                       **97.9%** |

3 missed Ultimate Sport Bundles most likely hit the partial-purchase case (player already owned some components; SDK sent fewer than 10).

**Cross-validation (Approach B):** simulating the exact `DetectBundlePurchasesJob` algorithm against raw `Transactions` CSV yields the same 141 bundles as the production `TransactionFactBundle` state — per-ProductId counts match exactly (90/11/36/4). Confirms the production ETL is lossless: no technical detection gaps, the 3 missed Ultimate Sport Bundles are a fundamental limitation of the algorithm (requires all components), not an infrastructure issue.

**Effect of bundle collapse on count:**

| Metric                      |    Raw |    Bundled |
|-----------------------------|-------:|-----------:|
| Rows                        | 16,554 |     15,605 |
| Gap vs MS Purchase (15,558) |  +6.4% | **+0.30%** |

Bundle detection eliminates ~95% of the count discrepancy. The residual +47 unit gap is small enough to be timezone edge cases + 3 undetected bundles + anomalies.

**Effect on revenue (`EquivalentPrice` @38%):**

| Metric           | % of MS Purchase royalty |
|------------------|-------------------------:|
| Raw sum          |                    95.8% |
| Bundled sum      |                    94.5% |
| (MS Net royalty) |                    97.9% |

Bundled revenue is **structurally more accurate** (reflects real bundle prices, not component sums), but moves 1.3 p.p. away from MS Purchase because bundle collapse removes the inflation that was partly offsetting VAT and fee-diff effects. Vs MS Net, bundled is under by 3.4 p.p.

**Conclusion:** the existing pipeline does its job well for configured bundles. Gaps are architectural (Price=0 bundles, empty InnerProducts, partial-purchase) and responsible for minor remaining error. No urgent fixes needed for FP-42870 scope — main recommendations for producer are in status/summary.

### 17. /Stats/Money already consumes bundle-aware data

Controller `StatsController.Money()` → `MoneyModel.Fill()` → `MonetizationProvider.GetStatsTransactions()` queries `VW_TransactionFact_Bundled`. So producer's money reports are **already** bundle-corrected for detected bundles.

Two price modes via `EnvironmentVariableCache.ShowRealPricesOn`:
- `true` (default): uses `EquivalentPrice` (local→USD via market rate, minus 38% fee)
- `false`: uses `ProductPriceUsd` (base Product.Price in USD, no fee)

Categories reported:
- `InGame` = ProductTypeId IN (1,3,4) — Money Pack, Premium Account, Pond Pass
- `Starter` = ProductTypeId = 2 — everything else (DLCs, packs, bundles — legacy label)

## Nov 2025 comparison (baseline) — 2026-04-21

Prod extraction: 16,554 transactions for `PaymentSystemId IN ('XBox','Win10')`, all `Status=Complete`, all prices filled.

**Count comparison vs MS Purchase units:**
- Our: 16,554 | MS: 15,558 | Excess: +996 (~6.4%)
- Excess concentrated in top currencies (USD/EUR/GBP account for ~890 of the 996)
- **12 rare/mid currencies match exactly** (SAR, KRW, SGD, KWD, COP, MYR, RON, THB, CLP, CZK, MXN, HUF) — confirms per-transaction recording is correct
- Excess on bundle components is ~100 per Ultimate Sport Bundle component (matches 104 MS bundle sales × 10 components — 1040 expected bundle-expansion rows)

**Product comparison:**
- 107 ForeignProductIds on our side, 113 on MS — 7 "MS-only" (all Starter Kits, see Finding #11)
- 1 "our-only" product (ForeignProductId `9NN1J59HBFDQ`, 2 transactions) — low priority, probably stale mapping or data edge case

## Plan

Bundle detection already lives in Stats DB (Finding #12), so the task shifts from "build a tool" to "audit the existing pipeline and quantify its gaps". Remaining work:

1. **Compare prices per currency in matched cells** — for currencies where unit counts match exactly (12 rare ones), verify revenue sums match. If yes, conversion math is sound; if no, regional pricing or exchange-rate logic is off.
2. **Quantify detection gaps** — count transactions with `BundleTransactionId IS NULL` that match a bundle's `InnerProductIds` but were missed due to partial-purchase / 30s-window / empty-InnerProducts cases.
3. **Estimate producer-visible drift** — compare `/Stats/Money` output vs MS royalty statement for the same period, per platform, per currency.
4. **Decide on corrective actions** — fix BIG HOLIDAY BUNDLE config; consider widening detection window; document partial-purchase limitation for producer.

### Open questions

- Does `TransactionFact.ProductPriceUsd` use market rates or Products.Price? (affects comparison with MS contract rates)
- Why do Halloween/Advanced/Deluxe Starter Packs produce 0 Transactions while being sold on MS? Client-side SDK issue, or server-side handling via different path?

## Milestones

### 2026-04-22 — Producer report published

Delivered: comment on FP-42870 summarizing the 5-month reconciliation and 7 ranked improvement proposals.

Source artifact: `artifacts/report.md`. Analyst query reference: `artifacts/analytic-queries-from-mary-k.sql`. JIRA comment ID: 115966.

Key outcomes:
- Xbox/Win10 revenue in `/Stats/Money` under-reports MS Net royalty by ~2% on average (range −4.3% to +4.2% across Jul–Nov 2025)
- Bundle detection pipeline in Stats DB works losslessly (97.9% of configured bundles detected; 3 misses = partial-purchase architectural limit)
- VAT identified as dominant contributor to the 38%-vs-30% fee gap
- MS Store promotional sales identified as a separate revenue-inflation factor (cause of Oct 2025 over-report)
- ARS/CLP/COP currency bugs quantified as negligible (~0.046% revenue) — low priority follow-up
