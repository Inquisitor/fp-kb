# Fish Generator — Decision Log

## 2026-03-07: Module card created
- Created `_card.md`, `weight-generation.md`, `backlog.md`
- Deep-dived weight generation: algorithm, sources, downstream systems, lifecycle
- Related: FP-33182

## 2026-03-07: Test coverage review — decision to audit
Full review of all test files related to fish generator module. Findings documented in [test-coverage.md](test-coverage.md).

**Key findings:**
- Most existing "tests" are data generators for manual analysis (file output, Console.WriteLine) with zero assertions
- `NormalDistribution` — 3 tests, all pass unconditionally (no Assert calls)
- `GameUtils.RandomizeFishWeight()` — zero tests for the core weight pipeline
- `Hooker` — 1 real test (multiplier only), formula shape/continuity/negativity untested
- `FishGenerator` — only bite time and scripted fish selection tested; weight generation, hooking, escape, catch all uncovered

**Decision:** Add test coverage items to module backlog. Priority: RandomizeFishWeight > NormalRandom statistical > Hooker formula > NormalDistribution assertions.

**Potential code issues found during review:**
1. `FishTemplate.WeightedQuantity` stale cache risk (lazy init with `== 0` check)
2. `Hooker.HookingProbablity` can theoretically go negative (no floor guard)
3. `GetMinMaxValue` asymmetric clamping (lower only, no upper)

## 2026-03-08: Normal distribution deep dive
Investigated all uses of normal distribution in fish weight generation. Documented in [normal-distribution.md](normal-distribution.md).

**Key findings:**
- Two independent implementations: `NormalRandom` (Box-Muller/sin, GameModel) and `NormalDistribution` (Marsaglia polar, BiteSystem)
- GameModel path: normal distribution only activates when `FishWeightBias` ≠ No (half-normal for Min/Max bias)
- BiteSystem path: hybrid uniform/normal — normal kicks in above configurable threshold (production default 0.95 = only top 5%)
- Form-specific polynomials add pre-normal nonlinearity: Young inflates norm (x=0.9→0.99, enters normal branch more easily); Unique is non-monotonic (peak at x≈0.3, dip at x≈0.7)
- `weightK` applied twice (to norm and to weight) — if weightK>1, guarantees normal branch
- Hardcoded defaults (0.75/0.2) vs SQL defaults (0.95/0.55) diverge significantly — fallback behavior is very different

## 2026-03-10: FishFact deep dive (FP-41845 phase 1.1)
Investigated FishFact statistics table — schema, SQL patches, C# write path, existing queries. Documented in [fish-fact.md](fish-fact.md).

**Key findings:**
- FishFact is a lifecycle table: INSERT at generation, UPDATE at each event (gone/hooked/escaped/caught/etc.)
- Records **all** generated fish, not just caught — complete weight distribution picture
- `FishId` = form-specific ID (e.g., 4550=NilePerchY) — filtering by form is trivial
- 11 source codes (B=BiteSystem, X=FishBox, W=PondWide, etc.) — defined in `FishGenerator.cs:26-36`
- Existing `GetFishWeightDistributionStats` already does weight-bucket histograms with `Source = 'B'` filter
- Feature flag: `EnvironmentVariableCache.CollectFishGenerationStats`
- Data is ephemeral (Cleanup removes old records)

**Decision:** FishFact is suitable as production data source for simulator validation (FP-41845 backlog item 1.1).

## 2026-03-10: Production data validation — polynomial effects confirmed
Extracted weight distribution histograms from FishFact for Northern Pike @ Saint-Croix and Nile Perch @ Congo River. Production data confirms form polynomial effects on weight distribution:
- **Common/Trophy** (identity polynomial): flat rectangle + sharp spike at 95% boundary — pure algorithm artifact, no polynomial distortion
- **Young** (concave polynomial, inflates norm): right-skewed hyperbola, massive spike at 95% — polynomial pushes most norms toward upper range, disproportionately triggering normal branch
- **Unique** (non-monotonic polynomial): bimodal "horns" distribution with suppressed 0-30% and 70-100% edges, two peaks near 30% and 70%, saddle in between — polynomial remaps inputs to mid-range, creating double-hump pattern

The 95% spike is the `GetPossibleNormalFloat()` artifact: half-normal (`GetMarsaglia01`) peaks at zero, which maps to the **lower boundary** of the 5% normal zone — concentrating fish at the 95% stitch point instead of spreading them toward maximum.

