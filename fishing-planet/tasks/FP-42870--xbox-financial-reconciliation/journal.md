---
task: FP-42870
title: "Xbox. Compare financial indicators by platform"
status: investigating
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-42870
related:
  - FP-41929
---

## Status

Brainstorming in progress (2026-03-27). Data sources identified, key discrepancies found, draft plan outlined. Still need to: examine XLS fully (RETURNS section), check real DB data (ProductMappings, Transactions), solve product mapping. Code and sensitive data will go to a separate private scripts repo.

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

## Key Findings (2026-03-27)

### 1. Fee discrepancy: 38% vs 30%

Our `EquivalentPrice` uses FeePercent=38 (we keep 62%). Microsoft Royalty Rate = 0.70 (we get 70%).

Example — Chamaeleon Cruiser Pack at $59.99:
- MS Wholesale: $59.99 × 0.70 = **$41.99**
- Our EquivalentPrice: $59.99 × 0.62 = **$37.19**
- Difference: ~13%

**Hypothesis:** FeePercent=38 was set empirically, likely accounts for:
- Currency conversion losses and exchange rate fluctuations
- Amounts Uncollectable (chargebacks, failed payments) — which we don't track separately
- Returns/refunds — also not tracked in our system
- Needs verification: is 38% explained by these factors, or is it just wrong?

### 2. "Amounts Uncollectable" — invisible to us

MS XLS contains negative entries (Transaction Type = "Amounts Uncollectable", Royalty Rate = -1) — chargebacks, failed payments. We have **no record** of these in Transactions (Status is always "Complete"). This could be a significant hidden loss.

### 3. RETURNS section

Lower in the XLS there appears to be a RETURNS section — not yet examined. Could account for refund-based exploits suspected in FP-41929. **TODO: examine this section.**

### 4. Product mapping is unsolved

- `ForeignProductId` in our `ProductMappings` table (alphanumeric like `"BNQSGPT638M1"`) does not appear anywhere in the XLS
- Product Name suffixes in XLS (numeric like `_OGP_22819`) don't match ForeignProductId
- Title ID is always "Non English Title ID" — useless

**Mapping approaches to try:**
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

## Plan

### Step 1: Product mapping

Find a reliable way to map MS product names to our ProductId.
- Try client price-loading logs (may contain mapping clues)
- Fallback: semi-manual mapping by parsing distinctive product names from both sources

### Step 2: Parse XLS

PHP tool (PhpSpreadsheet) to read ILS sheet from row 10:
- Group by Product Name + Currency
- Sum across Payment Methods (CREDITCARD + PAYPALPAYIN)
- Separate Amounts Uncollectable and RETURNS into distinct categories
- Output: intermediate table {Product, Currency, Units, Royalty, Uncollectable, Returns}

### Step 3: Extract from our DB

SQL query for the same month:
```sql
SELECT
    t.ProductId,
    p.Name AS ProductName,
    t.Currency,
    COUNT(*)          AS Units,
    SUM(t.Price)      AS TotalPrice,
    SUM(t.EquivalentPrice) AS TotalEquivalentPrice
FROM Transactions t
JOIN Products p ON p.ProductId = t.ProductId
WHERE t.PaymentSystemId IN ('XBox', 'Win10')
  AND t.Timestamp >= @StartDate
  AND t.Timestamp < @EndDate
GROUP BY t.ProductId, p.Name, t.Currency
```

### Step 4: Join and compare

Via product mapping, join both datasets on (Product, Currency). Compare:
- Unit counts (our count vs MS "Sum of Purchase Units")
- Revenue (our TotalPrice vs MS "Retail Price × Units"; our TotalEquivalentPrice vs MS "Sum of Royalty USD")

### Step 5: Deep dive — rare currencies

Start detailed per-transaction matching with KWD/CHF — low volume makes manual verification feasible. If discrepancies found here, extrapolate to USD.

### Open questions

- What period to start with? (which .xlsm files are available?)
- Examine RETURNS section in XLS — scope and structure
- Verify FeePercent=38 rationale — is it documented anywhere?
- Can we access client price-loading logs?

## Tooling

PHP/Laravel project. Components:
- **XLS parser** — PhpSpreadsheet, reads ILS sheet from row 10, handles grouped structure
- **DB connector** — query Transactions + Products + ProductMappings on prod
- **Mapping config** — JSON or DB table, built incrementally
- **Report generator** — comparison table with discrepancies highlighted

## Milestones
