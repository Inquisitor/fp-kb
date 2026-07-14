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
Confluence: [Matchmaking spec](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/5505613835) (Business Logic > Competitive), [Matchmaking testing](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/4339925014)

## Related Tasks
- FP-41746 (completed 2026-04-15): Alignment — bug fixes, rename, FFS algorithm, DB cleanup, GDD updated, new spec published to [Confluence](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/5505613835). Tech-debt successor: FP-43717 (`MaxRating` removal)
- FP-41833: Tests and test infrastructure
- FP-43553 (completed 2026-05-12): pre-release ConfigJson on prod-generated future tournaments after Leaderboards/Rating/Matchmaking deploy. Hot-patched all platforms (Steam 2026-04-29, PS/XB/MOB/NX 2026-05-11). Release procedure codified in Server Release Checklist template + `<kb>/feedback/configjson_extension_backfill.md`. Code-side root cause tracked under FP-43717; operator tooling under FP-43756 / FP-43758
- FP-43631 (completed 2026-05-11): PCR-drop abuse detection — discriminator (`IsStarted = 0`), threshold heuristic (`NoShowSharePct ≥ 30`), and per-period surgical leaderboard ban via `CompetitiveRatingsCurrent.IsBanned`. Bracket ID mapping confirmed empirically (`1=NOOBS / 2=MIDDLES / 3=TOPS`). 29 banned pre-finalization across STEAM/PS/XB; 107 in wider sweep routed to Support
- FP-44965 (completed 2026-07-14): NX prod — legacy content-gated matchmaking leaked via one stale template (168 "The Size Matters", old `Groups` schema) on the pre-LBM binary; fixed by stripping `Grouping` from the template + one future tournament. Grouping gate confirmed content-only (no feature flag); `RegenerateFutureCompetitions` ~14h cutoff documented — see [log](log.md) 2026-07-14. Ingress tracing handed to QA

See also: [backlog](backlog.md) | [log](log.md)