These patterns match known issue #8 (form polynomial interaction) from FP-33182 journal.

## 2026-03-10: Carousel disambiguation
Finding: "Carousel" refers to two unrelated mechanisms:
1. **FishSelector carousel** (`FishSelector._carousel`, BiteSystem) — the primary fish selection mechanism on production. Builds weighted probability wheel from bite maps → selects which fish generates → weight via `FishDescription.GenerateRandomWeight()`. Source=`B`.
2. **FishGenerator carousel** (`FishGenerator.GenerateCarouselFishTemplate()`) — legacy alternative within FishBox path. AbsoluteCarousel (Source=`A`) / ActiveCarousel (Source=`C`). Weight via `GameUtils.RandomizeFishWeight()`.

**Decision:** "Carousel" in project context means FishSelector carousel (BiteSystem) unless explicitly qualified. FishGenerator carousel is legacy, FishBox system is used only in missions. Updated glossary.

## 2026-03-10: Form polynomial origin (oral history from Max Komisarenko)

Max confirmed: polynomial coefficients in `FishDescription._formToNorm` were obtained via curve fitting on a web tool. He chose control points and fitted a cubic polynomial through them. The exact control points are lost — likely included (0,0) and (1,1) plus intermediate shape points.

**Original intent:** reproduce the `FishWeightBias` (Min/Max/No) behavior from the legacy FishBox system when migrating to BiteSystem. FishBox had dynamic bias via `NormalRandom` (Box-Muller half-normal); polynomials were a static approximation of that behavior per form.

**Outcome:** the goal was not fully achieved. Polynomials are a compromise — roughly similar to FishBox bias, but through a different mechanism. When `GetPossibleNormalFloat()` (FP-33182) was later added on top, the interaction between polynomials and the new threshold system was not considered, producing the anomalies visible in production data.

Updated [normal-distribution.md](normal-distribution.md) with origin and intent.

## 2026-03-10: weightK origin identified — chum system

`weightK` parameter in `FishDescription.GenerateRandomWeight()` originates from the **chum (groundbait) system**, not from pond or fish configuration.

**Chain:** `ChumPiece._fishTypeAttractivity[fishId].WeightK` → `ChumSystem.GetAttraction()` (Min pieceWeightK across pieces, interpolated by chum effectiveness norm) → `FishSelector.Record._weightK` (Max across chum zones) → `PondServer.GetFish()` → `GenerateRandomWeight()`. During chum mixing (`Chum_Server`), particles feed into `WeightK` while aromatizers feed into `Attraction` — separate ingredient types, single `FishTypeAttractivity` struct.

**Without chum:** weightK = 1.0, no effect on weight generation. The polynomial → threshold → lerp pipeline operates cleanly.

**With chum:** weightK ≠ 1, and all known issues activate: double application (to norm and to weight), threshold lowering (`0.95 / weightK`), asymmetric return (changedWeight only returned on form cross-over).

**Implication:** weightK bugs may have gone unnoticed because most fishing occurs without chum. The baseline weight distribution (no chum) is unaffected by weightK.

Updated [normal-distribution.md](normal-distribution.md) weightK section and FP-41845 backlog with simulator parameter table.

## 2026-03-10: Simulator architecture decision — no code copying

**Decision:** Simulator must invoke the **real BiteSystem code** directly. No re-implementation, no hardcoded polynomials/thresholds/sigma. Two candidate approaches:
- **Option A:** Server-side endpoint — run N generations via game server operation
- **Option B:** WebAdmin integration — if WebAdmin has access to `BiteSystem` / `FishDescription.GenerateRandomWeight()`, add simulation page with chart rendering

**Rationale:** Code copying creates divergence risk — if the algorithm changes, the simulator silently becomes stale. Using real code guarantees the simulator always reflects production behavior.

**Next step:** Check WebAdmin assembly references to determine if BiteSystem is accessible there (preferred — charts can be built in the same UI).

## 2026-03-10: Confluence design documents catalogued

Three historical BiteSystem design documents added to [module backlog](backlog.md) for future investigation:
1. [Алгоритм и формулы новой системы клева](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/923500587) (Mary Key, Jun 2024) — most current, contains formulas, chum, particles (WeightK origin)
2. [Детальное описание новой системы клева](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/424116241) (Mary Key, Nov 2018) — original design doc (FishBox → density maps migration)
3. [Новая система клева](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/361496584) (Dmytro Lukash, Mar 2021) — high-level architecture

