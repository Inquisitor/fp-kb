---
module: matchmaking
---

# Matchmaking
> Groups tournament participants into balanced buckets using rating-based brackets.

## Entry Points
- `MatchmakingLogic` — `Shared/SharedLib/Tournaments/MatchmakingLogic.cs` (core: `ProcessGrouping()`, `BalanceBuckets()`, `AllocateGroupBudget()`)

## Key Types
- `TournamentBracket` — rating range config per bracket
- `TournamentBucket` — runtime bucket extending TournamentBracket
- `TournamentGroupingRule` — grouping config: brackets, min/max/target sizes
- `TournamentGroup` — output: group of participants
- `Rational` — `Shared/SharedLib/Helpers/Rational.cs` (exact arithmetic for swap improvement)

## Dependencies
→ ObjectModel: TournamentBracket, TournamentBucket, TournamentGroup, TournamentGroupParticipant
← TournamentStartAdapter: calls `ProcessGrouping()` at tournament start
← TournamentsHelper: `InitializeGrouping()`
← TournamentAdapter: game server DAL
← WebAdmin: CompetetiveActivityBreaksModel, ReviewTournamentModel, ToolsController, StatsController

## Deep Dives
Tests: `SharedLib.Tests/Tournaments/MatchmakingLogicTests.cs` + `MatchmakingTestCase.cs` (string-notation parser)
Data: SQL `Tournaments`, `TournamentTemplates`, `TournamentSeries`, `TournamentGrid`; config via `TournamentGroupingRule` JSON in DB/WebAdmin
Confluence: 4339925004 (Matchmaking, stale), 4339925014 (Matchmaking testing, current)

## Related Tasks
- FP-41746: Alignment plan — bug fixes, rename, algorithm, DB cleanup (active; phases 1-4,6,8 done)
- FP-41833: Tests and test infrastructure

See also: [backlog](backlog.md) | [log](log.md)
