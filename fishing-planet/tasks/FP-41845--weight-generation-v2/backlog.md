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
- [x] Revert threshold/Marsaglia re-roll — restored pre-r12950 uniform lerp in `GenerateRandomWeight()`
- [x] Fixed double weightK application bug (was applied to both norm and final weight in r12950)
- [x] Method signature kept (params unused, will be repurposed for edge distribution)

### 2a.2 Simulator bucket range fix (bug)
- [x] Extended `globalMax *= weightMultiplier` when weightK > 1 — oversize fish now visible on chart

### 2a.3 Edge distribution system
- [ ] Implement edge distribution algorithms — see [design spec](artifacts/edge-distribution-design.md)

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

## Decisions

### Naming: "Edge" terminology (2026-03-13)

Chosen: **Edge Distribution** family (`IEdgeDistributionStrategy`, `EdgeDistribution`, `EdgeDistributionScope`, `CapAtThreshold`, `Unrestricted`, `PowerLawEdge`, `ExponentialEdge`).

Alternatives considered:
- **Tail** — rejected: "tail" in probability theory means a semi-infinite range (x→∞), but here the zone is bounded [threshold, 1.0]. Would confuse anyone with statistics background.
- **Decay** — rejected for type/variable names (kept as informal conversation term): "decay" implies exponential by default, but we have four algorithms including one that's the opposite of decay (`Unrestricted`).
- **FishWeight** prefix on enums — rejected for enum types: enums live in their own namespace (`BiteSystem.ServerOnly.FishWeight.Edge`), so the prefix is redundant. Long prefixed names (`FishWeightEdgeDistribution`, `FishWeightEdgeScope`) used only for GlobalVariablesCache properties (flat namespace).

Rationale: "Edge" is neutral — it describes position (the edge of the weight range) without implying a specific mathematical behavior. Works for all four algorithms including the pass-through.

Documents updated: [edge-distribution-design.md](artifacts/edge-distribution-design.md), [edge-distribution-impl-plan.md](artifacts/edge-distribution-impl-plan.md).

### Zone Fraction instead of Threshold (2026-03-14)

Chosen: **Zone fraction** (`UpperEdgeZoneFraction = 0.05`, `LowerEdgeZoneFraction = 0.0`) instead of threshold (0.95).

Rationale:
- Threshold is the complement of what the algorithm actually uses — every formula had `1-threshold`, adding cognitive overhead
- Zone size directly represents the portion where the algorithm acts
- For the lower edge, threshold from the opposite side is counter-intuitive; zone fraction works symmetrically from either edge
- Fractions (0–1), not percentages (0–100) — consistent with existing GV convention, no `/100` conversion in code, `Fraction` suffix self-documents the unit

SQL migration: `FishWeightUpperEdgeZoneFraction = 1.0 - OldThreshold` (0.05 = 1.0 - 0.95).

### [Flags] EdgeDistributionScope (2026-03-14)

Chosen: **Bit flags** for `EdgeDistributionScope` — form × edge matrix (Heaviest/Lightest/Others × Upper/Lower = 6 bits).

Named presets: `Heaviest` (u-----), `Extremes` (u--l--), `All` (ululul). Custom combinations via bitwise OR in GV string: `"HeaviestUpper, LightestLower"`.

Rationale:
- `Extremes` implies both edges: upper on heaviest + lower on lightest — requires flag granularity
- Unix permissions analogy (h-l-o × u-l) — extensible without enum changes
- `HasFlag()` eliminates special-case logic in `GetEdgeFlags()`
- `Enum.TryParse` with `[Flags]` handles comma-separated names natively

### Controller namespace: Settings (2026-03-14)

Chosen: `WebAdmin.Controllers.Settings` with partial controller pattern (`SettingsController.FishWeightGenerator.cs`).

Rationale: existing StatsController uses partial pattern. Settings pages should be organized, not dumped into flat Controllers/. Zero cost now, saves reorganization later.

## Deferred / Questions
- ~~Real ratio between forms (Young/Common/Trophy/Unique)~~ — investigated: proportions are emergent from FishSelector layer config, can be estimated from pond config or taken from FishFact. See [fish-selector-form-ratio.md](../../server/modules/fish-generator/fish-selector-form-ratio.md). Combined overall histogram = Σ(p_form × dist_form).
- ~~Unique polynomial "double hump" phenomenon~~ — explained, understood
- ~~Crossover visualization~~ — moved to Phase 2b
