# Fish Weight Edge Distribution System — Design Spec

**Date:** 2026-03-12
**Task:** FP-41845 — Implement New System of Weight Generation
**Phase:** 2a — Algorithm Design & Implementation

## Overview

Replace legacy weight generation (polynomials + Marsaglia re-roll from r12950) with a clean, configurable edge distribution system. Fish weights are generated uniformly within the central zone, then an edge distribution curve reduces probability of weights near the extremes of the range.

## Safety Philosophy

**Fail-safe defaults.** If DB settings are unavailable, the system falls back to the most restrictive configuration: `None` algorithm (hard ceiling at edge zone boundary). The `Uniform` algorithm (current behavior, no edge distribution) is explicitly the most permissive option and must be intentionally selected by GD.

Default parameter values for PowerLaw/Exponential are intentionally aggressive (steepness=50), producing behavior nearly identical to `None`.

## Naming Convention

**Enum short names vs GlobalVariable long names.** The edge distribution enums live in their own namespace (`BiteSystem.ServerOnly.FishWeight.EdgeDistribution`), so they use short names: `EdgeDistributionType`, `EdgeDistributionScope`. The GlobalVariablesCache properties live in a flat class, so they use prefixed long names: `FishWeightEdgeDistribution`, `FishWeightEdgeScope`. The mapping:

| Enum (short, in `EdgeDistribution` namespace) | GV property (long, in `GlobalVariablesCache`) |
|-----------------------------------------------|-----------------------------------------------|
| `EdgeDistributionType`                        | `FishWeightEdgeDistribution`                  |
| `EdgeDistributionScope`                       | `FishWeightEdgeScope`                         |

`Enum.TryParse<EdgeDistributionType>(GlobalVariablesCache.FishWeightEdgeDistribution, ...)` bridges the two.

**Zone fraction vs threshold.** External API uses zone fraction (0.05 = 5% of weight range is the edge zone). Internally, the zone fraction maps to an edge boundary: for the upper edge, `threshold = 1.0 - upperZoneFraction` (boundary from below); for the lower edge, the fraction is the boundary directly (`u <= lowerZoneFraction`). Zone fraction is directionally neutral — the same value (e.g. 0.05) means "5% of the range" regardless of which edge it's applied to.

## Commit Plan

Five commits (1–5), each independently deployable and testable. Pre-commit local verification (fixed-seed snapshot comparison) ensures behavioral equivalence through refactoring.

### Commit 1: Legacy Cleanup

**Goal:** Remove polynomials, rename GlobalVars, clean up method signatures. Behavior unchanged (uniform distribution).

**FishDescription.cs:**
- Remove `_formToNorm` dictionary (Young/Unique polynomials, Common/Trophy identity)
- Remove `GenerateRandomWeight()` entirely — logic moves to `FishWeightGenerator` in ServerOnly
- `FishDescription` becomes a pure data class (forms, weights, detractors + getters)
- `RandomWeight` struct stays — it's a data type, not logic

**New: `FishWeightGenerator.cs` in `BiteSystem/ServerOnly/FishWeight/`:**
- Created via `svn copy` from `FishDescription.cs` (preserves blame history), then contents cleaned up
- Static class with weight mapping logic extracted from `FishDescription`
- Namespace: `BiteSystem.ServerOnly.FishWeight`
- `static RandomWeight WeightFromNormalized(FishDescription fish, double u, FishForm form, float weightK)`
- Responsibility: clamp [0,1] → lerp min-max → apply weightK → crossover detection
- Uses `fish.GetFormData()`, `fish.GetFormsAndDescription()` for data access

**PondServer.cs:**
- Remove old statics `UseNormalDistributionForFishGeneratingFrom`, `NormalDistributionForFishGeneratingSigma`
- Update call site (line 440-441)

**GlobalVariablesCache.cs:**
- Rename property `UseNormalDistributionForFishGeneratingFrom` → `FishWeightUpperEdgeZoneFraction`, convert default from 0.95 to 0.05
- Delete `NormalDistributionForFishGeneratingSigma` property
- Update `UpdateStaticVariables()` accordingly

