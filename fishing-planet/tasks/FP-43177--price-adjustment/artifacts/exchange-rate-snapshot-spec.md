# Exchange Rate Snapshot for Regional Pricing

**Date:** 2026-04-13

## Summary

Add manual exchange rate management to RegionalPriceRates. LiveOps can review current vs. live exchange rates and
selectively update (snapshot) them. Prices remain stable until LiveOps explicitly triggers an update.

## Motivation

Currently `RegionalPriceRates.ExchangeRate` is a calculated field fetched from `MonetizationCache` on every grid load.
This means regional prices fluctuate daily as the cache refreshes from the CurrencyFreaks API. Per FP-43177 agreement (
Rudakov, 2026-04-08), LiveOps needs explicit control: exchange rates should remain fixed until manually updated.

## Architecture: Column + SQL View (Approach C)

Store `ExchangeRate` directly in `RegionalPriceRates` (simple, self-contained rows). A SQL View aggregates unique
currencies for the update page.

## Data Schema

### New columns in `RegionalPriceRates`

```sql
ALTER TABLE RegionalPriceRates
    ADD ExchangeRate decimal(38, 20) NOT NULL DEFAULT 1,
        ExchangeRateTimestamp datetime NULL;
```

Migration script populates from current live rates:

```sql
UPDATE r
SET r.ExchangeRate          = ISNULL(c.ExchangeRate, 1),
    r.ExchangeRateTimestamp = c.RefreshTimestamp FROM RegionalPriceRates r
LEFT JOIN CurrencyExchangeRates c
ON r.Currency = c.TargetCurrency;
```

### New SQL View: `VW_ExchangeRateUpdates`

One row per `RegionalPriceRates` entry. Straight JOIN on `CurrencyExchangeRates` — no aggregation needed (unique index
on `(PlatformId, Currency, Country)` guarantees no duplicates). LiveOps can update exchange rates with
per-platform/country granularity.

```sql
CREATE VIEW VW_ExchangeRateUpdates AS
SELECT r.RateId,
       r.PlatformId,
       r.Currency,
       r.Country,
       r.ExchangeRate                                                AS CurrentRate,
       r.ExchangeRateTimestamp                                       AS CurrentRateTimestamp,
       ISNULL(c.ExchangeRate, r.ExchangeRate)                        AS NewRate,
       c.RefreshTimestamp                                            AS NewRateTimestamp,
       DATEDIFF(MINUTE, r.ExchangeRateTimestamp, c.RefreshTimestamp) AS AgeDiffMinutes,
       CASE
           WHEN r.ExchangeRate = 0 THEN 0
           ELSE (ISNULL(c.ExchangeRate, r.ExchangeRate) - r.ExchangeRate)
                    / r.ExchangeRate * 100
           END                                                       AS DeviationPercent
FROM RegionalPriceRates r
         LEFT JOIN CurrencyExchangeRates c ON r.Currency = c.TargetCurrency;
```

### Update `VW_ProductLocalPrices`

Add `rt.ExchangeRate` to the existing SELECT (JOIN on `RegionalPriceRates rt` already exists):

```sql
SELECT plp.*,
       p.Price         AS BasePrice,
       p.DiscountPrice AS BaseDiscountPrice,
       pl.Name         AS Platform,
       r.Name          AS Region,
       rt.Rate,
       rt.MinimalUnit,
       rt.RoundingAmount,
       rt.RoundingType,
       rt.Beautify,
       rt.ExchangeRate
           ...
```

## Exchange Rate Scope

| Consumer                              | Source after change                                                          |
|---------------------------------------|------------------------------------------------------------------------------|
| `RegionalPriceRatesModel.GetData()`   | `entity.ExchangeRate` from DB (was `MonetizationCache`)                      |
| `ProductLocalPricesModel.GetData()`   | `entity.ExchangeRate` from `VW_ProductLocalPrices` (was `MonetizationCache`) |
| Game server (MonetizationHelper, etc) | `MonetizationCache` — unchanged                                              |
| `RefreshCurrencyExchangeRatesJob`     | `CurrencyExchangeRates` — unchanged                                          |

## DAL Layer

### `IMonetizationProvider`

New method:

