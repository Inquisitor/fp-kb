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
- `{Competitive,Global,Fish}LeaderboardPeriod` — per-type period rows
- `LeaderboardProcessingStatus` — Running / Cleaning lifecycle states
- `LeaderboardsQueryType` — query shape (`Top100AndUserAndSurrounding` etc.)
- `CompetitiveLeaderboardDimensionType`, `GlobalLeaderboardDimensionType` — dimension axes within a type

## Dependencies
→ DAL: `ILeaderboardsProvider_{Competitive,Global,Fish}` (Sql.Interface), `SqlLeaderboardsProvider_*` (Sql.MsSql)
→ ObjectModel: leaderboard period / reward / result types
→ EnvironmentVariableCache: pushes 12 subsystem flags into adapter on cache refresh
← TournamentEndAdapter: calls `UpdateCompetitiveLeaderboards` on tournament end
← GameProcessor / GameClientPeer_Game: calls `UpdateGlobalLeaderboards` / `UpdateFishLeaderboards` on catch
← AsyncProcessor: schedules finalization / cleanup / calc jobs
← GameClientPeer_Leaderboards: client-facing queries
← WebAdmin: `Stats/Leaderboards/*HistoryModel.cs`, `*ExtModel.cs`

## Deep Dives
- [Control variables](control-variables.md) — full semantics of the 13 leaderboards env-var flags (1 master + 12 subsystem), push-to-static refresh mechanics, client mirror map, defaults
- Tests: `Shared/SharedLib.Tests/Leaderboards/{Competitive,Global,Fish}LeaderboardsTests.cs`
- Confluence: [Leaderboards GDD - 1st iteration](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/4532731906/Leaderboards+GDD+-+1st+iteration)

## Related Tasks
- FP-26788 — original feature umbrella
- FP-34120 — initial env-var support (legacy A/B test 17)
- FP-34390 — added 12 subsystem flags (Update / Rewards / Jobs / UI per type)
- FP-36061 — added `IsLeaderboardsOn` master + query-type enums
- FP-41595 — LBM release support (rollout coordination, flag-flip checklist)

See also: [backlog](backlog.md) | [log](log.md)
