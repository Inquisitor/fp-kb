# FP-42870 — Xbox/Win10 revenue reconciliation against Microsoft royalty

## Summary

A reconciliation of Xbox/Win10 revenue against Microsoft royalty statements has been completed for **5 months (Jul–Nov 2025)**. Figures in `/Stats/Money` are reasonably accurate at the aggregate level, but contain several structural distortions worth being aware of.

Main takeaway: the current empirical **FeePercent=38%** works as a calibration — averaged across the period, the estimate under-reports the actual MS Net royalty by **~2%**. This is the net effect of several factors pulling in opposite directions. Per-month and per-currency figures can diverge more significantly: monthly gap ranged from **−4.3% to +4.2%**, and per-currency skew reaches ±10–12 p.p. (USD under-reported by ~11%, HUF over-reported by ~12%).

## Reconciliation findings

After bundle detection, the transaction count differs from MS Purchase units by only **~0.3%** on average (max +1% in any month). Revenue (`EquivalentPrice` with current `FeePercent=38`) tracks MS Net royalty within a few percentage points in most months.

Per-month gap between `/Stats/Money` aggregate and MS Net royalty:

| Month              |       Gap | Direction       |
|--------------------|----------:|-----------------|
| Jul 2025           |     −4.3% | under-report    |
| Aug 2025           |     −2.3% | under-report    |
| Sep 2025           |     −3.5% | under-report    |
| Oct 2025           | **+4.2%** | **over-report** |
| Nov 2025           |     −3.4% | under-report    |
| **Avg (weighted)** | **≈ −2%** |                 |

