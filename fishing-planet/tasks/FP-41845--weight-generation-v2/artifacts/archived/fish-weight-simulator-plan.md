# Fish Weight Simulator — Implementation Plan

> **Status: COMPLETE** (2026-03-11). All 8 tasks implemented, code reviewed, 11 tests green. Post-plan additions: actual-form bucketing, top-200 leaderboard preview, ELI5 tooltips for game designers, InvariantCulture fixes, iterations cap (20M).

**Goal:** Build a WebAdmin page that simulates N weight generations per form using real BiteSystem code and renders interactive Kendo area charts.

**Architecture:** Service layer (`FishWeightSimulationService`) in `Shared/BiteSystem/Common/` calls `FishDescription.GenerateRandomWeight()` directly. Controller (partial `StatsController`) loads `FishDescription` from `BiteSystemCache` and delegates to the service. Razor view uses Kendo DataViz Area Chart with AJAX POST.

**Tech Stack:** C# 9 / .NET Framework 4.7.2, ASP.NET MVC 5, Kendo UI 2013.2.918 (DataViz), MSTest, BiteSystem assembly.

**Spec:** [fish-weight-simulator-design.md](fish-weight-simulator-design.md)

---

## File Structure

| Action | Path                                                                    | Responsibility                                                                                 |
|--------|-------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| Create | `Shared/BiteSystem/Common/FishWeightSimulationService.cs`               | Service + result models (`FishWeightSimulationResult`, `FormSimulationResult`, `BucketResult`) |
| Create | `Shared/BiteSystem.Tests/Common/FishWeightSimulationServiceTests.cs`    | Unit tests for simulation service                                                              |
| Modify | `Shared/BiteSystem/Common/ObjectModel/Pond.cs`                          | Add `GetFishDescription()` public accessor                                                     |
| Create | `WebAdmin/WebAdmin/Controllers/StatsController.FishWeightSimulation.cs` | Controller partial class: GET page, GET fish list, POST simulate, POST export                  |
| Create | `WebAdmin/WebAdmin/Models/BiteSystem/FishWeightSimulationViewModel.cs`  | ViewModel for the page (pond list, defaults)                                                   |
| Create | `WebAdmin/WebAdmin/Views/Stats/FishWeightSimulation.cshtml`             | Razor view with filter form + Kendo Area Chart + JS logic                                      |

---

## Chunk 1: Service Layer (BiteSystem)

### Task 1: Add `GetFishDescription()` accessor to Pond

**Files:**
- Modify: `Shared/BiteSystem/Common/ObjectModel/Pond.cs:191` (before closing `}`)

- [ ] **Step 1: Add public method**

Add after `GetFishWeight()` method (line 190), before the closing brace:

```csharp
public FishDescription GetFishDescription(FishName name)
{
    return _fish.TryGetValue(name, out var desc) ? desc : null;
}
```

- [ ] **Step 2: Verify build**

Ask user to build `Shared/BiteSystem/BiteSystem.csproj`.

- [ ] **Step 3: Commit**

```
[FishWeightSim] Add public FishDescription accessor to Pond
+ `GetFishDescription(FishName)` on `Pond` — exposes `_fish` dictionary for simulation service
(Task: FP-41845 — Weight Generation v2)
```

---

### Task 2: Create service result models

**Files:**
- Create: `Shared/BiteSystem/Common/FishWeightSimulationService.cs`

- [ ] **Step 1: Write the result model classes**

```csharp
using System.Collections.Generic;

namespace BiteEditor.ObjectModel
{
    public class FishWeightSimulationResult
    {
        public float Step { get; set; }
        public Dictionary<FishForm, FormSimulationResult> Forms { get; set; }
    }

    public class FormSimulationResult
    {
        public float MinWeight { get; set; }
        public float MaxWeight { get; set; }
        public int TotalGenerated { get; set; }
        public List<BucketResult> Buckets { get; set; }
        public Dictionary<FishForm, int> CrossoversTo { get; set; }
    }

    public class BucketResult
    {
        public float Weight { get; set; }
        public int Count { get; set; }
        public float Percentage { get; set; }
    }
}
```

- [ ] **Step 2: Verify build**

Ask user to build `Shared/BiteSystem/BiteSystem.csproj`.

---

### Task 3: Implement `FishWeightSimulationService.Simulate()`

**Files:**
- Modify: `Shared/BiteSystem/Common/FishWeightSimulationService.cs` (add service class)

- [ ] **Step 1: Write failing test — Common form, weightK=1, flat distribution**

Create `Shared/BiteSystem.Tests/Common/FishWeightSimulationServiceTests.cs`:

