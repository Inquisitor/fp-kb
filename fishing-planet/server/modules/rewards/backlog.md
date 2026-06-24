# Rewards — Backlog

## Design debt

- [ ] Transactional reward delivery — atomic all-or-nothing across items / licenses / products / currency. Needed for `GameClientPeer_Tournaments` (`MarkRewardReceived`), `GameClientPeer_Leagues` (`SaveProfileWithLog`), `ProfileAdapter.ClaimReward` (`RemoveReward`), and `GameClientPeer_Inventory.GiveReward` (admin) where current non-transactional behavior risks data corruption on partial throw (re-collect / desync / double-claim). Try-catch retrofit is NOT the right fix here. From FP-41492 review (out-of-scope, architectural); per-site rationale in [log.md](log.md) entry 2026-04-25. Promote to ticket when next reward incident surfaces or when broader monetization architecture is being scoped.

## Logging parity

- [ ] "Subscription was not prolonged" log parity in the tracked delivery path. FP-43404 (r16056) added this message to the direct path (`ProductHelper.PutProductToProfileAndLog`) for a repeated single-DLC starter pack, but `TrackedProductDelivery` returns from its subscription-delivery method at the single-DLC guard BEFORE the `LogLicense` line, so the message is absent under `UseTrackedDelivery`. Prod runs direct today, so no live gap; add the parity log when tracked delivery is adopted so the "expected" message survives the switch. From FP-43404 review (F-3).
