---
title: Smart Beautify Algorithm
version: 1
status: approved
source: Google Sheets "Regional Pricing" + vibe-coded C# from task author
approved_by: GD (Stanislav Rudakov)
approved_date: 2026-04-02
---

# Smart Beautify Algorithm

## Core Formula

```
raw = baseRegionalPrice × exchangeRate
```

Where `baseRegionalPrice = originalUsdPrice × regionCoefficient`.

## Three-Tier Beautification

| Tier   | Step (`minimalUnit` < 1) | Step (`minimalUnit` ≥ 1) | Produces prices like |
|--------|--------------------------|--------------------------|----------------------|
| Gold   | 10                       | `minimalUnit` × 1000     | 9999, 999            |
| Silver | 1                        | `minimalUnit` × 100      | 99, 199              |
| Bronze | 0.1                      | `minimalUnit` × 10       | 9.9, 19              |

For each tier, two candidates: `ceil(raw / step) × step - minimalUnit` (up) and `floor(raw / step) × step - minimalUnit` (down).

## Rules

1. **3% Snap Window** — a beauty candidate is valid only if `|candidate - raw| / raw ≤ 3%`
2. **Bronze-Dependent Priority** — Gold beats Silver only if extra deviation cost ≤ threshold (0.5% for raw < 100, 1.5%
   for raw ≥ 100)
3. **Tier Priority** — Gold > Silver > Bronze (within 3% window)
4. **Direction by Coefficient** — coef ≥ 1 (premium) → prefer UP; coef < 1 (discount) → prefer DOWN
5. **Grid Fallback** — if no beauty found and `minimalUnit` ≥ 1: use `round(raw / minimalUnit) × minimalUnit` if deviation < 5%
6. **Bronze-Aware Fallback** — if nothing else: use Bronze step up/down (by coefficient direction)
7. **Minimal Unit Guard** — `max(minimalUnit, result)`, final round to 2 decimal places
8. **Precision** — declared as 4dp for distance checks; actual implementation uses full `decimal` precision (better)

## Reference Implementation (C#)

```csharp
public static decimal CalculateRegionalPrice(
    decimal baseRegionalPrice, decimal exchangeRate,
    decimal unit, decimal coefficient)
{
    if (baseRegionalPrice <= 0m || exchangeRate <= 0m) return 0m;

    decimal rawPrice = baseRegionalPrice * exchangeRate;

    // 1. Calculate Target Steps
    decimal silverStep = unit < 1m ? 1m : unit * 100m;
    decimal silverUp = Math.Ceiling(rawPrice / silverStep) * silverStep - unit;
    decimal silverDown = Math.Floor(rawPrice / silverStep) * silverStep - unit;

    decimal strengthStep = unit < 1m ? 10m : unit * 1000m;
    decimal strengthUp = Math.Ceiling(rawPrice / strengthStep) * strengthStep - unit;
    decimal strengthDown = Math.Floor(rawPrice / strengthStep) * strengthStep - unit;

    decimal bronzeStep = unit < 1m ? 0.1m : unit * 10m;
    decimal bronzeUp = Math.Ceiling(rawPrice / bronzeStep) * bronzeStep - unit;
    decimal bronzeDown = Math.Floor(rawPrice / bronzeStep) * bronzeStep - unit;

    // 2. Deviation Guards (<= 3%)
    decimal chkStrengthUp = Math.Abs(strengthUp - rawPrice) / rawPrice <= 0.03m ? strengthUp : 0m;
    decimal chkStrengthDown = Math.Abs(strengthDown - rawPrice) / rawPrice <= 0.03m ? strengthDown : 0m;
    decimal chkSilverUp = Math.Abs(silverUp - rawPrice) / rawPrice <= 0.03m ? silverUp : 0m;
    decimal chkSilverDown = Math.Abs(silverDown - rawPrice) / rawPrice <= 0.03m ? silverDown : 0m;
    decimal chkBronzeUp = Math.Abs(bronzeUp - rawPrice) / rawPrice <= 0.03m ? bronzeUp : 0m;
    decimal chkBronzeDown = Math.Abs(bronzeDown - rawPrice) / rawPrice <= 0.03m ? bronzeDown : 0m;

    // 3. Strict Grid Target
    decimal grid = Math.Round(rawPrice / unit, MidpointRounding.AwayFromZero) * unit;

    // 4. Resolve Best Silver Target
    decimal bestSilver;
    if (chkSilverUp > 0m && chkSilverDown > 0m)
        bestSilver = coefficient >= 1m ? chkSilverUp : chkSilverDown;
    else if (chkSilverUp > 0m)
        bestSilver = chkSilverUp;
    else
        bestSilver = chkSilverDown;

    // 5. Core Beauty Logic
    decimal beauty = 0m;
    if (chkStrengthUp > 0m || chkStrengthDown > 0m)
    {
        decimal str;
        if (chkStrengthUp > 0m && chkStrengthDown > 0m)
            str = coefficient >= 1m ? chkStrengthUp : chkStrengthDown;
        else if (chkStrengthUp > 0m)
            str = chkStrengthUp;
        else
            str = chkStrengthDown;

        decimal costThreshold = rawPrice < 100m ? 0.005m : 0.015m;

        if (bestSilver > 0m)
        {
            if ((Math.Abs(str - rawPrice) / rawPrice)
              - (Math.Abs(bestSilver - rawPrice) / rawPrice) <= costThreshold)
                beauty = str;
            else
                beauty = bestSilver;
        }
        else
            beauty = str;
    }
    else if (bestSilver > 0m)
    {
        beauty = bestSilver;
    }
    else if (chkBronzeUp > 0m || chkBronzeDown > 0m)
    {
        if (chkBronzeUp > 0m && chkBronzeDown > 0m)
            beauty = coefficient >= 1m ? chkBronzeUp : chkBronzeDown;
        else if (chkBronzeUp > 0m)
            beauty = chkBronzeUp;
        else
            beauty = chkBronzeDown;
    }

    // 6. Final Selection and Fallbacks
    decimal finalPrice;
    if (beauty > 0m)
        finalPrice = beauty;
    else if (unit >= 1m && (Math.Abs(grid - rawPrice) / rawPrice) < 0.05m)
        finalPrice = grid;
    else
        finalPrice = coefficient >= 1m ? bronzeUp : bronzeDown;

    return Math.Round(Math.Max(unit, finalPrice), 2, MidpointRounding.AwayFromZero);
}
```

