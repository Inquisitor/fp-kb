# Fish Weight Generation — Deep Dive

> Parent: [Fish Generator card](_card.md)

## Overview

Fish weight is determined at template generation time and stays constant through the entire fish lifecycle (attack → fight → catch). Weight affects: force, length, hook size, experience, cost, pulling force multiplier, and "huge fish" display.

## Weight Generation Algorithm

### Core function: `GameUtils.RandomizeFishWeight()` (GameUtils.cs)

```
Input:  minWeight, maxWeight (from LocalFish or FishCarouselItem), bias (FishWeightBias enum)
Output: decimal weight in [minWeight, maxWeight]
```

1. Generate random factor `sizeRnd` in [0, 1] based on bias:
   - `FishWeightBias.No` → `NextLinearDecimal()` — uniform distribution
   - `FishWeightBias.Min` → `NextHalfNormal()` — normal distribution biased toward 0 (lighter fish more likely)
   - `FishWeightBias.Max` → `1 - NextHalfNormal()` — normal distribution biased toward 1 (heavier fish more likely)
2. Interpolate: `weight = minWeight + (maxWeight - minWeight) * sizeRnd`

### Random distributions (NormalRandom.cs)

- `NextLinearDecimal()` / `NextLinearFloat()` — uniform [0,1] via `System.Random.NextDouble()`
- `NextHalfNormal()` — `|NextFullNormal()|`, range [0,1], peak at 0
- `NextFullNormal()` — Box-Muller transform: `sqrt(-2*ln(u1)) * sin(2*PI*u2) / 4`, range [-1,1], resamples if out of range

## Weight Sources by Generation Path

| Path                       | Method                                        | Weight Origin                                        | Randomization                               |
|----------------------------|-----------------------------------------------|------------------------------------------------------|---------------------------------------------|
| Debug fish                 | `GenerateFishTemplate()` — debug branch       | `DebugFishWeight` or LocalFish range                 | `RandomizeFishWeight()` if no debug weight  |
| Event fish                 | `GenerateFishTemplate()` — event branch       | `nextFishWeight` (pre-set via `SetFishToGenerate()`) | Already randomized at set time              |
| Scripted fish              | `GenerateScriptedFishTemplate()`              | ScriptedFish min/max range                           | `RandomizeFishWeight()` with fish bias      |
| Predefined (tutorial)      | `GenerateFishTemplate()` — predefined branch  | Hardcoded ranges (e.g. 0.35-0.4 kg)                  | `GetMinMaxValue()` with linear random       |
| Carousel (absolute/active) | `GenerateCarouselFishTemplate()`              | FishCarouselItem min/max                             | `RandomizeFishWeight()` with item bias      |
| FishBox (regular)          | `GenerateFishTemplate()` — box fish selection | LocalFish min/max from box condition                 | `RandomizeFishWeight()` with fish bias      |
| BiteSystem                 | `GenerateAttackForBiteSystem()`               | `biteSystemResult.Weight` (from BiteEditor)          | Weight comes pre-calculated from BiteSystem |

Note: Carousel is attempted as a *replacement* within the FishBox selection path (inside the per-template loop), not as a separate higher-priority source.

### Pre-generation via `SetFishToGenerate()`
- Called externally (events/scripts) to queue next fish
- `SetFishToGenerate(PondScriptedFish)` — randomizes weight with `GetMinMaxValue()` + linear random (ignores bias!)
- `SetFishToGenerate(int, decimal, float?, bool?)` — accepts exact weight, no randomization

## What Weight Affects

### Direct derivatives (calculated immediately)

| Property                 | Formula                                                   | Where Calculated                                                                                     |
|--------------------------|-----------------------------------------------------------|------------------------------------------------------------------------------------------------------|
| `IdealHookSize`          | `weight * ServerFish.HookSizeWeight`                      | `GeneratePredefinedFishTemplate()`, `GenerateFishTemplate()` — box fish branch                       |
| `Length`                 | `weight * LengthWeightMultiplier + LengthWeightConstant`  | `CreateAttackingFishInstance()`, `CreateFinalFishInstance()`                                         |
| `Force`                  | `weight * ServerFish.ForceWeight`                         | `CreateAttackingFishInstance()`, `CreateFightingFishInstance()`, `CreateFinalFishInstance()`         |
| `PullingForceMultiplier` | Interpolated via `ServerFish.GetPullingForceMultiplier()` | `CreateFightingFishInstance()` — uses **averaged** weight `(min+max)/2`, not actual generated weight |

