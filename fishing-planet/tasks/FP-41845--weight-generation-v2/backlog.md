# FP-41845 — Backlog

## Phase 1: Instrumentation & Simulation

### 1.1 Understand production data & validate FishFact
- [x] Study `FishFact` table — schema, fields, SQL patches, write sites in code → [fish-fact.md](../../server/modules/fish-generator/fish-fact.md)
- [x] Determine what production data is available per fish/pond/form — FishId = form ID, Weight, Source, all lifecycle events
- [x] Production config confirmed: `CollectFishGenerationStats` = ON, `FishGenerationStatsCleanupHorizonDays` = 90
- [x] Build SQL query — single query with PIVOT by form (WeightBucket | Y | C | T | U | Total), Source='B' filter
- [x] Tested on Northern Pike @ Saint-Croix (step=0.5 kg) and Nile Perch @ Congo (step=1 kg) — data quality confirmed
- [x] Histograms match expected patterns: Common/Trophy = flat rectangle + spike at 95%; Young = right-skewed hyperbola with sharp spike; Unique = bimodal "horns" with suppressed edges — all consistent with form polynomial effects
- [x] Output format: TSV → spreadsheet, percentages via `=IFERROR(cell/SUM(col), 0)` per form

### 1.2 Understand generation pipeline completeness
- [x] All generation paths write to FishFact (B, X, W, C, A, M, S, E, P, D) → [fish-fact.md](../../server/modules/fish-generator/fish-fact.md)
- [x] Simulator scope: **BiteSystem path only** (Source='B'). Target fish come exclusively from BiteSystem; other sources (FishBox, FishGenerator carousel, etc.) are legacy and use a different weight algorithm (`GameUtils.RandomizeFishWeight`). Note: BiteSystem has its own internal carousel (FishSelector) for fish selection — this is the primary production mechanism
- [x] Document simulator config requirements — params exposed via UI (weightK, threshold, sigma, iterations, step), defaults from GlobalVariablesCache

#### Key findings from 1.2
- All weight generation parameters (polynomials, threshold, sigma, MinWeight/MaxWeight, form) live in BiteSystem code and config — simulator will use them directly via real code, no hardcoding needed
- `weightK` comes from the **chum (groundbait) system** particles, not from pond/fish config. Without chum, weightK=1.0 and has no effect. All known weightK bugs (double application, threshold lowering, asymmetric return) only manifest when chum is used
- Simulator approach: **invoke real BiteSystem code** (no code copying) — see 1.3 for options

### 1.3 Build simulator

**Constraint: NO code copying.** Chose Option B — WebAdmin integration. BiteSystem assembly is accessible from WebAdmin.

- [x] Investigate which assemblies WebAdmin references — confirmed BiteSystem / `FishDescription.GenerateRandomWeight()` accessible
- [x] Design WebAdmin controller/page for simulation with chart output → [design](artifacts/archived/fish-weight-simulator-design.md), [plan](artifacts/archived/fish-weight-simulator-plan.md)
- [x] Implement: `FishWeightSimulationService` in `Shared/BiteSystem/Common/`, partial `StatsController`, Razor view with Kendo area chart
- [x] Output results: histogram buckets (same grid for all forms), TSV export with same format as production SQL query
- [x] Charting: Kendo area chart, form toggles, shared tooltips with count+percentage, crossover info
- [x] Top-200 leaderboard preview per form (weights bucketed by actual form)
- [x] Code review + fixes: null-safety, iterations cap (20M), `parseFloatSafe`, `OriginalForm` clarity, single-form test
- [x] 11 unit tests green

**Design note:** simulator accepts `weightK` parameter for chum effect analysis. Form ratio integration deferred — see [fish-selector-form-ratio.md](../../server/modules/fish-generator/fish-selector-form-ratio.md).

### 1.4 Validate simulator against production
- [ ] Get fish IDs of interest from game designers (start with reference fish from 1.1)
- [ ] Compare simulated histograms vs production histograms — verify shapes match within each form
- [ ] Investigate and explain discrepancies (if any)

## Phase 2: Algorithm Design & Implementation
(to be defined after phase 1 — depends on what simulation reveals and GD requirements)

## Phase 3: Documentation (FP-41844)
(blocked until phase 2 complete — artifacts from phases 1-2 become source material)

## Reference Data

### Test fish
| Pond             | PondId | Fish          | CategoryId | Young | Common | Trophy | Unique |
|------------------|--------|---------------|------------|-------|--------|--------|--------|
| Congo River      | 250    | Nile Perch    | 2020       | 4550  | 4560   | 4570   | 4580   |
| Saint-Croix Lake | 115    | Northern Pike | 104        | 108   | 109    | 110    | 111    |

### Production config
| Parameter                                    | Value | Source               |
|----------------------------------------------|-------|----------------------|
| `CollectFishGenerationStats`                 | true  | EnvironmentVariables |
| `FishGenerationStatsCleanupHorizonDays`      | 90    | EnvironmentVariables |
| `UseNormalDistributionForFishGeneratingFrom` | 0.95  | GlobalVariables      |
| `NormalDistributionForFishGeneratingSigma`   | 0.55  | GlobalVariables      |

## Deferred / Questions
- ~~Real ratio between forms (Young/Common/Trophy/Unique)~~ — investigated: proportions are emergent from FishSelector layer config, can be estimated from pond config or taken from FishFact. See [fish-selector-form-ratio.md](../../server/modules/fish-generator/fish-selector-form-ratio.md). Combined overall histogram = Σ(p_form × dist_form).
- Unique polynomial "double hump" phenomenon — explain to Stanislav in detail when relevant
- Crossover display format in simulator — currently shows `Young→Common: 150` (original→destination). Need to decide: show from original form perspective, destination form perspective, or both? Consider adding crossover info to the chart itself (e.g., shaded overlap regions or separate crossover histogram)