## Comparison with Current `LocalPriceCalculator`

| Aspect             | Current                       | Smart Beautify v1                          |
|--------------------|-------------------------------|--------------------------------------------|
| Beautify           | Single: `rounded - unit`      | Three tiers (gold/silver/bronze)           |
| Deviation control  | None                          | ≤ 3% window                                |
| Rounding direction | Explicit `RoundingType` param | Auto from coefficient (≥1 → up, <1 → down) |
| `RoundingAmount`   | Explicit param                | Derived from `unit`                        |
| `Beautify` flag    | Explicit param                | Always on (beauty is the algorithm)        |
| Fallback           | None                          | Grid → Bronze step                         |

Fields `RoundingAmount`, `RoundingType`, `Beautify` in `RegionalPriceRates` become unnecessary — all logic derives from
`Rate` and `MinimalUnit`.

## Deprecated Fields

Three fields in `RegionalPriceRates` become logically unused: `RoundingAmount`, `RoundingType`, `Beautify`.
Kept in DB schema during transition; removal deferred to a separate task after GD validates new logic.
See [deprecated-fields.md](deprecated-fields.md) for full documentation.

## Implementation Notes

- Algorithm constants must be extracted as named constants with documentation explaining
  what each one controls. Currently fixed values; extracted for code clarity and to simplify
  making them configurable in the future if needed:
  - `BeautySnapMaxDeviation` = 0.03 (3% — max allowed deviation for a beauty candidate)
  - `CostThresholdLow` = 0.005 (0.5% — Gold vs Silver preference margin for raw < 100)
  - `CostThresholdHigh` = 0.015 (1.5% — Gold vs Silver preference margin for raw ≥ 100)
  - `CostThresholdBoundary` = 100 (raw price boundary between low/high thresholds)
  - `GridFallbackMaxDeviation` = 0.05 (5% — max deviation for grid-aligned fallback)
- Discount price uses the same algorithm (same formula, `baseDiscountPrice × rate` as input).
- Direction by coefficient is intentional and confirmed by GD — regions with Rate=1.0 round UP.

