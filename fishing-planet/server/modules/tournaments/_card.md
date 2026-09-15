---
module: tournaments
---

# Tournaments
> Sport tournaments (multi-stage series) and competitions (single instances). Templates are authored
> per calendar slot and expanded into dated instances by a nightly job; a serie's stages are tied
> together by a shared `SerieInstanceId` and advance by stage type. **Stub** — entry points below are
> those walked during the FP-46040 review; populated further as tournament work lands.

## Entry Points
- `TournamentSchedulingAdapter` — `Shared/SharedLib/Tournaments/TournamentSchedulingAdapter.cs`. Two independent generators: `ScheduleTournements` (Sport, expands a template's schedule via `GenerateByTemplate`/`GenerateStartDays`) and `RandomizeCompetitions` (Competition, walks a two-hour-slot timeline and ignores `ScheduleType` entirely). Also `AssignSerieInstanceIds`, the manual-only `ScheduleCompetitions`, and the admin `CreateTestTournament`
- `TournamentEndAdapter` — `Shared/SharedLib/Tournaments/TournamentEndAdapter.cs`: finalization, `ManageTournamentSerieStages` (advances a player to the next stage)
- `TournamentSchedulingJob` — `AsyncProcessor/Jobs/TournamentSchedulingJob.cs`: daily at 00:01, wraps the whole generation run in one try/catch
- `CompetitionSchedulingJob` — `AsyncProcessor/Jobs/CompetitionSchedulingJob.cs`: daily at 00:02, calls `RandomizeCompetitions`
- WebAdmin tools — `WebAdmin/WebAdmin/Models/Tools/ToolsModel_Tournaments.cs` and `ToolsModel_Competitions.cs`; the latter's three regeneration buttons split random / scheduled / future, only the "scheduled" one reaching `GenerateStartDays`
- `TournamentTemplateBreaksModel` — `WebAdmin/WebAdmin/Models/Stats/`: diagnostic report of broken templates (missing pond weather, start/end not on one in-game day, inconsistent registration dates in a serie)

## Key Types
- `TournamentTemplateDto` / `TournamentDto` — `Dal/Sql.Interface/Tournaments/`; a template carries `ScheduleType` (`"D"`/`"W"`/`"M"`/`"Y"`) plus free-text `DaysOfWeek` / `DaysOfMonth` / `Month`
- `SeriesBasicInfoDto` — per serie `StagesCount` and `InitialTemplateId`, both computed in SQL by `GetTournamentSeriesBasicInfo`
- `StageType` — `Shared/ObjectModel/Tournaments/TournamentSerieInstance.cs`: `Qualification = 1`, `SemiFinal = 2`, `Final = 3`
- `TournamentKinds` — `Shared/Photon.Interfaces/Tournaments/TournamentKinds.cs`: `Sport = 1`, `Competition = 3`, `UserGenerated = 4`

## Dependencies
→ DAL: `ITournamentProvider` (Sql.Interface), `SqlTournamentProvider` (Sql.MsSql)
→ Weather: `GetPondWeather` per pond, baked into each instance's `ConfigJson` at generation time
← AsyncProcessor: nightly generation
← Leaderboards: `TournamentEndAdapter` calls `UpdateCompetitiveLeaderboards` on tournament end

## Deep Dives
- [Content calendar](content-calendar.md) — how the designer lays out a year; bounds which scheduling edge cases real content can reach
- Tests: `Shared/SharedLib.Tests/Tournaments/TournamentSchedulingAdapterTests.cs`

## Related Tasks
- FP-46040 — test-tournament stage ordering; the serie-stage ordering and generator limitations are written up in the [review](../../../review/FP-46040--tournament-qualifier-start-order/review.md)

See also: [backlog](backlog.md)
