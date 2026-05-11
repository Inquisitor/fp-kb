# Leaderboards — lifecycle and jobs

How a leaderboard period evolves through its lifetime, who advances it, and how rewards reach the player. This is the execution model behind the [control variables](control-variables.md).

## Period status state machine

`LeaderboardProcessingStatus` enum (`Shared/ObjectModel/Leaderboards/LeaderboardProcessingStatus.cs`) defines 9 states. The actual transitions form a fork-then-pipeline rather than a linear chain:

```
                   ┌──────────────────────────────────────────────────────┐
(no row, Unknown)──┤ Initialize → Upcoming → Current → Passed             │→ HistorySaved → Processing → Processed → Cleaning → Cleaned
                   │                                                      │
                   └ Unknown ────────────── Passed (catch-up shortcut) ───┘
```

Transition driver per arc — all in `LeaderboardsAdapter_{Competitive,Global,Fish}.cs`:
- `(no row) → Upcoming → Current` — `RotateCurrent*Leaderboards` for the *current* period at the tick time (`TryInitializeNew*LeaderboardPeriod` creates the row at Upcoming, switch then sets it to Current). Upcoming is transient — rarely observed in steady state.
- `Current → Passed` — `RotateCurrent*Leaderboards` for the *previous-of-current* period when its boundary just crossed.
- `Unknown → Passed` (catch-up shortcut) — `RotateCurrent*Leaderboards` when the previous period has no Status row at all (stale-cursor catch-up). Init creates Upcoming, then immediately set to Passed in the same call.
- `Passed → HistorySaved → Processing → Processed → Cleaning` — `FinalizeAndRestart*Leaderboards` (calls `Save*LeaderboardHistory` + `Distribute*Rewards` and sets statuses along the way).
- `Cleaning → Cleaned` — `Cleanup*LeaderboardsData` after `DeleteCurrent*LeaderboardsData` removes the rotated rows from `*RatingsCurrent`.

`Cleaned` is terminal — the period now lives only in `*Rating{PeriodTypeName}History`. Transitions are scattered across 3 method families plus `Set*LeaderboardStatus` writes; read together to see the whole picture.

## AsyncProcessor jobs and schedule

Seven hourly jobs run on the AsyncProcessor service (`AsyncProcessor/Jobs/Leaderboards/*.cs`), all `JobType.ScheduledJob` + `JobFrequancy.Hourly` with a fixed minute-in-hour `ExecuteTime`:

| Min | Job                                                                  |
|----:|----------------------------------------------------------------------|
| :05 | `CalculateCompetitiveLeaderboardChangeJob` (per-player rating delta) |
| :07 | `CompetitiveLeaderboardFinalizationJob`                              |
| :15 | `GlobalLeaderboardFinalizationJob`                                   |
| :20 | `CompetitiveLeaderboardCleanupJob`                                   |
| :23 | `FishLeaderboardFinalizationJob`                                     |
| :30 | `GlobalLeaderboardCleanupJob`                                        |
| :40 | `FishLeaderboardCleanupJob`                                          |

So every type has Finalize + Cleanup pair, plus a Calculate-change for Competitive only. Hourly cadence — not daily — but each tick advances state only when a period boundary has been crossed.

## Three finalization cursors and the catch-up loop

Each Finalization job tracks its own "last successfully finalized date" cursor in env-vars (`Async.{Competitive,Global,Fish}LeaderboardFinalizationTime`, accessor pair on `SqlAsyncProvider`). On each tick the job walks **day-by-day from cursor + 1d to today**, calling `FinalizeAndRestart{Type}Leaderboards(date)` for each day; the cursor is ratcheted only when the date completes successfully (any exception leaves it pinned, retry next hour).

