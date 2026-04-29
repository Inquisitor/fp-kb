---
module: reel-of-fortune
status: stub
---

# Reel of Fortune

Daily mini-game with two wheels — regular (per-day allocation: regular + premium-tier + ad-bonus) and golden (per-day rotation, paid in gold). Per-profile state on `Profile.ReelOfFortuneState`. Feature gated by AB-test, level cohort, and country (gambling-restricted list).

## Entry Points
- `ReelOfFortuneAdapter` — `Shared/SharedLib/Fortune/ReelOfFortuneAdapter.cs` (orchestrator: subscribes to `Profile.ProductAdded` / `OnBalanceChange` / `SubscriptionEnded`; `PerformSpin` / `PerformGoldenSpin` / `CheckForDailyReel`)
- `ReelOfFortuneLogic` — `Shared/ObjectModel/Fortune/ReelOfFortuneLogic.cs` (extension methods on `ReelOfFortuneState`: `TryAddSpinsForPremium`, `InitAvailableSpins`, `PerformSpin`, `UpdateContext`, `MakeRandomChoice`)
- `MockReelOfFortunePeer` — `Shared/SharedLib/Fortune/MockReelOfFortunePeer.cs` (no-op peer for offline WebAdmin / tests)

## Key Types
- `ReelOfFortuneState` — per-profile state (`LastCheckTime`, `AvailableSpins`, `AvailableSpinsForPremium`, `GoldenSpinDayNumber`, `DayRewards`)
- `ReelOfFortuneContext` — client-facing snapshot pushed via `IReelOfFortunePeer.FlushContextChangesToClient`
- `ReelOfFortuneCohort` — level-banded reward set; selected by `Profile.Level`
- `ReelOfFortuneGoldDay` — golden-wheel daily rotation entries
- `IReelOfFortunePeer` — output interface

## Dependencies
→ `FortuneCache` — cohorts, gold-day rewards, golden-spin prices
→ `AbTestCache` — feature gating (`ReelOfFortuneAbTestId`, `ReelOfFortuneGoldAbTestId`)
→ `EnvironmentVariableCache` — `GamblingRestrictedCountries`, `DebugDailyReelOfFortuneOn`
→ `BalanceHelper` — golden-wheel spin payment
~ `Profile` — events: `ProductAdded`, `OnBalanceChange`, `SubscriptionEnded`
← Live `GameClientPeer` flow, `WebAdmin/Models/Tools/ToolsModel_Products` (offline-grant adapter init)

## Deep Dives
(none yet)

## Related Tasks
- FP-41507 (resolved 2026-04-29) — premium spin not unlocked after DLC with subscription; widened `Profile_ProductAdded` condition (`StarterKit && HasSubscription`) + adapter init in WebAdmin offline-grant path
