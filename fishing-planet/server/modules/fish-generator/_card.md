---
module: fish-generator
---

# Fish Generator
> Spawns fish, assigns weight via bias-aware randomization, determines hookability.

## Entry Points
- `FishGenerator` — `Photon/src-server/GameModel/FishGenerator.cs` (2200 LOC, core generation & hooking)
- `GameUtils.RandomizeFishWeight()` — `Photon/src-server/GameModel/Helpers/GameUtils.cs` (bias-aware weight)

## Key Types
- `FishTemplate` — generated fish instance (weight, IdealHookSize, source, box)
- `Hooker` — hooking probability curve (piecewise: low wing / peak / high wing)
- `NormalRandom` — Box-Muller RNG (linear, half-normal, full-normal distributions)
- `LocalFish` — fish form config (MinWeight, MaxWeight, Bias)
- `ServerFish` — fish species config (ForceWeight, HookSizeWeight, Status)

## Dependencies
→ BiteSystem: `GenerateAttackForBiteSystem()` calls `Pond.GetFish()`
→ ObjectModel: LocalFish, Fish, FishCarouselItem, FishWeightBias
→ SharedLib/Game: ServerFish, CurrentGameConfig, RodInGameConfig
← GameProcessor: owns FishGenerator, orchestrates fishing session
← MultiRodGameProcessor: multi-rod sessions

## Deep Dives
- [Weight generation](weight-generation.md) — algorithm, sources, downstream effects, lifecycle
- [Normal distribution](normal-distribution.md) — two implementations (NormalRandom vs NormalDistribution), parameters, form polynomials
- [FishFact statistics](fish-fact.md) — lifecycle table in Stats DB, schema, source codes, existing queries
- [Test coverage](test-coverage.md) — inventory of tests, gaps, potential code issues
- [FishSelector form ratio](fish-selector-form-ratio.md) — how Y:C:T:U proportions emerge from FishSelector config, estimation approach
- [Edge distribution](edge-distribution.md) — edge distribution approaches, normalization, correct sampling; design rationale for FP-41845

## Related Tasks
- FP-33182: Improve random fish weight generation (reopened, on prod) → [task journal](../../tasks/FP-33182--weight-generation/journal.md)
- FP-41845: Implement new system of weight generation (in progress) → [task journal](../../tasks/FP-41845--weight-generation-v2/journal.md)
  - Phase 1 complete: WebAdmin weight simulator built, deployed, validated vs production (all forms ≤0.13pp deviation)
  - Phase 2a design complete: edge distribution system (4 algorithms, [Flags] scope, zone fraction config) → [design](../../tasks/FP-41845--weight-generation-v2/artifacts/edge-distribution-design.md)

See also: [backlog](backlog.md) | [log](log.md)
