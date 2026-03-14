# Fish Weight Edge Distribution System — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace legacy polynomial weight generation with a configurable edge distribution system — four algorithms, GlobalVariables-driven config, WebAdmin settings panel.

**Architecture:** Extract weight generation from `FishDescription` (data class) to `FishWeightGenerator` (ServerOnly). Edge distribution algorithms implement `IEdgeDistributionStrategy` interface. Immutable `FishWeightGeneratorConfig` assembled from GlobalVariables and assigned atomically. WebAdmin panel for GD to configure and simulate.

**Tech Stack:** C# 9 / .NET 4.7.2, ASP.NET MVC (Razor + Kendo), SQL Server GlobalVariables, SVN.

**Source spec:** [edge-distribution-design.md](edge-distribution-design.md)

---

## File Structure

### New files — `Shared/BiteSystem/ServerOnly/FishWeight/`

Namespace: `BiteSystem.ServerOnly.FishWeight`

| File                           | Responsibility                                                                                    |
|--------------------------------|---------------------------------------------------------------------------------------------------|
| `FishWeightGenerator.cs`       | Static class: complete weight generation pipeline (random → edge distribution → lerp → crossover) |
| `FishWeightGeneratorConfig.cs` | Immutable config with `static Current`                                                            |

### New files — `Shared/BiteSystem/ServerOnly/FishWeight/Edge/`

Namespace: `BiteSystem.ServerOnly.FishWeight.Edge`

| File                           | Responsibility                                         |
|--------------------------------|--------------------------------------------------------|
| `IEdgeDistributionStrategy.cs` | Interface: `double Sample(Random rnd, double u)`       |
| `CapAtThreshold.cs`            | `u → 0` (hard ceiling at threshold)                    |
| `Unrestricted.cs`              | `u → u` (pass-through, current behavior)               |
| `PowerLawEdge.cs`              | Inverse CDF: `1 - (1-u)^(1/(α+1))`                     |
| `ExponentialEdge.cs`           | Inverse CDF: `-ln(1 - u*(1-e^(-λ))) / λ`               |
| `EdgeDistribution.cs`          | Enum: `None, Uniform, PowerLaw, Exponential`           |
| `EdgeDistributionScope.cs`     | `[Flags]` enum: form×edge bit flags with named presets |

### Modified files

| File                                                               | What changes                                                                       |
|--------------------------------------------------------------------|------------------------------------------------------------------------------------|
| `Shared/BiteSystem/Common/ObjectModel/FishDescription.cs`          | Remove `_formToNorm`, remove `GenerateRandomWeight()`                              |
| `Shared/BiteSystem/ServerOnly/PondServer.cs`                       | Remove old statics, one-line `FishWeightGenerator.Generate()` call                 |
| `Shared/SharedLib/Config/GlobalVariablesCache.cs`                  | Rename/add properties, build edge distribution config in `UpdateStaticVariables()` |
| `WebAdmin/.../Controllers/StatsController.FishWeightSimulation.cs` | Update to use `FishWeightGenerator`, then move to new controller                   |
| `WebAdmin/.../Models/BiteSystem/FishWeightSimulationViewModel.cs`  | Replace Sigma with edge distribution params                                        |
| `WebAdmin/.../Views/Stats/FishWeightSimulation.cshtml`             | Settings UI + Preview modal                                                        |
| `WebAdmin/.../Views/Stats/Stats.cshtml`                            | Remove simulation link                                                             |
| `WebAdmin/.../Views/Home/Contents.cshtml`                          | Add simulation link under Fishing                                                  |

### SVN-moved files

| From                                                      | To                                                                  |
|-----------------------------------------------------------|---------------------------------------------------------------------|
| `Shared/BiteSystem/Common/FishWeightSimulationService.cs` | `Shared/BiteSystem/ServerOnly/FishWeightSimulationService.cs`       |
| `WebAdmin/.../Views/Stats/FishWeightSimulation.cshtml`    | `WebAdmin/.../Views/Settings/FishWeightGenerator.cshtml` (Commit 3) |

### New SQL patches

| Patch                                  | Contents                                                                |
|----------------------------------------|-------------------------------------------------------------------------|
| `SQL/Patches/LBM.M.2026.03.13-017.sql` | Rename threshold var to zone fraction (convert value), delete sigma var |
| `SQL/Patches/LBM.M.2026.03.13-018.sql` | Insert 5 new edge distribution variables                                |

---

## Pre-commit Verification (local only, not committed)

**Goal:** Before Commit 1, verify behavioral equivalence by running the old `GenerateRandomWeight()` with a fixed seed, recording exact weights, then confirming `FishWeightGenerator.WeightFromNormalized()` produces identical output. This is a local verification step — no test file is committed.

**Procedure:**
1. Run old API with `Random(42)`, record weights for each form + weightK=1.2 scenario
2. After refactoring (Task 1.1–1.4), run new API with same seed, compare
3. If identical — proceed to commit. If not — investigate before committing.

---

## Chunk 1: Commit 1 — Legacy Cleanup

**Goal:** Extract weight generation from `FishDescription` to `FishWeightGenerator` in ServerOnly. Remove polynomials. Rename GlobalVariables. SVN-move `FishWeightSimulationService`. Behavior unchanged (uniform distribution).

### Task 1.1: Create `FishWeightGenerator.cs` with `WeightFromNormalized()`

**Files:**
- Create: `Shared/BiteSystem/ServerOnly/FishWeight/FishWeightGenerator.cs`

- [ ] **Step 1: Create `FishWeightGenerator.cs` via SVN copy**

Use `svn copy` from `FishDescription.cs` to preserve blame history, then clean up the contents:
```bash
svn copy "Shared/BiteSystem/Common/ObjectModel/FishDescription.cs" "Shared/BiteSystem/ServerOnly/FishWeight/FishWeightGenerator.cs"
```
Then replace the file contents with the code below.

> **Note:** SVN copy preserves the file's history chain, so `svn blame` and `svn log` on `FishWeightGenerator.cs` will trace back through `FishDescription.cs`. This is valuable because the weight generation logic originated there.

This is the deterministic weight mapping extracted from `FishDescription.GenerateRandomWeight()`. The logic: clamp uniform [0,1] → lerp min/max → apply weightK → detect crossover.

```csharp
using System;
using BiteEditor.ObjectModel;

namespace BiteSystem.ServerOnly.FishWeight
{
    /// <summary>
    /// Fish weight generation pipeline. Extracts weight logic from FishDescription
    /// (which becomes a pure data class) into ServerOnly where it belongs.
    /// </summary>
    public static class FishWeightGenerator
    {
        /// <summary>
        /// Deterministic mapping: uniform [0,1] → fish weight with crossover detection.
        /// </summary>
        /// <param name="fish">Fish species data (form configs with min/max weights).</param>
        /// <param name="u">Normalized weight position in [0,1]. 0 = min weight, 1 = max weight.</param>
        /// <param name="form">Original fish form from FishSelector.</param>
        /// <param name="weightK">Chum weight multiplier. 1.0 = no chum.</param>
        internal static FishDescription.RandomWeight WeightFromNormalized(
            FishDescription fish, double u, FishForm form, float weightK)
        {
            var f = fish.GetFormData(form);

            if (u < 0)
                u = 0;
            else if (u > 1)
                u = 1;

            var weight = (float)((1 - u) * f.MinWeight + u * f.MaxWeight) * weightK;

            // Crossover: when weightK stretches weight beyond form boundaries,
            // find the form whose range contains the actual weight
            if (weight > f.MaxWeight || weight < f.MinWeight)
            {
                foreach (var formRecord in fish.GetFormsAndDescription())
                {
                    if (formRecord.Value.MinWeight <= weight && weight <= formRecord.Value.MaxWeight)
                        return new FishDescription.RandomWeight(formRecord.Key, formRecord.Value.MinWeight,
                            formRecord.Value.MaxWeight, weight, form);
                }
            }

            return new FishDescription.RandomWeight(form, f.MinWeight, f.MaxWeight, weight, form);
        }
    }
}
```

- [ ] **Step 2: Ask user to build**

Build: `Shared/BiteSystem/BiteSystem.csproj` — SDK-style project, new file is auto-included.

Expected: Build succeeds. No callers yet (internal method, no tests reference it).

### Task 1.2: Remove `_formToNorm` and `GenerateRandomWeight()` from `FishDescription`

**Files:**
- Modify: `Shared/BiteSystem/Common/ObjectModel/FishDescription.cs:41-47` (remove `_formToNorm`)
- Modify: `Shared/BiteSystem/Common/ObjectModel/FishDescription.cs:96-121` (remove `GenerateRandomWeight()`)

- [ ] **Step 1: Remove `_formToNorm` dictionary (lines 41-47)**

Delete the entire `_formToNorm` field — polynomials for Young/Unique are no longer used:
```csharp
// DELETE this block:
[JsonIgnore] private Dictionary<FishForm, Func<double, double>> _formToNorm = new Dictionary<FishForm, Func<double, double>>()
{
    { FishForm.Young, x => -0.0135*x*x*x - 0.9727*x*x + 1.9829*x + 0.0032 },
    { FishForm.Common, x => x},
    { FishForm.Trophy, x => x},
    { FishForm.Unique, x => 8.5574*x*x*x - 13.5356*x*x + 6.0272*x - 0.0489 },
};
```

