# Backlog — FP-43553

> Open follow-ups for the Competitions ConfigJson incident. Steam prod immediate fix is done; this list tracks what still has to land.

## Open

- [ ] Run `SQL/Releases/R202604-Leaderboards-Rating-Matchmaking.sql` on **PS** prod, address any non-empty rows in Q1..Q5 (in-place `JSON_MODIFY` backfill for tournaments with verdict `arch`; `REPLACE` patch for unquoted-key templates; WebAdmin fix for any `content` defects)
- [ ] Same on **XB** prod
- [ ] Same on **MOB** prod
- [ ] Same on **NX** prod
- [ ] Update release procedure: any extension of `TournamentJsonConfig` (or `TournamentTemplateJsonConfig`) requires a post-deploy backfill step for already-generated future tournaments whose `RegistrationStart` has passed. The standard `RegenerateFutureCompetitions` admin action does not cover them. Suggested: a templated `JSON_MODIFY` script the release engineer fills with the new field paths; ship alongside the SQL patch that lands the schema change
- [ ] Tighten `JsonVerificator.exe` (`WebAdmin/JsonVerificator/Program.cs`): add a parallel RFC-strict parse via `System.Text.Json.JsonDocument.Parse` and reject when it throws. Sequenced **after** all platforms' templates are normalised — otherwise contentщики will be unable to re-save the existing 15 templates that currently have unquoted `FinishPoint` keys
- [ ] Periodic content audit per platform: run Q3 (per-place Rating gaps) and Q5 (RFC-invalid templates) once before each release with a `TournamentJsonConfig` change; fix any defects in WebAdmin and re-generate affected future tournaments
- [ ] Tech-debt: refactor `ScheduleCompetitions` / `RandomizeCompetitions` (`Shared/SharedLib/Tournaments/TournamentSchedulingAdapter.cs`) so unknown JSON fields are not lost during generation. Two candidate approaches: (a) replace the deserialize→reserialize cycle with `JObject`-level in-place patching of weather and grouping; (b) keep current pipeline but add `MissingMemberHandling.Error` for the generation-side `JsonSerializerSettings` so model/template drift fails loudly during scheduling instead of silently dropping fields

## Deferred / Notes

- **Past tournaments out of scope.** 713 past competitions on Steam are not in this ticket — they were both generated and played under the pre-release contract; rating/penalty/Grouping model did not exist then. Treating them as defects would require synthetic backfill of player results, not justified by anything observable
- **Live tournament was patched only partially, by design.** Tournament 318866 received `Rating` and `*Penalty` backfill but not `Grouping` — `ProcessGrouping` had already run by the time of patching. With `RatingMultiplier = 1.0` in the template the absence of `Grouping` in the live config has no effect on rating math, only on bracket-level ranking surfaces (acceptable trade-off for a single in-flight tournament)
- **Architectural class A vs class C are independent.** Even if WebAdmin validator is tightened (class C), the snapshot effect (class A) will still occur on the next `TournamentJsonConfig` extension. The two backlog items must both land
- **Adjacent investigation (out of this ticket):** `Missions` and `TargetedAds` JSON columns may suffer from the same lax-JSON-acceptance pattern as templates do, since they share the WebAdmin validator infrastructure. Worth a one-time `ISJSON = 0` audit on each platform after this ticket closes
