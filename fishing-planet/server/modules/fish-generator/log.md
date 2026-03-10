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

## FP-33182: Fish generation improvements
- Full task journal: [FP-33182--weight-generation](../../tasks/FP-33182--weight-generation/journal.md)
- System on production (LBM20251201): hybrid uniform/Marsaglia distribution in BiteSystem path
- Mathematical model errors identified → FP-41845 in progress