```csharp
Task<int> SnapshotExchangeRatesForRegionalPricingAsync(
    IDictionary<int, (decimal Rate, DateTime Timestamp)> ratesByRateId);
```

### `SqlMonetizationProvider`

UPDATE `RegionalPriceRates` rows by `RateId`, wrapped in `TransactionScope`. Pattern follows
`SqlCurrencyExchangeRateProvider.UpdateExchangeRates()`.

```sql
UPDATE RegionalPriceRates
SET ExchangeRate          = @Rate,
    ExchangeRateTimestamp = @Timestamp
WHERE RateId = @RateId
```

Returns total number of rows updated.

### `RegionalPriceRateDto`

Add fields:

```csharp
public decimal ExchangeRate { get; set; }
public DateTime? ExchangeRateTimestamp { get; set; }
```

## WebAdmin UI

### Button on RegionalPriceRates page

Add "Update Exchange Rates" button to `RegionalPriceRates.cshtml` toolbar. Links to the new page:

```html
<a href="/Home/EditData?tableName=VW_ExchangeRateUpdates&lang=3"
   class="k-button" title="Review and update saved exchange rates">
    Update Exchange Rates
</a>
```

Not added to the navigation menu — accessible only from RegionalPriceRates.

### New page: VW_ExchangeRateUpdates

Kendo Grid (read-only, no inline editing) with columns:

| Column       | Source                 | Notes                                                      |
|--------------|------------------------|------------------------------------------------------------|
| ☑ Selected   | UI-only bool           | Select All checkbox in header (ProductLocalPrices pattern) |
| Platform     | `PlatformId` (FK)      | Platform name via ForeignKey lookup                        |
| Currency     | `Currency`             | Currency code                                              |
| Country      | `Country`              | Country code (empty = default)                             |
| Current Rate | `CurrentRate`          | Saved rate, monospace, N6 format                           |
| Saved        | `CurrentRateTimestamp` | When the rate was saved                                    |
| New Rate     | `NewRate`              | Live rate from CurrencyExchangeRates, monospace bold, N6   |
| Fetched      | `NewRateTimestamp`     | When the live rate was downloaded                          |
| Deviation    | `DeviationPercent`     | Signed %, green (+) up, red (−) down                       |
| Age          | `AgeDiffMinutes`       | Formatted "Xd Yh", orange >7d, red bold >30d               |

Buttons: **Update Selected**, **Update All**.

Grid settings: `CanAdd = false`, `CanSave = false`, `CanDelete = false`.

### New files

| File                                             | Purpose                                                |
|--------------------------------------------------|--------------------------------------------------------|
| `Models/Entities.cs`                             | New `ExchangeRateUpdate` entity with `Selected` bool   |
| `Models/Monetization/ExchangeRateUpdateModel.cs` | `TableEditModel<ExchangeRateUpdate>`, grid config, r/o |
| `Views/Home/VW_ExchangeRateUpdates.cshtml`       | Razor view with grid, buttons, Select All JS           |

### Controller endpoint

```csharp
[HttpPost]
[CustomAuthorize(Roles = "RW")]
public async Task<ActionResult> UpdateExchangeRates(List<ExchangeRateUpdateItem> rates)
```

In `HomeController.cs`. Calls `DalFactory.GetMonetizationProvider().SnapshotExchangeRatesForRegionalPricingAsync(...)`.
Logs via `AdminActionLog`.

## Changes to Existing Code

### `RegionalPriceRates` entity (`Entities.cs`)

- `ExchangeRate`: remove `[CalculatedField]`, keep `[Readonly]`
- Add `ExchangeRateTimestamp`: `[Readonly]`, `[Hidden]` in RegionalPriceRates grid

### `RegionalPriceRatesModel.GetData()`

Remove `entity.ExchangeRate = MonetizationCache.GetCurrencyExchangeRate(entity.Currency)` — value now comes from DB row.

### `ProductLocalPricesModel.GetData()`

Replace `MonetizationCache.GetCurrencyExchangeRate()` with `entity.ExchangeRate` from the updated
`VW_ProductLocalPrices` view.

### `ProductLocalPricesExt` entity (`Entities.cs`)

Add `ExchangeRate` property to receive the field from the updated view.
