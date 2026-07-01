# Rewards — Module Log

## 2026-04-25 [LBM r15615..r15649] FP-41492 — narrow containment + cache validation prevention

**Decision:** wrap `RewardManager.ProcessReward` in try-catch only inside `GameClientPeer_Missions.cs`; rely on cache validation (Products/Items/Licenses/InnerProducts/Bundle) at startup as the prevention layer for the remaining 15 call sites.

**Rationale:** for Missions, swallowing the exception is safe — mission completion state is independent of reward delivery, and `ProcessReward` return value is unused (`announce: false, sendEvent: false`). For the other 15 sites, blanket try-catch would be incorrect — Tournaments (`MarkRewardReceived`), Leagues (`SaveProfileWithLog`), and `ProfileAdapter.ClaimReward` (`RemoveReward`) all have post-call state mutations that would fake successful delivery on swallowed exception, leading to data corruption (double-claim, profile desync, tournament re-collect).

**Lessons learned:**
- Reward delivery is non-transactional. Items/licenses/products/currency are granted sequentially without a journal or two-phase commit. A throw anywhere mid-delivery leaves partial state. The original FP-41492 decision item #3 ("транзакційність — видавати усю нагороду або нічого") was acknowledged but not realized.
- `MonetizationCache.GetProduct` throws on missing language entry or missing product (not null-return). `ProductDeliveryService.DeliverProduct` and `peer.RefreshLicenses` can throw on transient DB issues. Cache validation reduces likelihood at startup but does not eliminate runtime exception paths.
- Try-catch retrofit pattern depends on whether reward delivery is **independent** of the surrounding state mutation (Cat A — try-catch safe) or **load-bearing** for it (Cat B — needs transactional design instead). See [backlog.md](backlog.md) for the per-site categorization.

**Branch stamp:** `[LBM r15615..r15649]` — code resides on Code branch (MFT) via branch-copy inheritance from LBM:15942; no explicit merge needed.

## 2026-06-30 [MFT20260325] FP-43009 — product reward platform resolution (Xbox GDK)

**Finding:** product-reward selection depends on platform agreement between two independently-derived values — the server's `peer.PlatformId` (from `profile.Source` at login, `GameClientPeer.LoadProfile`) and the client's `PlatformsManager.PlatformId` (from Unity build defines). On multi-platform installations (`XBox,Win10`, `Steam,Epic`) they must match: the server sends the catalog for `peer.PlatformId`, while the client filters `reward.Products` by `PlatformsManager.PlatformId` (`RewardsHelper.GetProductRewardForPlatform`). If they disagree, the client requests a product absent from its catalog cache and `ProductsCache.GetByID` fails, dropping the reward image. Surfaced on Xbox GDK builds (`UNITY_GAMECORE_XBOXONE`) that reported Win10 (4) instead of XBox (3); fixed client-side. Server reward pipeline unchanged.

**Finding:** `RewardUtils.LoadRewardViewData` -> `Brief()` populates `Reward.ProductsBrief` from **all** platforms present in `MonetizationCache`, with no per-platform filter. On multi-platform installs this ships sibling-platform product briefs to clients — harmless while clients filter by their own platform, but redundant payload and a latent foot-gun. Tracked in [backlog.md](backlog.md).

**Branch stamp:** `[MFT20260325]` — observation only, no server commit; relevant server code (`RewardUtils`, `RewardManager`) is identical on the Code branch.
