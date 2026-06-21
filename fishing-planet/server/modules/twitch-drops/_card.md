---
module: twitch-drops
---

# Twitch Drops & Account Linking
> Players link a Twitch account to their platform/game account on a standalone web app; on travel the game server reads the player's Twitch Drop entitlements and delivers mapped in-game rewards. Spans 4 processes over the shared `TwitchAccountLinks` table.

## Entry Points
- **Linking site** (net8, `Twitch/TwitchAccountLinking/`): `AuthenticationController.SignIn` (platform `Challenge`) → `HomeController.Index` (status + builds Twitch authorize URL, scope `user:read:email`) → `HomeController.TwitchLoginResult` (OAuth callback → `DalAdapter.CreateLink`); Twitch calls via `Utils/TwitchApiClient`.
- **Delivery** (Photon): `TwitchManager.DeliverDrops` (`LoadBalancing/Monetization/`), called from `GameClientPeer_Travel` on travel.
- **Token refresh** (AsyncProcessor): `RefreshTwitchLinksJob` — daily 02:20, tokens expiring ≤5 days.
- **Shared client** (net472): `Twitch.TwitchApiUtils` (`Shared/Twitch/`) — `ValidateToken`/`RefreshToken`/`GetDropEntitlements`/`FulfillDropEntitlements`.

## Key Types
- `TwitchAccountLinks` (per-platform Main DB) — link row: Source/ExternalId, Twitch Id/LogIn/DisplayName/`TwitchEmail` (**nullable**), access+refresh tokens + expirations.
- `TwitchUserLinkInfoDto` (server read) · `DalAdapter.BindingInfo` (site read subset).
- `TwitchApiUtils.DropEntitlement` (Id, BenefitId, fulfillment Status) · `TwitchRewardLink` — BenefitId→reward map (`TwitchRewardLinks` table).

## Dependencies
→ DAL `IProfileProvider` — link CRUD + token (`GetTwitchUserLinkInfo`/`SetTwitchTokenInfo`/`ClearTwitchTokenInfo`/`GetTwitchLinksByRefreshExpiration`)
→ DAL `IMonetizationProvider` — `CheckTwitchDropDelivered`/`MarkTwitchDropDelivered` (dedup), `GetTwitchRewardMappings`
→ [rewards](../rewards/_card.md) — `RewardManager.ProcessReward` delivers the mapped drop (loot-tables via `SelectSpecificReward`)
→ `RewardsCache.GetTwitchReward` · `EnvironmentVariableCache.TwitchDropsSupportedPlatforms` (platform gate; Win10→XBox alias; NX unsupported)
← `GameClientPeer_Travel` (delivery) · AsyncProcessor (token refresh) · WebAdmin Player Card (display)

## Deep Dives
- [architecture.md](architecture.md) — link + delivery + token-lifecycle flows, cross-process/DAL/client topology, and the no-email design (capture / backfill / reward gate)
- Confluence: [Twitch integration](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/3206119457), [Twitch Drops Setup](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/3264872465)
- Tests: `Dal/Sql.MsSql.Tests/SqlMonetizationProviderTest.cs` (drop dedup) · `Shared/Twitch.Tests/TwitchApiUtilsTest.cs`

## Related Tasks
- **FP-44593** — epic "[Twitch] Integration maintenance" (umbrella). Children (planned): **FP-44590** unify client → netstandard2.0 · **FP-44591** no-email linking (capture/backfill + reward gate) · **FP-44592** OAuth errors + DataProtection keys · **FP-44597** DeliverDrops per-entitlement reward isolation (low)
- FP-34340 (closed) earlier link-exception fixes · FP-28678 (closed) persist Twitch e-mail · FP-21080 (closed) original integration

See also: [backlog](backlog.md) | [log](log.md)