**FishWeightSimulationService.cs:**
- svn move from `BiteSystem/Common/` → `BiteSystem/ServerOnly/` (preserve history)
- MUST be in the same commit as `GenerateRandomWeight()` removal — otherwise build breaks
- Update call: `GenerateRandomWeight()` → `FishWeightGenerator.WeightFromNormalized()`
- Update `using` directives for new namespace

**StatsController.FishWeightSimulation.cs + FishWeightSimulationViewModel.cs:**
- Update parameter names passed to simulation service

**SQL Patch:**
- UPDATE: rename `BiteSystem.UseNormalDistributionForFishGeneratingFrom` → `BiteSystem.FishWeightUpperEdgeZoneFraction`, convert value (`1.0 - oldValue`)
- DELETE: `BiteSystem.NormalDistributionForFishGeneratingSigma`

### Commit 2: Edge Distribution Algorithms

**Goal:** Implement edge distribution system with four algorithms, configurable via GlobalVariables. Default = `None` (hard ceiling — safe). NOTE: this IS a behavior change from current production (where full weight range is reachable). GD must configure desired algorithm before deployment.

**New files in `BiteSystem/ServerOnly/FishWeight/` and `FishWeight/Edge/`:**

IMPORTANT: All edge distribution code goes in `ServerOnly/`, NOT `Common/`. The `Common` namespace is shared with the editor and may be exposed to the client.

```
FishWeight/
├── FishWeightGenerator.cs           — static class: full generation pipeline (Commit 1 + 2)
├── FishWeightGeneratorConfig.cs     — immutable config with volatile static Current
└── EdgeDistribution/
    ├── IEdgeDistributionStrategy.cs — interface: Sample(Random, double) → double; EdgeAreaFraction
    ├── EdgeDistributionType.cs      — enum: None, Uniform, PowerLaw, Exponential
    ├── EdgeDistributionScope.cs     — [Flags] enum: 14 bit flags (6 role-based + 8 form-specific). No presets in enum (JS-only)
    └── Strategies/
        ├── CapAtThreshold.cs        — u → 0 (hard ceiling); EdgeAreaFraction = 0
        ├── Unrestricted.cs          — u → u (pass-through); EdgeAreaFraction = 1
        ├── PowerLawEdge.cs          — inverse CDF: 1 - (1-u)^(1/(α+1)); EdgeAreaFraction = 1/(α+1)
        └── ExponentialEdge.cs       — inverse CDF: -ln(1 - u*(1-e^(-λ))) / λ; EdgeAreaFraction = (1-e^(-λ))/λ
```

Namespaces:
- `BiteSystem.ServerOnly.FishWeight` — generator, config
- `BiteSystem.ServerOnly.FishWeight.EdgeDistribution` — interface, enums
- `BiteSystem.ServerOnly.FishWeight.EdgeDistribution.Strategies` — four strategy implementations

**FishWeightGeneratorConfig (immutable):**
```csharp
using BiteSystem.ServerOnly.FishWeight.EdgeDistribution;
using BiteSystem.ServerOnly.FishWeight.EdgeDistribution.Strategies;

namespace BiteSystem.ServerOnly.FishWeight
{
    public class FishWeightGeneratorConfig
    {
        // All role-based edges enabled (6 flags). Safety default.
        private const EdgeDistributionScope AllRoleEdges =
            EdgeDistributionScope.HeaviestUpper | EdgeDistributionScope.HeaviestLower |
            EdgeDistributionScope.LightestUpper | EdgeDistributionScope.LightestLower |
            EdgeDistributionScope.OthersUpper   | EdgeDistributionScope.OthersLower;

        public float UpperEdgeZoneFraction { get; }
        public float LowerEdgeZoneFraction { get; }
        public EdgeDistributionScope EdgeScope { get; }
        public IEdgeDistributionStrategy EdgeStrategy { get; }

        public FishWeightGeneratorConfig(
            float upperEdgeZoneFraction = 0.05f,
            float lowerEdgeZoneFraction = 0.05f,
            EdgeDistributionScope edgeScope = AllRoleEdges,
            IEdgeDistributionStrategy edgeStrategy = null)
        {
            UpperEdgeZoneFraction = upperEdgeZoneFraction;
            LowerEdgeZoneFraction = lowerEdgeZoneFraction;
            EdgeScope = edgeScope;
            EdgeStrategy = edgeStrategy ?? CapAtThreshold.Instance;
        }

        // volatile ensures visibility across CPU caches.
        // Reference assignment in .NET is atomic — no mid-call config mutation.
        private static volatile FishWeightGeneratorConfig _current = new FishWeightGeneratorConfig();
        public static FishWeightGeneratorConfig Current
        {
            get => _current;
            internal set => _current = value;
        }
    }
}
```
Immutable by design — properties are get-only. `UpdateStaticVariables()` creates new instance and assigns atomically to `Current`. DB default `"All"` is resolved to individual flag names in `FromSettings()` before parsing.

