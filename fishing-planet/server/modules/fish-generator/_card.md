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
- [Test coverage](test-coverage.md) — inventory of tests, gaps, potential code issues

## Related Tasks
(none yet)

See also: [backlog](backlog.md) | [log](log.md)
