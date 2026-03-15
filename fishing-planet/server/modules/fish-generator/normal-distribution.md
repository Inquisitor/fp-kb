# Normal Distribution in Fish Weight — Deep Dive

> Parent: [Fish Generator card](_card.md)

## Overview

Two independent normal distribution implementations are used for fish weight.
They serve different generation paths and have different algorithms, parameters, and effects.

**Origin**: The BiteSystem `NormalDistribution` class and the form-specific polynomials (`_formToNorm`) predate FP-33182. Rev. 12950 (FP-33182) added `GetPossibleNormalFloat()` and related methods to the existing `NormalDistribution` class, and modified `FishDescription.GenerateRandomWeight()` to use them. See [FP-33182 journal](../../../tasks/FP-33182--weight-generation/journal.md) for full change analysis.

## Implementation 1: `NormalRandom` (GameModel)

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

## Implementation 2: `NormalDistribution` (BiteSystem)

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

### Method hierarchy

```
GetNormMarsaglia(sigma=0.2, mu=0)       — raw N(mu, sigma)
  └─ GetMarsaglia(sigma, mu, max=1)     — resample while |v| > max
      ├─ GetMarsaglia01(sigma, mu, max) — |GetMarsaglia|, range [0, max]
      └─ GetAbsMarsaglia(sigma, mu, max)— public, returns float (vs double)
```

### Key method for weight: `GetPossibleNormalFloat()`

Hybrid uniform/normal distribution:

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

### Application — `FishDescription.GenerateRandomWeight()`

Called from `PondServer.GetFish()` — BiteSystem path.

**Pipeline:**
1. `norm = formPolynomial(uniform_random)` — form-specific curve
2. `norm = clamp(norm, 0, 1) * weightK`
3. `weight = GetPossibleNormalFloat(norm, minWeight, maxWeight, threshold, sigma)`
4. `changedWeight = weight * weightK` — if out of form bounds, search for matching form

**Note on `weightK`:** Originates from the **chum (groundbait) system** — specifically from **particles** (крупные частицы), a chum sub-category that affects *only weight*, not bite probability. During chum mixing (`Chum_Server`), aromatizers feed into `Attraction` (bite probability) while particles feed into `WeightK` (weight modifier) — both stored in `FishTypeAttractivity` but computed from different ingredient types.

**Code chain:** `ChumPiece._fishTypeAttractivity[fishId].WeightK` → `ChumSystem.GetAttraction()` (Min pieceWeightK across chum pieces, then interpolated: `weightK = (1-norm) + norm * minWeightK`, where norm = chum effectiveness) → `FishSelector.Record._weightK` (Max across multiple chum zones via `Math.Max`) → `GenerateRandomWeight()`.

Without chum, weightK = 1.0 (no effect). Applied **twice** — once to `norm` (step 2) and once to `weight` (step 4). After step 2, `norm *= weightK` lowers the effective threshold from `0.95` to `0.95 / weightK` — e.g. with `weightK = 1.5` the threshold drops to ~0.633, routing a much larger fraction of fish through the normal distribution branch. However, the second multiplication (`changedWeight`) only takes effect when the fish **crosses into another form** — if `changedWeight` stays within the original form bounds (or no matching form is found), the returned weight is the un-multiplied `weight`.

**TODO — investigate deeper:** Confluence doc [Алгоритм и формулы новой системы клева](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/923500587) describes particle weight modifier design: `MaxEffect / OptimalBiteChumLayersCount` per layer, with form crossover on weight overflow. Verify how this maps to actual `ChumSystem` code — the GDD formula may differ from implementation. See also [backlog](backlog.md) Confluence Research section.

### Form-specific polynomials (`FishDescription._formToNorm`)

**Origin:** Created by Max Komisarenko during BiteSystem development (predates FP-33182). Coefficients were obtained via curve fitting on a web tool — control points were chosen to approximate the `FishWeightBias` (Min/Max/No) behavior from the legacy FishBox system. The exact control points are lost; (0,0) and (1,1) were likely among them. The goal of reproducing FishBox bias was not fully achieved — the polynomials are a static approximation of what was originally a dynamic bias mechanism.