Goal: produce "design vs reality" summary — what was implemented, changed, or dropped.

## 2026-03-10: FishSelector form ratio analysis

Investigated how Y:C:T:U form proportions are determined. Documented in [fish-selector-form-ratio.md](fish-selector-form-ratio.md).

**Key findings:**
- Form proportions are **emergent**, not explicitly configured as percentages
- All forms within a single FishLayer share the same `ProbabilityMap` — spatial probability is identical
- **Layer assignment is the primary driver**: forms in different layers have independent maps and `MapModifier` values
- `AttractorsModifier` (per form) only affects the attractor component — zero effect at spots without attractors
- Bait attraction is per FishId (= per form), but optimized players reduce this variation

**Architecture insight:** form ratios can be estimated from pond config without running FishSelector — just read layer assignments and `MapModifier` values. This is a separate capability from weight simulation but can be combined: `overall = Σ(p_form × dist_form)`.

**Decision:** added as separate backlog item in module backlog. Weight simulator (FP-41845) should be designed to accept external form proportions, making integration trivial later.

## 2026-03-10: weightK bug confirmed via SVN diff (rev 12950)

SVN diff of rev 12950 (FP-33182) confirms the weightK regression:
- **Before:** `weight = lerp(min, max, norm) * weightK` — single clean application to final weight. Weight could exceed form bounds (extrapolation). Consistent behavior for all fish.
- **After:** `norm *= weightK` (distorts distribution input) + `changedWeight = weight * weightK` (only used for form crossover). Within-form fish get `weight` WITHOUT weightK (line 122). Double application with inconsistent return.

The correct refactoring would have been: `weight = GetPossibleNormalFloat(norm, ...) * weightK` — add normal distribution without touching the weightK application point.

## 2026-03-11: WebAdmin simulator built — Option B confirmed (FP-41845 phase 1.3)

**Decision:** WebAdmin integration (Option B) chosen for the simulator. WebAdmin already references BiteSystem assembly — `FishDescription.GenerateRandomWeight()` is directly accessible. No server-side endpoint needed.

**Architecture decisions:**
- **Actual-form bucketing:** All accumulators (histogram counts, top-N weights, TotalGenerated) keyed by `randomWeight.Form` (post-crossover form), not original generation form. This matches FishFact production recording — when comparing simulator output to prod data, forms align 1:1.
- **Deterministic seed:** `new Random(42)` for reproducibility. Same inputs = identical output. Enables reliable comparison and debugging.
- **No code copying:** Service calls real `FishDescription.GenerateRandomWeight()` — no re-implementation of polynomials, Marsaglia, thresholds. Simulator always reflects production code.
- **InvariantCulture for all float I/O:** ASP.NET MVC `FormValueProvider` uses `CurrentCulture` (ru-RU = comma decimal). JS sends dot-formatted values. Manual parsing via `float.TryParse(..., InvariantCulture)` at controller level. Razor rendering also uses InvariantCulture.
- **Top-N via lazy sort-and-trim:** Accumulate up to 2×topN entries, sort+trim when threshold hit. O(N) amortized per form, avoids full heap for 1M+ iterations.
- **Iterations cap:** 20M max server-side to prevent accidental DoS on admin server.

**Lesson learned:** Kendo UI 2013.2.918 does not support `style: "smooth"` for area charts (added in 2013.3.1119). Also, Kendo 2013 `dataItem` doesn't preserve custom fields when using `field`/`categoryField` mapping — workaround: external lookup map for tooltip data.

## 2026-03-11: Weight simulator deployed and validated by stakeholders (FP-41845)

Simulator deployed to WebAdmin. Game designers and analysts confirmed it works correctly for their use cases. Tool is now available for Phase 1.4 (production data comparison) and ongoing parameter tuning work.

## 2026-03-11: Simulator validated against production data (FP-41845 phase 1.4)

Quantitative comparison of simulator output vs production FishFact histograms for **Nile Perch @ Congo River**.

**Setup:**
- Fish: Nile Perch @ Congo River (PondId=250)
- Shared params: weightK=1.0, threshold=0.95, sigma=0.55, step=1.0 kg (same on prod and in simulator)
- Comparison metric: per-bucket percentage of form total (normalizes different sample sizes)