### Indirect effects

| System                  | How Weight Affects It                                                                                                                                            |
|-------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Hooking probability** | `IdealHookSize` (from weight) vs actual `HookSize` → `Hooker.HookingProbability` — piecewise curve with peak at IdealHookSize, polynomial drop outside PeakWidth |
| **Fight mechanics**     | `Force` (from weight) determines fish pulling strength; `PullingForceMultiplier` scales it for heavy fish                                                        |
| **Experience**          | `FishExperienceCalculator` — `ExperienceWeight` × Force(=f(weight)) × pond/rod/trolling/club/league modifiers                                                    |
| **Silver/Gold rewards** | `GameProcessor` — weight × `SilverCostWeight`/`GoldCostWeight` × pond/trolling multipliers → `fish.SilverCost`/`fish.GoldCost`                                   |
| **Anti-cheat**          | `AntiCheatFishingManager` — landing net required based on `LandingNetMinWeight`/`MidWeight`/`MaxWeight` thresholds (GlobalVariablesCache)                        |
| **Tournaments**         | `TournamentAdapter` — scoring types (BiggestFish, TotalWeight, BestWeightMatch); min/max weight eligibility filtering                                            |
| **Leaderboards**        | `LeaderboardsAdapter` (LeaderboardsAdapter_Fish.cs) — weight is the primary sorting metric for fish leaderboards                                                 |
| **Personal records**    | `GameProcessor.CalculatePersonalRecord()` — compares caught fish weight against historical bests → `fish.IsPersonalRecord`                                       |
| **Huge fish display**   | `HugeFishShowStateMinLength` threshold checked against Length (derived from weight) → `fish.IsHugeFishDisplay`                                                   |
| **NoEscapeFishWeight**  | `GlobalVariablesCache.NoEscapeFishWeight` (default 0.906 kg) — fish below this weight skip line-slack escape check (easier to land)                              |
| **Auto-hook**           | `AutoHookModel` — weight bounds (0.5-1.5 kg) affect auto-hook modifier for bottom fishing                                                                        |
| **Fishing Together**    | Network params `TotalFishWeight`, `MaxFishWeight` sent to all players in multiplayer session                                                                     |
| **Daily missions**      | `PondFishWeightSettingsRow.AvgC/AvgT` define weight thresholds; `FishMeetsWeightCondition()` checks fish avg weight against mission range                        |
| **Bite time**           | NOT directly affected by weight — depends on `FishStatus` (Young/Common/Trophy/Unique)                                                                           |

## Fish Instance Lifecycle & Weight

```
GenerateFishTemplate()
  └─ FishTemplate.FishWeight = randomized weight (decimal)
      │
      ├─ CreateAttackingFishInstance(template, weight)
      │   └─ Fish { Weight = weight, Length = f(weight), Force = f(weight) }
      │
      ├─ CreateFightingFishInstance(template, genData, weight, hooked)
      │   └─ Fish { Weight = avg(min,max),
      │             Force = f(weight),
      │             PullingForceMultiplier = f(avg weight) }
      │
      └─ CreateFinalFishInstance(template, fish, weight)
          └─ Fish { Weight = weight, Length = f(weight), Force = f(weight),
                    IsYoung/IsTrophy/IsUnique flags, ExperienceData,
                    Weight/Length rounded to 3 decimal places }
```

### Important: Fighting instance weight discrepancy

`CreateFightingFishInstance()` sets `Weight = (genData.MinWeight + genData.MaxWeight) / 2` — this is the **average** of the range, NOT the actual generated weight. This is intentional: the fighting fish weight shown to the client is approximate (center of range), while:
- `Force` uses the actual generated weight (the `weight` parameter)
- `PullingForceMultiplier` uses the averaged `result.Weight` (same as what client sees)

The final catch instance (`CreateFinalFishInstance()`) gets the real weight.

For predefined/event/carousel fish, `genData.MinWeight == genData.MaxWeight == weight` (set in `GeneratePredefinedFishTemplate()` LocalFish construction), so there is no discrepancy.

## Debug Overrides

- `rodConfig.DebugFishId` — force specific fish species (>0 = exact ID, -1 = random from pond)
- `rodConfig.DebugFishWeight` — force exact weight (bypasses randomization)
- `rodConfig.DebugBiteTime` — force exact bite time
- `rodConfig.DebugNoFish` — suppress all fish generation
- `rodConfig.DebugImmediateFish` — force immediate attack (100% bite chance)