```csharp
using BiteEditor.ObjectModel;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Linq;

namespace BiteEditor.Tests
{
    [TestClass]
    public class FishWeightSimulationServiceTests
    {
        /// <summary>
        /// Build a minimal FishDescription with all 4 forms for testing.
        /// Nile Perch weight ranges: Y=[15,40], C=[40,80], T=[80,130], U=[130,204]
        /// </summary>
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
        public void Simulate_CommonForm_WeightK1_ProducesNonEmptyBuckets()
        {
            var service = new FishWeightSimulationService();
            var fish = CreateTestFish();

            var result = service.Simulate(fish, weightMultiplier: 1f, iterations: 10000,
                normalThreshold: 0.95f, normalSigma: 0.55f, step: 1f);

            Assert.IsNotNull(result);
            Assert.IsTrue(result.Forms.ContainsKey(FishForm.Common));
            var common = result.Forms[FishForm.Common];
            Assert.AreEqual(10000, common.TotalGenerated);
            Assert.IsTrue(common.Buckets.Count > 0);
            Assert.AreEqual(10000, common.Buckets.Sum(b => b.Count),
                "All generated weights must land in buckets");
        }

        [TestMethod]
        public void Simulate_WeightK1_ZeroCrossovers()
        {
            var service = new FishWeightSimulationService();
            var fish = CreateTestFish();

            var result = service.Simulate(fish, weightMultiplier: 1f, iterations: 10000,
                normalThreshold: 0.95f, normalSigma: 0.55f, step: 1f);

            foreach (var form in result.Forms.Values)
            {
                Assert.AreEqual(0, form.CrossoversTo.Values.Sum(),
                    "weightK=1 must produce zero crossovers");
            }
        }
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `dotnet test --no-build --filter "FullyQualifiedName~FishWeightSimulationServiceTests" Shared/BiteSystem.Tests/BiteSystem.Tests.csproj`
Expected: FAIL — `FishWeightSimulationService` class not found.

- [ ] **Step 3: Write the service implementation**

Add to `Shared/BiteSystem/Common/FishWeightSimulationService.cs` (same file as models):

```csharp
using System;
using System.Collections.Generic;
using System.Linq;

namespace BiteEditor.ObjectModel
{
    // ... (result models from Task 2 stay here) ...

    public class FishWeightSimulationService
    {
        private static readonly float[] NiceSteps =
            { 0.01f, 0.02f, 0.05f, 0.1f, 0.2f, 0.25f, 0.5f, 1f, 2f, 5f, 10f, 25f, 50f };

