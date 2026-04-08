# Normal Distribution in Fish Weight — Deep Dive

> Parent: [Fish Generator card](_card.md)

## Overview

Normal distribution is used in two independent subsystems. One is still active for weight generation, the other has been replaced.

| System                            | Class           | Still used for weight?                             | Still used at all?    |
|-----------------------------------|-----------------|----------------------------------------------------|-----------------------|
| GameModel — `NormalRandom`        | Box-Muller      | **Yes** — FishBox, Carousel, Scripted, Debug paths | Yes                   |
| BiteSystem — `NormalDistribution` | Marsaglia polar | **No** — replaced by edge distribution (r15919)    | Yes — dice rolls only |

The BiteSystem weight generation path (`FishDescription.GenerateRandomWeight()`, form polynomials, threshold/sigma) was removed in FP-41845 Phase 2a (r15919) and replaced by `FishWeightGenerator.Generate()` with normalized piecewise inverse CDF. See [edge-distribution.md](edge-distribution.md) for the replacement system.

---

## Implementation 1: `NormalRandom` (GameModel) — ACTIVE

**File**: `Photon/src-server/GameModel/Helpers/NormalRandom.cs`

### Algorithm — Box-Muller (sin variant)

```
result = sqrt(-2 * ln(u1)) * sin(2π * u2) / 4
```

Division by 4 compresses standard N(0,1) to effective σ≈0.25. Values outside [-1,1] are resampled (truncated normal).

### Methods used for weight

| Method             | Range   | Distribution              | Used in weight?               |
|--------------------|---------|---------------------------|-------------------------------|
| `NextFullNormal()` | [-1, 1] | N(0, ~0.25) truncated     | Base generator                |
| `NextHalfNormal()` | [0, 1]  | \|N(0, ~0.25)\| peak at 0 | Yes — `Bias.Min` / `Bias.Max` |
| `NextNormal()`     | [0, 1]  | N(0.5, ~0.25) truncated   | No (not used for weight)      |

### Application — `GameUtils.RandomizeFishWeight()`

Called from `FishGenerator` for FishBox, Carousel, Scripted, Debug paths.

```
Bias.No  → NextLinearDecimal()    → uniform, NO normal distribution
Bias.Min → NextHalfNormal()       → half-normal, lighter fish more likely
Bias.Max → 1 - NextHalfNormal()   → half-normal mirrored, heavier fish more likely
→ weight = min + (max - min) * sizeRnd
```

Normal distribution activates **only when Bias ≠ No**.

---

## Implementation 2: `NormalDistribution` (BiteSystem) — ACTIVE (dice rolls only)

**File**: `Shared/BiteSystem/Common/NormalDistribution.cs`

### Algorithm — Marsaglia polar method

```
do {
    v1 = rnd.NextDouble() * 2 - 1   // [-1, 1]
    v2 = rnd.NextDouble() * 2 - 1
    s = v1² + v2²
} while (s >= 1 || s == 0)
s = sqrt(-2 * ln(s) / s)
return mu + v1 * s * sigma           // N(mu, sigma)
```

### Current usage — fish generation dice rolls (NOT weight)

`NormalDistribution.GetAbsMarsaglia()` is used in `PondServer.GetFish()` and `FishSelector` for the "generate fish or not" probability dice roll:

```csharp
var diceRoll = NormalDistribution.GetAbsMarsaglia(rnd, FishSelector.MarsagliaSigma);  // σ=0.55
var noFishProbability = 1 - Math.Min(maxProbability, 1);
if (diceRoll >= noFishProbability) { /* generate fish */ }
```

This has nothing to do with weight — it determines whether a fish bites at all.

---

## Data Flow Summary

```
┌──────────── GameModel Path (unchanged) ──────────────┐
│ FishGenerator.GenerateFishTemplate()                 │
│   └─ GameUtils.RandomizeFishWeight(min, max, bias)   │
│       ├─ Bias.No  → Uniform              (no normal) │
│       ├─ Bias.Min → |N(0, ~0.25)|        (→ lighter) │
│       └─ Bias.Max → 1 - |N(0, ~0.25)|   (→ heavier)  │
│       └─ weight = lerp(min, max, sizeRnd)            │
└──────────────────────────────────────────────────────┘

┌──────────── BiteSystem Path (replaced in r15919) ────┐
│ PondServer.GetFish()                                 │
│   └─ FishWeightGenerator.Generate()                  │
│       1. u = uniform random [0, 1]                   │
│       2. GetEdgeFlags() — role + form-specific scope │
│       3. Normalized piecewise inverse CDF            │
│       4. WeightFromNormalized(u) — lerp + crossover  │
│   (See edge-distribution.md for full algorithm)      │
└──────────────────────────────────────────────────────┘
```

---
---

## Historical Reference (OBSOLETE — do not use)

> The following sections describe the **pre-r15919** BiteSystem weight generation system.
> It was removed in FP-41845 Phase 2a and replaced by the edge distribution system.
> Kept here for historical context only. See [edge-distribution.md](edge-distribution.md) for the current system.

### [Obsolete] NormalDistribution method hierarchy

```
GetNormMarsaglia(sigma=0.2, mu=0)       — raw N(mu, sigma)
  └─ GetMarsaglia(sigma, mu, max=1)     — resample while |v| > max
      ├─ GetMarsaglia01(sigma, mu, max) — |GetMarsaglia|, range [0, max]
      └─ GetAbsMarsaglia(sigma, mu, max)— public, returns float (vs double)
```

