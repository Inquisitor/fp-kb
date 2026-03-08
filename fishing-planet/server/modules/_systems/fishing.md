# Fishing Gameplay — System Overview

> Cross-module data flow and ownership for the fishing session pipeline.
> WIP — expanded as modules are documented.

## Ownership

```
MultiRodGameProcessor (session-level, owns Pond from BiteSystem)
  └── GameProcessor[0..7] (per rod slot)
        ├── FishGenerator        → fish-generator module
        ├── FishTireModel        → fight stamina (not yet documented)
        ├── RodCaster            → casting physics (not yet documented)
        ├── WearSystem           → equipment durability
        ├── HitchGenerator       → snag mechanics
        ├── FishExperienceCalc   → XP calculation
        └── LicenseModel         → legal catch validation

BiteSystem (separate project: Shared/BiteSystem/, 41 files)
  ├── Pond                → data container (maps, fish groups, weather, attractors)
  ├── FishSelector        → probability carousel + Marsaglia selection
  ├── ChumSystem          → feeder attraction mechanics
  └── Detractions         → caught fish repel new catches
```

## Data Flow

```
Cast → Pond.OnThrown() resets FishSelector state
     → FishGenerator picks source:
         Priority: Debug → Event → Scripted → Predefined → FishBox
         BiteSystem: GenerateAttackForBiteSystem() → Pond.GetFish()
           → FishSelector builds carousel (map prob × chart × attractors − detractions)
           → Marsaglia normal decides "bite or not"
           → Weighted random selects species
           → BiteSystem internally generates weight (NormalDistribution/Marsaglia)
     → FishTemplate created (weight, IdealHookSize, source)
     → Hooker determines hook probability (piecewise curve)
     → Fight: FishTireModel tracks stamina, WearSystem damages gear
     → Catch: Pond.HandleCatchFish() creates detractor
     → Rewards: FishExperienceCalculator, LicenseModel validation
```

## Module Cards
- [fish-generator](../fish-generator/_card.md) — spawning, weight, hooking
- [bite-system](../bite-system/_card.md) — probabilistic selection (TODO: create card)

## Code Locations
| Component              | Project / Path                                              |
|------------------------|-------------------------------------------------------------|
| GameProcessor          | `Photon/src-server/Loadbalancing/LoadBalancing/GameLogic/`  |
| FishGenerator, Hooker  | `Photon/src-server/GameModel/`                              |
| BiteSystem             | `Shared/BiteSystem/`                                        |
| ObjectModel (fish)     | `Shared/ObjectModel/Fish/`                                  |
| SharedLib (ServerFish) | `Shared/SharedLib/Game/`                                    |