**Raw data:**

|              | Production                                                                                                                                                     | Simulation                                                                                                                                                                                                       |
|--------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| File         | [FishStats-congo-nile-perch-2026-01-01-2months.tsv](../../../tasks/FP-41845--weight-generation-v2/artifacts/FishStats-congo-nile-perch-2026-01-01-2months.tsv) | [WeightSim_NilePerch_AF_CD_CongoRiver_N1000000_wK1_t0.95_s0.55_step1.00.tsv](../../../tasks/FP-41845--weight-generation-v2/artifacts/WeightSim_NilePerch_AF_CD_CongoRiver_N1000000_wK1_t0.95_s0.55_step1.00.tsv) |
| Description  | FishFact histogram, Source='B'                                                                                                                                 | Simulator output, N=1M/form                                                                                                                                                                                      |
| Period/Date  | 2026-01-01 → 2026-03-01                                                                                                                                        | 2026-03-11, r15909                                                                                                                                                                                               |
| Total sample | 1,887,028 (Y=947,776 C=524,745 T=238,135 U=176,372)                                                                                                            | 4,000,000 (1M × 4 forms)                                                                                                                                                                                         |

### Per-form deviation summary

| Form   | Buckets | Prod sample | Max dev.  | Mean abs. dev. | Verdict |
|--------|---------|-------------|-----------|----------------|---------|
| Young  | 26      | 947,776     | 0.109pp   | 0.030pp        | Match   |
| Common | 41      | 524,745     | 0.078pp   | 0.023pp        | Match   |
| Trophy | 50      | 238,135     | 0.085pp   | 0.023pp        | Match   |
| Unique | 75      | 176,372     | 0.133pp   | 0.020pp        | Match   |

Maximum deviation across all forms: **0.133pp** (Unique, bucket 186 kg). This is consistent with statistical sampling noise — Unique has the smallest production sample (176K vs 1M in simulator).

### Top-5 deviations per form

**Young** (range 15–40 kg, right-skewed hyperbola + 95% spike):

| Bucket | Prod %  | Sim %   | Δ        |
|--------|---------|---------|----------|
| 38 kg  | 12.611% | 12.720% | +0.109pp |
| 19 kg  |  2.266% |  2.202% | +0.064pp |
| 37 kg  |  6.315% |  6.374% | +0.058pp |
| 24 kg  |  2.552% |  2.600% | +0.048pp |
| 15 kg  |  1.909% |  1.864% | +0.045pp |

**Common** (range 40–80 kg, flat rectangle + 95% spike):

| Bucket | Prod %  | Sim %   | Δ        |
|--------|---------|---------|----------|
| 60 kg  |  2.549% |  2.471% | +0.078pp |
| 71 kg  |  2.479% |  2.534% | +0.055pp |
| 58 kg  |  2.539% |  2.488% | +0.051pp |
| 72 kg  |  2.494% |  2.540% | +0.046pp |
| 43 kg  |  2.489% |  2.530% | +0.041pp |

**Trophy** (range 80–130 kg, flat rectangle + 95% spike):

| Bucket  | Prod %  | Sim %   | Δ        |
|---------|---------|---------|----------|
| 100 kg  |  1.939% |  2.024% | +0.085pp |
|  89 kg  |  2.057% |  1.973% | +0.084pp |
| 114 kg  |  1.954% |  2.014% | +0.060pp |
|  81 kg  |  2.035% |  1.980% | +0.055pp |
| 102 kg  |  1.955% |  2.003% | +0.049pp |

**Unique** (range 130–205 kg, double-hump):

| Bucket  | Prod %   | Sim %    | Δ        |
|---------|----------|----------|----------|
| 186 kg  |  4.445%  |  4.579%  | +0.133pp |
| 165 kg  | 10.326%  | 10.425%  | +0.099pp |
| 169 kg  |  3.035%  |  2.943%  | +0.092pp |
| 180 kg  |  2.592%  |  2.535%  | +0.057pp |
| 130 kg  |  1.013%  |  1.064%  | +0.052pp |

### 95% threshold spike analysis

The characteristic spike at 95% of each form's weight range — the main algorithm artifact — matches with high precision:

