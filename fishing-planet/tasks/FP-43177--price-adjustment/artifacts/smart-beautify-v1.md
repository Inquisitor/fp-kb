# Smart Beautify Algorithm — v1 (First Approximation)

Source: Google Sheets "Regional Pricing" + vibe-coded C# from task author.
Status: **draft** — needs requirement refinement, possible additional features.

## Core Formula

```
raw = baseRegionalPrice × exchangeRate
```

Where `baseRegionalPrice = originalUsdPrice × regionCoefficient`.

## Three-Tier Beautification

| Tier     | Step (unit < 1) | Step (unit ≥ 1) | Produces prices like |
|----------|-----------------|-----------------|----------------------|
| Strong   | 10              | unit × 1000     | 9999, 999            |
| Elite    | 1               | unit × 100      | 99, 199              |
| Scale    | 0.1             | unit × 10       | 9.9, 19              |

For each tier, two candidates: `ceil(raw / step) × step - unit` (up) and `floor(raw / step) × step - unit` (down).

## Rules

1. **3% Snap Window** — a beauty candidate is valid only if `|candidate - raw| / raw ≤ 3%`
2. **Scale-Dependent Priority** — Strong beats Elite only if extra deviation cost ≤ threshold (0.5% for raw < 100, 1.5% for raw ≥ 100)
3. **Tier Priority** — Strong > Elite > Scale (within 3% window)
4. **Direction by Coefficient** — coef ≥ 1 (premium) → prefer UP; coef < 1 (discount) → prefer DOWN
5. **Grid Fallback** — if no beauty found and unit ≥ 1: use `round(raw / unit) × unit` if deviation < 5%
6. **Scale-Aware Fallback** — if nothing else: use Scale step up/down (by coefficient direction)
7. **Minimal Unit Guard** — `max(unit, result)`, final round to 2 decimal places
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
    decimal eliteStep = unit < 1m ? 1m : unit * 100m;
    decimal eliteUp = Math.Ceiling(rawPrice / eliteStep) * eliteStep - unit;
    decimal eliteDown = Math.Floor(rawPrice / eliteStep) * eliteStep - unit;

    decimal strengthStep = unit < 1m ? 10m : unit * 1000m;
    decimal strengthUp = Math.Ceiling(rawPrice / strengthStep) * strengthStep - unit;
    decimal strengthDown = Math.Floor(rawPrice / strengthStep) * strengthStep - unit;

    decimal scaleStep = unit < 1m ? 0.1m : unit * 10m;
    decimal scaleUp = Math.Ceiling(rawPrice / scaleStep) * scaleStep - unit;
    decimal scaleDown = Math.Floor(rawPrice / scaleStep) * scaleStep - unit;

    // 2. Deviation Guards (<= 3%)
    decimal chkStrengthUp = Math.Abs(strengthUp - rawPrice) / rawPrice <= 0.03m ? strengthUp : 0m;
    decimal chkStrengthDown = Math.Abs(strengthDown - rawPrice) / rawPrice <= 0.03m ? strengthDown : 0m;
    decimal chkEliteUp = Math.Abs(eliteUp - rawPrice) / rawPrice <= 0.03m ? eliteUp : 0m;
    decimal chkEliteDown = Math.Abs(eliteDown - rawPrice) / rawPrice <= 0.03m ? eliteDown : 0m;
    decimal chkScaleUp = Math.Abs(scaleUp - rawPrice) / rawPrice <= 0.03m ? scaleUp : 0m;
    decimal chkScaleDown = Math.Abs(scaleDown - rawPrice) / rawPrice <= 0.03m ? scaleDown : 0m;

    // 3. Strict Grid Target
    decimal grid = Math.Round(rawPrice / unit, MidpointRounding.AwayFromZero) * unit;

    // 4. Resolve Best Elite Target
    decimal bestElite;
    if (chkEliteUp > 0m && chkEliteDown > 0m)
        bestElite = coefficient >= 1m ? chkEliteUp : chkEliteDown;
    else if (chkEliteUp > 0m)
        bestElite = chkEliteUp;
    else
        bestElite = chkEliteDown;

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

        if (bestElite > 0m)
        {
            if ((Math.Abs(str - rawPrice) / rawPrice)
              - (Math.Abs(bestElite - rawPrice) / rawPrice) <= costThreshold)
                beauty = str;
            else
                beauty = bestElite;
        }
        else
            beauty = str;
    }
    else if (bestElite > 0m)
    {
        beauty = bestElite;
    }
    else if (chkScaleUp > 0m || chkScaleDown > 0m)
    {
        if (chkScaleUp > 0m && chkScaleDown > 0m)
            beauty = coefficient >= 1m ? chkScaleUp : chkScaleDown;
        else if (chkScaleUp > 0m)
            beauty = chkScaleUp;
        else
            beauty = chkScaleDown;
    }

    // 6. Final Selection and Fallbacks
    decimal finalPrice;
    if (beauty > 0m)
        finalPrice = beauty;
    else if (unit >= 1m && (Math.Abs(grid - rawPrice) / rawPrice) < 0.05m)
        finalPrice = grid;
    else
        finalPrice = coefficient >= 1m ? scaleUp : scaleDown;

    return Math.Round(Math.Max(unit, finalPrice), 2, MidpointRounding.AwayFromZero);
}
```

## Comparison with Current `LocalPriceCalculator`

| Aspect             | Current                       | Smart Beautify v1                          |
|--------------------|-------------------------------|--------------------------------------------|
| Beautify           | Single: `rounded - unit`      | Three tiers (strong/elite/scale)           |
| Deviation control  | None                          | ≤ 3% window                                |
| Rounding direction | Explicit `RoundingType` param | Auto from coefficient (≥1 → up, <1 → down) |
| `RoundingAmount`   | Explicit param                | Derived from `unit`                        |
| `Beautify` flag    | Explicit param                | Always on (beauty is the algorithm)        |
| Fallback           | None                          | Grid → Scale step                          |

Fields `RoundingAmount`, `RoundingType`, `Beautify` in `RegionalPriceRates` become unnecessary — all logic derives from `Rate` and `MinimalUnit`.

## Open Questions

- Discount price: same algorithm or separate logic?
- Should old fields (`RoundingAmount`, `RoundingType`, `Beautify`) be removed or kept for backward compat?
- Additional features TBD per task author
- Rule thresholds (3%, 5%, 0.5%/1.5%) — are these final or configurable?
