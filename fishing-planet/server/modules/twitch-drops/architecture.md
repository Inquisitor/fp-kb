# Twitch Drops & Account Linking — Architecture

## What this is
Two halves over one table (`TwitchAccountLinks`, present in each platform stack's Main DB):

1. **Account linking** — a standalone web app (`TwitchAccountLinking`, .NET 8, containerized) where a signed-in platform user (Steam / PlayStation / Apple / Google(Android) / Epic / XBox / Nintendo) authorizes Twitch via OAuth; the app stores the Twitch identity + tokens.
2. **Drop delivery** — the Photon game server, on travel, reads the player's Twitch Drop entitlements with the stored token and delivers mapped in-game rewards.

Only **Time-Based Drops** are implemented (Confluence "Twitch integration"). Reward content/campaigns are configured in WebAdmin (`TwitchRewardLinks`) and on the Twitch Developer Console; that content work is outside this module.

## Process / DAL / client topology
| Process                                  | Framework | DAL                                                | Twitch HTTP                    |
|------------------------------------------|-----------|----------------------------------------------------|--------------------------------|
| Linking site `TwitchAccountLinking`      | net8.0    | `DalAdapter` (per-platform connection-string dict) | `Utils/TwitchApiClient`        |
| AsyncProcessor (`RefreshTwitchLinksJob`) | net472    | `SqlProfileProvider` (single conn)                 | `Shared/Twitch.TwitchApiUtils` |
| Photon (`TwitchManager.DeliverDrops`)    | net472    | `SqlProfileProvider` (single conn)                 | `Shared/Twitch.TwitchApiUtils` |
| WebAdmin (Player Card)                   | net472    | `SqlProfileProvider`                               | —                              |

Two structural facts shape any change here:

- **The DAL is split, and that is correct.** The site is one process talking to *N* platform DBs (it picks the DB by platform from a connection-string dictionary keyed `Steam`/`PlayStation`/…). Each game-server stack is *one* process talking to *its own* DB. Sharing the DAL would be worse than two small parallel methods.
- **The Twitch HTTP client is duplicated, and that is not.** `Shared/Twitch` targets net472 (via `FishingPlanet.props`), so the net8 site cannot reference it and carries its own `TwitchApiClient`. The two drift (only the site reads `email`; only the shared lib has `GetDropEntitlements`). FP-44590 removes the duplication by retargeting `Shared/Twitch` to netstandard2.0 and unifying the client (adding `GetUserInfo`).

## Linking flow (web app)
1. `AuthenticationController.SignIn` (POST) issues an ASP.NET `Challenge` to the chosen platform provider (Steam OpenID; PlayStation/Apple/Google/Epic/XBox/Nintendo OAuth — all wired in `Startup.ConfigureServices`, each enabled only if its config section is present).
2. After platform auth, `HomeController.Index` resolves the platform identity, looks up an existing link (`DalAdapter.GetLink`), and — if unlinked — stores a random `state` in session and builds the Twitch authorize URL with `scope=user:read:email` and `force_verify` (currently a bare flag, i.e. a no-op; FP-44591 fixes it to `force_verify=true`).
3. Twitch redirects to `HomeController.TwitchLoginResult`, which re-checks `state` (session), exchanges `code` for a token (`TwitchApiClient.GetToken`), fetches the Twitch user (`GetUser` → `/helix/users`), and persists the link (`DalAdapter.CreateLink`).

Platform identity mapping (`HomeController.GetAuthenticatedUser`): `User.Identity.AuthenticationType` → `SupportedPlatforms`; `ExternalId` from the `NameIdentifier` claim (Steam id parsed via `SteamApiUtils`); Apple uses the e-mail claim as display name.

## Token lifecycle
`CreateLink` stores the access token, refresh token, and both expirations. Tokens are kept fresh in two independent places:
- `RefreshTwitchLinksJob` (AsyncProcessor, daily 02:20) refreshes links whose refresh-token expires within 5 days; on `Invalid refresh token` it clears the token (`ClearTwitchTokenInfo`).
- `DeliverDrops` validates the token inline and refreshes it if invalid or within 10 min of expiry before use.

Because the server holds long-lived refresh tokens and already calls Twitch on the player's behalf, server-side data (e.g. a now-confirmed e-mail) can be re-fetched **without any user re-auth** — this is what makes background/at-delivery e-mail backfill possible.

## Delivery flow (`TwitchManager.DeliverDrops`, on travel)
Invoked from `GameClientPeer_Travel`. Steps:
1. **Platform gate** — `EnvironmentVariableCache.TwitchDropsSupportedPlatforms` (Win10 source is aliased to XBox; Nintendo/NX is unsupported, no rewards).
2. `GetTwitchUserLinkInfo(platform, externalId)`; bail if no link.
3. Validate / refresh the stored token.
4. `GetDropEntitlements(token)` — Twitch returns entitlements for the **identity behind the token** (TwitchId), paginated. **E-mail plays no role in delivery.**
5. For each `CLAIMED` entitlement: dedup via `CheckTwitchDropDelivered(entitlementId)`; map BenefitId→reward via `RewardsCache.GetTwitchReward` (mappings from `TwitchRewardLinks`); resolve loot-tables (`RewardManager.SelectSpecificReward`); deliver via `RewardManager.ProcessReward` (`BalanceMovementType.TwitchReward`); record `MarkTwitchDropDelivered`.
6. Batch `FulfillDropEntitlements` on Twitch for everything delivered or already-delivered.

Already-`FULFILLED` entitlements are skipped; `CLAIMED` ones not delivered in a pass stay claimable on Twitch and are picked up on a later travel — **deferring delivery never loses a drop.**

## No-email handling (design — FP-44591)
Twitch's `/helix/users` returns `email` only when `user:read:email` is granted **and** the e-mail is verified; otherwise it is absent. The `TwitchEmail` column is nullable. Capturing the verified e-mail is an explicit integration goal (Confluence; FP-28678), but delivery does not need it.

Product (Producer + Live-Ops + CS Lead) decided e-mail is **required for reward delivery**:
- **Never block linking on a missing e-mail** — store the link with a NULL e-mail (the crash fix; see [log](log.md)).
- **Capture/backfill** the e-mail once confirmed, at three touchpoints sharing one `GetUserInfo` + `SetTwitchEmail`: the linking page (`Index`, immediate feedback), `DeliverDrops` (self-healing — backfill, then deliver in the same pass), and a daily safety-net sweep (`BackfillTwitchEmailJob`, separate from the token-refresh job because the predicate and cadence differ).
- **Gate delivery** — `DeliverDrops` skips (before calling entitlements) and logs the non-delivery with a support-readable reason plus the token's granted scopes (from `ValidateToken`); CLAIMED drops persist for later.
- **Surfaces** — a warning panel on the linking page and a non-categorical mark on the WebAdmin Player Card. Neither asserts "unverified" as the sole cause: we can only state "no e-mail; likely unconfirmed" (Helix does not return `email_verified`; presence of the scope only lets us rule out "scope missing").

## OAuth / session reliability (FP-44592)
Two recurring failure classes in the linking site:
- OAuth callback failures (`code` missing / `Correlation failed` / anti-forgery invalid) bubble to HTTP 500 instead of a friendly page — fix via the handlers' `OnRemoteFailure` / `OnAccessDenied` events.
- DataProtection keys live **inside the container** (`/root/.aspnet/DataProtection-Keys`), so a redeploy/restart rotates them and invalidates every active session / correlation / anti-forgery cookie. Fix = persist keys outside the container (volume / DB / Redis); an interim rescue is to copy the current key XML onto a mounted volume before redeploy so the active key survives.

## Rate limits
Twitch Helix is a token-bucket: **800 points/min per `client_id`**, 1 point/request. Per-link backfill (one `GetUserInfo`) and per-travel delivery are far below the ceiling.