        public FishWeightSimulationResult Simulate(
            FishDescription fish,
            float weightMultiplier,
            int iterations,
            float normalThreshold,
            float normalSigma,
            float? step)
        {
            var forms = new[] { FishForm.Young, FishForm.Common, FishForm.Trophy, FishForm.Unique }
                .Where(f => fish.TestForm(f))
                .ToList();

            // Compute global weight range
            float globalMin = float.MaxValue, globalMax = float.MinValue;
            foreach (var form in forms)
            {
                var data = fish.GetFormData(form);
                if (data.MinWeight < globalMin) globalMin = data.MinWeight;
                if (data.MaxWeight > globalMax) globalMax = data.MaxWeight;
            }

            // Auto-calculate step
            float actualStep;
            if (step.HasValue && step.Value > 0)
            {
                actualStep = step.Value;
            }
            else
            {
                var rawStep = (globalMax - globalMin) / 200f;
                if (rawStep < 0.01f)
                    actualStep = 0.01f;
                else if (rawStep > 50f)
                    actualStep = 50f;
                else
                    actualStep = NiceSteps.First(s => s >= rawStep);
            }

            // Build bucket grid
            var bucketCount = (int)Math.Ceiling((globalMax - globalMin) / actualStep) + 1;

            // Simulate per form
            var formResults = new Dictionary<FishForm, FormSimulationResult>();
            var rnd = new Random(42); // deterministic seed for reproducibility

            foreach (var form in forms)
            {
                var formData = fish.GetFormData(form);
                var counts = new int[bucketCount];
                var crossovers = new Dictionary<FishForm, int>();

                for (int i = 0; i < iterations; i++)
                {
                    var rw = fish.GenerateRandomWeight(rnd, form,
                        weightK: weightMultiplier,
                        normalPercentageFrom: normalThreshold,
                        normalDistributionSigma: normalSigma);

                    // Place into bucket based on weight
                    int bucketIndex = (int)((rw.Weight - globalMin) / actualStep);
                    if (bucketIndex < 0) bucketIndex = 0;
                    if (bucketIndex >= bucketCount) bucketIndex = bucketCount - 1;
                    counts[bucketIndex]++;

                    // Track crossovers
                    if (rw.Form != rw.OriginalForm)
                    {
                        if (!crossovers.ContainsKey(rw.Form))
                            crossovers[rw.Form] = 0;
                        crossovers[rw.Form]++;
                    }
                }

                // Build bucket results (emit ALL buckets including zeros for chart alignment)
                var buckets = new List<BucketResult>();
                for (int b = 0; b < bucketCount; b++)
                {
                    buckets.Add(new BucketResult
                    {
                        Weight = globalMin + b * actualStep,
                        Count = counts[b],
                        Percentage = iterations > 0
                            ? (float)Math.Round(100.0 * counts[b] / iterations, 2)
                            : 0f
                    });
                }

                formResults[form] = new FormSimulationResult
                {
                    MinWeight = formData.MinWeight,
                    MaxWeight = formData.MaxWeight,
                    TotalGenerated = iterations,
                    Buckets = buckets,
                    CrossoversTo = crossovers
                };
            }

            return new FishWeightSimulationResult
            {
                Step = actualStep,
                Forms = formResults
            };
        }
    }
}
```

- [ ] **Step 4: Build and run tests**

Ask user to build. Then run:
`dotnet test --no-build --filter "FullyQualifiedName~FishWeightSimulationServiceTests" Shared/BiteSystem.Tests/BiteSystem.Tests.csproj`
Expected: 2 PASS.

- [ ] **Step 5: Commit**

```
[FishWeightSim] Add FishWeightSimulationService with result models
+ `FishWeightSimulationService.Simulate()` — runs N iterations of `GenerateRandomWeight()` per form, buckets results into histogram
+ Result models: `FishWeightSimulationResult`, `FormSimulationResult`, `BucketResult`
+ Auto-step calculation from "nice" set {0.01..50}; crossover tracking
(Task: FP-41845 — Weight Generation v2)
```

---

### Task 4: Additional service tests

**Files:**
- Modify: `Shared/BiteSystem.Tests/Common/FishWeightSimulationServiceTests.cs`

- [ ] **Step 1: Write additional tests**

Add these test methods to the existing test class:

```csharp
[TestMethod]
public void Simulate_YoungForm_WeightK1_AllWeightsInGlobalRange()
{
    var service = new FishWeightSimulationService();
    var fish = CreateTestFish();

    var result = service.Simulate(fish, weightMultiplier: 1f, iterations: 10000,
        normalThreshold: 0.95f, normalSigma: 0.55f, step: 1f);

    var young = result.Forms[FishForm.Young];
    Assert.IsTrue(young.Buckets.All(b => b.Weight >= 15f - 1f && b.Weight <= 204f),
        "All Young buckets must be within global weight range");
}

[TestMethod]
public void Simulate_WeightKGreaterThan1_CrossoversAppear()
{
    var service = new FishWeightSimulationService();
    var fish = CreateTestFish();

    var result = service.Simulate(fish, weightMultiplier: 1.5f, iterations: 50000,
        normalThreshold: 0.95f, normalSigma: 0.55f, step: 1f);

    var totalCrossovers = result.Forms.Values.Sum(f => f.CrossoversTo.Values.Sum());
    Assert.IsTrue(totalCrossovers > 0,
        "weightK > 1 should produce crossovers");
}

[TestMethod]
public void Simulate_AutoStep_ProducesNiceStepValue()
{
    var service = new FishWeightSimulationService();
    var fish = CreateTestFish();

    // Range 15..204 = 189. 189/200 = 0.945 → first nice step >= 0.945 is 1.0
    var result = service.Simulate(fish, weightMultiplier: 1f, iterations: 100,
        normalThreshold: 0.95f, normalSigma: 0.55f, step: null);

    Assert.AreEqual(1f, result.Step, "Auto step for 15..204 range should be 1.0");
}

[TestMethod]
public void Simulate_ManualStep_UsesExactValue()
{
    var service = new FishWeightSimulationService();
    var fish = CreateTestFish();

    var result = service.Simulate(fish, weightMultiplier: 1f, iterations: 100,
        normalThreshold: 0.95f, normalSigma: 0.55f, step: 0.5f);

    Assert.AreEqual(0.5f, result.Step);
}

[TestMethod]
public void Simulate_AllFormsPresent_EvenWithFewerThan4()
{
    // Fish with only Common and Trophy
    var fish = new FishDescription(FishName.NorthernPike);
    fish.AddForm(FishForm.Common, 1f, 5f, 1f, false, 0, DetractionType.None, 0, 0, 0, false);
    fish.AddForm(FishForm.Trophy, 5f, 10f, 1f, false, 0, DetractionType.None, 0, 0, 0, false);

    var service = new FishWeightSimulationService();
    var result = service.Simulate(fish, weightMultiplier: 1f, iterations: 1000,
        normalThreshold: 0.95f, normalSigma: 0.55f, step: 0.1f);

    Assert.AreEqual(2, result.Forms.Count, "Only existing forms should be in result");
    Assert.IsTrue(result.Forms.ContainsKey(FishForm.Common));
    Assert.IsTrue(result.Forms.ContainsKey(FishForm.Trophy));
    Assert.IsFalse(result.Forms.ContainsKey(FishForm.Young));
}