**Architecture: separation of concerns.**

All weight generation logic lives in `ServerOnly`. `FishDescription` (Common) is a pure data class — forms, weights, detractors, and getters. `FishWeightGenerator` (ServerOnly) is the complete weight generation pipeline.

**FishWeightGenerator** has two methods:

```csharp
using BiteSystem.ServerOnly.FishWeight.EdgeDistribution;
using BiteSystem.ServerOnly.FishWeight.EdgeDistribution.Strategies;

namespace BiteSystem.ServerOnly.FishWeight
{
    public static class FishWeightGenerator
    {
        // Commit 1: deterministic mapping — lerp + weightK + crossover
        // Internal after Commit 2 — callers should use Generate()
        internal static RandomWeight WeightFromNormalized(
            FishDescription fish, double u, FishForm form, float weightK) { ... }

        // Commit 2: full pipeline — random → normalized piecewise inverse CDF → lerp → crossover
        public static RandomWeight Generate(
            Random rnd, FishDescription fish, FishForm form, float weightK,
            FishWeightGeneratorConfig config)
        {
            var u = rnd.NextDouble();
            var (applyUpper, applyLower) = GetEdgeFlags(form, fish, config.EdgeScope);

            var upperZone = (double)config.UpperEdgeZoneFraction;
            var lowerZone = (double)config.LowerEdgeZoneFraction;
            var areaFrac = config.EdgeStrategy.EdgeAreaFraction;

            // Normalized piecewise inverse CDF sampling.
            // The split point u* divides [0,1] proportionally to area under each PDF region.
            // This ensures the density is continuous at the zone boundaries (no spike).
            // See edge-distribution.md §5–6 for derivation.

            if (applyUpper && applyLower && upperZone > 0 && lowerZone > 0)
            {
                // Three-region split: lower edge + central + upper edge
                var threshold = 1.0 - upperZone;
                var centralWidth = threshold - lowerZone;
                var lowerArea = lowerZone * areaFrac;
                var upperArea = upperZone * areaFrac;
                var totalArea = lowerArea + centralWidth + upperArea;
                var u1 = lowerArea / totalArea;
                var u2 = (lowerArea + centralWidth) / totalArea;

                if (u < u1)
                {
                    var w = u / u1;
                    u = lowerZone - config.EdgeStrategy.Sample(rnd, 1.0 - w) * lowerZone;
                }
                else if (u < u2)
                {
                    u = lowerZone + (u - u1) / (u2 - u1) * centralWidth;
                }
                else
                {
                    var w = (u - u2) / (1.0 - u2);
                    u = threshold + config.EdgeStrategy.Sample(rnd, w) * upperZone;
                }
            }
            else if (applyUpper && upperZone > 0)
            {
                // Two-region split: central + upper edge
                var threshold = 1.0 - upperZone;
                var splitPoint = threshold / (threshold + upperZone * areaFrac);

                if (u < splitPoint)
                {
                    u = u / splitPoint * threshold;
                }
                else
                {
                    var w = (u - splitPoint) / (1.0 - splitPoint);
                    u = threshold + config.EdgeStrategy.Sample(rnd, w) * upperZone;
                }
            }
            else if (applyLower && lowerZone > 0)
            {
                // Two-region split: lower edge + central
                var centralStart = lowerZone;
                var splitPoint = lowerZone * areaFrac / (lowerZone * areaFrac + (1.0 - lowerZone));

                if (u < splitPoint)
                {
                    var w = u / splitPoint;
                    u = lowerZone - config.EdgeStrategy.Sample(rnd, 1.0 - w) * lowerZone;
                }
                else
                {
                    u = lowerZone + (u - splitPoint) / (1.0 - splitPoint) * (1.0 - lowerZone);
                }
            }

            return WeightFromNormalized(fish, u, form, weightK);
        }

        private static (bool upper, bool lower) GetEdgeFlags(FishForm form, FishDescription fish,
            EdgeDistributionScope scope)
        {
            if (scope == EdgeDistributionScope.None) return (false, false);

            // Layer 1: Role-based flags (Heaviest/Lightest/Others)
            FishForm heaviest = 0, lightest = FishForm.Unique;
            foreach (var f in fish.GetForms())
            {
                if (f > heaviest) heaviest = f;
                if (f < lightest) lightest = f;
            }

            bool isHeaviest = form == heaviest;
            bool isLightest = form == lightest;
            bool isOther = !isHeaviest && !isLightest;

            bool upper = (isHeaviest && scope.HasFlag(EdgeDistributionScope.HeaviestUpper))
                      || (isLightest && scope.HasFlag(EdgeDistributionScope.LightestUpper))
                      || (isOther && scope.HasFlag(EdgeDistributionScope.OthersUpper));

            bool lower = (isHeaviest && scope.HasFlag(EdgeDistributionScope.HeaviestLower))
                      || (isLightest && scope.HasFlag(EdgeDistributionScope.LightestLower))
                      || (isOther && scope.HasFlag(EdgeDistributionScope.OthersLower));

            // Layer 2: Form-specific flags (Young/Common/Trophy/Unique) — OR into role results
            switch (form)
            {
                case FishForm.Young:
                    upper |= scope.HasFlag(EdgeDistributionScope.YoungUpper);
                    lower |= scope.HasFlag(EdgeDistributionScope.YoungLower);
                    break;
                case FishForm.Common:
                    upper |= scope.HasFlag(EdgeDistributionScope.CommonUpper);
                    lower |= scope.HasFlag(EdgeDistributionScope.CommonLower);
                    break;
                case FishForm.Trophy:
                    upper |= scope.HasFlag(EdgeDistributionScope.TrophyUpper);
                    lower |= scope.HasFlag(EdgeDistributionScope.TrophyLower);
                    break;
                case FishForm.Unique:
                    upper |= scope.HasFlag(EdgeDistributionScope.UniqueUpper);
                    lower |= scope.HasFlag(EdgeDistributionScope.UniqueLower);
                    break;
            }

            return (upper, lower);
        }
    }
}
```

