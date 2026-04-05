---
title: "FP-43177 Implementation Spec: Smart Beautify"
status: approved
date: 2026-04-05
related:
  - smart-beautify-v1.md
  - deprecated-fields.md
---

# FP-43177 Implementation Spec

## Scope

Replace the price calculation algorithm in `LocalPriceCalculator` with the Smart Beautify algorithm.
Update all callers and the WebAdmin UI. Keep deprecated fields in DB/DTO for the transition period.

## 1. New Method — `LocalPriceCalculator.CalculateRegionalPrice()`

### Signature

```csharp
public static decimal CalculateRegionalPrice(
    decimal basePrice, decimal priceRate, decimal currencyExchangeRate,
    decimal minimalUnit, out string report)
```

- `basePrice` — original USD price
- `priceRate` — regional coefficient (multiplier AND direction selector)
- `currencyExchangeRate` — USD to local currency rate
- `minimalUnit` — smallest currency unit allowed by platform
- `report` — detailed decision trace (see section 3)

Parameters removed vs. old signature: `roundingAmount`, `roundingRule`, `beautify`.

### Algorithm

Three-tier smart beautify as defined in [smart-beautify-v1.md](smart-beautify-v1.md).
Internally computes `baseRegionalPrice = basePrice × priceRate`, then uses `priceRate` as
the direction coefficient.

### Constants

Extracted as named constants with XML doc comments in `LocalPriceCalculator`:

```csharp
/// <summary>Max allowed deviation for a beauty snap candidate.</summary>
private const decimal BeautySnapMaxDeviation = 0.03m;

/// <summary>Max extra deviation cost to prefer Strong over Elite tier (raw price below threshold boundary).</summary>
private const decimal CostThresholdLow = 0.005m;

/// <summary>Max extra deviation cost to prefer Strong over Elite tier (raw price at or above threshold boundary).</summary>
private const decimal CostThresholdHigh = 0.015m;

/// <summary>Raw price boundary: below this value CostThresholdLow applies, at or above — CostThresholdHigh.</summary>
private const decimal CostThresholdBoundary = 100m;

/// <summary>Max deviation for grid-aligned fallback (used when no beauty candidate is found).</summary>
private const decimal GridFallbackMaxDeviation = 0.05m;
```

## 2. Old Method — Deprecation

- Mark old overload with `[Obsolete("Use the new overload without rounding parameters. Scheduled for removal after GD validates the Smart Beautify algorithm.")]`
- Mark `RoundingRule` enum with `[Obsolete]`
- Keep private `Round()` method (used by old overload)
- Do NOT delete — cleanup is a separate task after GD validates new logic in production

## 3. Report — Full Decision Trace

The `out string report` must provide a complete trace of how the price was chosen.
GD will use this to verify the algorithm in the admin UI.

Contents:
1. **Inputs**: basePrice, priceRate, exchangeRate, minimalUnit
2. **Computed raw**: `baseRegionalPrice`, `rawPrice` (in local currency)
3. **Three tiers** — for each (Strong, Elite, Scale):
   - Step size
   - Up/Down candidates (values)
   - Deviation % from raw for each candidate
   - Pass/fail of 3% check
4. **Direction**: coefficient value, chosen direction (UP/DOWN)
5. **Tier selection**: which tier was chosen and why
   - If Strong vs Elite comparison: show cost threshold and margin
6. **Fallback** (if no beauty found): grid value, grid deviation, which fallback used
7. **Final result**: value, total deviation from raw %

## 4. Callers — 3 Call Sites

### ProductLocalPricesModel.cs (lines ~42-62)

Two calls (price + discount price). Change from:
```csharp
LocalPriceCalculator.CalculateRegionalPrice(
    (decimal)price.BasePrice, price.Rate.Value, exchangeRate,
    price.MinimalUnit.Value,
    price.RoundingAmount ?? price.MinimalUnit.Value,
    (LocalPriceCalculator.RoundingRule)(price.RoundingType ?? 0),
    price.Beautify ?? false, out priceReport);
```
To:
```csharp
LocalPriceCalculator.CalculateRegionalPrice(
    (decimal)price.BasePrice, price.Rate.Value, exchangeRate,
    price.MinimalUnit.Value, out priceReport);
```

### RegionalPriceRatesModel.cs (lines ~44-46)

Change to new signature, keep `out _` (report not used here).

### HomeController.cs (lines ~1179-1189)

Local function wrapper. Change to new signature, keep `out _`.

## 5. WebAdmin UI — Grid Changes

### RegionalPriceRates.cshtml

Hide columns from the Kendo grid:
- `RoundingAmount`
- `RoundingType`
- `Beautify`

Columns stay in the model/DTO (data still stored), just not shown in the grid.

### VW_ProductLocalPrices.cshtml

No changes to the grid itself. The `report` content displayed in the info popup will
automatically reflect the new algorithm trace.

## 6. Validation — No Changes

`RegionalPriceRatesModel.ValidatePriceRate()` stays as-is:
- Still validates Rate > 0 and MinimalUnit > 0
- Still auto-defaults `RoundingAmount = MinimalUnit` when 0 (covers hidden-column INSERT)
- `RoundingType` defaults to 0, `Beautify` defaults to false — valid for NOT NULL columns

No SQL patch needed — C# validation ensures valid values on INSERT.

## 7. What We Don't Touch

- DB schema (`RegionalPriceRates` table — columns stay)
- DTOs (`RegionalPriceRateDto` — properties stay)
- `VW_ProductLocalPrices` SQL view
- `PopulateRegionalPriceRates.sql` seed script
- Exchange rate refresh logic

## 8. Testing

### Acceptance Tests — Google Sheets Parity

Parameterized test with all 38 regions from the GD spec (basePrice=14.99):

| Country      | Currency | Rate | MinimalUnit | ExchangeRate | Expected Price |
|--------------|----------|------|-------------|--------------|----------------|

Values extracted from the Google Sheets "Regional Pricing" document. Each test verifies
that `CalculateRegionalPrice()` produces the exact same result as the spreadsheet.

### Unit Tests — Branch Coverage

Individual tests for each algorithm branch:
- **Tier selection**: Strong chosen, Elite chosen, Scale chosen
- **Direction**: coefficient ≥ 1 picks UP candidate, coefficient < 1 picks DOWN
- **Strong vs Elite comparison**: Strong wins within cost threshold, Elite wins when Strong is too expensive
- **Cost threshold boundary**: raw < 100 uses 0.005, raw ≥ 100 uses 0.015
- **3% guard**: candidate just inside 3%, candidate just outside 3%
- **Grid fallback**: unit ≥ 1, no beauty found, grid deviation < 5%
- **Scale fallback**: no beauty, no grid, falls to scale step
- **Minimal unit guard**: result forced up to minimalUnit when calculated value is below
- **Edge cases**: rate = 1.0 exactly, very small prices, very large prices, rate = 0 (should return 0)
- **Report**: verify report string contains all expected trace sections
