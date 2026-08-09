# Peer state ownership, disconnect path and client login flow — as-is

Snapshot taken 2026-08-10 against server branch `MFT20260325` (Content role) and client
`Win64_CodeBranch` (Code role). Line references are a dated snapshot and will drift.

**Verification status:** the file/method-level structure below was produced by delegated code
reconnaissance across the whole `GameClientPeer` partial family, the disconnect path and the client
login flow. Spot-checks re-read directly: the conditional save in `PreviewDisconnect`, the profile
event subscriptions in `LoadProfile`, the contents of `GameClientPeer_MultiRods.cs`, and the
application list in `PhotonServer.config`. Everything else is delegated output, not independently
re-read — treat as a map, not as verdicts.

---

## 1. What the peer owns

`GameClientPeer` spans 31 partial files (~22 700 lines) under
`Photon/src-server/Loadbalancing/LoadBalancing/GameServer/`, carrying on the order of a hundred
class-level fields.

**The coupling mechanism is typing, not size.** The peer implements seven domain interfaces
directly — `IClubPeer`, `IFishingTogetherPeer`, `ILeaguesPeer`, `IReelOfFortunePeer`,
`IDailyMissionPeer`, `IThirdPartyAdsPeer`, `IPushNotificationsPeer` (plus `IGenericPeer`,
`IProfilePeer`, `IFishRadarHost`). Seven subsystems therefore cannot be constructed without a live
peer. On top of that, roughly twenty external classes hold a `GameClientPeer` field — among them
`GameProcessor`, `MultiRodGameProcessor`, `AchievementManager`, `BoatManager`, `TargetedAdsManager`,
`AnalyticsAdapter`, `GameAuthenticator`, `SteamPaymentEngine`. Every such back-reference is a
reattach obstacle, because reconnect produces a *new* peer instance.

State groups:

| Group | Examples | Nature |
|---|---|---|
| Authoritative | `profile` (loaded once at login via `ProfileAdapter.GetProfile`), `biteSystemData` (lazy, separate DB call and separate save) | must move to the session |
| Login-time eager | `platformMapping`, analytics, anti-cheat (accumulates cheat rating in memory for the whole session), missions manager, chat channel controller, club/leagues/FT/fortune adapters | derived from profile + caches |
| Lazy per-peer adapters | achievements, targeted ads, offers, stats, bonuses, licences, leaderboards, radar, tablet map, UGC, third-party ads, farm reboots, daily missions, game session, daily activity, fish stats | each behind one lazy property; bounded, repeatable change |
| Live gameplay | `MultiRodGameProcessor` with its per-rod `GameProcessor` slots, `CurrentActorData`, `RoomReference` | torn down on every disconnect; FP-45122 territory |
| Transport-scoped | request/event/response sequence ids, ping data, TPM flags, `LastActivity`, `Disconnected`, execution fiber | correctly peer-owned, stays |

**Roughly a third of the class touches no peer-owned state at all** — `_Inventory`, `_Monetization`,
`_Shop`, `_Friendship`, `_NavBuoys`, `_Tops`, `_RateUs`, `_SkinElements`, `_PushNotifications` are
pure handlers over `Profile`. They need the profile plus a send/log capability, which is exactly the
surface a thin transport facade still offers.

**Synchronisation.** `transactionLock` is the dominant primitive, guarding profile and inventory
mutation across a dozen of the partial files, and it is handed out to `TargetedAdsManager` and
`UGCProcess` as their own lock. Wherever the profile moves, that lock moves with it, and those two
external consumers must be reconciled. Cross-fiber staging buffers already exist for club and
Fishing Together context, because room-fiber updates race the peer's own fiber.

Incidental: `GameClientPeer_Common.cs` is not a partial of the class at all despite the name — it is
a separate static helper.

## 2. Disconnect and what survives

Both endings converge on `PreviewDisconnect`: the client normally sends a `PreviewDisconnect`
operation, and if the socket simply dies, `DoDisconnect` calls the same method itself. So the
profile is saved on both paths — with one exception, see FP-45679: the save runs only if
`OnlineCacheAdaper.ValidateSession` still holds, and is skipped wholesale otherwise.