`FinalizeAndRestart(date)` internally enumerates `LeaderboardPeriodType` and rotates+finalizes whichever periods ended on that date. So a single tick can advance Weekly/Monthly/Yearly all together when their boundaries align (e.g. the Jan 1 tick will close Yearly + Monthly + Weekly for whoever's week happened to end).

**Implication:** if a cursor is stale, the very first tick walks the full backlog. Catch-up cost is linear in cursor lag (in days). On a fresh-deploy or post-rotation flag-flip it can run hundreds of iterations in one tick — relies on the catch-up safety property below.

## Catch-up safety property

The catch-up loop above is safe to run on any cursor lag because of an emergent property of the storage:

1. `*RatingsCurrent` holds **only currently-open periods** (rotated rows are deleted by Cleanup).
2. For any past period, `*RatingsCurrent` rows for it = ∅.
3. `SaveCompetitiveLeaderboardHistory` MERGE-s from `*RatingsCurrent WHERE PeriodId = @past` → 0 source rows → 0 inserts in History.
4. `DistributeLeaderboardRewards` reads from `*LeaderboardHistory WHERE PeriodId = @past AND Place IN (...)` → 0 rows → early `return true` with `sentCount = 0`.
5. **Zero reward messages enqueued**, regardless of how stale the cursor was.

This is what makes "flip Jobs on with stale cursor" non-destructive. The cursor advances to today; status table fills with `Cleaned` rows for every walked period; no player gets a stale-period reward message. Property exercised at LBM rollout (see [`tasks/FP-41595--leaderboards-release-support/journal.md`](../../tasks/FP-41595--leaderboards-release-support/journal.md) for the run record).

## Reset event triggering

`TryRaiseLeaderboardsResetEvent` (`Photon/src-server/Loadbalancing/LoadBalancing/GameServer/GameClientPeer_Leaderboards.cs`) is called from `GameClientPeer_Travel.cs` only — at login completion and at travel checkpoints. **Not on any schedule.** Per-peer state lives in the `_LeaderboardsResetEventLastCheckTime` field (memory-only, not persisted). On first call after login the field is null → defaults to `PrevActivityDate.AddSeconds(-15)` so reset events accumulated during the player's offline window are caught.

Effect: a player who never travels/relogs misses the toast even when periods rotate. The toast itself is purely cosmetic (handled by `InfoServerMessagesHandler.LeaderboardsReset` on client) — does **not** trigger a re-fetch. So missing it doesn't cause data drift.

Server-side gate: `if (!EnvironmentVariableCache.IsLeaderboardsOn) return;` — so when the master flag is `N`, no reset events fire.

## Reward delivery channel

Rewards are not granted directly to inventory at finalization. They travel through the **offline-chat channel**:

1. **Producer** — `DistributeLeaderboardRewards` in `LeaderboardsAdapter_{Competitive,Global,Fish}.cs`:
   - For each ranked player + matching `*LeaderboardRewards` rule:
     - Builds `LeaderboardResultMessage<{Type}LeaderboardPeriod>` (UserId, Period, Place, Reward, ClubPoints)
     - Wraps in `ChatMessageBase` with `Sender = Guid.Empty`, `SenderName = "System"`, `Data = ChatRequests.{Type}LeaderboardsResult`, `IsOffline = true`, `Expiration = utcNow + MessageLifetime.LeaderboardResultExpiration`
     - Adds to `messages` list, dispatched through chat-server protocol

2. **Persistence** — `Dal/Sql.MsSql/Chat/SqlOfflineMessagePersister.cs` writes JSON-serialized `ChatMessageBase` to the `OfflineChatMessages` table.

3. **Consumer** — `GameClientPeer_Leaderboards.OnReceiveMessage_Leaderboards` switches on `Data` field:
   - `ChatRequests.CompetitiveLeaderboardsResult` → `ProcessCompetitiveLeaderboardResult`
   - `ChatRequests.GlobalLeaderboardsResult` → `ProcessGlobalLeaderboardResult`
   - `ChatRequests.FishLeaderboardsResult` → `ProcessFishLeaderboardResult`
   
   Each `Process*` method deserializes `LeaderboardResultMessage<T>`, calls `RewardManager.GiveDeferredReward(this, reward, clubPoints, ProfileRewardSources.{Type}Leaderboard, ..., entityId: message.Period.CompositeId)`, and increments `Profile.Stats.LeaderboardPlaceTaken(place)`.

**Why offline channel, not direct grant:** finalization runs on AsyncProcessor (separate from GameServer); player may be offline at the moment. Chat-server queues the message; on next login GameServer's chat handler delivers it.

**Diagnostic query** — to find LB reward messages on a prod stream:
```sql
SELECT TOP 100 [Timestamp], LEFT(Json, 200) AS Preview
FROM OfflineChatMessages WITH (NOLOCK)
WHERE Json LIKE '%LeaderboardsResult%'
ORDER BY [Timestamp] DESC;
```

## RewardsOn safety with finalization

`RewardsOn=N` short-circuits `DistributeLeaderboardRewards` before any `ChatMessageBase` is built — see [`control-variables.md`](control-variables.md) § Subsystem flags for the gate detail. Net effect on the lifecycle: a period can be Finalize-d and `Cleaned` while `RewardsOn=N`, leaving History rows with `RewardId = NULL` and zero rows in `OfflineChatMessages`. This is the safety mechanism behind "flip Jobs=Y but keep RewardsOn=N for the first period".

## See also

- [`control-variables.md`](control-variables.md) — flag semantics including the master vs subsystem split
- `Shared/SharedLib/Leaderboards/LeaderboardsAdapter_{Competitive,Global,Fish}.cs` — state transitions and reward generation
- `AsyncProcessor/Jobs/Leaderboards/*.cs` — three FinalizationJobs + three CleanupJobs + `CalculateCompetitiveLeaderboardChangeJob`
- `Dal/Sql.MsSql/Chat/SqlOfflineMessagePersister.cs` — chat-message → `OfflineChatMessages` writeback
- `Dal/Sql.MsSql/Async/SqlAsyncProvider.cs:1388-1410` — three finalization-date cursor accessors
