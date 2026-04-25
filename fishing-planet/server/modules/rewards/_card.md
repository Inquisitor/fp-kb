---
module: rewards
status: stub
---

# Rewards

> Reward delivery pipeline: select → validate → deliver (items, licenses, products, currency, exp). Called from 17 subsystems on completion events (missions, tournaments, leagues, achievements, daily bonus, RoF spin, third-party ads, twitch drops, promo codes, leveling, admin grants).

## Entry Points
- `RewardManager.ProcessReward()` — `Photon/src-server/Loadbalancing/LoadBalancing/GameLogic/RewardManager.cs` (main orchestrator: items → licenses → products → currency → exp → analytics)
- `RewardManager.SelectSpecificReward()` — same file (loot-table → concrete reward by RNG before processing)
- `RewardManager.ProcessProductRewards()` — same file (per-platform product delivery; throws on missing product)
- `RewardManager.GiveDeferredReward()` — same file (queue reward for later claim via `ProfileAdapter.ClaimReward`)
- `RewardUtils.ValidateRewards()` — `Shared/SharedLib/Rewards/RewardUtils.cs` (startup-time validation for items/licenses/products/loot-tables/platforms)

## Key Types
- `Reward` — `Shared/ObjectModel/Common/Reward.cs` (root: items, licenses, products, money, exp, loot-table config)
- `ProductReward` — products array on `Reward` with PlatformId/RegionId targeting
- `LicenseRef` — license id + term pair
- `ItemReward` — items array
- `LootTableConfig` — RNG-weighted alternatives; resolved via `SelectSpecificReward`

## Dependencies
→ `MonetizationCache` — product lookup + validation (throws `InvalidOperationException` on missing language/product)
→ `ItemCache` — item existence (filtered by `IsActive=1` at SQL view level)
→ `LicenseCache` — license existence and term mapping
→ `RewardsCache` — multilingual reward catalog, loot tables, twitch-related rewards, validation
→ `FortuneCache` — RoF cohorts/gold-day rewards (own validation)
→ `ProductDeliveryService` — actual product grant transaction
← 17 subsystems (see [call sites](call-sites.md) — TODO)

## Deep Dives
(none yet)

## Related Tasks
- FP-41492 (resolved 2025-12-31) — wrap Missions ProcessReward in try-catch + cache validation infra; narrow containment scope, design debt for other 15 sites filed in [backlog.md](backlog.md)
