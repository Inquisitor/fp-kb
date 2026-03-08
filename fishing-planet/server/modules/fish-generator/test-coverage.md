# Fish Generator — Test Coverage Review

> Parent: [Fish Generator card](_card.md)
> Date: 2026-03-07
> Status: initial review complete, backlog created

## Overview

Review of all existing tests covering fish generator components: randomization, weight generation, hooking, fish templates, and the generator itself.

**Key finding:** Most "test" files are data generators for manual visual analysis (`Console.WriteLine`, file output) with **zero assertions**. Actual automated coverage is minimal.

## Test Files Inventory

### NormalRandom (Box-Muller)

**File:** `Photon/src-server/Loadbalancing/LoadBalancing.Tests/NormalRandomTest.cs`

| Test Method                          | Status     | Assertions | What It Does                                          |
|--------------------------------------|------------|:----------:|-------------------------------------------------------|
| `GenerateNormalRandoms`              | `[Ignore]` | 0          | Writes 10k `NextFullNormal()` values to file          |
| `GenerateSemiNormalRandoms`          | `[Ignore]` | 0          | Writes 10k `NextHalfNormal()` values to file          |
| `GenerateLinearFloatRandoms`         | `[Ignore]` | 0          | Writes 10k `NextLinearFloat()` values to file         |
| `DifferentGeneratorsUseDifferentSeeds` | Active   | 1          | 1M iterations: two instances never produce same value |
| `NextDoubleTest`                     | Active     | 1          | 10k iterations: ~5% of values < 0.05                 |

**File:** `Photon/src-server/Loadbalancing/LoadBalancing.Tests/RandomTest.cs`

| Test Method                        | Status | Assertions | What It Does                                        |
|------------------------------------|--------|:----------:|-----------------------------------------------------|
| `RandomGenerationProbability`      | Active | ~1         | Basic `Random.Next()` distribution check             |
| `CheckRandomCustomNormalization`   | Active | ~1         | `NextLinearFloat(operation)` produces varied results |
| `RandomNormalizationForAttack`     | Active | ~1         | `NextLinearInt4Attack()` with various ranges         |

**Coverage gaps — NormalRandom:**
- `NextFullNormal()` — no assertion that output is in [-1,1], no mean/stddev check
- `NextHalfNormal()` — no assertion that output is in [0,1], no distribution shape check
- `NextNormal()` — no tests at all (range [0,1], mean ~0.5)
- `NextSign()` — no tests (should give -1/+1 with ~50/50)
- `NextLinearFloat(operation)` anti-repeat (minDiff=0.1) — only smoke-tested
- `RandomElement<T>()` — no tests for either overload

### NormalDistribution (Marsaglia, BiteSystem)

**File:** `Shared/SharedLib.Tests/NormalDistributionTest.cs`

| Test Method                        | Status | Assertions | What It Does                                                 |
|------------------------------------|--------|:----------:|--------------------------------------------------------------|
| `Comparison`                       | Active | **0**      | Compares uniform vs Marsaglia, prints stats to console       |
| `TestUniformDistribution`          | Active | **0**      | Prints uniform distribution stats (1.5-20 kg)                |
| `TestUniformOrNormalDistribution`  | Active | **0**      | Prints blended distribution stats (75%/95% normal threshold) |

**All three tests pass unconditionally** — they collect statistics and call `Console.WriteLine()` / `stats.Print()` without any `Assert.*` calls.

**Coverage gaps — NormalDistribution:**
- `GetUniformOrNormalFloat()` — exercised but never verified
- `GetNextFloat()` — not tested at all
- `GetAbsMarsaglia()` — public method, not tested
- `GetPossibleNormalFloat()` — threshold switching logic, not verified
- Boundary behavior (`minValue == maxValue`, `sigma = 0`) — not tested

### GameUtils — Weight Randomization

**No dedicated test file exists.**

| Method                | Tests | Notes                                            |
|-----------------------|:-----:|--------------------------------------------------|
| `RandomizeFishWeight` | 0     | Critical: 3 bias modes, core weight pipeline     |
| `GetMinMaxValue`      | 0     | Interpolation + lower-bound clamp, no upper clamp |
| `CheckCondition`      | 0     | FishBox time/weather evaluation                  |
| `WarmupBox`           | 0     | Cooldown recovery                                |
| `CooldownBox`         | 0     | Cooldown decrement                               |
| `BaseWeatherName`     | 0     | String parsing                                   |

**Notable:** `GetMinMaxValue` has lower-bound clamping (`if (result < min) return min`) but no upper-bound clamping — `mod > 1` produces values above `max`. This is by design (mod comes from [0,1] distributions) but worth documenting.

### Hooker — Hooking Probability

**File:** `Photon/src-server/Loadbalancing/LoadBalancing.Tests/GameLogicTests/FormulasTest.cs`

| Test Method                          | Status     | Assertions | What It Does                                       |
|--------------------------------------|------------|:----------:|-----------------------------------------------------|
| `CheckMinorHookingAttributeInfluence`| Active     | 1          | `HookingMultiplier` scales probability linearly     |
| `GenerateHookingChance`             | `[Ignore]` | 0          | Writes probability curve to file (hook sizes 5-99)  |