[TestMethod]
public void Simulate_BucketPercentages_SumTo100()
{
    var service = new FishWeightSimulationService();
    var fish = CreateTestFish();

    var result = service.Simulate(fish, weightMultiplier: 1f, iterations: 10000,
        normalThreshold: 0.95f, normalSigma: 0.55f, step: 1f);

    foreach (var kvp in result.Forms)
    {
        var sum = kvp.Value.Buckets.Sum(b => b.Percentage);
        Assert.IsTrue(sum > 99.5f && sum < 100.5f,
            $"Form {kvp.Key}: bucket percentages should sum to ~100%, got {sum}%");
    }
}
```

- [ ] **Step 2: Run all tests**

Ask user to build. Then:
`dotnet test --no-build --filter "FullyQualifiedName~FishWeightSimulationServiceTests" Shared/BiteSystem.Tests/BiteSystem.Tests.csproj`
Expected: 8 PASS.

- [ ] **Step 3: Commit**

```
[FishWeightSim] Add comprehensive tests for simulation service
+ Tests: auto-step calculation, manual step, crossovers with weightK>1, bucket percentage totals, fewer-than-4-forms, weight range validation
(Task: FP-41845 — Weight Generation v2)
```

---

## Chunk 2: WebAdmin Controller & ViewModel

### Task 5: Create ViewModel

**Files:**
- Create: `WebAdmin/WebAdmin/Models/BiteSystem/FishWeightSimulationViewModel.cs`

- [ ] **Step 1: Write the ViewModel**

```csharp
using System.Collections.Generic;
using System.Linq;
using System.Web.Mvc;
using Photon.Interfaces;
using SharedLib.Config;

namespace WebAdmin.Models.BiteSystem
{
    public class FishWeightSimulationViewModel
    {
        public int? PondId { get; set; }
        public int? FishCategoryId { get; set; }
        public int Iterations { get; set; } = 100000;
        public float WeightK { get; set; } = 1.0f;
        public float Threshold { get; set; } = 0.95f;
        public float Sigma { get; set; } = 0.55f;
        public float? Step { get; set; }

        public IEnumerable<SelectListItem> PondList { get; set; }

        public void FillPondList()
        {
            PondList = GameServerCache.GetAllPondsAssetMapping()
                .Select(p => new SelectListItem
                {
                    Value = p.PondId.ToString(),
                    Text = $"{GameServerCache.GetPondDirect(p.PondId, SharedConsts.DefaultLanguageId)?.Name ?? "Unknown"} ({p.PondId})"
                })
                .OrderBy(p => p.Text);
        }
    }
}
```

- [ ] **Step 2: Verify build**

Ask user to build `WebAdmin/WebAdmin.sln`.

---

### Task 6: Create Controller partial class

**Files:**
- Create: `WebAdmin/WebAdmin/Controllers/StatsController.FishWeightSimulation.cs`

- [ ] **Step 1: Write the controller**

```csharp
using BiteEditor;
using BiteEditor.ObjectModel;
using Photon.Interfaces;
using SharedLib.Config;
using SharedLib.Game;
using System.Linq;
using System.Text;
using System.Web.Mvc;
using WebAdmin.Models.BiteSystem;

namespace WebAdmin.Controllers
{
    public partial class StatsController
    {
        // GET: /Stats/FishWeightSimulation
        public ActionResult FishWeightSimulation()
        {
            var model = new FishWeightSimulationViewModel();
            model.FillPondList();
            return View(model);
        }

        // AJAX GET: /Stats/GetPondFishList?pondId=250
        public ActionResult GetPondFishList(int pondId)
        {
            var pondInfo = GameServerCache.GetPondDirect(pondId, SharedConsts.DefaultLanguageId);
            var pond = BiteSystemCache.BiteMaps.Cache.FindPond(pondInfo.Asset);
            if (pond == null)
                return JsonUtc(new object[0]);

            var allFish = pond.GetAllFish(); // Dictionary<int fishId, FormRecord>
            var grouped = allFish
                .Select(kvp =>
                {
                    var (fishName, fishForm) = Settings.GetFishNameAndForm(kvp.Key);
                    return new { FishName = fishName, FishForm = fishForm, Record = kvp.Value, FishId = kvp.Key };
                })
                .Where(x => x.FishName != FishName.None)
                .GroupBy(x => (int)x.FishName)
                .Select(g =>
                {
                    var first = g.First();
                    var displayName = FishCache.GetFishCategoryName((int)first.FishName, SharedConsts.DefaultLanguageId)
                                     ?? first.FishName.ToString();
                    return new
                    {
                        fishCategoryId = (int)first.FishName,
                        name = displayName,
                        forms = g.OrderBy(f => f.FishForm).Select(f => new
                        {
                            form = f.FishForm.ToString(),
                            minWeight = f.Record.MinWeight,
                            maxWeight = f.Record.MaxWeight
                        })
                    };
                })
                .OrderBy(x => x.name);

            return JsonUtc(grouped);
        }

