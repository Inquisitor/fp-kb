# Smart Beautify Algorithm

Regional price calculation algorithm. Converts a USD base price into a "beautiful" local currency
price (ending in 9s: 9.99, 49.99, 999, 4999) while keeping deviation from the mathematically
correct price within controlled bounds.

## Glossary

- **raw price** — the mathematically exact local currency price before any rounding: `basePrice × rate × exchangeRate`. This is the "ideal" price we're trying to approximate beautifully.
- **beauty candidate** — a rounded price that ends in 9s (like 99.99 or 4999). The algorithm generates several candidates and picks the best one.
- **tier** — a rounding granularity level. Higher tiers produce "rounder" beauty numbers (9999 vs 99 vs 9.9). See [Three Tiers](#three-tiers).
- **deviation** — how far a candidate is from the raw price, expressed as a percentage: `|candidate − raw| / raw × 100%`.
- **snap** — choosing a beauty candidate to represent the raw price. "Snapping" to 55.99 means rounding 55.41 to that beauty point.
- **direction** — whether the algorithm prefers rounding up (toward a more expensive price) or down (toward a cheaper one). Determined by `rate`.
- **minimal unit** — the smallest price increment allowed by the platform for a given currency. For example, Steam allows UAH only in whole numbers (`minimalUnit` = 1), but USD in cents (`minimalUnit` = 0.01). In code: `minimalUnit` parameter.
- **snapBase** — the base number to which a price snaps before beautification. The algorithm rounds to the nearest multiple of `snapBase`, then subtracts `minimalUnit`. For example, Gold `snapBase` = 10: snap to 60, subtract 0.01 → 59.99. Each tier has its own `snapBase` derived from `minimalUnit`. In code: `goldSnapBase`, `silverSnapBase`, `bronzeSnapBase`.

## Formula

```
baseRegionalPrice = basePrice × rate
rawPrice = baseRegionalPrice × exchangeRate
```

The algorithm then selects the best beauty candidate near `rawPrice`.

## Parameters

| Parameter      | Role                                                                                                              |
|----------------|-------------------------------------------------------------------------------------------------------------------|
| `basePrice`    | Original product price in USD                                                                                     |
| `rate`         | Regional price multiplier (0.3 → price is 30% of original, i.e. 70% discount). Also determines rounding direction |
| `exchangeRate` | USD → local currency rate (e.g. 41 means 1 USD = 41 UAH)                                                          |
| `minimalUnit`  | Smallest currency unit on platform (0.01 for USD, 1 for UAH on Steam)                                             |

`rate` serves dual purpose: price multiplier AND rounding direction selector.
- `rate ≥ 1` (premium/parity region): prefer rounding **up**
- `rate < 1` (discount region): prefer rounding **down**

## Three Tiers

A "beautiful" price is one that ends in 9s — but 9s come at different scales. The algorithm
tries three levels of beauty, from the most impressive to the most modest:

**Gold** — snaps to the largest round-number boundaries (tens for cent-based currencies,
thousands for whole-unit currencies). Produces prices like **9.99**, **19.99**, **99.99** (cents)
or **999**, **1999**, **4999**, **9999** (whole). The most psychologically impactful —
"just under a big round number".

**Silver** — snaps to integer boundaries (ones for cent-based, hundreds for whole-unit).
Produces prices like **0.99**, **1.99**, **14.99**, **55.99** (cents) or **99**, **199**,
**499**, **1099** (whole). The most common type of beauty pricing.

**Bronze** — snaps to the smallest meaningful boundaries (tenths for cent-based, tens
for whole-unit). Produces prices like **0.09**, **0.19**, **1.09**, **3.09** (cents)
or **9**, **19**, **49**, **109**, **189** (whole). Used when Gold and Silver can't snap
within the allowed deviation.

### How candidates are computed

Each tier has a **`snapBase`** — the base number to which the price snaps before beautification.
The algorithm rounds raw price to the nearest multiple of `snapBase` (up and down), then subtracts
`minimalUnit`:

```
candidate_up   = ceil(rawPrice / snapBase)  × snapBase − minimalUnit
candidate_down = floor(rawPrice / snapBase) × snapBase − minimalUnit
```

This places the price exactly one `minimalUnit` below a round boundary. For currencies with
`minimalUnit` = 0.01 or 1, the result is classic "nines" pricing: 9.99, 99, 999, 4999.
For currencies with non-standard `minimalUnit` (10, 500) the principle is the same, but
the result looks different visually (see note below).

Each tier defines its own `snapBase`:

| Tier   | `snapBase` (`minimalUnit` < 1) | `snapBase` (`minimalUnit` ≥ 1) |
|--------|--------------------------------|--------------------------------|
| Gold   | 10                             | `minimalUnit` × 1000           |
| Silver | 1                              | `minimalUnit` × 100            |
| Bronze | 0.1                            | `minimalUnit` × 10             |

For whole-unit currencies, `snapBase` scales proportionally with `minimalUnit`:

| `minimalUnit` | Currency | Gold    | Silver | Bronze |
|---------------|----------|---------|--------|--------|
| 0.01          | USD/EUR  | 10      | 1      | 0.1    |
| 1             | UAH/JPY  | 1 000   | 100    | 10     |
| 10            | KRW      | 10 000  | 1 000  | 100    |
| 500           | VND      | 500 000 | 50 000 | 5 000  |

**USD/EUR** (`minimalUnit` = 0.01):

| Tier   | `snapBase` | Snap to | −`minimalUnit` | Candidate |
|--------|------------|---------|----------------|-----------|
| Gold   | 10         | 60      | −0.01          | **59.99** |
| Silver | 1          | 56      | −0.01          | **55.99** |
| Bronze | 0.1        | 55.5    | −0.01          | **55.49** |

**UAH/JPY** (`minimalUnit` = 1):

| Tier   | `snapBase` | Snap to | −`minimalUnit` | Candidate |
|--------|------------|---------|----------------|-----------|
| Gold   | 1 000      | 2 000   | −1             | **1 999** |
| Silver | 100        | 200     | −1             | **199**   |
| Bronze | 10         | 190     | −1             | **189**   |

**KRW** (`minimalUnit` = 10):

| Tier   | `snapBase` | Snap to | −`minimalUnit` | Candidate  |
|--------|------------|---------|----------------|------------|
| Gold   | 10 000     | 20 000  | −10            | **19 990** |
| Silver | 1 000      | 15 000  | −10            | **14 990** |
| Bronze | 100        | 14 500  | −10            | **14 490** |

> **Note:** Visual "nines" (99, 999, 9999) only appear when `minimalUnit` is a power of 10
> (0.01, 1). For currencies with other `minimalUnit` values, the algorithm works identically —
> the price is placed one `minimalUnit` below a `snapBase` multiple — but the result looks
> different. This is not a bug: "beauty" is defined by the currency grid, not by decimal digits.

**VND** (`minimalUnit` = 500):

| Tier   | `snapBase` | Snap to | −`minimalUnit` | Candidate    |
|--------|------------|---------|----------------|--------------|
| Gold   | 500 000    | 500 000 | −500           | **499 500**  |
| Silver | 50 000     | 150 000 | −500           | **149 500**  |
| Bronze | 5 000      | 115 000 | −500           | **114 500**  |

## Selection Rules

### 1. Deviation Guard (3%)

Each candidate is checked: `|candidate − raw| / raw ≤ 3%`. Candidates deviating more
than 3% from the raw price are discarded. This prevents prices from drifting too far
from the mathematically correct value.

### 2. Rounding Direction Preference

When both Up and Down candidates pass the 3% check within a tier, the rounding direction
is chosen by `rate`:
- `rate ≥ 1` → pick Up (round toward higher price)
- `rate < 1` → pick Down (round toward lower price)

If only one candidate passes, it is used regardless of direction — this is the only
situation where the algorithm may pick a direction opposite to the preference, because
there is no alternative.

**Note on "closest" rounding.** The algorithm never explicitly uses "closest" (round to nearest)
as a strategy. The direction is always UP or DOWN based on `rate`. Closest-like behavior
only appears as a side effect:
- When only one candidate passes the 3% guard — forced choice, not a preference
- In the grid fallback — a last-resort mechanism when all beauty candidates fail

### 3. Tier Priority: Gold > Silver > Bronze

Higher-tier beautification (more 9s) is preferred when it doesn't cost too much extra deviation.

When both Gold and Silver are available, a cost comparison decides:
```
extraCost = |Gold − raw|/raw − |Silver − raw|/raw
```
Gold wins if `extraCost ≤ costThreshold`, where:
- `raw < 100` → threshold = **0.5%** (stricter, protects low-value currencies)
- `raw ≥ 100` → threshold = **1.5%** (more lenient, bigger prices tolerate more)

If Gold's extra cost exceeds the threshold, Silver is preferred (closer to raw price).

### 4. Fallbacks

If no beauty candidate passes the 3% guard:
1. **Grid fallback** (only when `minimalUnit` ≥ 1): snap to the nearest whole minimal unit (`round(raw / minimalUnit) × minimalUnit`), accepted if deviation < **5%**. This is the only place where true "nearest" rounding is used.
2. **Bronze step fallback**: use the Bronze tier's Up or Down candidate (by direction), ignoring the 3% guard. Last resort — may produce larger deviations.

### 5. Minimal Unit Guard

Final result is `max(minimalUnit, price)`, rounded to 2 decimal places. The price can never
be less than one minimal unit.

## Constants

| Constant                   | Value | Purpose                                        |
|----------------------------|-------|------------------------------------------------|
| `BeautySnapMaxDeviation`   | 3%    | Max deviation for a beauty candidate           |
| `CostThresholdLow`         | 0.5%  | Gold vs Silver margin for raw < 100            |
| `CostThresholdHigh`        | 1.5%  | Gold vs Silver margin for raw ≥ 100            |
| `CostThresholdBoundary`    | 100   | Raw price boundary between low/high thresholds |
| `GridFallbackMaxDeviation` | 5%    | Max deviation for grid-aligned fallback        |

Currently hardcoded as named constants in `LocalPriceCalculator`. May become configurable
if needed in the future.

## Examples

All examples use base price 14.99 USD unless noted otherwise.

### 1. Poland (PLN, `minimalUnit` = 0.01) — 3% guard rejects Gold, Silver wins

Raw price: 55.41. Rate = 1.0 → direction UP.

| Tier   | Step | Up candidate | Dev    | Down candidate | Dev    |
|--------|------|--------------|--------|----------------|--------|
| Gold   | 10   | 59.99        | 8.27%  | 49.99          | 9.78%  |
| Silver | 1    | **55.99**    | 1.05%  | 54.99          | 0.75%  |
| Bronze | 0.1  | 55.49        | 0.15%  | 55.39          | 0.03%  |

Gold candidates both exceed 3% → rejected (**Rule 1**). Silver has both candidates within 3%.
Direction UP → pick Silver up = **55.99** (**Rule 3**: highest available tier wins).

### 2. Russia (RUB, `minimalUnit` = 0.01) — Gold beats Silver via cost threshold

Raw price: 1890.99. Rate = 1.5 → direction UP.

| Tier   | Step | Up candidate | Dev   | Down candidate | Dev   |
|--------|------|--------------|-------|----------------|-------|
| Gold   | 10   | **1899.99**  | 0.48% | 1889.99        | 0.05% |
| Silver | 1    | 1890.99      | 0.00% | 1889.99        | 0.05% |

Both Gold and Silver pass 3%. Direction UP: Gold = 1899.99, Silver = 1890.99.
Extra cost: 0.48% − 0.00% = 0.48%. Raw ≥ 100 → threshold 1.5%. Since 0.48% ≤ 1.5%,
Gold wins (**Rule 2**: extra cost within threshold). Result: **1899.99**.

### 3. Gold loses to Silver — cost threshold rejects Gold

Constructed case: `basePrice` = 100, `rate` = 1.0, `exchangeRate` = 103, `minimalUnit` = 1.
Raw price: 10300. Direction UP.

| Tier   | Step  | Up candidate | Dev   | Down candidate | Dev   |
|--------|-------|--------------|-------|----------------|-------|
| Gold   | 1000  | 10999 (fail) | 6.79% | **9999**       | 2.92% |
| Silver | 100   | **10299**    | 0.01% | 10199          | 0.98% |

Gold up fails 3%, only Gold down = 9999 (2.92%) passes. Silver up = 10299 (0.01%) preferred by direction UP.
Extra cost: 2.92% − 0.01% = 2.91%. Raw ≥ 100 → threshold 1.5%. Since 2.91% > 1.5%,
Silver wins (**Rule 2**: Gold is too expensive). Result: **10299**.

### 4. Ukraine (UAH, `minimalUnit` = 1) — Bronze tier, forced direction override

Raw price: 186.18. Rate = 0.3 → direction DOWN.

| Tier   | Step | Up candidate | Dev     | Down candidate | Dev     |
|--------|------|--------------|---------|----------------|---------|
| Gold   | 1000 | 999          | 436.6%  | −1             | —       |
| Silver | 100  | 199          | 6.88%   | 99             | 46.8%   |
| Bronze | 10   | **189**      | 1.51%   | 179            | 3.86%   |

Gold and Silver both fail 3%. Bronze: only up = 189 passes (1.51%).
Direction is DOWN, but only one candidate available → forced to take it (**Rule 4**: no alternative).
Result: **189**.

### 5. South Korea (KRW, `minimalUnit` = 10) — large minimal unit, direction DOWN

Raw price: 14522.84. Rate = 0.7 → direction DOWN.

| Tier   | Step  | Up candidate | Dev   | Down candidate | Dev   |
|--------|-------|--------------|-------|----------------|-------|
| Gold   | 10000 | 19990        | 37.6% | 9990           | 31.2% |
| Silver | 1000  | 14990        | 3.22% | 13990          | 3.67% |
| Bronze | 100   | 14590        | 0.46% | **14490**      | 0.23% |

Gold and Silver fail 3%. Bronze has both candidates within 3%.
Direction DOWN → pick Bronze down = **14490** (**Rule 4**). Step = `minimalUnit` × 10 = 100,
so prices snap to hundreds-boundaries minus 10.

### 6. Vietnam (VND, `minimalUnit` = 500) — extreme minimal unit

Raw price: 116067.57. Rate = 0.3 → direction DOWN.

| Tier   | Step    | Up candidate | Dev    | Down candidate | Dev    |
|--------|---------|--------------|--------|----------------|--------|
| Gold   | 500000  | 499500       | 330.4% | −500           | —      |
| Silver | 50000   | 149500       | 28.8%  | 99500          | 14.3%  |
| Bronze | 5000    | 119500       | 2.96%  | **114500**     | 1.35%  |

Only Bronze passes 3%. Direction DOWN → **114500**.
With `minimalUnit` = 500, Bronze step = 5000. Prices snap to 5000-boundaries minus 500:
..., 109500, 114500, 119500, ... Effectively rounding to the nearest "X500 below a 5000-multiple".

### 7. Grid fallback (`minimalUnit` = 1, raw = 105)

Constructed case: `basePrice` = 1, `rate` = 1.0, `exchangeRate` = 105, `minimalUnit` = 1.
Raw price: 105. Direction UP.

| Tier   | Step | Up candidate | Dev    | Down candidate | Dev    |
|--------|------|--------------|--------|----------------|--------|
| Gold   | 1000 | 999          | 851.4% | −1             | —      |
| Silver | 100  | 199          | 89.5%  | 99             | 5.71%  |
| Bronze | 10   | 109          | 3.81%  | 99             | 5.71%  |

ALL beauty candidates fail 3% → **Rule 5** activates.
Grid: `round(105 / 1) × 1` = 105. Deviation 0% < 5% → accepted. Result: **105**.

This is the only place where true "nearest" rounding is used — no beautification,
just snapping to the nearest `minimalUnit`-aligned value.

### 8. Bronze step fallback (`minimalUnit` = 0.01, raw = 0.155)

Constructed case: `basePrice` = 0.01, `rate` = 1.0, `exchangeRate` = 15.5, `minimalUnit` = 0.01.
Raw price: 0.155. Direction UP.

All tiers fail 3% (nearest beauty candidates are too far from 0.155).
`minimalUnit` < 1 → grid fallback not available.
**Rule 6** activates: take Bronze up = **0.19** (deviation 22.6%).

Last resort — deviation is large, but there is no better option for this price range.

### 9. Minimal unit guard (raw = 0.005)

Constructed case: `basePrice` = 0.01, `rate` = 0.5, `exchangeRate` = 1, `minimalUnit` = 0.01.
Raw price: 0.005. Direction DOWN.

All tiers fail. Bronze step fallback: direction DOWN → Bronze down = −0.01 (negative!).
**Rule 7** activates: `max(minimalUnit, −0.01)` = **0.01**.

The price cannot go below one minimal unit, regardless of what the algorithm computes.

### 10. Kuwait (KWD, `minimalUnit` = 0.01) — algorithm degradation at very low prices

Kuwaiti dinar is an expensive currency (1 KWD ≈ 3.27 USD), so local prices are small numbers.
This pushes the beauty grid to its limits.

**$0.99 product** → raw = 0.303. Rate = 1.0 → direction UP.

| Tier   | `snapBase` | Up candidate | Dev     | Down candidate | Dev    |
|--------|------------|--------------|---------|----------------|--------|
| Gold   | 10         | 9.99         | 3192.5% | −0.01          | —      |
| Silver | 1          | 0.99         | 226.3%  | −0.01          | —      |
| Bronze | 0.1        | 0.39         | 28.5%   | 0.29           | 4.42%  |

ALL candidates fail 3%. Bronze fallback activates: direction UP → **0.39** (deviation **28.5%**).
A $0.99 product priced at 0.39 KWD instead of 0.30 KWD — the customer pays almost a third more
than the mathematically correct price.

**Why this happens:** at raw = 0.30, the Bronze `snapBase` = 0.1 produces candidates at 0.29 and 0.39.
The gap between consecutive beauty points (0.10) is 33% of the raw price itself — far too coarse
for the 3% guard to find anything acceptable.

**$4.99 product** → raw = 1.53. Same problem but milder:

| Tier   | `snapBase` | Up candidate | Dev   | Down candidate | Dev   |
|--------|------------|--------------|-------|----------------|-------|
| Bronze | 0.1        | 1.59         | 3.97% | **1.49**       | 2.57% |

Bronze down = 1.49 passes 3% (barely). Direction is UP, but up = 1.59 fails 3% → forced to
take down. Result: **1.49** — direction preference overridden.

**$14.99 product** → raw = 4.59. Bronze up = 4.59 matches almost exactly (0.09% deviation).
At this price range the algorithm works normally again.

> **Takeaway:** The Smart Beautify algorithm degrades gracefully for very small raw prices
> (roughly below 1.0 in local currency). The Bronze fallback ensures a price is always produced,
> but deviations can be significant. This is an inherent limitation of grid-based beautification
> when the grid spacing is large relative to the price.

## Implementation

- Algorithm: `LocalPriceCalculator.CalculateRegionalPrice()` in `Shared/SharedLib/Monetization/LocalPriceCalculator.cs`
- Tests: `Shared/SharedLib.Tests/Monetization/LocalPriceCalculatorTests.cs`
- GD spec source: Google Sheets "Regional Pricing" (link in JIRA FP-43177)
