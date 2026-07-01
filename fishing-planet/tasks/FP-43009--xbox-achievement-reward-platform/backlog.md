# Backlog — FP-43009

- [x] (bubbled up on close) `RewardUtils.LoadRewardViewData` -> `Brief()` builds `Reward.ProductsBrief` from **all** platforms present in `MonetizationCache`, not filtered to the player's platform. On multi-platform installations (`XBox,Win10` / `Steam,Epic`) this ships sibling-platform product briefs to clients. Harmless given correct client-side platform filtering, but dead weight in the payload and a latent foot-gun if a client ever stops filtering. Bubbled to `server/modules/rewards/backlog.md` -> "Product brief payload".