        // AJAX POST: /Stats/SimulateWeights
        [HttpPost]
        public ActionResult SimulateWeights(int pondId, int fishCategoryId,
            int iterations = 100000, float weightK = 1.0f,
            float threshold = 0.95f, float sigma = 0.55f, float? step = null)
        {
            var fish = GetFishDescription(pondId, fishCategoryId);
            if (fish == null)
                return JsonUtc(new { error = "Fish not found on this pond" });

            var service = new FishWeightSimulationService();
            var result = service.Simulate(fish,
                weightMultiplier: weightK,
                iterations: iterations,
                normalThreshold: threshold,
                normalSigma: sigma,
                step: step);

            // Map to JSON-friendly format with string keys
            var response = new
            {
                step = result.Step,
                forms = result.Forms.ToDictionary(
                    kvp => kvp.Key.ToString(),
                    kvp => new
                    {
                        minWeight = kvp.Value.MinWeight,
                        maxWeight = kvp.Value.MaxWeight,
                        totalGenerated = kvp.Value.TotalGenerated,
                        buckets = kvp.Value.Buckets.Select(b => new
                        {
                            weight = b.Weight,
                            count = b.Count,
                            pct = b.Percentage
                        }),
                        crossoversTo = kvp.Value.CrossoversTo.ToDictionary(
                            c => c.Key.ToString(),
                            c => c.Value)
                    })
            };

            return JsonUtc(response);
        }

        // POST: /Stats/ExportWeightSimulation (form submit → file download)
        [HttpPost]
        public ActionResult ExportWeightSimulation(
            int pondId, int fishCategoryId, int iterations,
            float weightK, float threshold, float sigma, float? step)
        {
            var fish = GetFishDescription(pondId, fishCategoryId);
            if (fish == null)
                return HttpNotFound("Fish not found on this pond");

            var service = new FishWeightSimulationService();
            var result = service.Simulate(fish,
                weightMultiplier: weightK,
                iterations: iterations,
                normalThreshold: threshold,
                normalSigma: sigma,
                step: step);

            // Build TSV — all forms share the same bucket grid (same count, same weights)
            var sb = new StringBuilder();
            sb.AppendLine("WeightBucket\tY\tC\tT\tU\tTotal");

            var anyForm = result.Forms.Values.First();
            for (int i = 0; i < anyForm.Buckets.Count; i++)
            {
                var w = anyForm.Buckets[i].Weight;
                int y = GetBucketCountByIndex(result, FishForm.Young, i);
                int c = GetBucketCountByIndex(result, FishForm.Common, i);
                int t = GetBucketCountByIndex(result, FishForm.Trophy, i);
                int u = GetBucketCountByIndex(result, FishForm.Unique, i);
                sb.AppendLine($"{w:F2}\t{y}\t{c}\t{t}\t{u}\t{y + c + t + u}");
            }

            var fishName = ((FishName)fishCategoryId).ToString();
            var pondInfo = GameServerCache.GetPondDirect(pondId, SharedConsts.DefaultLanguageId);
            var pondName = pondInfo.Asset.Replace(" ", "");
            var stepStr = result.Step.ToString("F2");

            var fileName = $"WeightSim_{fishName}_{pondName}_N{iterations}_wK{weightK}_t{threshold}_s{sigma}_step{stepStr}.tsv";

            return File(Encoding.UTF8.GetBytes(sb.ToString()), "text/tab-separated-values", fileName);
        }

        private static int GetBucketCountByIndex(FishWeightSimulationResult result, FishForm form, int index)
        {
            if (result.Forms.TryGetValue(form, out var formResult) && index < formResult.Buckets.Count)
                return formResult.Buckets[index].Count;
            return 0;
        }

