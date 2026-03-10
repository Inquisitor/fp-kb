---
status: reopened
executor: Stanislav Samoilov
original-author: Max Komisarenko
jira: https://fishingplanet.atlassian.net/browse/FP-33182
related: FP-41845, FP-38549, FP-39522
epic: FP-26788 (Leaderboards and ratings)
confluence: https://fishingplanet.atlassian.net/wiki/pages/viewpage.action?pageId=4219830273
---
# FP-33182: Improve Random Fish Weight Generation

## Status
System is deployed on production (current branch LBM20251201). Mathematical model has known errors — fix planned in FP-41845.
Reopened: the 20.11.2025 update specifies that boundary weight suppression must apply **only to the eldest fish form** at a pond, not to all forms.

## Summary

### Goal
Make fish weights near the boundaries of the weight range **extremely rare** so that leaderboard records are unique and interesting. The average weight must remain unchanged to preserve game balance.

**Acceptance criteria** (from JIRA description):
- For fish under 10 kg — top weights should differ by at least 1-2 grams
- For fish about 300 kg — top weights should differ by at least ~100 grams
- Generation average must be preserved

### Solution: Hybrid Uniform/Normal Distribution
The BiteSystem weight generation path was extended with a threshold-based system:
- Below threshold (default 95% of the weight range) → **uniform distribution** (unchanged behavior)
- Above threshold (top 5%) → weight is **re-generated** using **Marsaglia polar method** normal distribution, which concentrates values away from the absolute boundary

This makes it nearly impossible to generate a fish at the exact maximum weight, creating natural separation between top leaderboard entries.

### Why It Matters
Without this system, uniform distribution generates weights so close to the boundary that thousands of players can catch "max weight" fish within hours, making leaderboards trivially saturated. The normal distribution in the boundary zone creates natural scarcity of extreme weights.

## Technical Implementation

### What Rev. 12950 Changed (vs Pre-Existing Code)

**Pre-existing** (NOT part of FP-33182):
- `NormalDistribution.cs` — already existed with `GetNormMarsaglia()`, `GetMarsaglia()`, `GetAbsMarsaglia()` (Marsaglia polar method). Used by BiteSystem for fish generation **probability** dice, not weight.
- `FishDescription._formToNorm` polynomials — already existed (Young, Common, Trophy, Unique curves)
- `FishDescription.GenerateRandomWeight()` — already existed with form polynomials + simple lerp + weightK

**Added by rev. 12950** (Max Komisarenko):
- `NormalDistribution.GetMarsaglia01()` — private, returns `|GetMarsaglia()|` (half-normal in [0,1])
- `NormalDistribution.GetNextFloat()` — full normal distribution between min/max (unused in production flow)
- `NormalDistribution.GetUniformOrNormalFloat()` — convenience wrapper (used in tests only)
- `NormalDistribution.GetPossibleNormalFloat()` — **core new method**, hybrid uniform/normal
- `NormalDistributionTest.cs` — test file with Console.WriteLine output, zero assertions

**Modified by rev. 12950:**
- `NormalDistribution` — changed `GetNormMarsaglia`, `GetMarsaglia` from public float to private double
- `FishDescription.GenerateRandomWeight()` — added parameters, changed weight calculation logic
- `PondServer.cs` (Pond partial class) — added static fields for parameters
- `GlobalVariablesCache.cs` — added properties (hardcoded defaults 0.75/0.2) + injection into Pond

**Added by rev. 14437** (Stanislav Samoilov, 2025-06-25):
- Changed hardcoded defaults in `GlobalVariablesCache` from 0.75/0.2 to **0.95/0.55**
- Added SQL patch `IMV.M.2025.06.25-016.sql` inserting GlobalVariables with values 0.95/0.55

**Added by rev. 14637** (Stanislav Samoilov, 2025-08-04):
- Extended `NormalDistributionTest.cs` with `WeightStats` helper and `TestUniformDistribution`/`TestUniformOrNormalDistribution` data-driven tests (still zero assertions)

### Files on Production (LBM20251201)

| File                                                      | Role                                                 |
|-----------------------------------------------------------|------------------------------------------------------|
| `Shared/BiteSystem/Common/NormalDistribution.cs`          | `GetPossibleNormalFloat()` — hybrid uniform/normal   |
| `Shared/BiteSystem/Common/ObjectModel/FishDescription.cs` | `GenerateRandomWeight()` — calling chain             |
| `Shared/BiteSystem/ServerOnly/PondServer.cs`              | `Pond` partial — static parameter fields + call site |
| `Shared/SharedLib/Config/GlobalVariablesCache.cs`         | Properties (defaults 0.95/0.55) + injection          |
| `SQL/Patches/IMV.M.2025.06.25-016.sql`                    | DB defaults (0.95/0.55)                              |
| `Shared/SharedLib.Tests/NormalDistributionTest.cs`        | Visualization tests (no assertions)                  |

