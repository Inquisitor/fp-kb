# Fish Weight Simulator — Design Spec

> Task: [FP-41845](../journal.md) Phase 1.3
> Date: 2026-03-10
> Status: Approved

## Goal

WebAdmin page that runs N weight generations for a given fish/pond using real BiteSystem code, displays per-form histograms, and exports data for comparison with production statistics.

## Decisions

| Decision         | Choice                                | Rationale                                                      |
|------------------|---------------------------------------|----------------------------------------------------------------|
| Location         | `StatsController` (partial class)     | Logically grouped with existing stats pages                    |
| Charting         | Kendo Chart, client-side JS rendering | Interactive: toggle forms, re-simulate without page reload     |
| Architecture     | Service layer (Approach B)            | Clean separation: UI ↔ simulation logic ↔ BiteSystem           |
| Service location | `Shared/BiteSystem/Common/`           | Testable without WebAdmin; reusable from server endpoint later |
| Chart style      | Area chart, all forms simultaneous    | Matches production FishWeightDistribution chart                |
| Bucket step      | Auto-calculated with manual override  | Auto fills placeholder after computation                       |

## Scope

### In scope (MVP + extensions)
- Pond/fish selection with cascading dropdowns
- Parameters: N, weightK, threshold, sigma, step
- Per-form simulation via real `GenerateRandomWeight()`
- Area chart with 4 forms (Y/C/T/U), color-coded, checkboxes to toggle
- Combined overall histogram (weighted by simulation counts)
- A/B comparison (two runs with different parameters)
- TSV export compatible with FishStats format
- Form crossover tracking and display

### Out of scope
- Production data overlay (FishFact SQL queries)
- Form ratio estimation from pond config (separate module backlog item)
- FishSelector simulation

## Parameter Name Mapping

The UI, API, service, and BiteSystem code use different names for the same parameters:

| UI label  | API JSON field | Service parameter    | BiteSystem parameter        |
|-----------|----------------|----------------------|-----------------------------|
| threshold | `threshold`    | `normalThreshold`    | `normalPercentageFrom`      |
| sigma     | `sigma`        | `normalSigma`        | `normalDistributionSigma`   |
| weightK   | `weightK`      | `weightMultiplier`   | `weightK`                   |

The service uses clean, descriptive names. The controller maps API field names → service parameter names. The service internally maps to BiteSystem-native names when calling `GenerateRandomWeight()`. BiteSystem parameters will be renamed to match service names in a future refactoring pass.

## Architecture

```
Browser (Kendo Area Chart + filter panel)
    │ AJAX POST (form-encoded)
    ▼
StatsController.FishWeightSimulation.cs (thin)
    │ loads FishDescription via lookup chain (see below)
    ▼
FishWeightSimulationService (in Shared/BiteSystem/Common/)
    │ calls real code, no copying
    ▼
FishDescription.GenerateRandomWeight()  (existing, unmodified)
NormalDistribution.GetPossibleNormalFloat()  (existing, unmodified)
```

### FishDescription Lookup Chain

The controller resolves `(pondId, fishCategoryId)` → `FishDescription`:

1. `BiteSystemCache.BiteMaps` → `Ponds` collection → `Pond` by pondId
2. Cast `fishCategoryId` directly to `FishName`: `(FishName)fishCategoryId` — `FishName` enum values equal CategoryIds (e.g., `NilePerch = 2020`)
3. Get `FishDescription` from `Pond`

**Required code change:** `Pond._fish` is currently private with no public accessor that returns `FishDescription`. We need to add a public method to `Pond`:
```csharp
public FishDescription GetFishDescription(FishName name) => _fish.TryGetValue(name, out var desc) ? desc : null;
```
This is a minimal, non-breaking addition to BiteSystem.

### Dependency Constraint

`FishWeightSimulationService` lives in `Shared/BiteSystem/Common/` and must NOT reference `SharedLib` (which contains `BiteSystemCache`). Adding such a reference would create a circular dependency (`SharedLib` → `BiteSystem` → `SharedLib`). The service receives `FishDescription` as a parameter — the caller (controller) is responsible for loading it.

## API

### GET /Stats/FishWeightSimulation
Returns page with filter form. Pond list from `BiteSystemCache`.

### AJAX GET /Stats/GetPondFishList?pondId={id}
Returns fish species available on the pond with forms and weight ranges.