**Callers — one line each:**

PondServer:
```csharp
var randomWeight = FishWeightGenerator.Generate(
    playerData.Rnd, _fish[name], form, weightK, FishWeightGeneratorConfig.Current);
```

SimulationService (can pass custom config from UI, not just Current):
```csharp
var randomWeight = FishWeightGenerator.Generate(rnd, fish, form, weightK, simulationConfig);
```

Edge distribution modifies the normalized weight position (0..1) before min-max lerp. WeightK is applied to the lerped weight afterwards — oversize fish behavior is unaffected.

**Thread safety:** `FishWeightGeneratorConfig` is immutable (get-only properties). `UpdateStaticVariables()` creates a new instance and assigns atomically to `_current` (volatile). Reference assignment in .NET is atomic; `volatile` ensures cross-CPU-cache visibility. No mid-call config mutation possible. `Current` setter is `internal` — only BiteSystem assembly can write. Since `GlobalVariablesCache.UpdateStaticVariables()` lives in SharedLib (different assembly), config assembly lives in `FishWeightGeneratorConfig.UpdateFromGlobalVariables()` inside BiteSystem. `UpdateStaticVariables()` calls it as a one-liner. BiteSystem already references SharedLib, so `GlobalVariablesCache` properties are accessible. Tests write via `[InternalsVisibleTo("BiteSystem.Tests")]`.

**Zone overlap guard:** `UpdateStaticVariables()` clamps `upperZone + lowerZone <= 0.8` (at least 20% uniform zone). On overlap, both zones are proportionally shrunk.

**PondServer.cs:** Remove old static fields, replace with one-line call to `FishWeightGenerator.Generate()`.

