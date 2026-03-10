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

## 2026-03-10: Carousel disambiguation

Finding: "Carousel" refers to two unrelated mechanisms:

1. **FishSelector carousel** (`FishSelector._carousel`, BiteSystem) — the primary fish selection mechanism on production. Builds weighted probability wheel from bite maps → selects which fish generates → weight via `FishDescription.GenerateRandomWeight()`. Source=`B`.

2. **FishGenerator carousel** (`FishGenerator.GenerateCarouselFishTemplate()`) — legacy alternative within FishBox path. AbsoluteCarousel (Source=`A`) / ActiveCarousel (Source=`C`). Weight via `GameUtils.RandomizeFishWeight()`.

**Decision:** "Carousel" in project context means FishSelector carousel (BiteSystem) unless explicitly qualified. FishGenerator carousel is legacy, FishBox system is used only in missions. Updated glossary.

## FP-33182: Fish generation improvements
- Full task journal: [FP-33182--weight-generation](../../tasks/FP-33182--weight-generation/journal.md)
- System on production (LBM20251201): hybrid uniform/Marsaglia distribution in BiteSystem path
- Mathematical model errors identified → FP-41845 in progress
