# Fish Weight Decay System — Design Spec

**Date:** 2026-03-12
**Task:** FP-41845 — Implement New System of Weight Generation
**Phase:** 2a — Algorithm Design & Implementation

## Overview

Replace legacy weight generation (polynomials + Marsaglia re-roll from r12950) with a clean, configurable decay system. Fish weights are generated uniformly up to a configurable threshold, then a decay curve reduces probability of near-maximum weights.

## Safety Philosophy

**Fail-safe defaults.** If DB settings are unavailable, the system falls back to the most restrictive configuration: `None` algorithm (hard ceiling at threshold). The `Uniform` algorithm (current behavior, no decay) is explicitly the most permissive option and must be intentionally selected by GD.

Default parameter values for PowerLaw/Exponential are intentionally aggressive (steepness=50), producing behavior nearly identical to `None`.

## Commit Plan

Five isolated commits, each independently deployable and testable:

### Commit 1: Legacy Cleanup

**Goal:** Remove polynomials, rename GlobalVars, clean up method signatures. Behavior unchanged (uniform distribution).

**FishDescription.cs:**
- Remove `_formToNorm` dictionary (Young/Unique polynomials, Common/Trophy identity)
- `_formToNorm[form](rnd.NextDouble())` → `rnd.NextDouble()`
- Rename method variables to descriptive names (e.g. `norm` → `uniform`, clarify lerp)
- Signature: remove `normalDistributionSigma`, rename `normalPercentageFrom` → `decayThreshold`

**PondServer.cs:**
- Rename `UseNormalDistributionForFishGeneratingFrom` → `FishWeightDecayThreshold`
- Delete `NormalDistributionForFishGeneratingSigma`
- Update call site (line 440-441)

**GlobalVariablesCache.cs:**
- Rename property `UseNormalDistributionForFishGeneratingFrom` → `FishWeightDecayThreshold`
- Delete `NormalDistributionForFishGeneratingSigma` property
- Update `UpdateStaticVariables()` accordingly

**FishWeightSimulationService.cs:**
- Update call to `GenerateRandomWeight()` (signature change)

**StatsController.FishWeightSimulation.cs + FishWeightSimulationViewModel.cs:**
- Update parameter names passed to simulation service

**SQL Patch:**
- UPDATE: rename `BiteSystem.UseNormalDistributionForFishGeneratingFrom` → `BiteSystem.FishWeightDecayThreshold`
- DELETE: `BiteSystem.NormalDistributionForFishGeneratingSigma`

### Commit 2: Decay Algorithms

**Goal:** Implement decay system with four algorithms, configurable via GlobalVariables. Default = `None` (safe). Behavior unchanged until GD switches algorithm.

**New files in `BiteSystem/Common/`:**

```
IFishWeightDecay.cs         — interface: Sample(Random, double) → double
NoDecay.cs                  — u => 0 (hard ceiling at threshold)
UniformDecay.cs             — u => u (pass-through, current behavior)
PowerLawDecay.cs            — inverse CDF: 1 - (1-u)^(1/(α+1))
ExponentialDecay.cs         — inverse CDF: -ln(1 - u*(1-e^(-λ))) / λ
FishWeightDecayAlgorithm.cs — enum: None, Uniform, PowerLaw, Exponential
FishWeightDecayScope.cs     — enum: None, Heaviest, Extremes, All
FishWeightGeneratorConfig.cs — config object with static Current
```

**FishWeightGeneratorConfig:**
```csharp
public class FishWeightGeneratorConfig
{
    public float DecayThreshold { get; set; } = 0.95f;
    public FishWeightDecayScope DecayScope { get; set; } = FishWeightDecayScope.Heaviest;
    public IFishWeightDecay DecayAlgorithm { get; set; } = NoDecay.Instance;
    public static FishWeightGeneratorConfig Current { get; set; } = new();
}
```

**Scope determination** uses enum order of available forms in `_forms`:
```csharp
var heaviest = _forms.Keys.Max();   // FishForm enum: Young=0 < Common=1 < Trophy=2 < Unique=3
var lightest = _forms.Keys.Min();
```

**Decay application in GenerateRandomWeight:**
- Check if form matches scope → if not, skip decay
- If uniform value >= threshold → remap to tail zone [0,1], apply decay, remap back
- Clamp + lerp + crossover detection unchanged
- Decay modifies the normalized weight position (0..1) before min-max lerp. WeightK is applied to the lerped weight afterwards — oversize fish behavior is unaffected

**Thread safety:** `UpdateStaticVariables()` must always create a new `FishWeightGeneratorConfig` instance and assign it atomically to `Current` — never mutate an existing instance in-place. Reference assignment in .NET is atomic.

**PondServer.cs:** Add new static fields, pass `FishWeightGeneratorConfig.Current` to `GenerateRandomWeight`.

**GlobalVariablesCache.cs:** Four new properties + config assembly in `UpdateStaticVariables()`:
- `BiteSystem.FishWeightDecayAlgorithm` (string, parsed via Enum.TryParse)
- `BiteSystem.FishWeightDecayScope` (string, parsed via Enum.TryParse)
- `BiteSystem.FishWeightDecayPowerLawSteepness` (float, default 50.0)
- `BiteSystem.FishWeightDecayExponentialRate` (float, default 50.0)

**SQL Patch:** INSERT four new variables with safe defaults.

### Commit 3: Move Simulator to Content

**Goal:** Relocate Fish Weight Simulation page from Stats to Content > Fishing. Purely organizational.