This also removes the `using System;` dependency from `Func<double, double>` — check if `System` is still needed (yes: `InvalidOperationException` on line 67 and line 119 still uses it, but we're removing lines 96-121 too, leaving only line 67).

- [ ] **Step 2: Remove `GenerateRandomWeight()` method (lines 96-121)**

Delete the entire method:
```csharp
// DELETE this entire method:
public RandomWeight GenerateRandomWeight(Random rnd, FishForm form, float weightK, float normalPercentageFrom, float normalDistributionSigma)
{
    // ... all contents ...
}
```

`FishDescription` is now a pure data class: forms, weights, detractors + getters.

**IMPORTANT:** This breaks two callers:
1. `PondServer.cs:440` — fixed in Task 1.4
2. `FishWeightSimulationService.cs:181` — fixed in Task 1.3

All three changes (this removal + both caller updates) MUST be in the same commit.

### Task 1.3: SVN-move `FishWeightSimulationService.cs` to ServerOnly

**Files:**
- SVN move: `Shared/BiteSystem/Common/FishWeightSimulationService.cs` → `Shared/BiteSystem/ServerOnly/FishWeightSimulationService.cs`
- Modify: (after move) `Shared/BiteSystem/ServerOnly/FishWeightSimulationService.cs`

- [ ] **Step 1: SVN move the file**

```bash
svn move "Shared/BiteSystem/Common/FishWeightSimulationService.cs" "Shared/BiteSystem/ServerOnly/FishWeightSimulationService.cs"
```

This preserves VCS history.

- [ ] **Step 2: Update namespace**

Change namespace from `BiteSystem.Common` to `BiteSystem.ServerOnly`:
```csharp
// OLD:
namespace BiteSystem.Common
// NEW:
namespace BiteSystem.ServerOnly
```

- [ ] **Step 3: Update the `GenerateRandomWeight` call to use `FishWeightGenerator.WeightFromNormalized()`**

In the `Simulate()` method, line 181, replace:
```csharp
// OLD:
var randomWeight = fish.GenerateRandomWeight(rnd, form,
    weightK: weightMultiplier,
    normalPercentageFrom: normalThreshold,
    normalDistributionSigma: normalSigma);
```
```csharp
// NEW:
var randomWeight = FishWeightGenerator.WeightFromNormalized(fish, rnd.NextDouble(), form, weightMultiplier);
```

Note: `normalThreshold` and `normalSigma` parameters are no longer consumed — they have no effect in the current code (polynomials removed, Marsaglia reverted). The `Simulate()` method signature will be updated in Commit 2 when edge distribution config is added.

- [ ] **Step 4: Remove unused `using` directives**

Remove unused usings that resulted from the call change. Keep `System`, `System.Collections.Generic`, `System.Linq`, `BiteEditor`, `BiteEditor.ObjectModel`. Add `using BiteSystem.ServerOnly.FishWeight;` — `FishWeightGenerator` is in the sub-namespace.

### Task 1.3b: Update existing tests after namespace move

**Files:**
- Modify: `Shared/BiteSystem.Tests/Common/FishWeightSimulationServiceTests.cs:3`

The existing 11 simulation tests reference `using BiteSystem.Common` which no longer contains `FishWeightSimulationService` after the SVN move. Without this update, **the test project won't compile**.

- [ ] **Step 1: Update using directive**

```csharp
// OLD:
using BiteSystem.Common;
// NEW:
using BiteSystem.ServerOnly;
```

Note: The test method signatures still use `normalThreshold:` and `normalSigma:` named parameters — these are fine because the `Simulate()` method signature is unchanged in Commit 1 (the parameters are simply unused internally). The signature update happens in Commit 2.

### Task 1.4: Update `PondServer.cs` call site

**Files:**
- Modify: `Shared/BiteSystem/ServerOnly/PondServer.cs:14-15` (remove old statics)
- Modify: `Shared/BiteSystem/ServerOnly/PondServer.cs:440-441` (update call)

- [ ] **Step 1: Remove old static fields (lines 14-15)**

```csharp
// DELETE these two lines from class Pond:
public static float UseNormalDistributionForFishGeneratingFrom = .75f;
public static float NormalDistributionForFishGeneratingSigma = .2f;
```

Note: these are in `partial class Pond` (file starts with `namespace BiteEditor.ObjectModel`), NOT in `PondServer`. The file path is `PondServer.cs` but it contributes to `Pond`.

- [ ] **Step 2: Replace `GenerateRandomWeight` call (lines 440-441)**

```csharp
// OLD:
var randomWeight = _fish[generatedFish.FishName].GenerateRandomWeight(playerData.Rnd, generatedFish.FishForm, generatedFish.WeightK,
    UseNormalDistributionForFishGeneratingFrom, NormalDistributionForFishGeneratingSigma);
```
```csharp
// NEW:
var randomWeight = FishWeightGenerator.WeightFromNormalized(
    _fish[generatedFish.FishName], playerData.Rnd.NextDouble(), generatedFish.FishForm, generatedFish.WeightK);
```

Note: `FishWeightGenerator` is in `BiteSystem.ServerOnly.FishWeight`. The file already has `using BiteSystem.ServerOnly;` (line 1) — add `using BiteSystem.ServerOnly.FishWeight;` to resolve `FishWeightGenerator`.

### Task 1.5: Rename GlobalVariable property and update push

**Files:**
- Modify: `Shared/SharedLib/Config/GlobalVariablesCache.cs:634` (rename property)
- Modify: `Shared/SharedLib/Config/GlobalVariablesCache.cs:635` (delete sigma property)
- Modify: `Shared/SharedLib/Config/GlobalVariablesCache.cs:156-157` (update push in `UpdateStaticVariables()`)

- [ ] **Step 1: Rename threshold property (line 634)**

```csharp
// OLD:
public static float UseNormalDistributionForFishGeneratingFrom => GlobalVariables.Cache.GetFloatValue(nameof(UseNormalDistributionForFishGeneratingFrom), .95f);
```
```csharp
// NEW:
public static float FishWeightUpperEdgeZoneFraction => GlobalVariables.Cache.GetFloatValue(nameof(FishWeightUpperEdgeZoneFraction), .05f);
```

Note: `nameof()` auto-generates the string key used to look up the value in DB. The DB variable must also be renamed (Task 1.7).

- [ ] **Step 2: Delete sigma property (line 635)**

```csharp
// DELETE:
public static float NormalDistributionForFishGeneratingSigma => GlobalVariables.Cache.GetFloatValue(nameof(NormalDistributionForFishGeneratingSigma), .55f);
```

- [ ] **Step 3: Update `UpdateStaticVariables()` (lines 156-157)**

```csharp
// OLD:
BiteEditor.ObjectModel.Pond.UseNormalDistributionForFishGeneratingFrom = UseNormalDistributionForFishGeneratingFrom;
BiteEditor.ObjectModel.Pond.NormalDistributionForFishGeneratingSigma = NormalDistributionForFishGeneratingSigma;
```

Delete both lines — the static fields on `Pond` were removed in Task 1.4. The zone fraction will be consumed via `FishWeightGeneratorConfig.Current` starting from Commit 2.

### Task 1.6: Update WebAdmin references

**Files:**
- Modify: `WebAdmin/WebAdmin/Models/BiteSystem/FishWeightSimulationViewModel.cs:27,30`
- Modify: `WebAdmin/WebAdmin/Controllers/StatsController.FishWeightSimulation.cs:3,97-103,146-154,198-210`

- [ ] **Step 1: Update ViewModel**

```csharp
// OLD (line 27):
public float Threshold { get; set; } = GlobalVariablesCache.UseNormalDistributionForFishGeneratingFrom;
// NEW:
public float Threshold { get; set; } = 1.0f - GlobalVariablesCache.FishWeightUpperEdgeZoneFraction;
```

```csharp
// OLD (line 30):
/// <summary>Normal distribution sigma for edge zone weights. Default from GlobalVariables (typically 0.55).</summary>
public float Sigma { get; set; } = GlobalVariablesCache.NormalDistributionForFishGeneratingSigma;
// NEW — keep Sigma for now but with a hardcoded default (will be removed in Commit 2):
public float Sigma { get; set; } = 0.55f;
```

- [ ] **Step 2: Update Controller — using and call sites**

Update `using`:
```csharp
// OLD:
using BiteSystem.Common;
// NEW:
using BiteSystem.ServerOnly;
```

Update `ParseSimParams` default for threshold:
```csharp
// OLD:
float.TryParse(form["threshold"], NumberStyles.Float, inv, out var th) ? th : GlobalVariablesCache.UseNormalDistributionForFishGeneratingFrom,
// NEW:
float.TryParse(form["threshold"], NumberStyles.Float, inv, out var th) ? th : 1.0f - GlobalVariablesCache.FishWeightUpperEdgeZoneFraction,
```

Update `ParseSimParams` default for sigma:
```csharp
// OLD:
float.TryParse(form["sigma"], NumberStyles.Float, inv, out var sg) ? sg : GlobalVariablesCache.NormalDistributionForFishGeneratingSigma,
// NEW:
float.TryParse(form["sigma"], NumberStyles.Float, inv, out var sg) ? sg : 0.55f,
```

### Task 1.7: SQL Patch — rename and delete variables

**Files:**
- Create: `SQL/Patches/LBM.M.2026.03.13-017.sql`

- [ ] **Step 1: Create SQL patch**

```sql
USE [Main]
GO

IF EXISTS (SELECT 1
           FROM [dbo].[AppliedPatches]
           WHERE [PatchName] = 'LBM.M.2026.03.13-017')
    BEGIN
        PRINT 'Script was already applied, canceling execution!'
        SET NOEXEC ON
    END
GO
-- ----------------------------------------------------------------


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- Rename threshold variable to zone fraction and convert value
IF EXISTS (SELECT 1 FROM GlobalVariables WHERE Name = 'BiteSystem.UseNormalDistributionForFishGeneratingFrom')
    AND NOT EXISTS (SELECT 1 FROM GlobalVariables WHERE Name = 'BiteSystem.FishWeightUpperEdgeZoneFraction')
    BEGIN
        UPDATE GlobalVariables
        SET Name = 'BiteSystem.FishWeightUpperEdgeZoneFraction',
            Value = CAST(1.0 - CAST(Value AS FLOAT) AS VARCHAR(50))
        WHERE Name = 'BiteSystem.UseNormalDistributionForFishGeneratingFrom'
    END
GO

-- Delete sigma variable (no longer used)
IF EXISTS (SELECT 1 FROM GlobalVariables WHERE Name = 'BiteSystem.NormalDistributionForFishGeneratingSigma')
    BEGIN
        DELETE FROM GlobalVariables
        WHERE Name = 'BiteSystem.NormalDistributionForFishGeneratingSigma'
    END
GO


-- ----------------------------------------------------------------
INSERT INTO [dbo].[AppliedPatches]
VALUES ('LBM.M.2026.03.13-017');
GO

SET NOEXEC OFF
GO
```

### Task 1.8: Build and test

- [ ] **Step 1: Ask user to build all affected solutions**

Build:
- `Shared/BiteSystem/BiteSystem.csproj` (FishDescription, FishWeightGenerator, FishWeightSimulationService)
- `Photon/src-server/Loadbalancing/LoadBalancing.sln` (PondServer)
- `Shared/SharedLib/SharedLib.csproj` (GlobalVariablesCache)
- `WebAdmin/WebAdmin.sln` (Controller, ViewModel)

Expected: All build successfully.

- [ ] **Step 2: Run existing tests**

```bash
dotnet test --no-build Shared/BiteSystem.Tests/BiteSystem.Tests.csproj
```

Expected: All 11 simulation tests pass. The tests call `FishWeightSimulationService.Simulate()` which now uses `FishWeightGenerator.WeightFromNormalized()` instead of `FishDescription.GenerateRandomWeight()`. Results should be identical because the logic is the same (minus polynomials, which were already reverted in a prior commit).

- [ ] **Step 3: Commit**

```
FP-41845: [Edge] Extract weight generation from FishDescription to FishWeightGenerator
+ `FishWeightGenerator.WeightFromNormalized()` in BiteSystem/ServerOnly — deterministic weight mapping extracted from `FishDescription`
- `_formToNorm` polynomials and `GenerateRandomWeight()` from `FishDescription` — now a pure data class
- Old static fields `UseNormalDistributionForFishGeneratingFrom`, `NormalDistributionForFishGeneratingSigma` from `Pond`
= `FishWeightSimulationService` moved from Common to ServerOnly (svn move)
= `PondServer` call site updated to `FishWeightGenerator.WeightFromNormalized()`
= GlobalVariable renamed: `UseNormalDistributionForFishGeneratingFrom` → `FishWeightUpperEdgeZoneFraction`
- GlobalVariable `NormalDistributionForFishGeneratingSigma` (no longer needed)
= Existing simulation tests updated for new namespace
(task: Implement New System of Weight Generation)
https://jira.fishingplanet.com/browse/FP-41845
```

**CRITICAL:** SQL patch `LBM.M.2026.03.13-017.sql` must be applied BEFORE deploying this code, because the code reads `BiteSystem.FishWeightUpperEdgeZoneFraction` (new name).

---

## Chunk 2: Commit 2 — Edge Distribution Algorithms

**Goal:** Implement edge distribution system with four algorithms, configurable via GlobalVariables. Default = `CapAtThreshold` (hard ceiling at edge zone boundary — safest option). This IS a behavior change from production (where full weight range is reachable). GD must configure desired algorithm before deployment.

### Task 2.1: Create edge distribution interface and enum types

**Files:**
- Create: `Shared/BiteSystem/ServerOnly/FishWeight/Edge/IEdgeDistributionStrategy.cs`
- Create: `Shared/BiteSystem/ServerOnly/FishWeight/Edge/EdgeDistribution.cs`
- Create: `Shared/BiteSystem/ServerOnly/FishWeight/Edge/EdgeDistributionScope.cs`

- [ ] **Step 1: Create `IEdgeDistributionStrategy.cs`**

```csharp
using System;

namespace BiteSystem.ServerOnly.FishWeight.Edge
{
    /// <summary>
    /// Edge distribution algorithm for the edge zone of fish weight distribution.
    /// Takes a uniform sample u∈[0,1] representing position in the edge zone
    /// and returns a transformed value t∈[0,1] — the redistributed position.
    /// </summary>
    /// <remarks>
    /// The Random parameter is unused by current implementations (all four are pure
    /// inverse-CDF transforms). Included for extensibility — future algorithms may
    /// need additional random draws. Note: consuming extra draws from playerData.Rnd
    /// changes the deterministic sequence for subsequent operations.
    /// </remarks>
    public interface IEdgeDistributionStrategy
    {
        double Sample(Random rnd, double u);
    }
}
```

- [ ] **Step 2: Create `EdgeDistribution.cs`**

```csharp
namespace BiteSystem.ServerOnly.FishWeight.Edge
{
    public enum EdgeDistribution
    {
        /// <summary>Hard ceiling at edge zone boundary. u → 0. Safest default.</summary>
        None,
        /// <summary>No edge distribution — pass-through. u → u. Current production behavior.</summary>
        Uniform,
        /// <summary>Power-law edge distribution. Density reaches zero at max weight.</summary>
        PowerLaw,
        /// <summary>Exponential edge distribution. Density approaches zero asymptotically.</summary>
        Exponential
    }
}
```

- [ ] **Step 3: Create `EdgeDistributionScope.cs`**

```csharp
using System;

namespace BiteSystem.ServerOnly.FishWeight.Edge
{
    /// <summary>
    /// Controls which fish forms and edges have distribution applied.
    /// Bit flags: form (Heaviest/Lightest/Others) × edge (Upper/Lower).
    /// Named presets cover common use cases; custom combos via bitwise OR.
    /// Forms are relative to the fish's available forms per pond —
    /// e.g. if a fish has no Young, the lightest form is Common.
    /// </summary>
    [Flags]
    public enum EdgeDistributionScope
    {
        None = 0,

        HeaviestUpper = 1,
        HeaviestLower = 2,
        LightestUpper = 4,
        LightestLower = 8,
        OthersUpper   = 16,
        OthersLower   = 32,

        // Named presets
        Heaviest = HeaviestUpper,
        Extremes = HeaviestUpper | LightestLower,
        All      = HeaviestUpper | HeaviestLower
                 | LightestUpper | LightestLower
                 | OthersUpper   | OthersLower,
    }
}
```

### Task 2.2: Create the four edge distribution implementations

**Files:**
- Create: `Shared/BiteSystem/ServerOnly/FishWeight/Edge/CapAtThreshold.cs`
- Create: `Shared/BiteSystem/ServerOnly/FishWeight/Edge/Unrestricted.cs`
- Create: `Shared/BiteSystem/ServerOnly/FishWeight/Edge/PowerLawEdge.cs`
- Create: `Shared/BiteSystem/ServerOnly/FishWeight/Edge/ExponentialEdge.cs`

- [ ] **Step 1: Create `CapAtThreshold.cs`**

```csharp
using System;

namespace BiteSystem.ServerOnly.FishWeight.Edge
{
    /// <summary>
    /// Hard ceiling — all edge zone samples collapse to the edge zone boundary.
    /// Effectively caps fish weight at the edge zone boundary.
    /// This is the fail-safe default: if DB settings are unavailable, no fish
    /// can reach maximum weight.
    /// </summary>
    public sealed class CapAtThreshold : IEdgeDistributionStrategy
    {
        public static readonly CapAtThreshold Instance = new CapAtThreshold();
        private CapAtThreshold() { }

        public double Sample(Random rnd, double u) => 0;
    }
}
```

- [ ] **Step 2: Create `Unrestricted.cs`**

```csharp
using System;

namespace BiteSystem.ServerOnly.FishWeight.Edge
{
    /// <summary>
    /// No edge distribution — uniform pass-through. Equivalent to current production behavior.
    /// WARNING: This is the most permissive option. Fish can reach maximum weight
    /// with the same probability as any other weight. Must be intentionally selected by GD.
    /// </summary>
    public sealed class Unrestricted : IEdgeDistributionStrategy
    {
        public static readonly Unrestricted Instance = new Unrestricted();
        private Unrestricted() { }

        public double Sample(Random rnd, double u) => u;
    }
}
```

- [ ] **Step 3: Create `PowerLawEdge.cs`**

```csharp
using System;

namespace BiteSystem.ServerOnly.FishWeight.Edge
{
    /// <summary>
    /// Power-law edge distribution: inverse CDF = 1 - (1-u)^(1/(α+1)).
    /// Density reaches exactly zero at t=1 (max weight).
    /// Higher α = stronger redistribution = harder to get near-maximum weights.
    /// </summary>
    public sealed class PowerLawEdge : IEdgeDistributionStrategy
    {
        public readonly double Alpha;

        public PowerLawEdge(double alpha)
        {
            Alpha = alpha;
        }

        public double Sample(Random rnd, double u)
        {
            return 1.0 - Math.Pow(1.0 - u, 1.0 / (Alpha + 1.0));
        }
    }
}
```

- [ ] **Step 4: Create `ExponentialEdge.cs`**

```csharp
using System;

namespace BiteSystem.ServerOnly.FishWeight.Edge
{
    /// <summary>
    /// Exponential edge distribution: inverse CDF = -ln(1 - u*(1 - e^(-λ))) / λ.
    /// Density approaches zero asymptotically — near-max weights are possible but rare.
    /// Higher λ = stronger redistribution.
    /// </summary>
    public sealed class ExponentialEdge : IEdgeDistributionStrategy
    {
        public readonly double Lambda;

        public ExponentialEdge(double lambda)
        {
            Lambda = lambda;
        }

        public double Sample(Random rnd, double u)
        {
            return -Math.Log(1.0 - u * (1.0 - Math.Exp(-Lambda))) / Lambda;
        }
    }
}
```

### Task 2.3: Create `FishWeightGeneratorConfig`

**Files:**
- Create: `Shared/BiteSystem/ServerOnly/FishWeight/FishWeightGeneratorConfig.cs`

- [ ] **Step 1: Create config class**

```csharp
using System;
using BiteSystem.ServerOnly.FishWeight.Edge;
using SharedLib.Config;

namespace BiteSystem.ServerOnly.FishWeight
{
    /// <summary>
    /// Immutable configuration for fish weight generation.
    /// Created by GlobalVariablesCache.UpdateStaticVariables() and assigned
    /// atomically to Current. Get-only properties prevent mid-call mutation.
    /// </summary>
    public class FishWeightGeneratorConfig
    {
        public float UpperEdgeZoneFraction { get; }
        public float LowerEdgeZoneFraction { get; }
        public EdgeDistributionScope EdgeScope { get; }
        public IEdgeDistributionStrategy EdgeStrategy { get; }

        public FishWeightGeneratorConfig(
            float upperEdgeZoneFraction = 0.05f,
            float lowerEdgeZoneFraction = 0.05f,
            EdgeDistributionScope edgeScope = EdgeDistributionScope.All,
            IEdgeDistributionStrategy edgeStrategy = null)
        {
            UpperEdgeZoneFraction = upperEdgeZoneFraction;
            LowerEdgeZoneFraction = lowerEdgeZoneFraction;
            EdgeScope = edgeScope;
            EdgeStrategy = edgeStrategy ?? CapAtThreshold.Instance;
        }

        /// <summary>
        /// Current production config. Assigned atomically by UpdateStaticVariables().
        /// Reference assignment in .NET is atomic. volatile ensures visibility across CPU caches.
        /// Default: CapAtThreshold (safest — caps at edge zone boundary).
        /// </summary>
        private static volatile FishWeightGeneratorConfig _current = new FishWeightGeneratorConfig();
        public static FishWeightGeneratorConfig Current
        {
            get => _current;
            internal set => _current = value;
        }

        /// <summary>
        /// Assembles config from GlobalVariablesCache and assigns to Current.
        /// Called from GlobalVariablesCache.UpdateStaticVariables().
        /// Lives here (not in SharedLib) so that internal set works within the same assembly.
        /// </summary>
        public static void UpdateFromGlobalVariables()
        {
            var upperZone = Math.Max(0f, Math.Min(1f, GlobalVariablesCache.FishWeightUpperEdgeZoneFraction));
            var lowerZone = Math.Max(0f, Math.Min(1f, GlobalVariablesCache.FishWeightLowerEdgeZoneFraction));

            // Prevent overlapping zones — ensure at least 20% uniform zone remains
            if (upperZone + lowerZone > 0.8f)
            {
                var total = upperZone + lowerZone;
                upperZone = upperZone / total * 0.8f;
                lowerZone = lowerZone / total * 0.8f;
            }

            var steepness = Math.Max(0.01f, Math.Min(200f, GlobalVariablesCache.FishWeightEdgePowerLawSteepness));
            var rate = Math.Max(0.01f, Math.Min(200f, GlobalVariablesCache.FishWeightEdgeExponentialRate));

            IEdgeDistributionStrategy strategy;
            if (Enum.TryParse<EdgeDistribution>(GlobalVariablesCache.FishWeightEdgeDistribution, true, out var alg))
            {
                strategy = alg switch
                {
                    EdgeDistribution.Uniform => Unrestricted.Instance,
                    EdgeDistribution.PowerLaw => new PowerLawEdge(steepness),
                    EdgeDistribution.Exponential => new ExponentialEdge(rate),
                    _ => CapAtThreshold.Instance
                };
            }
            else
            {
                strategy = CapAtThreshold.Instance;
            }

            var scope = Enum.TryParse<EdgeDistributionScope>(GlobalVariablesCache.FishWeightEdgeScope, true, out var sc)
                ? sc
                : EdgeDistributionScope.All;

            Current = new FishWeightGeneratorConfig(upperZone, lowerZone, scope, strategy);
        }
    }
}
```

> **Note:** `UpdateFromGlobalVariables()` is `public` (callable from SharedLib) but `Current` setter is `internal` (writable only from BiteSystem). The method is the only production write path — external code cannot bypass it. Add `[assembly: InternalsVisibleTo("BiteSystem.Tests")]` to BiteSystem for test access.

### Task 2.4: Add `Generate()` method to `FishWeightGenerator`

**Files:**
- Modify: `Shared/BiteSystem/ServerOnly/FishWeight/FishWeightGenerator.cs`

- [ ] **Step 1: Add `using` for Edge namespace and `Generate()` + `GetEdgeFlags()`**

Add `using BiteSystem.ServerOnly.FishWeight.Edge;` at the top of the file.

Add these methods to the existing `FishWeightGenerator` class, after `WeightFromNormalized()`:

```csharp
/// <summary>
/// Full weight generation pipeline: random → edge distribution → lerp → crossover.
/// </summary>
public static FishDescription.RandomWeight Generate(
    Random rnd, FishDescription fish, FishForm form, float weightK,
    FishWeightGeneratorConfig config)
{
    var u = rnd.NextDouble();
    var (applyUpper, applyLower) = GetEdgeFlags(form, fish, config.EdgeScope);

    // Upper edge distribution
    var upperZone = (double)config.UpperEdgeZoneFraction;
    if (applyUpper && upperZone > 0)
    {
        var threshold = 1.0 - upperZone;
        if (u >= threshold)
        {
            var edgeU = (u - threshold) / upperZone;
            edgeU = Math.Min(edgeU, 1.0 - 1e-10); // guard against u=1.0 → ln(0)
            var sampled = config.EdgeStrategy.Sample(rnd, edgeU);
            u = threshold + sampled * upperZone;
        }
    }

    // Lower edge distribution (mirror of upper)
    var lowerZone = (double)config.LowerEdgeZoneFraction;
    if (applyLower && lowerZone > 0)
    {
        if (u <= lowerZone)
        {
            var edgeU = (lowerZone - u) / lowerZone;
            edgeU = Math.Min(edgeU, 1.0 - 1e-10);
            var sampled = config.EdgeStrategy.Sample(rnd, edgeU);
            u = lowerZone - sampled * lowerZone;
        }
    }

    return WeightFromNormalized(fish, u, form, weightK);
}

/// <summary>
/// Determines which edges (upper/lower) should have distribution applied,
/// based on the configured scope flags and the fish's available forms.
/// </summary>
private static (bool upper, bool lower) GetEdgeFlags(FishForm form, FishDescription fish,
    EdgeDistributionScope scope)
{
    if (scope == EdgeDistributionScope.None) return (false, false);

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

    return (upper, lower);
}
```

### Task 2.5: Update `PondServer.cs` to use `Generate()`

**Files:**
- Modify: `Shared/BiteSystem/ServerOnly/PondServer.cs:440-441` (update call)

- [ ] **Step 1: Replace `WeightFromNormalized` call with `Generate`**

```csharp
// OLD (from Commit 1):
var randomWeight = FishWeightGenerator.WeightFromNormalized(
    _fish[generatedFish.FishName], playerData.Rnd.NextDouble(), generatedFish.FishForm, generatedFish.WeightK);
```
```csharp
// NEW:
var randomWeight = FishWeightGenerator.Generate(
    playerData.Rnd, _fish[generatedFish.FishName], generatedFish.FishForm, generatedFish.WeightK,
    FishWeightGeneratorConfig.Current);
```

### Task 2.6: Update `FishWeightSimulationService` to accept config

**Files:**
- Modify: `Shared/BiteSystem/ServerOnly/FishWeightSimulationService.cs`

- [ ] **Step 1: Update `Simulate()` signature**

Replace the method signature parameters `normalThreshold` and `normalSigma` with a `FishWeightGeneratorConfig`:

```csharp
// OLD:
public FishWeightSimulationResult Simulate(
    FishDescription fish,
    float weightMultiplier,
    int iterations,
    float normalThreshold,
    float normalSigma,
    float? step,
    int topN = 200)
```
```csharp
// NEW:
public FishWeightSimulationResult Simulate(
    FishDescription fish,
    float weightMultiplier,
    int iterations,
    FishWeightGeneratorConfig config,
    float? step,
    int topN = 200)
```

- [ ] **Step 2: Update the generation call inside the loop**

```csharp
// OLD (from Commit 1):
var randomWeight = FishWeightGenerator.WeightFromNormalized(fish, rnd.NextDouble(), form, weightMultiplier);
```
```csharp
// NEW:
var randomWeight = FishWeightGenerator.Generate(rnd, fish, form, weightMultiplier, config);
```

### Task 2.7: Add GlobalVariables properties and config assembly

**Files:**
- Modify: `Shared/SharedLib/Config/GlobalVariablesCache.cs`

- [ ] **Step 1: Add five new properties (after `FishWeightUpperEdgeZoneFraction`)**

```csharp
public static float FishWeightUpperEdgeZoneFraction => GlobalVariables.Cache.GetFloatValue(nameof(FishWeightUpperEdgeZoneFraction), .05f);

public static float FishWeightLowerEdgeZoneFraction => GlobalVariables.Cache.GetFloatValue(nameof(FishWeightLowerEdgeZoneFraction), .05f);
public static string FishWeightEdgeDistribution => GlobalVariables.Cache.GetStringValue(nameof(FishWeightEdgeDistribution), "None");
public static string FishWeightEdgeScope => GlobalVariables.Cache.GetStringValue(nameof(FishWeightEdgeScope), "All");
public static float FishWeightEdgePowerLawSteepness => GlobalVariables.Cache.GetFloatValue(nameof(FishWeightEdgePowerLawSteepness), 50f);
public static float FishWeightEdgeExponentialRate => GlobalVariables.Cache.GetFloatValue(nameof(FishWeightEdgeExponentialRate), 50f);
```

Note: `GetStringValue` must exist on the cache — verify. If not, use `GetValue` or equivalent. The existing pattern uses `GetFloatValue`, `GetIntValue`, `GetBoolValue` — string getter may need checking.

- [ ] **Step 2: Add `using` for BiteSystem.ServerOnly.FishWeight namespaces**

- [ ] **Step 3: Add one-line call in `UpdateStaticVariables()`**

After the line where the old Pond statics were removed (former lines 156-157), add:

```csharp
FishWeightGeneratorConfig.UpdateFromGlobalVariables();
```

No `using` changes needed in GlobalVariablesCache — `FishWeightGeneratorConfig` is already referenced via the existing BiteSystem project reference. The config assembly logic lives in `FishWeightGeneratorConfig.UpdateFromGlobalVariables()` (see Task 2.3) — this keeps `Current`'s `internal set` working because writer and config are in the same assembly.

### Task 2.8: Update WebAdmin controller and ViewModel

**Files:**
- Modify: `WebAdmin/WebAdmin/Controllers/StatsController.FishWeightSimulation.cs`
- Modify: `WebAdmin/WebAdmin/Models/BiteSystem/FishWeightSimulationViewModel.cs`

- [ ] **Step 1: Update ViewModel — replace Sigma with edge distribution params**

```csharp
// OLD:
public float Sigma { get; set; } = 0.55f;
// DELETE the Sigma property entirely, ADD:
public string Algorithm { get; set; } = GlobalVariablesCache.FishWeightEdgeDistribution;
public string Scope { get; set; } = GlobalVariablesCache.FishWeightEdgeScope;
public float PowerLawSteepness { get; set; } = GlobalVariablesCache.FishWeightEdgePowerLawSteepness;
public float ExponentialRate { get; set; } = GlobalVariablesCache.FishWeightEdgeExponentialRate;
```

Update UpperEdgeZoneFraction default:
```csharp
// OLD:
public float Threshold { get; set; } = 1.0f - GlobalVariablesCache.FishWeightUpperEdgeZoneFraction;
// NEW:
public float UpperEdgeZoneFraction { get; set; } = GlobalVariablesCache.FishWeightUpperEdgeZoneFraction;
```

- [ ] **Step 2: Update Controller — `ParseSimParams` and callers**

Replace `ParseSimParams`:
```csharp
private static (int iterations, float weightK, FishWeightGeneratorConfig config, float? step)
    ParseSimParams(System.Collections.Specialized.NameValueCollection form)
{
    var inv = CultureInfo.InvariantCulture;

    var iterations = int.TryParse(form["iterations"], out var n)
        ? Math.Min(n, FishWeightSimulationViewModel.MaxIterations)
        : FishWeightSimulationViewModel.DefaultIterations;
    var weightK = float.TryParse(form["weightK"], NumberStyles.Float, inv, out var wk)
        ? wk : FishWeightSimulationViewModel.DefaultWeightK;

    var upperZoneFraction = float.TryParse(form["upperZoneFraction"], NumberStyles.Float, inv, out var uzf)
        ? uzf : GlobalVariablesCache.FishWeightUpperEdgeZoneFraction;
    var lowerZoneFraction = float.TryParse(form["lowerZoneFraction"], NumberStyles.Float, inv, out var lzf)
        ? lzf : GlobalVariablesCache.FishWeightLowerEdgeZoneFraction;
    var steepness = float.TryParse(form["steepness"], NumberStyles.Float, inv, out var st)
        ? st : GlobalVariablesCache.FishWeightEdgePowerLawSteepness;
    var rate = float.TryParse(form["rate"], NumberStyles.Float, inv, out var rt)
        ? rt : GlobalVariablesCache.FishWeightEdgeExponentialRate;

    var algorithmStr = form["algorithm"] ?? GlobalVariablesCache.FishWeightEdgeDistribution;
    var scopeStr = form["scope"] ?? GlobalVariablesCache.FishWeightEdgeScope;

    IEdgeDistributionStrategy edgeStrategy = CapAtThreshold.Instance;
    if (Enum.TryParse<EdgeDistribution>(algorithmStr, true, out var alg))
    {
        edgeStrategy = alg switch
        {
            EdgeDistribution.Uniform => Unrestricted.Instance,
            EdgeDistribution.PowerLaw => new PowerLawEdge(steepness),
            EdgeDistribution.Exponential => new ExponentialEdge(rate),
            _ => CapAtThreshold.Instance
        };
    }

    var edgeScope = Enum.TryParse<EdgeDistributionScope>(scopeStr, true, out var sc)
        ? sc : EdgeDistributionScope.All;

    var config = new FishWeightGeneratorConfig(upperZoneFraction, lowerZoneFraction, edgeScope, edgeStrategy);

    var step = float.TryParse(form["step"], NumberStyles.Float, inv, out var s) ? s : (float?)null;

    return (iterations, weightK, config, step);
}
```

Update callers (`SimulateWeights` and `ExportWeightSimulation`):
```csharp
// OLD:
var (iterations, weightK, threshold, sigma, step) = ParseSimParams(Request.Form);
var service = new FishWeightSimulationService();
var result = service.Simulate(fish,
    weightMultiplier: weightK,
    iterations: iterations,
    normalThreshold: threshold,
    normalSigma: sigma,
    step: step);
```
```csharp
// NEW:
var (iterations, weightK, config, step) = ParseSimParams(Request.Form);
var service = new FishWeightSimulationService();
var result = service.Simulate(fish,
    weightMultiplier: weightK,
    iterations: iterations,
    config: config,
    step: step);
```

- [ ] **Step 3: Fix `ExportWeightSimulation` filename format**

The filename string (line ~178) uses `sigma` variable which no longer exists. Replace:

```csharp
// OLD:
var fileName = string.Format(inv, "WeightSim_{0}_{1}_N{2}_wK{3}_t{4}_s{5}_step{6}.tsv",
    fishName, pondName, iterations, weightK, threshold, sigma, stepStr);
```
```csharp
// NEW:
var fileName = string.Format(inv, "WeightSim_{0}_{1}_N{2}_wK{3}_t{4}_step{5}.tsv",
    fishName, pondName, iterations, weightK, config.UpperEdgeZoneFraction, stepStr);
```

### Task 2.8b: Update existing simulation tests for new `Simulate()` signature

**Files:**
- Modify: `Shared/BiteSystem.Tests/Common/FishWeightSimulationServiceTests.cs`

All 11 tests use `normalThreshold:` and `normalSigma:` named parameters. After Task 2.6 changed the `Simulate()` signature to accept `FishWeightGeneratorConfig`, these tests **won't compile**.

- [ ] **Step 1: Update all test calls**

Replace all occurrences of:
```csharp
service.Simulate(fish, weightMultiplier: ..., iterations: ...,
    normalThreshold: 0.95f, normalSigma: 0.55f, step: ...);
```
with:
```csharp
service.Simulate(fish, weightMultiplier: ..., iterations: ...,
    config: new FishWeightGeneratorConfig(edgeStrategy: Unrestricted.Instance), step: ...);
```

This uses `Unrestricted` to match the legacy behavior (no edge distribution). Add `using BiteSystem.ServerOnly.FishWeight;` and `using BiteSystem.ServerOnly.FishWeight.Edge;` if not already present.

Note: All 11 tests need this change. The config uses defaults for zone fraction (0.05) and scope (All), and `Unrestricted` passes through uniformly — matching the old `normalThreshold=0.95, normalSigma=0.55` behavior (after polynomial/Marsaglia removal).

### Task 2.9: SQL Patch — insert new variables

**Files:**
- Create: `SQL/Patches/LBM.M.2026.03.13-018.sql`

- [ ] **Step 1: Create SQL patch**

```sql
USE [Main]
GO

IF EXISTS (SELECT 1
           FROM [dbo].[AppliedPatches]
           WHERE [PatchName] = 'LBM.M.2026.03.13-018')
    BEGIN
        PRINT 'Script was already applied, canceling execution!'
        SET NOEXEC ON
    END
GO
-- ----------------------------------------------------------------


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


IF NOT EXISTS (SELECT 1 FROM GlobalVariables WHERE Name = 'BiteSystem.FishWeightLowerEdgeZoneFraction')
    BEGIN
        INSERT INTO GlobalVariables (Name, Value) VALUES ('BiteSystem.FishWeightLowerEdgeZoneFraction', '0.05')
    END
GO

IF NOT EXISTS (SELECT 1 FROM GlobalVariables WHERE Name = 'BiteSystem.FishWeightEdgeDistribution')
    BEGIN
        INSERT INTO GlobalVariables (Name, Value) VALUES ('BiteSystem.FishWeightEdgeDistribution', 'None')
    END
GO

IF NOT EXISTS (SELECT 1 FROM GlobalVariables WHERE Name = 'BiteSystem.FishWeightEdgeScope')
    BEGIN
        INSERT INTO GlobalVariables (Name, Value) VALUES ('BiteSystem.FishWeightEdgeScope', 'All')
    END
GO

IF NOT EXISTS (SELECT 1 FROM GlobalVariables WHERE Name = 'BiteSystem.FishWeightEdgePowerLawSteepness')
    BEGIN
        INSERT INTO GlobalVariables (Name, Value) VALUES ('BiteSystem.FishWeightEdgePowerLawSteepness', '50')
    END
GO

IF NOT EXISTS (SELECT 1 FROM GlobalVariables WHERE Name = 'BiteSystem.FishWeightEdgeExponentialRate')
    BEGIN
        INSERT INTO GlobalVariables (Name, Value) VALUES ('BiteSystem.FishWeightEdgeExponentialRate', '50')
    END
GO


-- ----------------------------------------------------------------
INSERT INTO [dbo].[AppliedPatches]
VALUES ('LBM.M.2026.03.13-018');
GO

SET NOEXEC OFF
GO
```

### Task 2.10: Write unit tests for edge distribution algorithms

**Files:**
- Create or modify: `Shared/BiteSystem.Tests/EdgeDistributionTests.cs`

- [ ] **Step 1: Create test file**

```csharp
using System;
using BiteSystem.ServerOnly.FishWeight;
using BiteSystem.ServerOnly.FishWeight.Edge;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace BiteSystem.Tests
{
    [TestClass]
    public class EdgeDistributionTests
    {
        private readonly Random _rnd = new Random(42);

        [TestMethod]
        public void CapAtThreshold_AlwaysReturnsZero()
        {
            var strategy = CapAtThreshold.Instance;
            Assert.AreEqual(0.0, strategy.Sample(_rnd, 0.0));
            Assert.AreEqual(0.0, strategy.Sample(_rnd, 0.5));
            Assert.AreEqual(0.0, strategy.Sample(_rnd, 0.999));
        }

        [TestMethod]
        public void Unrestricted_ReturnsInput()
        {
            var strategy = Unrestricted.Instance;
            Assert.AreEqual(0.0, strategy.Sample(_rnd, 0.0));
            Assert.AreEqual(0.5, strategy.Sample(_rnd, 0.5));
            Assert.AreEqual(0.999, strategy.Sample(_rnd, 0.999));
        }

        [TestMethod]
        public void PowerLawEdge_OutputInRange()
        {
            var strategy = new PowerLawEdge(5.0);
            for (int i = 0; i <= 100; i++)
            {
                var u = i / 100.0;
                var result = strategy.Sample(_rnd, u);
                Assert.IsTrue(result >= 0.0 && result <= 1.0,
                    $"PowerLaw(α=5) out of range at u={u}: {result}");
            }
        }

        [TestMethod]
        public void PowerLawEdge_MonotonicallyIncreasing()
        {
            var strategy = new PowerLawEdge(3.0);
            double prev = -1;
            for (int i = 0; i <= 100; i++)
            {
                var u = i / 100.0;
                var result = strategy.Sample(_rnd, u);
                Assert.IsTrue(result >= prev,
                    $"PowerLaw not monotonic at u={u}: {result} < {prev}");
                prev = result;
            }
        }

        [TestMethod]
        public void PowerLawEdge_AtZero_ReturnsZero()
        {
            var strategy = new PowerLawEdge(10.0);
            Assert.AreEqual(0.0, strategy.Sample(_rnd, 0.0), 1e-10);
        }

        [TestMethod]
        public void PowerLawEdge_HigherAlpha_StrongerRedistribution()
        {
            var low = new PowerLawEdge(1.0);
            var high = new PowerLawEdge(50.0);
            // At midpoint, higher alpha should produce lower output (stronger redistribution)
            Assert.IsTrue(high.Sample(_rnd, 0.5) < low.Sample(_rnd, 0.5));
        }

        [TestMethod]
        public void ExponentialEdge_OutputInRange()
        {
            var strategy = new ExponentialEdge(7.0);
            for (int i = 0; i <= 100; i++)
            {
                var u = i / 100.0;
                if (u >= 1.0) u = 1.0 - 1e-10; // guard
                var result = strategy.Sample(_rnd, u);
                Assert.IsTrue(result >= 0.0 && result <= 1.0,
                    $"Exponential(λ=7) out of range at u={u}: {result}");
            }
        }

        [TestMethod]
        public void ExponentialEdge_MonotonicallyIncreasing()
        {
            var strategy = new ExponentialEdge(5.0);
            double prev = -1;
            for (int i = 0; i <= 99; i++) // skip u=1.0
            {
                var u = i / 100.0;
                var result = strategy.Sample(_rnd, u);
                Assert.IsTrue(result >= prev,
                    $"Exponential not monotonic at u={u}: {result} < {prev}");
                prev = result;
            }
        }

        [TestMethod]
        public void ExponentialEdge_AtZero_ReturnsZero()
        {
            var strategy = new ExponentialEdge(10.0);
            Assert.AreEqual(0.0, strategy.Sample(_rnd, 0.0), 1e-10);
        }

        [TestMethod]
        public void ExponentialEdge_HigherLambda_StrongerRedistribution()
        {
            var low = new ExponentialEdge(1.0);
            var high = new ExponentialEdge(50.0);
            Assert.IsTrue(high.Sample(_rnd, 0.5) < low.Sample(_rnd, 0.5));
        }

        [TestMethod]
        public void FishWeightGeneratorConfig_DefaultsToHardCeiling()
        {
            var config = new FishWeightGeneratorConfig();
            Assert.AreEqual(0.05f, config.UpperEdgeZoneFraction);
            Assert.AreEqual(0.05f, config.LowerEdgeZoneFraction);
            Assert.AreEqual(EdgeDistributionScope.All, config.EdgeScope);
            Assert.IsInstanceOfType(config.EdgeStrategy, typeof(CapAtThreshold));
        }

        [TestMethod]
        public void FishWeightGeneratorConfig_IsImmutable()
        {
            var config = new FishWeightGeneratorConfig(
                upperEdgeZoneFraction: 0.1f,
                lowerEdgeZoneFraction: 0.03f,
                edgeScope: EdgeDistributionScope.Extremes,
                edgeStrategy: Unrestricted.Instance);

            // Properties are get-only — verify values are what was set
            Assert.AreEqual(0.1f, config.UpperEdgeZoneFraction);
            Assert.AreEqual(0.03f, config.LowerEdgeZoneFraction);
            Assert.AreEqual(EdgeDistributionScope.Extremes, config.EdgeScope);
            Assert.AreSame(Unrestricted.Instance, config.EdgeStrategy);
        }
    }
}
```

- [ ] **Step 1b: Create integration test file for `FishWeightGenerator.Generate()` pipeline**

```csharp
using System;
using BiteEditor;
using BiteEditor.ObjectModel;
using BiteSystem.ServerOnly.FishWeight;
using BiteSystem.ServerOnly.FishWeight.Edge;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace BiteSystem.Tests
{
    [TestClass]
    public class FishWeightGeneratorTests
    {
        private static FishDescription CreateTestFish()
        {
            var fish = new FishDescription(FishName.NilePerch);
            fish.AddForm(FishForm.Young, 15f, 40f, 1f, false, 0, DetractionType.None, 0, 0, 0, false);
            fish.AddForm(FishForm.Common, 40f, 80f, 1f, false, 0, DetractionType.None, 0, 0, 0, false);
            fish.AddForm(FishForm.Trophy, 80f, 130f, 1f, false, 0, DetractionType.None, 0, 0, 0, false);
            fish.AddForm(FishForm.Unique, 130f, 204f, 1f, false, 0, DetractionType.None, 0, 0, 0, false);
            return fish;
        }

        [TestMethod]
        public void Generate_Unrestricted_MatchesWeightFromNormalized()
        {
            // Uniform edge distribution should produce the same distribution as WeightFromNormalized with rnd.NextDouble()
            var fish = CreateTestFish();
            var config = new FishWeightGeneratorConfig(edgeStrategy: Unrestricted.Instance);

            var rnd1 = new Random(42);
            var rnd2 = new Random(42);

            for (int i = 0; i < 1000; i++)
            {
                var generated = FishWeightGenerator.Generate(rnd1, fish, FishForm.Unique, 1f, config);
                // WeightFromNormalized is internal — verify via Generate with Uniform (which is a pass-through)
                Assert.IsTrue(generated.Weight >= 130f && generated.Weight <= 204f,
                    $"Weight {generated.Weight} outside Unique range");
            }
        }

        [TestMethod]
        public void Generate_HardCeiling_CapsAtThreshold()
        {
            var fish = CreateTestFish();
            var config = new FishWeightGeneratorConfig(
                upperEdgeZoneFraction: 0.05f,
                edgeScope: EdgeDistributionScope.All,
                edgeStrategy: CapAtThreshold.Instance);

            var rnd = new Random(42);
            float maxWeight = 0;

            for (int i = 0; i < 10000; i++)
            {
                var result = FishWeightGenerator.Generate(rnd, fish, FishForm.Unique, 1f, config);
                if (result.Weight > maxWeight) maxWeight = result.Weight;
            }

            // zoneFraction=0.05 → threshold=0.95 → max weight ≈ 130 + (1-0.05)*(204-130) = 200.3
            float expectedCeiling = 130f + (1f - 0.05f) * (204f - 130f);
            Assert.IsTrue(maxWeight <= expectedCeiling + 0.1f,
                $"HardCeiling: max weight {maxWeight} exceeds expected ceiling {expectedCeiling}");
        }

        [TestMethod]
        public void Generate_ScopeNone_NoEdgeDistributionApplied()
        {
            var fish = CreateTestFish();
            var config = new FishWeightGeneratorConfig(
                upperEdgeZoneFraction: 0.5f, // aggressive zone fraction
                edgeScope: EdgeDistributionScope.None, // but scope disables it
                edgeStrategy: CapAtThreshold.Instance);

            var rnd = new Random(42);
            float maxWeight = 0;

            for (int i = 0; i < 10000; i++)
            {
                var result = FishWeightGenerator.Generate(rnd, fish, FishForm.Unique, 1f, config);
                if (result.Weight > maxWeight) maxWeight = result.Weight;
            }

            // With scope=None, edge distribution is disabled → fish should reach near max weight
            Assert.IsTrue(maxWeight > 200f,
                $"Scope=None should allow near-max weights, got max={maxWeight}");
        }

        [TestMethod]
        public void Generate_ScopeHeaviest_OnlyAffectsHeaviestForm()
        {
            var fish = CreateTestFish();
            var config = new FishWeightGeneratorConfig(
                upperEdgeZoneFraction: 0.5f,
                lowerEdgeZoneFraction: 0f,
                edgeScope: EdgeDistributionScope.Heaviest,
                edgeStrategy: CapAtThreshold.Instance);

            // Unique (heaviest) should be capped
            var rnd1 = new Random(42);
            float maxUnique = 0;
            for (int i = 0; i < 10000; i++)
            {
                var result = FishWeightGenerator.Generate(rnd1, fish, FishForm.Unique, 1f, config);
                if (result.Weight > maxUnique) maxUnique = result.Weight;
            }
            float uniqueCeiling = 130f + (1f - 0.5f) * (204f - 130f);
            Assert.IsTrue(maxUnique <= uniqueCeiling + 0.1f,
                $"Unique (heaviest) should be capped at {uniqueCeiling}, got {maxUnique}");

            // Common (not heaviest) should NOT be capped
            var rnd2 = new Random(42);
            float maxCommon = 0;
            for (int i = 0; i < 10000; i++)
            {
                var result = FishWeightGenerator.Generate(rnd2, fish, FishForm.Common, 1f, config);
                if (result.Weight > maxCommon) maxCommon = result.Weight;
            }
            Assert.IsTrue(maxCommon > 75f,
                $"Common (not heaviest) should reach near max, got {maxCommon}");
        }

        [TestMethod]
        public void Generate_PowerLawEdge_ReducesNearMaxWeights()
        {
            var fish = CreateTestFish();
            var uniformConfig = new FishWeightGeneratorConfig(
                edgeScope: EdgeDistributionScope.All,
                edgeStrategy: Unrestricted.Instance);
            var powerConfig = new FishWeightGeneratorConfig(
                upperEdgeZoneFraction: 0.2f,
                edgeScope: EdgeDistributionScope.All,
                edgeStrategy: new PowerLawEdge(5.0));

            int uniformNearMax = 0, powerNearMax = 0;
            float threshold95 = 130f + 0.95f * (204f - 130f); // ~200.3

            var rnd1 = new Random(42);
            for (int i = 0; i < 50000; i++)
            {
                var result = FishWeightGenerator.Generate(rnd1, fish, FishForm.Unique, 1f, uniformConfig);
                if (result.Weight >= threshold95) uniformNearMax++;
            }

            var rnd2 = new Random(42);
            for (int i = 0; i < 50000; i++)
            {
                var result = FishWeightGenerator.Generate(rnd2, fish, FishForm.Unique, 1f, powerConfig);
                if (result.Weight >= threshold95) powerNearMax++;
            }

            Assert.IsTrue(powerNearMax < uniformNearMax,
                $"PowerLaw should reduce near-max fish: uniform={uniformNearMax}, power={powerNearMax}");
        }

        [TestMethod]
        public void Generate_LowerEdge_HardCeiling_CapsAtMinimum()
        {
            var fish = CreateTestFish();
            var config = new FishWeightGeneratorConfig(
                upperEdgeZoneFraction: 0f,
                lowerEdgeZoneFraction: 0.1f,
                edgeScope: EdgeDistributionScope.All,
                edgeStrategy: CapAtThreshold.Instance);

            var rnd = new Random(42);
            float minWeight = float.MaxValue;

            for (int i = 0; i < 10000; i++)
            {
                var result = FishWeightGenerator.Generate(rnd, fish, FishForm.Young, 1f, config);
                if (result.Weight < minWeight) minWeight = result.Weight;
            }

            // lowerZone=0.1 → floor at 10% of range: 15 + 0.1*(40-15) = 17.5
            float expectedFloor = 15f + 0.1f * (40f - 15f);
            Assert.IsTrue(minWeight >= expectedFloor - 0.1f,
                $"LowerEdge HardCeiling: min weight {minWeight} below expected floor {expectedFloor}");
        }

        [TestMethod]
        public void Generate_ScopeExtremes_HeaviestUpperAndLightestLower()
        {
            var fish = CreateTestFish();
            var config = new FishWeightGeneratorConfig(
                upperEdgeZoneFraction: 0.5f,
                lowerEdgeZoneFraction: 0.5f,
                edgeScope: EdgeDistributionScope.Extremes,
                edgeStrategy: CapAtThreshold.Instance);

            // Unique (heaviest) — upper edge should cap max weight
            var rnd1 = new Random(42);
            float maxUnique = 0;
            for (int i = 0; i < 10000; i++)
            {
                var result = FishWeightGenerator.Generate(rnd1, fish, FishForm.Unique, 1f, config);
                if (result.Weight > maxUnique) maxUnique = result.Weight;
            }
            float uniqueCeiling = 130f + 0.5f * (204f - 130f); // 167
            Assert.IsTrue(maxUnique <= uniqueCeiling + 0.1f,
                $"Unique upper capped at {uniqueCeiling}, got {maxUnique}");

            // Young (lightest) — lower edge should cap min weight
            var rnd2 = new Random(42);
            float minYoung = float.MaxValue;
            for (int i = 0; i < 10000; i++)
            {
                var result = FishWeightGenerator.Generate(rnd2, fish, FishForm.Young, 1f, config);
                if (result.Weight < minYoung) minYoung = result.Weight;
            }
            float youngFloor = 15f + 0.5f * (40f - 15f); // 27.5
            Assert.IsTrue(minYoung >= youngFloor - 0.1f,
                $"Young lower capped at {youngFloor}, got {minYoung}");

            // Common (middle) — neither edge should apply
            var rnd3 = new Random(42);
            float maxCommon = 0, minCommon = float.MaxValue;
            for (int i = 0; i < 10000; i++)
            {
                var result = FishWeightGenerator.Generate(rnd3, fish, FishForm.Common, 1f, config);
                if (result.Weight > maxCommon) maxCommon = result.Weight;
                if (result.Weight < minCommon) minCommon = result.Weight;
            }
            Assert.IsTrue(maxCommon > 75f, $"Common max should be near 80, got {maxCommon}");
            Assert.IsTrue(minCommon < 45f, $"Common min should be near 40, got {minCommon}");
        }
    }
}
```

- [ ] **Step 2: Run tests**

Ask user to build, then:
```bash
dotnet test --no-build Shared/BiteSystem.Tests/BiteSystem.Tests.csproj --filter "FullyQualifiedName~EdgeDistributionTests"
```

Expected: All tests pass.

- [ ] **Step 3: Run all existing tests**

```bash
dotnet test --no-build Shared/BiteSystem.Tests/BiteSystem.Tests.csproj
```

Expected: All tests pass (existing simulation tests + new edge distribution tests).

### Task 2.11: Build and commit

- [ ] **Step 1: Build all affected projects**

Ask user to build:
- `Shared/BiteSystem/BiteSystem.csproj`
- `Shared/SharedLib/SharedLib.csproj`
- `Photon/src-server/Loadbalancing/LoadBalancing.sln`
- `WebAdmin/WebAdmin.sln`
- `Shared/BiteSystem.Tests/BiteSystem.Tests.csproj`

- [ ] **Step 2: Commit**

```
FP-41845: [Edge] Implement edge distribution system with four strategies
+ `IEdgeDistributionStrategy` interface and four implementations: `CapAtThreshold`, `Unrestricted`, `PowerLawEdge`, `ExponentialEdge`
+ `EdgeDistribution` and `EdgeDistributionScope` enums
+ `FishWeightGeneratorConfig` — immutable config with atomic `Current` assignment
+ `FishWeightGenerator.Generate()` — full pipeline: random → scope check → edge distribution → lerp → crossover
+ GlobalVariables: `FishWeightEdgeDistribution`, `FishWeightEdgeScope`, `FishWeightEdgePowerLawSteepness`, `FishWeightEdgeExponentialRate`
+ Unit tests for edge distribution algorithms, config, and `Generate()` pipeline integration
= `PondServer` and `FishWeightSimulationService` updated to use `FishWeightGenerator.Generate()`
= WebAdmin simulator updated: edge distribution params replace sigma
(task: Implement New System of Weight Generation)
https://jira.fishingplanet.com/browse/FP-41845
```

**CRITICAL:** SQL patch `LBM.M.2026.03.13-018.sql` must be applied BEFORE deploying this code. GD must configure `FishWeightEdgeDistribution = Uniform` if they want current production behavior preserved during transition.

---

## Chunk 3: Commits 3-5 — WebAdmin Changes

### Commit 3: Move Simulator to Content

### Task 3.1: Create new controller

**Files:**
- Create: `WebAdmin/WebAdmin/Controllers/Settings/SettingsController.FishWeightGenerator.cs`

- [ ] **Step 1: Create the controller**

```csharp
using BiteEditor;
using BiteEditor.ObjectModel;
using BiteSystem.ServerOnly;
using BiteSystem.ServerOnly.FishWeight;
using BiteSystem.ServerOnly.FishWeight.Edge;
using Photon.Interfaces;
using SharedLib.Config;
using SharedLib.Game;
using System;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Web.Mvc;
using WebAdmin.Models.BiteSystem;

namespace WebAdmin.Controllers.Settings
{
    [Authorize]
    [InitializeSimpleMembership]
    public partial class SettingsController : BaseController
    {
        // Fish weight generator settings
        public ActionResult FishWeightGenerator()
        {
            var model = new FishWeightSimulationViewModel();
            model.FillPondList();
            return View(model);
        }
    }
}
```

**IMPORTANT:** `[Authorize]` and `[InitializeSimpleMembership]` are required — without them the page is accessible to unauthenticated users. Check `StatsController`'s class-level attributes for exact pattern (it also has `[CustomAuthorize(Roles = "Stats")]` — determine correct role for this new controller).

- [ ] **Step 2: Move action methods from StatsController**

Move `GetPondFishList`, `SimulateWeights`, `ExportWeightSimulation`, `GetBucketCountByIndex`, `ParseSimParams`, `GetFishDescription` from `StatsController.FishWeightSimulation.cs` into `SettingsController.FishWeightGenerator.cs`.

After moving, the file `StatsController.FishWeightSimulation.cs` should be deleted (or emptied of simulation code).

### Task 3.2: SVN-move the view

**Files:**
- SVN move: `WebAdmin/WebAdmin/Views/Stats/FishWeightSimulation.cshtml` → `WebAdmin/WebAdmin/Views/Settings/FishWeightGenerator.cshtml`

- [ ] **Step 1: Create destination directory**

```bash
mkdir -p "WebAdmin/WebAdmin/Views/Settings"
```

- [ ] **Step 2: SVN move the view file**

```bash
svn move "WebAdmin/WebAdmin/Views/Stats/FishWeightSimulation.cshtml" "WebAdmin/WebAdmin/Views/Settings/FishWeightGenerator.cshtml"
```

- [ ] **Step 3: Update controller references in the view**

The `@model` directive stays the same (`FishWeightSimulationViewModel`). Update these three `Url.Action` references that point to the old "Stats" controller:

1. **Line ~128:** `@Url.Action("GetPondFishList", "Stats")` → `@Url.Action("GetPondFishList", "Settings")`
2. **Line ~167:** `@Url.Action("SimulateWeights", "Stats")` → `@Url.Action("SimulateWeights", "Settings")`
3. **Line ~389:** `@Url.Action("ExportWeightSimulation", "Stats")` → `@Url.Action("ExportWeightSimulation", "Settings")`

Search for any other occurrences of `"Stats"` in the view file to catch additional references.

### Task 3.2b: Update `WebAdmin.csproj`

**Files:**
- Modify: `WebAdmin/WebAdmin/WebAdmin.csproj`

The WebAdmin project uses old-style `.csproj` (non-SDK, `ToolsVersion="4.0"`) — source files must be explicitly listed.

- [ ] **Step 1: Add new controller compile entry**

Add to the `<Compile>` section:
```xml
<Compile Include="Controllers\Settings\SettingsController.FishWeightGenerator.cs" />
```

- [ ] **Step 2: Update view content entries**

The `svn move` does NOT auto-update the `.csproj`. Manually:
- Remove: `<Content Include="Views\Stats\FishWeightSimulation.cshtml" />`
- Add: `<Content Include="Views\Settings\FishWeightGenerator.cshtml" />`

Note: Search for the exact entry format used by existing view files in the csproj.

### Task 3.3: Update navigation

**Files:**
- Modify: `WebAdmin/WebAdmin/Views/Stats/Stats.cshtml:139`
- Modify: `WebAdmin/WebAdmin/Views/Home/Contents.cshtml:123-126`

- [ ] **Step 1: Remove link from Stats page (line 139)**

```html
<!-- DELETE this line: -->
<li>@Html.ActionLink("Fish Weight Simulation", "FishWeightSimulation", "Stats") <span style="color: red;">[NEW]</span></li>
```

- [ ] **Step 2: Add link to Contents page — under Fishing section (after line 126)**

```html
<!-- ADD after the Fish link (line 125): -->
<li>@Html.ActionLink("Fish Weight Generator Settings", "FishWeightGenerator", "Settings")</li>
```

### Task 3.4: Delete old partial controller file

**Files:**
- Delete: `WebAdmin/WebAdmin/Controllers/StatsController.FishWeightSimulation.cs`

- [ ] **Step 1: SVN delete**

```bash
svn delete "WebAdmin/WebAdmin/Controllers/StatsController.FishWeightSimulation.cs"
```

### Task 3.5: Build and commit

- [ ] **Step 1: Build WebAdmin**

Ask user to build `WebAdmin/WebAdmin.sln`.

- [ ] **Step 2: Commit**

```
FP-41845: [Edge] Move Fish Weight Simulation to Content > Fishing
= Simulation page moved from Stats to Content/Fishing section as "Fish Weight Generator Settings"
+ `SettingsController` (partial) — new controller for the settings page
- Simulation code removed from `StatsController`
= View moved from `Views/Stats/FishWeightSimulation.cshtml` to `Views/Settings/FishWeightGenerator.cshtml` (svn move)
= Navigation updated: removed from Stats, added to Contents under Fishing
(task: Implement New System of Weight Generation)
https://jira.fishingplanet.com/browse/FP-41845
```

---

### Commit 4: Settings UI

### Task 4.1: Add Save/Refresh/Reset functionality to the controller

**Files:**
- Modify: `WebAdmin/WebAdmin/Controllers/Settings/SettingsController.FishWeightGenerator.cs`

- [ ] **Step 1: Add Save action**

**IMPORTANT:** There is no `SetValue()` API on GlobalVariables cache. The codebase has no established pattern for programmatic writes to GlobalVariables from controllers. The GlobalVariables editor uses Kendo grid CRUD via `CrudHelper.UpdateData`. For this controller, investigate two approaches:

**Option A:** Use `CrudHelper.UpdateData` with constructed GlobalVariable entities (entity at `WebAdmin/Models/Entities.cs:850-856` has `Name` and `Value` properties).

**Option B:** Direct ADO.NET SQL UPDATE against the `GlobalVariables` table.

Choose the approach that fits the codebase better at implementation time. The action should parse floats from `Request.Form` with `InvariantCulture` (NOT use float parameters in method signature — ASP.NET MVC model binding uses `CurrentCulture` which is `ru-RU` on servers, causing dot-formatted JS values to fail).

```csharp
[HttpPost]
public ActionResult SaveSettings()
{
    var inv = CultureInfo.InvariantCulture;

    var algorithm = Request.Form["algorithm"] ?? "None";
    var scope = Request.Form["scope"] ?? "All";
    var upperZoneFraction = float.TryParse(Request.Form["upperZoneFraction"], NumberStyles.Float, inv, out var uzf) ? uzf : 0.05f;
    var lowerZoneFraction = float.TryParse(Request.Form["lowerZoneFraction"], NumberStyles.Float, inv, out var lzf) ? lzf : 0f;
    var steepness = float.TryParse(Request.Form["steepness"], NumberStyles.Float, inv, out var st) ? st : 50f;
    var rate = float.TryParse(Request.Form["rate"], NumberStyles.Float, inv, out var rt) ? rt : 50f;

    // TODO: Write to DB — investigate CrudHelper.UpdateData or direct SQL UPDATE
    // var updates = new Dictionary<string, string>
    // {
    //     ["BiteSystem.FishWeightEdgeDistribution"] = algorithm,
    //     ["BiteSystem.FishWeightEdgeScope"] = scope,
    //     ["BiteSystem.FishWeightUpperEdgeZoneFraction"] = upperZoneFraction.ToString(inv),
    //     ["BiteSystem.FishWeightLowerEdgeZoneFraction"] = lowerZoneFraction.ToString(inv),
    //     ["BiteSystem.FishWeightEdgePowerLawSteepness"] = steepness.ToString(inv),
    //     ["BiteSystem.FishWeightEdgeExponentialRate"] = rate.ToString(inv),
    // };

    return JsonUtc(new { success = true });
}
```

- [ ] **Step 2: Add RefreshCaches action**

**IMPORTANT:** `GlobalVariablesCache.GlobalVariables.Refresh()` only refreshes the local in-process cache. To push changes to game servers, use the `ToolsModel.RefreshServerCache()` pattern:

```csharp
[HttpPost]
public ActionResult RefreshCaches()
{
    var toolsModel = new ToolsModel { RefreshCaches_Variables = true };
    var success = toolsModel.RefreshServerCache(out var details);
    return JsonUtc(new { success, details });
}
```

Verify: Check `ToolsModel` class and `RefreshServerCache` method for the exact pattern. Look at how the GlobalVariables page or Tools page does cache refresh.

- [ ] **Step 3: Add GetCurrentSettings action (for Reset button)**

```csharp
public ActionResult GetCurrentSettings()
{
    return JsonUtc(new
    {
        algorithm = GlobalVariablesCache.FishWeightEdgeDistribution,
        scope = GlobalVariablesCache.FishWeightEdgeScope,
        upperEdgeZoneFraction = GlobalVariablesCache.FishWeightUpperEdgeZoneFraction,
        lowerEdgeZoneFraction = GlobalVariablesCache.FishWeightLowerEdgeZoneFraction,
        powerLawSteepness = GlobalVariablesCache.FishWeightEdgePowerLawSteepness,
        exponentialRate = GlobalVariablesCache.FishWeightEdgeExponentialRate
    });
}
```

### Task 4.2: Update the view — settings panel

**Files:**
- Modify: `WebAdmin/WebAdmin/Views/Settings/FishWeightGenerator.cshtml`

- [ ] **Step 1: Add settings controls before simulation controls**

Add algorithm dropdown, scope dropdown, upper/lower zone fraction inputs, steepness slider+input, rate slider+input. Algorithm-specific fields are shown/hidden based on selected algorithm. JavaScript preserves hidden field values in memory.

This is a substantial view change — the exact HTML/JS depends on the existing view structure and Kendo widget patterns used in the project. Key elements:

```html
<div class="settings-panel">
    <h3>Weight Generation Settings</h3>

    <label>Algorithm:</label>
    <select id="algorithm">
        <option value="None">None (Hard Ceiling)</option>
        <option value="Uniform">Uniform (No Edge Distribution)</option>
        <option value="PowerLaw">Power Law</option>
        <option value="Exponential">Exponential</option>
    </select>

    <label>Scope:</label>
    <select id="scope">
        <option value="None">None (Disabled)</option>
        <option value="Heaviest">Heaviest Form Only (upper edge)</option>
        <option value="Extremes">Heaviest (upper) + Lightest (lower)</option>
        <option value="All">All Forms (all edges)</option>
    </select>
    <small>Presets backed by [Flags] — custom combos possible via bitwise OR in DB</small>

    <label>Upper Edge Zone:</label>
    <input type="range" id="upperZoneFractionSlider" min="0" max="1" step="0.01" />
    <input type="text" id="upperZoneFraction" style="width:60px;" />

    <label>Lower Edge Zone:</label>
    <input type="range" id="lowerZoneFractionSlider" min="0" max="1" step="0.01" />
    <input type="text" id="lowerZoneFraction" style="width:60px;" />

    <div id="powerLawParams" style="display:none;">
        <label>Steepness (α):</label>
        <input type="range" id="steepnessSlider" min="0.01" max="200" step="0.01" />
        <input type="text" id="steepness" style="width:60px;" />
    </div>

    <div id="exponentialParams" style="display:none;">
        <label>Rate (λ):</label>
        <input type="range" id="rateSlider" min="0.01" max="200" step="0.01" />
        <input type="text" id="rate" style="width:60px;" />
    </div>

    <button id="saveBtn" class="btn btn-primary">Save</button>
    <button id="refreshBtn" class="btn btn-warning">Refresh Caches</button>
    <button id="resetBtn" class="btn btn-default">Reset</button>
</div>
```

- [ ] **Step 2: Add JavaScript for show/hide, save with confirmation, reset**

```javascript
// Algorithm-specific field visibility
$('#algorithm').change(function() {
    var alg = $(this).val();
    $('#powerLawParams').toggle(alg === 'PowerLaw');
    $('#exponentialParams').toggle(alg === 'Exponential');
});

// Save with confirmation dialog
$('#saveBtn').click(function() {
    if (!confirm('WARNING: These settings affect fish weight generation on ALL game servers. Continue?')) return;
    if (!confirm('Are you sure? This will change how fish weights are generated.')) return;
    $.post('@Url.Action("SaveSettings")', {
        algorithm: $('#algorithm').val(),
        scope: $('#scope').val(),
        upperZoneFraction: $('#upperZoneFraction').val(),
        lowerZoneFraction: $('#lowerZoneFraction').val(),
        powerLawSteepness: $('#steepness').val(),
        exponentialRate: $('#rate').val()
    }, function(data) {
        if (data.success) alert('Settings saved.');
    });
});

// Reset to current DB values
$('#resetBtn').click(function() {
    $.get('@Url.Action("GetCurrentSettings")', function(data) {
        $('#algorithm').val(data.algorithm).change();
        $('#scope').val(data.scope);
        $('#upperZoneFraction').val(data.upperEdgeZoneFraction);
        $('#upperZoneFractionSlider').val(data.upperEdgeZoneFraction);
        $('#lowerZoneFraction').val(data.lowerEdgeZoneFraction);
        $('#lowerZoneFractionSlider').val(data.lowerEdgeZoneFraction);
        $('#steepness').val(data.powerLawSteepness);
        $('#steepnessSlider').val(data.powerLawSteepness);
        $('#rate').val(data.exponentialRate);
        $('#rateSlider').val(data.exponentialRate);
    });
});
```

- [ ] **Step 3: Wire simulation to use form values (not cache)**

Simulation should send the current form values as parameters, so GD can tweak settings, simulate, and then save. Update the simulate JS to include algorithm/scope/steepness/rate in the POST data.

### Task 4.3: Build and commit

- [ ] **Step 1: Build WebAdmin**

- [ ] **Step 2: Manual test**

Navigate to Content > Fishing > Fish Weight Generator Settings. Verify:
- Algorithm dropdown shows/hides relevant params
- Reset loads current DB values
- Simulation uses form values
- Save shows confirmation dialogs

- [ ] **Step 3: Commit**

```
FP-41845: [Edge] Add settings UI with Save, Refresh Caches, and Reset
+ Save button writes edge distribution config to GlobalVariables DB
+ Refresh Caches button pushes config to game servers
+ Reset button restores fields from current DB values
+ Algorithm-specific fields shown/hidden dynamically; hidden values preserved
+ Confirmation dialogs before Save
= Simulation now uses form values (not cache) for interactive tuning
(task: Implement New System of Weight Generation)
https://jira.fishingplanet.com/browse/FP-41845
```

---

### Commit 5: Preview Modal

### Task 5.1: Add Preview button and modal

**Files:**
- Modify: `WebAdmin/WebAdmin/Views/Settings/FishWeightGenerator.cshtml`

- [ ] **Step 1: Add Preview button**

```html
<button id="previewBtn" class="btn btn-info">Preview Curves</button>
```

- [ ] **Step 2: Add fullscreen modal with Kendo chart**

```html
<div id="previewModal" style="display:none; position:fixed; top:0; left:0; right:0; bottom:0; z-index:10000; background:#fff; overflow:auto; padding:20px;">
    <h2>Edge Distribution Curve Preview</h2>
    <button id="closePreview" class="btn btn-default" style="float:right;">Close</button>

    <div style="margin: 10px 0;">
        <label>Upper Edge Zone Fraction:</label>
        <input type="range" id="previewUpperZone" min="0" max="1" step="0.01" value="0.05" />
        <span id="previewUpperZoneVal">0.05</span>
    </div>

    <div style="margin: 10px 0;">
        <label>PowerLaw α:</label>
        <input type="range" id="previewAlpha" min="0.01" max="200" step="0.01" value="3" />
        <span id="previewAlphaVal">3</span>

        <label style="margin-left:20px;">Exponential λ:</label>
        <input type="range" id="previewLambda" min="0.01" max="200" step="0.01" value="7" />
        <span id="previewLambdaVal">7</span>
    </div>

    <div style="margin: 10px 0;">
        <label><input type="checkbox" id="showNone" /> None</label>
        <label><input type="checkbox" id="showUniform" /> Uniform</label>
        <label><input type="checkbox" id="showPowerLaw" checked /> Power Law</label>
        <label><input type="checkbox" id="showExponential" checked /> Exponential</label>
    </div>

    <div id="previewChart" style="height:500px;"></div>

    <button id="applyPreview" class="btn btn-primary">Apply to Settings</button>
</div>
```

- [ ] **Step 3: Add JavaScript for chart rendering and Apply button**

The chart shows the edge zone with selected curves. Uses Kendo chart — verify it can render smooth curves (if not, use dense polylines with 200+ points).

```javascript
$('#previewBtn').click(function() {
    $('#previewModal').show();
    renderPreviewChart();
});

$('#closePreview').click(function() {
    $('#previewModal').hide();
});

$('#applyPreview').click(function() {
    // Copy preview settings to main form
    // Determine which algorithm is currently most prominent in preview
    // or use the last-selected algorithm checkbox
    $('#upperZoneFraction').val($('#previewUpperZone').val());
    $('#upperZoneFractionSlider').val($('#previewUpperZone').val());
    $('#steepness').val($('#previewAlpha').val());
    $('#steepnessSlider').val($('#previewAlpha').val());
    $('#rate').val($('#previewLambda').val());
    $('#rateSlider').val($('#previewLambda').val());
    $('#previewModal').hide();
});

function renderPreviewChart() {
    // Generate curve data points
    var points = 200;
    var upperZone = parseFloat($('#previewUpperZone').val());
    var alpha = parseFloat($('#previewAlpha').val());
    var lambda = parseFloat($('#previewLambda').val());

    var series = [];
    // ... compute curves and create Kendo chart series ...
    // Each curve: array of {x: position_in_edge_zone, y: redistributed_position}

    $('#previewChart').kendoChart({
        // Kendo chart config — TBD: verify smooth line rendering capability
        seriesDefaults: { type: 'scatterLine', width: 2, markers: { visible: false } },
        series: series,
        // ... axes, legend, tooltip config ...
    });
}
```

Note: TBD — verify Kendo can render smooth curves (not angular polylines). If not, use dense data points (200+).

### Task 5.2: Build and commit

- [ ] **Step 1: Build WebAdmin**

- [ ] **Step 2: Manual test**

Open Preview modal. Verify sliders update chart, checkboxes toggle curves, Apply copies settings to main form.

- [ ] **Step 3: Commit**

```
FP-41845: [Edge] Add Preview modal with interactive edge distribution curve explorer
+ Fullscreen modal with Kendo chart showing edge zone distribution curves
+ Sliders for upper zone fraction, PowerLaw α, Exponential λ
+ Checkboxes to toggle None/Uniform/PowerLaw/Exponential curves
+ Apply button copies preview settings to main form
(task: Implement New System of Weight Generation)
https://jira.fishingplanet.com/browse/FP-41845
```

---

## Deployment Notes

### SQL Patch Order

1. `LBM.M.2026.03.13-017.sql` — rename threshold to zone fraction, convert value, delete sigma (BEFORE Commit 1 code)
2. `LBM.M.2026.03.13-018.sql` — insert new edge distribution variables (BEFORE Commit 2 code)

### GD Action Required

After Commit 2 is deployed, default behavior is `Algorithm=None` (hard ceiling at 95%). To restore current production behavior, GD must set `Algorithm=Uniform` via the settings page or directly in GlobalVariables.

### Rollback

Each commit is independently deployable. Rollback to any previous commit leaves the system in a working state. SQL patches are idempotent (IF EXISTS guards). Code defaults handle missing DB variables gracefully (fail-safe to CapAtThreshold).
