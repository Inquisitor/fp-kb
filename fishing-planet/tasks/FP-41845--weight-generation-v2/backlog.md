# FP-41845 — Backlog

## Phase 1: Instrumentation & Simulation

### 1.1 Understand production data & validate FishFact
- [ ] Study `FishFact` table — schema, what fields are captured, where data comes from (SQL patches + write sites in code)
- [ ] Determine what production data is available per fish/pond/form: weight, form, pond, generation source, parameters
- [ ] Build a SQL query to extract weight distribution for a specific fish+pond, grouped by form
- [ ] Test the query against reference fish to validate FishFact data quality:
  - Nile Perch @ Congo River (pond=250): Y=4550, C=4560, T=4570, U=4580 (category=2020)
  - Northern Pike @ Saint-Croix Lake (pond=115): Y=108, C=109, T=110, U=111 (category=104)
- [ ] Review resulting histograms — assess whether FishFact captures enough data for meaningful comparison
- [ ] Decide on histogram bucket granularity and output format (to be discussed during work)

### 1.2 Understand generation pipeline completeness
- [ ] Map which generation paths feed FishFact (BiteSystem only? GameModel too? FishBox/Carousel/Scripted?)
- [ ] Determine whether simulator needs to cover only BiteSystem path or also GameModel path (`GameUtils.RandomizeFishWeight()`)
- [ ] Document which real pond/fish configuration data the simulator needs to load (form polynomials, weightK, min/max weights, threshold, sigma)

### 1.3 Build simulator
- [ ] Create test project (or extend existing) that can run weight generation for a specific fish+pond+form with real configuration
- [ ] Load real pond/fish parameters (form polynomials, weightK, weight ranges, threshold, sigma) — either from DB or hardcoded per test scenario
- [ ] Run N iterations, collect weight distribution histogram
- [ ] Output results in agreed format with same bucket granularity as production stats for comparability

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

## Deferred / Questions
- Real ratio between forms (Young/Common/Trophy/Unique) — shouldn't matter for per-form histograms, but verify
- Unique polynomial "double hump" phenomenon — explain to Stanislav in detail when relevant
- Scope of GameModel path (`RandomizeFishWeight` with Bias) — investigate in 1.2
