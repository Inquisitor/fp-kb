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
- [x] Get fish IDs of interest from game designers (start with reference fish from 1.1) — used Nile Perch @ Congo River
- [x] Compare simulated histograms vs production histograms — all four forms match within 0.13pp max deviation
- [x] Investigate and explain discrepancies — no meaningful discrepancies; boundary crossover accounting (23 fish / 1.9M = 0.001%) is negligible. Detailed analysis in [module log](../../server/modules/fish-generator/log.md)

## Phase 2a: Algorithm Design & Implementation

GD requirements source: [Confluence doc](artifacts/confluence-leaderboards-weight-gen.md), [historical context](artifacts/confluence-bite-system-weight-bias.md)

### 2a.1 Partial revert of r12950 (FP-33182)
- [ ] Remove Young polynomial — replace with `y=x` (uniform distribution)
- [ ] Remove Unique polynomial — replace with `y=x` (uniform distribution)
- [ ] Keep threshold setting (`UseNormalDistributionForFishGeneratingFrom`)
- [ ] Sigma (`NormalDistributionForFishGeneratingSigma`) — TBD whether to keep, repurpose, or remove
- [ ] Repurpose & rename global variables to match new algorithm semantics

### 2a.2 Simulator bucket range fix (bug)
- [ ] Buckets currently end at form max weight — fish generated beyond max (via WeightK) are invisible on chart
- [ ] Extend bucket range to accommodate oversize fish when WeightK > 1

### 2a.3 Decay algorithms in BiteSystem
- [ ] Implement **power-law decay**: `p(x) = ((1-x)/(1-threshold))^α` — density reaches zero at 100%
- [ ] Implement **exponential decay**: `p(x) = exp(-λ(x-threshold)/(1-threshold))` — asymptotic, density approaches zero but never reaches it
- [ ] Both: uniform distribution from 0% to threshold%, smooth decay from threshold% to 100%
- [ ] Both: seam at threshold is smooth by construction (density continuous)
- [ ] GlobalVariable switch to select active algorithm (power-law vs exponential)
- [ ] GlobalVariable for decay steepness parameter (α or λ depending on selected algorithm)
- [ ] Decay does NOT affect WeightK — oversize fish (WeightK > 1) can still exceed 100% of elder form max
- [ ] Generation average shifts only ~1-3% lower — acceptable for balance
- [ ] Historical context: Max's cubic regression attempt on Unique polynomial had the right idea but wrong approach (whole-form distortion → artifacts). New approach: targeted decay only in the tail zone
- [ ] Interactive comparison tool: [decay-comparison.html](artifacts/decay-comparison.html)

### 2a.4 Decay Designer tab in simulator
- [ ] New tab/section on WebAdmin simulator page — interactive decay curve configurator
- [ ] Sliders for threshold, α (power-law), λ (exponential), algorithm selector
- [ ] Live PDF preview (like decay-comparison.html but integrated into WebAdmin with Kendo charts)
- [ ] "Apply to Simulation" button — runs selected decay config through real `GenerateRandomWeight` engine
- [ ] Results displayed on the existing simulator histogram for direct comparison with production data

### 2a.5 WeightK oversize validation
- [ ] Verify that WeightK > 1 correctly pushes Unique fish beyond max weight of elder form
- [ ] Ensure decay curve does not interfere with WeightK oversize behavior

## Phase 2b: Simulator Enhancements
(parallel with 2a — GD feedback during active testing)

- [ ] Crossover visualization — stacked area showing crossover fish as separate layer within each form
- (additional GD requests expected during testing)

## Phase 3: Documentation (FP-41844)
(blocked until phase 2a complete — artifacts from phases 1-2 become source material)

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
- ~~Unique polynomial "double hump" phenomenon~~ — explained, understood
- ~~Crossover visualization~~ — moved to Phase 2b
