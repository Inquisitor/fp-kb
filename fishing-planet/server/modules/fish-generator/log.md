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

## FP-33182: Fish generation improvements
- Full task journal: [FP-33182--weight-generation](../../tasks/FP-33182--weight-generation/journal.md)
- System on production (LBM20251201): hybrid uniform/Marsaglia distribution in BiteSystem path
- Mathematical model errors identified → FP-41845 in progress
