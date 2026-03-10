# FishSelector Form Ratio — Preliminary Analysis

> Parent: [Fish Generator card](_card.md)

## Overview

Form proportions (Y:C:T:U) are **emergent**, not explicitly configured. They arise from the FishSelector carousel, which builds a weighted lottery from multiple inputs. This document records preliminary findings on how to estimate form proportions from pond configuration without running FishSelector.

## How FishSelector Builds Form Probabilities

### Layer structure

```
Pond → Weather → Fish[species] → Layer[j]
                                   ├─ ProbabilityMap   (2D bitmap, SHARED by all forms in the layer)
                                   ├─ MapModifier      (float multiplier, per layer)
                                   ├─ TimeChart        (time-of-day curve, per layer)
                                   └─ Forms: [Young, Common, Trophy, ...]
```

**Key fact:** all forms within a single layer share the same `ProbabilityMap`. The spatial probability is identical — differentiation between forms comes from other factors.

### Per-form probability chain

For each (species, form) pair, FishSelector computes a selection weight:

```
pointProbability = Map.GetProbability(pos) * MapModifier   // per layer, shared by all forms
chartProbability = TimeChart.GetValue(timeOfDay)            // per layer, shared
attractorsModifier = FormRecord.AttractorsModifier          // PER FORM
baitAttraction = BaitData[FishId]                           // PER FORM (FishId is form-specific)
```

Attractor bonuses are scaled by `AttractorsModifier`:
```csharp
_addAttractors = addAttractors > 0 ? addAttractors * attractorsModifier : addAttractors;
_mulAttractors = mulAttractors > 1 ? (mulAttractors - 1) * attractorsModifier + 1 : mulAttractors;
```

**Note:** if no attractors are active at the position (addAttractors=0, mulAttractors=1), `AttractorsModifier` has **zero effect**.

### What differentiates forms

| Factor                   | Per form?                         | Effect on ratio                                                                       |
|--------------------------|-----------------------------------|---------------------------------------------------------------------------------------|
| ProbabilityMap (spatial) | No (per layer)                    | Only if forms are in different layers                                                 |
| MapModifier              | No (per layer)                    | Only if forms are in different layers                                                 |
| TimeChart                | No (per layer)                    | Only if forms are in different layers                                                 |
| **Layer assignment**     | **Yes**                           | **Primary driver** — forms in different layers have independent spatial distributions |
| **AttractorsModifier**   | **Yes**                           | Only at spots with active attractors                                                  |
| **Bait attraction**      | **Yes** (FishId is form-specific) | Depends on bait; optimized players reduce this variation                              |

### Conclusion: layer assignment is the main driver

If all forms are in the **same layer**: under ideal conditions (no attractors, optimal bait), their probabilities are approximately equal. Ratio ≈ 1:1:1:1.

If forms are in **different layers**: each layer has its own map and MapModifier — the ratio is primarily determined by `mapProbability * MapModifier` at the player's position.

## Estimating Y:C:T:U Without Running FishSelector

### Approach

1. Load pond config for target pond + weather
2. For each form of the target species: identify which layer it belongs to
3. At a representative "good fishing spot": read `mapProbability * MapModifier` per layer
4. Compute ratio of these values → approximate Y:C:T:U proportions

This does **not** require running FishSelector — just reading configuration data.

### Caveats

- **Spatial variation:** bite maps are 2D — probability varies by position. Production statistics aggregate across all players/positions. A single-point estimate gives the ratio at that spot, not the aggregate.
- **Time averaging:** time charts modulate probabilities throughout the day. Production data integrates over all times. An estimate at a single time point may differ from the daily average.
- **Bait bias:** different baits have different attraction bonuses per form (via FishId). Players optimize bait choice, which may shift form proportions toward their target.
- **Attractor spots:** at positions with active attractors, `AttractorsModifier` differences between forms take effect. At neutral positions, they don't.

### Practical accuracy

For a rough estimate (±5-10%), reading layer configuration should suffice — the primary driver is which layer each form belongs to and the relative MapModifier values. For precise match with production data, spatial averaging across the map and time integration would be needed.

## Production Reference Data

From FishFact (2 months, Source='B'), form proportions by total fish count:

| Species | Pond | Young | Common | Trophy | Unique |
|---------|------|-------|--------|--------|--------|
| Nile Perch | Congo River | 50.2% | 27.8% | 12.6% | 9.3% |
| Northern Pike | Saint-Croix | 0% (no form) | 73.2% | 24.8% | 2.0% |

These proportions reflect aggregate player behavior (all positions, times, baits). They serve as validation targets for config-based estimation.

## Simulator Integration Plan

The weight simulator (FP-41845) produces **per-form weight distributions**. Form ratio estimation is a separate capability that can be combined with it:

```
overall_histogram[bucket] = Σ(p_form × per_form_distribution[bucket])
```

Two modes for `p_form`:
- **Predicted:** from pond config analysis (no production data needed)
- **Actual:** from FishFact counts (for validation)

Comparing predicted vs actual proportions shows how player behavior shifts theoretical ratios — itself valuable information for game designers.

## Key Source Files

| File | Role |
|------|------|
| `Shared/BiteSystem/ServerOnly/PondServer.cs` (GetFish, lines 304-425) | Iterates Weather → Fish → Layers → Forms, calls UpdateRecord per form |
| `Shared/BiteSystem/ServerOnly/FishSelector.cs` | Builds carousel, weighted lottery selection |
| `Shared/BiteSystem/Common/ObjectModel/FishDescription.cs` | `FormRecord` with `AttractorsModifier` |
| `BiteEditor.ObjectModel/FishLayer.cs` | Layer structure: `ProbabilityMap`, `Forms` list |
| `BiteEditor.ObjectModel/Fish.cs` | Groups layers per species |
| `BiteEditor.ObjectModel/Weather.cs` | Groups fish per weather condition |
| `BiteEditor.ObjectModel/Ponds.cs` | Loads `*_settings.srv` JSON → Pond objects |
