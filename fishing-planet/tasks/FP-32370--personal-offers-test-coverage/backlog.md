# FP-32370 backlog

## Refactor (testability)
- [ ] Decide seam: extract a pure `PersonalOfferEngine` vs constructor-inject dependencies behind interfaces
- [ ] Introduce an injectable clock; stop reading `DT.Helper.UtcNow` inside the state machine (check existing `LoadBalancing.Tests/LocalTimeProvider.cs`)
- [ ] Abstract `CheckAdConditions` / `CheckAdAuditory` behind an evaluator interface
- [ ] Replace the `InternalsVisibleTo` seam (from FP-44184) with the real one once the engine is pure
- [ ] Remove the dead `NumberOfPersonalOfferShowsPerDay` global (`GlobalVariablesCache`, no consumer, absent from GD design) — flagged as "not implemented" in the FP-44184 TDD edit

## State-machine test coverage
- [ ] Init -> Active transition
- [ ] Active: chain timeout expiry (ChainEndTime) and campaign-end clamp
- [ ] Active: design expiry -> ChainElementCooldown (mid-chain) and ChainEndCooldown (last design)
- [ ] ChainElementCooldown: ElementCooldownHours gating; advance to next design
- [ ] ChainEndCooldown: ChainRerunTimeoutHours gating; chain restart at design 0
- [ ] Unlimited chain: expiry on condition loss; ChainPreserveTimeoutHours hold
- [ ] ExpiringByPurchase, InvalidatedByReset transitions
- [ ] Expired -> reactivation after Timeout while campaign active
- [ ] MaxPersonalOfferStateSequentialTransitions infinite-loop guard
- [ ] ActivePersonalOffersLimitReached gating across states

## Notes
- Consider whether a `TargetedAds` / `PersonalOffers` module card is warranted once the refactor lands.