**GlobalVariablesCache.cs:** Five new properties + config assembly in `UpdateStaticVariables()`:
- `BiteSystem.FishWeightLowerEdgeZoneFraction` (float, default 0.05)
- `BiteSystem.FishWeightEdgeDistribution` (string → `Enum.TryParse<EdgeDistribution>()`, default `"None"`)
- `BiteSystem.FishWeightEdgeScope` (string → `Enum.TryParse<EdgeDistributionScope>()`, default `"All"`)
- `BiteSystem.FishWeightEdgePowerLawSteepness` (float, default 50.0)
- `BiteSystem.FishWeightEdgeExponentialRate` (float, default 50.0)

Note: GV property names use the `FishWeight` prefix (flat namespace), while enum types use short names (own `Edge` namespace).

**SQL Patch:** INSERT five new variables with safe defaults.

### Commit 3: Move Simulator to Content

**Goal:** Relocate Fish Weight Simulation page from Stats to Content > Fishing. Purely organizational.

**Changes:**
- Create partial `SettingsController` in `WebAdmin.Controllers.Settings` namespace
- File: `Controllers/Settings/SettingsController.FishWeightGenerator.cs`
- Move action methods from `StatsController.FishWeightSimulation.cs`
- Move view from `Views/Stats/FishWeightSimulation.cshtml` to `Views/Settings/FishWeightGenerator.cshtml`
- ViewModel stays in place
- Remove link from `Stats/Stats.cshtml` ("Balancing tools" section)
- Add link to `Home/Contents.cshtml` ("Fishing" section)
- Authorization: page viewable with RW/RO role. Save/Refresh restricted to `Game Designer` role (exists in `RoleBasedAuthModel`, needs wiring to controller action). Initial implementation: just add the button, role check TBD.

### Commit 4: Settings UI

**Goal:** Transform simulator page into a settings + simulation panel.

**UI elements:**
- Algorithm dropdown: None / Uniform / PowerLaw / Exponential
- Upper Edge Zone Fraction input (0–1)
- Lower Edge Zone Fraction input (0–1)
- PowerLaw Steepness: slider + numeric input
- Exponential Rate: slider + numeric input
- Scope: inline SVG preview + Edit Scope modal (Role/Form checkbox matrix, SVG bezier preview). No dropdown — presets are JS-only convenience in the modal
- **Save** button (GameDesigner role only) — writes to GlobalVariables in DB via `EdgeDistributionSettingsModel` + `DalFactory.GetSysProvider()`
- **Refresh Caches** button (GameDesigner role only) — pushes to game servers
- **Reset** button — resets all fields (visible + hidden) to current DB values
- Confirmation dialog before Save: warns that settings affect fish weight generation on all servers

**Behavior:**
- On load: fields populated from DB via `EdgeDistributionSettingsModel` (reads directly, no GlobalVariablesCache dependency)
- Algorithm-specific fields: visible only for selected algorithm
- Hidden field values preserved in memory when switching algorithms
- Reset clears everything: algorithm, all algorithm-specific params (visible and hidden)
- Simulation uses form values (not cache) — GD tunes, simulates, then saves

### Commit 5: Preview Modal

**Goal:** Interactive edge distribution curve explorer integrated into the settings page.

**Preview button** opens fullscreen modal:
- Chart showing edge zone with distribution curves
- Zone fraction slider
- Per-algorithm steepness/rate sliders
- Checkboxes to toggle curves: None, Uniform, PowerLaw, Exponential
- Kendo chart rendering (TBD: verify Kendo can render smooth curves, not just angular polylines)
- **Apply** button — copies selected settings from Preview into main form

## GlobalVariables Summary

| Variable                                     | Type   | Code Default | DB Default                     | Description                |
|----------------------------------------------|--------|--------------|--------------------------------|----------------------------|
| `BiteSystem.FishWeightUpperEdgeZoneFraction` | float  | 0.05         | 0.05 (converted from existing) | Upper edge zone size (0–1) |
| `BiteSystem.FishWeightLowerEdgeZoneFraction` | float  | 0.05         | 0.05                           | Lower edge zone size (0–1) |
| `BiteSystem.FishWeightEdgeDistribution`      | string | `"None"`     | `"None"`                       | Active algorithm           |
| `BiteSystem.FishWeightEdgeScope`             | string | `"All"`      | `"All"`                        | Which forms × edges        |
| `BiteSystem.FishWeightEdgePowerLawSteepness` | float  | 50.0         | 50.0                           | α exponent                 |
| `BiteSystem.FishWeightEdgeExponentialRate`   | float  | 50.0         | 50.0                           | λ rate                     |