### Core Algorithm: `GetPossibleNormalFloat()`
```
Input:  norm (0..1 from form polynomial), minValue, maxValue, normalPercentageFrom, sigma
Output: weight in [minValue, maxValue]

if norm < normalPercentageFrom:
    return lerp(minValue, maxValue, norm)          // Uniform path — identity mapping

// Normal path — upper portion only
minValue += normalPercentageFrom * (maxValue - minValue)   // Compress range to top slice
norm = GetMarsaglia01(rnd, sigma)                          // NEW random: half-normal [0,1], peak at 0
return lerp(minValue, maxValue, norm)                       // Interpolate in compressed range
```

**Note**: the `norm` parameter is DISCARDED in the normal path — a completely new random value is generated via `GetMarsaglia01`. The original `norm` only serves as a gate (above/below threshold).

### Calling Chain (BiteSystem Path)
```
PondServer.GetFish()
  └─ FishDescription.GenerateRandomWeight(rnd, form, weightK, threshold=0.95, sigma=0.55)
       1. norm = formPolynomial(uniform_random)     // PRE-EXISTING: form-specific curve
       2. norm = clamp(norm, 0, 1) * weightK        // NEW: scale by weightK BEFORE generation
       3. weight = GetPossibleNormalFloat(norm, min, max, threshold, sigma)  // NEW
       4. changedWeight = weight * weightK           // NEW: scale AGAIN for form cross-over
       5. if changedWeight outside form bounds → search other forms → return changedWeight
          else → return weight (WITHOUT second weightK)
```

### What Changed in `GenerateRandomWeight()` — Before vs After

**Before rev. 12950:**
```csharp
norm = formPolynomial(rnd.NextDouble());
norm = clamp(norm, 0, 1);
weight = lerp(minWeight, maxWeight, norm) * weightK;    // weightK applied ONCE to result
if (weight outside form) → search other forms
return weight;
```

**After rev. 12950 (current production):**
```csharp
norm = formPolynomial(rnd.NextDouble());
norm = clamp(norm, 0, 1);
norm *= weightK;                                         // weightK applied to norm (1st time)
weight = GetPossibleNormalFloat(norm, min, max, 0.95, 0.55);
changedWeight = weight * weightK;                        // weightK applied to weight (2nd time)
if (changedWeight outside form) → search → return changedWeight
else → return weight;                                    // WITHOUT 2nd weightK!
```

**Critical difference**: `weightK` is applied **twice** but **asymmetrically**:
- If fish stays in same form → returned `weight` has weightK baked into norm only (indirect effect)
- If fish crosses to another form → returned `changedWeight` has weightK applied twice (direct multiplication)

### Configurable Parameters
| Parameter                                    | Hardcoded (Pond field) | Hardcoded (GlobalVariablesCache) | SQL (production) | Effect                                             |
|----------------------------------------------|------------------------|----------------------------------|------------------|----------------------------------------------------|
| `UseNormalDistributionForFishGeneratingFrom` | 0.75                   | 0.95                             | **0.95**         | Threshold above which normal distribution kicks in |
| `NormalDistributionForFishGeneratingSigma`   | 0.2                    | 0.55                             | **0.55**         | Sigma for Marsaglia half-normal                    |

**Injection chain**: SQL `GlobalVariables` → `GlobalVariablesCache` properties (defaults 0.95/0.55) → `Pond` static fields (defaults 0.75/0.2).
If SQL values exist → Pond gets 0.95/0.55. If SQL empty but GlobalVariablesCache works → Pond gets 0.95/0.55. If GlobalVariablesCache injection fails → Pond uses own defaults 0.75/0.2.

### Form-Specific Polynomials (Pre-Existing, NOT from FP-33182)

Applied to the uniform random value **before** the threshold check. These polynomials were part of the original BiteSystem and predate rev. 12950.

| Form   | Polynomial                                | Effect on norm                                                                                                |
|--------|-------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| Young  | `-0.0135x³ - 0.9727x² + 1.9829x + 0.0032` | Concave above identity: inflates norm (x=0.5→0.75, x=0.9→0.99)                                                |
| Common | `x` (identity)                            | No change                                                                                                     |
| Trophy | `x` (identity)                            | No change                                                                                                     |
| Unique | `8.5574x³ - 13.5356x² + 6.0272x - 0.0489` | Non-monotonic: peak ~0.77 at x≈0.3, dips below identity at x≈0.7. Produces two "humps" in weight distribution |

**Interaction with new system**: Because Young polynomial inflates norm (x=0.9→0.99), Young fish cross the 0.95 threshold more readily than Common/Trophy, making them disproportionately affected by the normal distribution branch. Unique polynomial creates complex multi-modal behavior.

