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

## Confluence Research — BiteSystem & Chum Design Documents
- [ ] Study and cross-reference with code: [Алгоритм и формулы новой системы клева](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/923500587) (Mary Key, Jun 2024) — bite probability formulas (two dice rolls), chum calculation, attractors/detractors, particle weight modifier (WeightK origin), form polynomial curves, global constants. **Most current doc.**
- [ ] Study and cross-reference with code: [Детальное описание новой системы клева](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/424116241) (Mary Key, Nov 2018) — original design doc replacing FishBox with density maps. JSON formats for FishMaps, Attractors, AttractorGroups, Chum system (ingredients/recipes/ready chum), map types (QM, HM, FM, DM, BSM)
- [ ] Study and cross-reference with code: [Новая система клева](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/361496584) (Dmytro Lukash, Mar 2021) — high-level architecture, dynamic probability maps, map operations, chum ingredients/recipes format, formula stubs
- [ ] After studying all three: produce a "design vs reality" summary — what was implemented, what was changed, what was dropped

## Form Ratio Estimation
Goal: give game designers a tool to predict Y:C:T:U proportions from pond configuration, without waiting for production statistics. See [fish-selector-form-ratio.md](fish-selector-form-ratio.md) for preliminary findings.
- [ ] Extract layer assignments per form from pond config (`*_settings.srv`) for reference fish (Nile Perch, Northern Pike)
- [ ] Compare layer `MapModifier` values across forms — verify that layer assignment is indeed the primary ratio driver
- [ ] Prototype config-based ratio estimation: load pond → compute per-form probability weights at representative position(s)
- [ ] Validate estimated ratios against production FishFact proportions (ref data in deep dive)
- [ ] Investigate spatial averaging: can we compute map-wide average probability per layer (not just single point)?
- [ ] Integrate with weight simulator: combine estimated proportions with per-form weight distributions → overall histogram
- [ ] Two-mode UI: predicted (from config) vs actual (from FishFact) — show both on the same chart

## Documentation Items
- [ ] Document hooking probability curve in detail (`Hooker` class piecewise formula)
- [ ] Document bite time generation (`GetBiteTime()`, `GetAttackDelay()`)
- [x] Document BiteSystem integration (BiteEditor.ObjectModel.Pond → weight generation pipeline) → [normal-distribution.md](normal-distribution.md)
- [ ] Document `FishValueModulator` — modulates XP and club points via Force (derived from weight)
- [ ] Document `LicenseModel` weight range merging — licenses intersect MinWeight/MaxWeight ranges for legal catches
- [ ] Document WebAdmin `FishWeightDistribution()` analytics in `StatsController`

## WebAdmin Weight Simulator — UI polish

- [ ] Revisit Kendo DropDownList normalization for `EdgeDistributionScope` — current `scope === "YoungAndHeaviest"` explicit check in `onScopeChange()` JS is a hack (Kendo doesn't handle commas in option values). Workaround chose enum normalization (`TryParse → ToString()`) in ViewModel/Controller; preferred local approach is pipe/slash separator conversion (`, ` ↔ `|`) contained within the cshtml view layer. Also eliminate the explicit preset name check in `onScopeChange()`. Defer to flexible-checkbox-matrix iteration for edge scope.