## Algorithms

| Algorithm   | Inverse CDF: u∈[0,1] → t∈[0,1] | Density at max (t=1)    | Parameter     |
|-------------|--------------------------------|-------------------------|---------------|
| None        | `u → 0`                        | 0 (hard ceiling)        | —             |
| Uniform     | `u → u`                        | 1 (no redistribution)   | —             |
| PowerLaw    | `u → 1-(1-u)^(1/(α+1))`        | 0 (zero density)        | α (steepness) |
| Exponential | `u → -ln(1-u·(1-e^(−λ)))/λ`    | e^(−λ) > 0 (asymptotic) | λ (rate)      |

Where u is a uniform random sample, t is the resulting position in the edge zone.

**Parameter validation:**

| Parameter     | Valid range | Where enforced        | Behavior                                 |
|---------------|-------------|-----------------------|------------------------------------------|
| Zone fraction | [0.0, 1.0]  | `FromSettings()`      | Clamp to bounds                          |
| α (steepness) | any ≥ 0     | `Sample()` internally | `Math.Max(α, 1e-10)` at computation time |
| λ (rate)      | any ≥ 0     | `Sample()` internally | `Math.Max(λ, 1e-10)` at computation time |

Constructors store parameters as-is. Validation happens at the point of use, not at configuration time — this allows GD-set values to be inspected and diagnosed without silent modification.

Overlap guard:
- `upperZone + lowerZone > 0.8` → proportionally shrink both to fit within 80% (20% uniform zone guaranteed)

Division-by-zero guards:
- `zoneFraction = 0.0` → skip edge distribution entirely (no edge zone)
- `EdgeAreaFraction = 0` (CapAtThreshold) → split point = 1.0, all draws go to central zone (no `Sample()` call)
- `λ` and `α` clamped to `≥ 1e-10` inside `Sample()` at computation time — constructors store as-is
- Normalized sampling eliminates the `edgeU = 1.0` edge case — `w` is derived from a proportional split, never reaches exactly 1.0

## Design Notes

**Scope as [Flags] enum.** `EdgeDistributionScope` uses bit flags in two layers: 6 role-based flags (Heaviest/Lightest/Others × Upper/Lower, bits 0-5) + 8 form-specific flags (Young/Common/Trophy/Unique × Upper/Lower, bits 6-13) = 14 bits total. `GetEdgeFlags()` first evaluates the role-based flags, then ORs in form-specific flags for precise per-form control. Named presets were removed from the enum — they exist only as common configurations in the WebAdmin UI checkbox matrix. `ToString()` always returns individual flag names. DB stores comma-separated flag names (`"HeaviestUpper, YoungLower"`). `"All"` in DB is a safety fallback resolved to all 6 role flags in `FromSettings()`.

**Scope vs Algorithm interaction:** `EdgeStrategy = CapAtThreshold` applies hard ceiling (NOT "no effect"). `EdgeScope = EdgeDistributionScope.None` disables edge distribution entirely. Two independent switches. UI should show warning when settings conflict (e.g. "Edge distribution inactive: Scope is None").

**Naming:** `CapAtThreshold` (`u → 0`) — name reflects behavior (hard ceiling at edge zone boundary). `Unrestricted` (`u → u`) is the true pass-through (no modification).

**IEdgeDistributionStrategy interface:** Two members:
- `Sample(Random, double) → double` — inverse CDF transform. The `Random` parameter is unused by current implementations (all four are pure transforms of the `double` input). Included for extensibility.
- `EdgeAreaFraction { get; }` — integral of the edge function over [0,1]. Used by `Generate()` to compute the normalized split point. Values: CapAtThreshold=0, Unrestricted=1, PowerLaw=1/(α+1), Exponential=(1−e^(−λ))/λ. This property is what makes the piecewise inverse CDF seamless — see [edge-distribution.md](../../../server/modules/fish-generator/edge-distribution.md) §6.