| Form   | Polynomial                                | Effect                                                                                                                                     |
|--------|-------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|
| Young  | `-0.0135x³ - 0.9727x² + 1.9829x + 0.0032` | Concave above identity — inflates norm (x=0.5→0.75, x=0.9→0.99). Likely intended to mimic Bias.Max (heavier fish more probable)            |
| Common | `x`                                       | Identity — uniform input preserved (equivalent to Bias.No)                                                                                 |
| Trophy | `x`                                       | Identity — uniform input preserved (equivalent to Bias.No)                                                                                 |
| Unique | `8.5574x³ - 13.5356x² + 6.0272x - 0.0489` | Non-monotonic: peak ~0.77 at x≈0.3, dips below identity at x≈0.7. Intent unclear — possibly an attempt at a special rare-fish distribution |

Note: polynomials don't pass exactly through (0,0) — Young: f(0)=0.003, Unique: f(0)=-0.049. This is typical of least-squares regression that minimizes total error rather than pinning endpoints. Values are clamped to [0,1] after evaluation.

Sample values:

| Input | Young | Unique | Identity |
|-------|-------|--------|----------|
| 0.1   | 0.20  | 0.43   | 0.1      |
| 0.3   | 0.51  | 0.77   | 0.3      |
| 0.5   | 0.75  | 0.65   | 0.5      |
| 0.7   | 0.91  | 0.47   | 0.7      |
| 0.9   | 0.99  | 0.65   | 0.9      |

---

## Configurable Parameters

| Parameter                                    | Hardcoded default           | SQL/GlobalVariables default | Effect                                                  |
|----------------------------------------------|-----------------------------|-----------------------------|---------------------------------------------------------|
| `UseNormalDistributionForFishGeneratingFrom` | 0.75 (`Pond` field)         | **0.95**                    | Threshold above which normal distribution kicks in      |
| `NormalDistributionForFishGeneratingSigma`   | 0.2 (`Pond` field)          | **0.55**                    | Sigma for Marsaglia in weight generation                |
| `MarsagliaSigma`                             | 0.55 (`FishSelector` field) | 0.55                        | Sigma for fish generation probability dice (NOT weight) |

**Injection chain**: SQL `GlobalVariables` → `GlobalVariablesCache` properties → `Pond` / `FishSelector` static fields.

SQL patch: `IMV.M.2025.06.25-016.sql`.

### Default discrepancy

Hardcoded (0.75 / 0.2) vs SQL (0.95 / 0.55) differ significantly:
- With 0.75: normal distribution activates for 25% of norm values (upper quarter)
- With 0.95: normal distribution activates for only 5% (upper tail)
- σ=0.2 is narrow (concentrated near 0) vs σ=0.55 is wide (spread out)

If GlobalVariables fail to load, behavior changes substantially.

---

## Data Flow Summary

```
┌──────────── GameModel Path ────────────────────────--┐
│ FishGenerator.GenerateFishTemplate()                 │
│   └─ GameUtils.RandomizeFishWeight(min, max, bias)   │
│       ├─ Bias.No  → Uniform              (no normal) │
│       ├─ Bias.Min → |N(0, ~0.25)|        (→ lighter) │
│       └─ Bias.Max → 1 - |N(0, ~0.25)|   (→ heavier)  │
│       └─ weight = lerp(min, max, sizeRnd)            │
└────────────────────────────────────────────────────-─┘

┌──────────── BiteSystem Path ──────────────────────┐
│ PondServer.GetFish()                              │
│   └─ FishDescription.GenerateRandomWeight()       │
│       1. norm = formPolynomial(uniform)           │
│       2. norm *= weightK                          │
│       3. GetPossibleNormalFloat(norm, min, max,   │
│              threshold=0.95, sigma=0.55)          │
│          ├─ norm < 0.95 → lerp      (no normal)   │
│          └─ norm ≥ 0.95 → |N(0,0.55)| in upper 5% │
└───────────────────────────────────────────────────┘
```

## Key Observations

1. **Young fish** polynomial inflates norm (x=0.9→0.99), so Young fish **more readily** trigger the normal distribution branch than Common/Trophy at the same uniform input.
2. **Unique fish** polynomial is non-monotonic — strongly inflates low inputs (x=0.3→0.77) but depresses mid-range (x=0.7→0.47). Net effect: many Unique fish land in the mid-upper weight range regardless of input.
3. In BiteSystem's normal branch, `GetMarsaglia01` returns |N(0,σ)| — peak at 0 — so even in the upper range, weights lean toward the lower boundary of that range.
4. `MarsagliaSigma` (0.55) is used for fish generation **probability** dice rolls (`PondServer.GetFish()`, `FishSelector`), not for weight — but affects whether a fish is generated at all.
