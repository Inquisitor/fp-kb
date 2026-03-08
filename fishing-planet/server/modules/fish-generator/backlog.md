# Fish Generator — Backlog

## Investigation Items
- [ ] `SetFishToGenerate(PondScriptedFish)` ignores `fish.Bias` — uses `NextLinearDecimal()` + `GetMinMaxValue()` instead of `RandomizeFishWeight()`. Intentional or bug?
- [ ] `TutorialSource = "T"` constant exists but appears unused in generation paths — was it deprecated?

## Test Coverage Items (ref: [test-coverage.md](test-coverage.md))

Priority 1 — core weight pipeline:
- [ ] `GameUtils.RandomizeFishWeight()` — 3 bias modes (Min/Max/No), min==max, boundary cases
- [ ] `GameUtils.GetMinMaxValue()` — mod=0 (→min), mod=1 (→max), mod>1 (→>max), validation exceptions

Priority 2 — randomization statistical properties:
- [ ] `NormalRandom.NextFullNormal()` — range [-1,1], mean ~0, distribution shape
- [ ] `NormalRandom.NextHalfNormal()` — range [0,1], bias toward 0
- [ ] `NormalRandom.NextNormal()` — range [0,1], mean ~0.5
- [ ] `NormalRandom.NextSign()` — +-1 with ~50/50

Priority 3 — hooking formula:
- [ ] `Hooker` peak correctness: HookSize==IdealHookSize → probability ~1.0
- [ ] `Hooker` piecewise continuity at LowDrop/HighDrop boundaries
- [ ] `Hooker` negative probability guard (or prove it can't happen)
- [ ] `Hooker` multiple IdealHookSize values including <10 and >=10 (PeakCorrection branch)

Priority 4 — BiteSystem distribution:
- [ ] `NormalDistribution` — add real assertions to existing tests (currently zero)
- [ ] `NormalDistribution.GetNextFloat()` — not tested at all
- [ ] `NormalDistribution.GetAbsMarsaglia()` — not tested at all

Priority 5 — FishGenerator paths (requires more setup):
- [ ] `GenerateFishTemplate()` end-to-end per source type
- [ ] `SetFishToGenerate(PondScriptedFish)` — verify bias handling (see Investigation Items)
- [ ] `GenerateHookingFor*()` — three hooking variants
- [ ] `GenerateEscape()`, `GenerateCatch()`

Deferred — low risk:
- [ ] `FishTemplate.WeightedQuantity` stale cache behavior
- [ ] `FishTemplate.FishColorAttraction` LINQ matching
- [ ] `NormalRandom.RandomElement<T>()` — both overloads

## Documentation Items
- [ ] Document hooking probability curve in detail (`Hooker` class piecewise formula)
- [ ] Document bite time generation (`GetBiteTime()`, `GetAttackDelay()`)
- [x] Document BiteSystem integration (BiteEditor.ObjectModel.Pond → weight generation pipeline) → [normal-distribution.md](normal-distribution.md)
- [ ] Document `FishValueModulator` — modulates XP and club points via Force (derived from weight)
- [ ] Document `LicenseModel` weight range merging — licenses intersect MinWeight/MaxWeight ranges for legal catches
- [ ] Document WebAdmin `FishWeightDistribution()` analytics in `StatsController`
