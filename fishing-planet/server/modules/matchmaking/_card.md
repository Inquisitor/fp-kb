# Matchmaking

## Entry Points
- `MatchmakingLogic` — `Shared/SharedLib/Tournaments/MatchmakingLogic.cs` (core algorithm: `ProcessGrouping()`, `BalanceBuckets()`, `AllocateGroupBudget()`)
- `TournamentStartAdapter` — `Shared/SharedLib/Tournaments/TournamentStartAdapter.cs` (calls `MatchmakingLogic.ProcessGrouping()` at tournament start)
- `TournamentBracket` — `Shared/ObjectModel/Tournaments/TournamentBracket.cs` (rating range config per bracket)
- `TournamentBucket` — `Shared/ObjectModel/Tournaments/TournamentBucket.cs` (runtime bucket extending `TournamentBracket`)
- `TournamentGroupingRule` — `Shared/ObjectModel/Tournaments/TournamentGroupingRule.cs` (grouping config: brackets, min/max/target sizes)
- `TournamentGroup` — `Shared/ObjectModel/Tournaments/TournamentGroup.cs` (output: group of participants)

## Test Infrastructure
- `MatchmakingLogicTests` — `Shared/SharedLib.Tests/Tournaments/MatchmakingLogicTests.cs`
- `MatchmakingTestCase` — `Shared/SharedLib.Tests/Tournaments/Helpers/MatchmakingTestCase.cs` (string-notation parser)
- `Rational` — `Shared/SharedLib/Helpers/Rational.cs` (exact arithmetic for swap improvement)

## Data
- SQL: `Tournaments`, `TournamentTemplates`, `TournamentSeries`, `TournamentGrid`, `TournamentParticipants`, `TournamentIndividualResults`
- Config: `TournamentGroupingRule` JSON inside tournament templates (DB + WebAdmin)

## Depends On
- ObjectModel (`TournamentBracket`, `TournamentBucket`, `TournamentGroup`, `TournamentGroupParticipant`)
- SharedLib/Helpers (`Rational`)

## Used By
- `TournamentStartAdapter` (tournament start flow)
- `TournamentsHelper` (`InitializeGrouping()`)
- `TournamentAdapter` — `Photon/.../DalAdapters/TournamentAdapter.cs` (game server DAL)
- `CompetetiveActivityBreaksModel` — `WebAdmin/.../Models/Stats/CompetetiveActivityBreaksModel.cs`
- `ReviewTournamentModel` — `WebAdmin/.../Models/Tools/ReviewTournamentModel.cs`
- `ToolsController`, `StatsController` — WebAdmin controllers

## Confluence Pages
- 4339925004: Matchmaking (stale — missing group budget algorithm)
- 4339925014: Matchmaking testing (current)

## Related Tasks
- FP-41746: Alignment plan — bug fixes, rename, algorithm (active)
- FP-41833: Tests and test infrastructure