What is discarded: the whole live simulation object graph (`processor = null` after `Unload`), the
in-memory anti-cheat rating accumulated during the session, chat subscription state on a hard drop,
schedulers and timers. What survives is only database rows — the profile blob including
`PersistentData.RodState`, the bite-system blob, a room-population marker, an analytics session row.

**Existing resume mechanisms, in order of relevance:**

- **Fishing Together is the one real precedent.** `FishingTogetherAdapter.Leave` schedules a named
  action *on the `Room` object* (`room.ScheduleNamedAction`, 180 s by default), so it genuinely
  outlives the peer; a returning player cancels it and the log records "Reconnected to previously
  disconnected session". Its offline finish loads the profile from the DB with no live peer at all —
  a blocking call on the room fiber, which is the part not to copy.
- **`GameSessions` / `InitGameSession`** reopens a recently closed session row within a grace window
  (default 60 s). Analytics playtime continuity only, no game state — but structurally the closest
  thing to a reconnect token with a grace period.
- **Mongo `oc`** carries `{sessionId, UserId}` and nothing else: duplicate-login guard and session
  re-validation, never restoration.
- **`Profile.PersistentData.RodState`** is resume-by-replay from the database, not reattachment, and
  fish-fight restore is already known broken in practice.
- **`GameClientPeer_FarmReboots.cs`** is not a reconnect mechanism despite the name — it pushes
  scheduled-maintenance countdowns to the client.

## 3. What a reconnect costs today

Login is two-stage and loads the profile twice, because Master and Game are separate
`ApplicationBase` instances in their own AppDomains with no shared memory. `PhotonServer.config`
declares them under one `<Instance>` — `Master`, `GameServer1`, `GameServer2`, `Chat`, `Club`,
`CounterPublisher` — so several game applications can live in one process and still share nothing.

Master: token validation, `oc` logon (with a poll of up to 30 s for a stale record), session row
insert, full profile load, club init, offline purchase delivery, IP record. Game: token
re-validation, `DisconnectPeers` for the user, a **second** full profile load, club init **again**,
leagues context, reel of fortune, Fishing Together init, friends refresh, tournament refresh,
pending product delivery, analytics session init. On the order of ten to fifteen sequential
DB/Mongo round trips before the client can ask to enter a pond — the cost an in-memory reattach
avoids.

## 4. Blockers to keeping state alive

- Profile and peer are wired 1:1 — `LoadProfile` subscribes peer instance methods to profile events
  and never unsubscribes (FP-45680), and `GameProcessor` pushes results through `peer.SendEvent*`.
- Fiber affinity: each peer owns a `PoolFiber` and state is implicitly protected by "only the peer's
  fiber touches it", which stops being true the moment the peer goes and the state stays.
- `Actor.Peer` is a live reference in the Photon Lite layer with no detach/reattach API, and
  `LiteGame.RemovePeerFromGame` destroys the actor outright on disconnect.
- Duplicate login actively destroys the previous peer before the new one is authenticated.
- `GameCache.Instance` is a per-process static, and Master routes on room liveness only — there is
  no concept of "this instance holds a detached session for this user".

## 5. Client login flow

`PhotonServerConnection` holds a single `Peer` field that is **replaced** when the connection moves
from Master to Game, while the connection object itself is a singleton that survives the swap — so
the client already carries a loaded profile across a change of connection. `RequestProfile` checks
only `IsAuthenticated` and sends to whichever server is current: there is **no structural dependency
on Master**, only call order.

Most platforms do not request the profile separately at all — they piggyback it on `SetAddProps`
with a request flag, and the client re-tags the response as a `GetProfile` response. The same
piggyback already exists on the Game server and is never invoked there.

**No reconnect logic exists.** Every dropped connection — clean or not — leads to a "Connection Lost"
panel, then a full teardown (`CleanupStateAndLoadStartScene` → `StaticUserData.Reset` →
`PhotonConnectionFactory.Clear`) and the login flow starts from scratch with a fresh profile object.
The client does distinguish a voluntary quit from a drop (`IsQuitDisconnect`), but both converge on
the same teardown.

**No profile versioning exists** anywhere in the exchange — no revision, timestamp or checksum field
in the profile DTO or in the wire-protocol parameter codes, and the profile is never cached locally
between runs. A precedent for a freshness check does exist for *reference* data: `LocalDataCache`
serves ponds, fish, products and similar from local files keyed on one global server timestamp, and
is enabled on mobile only.
