# Leaderboards — log

## 2026-05-11
FP-43631 (matchmaking abuse detection) exercised the leaderboard ban + finalization path under live conditions. Findings about leaderboard mechanics captured here:

Finding: **`CompetitiveRatingsCurrent.IsBanned` is the ephemeral surgical ban hook**. Setting `IsBanned = 1` for `(PeriodTypeId, PeriodId, UserId)` causes `SaveCompetitiveLeaderboardHistory` to skip that row during the finalization MERGE (filter `WHERE [r].[IsBanned] = 0`). Result: the user gets no row in `CompetitiveRating*History`, no `RewardId` assignment, no `OfflineChatMessages` reward push. Verified empirically across STEAM/PS/Xbox for period 20260504: 29 banned users absent from winners' lists post-finalize, while clean top-10 received `RewardId 75066–75075` as expected.

Finding: **post-cleanup data loss for banned cohort**. The hourly job at `MM:07` UTC finalizes the period (MERGE to History) and the subsequent cleanup pass at `~MM:20` UTC DELETEs all rows for that period from `*RatingsCurrent`. Result: banned users vanish from both Current (deleted) and History (never inserted). Audit-trail for the ban operation lives outside the DB — must be kept externally (we used `bans-<date>.md`). Architectural note: if reproducible ban audit becomes a requirement, the candidates are (a) a dedicated `CompetitiveLeaderboardBans` history table populated at finalization, or (b) durable marking via `Users.IsBanned` / `Profiles.IsCompetitionsBanned` — the latter is too heavy for a per-period ban scoped only to reward exclusion.

Finding: **`UpdateLeaderboardsBanned` SP is NOT a substitute for direct UPDATE**. The SP computes the flag from `Users.IsBanned` (default 0 for normal accounts) plus `Profiles.Role NOT IN ('-', 'I', 'D')` then SETs `*RatingsCurrent.IsBanned` accordingly. Calling it for a normal account RESETS `IsBanned` to 0 — overriding any manual UPDATE. For surgical per-period leaderboard bans without account-level consequences, direct `UPDATE CompetitiveRatingsCurrent SET IsBanned = 1 WHERE ...` is the only correct path. Documented this caveat in the operational SQL artifact (`weekly-leaderboard-ban.sql` header).

## 2026-04-28
Module created during FP-41595 release-support investigation. Deep dive [Control variables](control-variables.md) added — durable runtime semantics for the 13 leaderboards env-var flags (1 master + 12 subsystem), push-to-static refresh mechanics via `EnvironmentVariableCache.UpdateStaticVariables`, and client mirror map.

Finding (open): client (`Assets/Photon Server Networking/PhotonServerConnection_LeaderBoards.cs`) declares 3 per-type `…UIOn` properties (`IsCompetitiveLeaderboardsUIOn`, `IsGlobalLeaderboardsUIOn`, `IsFishLeaderboardsUIOn`) but no client C# code reads them. Either reserved for future per-tab gating, or stale. Worth a clarifying ask to the LB feature team before LBM rollout — if they are stale the WebAdmin/QA bar for testing per-type UI toggles is currently lower than expected (effect is purely empty server response). Backlog item created.

Finding: `IsLeaderboardsOn` server-side gates only `TryRaiseLeaderboardsResetEvent`, not the data flows. Asymmetry is intentional — flipping the master to `N` blanks the client UI without disrupting in-flight period accounting. Documented in `control-variables.md` § Master flag.

## 2026-05-01
LBM rolled out and Leaderboards activated on all 5 prod streams (FP-41595). Architectural findings captured during launch:

Finding: **catch-up safety property** — when AsyncProcessor's per-type cursor (`Async.{Type}LeaderboardFinalizationTime`) is stale, the FinalizationJob walks day-by-day from cursor+1 to today, calling `FinalizeAndRestart{Type}Leaderboards(date)` for each day. Each walked day reads `*RatingsCurrent WHERE PeriodId = @past` → 0 rows (rotated/cleaned long ago) → 0 history rows written → `DistributeLeaderboardRewards` early-return with 0 messages. **No reward leak from stale cursor.** Verified empirically on Steam at 00:00 UTC flip: cursor pointed to ~Aug 2024, catch-up walked ~600 days, populated `*LeaderboardStatus` with 88 weekly + 22 monthly + 4 yearly entries (per type), produced 0 messages in `OfflineChatMessages`. Documented in `lifecycle-and-jobs.md` § Catch-up safety property.

Finding: **reward delivery is push, not direct grant** — `DistributeLeaderboardRewards` enqueues `ChatMessageBase` (`Sender = Guid.Empty`, `Data = ChatRequests.{Type}LeaderboardsResult`, `IsOffline = true`) → persisted to `OfflineChatMessages` via `Dal/Sql.MsSql/Chat/SqlOfflineMessagePersister.cs` → consumed by `GameClientPeer_Leaderboards.OnReceiveMessage_Leaderboards` → `RewardManager.GiveDeferredReward`. Multi-component wiring; the chat channel is what makes finalization safe to run while player is offline. Documented in `lifecycle-and-jobs.md` § Reward delivery channel.

Finding: **3-row UPSERT per gameplay event** — every `Update*Leaderboards` writes Weekly + Monthly + Yearly bucket rows simultaneously (via `EnumHelper.GetValues<LeaderboardPeriodType>().Select(...)` then per-period MERGE). One catch event with allowed `Source` triggers 6 UPSERTs (3 Global + 3 Fish) plus index maintenance — Global with 6 dim NC indexes is the largest write-amplification surface. Documented in `data-model.md` § One event = three UPSERTs.

Finding: **client cannot request past periods** — `Get{Type}Leaderboards` SubOps accept `(kind, dimensionType, periodType)` only, server constructs period from `DT.Helper.UtcNow`. So historical viewing isn't part of the player API; only current-period reads. WebAdmin's `Stats/Leaderboards/*HistoryModel.cs` reads History tables directly — admin-only, separate path. Documented in `data-model.md` § Client cannot request past periods.

Closed open finding from 2026-04-28 (master flag asymmetry) — content moved to `control-variables.md` § Master flag and `lifecycle-and-jobs.md` § Reset event triggering.
