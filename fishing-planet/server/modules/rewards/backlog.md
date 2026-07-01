# Rewards — Backlog

## Design debt

- [ ] Transactional reward delivery — atomic all-or-nothing across items / licenses / products / currency. Needed for `GameClientPeer_Tournaments` (`MarkRewardReceived`), `GameClientPeer_Leagues` (`SaveProfileWithLog`), `ProfileAdapter.ClaimReward` (`RemoveReward`), and `GameClientPeer_Inventory.GiveReward` (admin) where current non-transactional behavior risks data corruption on partial throw (re-collect / desync / double-claim). Try-catch retrofit is NOT the right fix here. From FP-41492 review (out-of-scope, architectural); per-site rationale in [log.md](log.md) entry 2026-04-25. Promote to ticket when next reward incident surfaces or when broader monetization architecture is being scoped.

## Product brief payload

- [ ] `RewardUtils.LoadRewardViewData` -> `Brief()` builds `Reward.ProductsBrief` from **all** platforms present in `MonetizationCache`, unfiltered by player platform. On multi-platform installs (`XBox,Win10`, `Steam,Epic`) clients receive sibling-platform product briefs. Harmless while clients filter by their own platform (`RewardsHelper.GetProductRewardForPlatform`), but redundant payload and a latent foot-gun if a client stops filtering. Consider filtering `ProductsBrief` to the relevant platform(s). From FP-43009 diagnosis (origin: `tasks/FP-43009--xbox-achievement-reward-platform`).

## Logging parity

- [ ] "Subscription was not prolonged" log parity in the tracked delivery path. FP-43404 (r16056) added this message to the direct path (`ProductHelper.PutProductToProfileAndLog`) for a repeated single-DLC starter pack, but `TrackedProductDelivery` returns from its subscription-delivery method at the single-DLC guard BEFORE the `LogLicense` line, so the message is absent under `UseTrackedDelivery`. Prod runs direct today, so no live gap; add the parity log when tracked delivery is adopted so the "expected" message survives the switch. From FP-43404 review (F-3).