Implementation: `Pond.GetAllFish()` returns per-fishId `FormRecord` entries. Controller groups them by species (via `Settings.GetFishNameAndForm()` or `FishCache`), then for each species enumerates its forms with MinWeight/MaxWeight from `FormRecord`. If `Pond` does not expose a convenience method for this, the controller builds the grouped response manually.

Response:
```json
[
  {
    "fishCategoryId": 2020,
    "name": "Nile Perch",
    "forms": [
      {"form": "Young", "minWeight": 15.0, "maxWeight": 40.0},
      {"form": "Common", "minWeight": 40.0, "maxWeight": 80.0},
      {"form": "Trophy", "minWeight": 80.0, "maxWeight": 130.0},
      {"form": "Unique", "minWeight": 130.0, "maxWeight": 204.0}
    ]
  }
]
```

### AJAX POST /Stats/SimulateWeights
Request:
```json
{
  "pondId": 250,
  "fishCategoryId": 2020,
  "iterations": 100000,
  "weightK": 1.0,
  "threshold": 0.95,
  "sigma": 0.55,
  "step": null
}
```

Response:
```json
{
  "step": 1.0,
  "forms": {
    "Young": {
      "minWeight": 15.0,
      "maxWeight": 40.0,
      "totalGenerated": 100000,
      "buckets": [
        {"weight": 15.0, "count": 1823, "pct": 1.82},
        {"weight": 16.0, "count": 2041, "pct": 2.04}
      ],
      "crossoversTo": {"Common": 12}
    },
    "Common": { "..." : "..." },
    "Trophy": { "..." : "..." },
    "Unique": { "..." : "..." }
  }
}
```

### POST /Stats/ExportWeightSimulation
Same simulation parameters as SimulateWeights, but submitted via HTML form (`application/x-www-form-urlencoded`), not JSON. The controller uses a flat `[FromForm]` binding model (nullable `step` represented as empty string → null).

TSV filename encodes all parameters: `WeightSim_{Fish}_{Pond}_N{iterations}_wK{weightK}_t{threshold}_s{sigma}_step{step}.tsv`
Example: `WeightSim_NilePerch_CongoRiver_N100000_wK1.0_t0.95_s0.55_step1.0.tsv`

Returns TSV `FileResult`:
```
WeightBucket	Y	C	T	U	Total
15.00	1823	0	0	0	1823
16.00	2041	0	0	0	2041
...
```

## Service Design

### FishWeightSimulationService

Location: `Shared/BiteSystem/Common/FishWeightSimulationService.cs`

```csharp
public class FishWeightSimulationService
{
    public FishWeightSimulationResult Simulate(
        FishDescription fish,
        float weightMultiplier,
        int iterations,
        float normalThreshold,
        float normalSigma,
        float? step);
}
```

Internally maps to BiteSystem names when calling:
```csharp
fish.GenerateRandomWeight(rnd, form,
    weightK: weightMultiplier,
    normalPercentageFrom: normalThreshold,
    normalDistributionSigma: normalSigma);
```

Algorithm:
1. Compute global weight range across all forms: `globalMin..globalMax`
2. Auto-calculate step if null:
   - Compute raw step: `rawStep = (globalMax - globalMin) / 200`
   - Floor: if `rawStep < 0.01`, use `0.01`
   - Ceiling: if `rawStep > 50`, use `50`
   - Otherwise: find first element ≥ `rawStep` in the ordered set `{0.01, 0.02, 0.05, 0.1, 0.2, 0.25, 0.5, 1, 2, 5, 10, 25, 50}`
3. Create bucket grid from `globalMin` to `globalMax`
4. For each form, N iterations:
   - Call `fish.GenerateRandomWeight(rnd, form, weightMultiplier, normalThreshold, normalSigma)`
   - `result` is a `RandomWeight` with `.Weight`, `.Form` (final), `.OriginalForm`
   - Place `result.Weight` into the **original form's** bucket list (the form we requested generation for). Crossover fish stay in the originating form's histogram — this shows what the algorithm produces for that form, including the weight distortion from `weightK`.
   - **Crossover weight note:** for crossover fish, `result.Weight` = `changedWeight` = `weight * weightK`, which by definition falls **outside** the originating form's `[MinWeight, MaxWeight]` range. These weights land in buckets beyond the form's natural bounds (the global bucket grid covers all weights). This is intentional — it visually shows the "crossover tail" extending past the form boundary. The chart should mark each form's `[MinWeight, MaxWeight]` range (e.g., with vertical lines or shading) so the user can distinguish natural distribution from crossover artifacts.
   - If `result.Form != result.OriginalForm` → increment `CrossoversTo[result.Form]`
