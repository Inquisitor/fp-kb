# Rewards — Module Log

## 2026-04-25 [LBM r15615..r15649] FP-41492 — narrow containment + cache validation prevention

**Decision:** wrap `RewardManager.ProcessReward` in try-catch only inside `GameClientPeer_Missions.cs`; rely on cache validation (Products/Items/Licenses/InnerProducts/Bundle) at startup as the prevention layer for the remaining 15 call sites.

**Rationale:** for Missions, swallowing the exception is safe — mission completion state is independent of reward delivery, and `ProcessReward` return value is unused (`announce: false, sendEvent: false`). For the other 15 sites, blanket try-catch would be incorrect — Tournaments (`MarkRewardReceived`), Leagues (`SaveProfileWithLog`), and `ProfileAdapter.ClaimReward` (`RemoveReward`) all have post-call state mutations that would fake successful delivery on swallowed exception, leading to data corruption (double-claim, profile desync, tournament re-collect).

**Lessons learned:**
- Reward delivery is non-transactional. Items/licenses/products/currency are granted sequentially without a journal or two-phase commit. A throw anywhere mid-delivery leaves partial state. The original FP-41492 decision item #3 ("транзакційність — видавати усю нагороду або нічого") was acknowledged but not realized.
- `MonetizationCache.GetProduct` throws on missing language entry or missing product (not null-return). `ProductDeliveryService.DeliverProduct` and `peer.RefreshLicenses` can throw on transient DB issues. Cache validation reduces likelihood at startup but does not eliminate runtime exception paths.
- Try-catch retrofit pattern depends on whether reward delivery is **independent** of the surrounding state mutation (Cat A — try-catch safe) or **load-bearing** for it (Cat B — needs transactional design instead). See [backlog.md](backlog.md) for the per-site categorization.

**Branch stamp:** `[LBM r15615..r15649]` — code resides on Code branch (MFT) via branch-copy inheritance from LBM:15942; no explicit merge needed.