## Extensibility

- New algorithms: implement `IEdgeDistributionStrategy`, add `EdgeDistribution` enum value, add GlobalVariable for parameters
- New scope combinations: add form-specific or role-based flags to `[Flags]` enum, compose via comma-separated flag names in DB. Presets are JS-only (WebAdmin UI)
- Cross-form edge distribution: future scope extension
- `FishWeightGenerator.Generate()` is the full pipeline; new steps plug in naturally

## Files Affected

### BiteSystem/ServerOnly/FishWeight/ (new — namespace `BiteSystem.ServerOnly.FishWeight`)
- `FishWeightGenerator.cs` — static class, full weight generation pipeline. Created via `svn copy` from `FishDescription.cs` to preserve blame history (Commit 1), extended with `Generate()` (Commit 2)
- `FishWeightGeneratorConfig.cs` — immutable config with `volatile static Current` (Commit 2)

### BiteSystem/ServerOnly/FishWeight/EdgeDistribution/ (new — namespace `BiteSystem.ServerOnly.FishWeight.EdgeDistribution`)
- `IEdgeDistributionStrategy.cs` — interface: `Sample(Random, double) → double`, `EdgeAreaFraction { get; }`
- `EdgeDistributionType.cs` — enum: `None, Uniform, PowerLaw, Exponential`
- `EdgeDistributionScope.cs` — `[Flags]` enum: 14 bit flags (6 role-based + 8 form-specific). Presets removed from enum, JS-only for UI

### BiteSystem/ServerOnly/FishWeight/EdgeDistribution/Strategies/ (new — namespace `...EdgeDistribution.Strategies`)
- `CapAtThreshold.cs`, `Unrestricted.cs`, `PowerLawEdge.cs`, `ExponentialEdge.cs` — four strategy implementations

### BiteSystem/Common/ObjectModel/ (modified)
- `FishDescription.cs` — remove `_formToNorm` polynomials, remove `GenerateRandomWeight()` entirely. Pure data class.

### BiteSystem/ServerOnly/ (modified)
- `PondServer.cs` — remove old static fields, replace `GenerateRandomWeight` call with `FishWeightGenerator.Generate()`

### BiteSystem/Common/ → BiteSystem/ServerOnly/ (svn move)
- `FishWeightSimulationService.cs` — move to ServerOnly, update call to `FishWeightGenerator.WeightFromNormalized()`, change namespace from `BiteSystem.Common` to `BiteSystem.ServerOnly`

### SharedLib/Config/ (modified)
- `GlobalVariablesCache.cs` — rename/add properties (long GV names: `FishWeightUpperEdgeZoneFraction`, `FishWeightLowerEdgeZoneFraction`, `FishWeightEdgeDistribution`, `FishWeightEdgeScope`, etc.), build `FishWeightGeneratorConfig` in `UpdateStaticVariables()` using `Enum.TryParse<EdgeDistribution>()` / `Enum.TryParse<EdgeDistributionScope>()`

### WebAdmin/ (modified + new)
- `Controllers/StatsController.FishWeightSimulation.cs` — update parameter names (Commit 1), then move (Commit 3)
- `Models/BiteSystem/FishWeightSimulationViewModel.cs` — remove Sigma, add Algorithm/Scope/Steepness/Rate/ZoneFractions
- New partial `SettingsController` in `Controllers/Settings/` (Commit 3)
- Move + extend simulation view to `Views/Settings/FishWeightGenerator.cshtml` (Commit 3–5)
- Update navigation: Stats.cshtml, Contents.cshtml

### SQL/Patches/ (new)
- `LBM.M.2026.03.13-017.sql` — rename threshold var to zone fraction (convert value), delete sigma var
- `LBM.M.2026.03.13-018.sql` — insert five new edge distribution variables
- Both patches use IF EXISTS / IF NOT EXISTS guards for idempotent reruns
- SQL patches must be applied BEFORE code deployment (code reads new variable names)

### Not modified
- `NormalDistribution.cs` — used by FishSelector, kept as-is