        private FishDescription GetFishDescription(int pondId, int fishCategoryId)
        {
            var pondInfo = GameServerCache.GetPondDirect(pondId, SharedConsts.DefaultLanguageId);
            var pond = BiteSystemCache.BiteMaps.Cache.FindPond(pondInfo.Asset);
            if (pond == null) return null;

            var fishName = (FishName)fishCategoryId;
            return pond.GetFishDescription(fishName);
        }
    }
}
```

- [ ] **Step 2: Verify build**

Ask user to build `WebAdmin/WebAdmin.sln`.

- [ ] **Step 3: Commit**

```
[FishWeightSim] Add StatsController partial class and ViewModel
+ `FishWeightSimulation()` GET — page with pond dropdown
+ `GetPondFishList()` GET — cascading fish list with forms and weight ranges
+ `SimulateWeights()` POST — runs simulation, returns JSON histogram
+ `ExportWeightSimulation()` POST — TSV file download with all params in filename
+ `FishWeightSimulationViewModel` — pond list, default parameters
(Task: FP-41845 — Weight Generation v2)
```

---

## Chunk 3: Razor View & JavaScript

### Task 7: Create the simulation page view

**Files:**
- Create: `WebAdmin/WebAdmin/Views/Stats/FishWeightSimulation.cshtml`

- [ ] **Step 1: Write the Razor view**

```html
@model WebAdmin.Models.BiteSystem.FishWeightSimulationViewModel

@{
    ViewBag.Title = "Fish Weight Simulation";
}

<hgroup class="title">
    <h1>@ViewBag.Title</h1>
</hgroup>