5. Normalize counts → percentages per form (denominator = N iterations for that form)
6. Return `FishWeightSimulationResult`

**Note on `weightK` behavior in the underlying code:** `GenerateRandomWeight()` applies `weightK` twice — once to `norm` (before `GetPossibleNormalFloat`, distorting distribution shape) and once to `weight` (after, but only used for form crossover check). Within-form fish receive weight WITHOUT the second `weightK` multiplication. This is a known bug (see [log.md](../../server/modules/fish-generator/log.md), entry "weightK bug confirmed via SVN diff"). The simulator faithfully reproduces this behavior since it calls the real code.

Thread safety: one `Random` per call, service is stateless.

### Data Models

```csharp
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
    public float Weight { get; set; }     // bucket lower bound
    public int Count { get; set; }
    public float Percentage { get; set; }
}
```

## UI Design

### Layout
Horizontal filter panel above chart (matches FishWeightDistribution pattern):

```
┌───────────────────────────────────────────────────────────────┐
│  Fish Weight Simulation                                       │
├───────────────────────────────────────────────────────────────┤
│  Pond: [▼ dropdown ]  Fish: [▼ dropdown ]                     │
│  N: [100000] weightK: [1.0] threshold: [0.95] sigma: [0.55]   │
│  Step: [Auto     ]   [Simulate]  [Export TSV]                 │
├───────────────────────────────────────────────────────────────┤
│  ☑ Young  ☑ Common  ☑ Trophy  ☑ Unique       Crossovers: ...  │
├───────────────────────────────────────────────────────────────┤
│                    Kendo Area Chart                           │
│  (X = weight, Y = % within form, 4 colored area series)       │
└───────────────────────────────────────────────────────────────┘
```

### Colors
| Form   | Color    | Hex     |
|--------|----------|---------|
| Young  | Blue     | #4285F4 |
| Common | Red/Pink | #EA4335 |
| Trophy | Yellow   | #FBBC04 |
| Unique | Green    | #34A853 |

### JavaScript Flow
1. Pond change → AJAX `GetPondFishList` → populate Fish dropdown
2. Fish change → update form checkboxes, fill defaults (threshold/sigma from known production values)
3. [Simulate] → AJAX POST `SimulateWeights` → render chart, fill computed step into input
4. Checkboxes → toggle series visibility (client-side, no re-request)
5. [Export TSV] → form submit → file download

### Crossover Display
Below checkboxes, shown only when weightK ≠ 1.0:
"Crossovers: Young→Common: 12, Trophy→Unique: 3"

## File Structure

```
Shared/BiteSystem/
└── Common/
    └── FishWeightSimulationService.cs      // service + result models

Shared/BiteSystem.Tests/
└── FishWeightSimulationServiceTests.cs     // unit tests

WebAdmin/WebAdmin/
├── Controllers/
│   └── StatsController.FishWeightSimulation.cs
├── Models/
│   └── BiteSystem/
│       └── FishWeightSimulationViewModel.cs
└── Views/
    └── Stats/
        └── FishWeightSimulation.cshtml
```

## Testing

Unit tests in `Shared/BiteSystem.Tests/FishWeightSimulationServiceTests.cs`:

1. **Common form, weightK=1** → flat distribution (identity polynomial), no crossovers
2. **Young form, weightK=1** → right-skewed distribution with density spike near the `normalPercentageFrom` boundary (caused by `GetPossibleNormalFloat` switching from uniform to half-normal sampling, amplified by Young polynomial inflating norm values toward that threshold)
3. **weightK > 1** → crossovers appear (some fish reclassified to adjacent form), distribution shifts toward upper range, crossover weights land in buckets beyond the originating form's `[MinWeight, MaxWeight]`
4. **weightK = 1** → zero crossovers guaranteed
5. **Auto step** → bucket count ~200, step from the defined "nice" set
6. **Manual step** → exact match, buckets align to provided value
7. **Only existing forms** in result — no dummy entries for missing forms (fish with 2 forms → 2 entries in result)

No unit tests for View/JS/Controller — manual QA via browser.

## Future Extensions (designed for, not implemented)

- **Form ratio integration:** service returns per-form results; combiner is external. API: `run per form → weight externally → combine`. See [fish-selector-form-ratio.md](../../server/modules/fish-generator/fish-selector-form-ratio.md).
- **Production overlay:** add FishFact SQL endpoint later, chart JS already supports multiple data sources.
- **Server endpoint reuse:** service lives in BiteSystem assembly, accessible from game server without WebAdmin dependency.
