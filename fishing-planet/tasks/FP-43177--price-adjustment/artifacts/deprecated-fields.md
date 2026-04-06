---
title: Deprecated Fields in RegionalPriceRates
status: approved
related: smart-beautify-v1.md
---

# Deprecated Fields in RegionalPriceRates

With the introduction of the Smart Beautify algorithm (see [smart-beautify-v1.md](smart-beautify-v1.md)),
three fields in the `RegionalPriceRates` table become logically unused. They are kept in the DB schema
for now; removal is deferred until GD validates the new logic in production.

## RoundingAmount (decimal)

**What it did:** Explicit rounding denominator for price calculation. The old formula rounded
`rawPrice` to the nearest multiple of this value: `round(raw / roundingAmount) * roundingAmount`.

**How it was configured:**
- Must be ≥ MinimalUnit and evenly divisible by it
- Auto-defaulted to MinimalUnit if set to 0
- Typical values: 0.01 (USD, EUR), 1 (UAH, JPY), 10 (KRW), 500 (VND)
- In practice, almost always equaled MinimalUnit (see `PopulateRegionalPriceRates.sql` line 36)

**Why it's replaced:** The new algorithm derives three step sizes directly from MinimalUnit:
`unit×10` (bronze), `unit×100` (silver), `unit×1000` (gold). No separate parameter needed.

**Code references:**
- DTO: `RegionalPriceRateDto.RoundingAmount` — `Dal/Sql.Interface/Monetization/RegionalPriceRateDto.cs`
- Calculator: `LocalPriceCalculator.CalculateRegionalPrice()` param `roundingAmount` — `Shared/SharedLib/Monetization/LocalPriceCalculator.cs`
- Validation: `RegionalPriceRatesModel.ValidatePriceRate()` — `WebAdmin/WebAdmin/Models/Monetization/RegionalPriceRatesModel.cs` (lines 88-92)
- Fallback: `ProductLocalPricesModel` uses `price.RoundingAmount ?? price.MinimalUnit.Value`

## RoundingType (int → RoundingRule enum)

**What it did:** Explicit control over rounding direction when snapping to RoundingAmount grid.

**Values:**

| Value | Enum      | Math function  |
|-------|-----------|----------------|
| 0     | `Closest` | `Math.Round`   |
| 1     | `Up`      | `Math.Ceiling` |
| 2     | `Down`    | `Math.Floor`   |

**How it was configured:**
- Default: 0 (Closest) in `PopulateRegionalPriceRates.sql`
- In practice, almost always Closest — up/down used rarely if ever
- UI rendered as dropdown via `[Enum(typeof(LocalPriceCalculator.RoundingRule))]` attribute in Entities.cs

**Why it's replaced:** The new algorithm determines direction automatically from the Rate (region coefficient):
- Rate ≥ 1 (premium/parity region) → candidates rounded UP preferred
- Rate < 1 (discount region) → candidates rounded DOWN preferred

This is applied per-tier with preference logic, not a single global rule.

**Code references:**
- Enum: `LocalPriceCalculator.RoundingRule` — `Shared/SharedLib/Monetization/LocalPriceCalculator.cs`
- DTO: `RegionalPriceRateDto.RoundingType` — `Dal/Sql.Interface/Monetization/RegionalPriceRateDto.cs`
- UI attribute: `Entities.cs` RegionalPriceRates class, line ~1895
- Switch: `LocalPriceCalculator.cs` lines 40-51

## Beautify (bool)

**What it did:** After rounding, subtract one MinimalUnit to create "psychological" prices
(e.g. 10.00 → 9.99, 1000 → 999).

**Condition:** Only applied when `roundingAmount > minimalUnit` — if they were equal,
subtraction would produce a price below the rounding grid.

**How it was configured:**
- Default: false (0) in `PopulateRegionalPriceRates.sql`
- Simple on/off toggle in UI

**Why it's replaced:** In the new algorithm, the `-unit` subtraction is built into every
tier candidate: `ceil(raw / step) × step - unit`. Beautification is always active and
integral to the formula — not a separate toggle.

**Code references:**
- DTO: `RegionalPriceRateDto.Beautify` — `Dal/Sql.Interface/Monetization/RegionalPriceRateDto.cs`
- Calculator: `LocalPriceCalculator.cs` line 26-27: `if (beautify && roundingAmount > minimalUnit) roundedAmount -= minimalUnit`
- Fallback: `ProductLocalPricesModel` uses `price.Beautify ?? false`

## Migration Plan

Fields remain in the DB schema and DTO during the transition period. Removal steps (deferred to a separate task after GD validates new logic):

1. Drop columns `RoundingAmount`, `RoundingType`, `Beautify` from `RegionalPriceRates` table
2. Remove corresponding properties from `RegionalPriceRateDto`
3. Remove `RoundingRule` enum from `LocalPriceCalculator`
4. Remove validation logic in `RegionalPriceRatesModel.ValidatePriceRate()`
5. Remove fallback logic in `ProductLocalPricesModel`
6. Update `VW_ProductLocalPrices` view (remove columns)
7. Update `RegionalPriceRates.cshtml` grid (remove columns from UI)
8. Update `PopulateRegionalPriceRates.sql` seed script