**Coverage gaps — Hooker:**
- Peak zone correctness: `HookSize == IdealHookSize` should give probability ~1.0
- Piecewise continuity at LowDrop/HighDrop boundaries
- `PeakCorrection` branch: `IdealHookSize < 10` vs `>= 10`
- Negative probability risk: peak formula `1 - 0.03*(IdealHookSize-HookSize)^2/PeakCorrection` can go negative for wide PeakWidth — no `Math.Max(0, ...)` guard
- Edge values: `HookSize = 0`, `HookingMultiplier = 0`, very large IdealHookSize
- Monotonic decrease in both wings

### FishTemplate

**No tests exist.**

- `WeightedQuantity` — lazy-cached (`if (weightedQuantity == 0)`): stale cache if fields mutate after first access; also re-computes when sum genuinely equals 0
- `FishColorAttraction` — LINQ matching, not tested

### FishGenerator

**File:** `Photon/src-server/GameModel.Tests/BiteTimeGenerationTest.cs`

| Test Method                          | Status     | Assertions | What It Tests                          |
|--------------------------------------|------------|:----------:|----------------------------------------|
| `BiteTimeCanBeGeneratedForYoungFish` | `[Ignore]` | 3          | `GetBiteTime()` — Young status         |
| `BiteTimeCanBeGeneratedForCommonFish`| `[Ignore]` | 3          | `GetBiteTime()` — Common status        |
| `BiteTimeCanBeGeneratedForUniqueFish`| `[Ignore]` | 3          | `GetBiteTime()` — Unique status        |
| `BiteTimeCanBeGeneratedForTrophyFish`| `[Ignore]` | 3          | `GetBiteTime()` — Trophy status        |
| `CreateFishBiteTemplateForClient`    | Active     | ~3         | Bite template variety (tastes, dirs)    |
| `CanSelectScriptedFish`             | Active     | ~2         | Scripted fish selection with chum spots |
| `CanSelectScriptedFishReturnNothing` | `[Ignore]` | ~1         | Selection returns null on time mismatch |

**File:** `Photon/src-server/Loadbalancing/LoadBalancing.Tests/GameLogicTests/GameLogicTest.cs`

Integration tests exercising FishGenerator through GameProcessor. Most are `[Ignore]`.

**Coverage gaps — FishGenerator:**
- `GenerateFishTemplate()` — main pipeline (Debug/Event/Scripted/Predefined/FishBox) — no isolated tests
- `GenerateCarouselFishTemplate()` — carousel path — no tests
- `GenerateAttackForBiteSystem()` — BiteSystem path — no tests
- `SetFishToGenerate()` — both overloads (one ignores bias — see backlog) — no tests
- `GenerateHookingForLure/Float/Bottom()` — no tests
- `GenerateEscape()` — no tests
- `GenerateCatch()` — final fish instance — no tests
- `RestoreFish()` — reconnection recovery — no tests
- Weight generation flow end-to-end — no tests

### Adjacent Tests (not directly fish-generator but related)

| File | Class | What It Tests |
|------|-------|---------------|
| `LoadBalancing.Tests/GameLogicTests/FishTireModelTest.cs` | `FishTireModelTest` | Fish stamina loss/recovery (2 active tests) |
| `LoadBalancing.Tests/GameLogicTests/FishTireModelSimulation.cs` | `FishTireModelSimulation` | Stamina simulation with real force sequences |
| `SharedLib.Tests/FishExperienceCalculatorTest.cs` | (if exists) | Experience from weight/force |
| `SharedLib.Tests/FishValueModulatorTest.cs` | (if exists) | XP/club point modulation |

## Summary

| Component                    | Active Tests | Ignored | Real Assertions | Rating       |
|------------------------------|:------------:|:-------:|:---------------:|:------------:|
| NormalRandom                 | 2            | 3       | 2               | Weak         |
| NormalDistribution           | 3            | 0       | **0**           | **None**     |
| GameUtils.RandomizeFishWeight| 0            | 0       | 0               | **None**     |
| GameUtils.GetMinMaxValue     | 0            | 0       | 0               | **None**     |
| Hooker                       | 1            | 1       | 1               | Minimal      |
| FishTemplate                 | 0            | 0       | 0               | **None**     |
| FishGenerator (bite time)    | 2            | 5       | ~5              | Weak         |
| FishGenerator (weight gen)   | 0            | 0       | 0               | **None**     |
| FishGenerator (hooking)      | 0            | 0       | 0               | **None**     |
| FishGenerator (escape/catch) | 0            | 0       | 0               | **None**     |

## Potential Code Issues Found

1. **`FishTemplate.WeightedQuantity` stale cache** — lazy-cached with `if (weightedQuantity == 0)` check. If `Quantity + BaitAttraction` changes after first access, cached value is stale. Also re-computes every time if sum genuinely equals 0.

2. **`Hooker.HookingProbablity` negative probability** — peak formula `1 - 0.03*(IdealHookSize-HookSize)^2/PeakCorrection` can theoretically go negative. No `Math.Max(0, ...)` guard. Needs verification with concrete IdealHookSize values.

3. **`GameUtils.GetMinMaxValue` no upper clamp** — `mod > 1` produces values above `max`. Safe because callers pass [0,1] distributions, but asymmetric with lower-bound clamp.

4. **`SetFishToGenerate(PondScriptedFish)` ignores bias** — uses `NextLinearDecimal()` + `GetMinMaxValue()` instead of `RandomizeFishWeight()`. Already tracked in backlog.