| Form   | Spike bucket | Flat avg (prod) | Spike (prod) | Spike ratio (prod) | Spike ratio (sim) |
|--------|--------------|-----------------|--------------|--------------------|-------------------|
| Young  | 38 kg        | 29,368          | 119,521      | 4.07x              | 4.11x             |
| Common | 78 kg        | 13,115          | 17,816       | 1.36x              | 1.37x             |
| Trophy | 127 kg       | 4,754           | 6,071        | 1.28x              | 1.29x             |

Spike ratios match within 0.01–0.04x. The spike decreasing from Young (4x) through Common (1.4x) to Trophy (1.3x) is expected: Young polynomial inflates norms toward 1.0, concentrating more fish near the threshold; Common/Trophy identity polynomials produce a proportionally smaller spike.

### Unique double-hump analysis

The non-monotonic Unique polynomial creates a bimodal distribution. Both peaks and the valley between them match:

| Feature              | Prod   | Sim    | Δ       |
|----------------------|--------|--------|---------|
| Peak 1 (165 kg)      | 10.33% | 10.43% | 0.099pp |
| Peak 2 (187 kg)      | 8.28%  | 8.27%  | 0.012pp |
| Valley (174–177 avg) | 2.41%  | 2.43%  | 0.014pp |

Peak 1 > Peak 2 in both datasets. The valley at 174–177 kg corresponds to the polynomial's dip at normalized x ≈ 0.6–0.65.

### Boundary crossover accounting

Production FishFact records fish by **original form** (FishId assigned at generation). The simulator buckets by **actual form** (post-crossover). At weightK=1.0, crossovers are rare — only at exact form boundaries:

| Bucket | Production              | Simulator                         |
|--------|-------------------------|-----------------------------------|
| 40 kg  | Young=21, Common=13,267 | Common=25,058 (21 Young absorbed) |
| 80 kg  | Common=2, Trophy=4,802  | Trophy=20,172 (2 Common absorbed) |

Total crossover fish: 23 out of ~1.9M (0.001%). Negligible — does not affect shape comparison.

**Note:** at weightK > 1.0 (chum), crossovers become significant and this accounting difference matters more. For chum validation, the production SQL query would need to group by weight range rather than FishId to match simulator bucketing.

### Conclusion

**The simulator faithfully reproduces production weight generation.** All four distribution shapes — Young hyperbola, Common/Trophy rectangles, Unique double-hump — match within statistical noise. The 95% threshold spikes match in position, magnitude, and relative scaling across forms. `Random(42)` deterministic seed introduces no measurable bias vs production Marsaglia polar method.

**Decision:** Phase 1.4 validated. Simulator is a reliable tool for algorithm analysis and design work in Phase 2.

## 2026-03-12: FP-33182 threshold/Marsaglia reverted (FP-41845 phase 2a.1)

**Decision:** Reverted r12950 changes in `GenerateRandomWeight()`. Restored pre-FP-33182 uniform generation as clean baseline before implementing new decay algorithm.

**What was removed:**
- `NormalDistribution.GetPossibleNormalFloat()` call — threshold-based re-roll to Marsaglia normal distribution
- Double weightK application (`norm *= weightK` + `changedWeight = weight * weightK`)

**What was restored:** `weight = lerp(MinWeight, MaxWeight, norm) * weightK` — single clean weightK application.

**What was kept:** Method signature with `normalPercentageFrom` and `normalDistributionSigma` params (unused, will be repurposed for decay). Polynomials retained for now (removal is a separate step). `NormalDistribution.cs` untouched — methods remain available.

**Rationale:** New decay algorithm (Phase 2a.3) replaces the threshold/Marsaglia approach entirely. Starting from clean uniform baseline avoids layering new logic on top of known-buggy code.

## 2026-03-12: Decay algorithm design — normal-first approach rejected (FP-41845 phase 2a)

**Context:** Three candidate approaches for smooth weight decay in the `[threshold%, 100%]` zone:
1. **Normal-first** (generate normal, keep if > threshold, re-roll uniform otherwise)
2. **Power-law decay** (`p(x) = ((1-x)/(1-threshold))^α`)
3. **Exponential decay** (`p(x) = exp(-λ(x-threshold)/(1-threshold))`)

**Decision:** Normal-first rejected. Power-law and exponential both advance to implementation (2a.3) with a GlobalVariable switch.