Four of five months show a consistent under-report of 2–4%. **October is the outlier**: several high-volume products in EUR/GBP went on MS Store sale that month, inflating the recorded revenue against the lower amounts MS actually collected (see factor #5 below). This is not a regression of our pipeline — it's a distortion that becomes visible only when specific conditions coincide (large products × sale × VAT currencies).

## Why the gap exists — 5 factors

**1. Local VAT.** MS deducts local VAT (7–27% depending on country) before calculating its 30% commission. Gross amount (with tax) is recorded on our side. The 38% fee is an empirical adjustment that partially compensates for this at the aggregate level, but distorts per-currency figures: USD is under-estimated by ~11%, HUF is over-estimated by ~12%.

**2. Bundle detection.** When a player buys a bundle on Xbox, the client SDK sends the server not the bundle itself but its components individually. N rows are written in `Transactions` at component prices, not a single row at the bundle price. Good news: automatic bundle detection in Stats DB closes this gap at **~98%** across all 5 months. Remaining misses are partial-purchase cases where the player already owned some components and the SDK sent only a subset.

**3. RETURNS + Amounts Uncollectable.** MS deducts refunds and uncollectable amounts from its payments. These are not visible in the DB — transactions remain with status `Complete`. Monthly impact ranges from **1.5% to 2.9%** of royalty, averaging around 2%.

**4. Regional currencies and region pricing.** For several rare currencies (ARS, CLP, COP) there is a bug in price recording — the USD equivalent is stored instead of the local amount. ARS bug is consistently present across all 5 months; CLP/COP bugs are intermittent. Impact is negligible at aggregate level (<0.05% of revenue), but MS's regional pricing mechanics are not precisely reflected in the data either — adds noise at the level of a few percent in specific regions.

**5. MS Store promotional sales.** Microsoft periodically discounts products (seasonal promotions, holiday sales). When a player buys at the sale price, the client records the catalog (base) price in `Transactions.Price` instead of the actually paid amount. This inflates our reported revenue. Sales happen every month, but their impact on the aggregate is only visible when high-volume products in VAT currencies go on sale — that's exactly what drove the October +4.2% over-report. Royalty statements don't mark discounted rows with a dedicated flag — sales can only be inferred post-hoc by comparing `Retail Price Per Unit` against our catalog price.

## Contribution of each factor to the discrepancy

Estimates for a typical month (Nov 2025 as sample), in percentage points of MS Purchase royalty (= 100%). Magnitudes vary month-to-month for factors #2, #3, #5:

| Factor                                            | Direction                      | Magnitude                                                                   |
|---------------------------------------------------|--------------------------------|-----------------------------------------------------------------------------|
| Fee difference: our 38% vs MS 30%                 | Reduces the estimate           | ≈ −12 p.p.                                                                  |
| VAT not stripped on our side                      | Inflates the estimate          | ≈ +6.6 p.p.                                                                 |
| Bundle expansion (pre-detection)                  | Inflates the estimate          | ≈ +1.6 p.p. (near 0 after detection)                                        |
| MS Store promotional sales (catalog vs paid)      | Inflates the estimate          | Variable; up to ~+5 p.p. in months with high-volume sales on VAT currencies |
| RETURNS + Amounts Uncollectable (invisible to us) | Reduces (MS deducts, we don't) | ~ −2 p.p.                                                                   |
| ARS/CLP/COP price recording bugs                  | Reduces the estimate           | Negligible (<0.05 p.p.)                                                     |
| **Total: EquivalentPrice @38% vs MS Net**         | **Under-report**               | **≈ −2 p.p.** (averaged over the period)                                    |

In other words, 38% empirically offsets the sum of the other factors — but only at the aggregate level. Per-country and per-currency skew remains: where VAT is high (EU), the estimate is inflated; where VAT is 0 (US, Canada), the estimate is understated.

**Important implication:** fixing just one factor in isolation can make the aggregate gap *worse*, because the current balance relies on compensating errors. For example, if we start recording the actually paid price during sales (factor #5) without also reducing the fee from 38% to 30% (factor #1), the under-report will grow. Improvements should be planned as a package, not piece by piece.

## What works well

- Bundle detection in Stats DB — ~98% for configured products (Ultimate Sport, Lucky). The production ETL losslessly reproduces the algorithm, verified by simulation.
- Product mapping MS ↔ DB — 100% coverage across all 5 months (every Offer GUID sold on MS side resolves to a `ProductMappings.ForeignProductId`).
- Individual transaction recording is reliable — for 12 rare currencies the count matches MS exactly to the unit.

## Proposed improvements

| Proposal                                                                                                                                                                                       | Potential effect                                                                                                       | Impact | Difficulty                    |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------|--------|-------------------------------|
| VAT-aware calculation in Stats ETL, reducing `FeePercent` to 30%                                                                                                                               | Removes per-currency distortions (currently ±10–12 p.p. in individual countries), revenue becomes accurate per country | High   | Medium                        |
| Xbox Store refund webhook for real-time clawback                                                                                                                                               | Per-user attribution, ability to reclaim items on refund                                                               | High   | High (research + integration) |
| Monthly import of MS royalty adjustments (returns + uncollectable) into revenue reports from .xlsm                                                                                             | Removes the ~2% aggregate under-count                                                                                  | Medium | Low                           |
| Record actual paid price in `Transactions.Price` (handle MS Store sales)                                                                                                                       | Removes revenue overstatement during promotional periods                                                               | Medium | Medium (client change)        |
| Delist obsolete bundles (Christmas/Halloween/Starter Packs/BIG HOLIDAY) — unlist on MS Partner Center and set `IsOnStorefront=0` in our `Products` (records stay in DB for historical reports) | Removes stale items from the store and from reconciliation noise; historical data preserved                            | Low    | Low                           |
| Inventory-based refund detection on login as a supplementary layer                                                                                                                             | Catches refunds missed by webhook; works only for active players                                                       | Low    | Medium                        |
| Sync local prices from Xbox SDK instead of our market-rate conversion                                                                                                                          | Solves regional pricing and currency bugs (ARS/CLP/COP) architecturally                                                | Low    | High                          |

## Points for discussion

- How important is accuracy at the country/currency level. If correct per-country reports are needed, VAT-aware calculation is the priority. If aggregate revenue per period is sufficient, importing returns/uncollectable from .xlsm is enough.
- Whether real-time item clawback on refund is needed. If critical for game economy, it makes sense to explore webhooks. If knowing the amounts is sufficient, aggregate import will do.
- Whether to delist obsolete bundles from MS Partner Center and hide them from our storefront (records remain in DB for historical reports). This will simplify future reconciliation.
- Whether to treat the improvements as a single coordinated package (one release with all fixes + FeePercent change) or to ship them incrementally with active monitoring of the aggregate gap.

On request, separate tickets can be prepared for each proposal with a detailed scope.