**Changes:**
- Create new controller (e.g. `FishWeightGeneratorSettingsController`) in a `Settings` namespace area
- Move partial controller code from `StatsController.FishWeightSimulation.cs`
- Move view from `Views/Stats/FishWeightSimulation.cshtml` to new controller's view folder
- ViewModel stays in place
- Remove link from `Stats/Stats.cshtml` ("Balancing tools" section)
- Add link to `Home/Contents.cshtml` ("Fishing" section)
- Authorization: inherits from new controller, Save restricted to GameDesigner role

### Commit 4: Settings UI

**Goal:** Transform simulator page into a settings + simulation panel.

**UI elements:**
- Algorithm dropdown: None / Uniform / PowerLaw / Exponential
- Threshold input (0–1)
- PowerLaw Steepness: slider + numeric input
- Exponential Rate: slider + numeric input
- Scope dropdown: None / Heaviest / Extremes / All
- **Save** button (GameDesigner role only) — writes to GlobalVariables in DB
- **Refresh Caches** button (GameDesigner role only) — pushes to game servers
- **Reset** button — resets all fields (visible + hidden) to current DB values
- Confirmation dialog before Save: warns that settings affect fish weight generation on all servers

**Behavior:**
- On load: fields populated from GlobalVariablesCache (current prod values)
- Algorithm-specific fields: visible only for selected algorithm
- Hidden field values preserved in memory when switching algorithms
- Reset clears everything: algorithm, all algorithm-specific params (visible and hidden)
- Simulation uses form values (not cache) — GD tunes, simulates, then saves

### Commit 5: Preview Modal

**Goal:** Interactive decay curve explorer integrated into the settings page.

**Preview button** opens fullscreen modal:
- Chart showing tail zone (threshold → 100% of weight range)
- Threshold slider
- Per-algorithm steepness/rate sliders
- Checkboxes to toggle curves: None, Uniform, PowerLaw, Exponential
- Kendo chart rendering
- **Apply** button — copies selected settings from Preview into main form

## GlobalVariables Summary

| Variable                                      | Type   | Code Default | DB Default                   | Description              |
|-----------------------------------------------|--------|--------------|------------------------------|--------------------------|
| `BiteSystem.FishWeightDecayThreshold`         | float  | 0.95         | 0.95 (renamed from existing) | Tail zone start position |
| `BiteSystem.FishWeightDecayAlgorithm`         | string | `"None"`     | `"None"`                     | Active algorithm         |
| `BiteSystem.FishWeightDecayScope`             | string | `"Heaviest"` | `"Heaviest"`                 | Which forms get decay    |
| `BiteSystem.FishWeightDecayPowerLawSteepness` | float  | 50.0         | 50.0                         | α exponent               |
| `BiteSystem.FishWeightDecayExponentialRate`   | float  | 50.0         | 50.0                         | λ rate                   |

## Algorithms

| Algorithm   | Inverse CDF: u∈[0,1] → t∈[0,1] | Density at max (t=1) | Parameter     |
|-------------|--------------------------------|----------------------|---------------|
| None        | `u → 0`                        | 0 (hard ceiling)     | —             |
| Uniform     | `u → u`                        | 1 (no decay)         | —             |
| PowerLaw    | `u → 1-(1-u)^(1/(α+1))`        | 0 (zero density)     | α (steepness) |
| Exponential | `u → -ln(1-u·(1-e⁻ᵞ))/λ`       | e⁻ᵞ > 0 (asymptotic) | λ (rate)      |

Where u is a uniform random sample, t is the resulting position in the tail zone.
Valid ranges: α > 0, λ > 0. Invalid values should be clamped at the parsing layer.

## Design Notes

**Scope vs Algorithm interaction:** `DecayAlgorithm = None` disables decay regardless of scope. `DecayScope = None` also disables decay regardless of algorithm. Two independent "off switches" — GD should be aware that both must be set to non-None for decay to take effect.

**IFishWeightDecay.Sample(Random, double):** The `Random` parameter is unused by current implementations (all four are pure inverse-CDF transforms of the `double` input). It is included for extensibility — future algorithms may need additional random draws.

## Extensibility

- New algorithms: implement `IFishWeightDecay`, add enum value, add GlobalVariable for parameters
- Both-sides decay (lower tail): future config option, `IFishWeightDecay` interface already supports
- Cross-form decay: future scope extension
- Refactoring to `FishWeightGenerator` class: deferred, safe to do later if needed

## Files Affected

### BiteSystem/Common/ (new)
- `IFishWeightDecay.cs`, `NoDecay.cs`, `UniformDecay.cs`, `PowerLawDecay.cs`, `ExponentialDecay.cs`
- `FishWeightDecayAlgorithm.cs`, `FishWeightDecayScope.cs`, `FishWeightGeneratorConfig.cs`

### BiteSystem/Common/ObjectModel/ (modified)
- `FishDescription.cs` — remove polynomials, add decay logic

### BiteSystem/ServerOnly/ (modified)
- `PondServer.cs` — rename/add static fields, update call site

### BiteSystem/Common/ (modified)
- `FishWeightSimulationService.cs` — update GenerateRandomWeight() call signature

### SharedLib/Config/ (modified)
- `GlobalVariablesCache.cs` — rename/add properties, update UpdateStaticVariables()

### WebAdmin/ (modified + new)
- `Controllers/StatsController.FishWeightSimulation.cs` — update parameter names (Commit 1), then move (Commit 3)
- `Models/BiteSystem/FishWeightSimulationViewModel.cs` — update defaults
- New controller for settings page
- Move + extend simulation view
- Update navigation (Stats.cshtml, Contents.cshtml)

### SQL/Patches/ (new)
- Patch 1: rename + delete old GlobalVariables
- Patch 2: insert new GlobalVariables
- Both patches use IF EXISTS / IF NOT EXISTS guards for idempotent reruns

### Not modified
- `NormalDistribution.cs` — used by FishSelector, kept as-is
