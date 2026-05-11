---
module: leaderboards
---

# Leaderboards
> Three persistent leaderboard types — Competitive (per-tournament-kind ranks), Global (player progression), Fish (per-species records). Each type has its own update path, finalization/cleanup jobs, and reward distribution.

## Entry Points
- `LeaderboardsAdapter` — partial class split per type: `Shared/SharedLib/Leaderboards/LeaderboardsAdapter.cs` + `_Competitive.cs` / `_Global.cs` / `_Fish.cs` (Update / Get / Finalize / Rotate / Cleanup / Calculate methods)
- `LeaderboardsHelper` — partial class with same per-type split (supported tournament kinds, accepted fish sources)
- AsyncProcessor jobs — `AsyncProcessor/Jobs/Leaderboards/{Competitive,Global,Fish}Leaderboard{Cleanup,Finalization}Job.cs` plus `CalculateCompetitiveLeaderboardChangeJob.cs`

## Key Types
- `LeaderboardsAdapter` — runtime entry; holds 12 static subsystem flags pushed from `EnvironmentVariableCache.UpdateStaticVariables`
- `{Competitive,Global,Fish}LeaderboardPeriod` — per-type period descriptors; PeriodId = period start as `YYYYMMDD`
- `LeaderboardProcessingStatus` — 9-state machine (Unknown → Upcoming → Current → Passed → HistorySaved → Processing → Processed → Cleaning → Cleaned), see [`lifecycle-and-jobs.md`](lifecycle-and-jobs.md)
- `LeaderboardsQueryType` — query shape (`Top100AndUserAndSurrounding` etc.)
- `CompetitiveLeaderboardDimensionType`, `GlobalLeaderboardDimensionType` — dimension axes within a type
- `LeaderboardResultMessage<T>` — reward push DTO carried via offline-chat channel

## Dependencies
→ DAL: `ILeaderboardsProvider_{Competitive,Global,Fish}` (Sql.Interface), `SqlLeaderboardsProvider_*` (Sql.MsSql)
→ ObjectModel: leaderboard period / reward / result types
→ EnvironmentVariableCache: pushes 12 subsystem flags into adapter on cache refresh
→ ChatServer: rewards delivered as offline `ChatMessageBase` to `OfflineChatMessages` (see [`lifecycle-and-jobs.md`](lifecycle-and-jobs.md) § Reward delivery channel)
← TournamentEndAdapter: calls `UpdateCompetitiveLeaderboards` on tournament end
← GameProcessor / GameClientPeer_Game: calls `UpdateGlobalLeaderboards` / `UpdateFishLeaderboards` on catch
← AsyncProcessor: 3 finalization jobs (per type) + 3 cleanup jobs + `CalculateCompetitiveLeaderboardChangeJob`; cursor env-vars `Async.{Type}LeaderboardFinalizationTime`
← GameClientPeer_Leaderboards: client-facing queries (only current period — server resolves PeriodId from `DT.Helper.UtcNow`)
← WebAdmin: `Stats/Leaderboards/*HistoryModel.cs`, `*ExtModel.cs` (admin-only access to History)

## Deep Dives
- [Control variables](control-variables.md) — full semantics of the 13 leaderboards env-var flags (1 master + 12 subsystem), push-to-static refresh mechanics, client mirror map, defaults
- [Lifecycle and jobs](lifecycle-and-jobs.md) — period state machine, AsyncProcessor cursors, catch-up safety, reset event triggering, reward delivery channel
- [Data model and read path](data-model.md) — 3-row UPSERT pattern, PeriodId encoding, history table naming, index alignment with TOP-N optimization, query-cost breakdown, `IsBanned` gotcha
- Tests: `Shared/SharedLib.Tests/Leaderboards/{Competitive,Global,Fish}LeaderboardsTests.cs`
- Confluence: [Leaderboards GDD - 1st iteration](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/4532731906/Leaderboards+GDD+-+1st+iteration)

> **Disambiguation:** `TopsCache` (`Shared/SharedLib/Config/TopsCache.cs`) is the legacy `TopsAdapter` feature — not this module. See [`data-model.md`](data-model.md) § TopsCache vs LeaderboardsCache.

## Related Tasks
- FP-26788 — feature umbrella (original spec)
- FP-41595 — LBM release support: prod launch on 5 streams (2026-05-01), flag-flip checklist, DB load baseline
- FP-43631 (completed 2026-05-11): used the leaderboard ban surface (`CompetitiveRatingsCurrent.IsBanned`) for per-period surgical exclusion of matchmaking abusers. Findings about `UpdateLeaderboardsBanned` SP gotcha, post-cleanup audit loss, and History PK shape captured in `log.md`

See also: [backlog](backlog.md) | [log](log.md)