<style>
    .sim-form { margin-bottom: 10px; }
    .sim-form table td { padding: 4px 8px; white-space: nowrap; }
    .sim-form input[type=text], .sim-form select { width: 120px; }
    .form-toggles { margin: 8px 0; }
    .form-toggles label { margin-right: 16px; font-weight: bold; }
    .form-toggles .form-young { color: #4285F4; }
    .form-toggles .form-common { color: #EA4335; }
    .form-toggles .form-trophy { color: #FBBC04; }
    .form-toggles .form-unique { color: #34A853; }
    .crossover-info { margin: 4px 0; color: #666; font-size: 0.9em; }
    #simulationChart { height: 450px; }
    .sim-status { margin: 8px 0; color: #888; }
</style>

<div class="sim-form">
    <table>
        <tr>
            <td>Pond:</td>
            <td>
                <select id="pondSelect">
                    <option value="">-- Select Pond --</option>
                    @foreach (var p in Model.PondList)
                    {
                        <option value="@p.Value">@p.Text</option>
                    }
                </select>
            </td>
            <td>Fish:</td>
            <td><select id="fishSelect" disabled><option value="">-- Select Fish --</option></select></td>
            <td>N:</td>
            <td><input type="text" id="iterations" value="@Model.Iterations" /></td>
            <td>weightK:</td>
            <td><input type="text" id="weightK" value="@Model.WeightK.ToString("F1")" /></td>
        </tr>
        <tr>
            <td></td>
            <td></td>
            <td></td>
            <td></td>
            <td>threshold:</td>
            <td><input type="text" id="threshold" value="@Model.Threshold.ToString("F2")" /></td>
            <td>sigma:</td>
            <td><input type="text" id="sigma" value="@Model.Sigma.ToString("F2")" /></td>
        </tr>
        <tr>
            <td>Step:</td>
            <td><input type="text" id="step" placeholder="Auto" /></td>
            <td colspan="2">
                <button type="button" class="k-button" id="btnSimulate" onclick="runSimulation()">Simulate</button>
                <button type="button" class="k-button" id="btnExport" onclick="exportTsv()" disabled>Export TSV</button>
            </td>
            <td colspan="4"><span class="sim-status" id="simStatus"></span></td>
        </tr>
    </table>
</div>

<div class="form-toggles" id="formToggles" style="display:none;">
    <label class="form-young"><input type="checkbox" checked data-form="Young" onchange="toggleFormSeries(this)" /> Young</label>
    <label class="form-common"><input type="checkbox" checked data-form="Common" onchange="toggleFormSeries(this)" /> Common</label>
    <label class="form-trophy"><input type="checkbox" checked data-form="Trophy" onchange="toggleFormSeries(this)" /> Trophy</label>
    <label class="form-unique"><input type="checkbox" checked data-form="Unique" onchange="toggleFormSeries(this)" /> Unique</label>
    <span class="crossover-info" id="crossoverInfo"></span>
</div>

<div id="simulationChart"></div>

<script type="text/javascript">
    var lastSimResult = null;
    var formColors = {
        "Young": "#4285F4",
        "Common": "#EA4335",
        "Trophy": "#FBBC04",
        "Unique": "#34A853"
    };

    // Pond change → load fish list
    $("#pondSelect").change(function () {
        var pondId = $(this).val();
        var fishSelect = $("#fishSelect");
        fishSelect.empty().append('<option value="">-- Select Fish --</option>');

        if (!pondId) {
            fishSelect.prop("disabled", true);
            return;
        }

        $.ajax({
            url: '@Url.Action("GetPondFishList", "Stats")',
            data: { pondId: pondId },
            success: function (data) {
                $.each(data, function (_, fish) {
                    fishSelect.append($('<option>', {
                        value: fish.fishCategoryId,
                        text: fish.name
                    }));
                });
                fishSelect.prop("disabled", false);
            }
        });
    });

    function getParams() {
        return {
            pondId: parseInt($("#pondSelect").val()),
            fishCategoryId: parseInt($("#fishSelect").val()),
            iterations: parseInt($("#iterations").val()) || 100000,
            weightK: parseFloat($("#weightK").val()) || 1.0,
            threshold: parseFloat($("#threshold").val()) || 0.95,
            sigma: parseFloat($("#sigma").val()) || 0.55,
            step: $("#step").val() ? parseFloat($("#step").val()) : null
        };
    }

    function runSimulation() {
        var params = getParams();
        if (!params.pondId || !params.fishCategoryId) {
            alert("Select a Pond and Fish first.");
            return;
        }

        $("#simStatus").text("Simulating...");
        $("#btnSimulate").prop("disabled", true);

        $.ajax({
            url: '@Url.Action("SimulateWeights", "Stats")',
            type: "POST",
            data: params,
            success: function (data) {
                if (data.error) {
                    alert(data.error);
                    return;
                }
                lastSimResult = data;

                // Fill step placeholder with computed value
                if (!$("#step").val()) {
                    $("#step").attr("placeholder", data.step.toFixed(2));
                }

                renderChart(data);
                renderCrossovers(data);
                $("#formToggles").show();
                $("#btnExport").prop("disabled", false);
            },
            error: function () {
                alert("Simulation failed. Check server logs.");
            },
            complete: function () {
                $("#simStatus").text("");
                $("#btnSimulate").prop("disabled", false);
            }
        });
    }

    function renderChart(data) {
        var series = [];
        var formOrder = ["Young", "Common", "Trophy", "Unique"];

        $.each(formOrder, function (_, formName) {
            if (data.forms[formName]) {
                var buckets = data.forms[formName].buckets;
                var chartData = $.map(buckets, function (b) {
                    return { weight: b.weight, pct: b.pct };
                });

                series.push({
                    name: formName,
                    data: chartData,
                    field: "pct",
                    categoryField: "weight",
                    color: formColors[formName],
                    line: { width: 1.5 },
                    opacity: 0.6,
                    visible: $('[data-form="' + formName + '"]').is(':checked')
                });
            }
        });

        $("#simulationChart").empty();
        $("#simulationChart").kendoChart({
            title: { text: "Weight Distribution by Form" },
            legend: { position: "top" },
            seriesDefaults: {
                type: "area",
                missingValues: "zero"
            },
            series: series,
            categoryAxis: {
                title: { text: "Weight" },
                labels: {
                    rotation: -45,
                    step: Math.max(1, Math.floor(series.length > 0 && series[0].data.length > 50 ? series[0].data.length / 30 : 1))
                },
                majorGridLines: { visible: false }
            },
            valueAxis: {
                title: { text: "% within form" },
                labels: { format: "{0}%" }
            },
            tooltip: {
                visible: true,
                format: "{0}%",
                template: "#= series.name #: #= value.toFixed(2) #% at #= category # kg"
            }
        });
    }

    function toggleFormSeries(checkbox) {
        var chart = $("#simulationChart").data("kendoChart");
        if (!chart) return;

        var formName = $(checkbox).data("form");
        var series = chart.options.series;
        for (var i = 0; i < series.length; i++) {
            if (series[i].name === formName) {
                series[i].visible = checkbox.checked;
            }
        }
        chart.refresh();
    }

    function renderCrossovers(data) {
        var wk = parseFloat($("#weightK").val()) || 1.0;
        if (wk === 1.0) {
            $("#crossoverInfo").text("");
            return;
        }

        var parts = [];
        $.each(data.forms, function (formName, formData) {
            $.each(formData.crossoversTo, function (targetForm, count) {
                if (count > 0) {
                    parts.push(formName + "→" + targetForm + ": " + count);
                }
            });
        });

        $("#crossoverInfo").text(parts.length > 0 ? "Crossovers: " + parts.join(", ") : "No crossovers");
    }

    function exportTsv() {
        var params = getParams();
        if (!params.pondId || !params.fishCategoryId) return;

        // Submit via hidden form for file download
        var form = $('<form method="POST" action="@Url.Action("ExportWeightSimulation", "Stats")" target="_blank"></form>');
        $.each(params, function (key, val) {
            if (val !== null && val !== undefined) {
                form.append($('<input type="hidden">').attr("name", key).val(val));
            }
        });
        $("body").append(form);
        form.submit();
        form.remove();
    }
</script>
```

- [ ] **Step 2: Verify build and manual test**

Ask user to build `WebAdmin/WebAdmin.sln` and navigate to `/Stats/FishWeightSimulation` in browser.
Check:
1. Pond dropdown loads
2. Selecting a pond populates the fish dropdown
3. Clicking Simulate renders the area chart
4. Form checkboxes toggle series
5. Export TSV downloads a file with correct filename

- [ ] **Step 3: Commit**

```
[FishWeightSim] Add simulation page with Kendo area chart
+ `FishWeightSimulation.cshtml` — filter form, cascading dropdowns, Kendo area chart, form toggle checkboxes, crossover display, TSV export
+ AJAX flow: pond change → fish list, simulate → chart render, export → file download
(Task: FP-41845 — Weight Generation v2)
```

---

## Chunk 4: Polish & Verification

### Task 8: End-to-end verification

- [ ] **Step 1: Test with Nile Perch @ Congo River (pondId=250, fishCategoryId=2020)**

Expected behavior:
- All 4 forms appear (Y/C/T/U)
- Young: right-skewed distribution with density spike near 95% threshold
- Common/Trophy: roughly flat with spike at threshold boundary
- Unique: bimodal "horns" distribution
- Step auto-calculated as 1.0 (range 15..204 = 189, 189/200 ≈ 1.0)
- With weightK=1.0: zero crossovers
- With weightK=1.5: crossovers appear, distribution shifts

- [ ] **Step 2: Test with Northern Pike @ Saint-Croix (pondId=115, fishCategoryId=104)**

Expected: likely fewer forms (verify), patterns consistent with production data.

- [ ] **Step 3: Test TSV export**

Verify:
- Filename contains all parameters
- TSV format: `WeightBucket\tY\tC\tT\tU\tTotal`
- Data matches chart
- File opens correctly in spreadsheet application

- [ ] **Step 4: Final commit (if any fixes needed)**

```
[FishWeightSim] Fix issues found during E2E verification
* <description of fixes>
(Task: FP-41845 — Weight Generation v2)
```

---

## Implementation Notes

### Key reference points
- `FishDescription.GenerateRandomWeight()`: `Shared/BiteSystem/Common/ObjectModel/FishDescription.cs:96`
- `NormalDistribution.GetPossibleNormalFloat()`: `Shared/BiteSystem/Common/NormalDistribution.cs:75`
- `Pond._fish`: `Shared/BiteSystem/Common/ObjectModel/Pond.cs:21`
- `Pond.GetAllFish()`: `Shared/BiteSystem/Common/ObjectModel/Pond.cs:172`
- `Settings.GetFishNameAndForm()`: `Shared/BiteSystem/Common/Settings.cs:406`
- `FishForm` enum: `Shared/BiteSystem/Common/Settings.cs:443` (Young, Common, Trophy, Unique)
- `FishName` enum: `Shared/BiteSystem/Common/Settings.cs:9` (values = CategoryIds, e.g. `NilePerch = 2020`)
- `BiteSystemCache.BiteMaps`: `Shared/SharedLib/Game/BiteSystemCache.cs:20`
- `GameServerCache.GetAllPondsAssetMapping()`: `Shared/SharedLib/Config/GameServerCache.cs:420`
- `StatsController` declaration: `WebAdmin/WebAdmin/Controllers/StatsController.cs:27`
- Existing Kendo chart pattern: `WebAdmin/WebAdmin/Views/Stats/FishWeightDistribution.cshtml`
- Existing BiteSystem ViewModel: `WebAdmin/WebAdmin/Models/BiteSystem/PondFishFormViewModel.cs`

### Parameter name mapping (spec reference)
| UI label  | API JSON field | Service parameter    | BiteSystem parameter        |
|-----------|----------------|----------------------|-----------------------------|
| threshold | `threshold`    | `normalThreshold`    | `normalPercentageFrom`      |
| sigma     | `sigma`        | `normalSigma`        | `normalDistributionSigma`   |
| weightK   | `weightK`      | `weightMultiplier`   | `weightK`                   |

### Dependency constraint
`FishWeightSimulationService` in `Shared/BiteSystem/Common/` must NOT reference `SharedLib`. The service receives `FishDescription` as a parameter — the controller handles lookup via `BiteSystemCache`.

### Build commands
```
msbuild Shared\BiteSystem\BiteSystem.csproj /p:Configuration=Debug
msbuild WebAdmin\WebAdmin.sln /p:Configuration=Debug
dotnet test --no-build Shared\BiteSystem.Tests\BiteSystem.Tests.csproj
```