### Scope of Change
This system applies **only to the BiteSystem weight generation path** (`PondServer.GetFish()` → `FishDescription.GenerateRandomWeight()`). Other paths (FishBox, Carousel, Scripted, Debug, Event) through `GameUtils.RandomizeFishWeight()` are **not affected** and continue using uniform / Box-Muller bias.

### Branch History of the Code

| Branch             | Has rev. 12950 code?                                              | Notes                                              |
|--------------------|-------------------------------------------------------------------|----------------------------------------------------|
| GRM20240409        | Originally merged, then reverted (r13378)                         | Reverted before release                            |
| HFH (next release) | Inherited, then reverted (r13848)                                 | Reverted before release                            |
| IMV20250220        | Inherited, reverted (r14879), env vars dropped (r14881)           | Clean revert — went to release WITHOUT the feature |
| JLM20250520        | **Kept** + received GlobalVariables fix (r14439) + tests (r14637) | Carried feature forward                            |
| KNW                | Received tests merge (r14703)                                     | Inherited from JLM                                 |
| LBM20251201        | **Present** — current production branch                           | Feature is live                                    |

## Test Results (from Confluence)

**⚠️ Note**: These results demonstrate `GetNextFloat` (pure normal distribution centered at midpoint, σ=0.2), **not** the production hybrid method `GetPossibleNormalFloat` (threshold=0.95, σ=0.55). The "Marsaglia" column shows what full Marsaglia-based normal distribution looks like vs uniform — it was used to justify the approach, not to test the final implementation.

**Interval 0.1 – 1 kg (simulated over long period):**

| Method    | Average  | <33% range | 33%-66% | >66% range |
|-----------|----------|------------|---------|------------|
| Uniform   | 0.550 kg | 32.95%     | 33.02%  | 34.03%     |
| Marsaglia | 0.550 kg | 4.44%      | 90.08%  | 5.48%      |

- Uniform: extreme values reach 0.1000013 ... 0.9999992 (essentially touching boundaries)
- Marsaglia: extreme values only reach 0.1373 ... 0.9799 (significant gap from boundaries)

**Interval 10 – 30 kg:**

| Method    | Average   | <33% range | 33%-66% | >66% range |
|-----------|-----------|------------|---------|------------|
| Uniform   | 20.003 kg | 32.95%     | 33.05%  | 34.00%     |
| Marsaglia | 20.001 kg | 4.47%      | 90.09%  | 5.44%      |

Average is preserved for `GetNextFloat` (by symmetry of N(0,σ) around midpoint). For the production hybrid `GetPossibleNormalFloat`, mathematical analysis shows the combined expected output is ~0.4997 of the range (vs ideal 0.5) — a negligible deviation of ~0.06%.

## Known Issues

### From JIRA Description (post-initial implementation)
1. **No Environment variables** — parameters weren't injected from DB. **Fixed** in r14437 (added SQL patch + changed hardcoded defaults to 0.95/0.55).
2. **Doesn't work with small fish** (<1 kg) — specific mechanism unclear; may be related to form polynomials or threshold interaction at small ranges.
3. **Overall implementation should be revised** — general sentiment from reviewers.

### From 20.11.2025 Update
4. **Scope too broad** — boundary weight suppression must apply **only to the eldest fish form** at a pond, not to all forms. Currently applies equally to all forms (Young, Common, Trophy, Unique).

### From Code Analysis

5. **`weightK` semantic change** — Before rev. 12950: `weight = lerp(min, max, norm) * weightK` (one multiplication). After: weightK applied to `norm` before generation AND to `weight` after, but asymmetrically — `changedWeight` (with 2nd weightK) is only returned on form cross-over; otherwise plain `weight` is returned. This changes the meaning of weightK for same-form fish.

6. **`weightK` lowers normal branch threshold** — `norm *= weightK` before the threshold check means the effective threshold drops from `0.95` to `0.95 / weightK`. With `weightK = 1.05` the threshold becomes ~0.905; with `weightK = 1.5` it drops to ~0.633; with `weightK = 2.0` to ~0.475. This progressively routes more fish through normal distribution as `weightK` grows. Additionally, any norm where `norm * weightK > 1.0` unconditionally enters the normal branch.

7. **Only upper boundary handled** — Confluence describes suppression at both boundaries (0-5% AND 95-100%), but `GetPossibleNormalFloat()` only handles `norm >= threshold` (upper). The lower boundary passes through as uniform lerp. This is likely an implementation gap vs the design intent.

8. **Form polynomial interaction** — Pre-existing polynomials interact with the new threshold in ways that may not have been considered:
   - Young: inflates norm (x=0.9→0.99), so Young fish enter normal branch disproportionately often
   - Unique: non-monotonic curve creates two-hump weight distribution, with complex behavior near threshold
   - Common/Trophy: identity (x→x), so threshold works as designed only for these forms

