---
jira: FP-32370
status: planning
executor: Stanislav
branch: MFT
related: FP-44184 (completed — first PO unit tests + InternalsVisibleTo seam landed there, see its journal); no TargetedAds module card yet
---

## Status

Registered as active. Scope: cover the Personal Offers state machine with unit tests and refactor `TargetedAdsManager` so the offers logic is testable without a live `GameClientPeer`. A first seam already landed under FP-44184 (pure `SwitchPersonalOfferDesignByIndex` / `AlignPersonalOfferEndTime` exposed via `InternalsVisibleTo` + 4 timing tests) — a stopgap to be replaced by a real seam here. Refactor approach sketched below; implementation deferred ("потом как-то сделаем").

## Summary

**Goal (from JIRA).** Cover the offers state machine with tests; refactor `TargetedAdsManager` so the class is better testable.

**Why it is hard today.** `TargetedAdsManager` (partial class across `Photon/src-server/Loadbalancing/LoadBalancing/GameLogic/TargetedAdsManager*.cs`) is tightly coupled to runtime singletons, which blocks unit-testing the offers state machine:

- `GameClientPeer` — `peer.Profile` (TargetedAdsContext, products, level), `peer.PlatformMapping`, `peer.DebugUtility` for logging.
- Static caches — `TargetedAdsCache`, `GlobalVariablesCache`.
- Static clock — `DT.Helper.UtcNow`, read directly inside `UpdatePersonalOfferState` and all time-based transitions.
- Static `DalFactory` for logging / persistence.
- Condition evaluation — `CheckAdConditions` / `CheckAdAuditory` depend on the full profile.

The state machine (`UpdatePersonalOfferState`, `UpdatePersonalOffer`, cooldown / rerun / expiry transitions) is the high-value target and is currently unreachable from a unit test.

## Plan

**Down payment (done, FP-44184).** Pure helpers `SwitchPersonalOfferDesignByIndex` + `AlignPersonalOfferEndTime` made `internal static`, exposed via `LoadBalancing/Properties/AssemblyInternals.cs` (`InternalsVisibleTo("LoadBalancing.Tests")`), covered by `LoadBalancing.Tests/GameLogicTests/PersonalOfferDesignTimingTest.cs`. Treat `InternalsVisibleTo` as temporary — replace with a real seam.

**Refactor approach (sketch — to be decided):**

1. Extract a pure `PersonalOfferEngine` (or similar) owning the state-machine logic over `TargetedAdsContext` + config, with no `GameClientPeer` reference. The manager becomes a thin adapter wiring peer / caches / clock into the engine.
2. Inject a clock (`Func<DateTime>` / `ITimeProvider`) instead of reading `DT.Helper.UtcNow` directly, so time-based transitions are deterministic. Lead: `LoadBalancing.Tests/LocalTimeProvider.cs` already exists — check whether a clock seam is partly in place.
3. Abstract condition evaluation behind an interface (`IAdConditionEvaluator`) so tests feed pass / fail verdicts without building a full profile.
4. Once the engine is pure, drop the `InternalsVisibleTo` trickery and test the engine through its public surface.

**Target coverage (state machine):** Init -> Active; chain timeout expiry; element expiry -> ChainElementCooldown / ChainEndCooldown; cooldown / rerun gating; unlimited-chain expiry by condition loss; ChainPreserveTimeout hold; ExpiringByPurchase; InvalidatedByReset; Expired -> reactivation; AlignPersonalOfferEndTime clamping; sequential-transition guard. Detailed list in [backlog.md](backlog.md).

## Milestones

- 2026-06-03: Registered as active. First PO unit tests + testability seam landed under FP-44184. Refactor approach sketched; implementation deferred.