### [Obsolete] GetPossibleNormalFloat() — hybrid uniform/normal

Hybrid uniform/normal distribution used for weight generation before r15919:

```
if (norm < normalPercentageFrom):
    return min * (1 - norm) + max * norm               // Linear interpolation

// Normal path — upper portion of weight range only
min += normalPercentageFrom * (max - min)              // Shift min up
norm = GetMarsaglia01(rnd, sigma)                      // New norm ∈ [0,1], half-normal
return min * (1 - norm) + max * norm                   // Interpolate in upper range
```

Below threshold → input `norm` drives the result linearly.
Above threshold → Marsaglia half-normal value, interpolated in **upper** weight range only.

### [Obsolete] FishDescription.GenerateRandomWeight() pipeline

Called from `PondServer.GetFish()` — BiteSystem path. **Removed in r15919.**

**Pipeline:**
1. `norm = formPolynomial(uniform_random)` — form-specific curve
2. `norm = clamp(norm, 0, 1) * weightK`
3. `weight = GetPossibleNormalFloat(norm, minWeight, maxWeight, threshold, sigma)`
4. `changedWeight = weight * weightK` — if out of form bounds, search for matching form

**Note on `weightK`:** Originates from the **chum (groundbait) system** — specifically from **particles** (крупные частицы), a chum sub-category that affects *only weight*, not bite probability. During chum mixing (`Chum_Server`), aromatizers feed into `Attraction` (bite probability) while particles feed into `WeightK` (weight modifier) — both stored in `FishTypeAttractivity` but computed from different ingredient types.

**Code chain:** `ChumPiece._fishTypeAttractivity[fishId].WeightK` → `ChumSystem.GetAttraction()` (Min pieceWeightK across chum pieces, then interpolated: `weightK = (1-norm) + norm * minWeightK`, where norm = chum effectiveness) → `FishSelector.Record._weightK` (Max across multiple chum zones via `Math.Max`) → `GenerateRandomWeight()`.

Without chum, weightK = 1.0 (no effect). Applied **twice** — once to `norm` (step 2) and once to `weight` (step 4). After step 2, `norm *= weightK` lowers the effective threshold from `0.95` to `0.95 / weightK` — e.g. with `weightK = 1.5` the threshold drops to ~0.633, routing a much larger fraction of fish through the normal distribution branch. However, the second multiplication (`changedWeight`) only takes effect when the fish **crosses into another form** — if `changedWeight` stays within the original form bounds (or no matching form is found), the returned weight is the un-multiplied `weight`.

### [Obsolete] Form-specific polynomials (`FishDescription._formToNorm`)

**Removed in r15919.** Created by Max Komisarenko during BiteSystem development (predates FP-33182). The intent was to approximate an inverse CDF curve for inverse transform sampling — a concave-up curve (like `x²`) that would bias weight distribution toward lighter fish. Coefficients were obtained via cubic regression on a web tool ("Кубическая регрессия") with control points at (0,0), (~0.6, 0.5), (~0.9, 0.65), (1,1).

The author believed the resulting polynomial was monotonically increasing (see `artifacts/image_2020_01_21T15_07_20_948Z.png`). In reality, the Unique polynomial produced an **N-shaped** (non-monotonic) curve on [0,1] — rising to ~0.77 at x≈0.3, falling to ~0.47 at x≈0.7, then rising again to 1.0. On the descending segment, a larger uniform sample produces a *smaller* weight — and the weight range covered by that segment is also covered by the ascending segments on both sides, tripling the effective density there. The turnaround points themselves become density spikes. This is the root cause of the "double hump" artifact visible in production Unique histograms.

| Form   | Polynomial                                | Effect                                                                                                                                                                            |
|--------|-------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Young  | `-0.0135x³ - 0.9727x² + 1.9829x + 0.0032` | Concave above identity — inflates norm toward heavier weights. Roughly achieves the intended inverse CDF shape                                                                    |
| Common | `x`                                       | Identity — uniform input preserved                                                                                                                                                |
| Trophy | `x`                                       | Identity — uniform input preserved                                                                                                                                                |
| Unique | `8.5574x³ - 13.5356x² + 6.0272x - 0.0489` | **N-shaped** (non-monotonic): peak ~0.77 at x≈0.3, dips to ~0.47 at x≈0.7. Intended as inverse CDF but fails the monotonicity requirement — produces double-hump density artifact |

### [Obsolete] Configurable Parameters

| Parameter                                    | Hardcoded default           | SQL/GlobalVariables default | Effect                                                  |
|----------------------------------------------|-----------------------------|-----------------------------|---------------------------------------------------------|
| `UseNormalDistributionForFishGeneratingFrom` | 0.75 (`Pond` field)         | **0.95**                    | Threshold above which normal distribution kicks in      |
| `NormalDistributionForFishGeneratingSigma`   | 0.2 (`Pond` field)          | **0.55**                    | Sigma for Marsaglia in weight generation                |
| `MarsagliaSigma`                             | 0.55 (`FishSelector` field) | 0.55                        | Sigma for fish generation probability dice (NOT weight) |

Note: `UseNormalDistributionForFishGeneratingFrom` was renamed to `FishWeightUpperEdgeZoneFraction` (inverted: 0.95 → 0.05) and `NormalDistributionForFishGeneratingSigma` was deleted. `MarsagliaSigma` is still active (dice rolls).