**Rationale:** Normal-first has a fundamental discontinuity at the threshold seam. The flat uniform zone has density `Φ(threshold)/threshold`, while the normal tail starts at `φ(threshold)`. These values are coupled — making the seam smooth requires high tail probability (~39%), which contradicts the goal of making tail fish rare (~5%). Power-law and exponential are seamless by construction (`p(threshold) = 1`), have single intuitive tuning parameters, and support closed-form sampling (no rejection).

**Analysis artifact:** [decay-comparison.html](../../../tasks/FP-41845--weight-generation-v2/artifacts/decay-comparison.html) — interactive comparison with sliders, PDF plots, and simulated histograms.

## 2026-03-14: Edge distribution system design finalized (FP-41845 phase 2a design)

**Decisions:**
- **Naming: "Edge Distribution"** — replaces "decay"/"tail". "Edge" is directionally neutral (works for upper and lower), doesn't imply specific math (unlike "decay" → exponential). Types: `IEdgeDistributionStrategy`, `EdgeDistribution`, `EdgeDistributionScope`, `CapAtThreshold`, `Unrestricted`, `PowerLawEdge`, `ExponentialEdge`.
- **Zone fraction replaces threshold** — external API uses fraction (0.05 = 5% of range). `threshold = 1.0 - zoneFraction` computed internally. Zone fraction works identically from either edge; threshold was one-sided and added `1-threshold` clutter to every formula.
- **`[Flags]` EdgeDistributionScope** — bit matrix: form (Heaviest/Lightest/Others) × edge (Upper/Lower) = 6 bits. Named presets (Heaviest, Extremes, All). `Enum.TryParse` handles comma-separated custom combos. Eliminates special-case logic — `HasFlag()` replaces cascading `if/switch`.
- **Callback config pattern** — `FishWeightGeneratorConfig.UpdateFromGlobalVariables()` assembles config inside BiteSystem assembly, called from `GlobalVariablesCache.UpdateStaticVariables()` as one-liner. Enables `internal set` on `Config.Current` (writer and config in same assembly). Fixes architectural smell where SharedLib reached into subsystem internals.
- **Fail-safe defaults** — Algorithm=None (CapAtThreshold), Scope=All, both zones=0.05. Maximally restrictive: no fish can reach extreme weights until GD explicitly configures.

**Design artifacts:** [edge-distribution-design.md](../../../tasks/FP-41845--weight-generation-v2/artifacts/edge-distribution-design.md), [edge-distribution-impl-plan.md](../../../tasks/FP-41845--weight-generation-v2/artifacts/edge-distribution-impl-plan.md).

## 2026-03-19: Simulator bucketing rewritten in decimal arithmetic (FP-41845 polishing)

**Problem:** float arithmetic in bucket index computation (`(int)((weight - globalMin) / step)`) caused systematic off-by-one errors at gram resolution. `0.065f - 0.060f = 0.004999...`, `/0.001f = 4.999`, `(int) = 4` — fish at 65g placed in 64g bucket. Pattern: every ~3-4th gram value empty, neighbors doubled.

**Decision:** All bucketing arithmetic (index computation, bucket count, bucket labels) uses `decimal`. Float grid parameters cleaned via `Math.Round((decimal)floatValue, 6)` before entering decimal pipeline. Weight rounded to grams via shared `FishWeightRounding.Round()` (matching production `RoundTo3rdDigit`).

**Rationale:** Epsilon-based float compensation (adding 1e-6 before truncation) was considered and rejected — it masks the root cause and can fail for different value ranges. Decimal arithmetic eliminates the problem entirely. Performance impact: negligible (single decimal division per iteration in a ~2s simulation).

**Shared rounding constants:** `FishWeightRounding.DecimalPlaces=3`, `FishWeightRounding.Mode=AwayFromZero` — used by both `FishGenerator` (production) and `FishWeightSimulationService`. If rounding changes, both sites update together.

**Lesson learned:** Production stores fish weights as `decimal` and never does float÷float for bucketing. The simulator must use the same numeric type for index math to avoid distribution artifacts invisible in production.

## FP-33182: Fish generation improvements
- Full task journal: [FP-33182--weight-generation](../../../tasks/FP-33182--weight-generation/journal.md)
- ~~System on production (LBM20251201): hybrid uniform/Marsaglia distribution in BiteSystem path~~ — reverted in FP-41845 phase 2a.1
- Mathematical model errors identified → FP-41845 in progress