9. **Default discrepancy** — Three layers of defaults: Pond fields (0.75/0.2), GlobalVariablesCache (0.95/0.55), SQL (0.95/0.55). If GlobalVariablesCache injection into Pond fails, behavior changes from "5% normal zone with wide sigma" to "25% normal zone with narrow sigma".

10. **Test quality** — All tests (`NormalDistributionTest.cs`) are visualization-only (Console.WriteLine), zero assertions. The Comparison test uses hardcoded threshold 0.75 (not 0.95), so test results don't reflect production behavior. Tests added in r14637 also have zero assertions.

11. **Mathematical model errors** — identified by game design team after production deployment. Specific errors to be analyzed and fixed in FP-41845.

## Related Tasks

| Task         | Summary                                             | Status            | Relationship                                                                  |
|--------------|-----------------------------------------------------|-------------------|-------------------------------------------------------------------------------|
| **FP-41845** | Implement new system of weight generation           | In Progress       | Successor — fixes mathematical model errors                                   |
| **FP-38549** | Collect stats on prod of random fish generation     | Closed            | Statistics collection for analysis                                            |
| **FP-39522** | Disable new system of random fish weight generation | Closed (Won't Do) | Decided to rework the system entirely (FP-41845) instead of reverting on prod |
| **FP-42080** | New system of random fish weight Generation support | To Do             | Game design support task (Andrii Maslov)                                      |
| FP-26788     | Leaderboards and ratings                            | —                 | Parent epic                                                                   |

## Chronology

| Date       | Event                                                                                                                                               | Branch/Rev              |
|------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------|
| 2024-08-29 | Task created (Reporter: Ivan Malyshev)                                                                                                              | —                       |
| 2024-09-23 | Max Komisarenko: test results — uniform vs Marsaglia distribution comparison                                                                        | —                       |
| 2024-09-25 | **Original implementation merged** onto GRM branch                                                                                                  | GRM@12950               |
| 2024-09-25 | Kyrylo Rovnyi: "Changes are scary, not taking into current release"                                                                                 | —                       |
| 2024-10-17 | Stanislav Stefaniak: feature useful and needed for leaderboards; code correctness should be verified; pass to Andrii Maslov for distribution review | —                       |
| 2024-12-12 | **Reverted on GRM** before release                                                                                                                  | GRM@13378               |
| 2025-03-10 | **Reverted on HFH** before release                                                                                                                  | HFH@13848               |
| 2025-04-03 | Available on IMV branch (inherited from trunk after GRM)                                                                                            | IMV                     |
| 2025-05-25 | Discussion: DB patch for GlobalVariables missing                                                                                                    | —                       |
| 2025-06-24 | After discussion — task approved as-is                                                                                                              | —                       |
| 2025-06-25 | Stanislav Stefaniak: need to add `UseNormalDistributionForFishGeneratingFrom` and `NormalDistributionForFishGeneratingSigma` to GlobalVariables     | —                       |
| 2025-06-25 | Added GlobalVariables: changed defaults 0.75/0.2 → 0.95/0.55 + SQL patch                                                                            | IMV@14437, JLM@14439    |
| 2025-06-25 | Fixed patch name                                                                                                                                    | IMV@14440, JLM@14441    |
| 2025-08-04 | Added visualization tests (WeightStats, data-driven tests, still no assertions)                                                                     | JLM@14637, KNW@14703    |
| 2025-09-03 | **Clean revert of rev. 12950 on IMV** — IMV went to release WITHOUT the feature                                                                     | IMV@14879               |
| 2025-09-03 | Dropped GlobalVariables entries on IMV (SQL DELETE patch)                                                                                           | IMV@14881               |
| —          | **JLM kept the code** → inherited by KNW → inherited by LBM                                                                                         | JLM → KNW → LBM20251201 |
| —          | System deployed to production via JLM lineage                                                                                                       | LBM20251201 (current)   |
| 2025-11-20 | JIRA updated: boundary suppression only for eldest form                                                                                             | —                       |
| 2026-03-02 | Task reopened, linked to FP-41845                                                                                                                   | —                       |

## Milestones
- 2024-09-25: Original implementation (r12950, Max Komisarenko) — added `GetPossibleNormalFloat()`, modified `GenerateRandomWeight()`, added GlobalVariables + test
- 2025-06-25: GlobalVariables defaults changed to 0.95/0.55 + SQL patch (Stanislav Samoilov)
- 2025-09-03: Clean revert on IMV (release without feature); JLM lineage continued with feature intact
- Current: System on production (LBM20251201), mathematical model errors identified → FP-41845
