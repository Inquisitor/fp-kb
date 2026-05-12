# Backlog — FP-43553

> Open follow-ups for the Competitions ConfigJson incident. Steam prod immediate fix is done; this list tracks what still has to land.

## Open

(empty — all items resolved, deferred per explicit decision, or split out to dedicated tickets)

## Closed

- [x] **2026-05-11** Run the fix-up script on **PS / XB / MOB / NX** prod. Completed by DevOps as part of platform release checklists.
- [x] **2026-05-11** Update release procedure for `TournamentJsonConfig` extensions. Server Release Checklist template (Confluence page 4395597825, version 17) gained a new conditional step "Fix generated competitions" placed immediately after `Regenerate future competitive activities`. Developer-side rule codified in `<kb>/feedback/jsonconfig_extension_backfill.md`.
- [x] **2026-05-11** Periodic content audit per platform. Subsumed by the new template step: every release copied from the template now carries the dry-run procedure inline.

## Tracked elsewhere

- **FP-43717** (`[Matchmaking] Eliminate dependency on persisted MaxRating in bracket config`) — supersedes the defensive symmetric/local `InitializeGrouping` fix that previously lived in this backlog. Its scope is wider: either remove `MaxRating` from the schema altogether, or make it transient at the matchmaking entry point. The asymmetry contract that caused the defect no longer matters after FP-43717 lands.
- **FP-43756** (`[Competitions] Cancel scheduled competitions overlapping release downtime`) — Proposal to GD to extend the Upcoming Release page to surface and cancel `KindId = 3` competitions overlapping release downtime. Closes the live-competition-during-release risk class.
- **FP-43758** (`[Competitions] Add non-destructive admin action to refresh scheduled competition configs`) — new `RefreshFutureCompetitionConfigs` admin action that refreshes existing future competitions' `ConfigJson` from their templates without losing participant registrations. Replaces the manual `JSON_MODIFY` fix-up flow established by this incident.

## Deferred / Notes

- **`JsonVerificator.exe` strict-parse — skipped (2026-05-12).** Adding parallel RFC-strict parse via `System.Text.Json.JsonDocument.Parse` was considered as a guard against future content like the unquoted-`FinishPoint` defect. Skipped per GD lead: game designers are accustomed to the current lenient JSON syntax in templates, and forcing RFC-strict editing would block their workflow on the 15 templates that already carry that shape. SQL-side defence (Phase 0 of the fix-up script) already normalises `FinishPoint` before each release that needs it, which covers the deploy-time risk. Revisit only if content-validation requirements tighten.
- **Adjacent `Missions` / `TargetedAds` `ISJSON` audit — skipped (2026-05-12).** A one-time `ISJSON = 0` scan across the GD-authored JSON columns was considered to surface the same unquoted-key pattern elsewhere. Skipped per GD lead: those columns share the same lenient-template authoring flow, so any rows surfaced would not be acted on (same workflow trade-off as the strict-parse skip above). Runtime correctness is unaffected — Newtonsoft normalises on every re-serialise. Revisit only if content-validation requirements tighten.
- **Scheduling adapter unknown-fields refactor — skipped (2026-05-12).** Refactor `ScheduleCompetitions` / `RandomizeCompetitions` to preserve unknown JSON fields during generation (via `JObject` patching or `MissingMemberHandling.Error`) was considered as a deeper architectural defence. Skipped per user decision: with FP-43758 providing a non-destructive operator action that refreshes ConfigJson from templates, the only remaining failure mode would be someone bypassing the canonical pipeline — and the pipeline exists specifically to prevent that. Defence-in-depth value does not justify the architectural change.
- **Past tournaments out of scope.** 713 past competitions on Steam are not in this ticket — they were both generated and played under the pre-release contract; rating/penalty/Grouping model did not exist then. Treating them as defects would require synthetic backfill of player results, not justified by anything observable
- **Live tournament was patched only partially, by design.** Tournament 318866 received `Rating` and `*Penalty` backfill but not `Grouping` — `ProcessGrouping` had already run by the time of patching. With `RatingMultiplier = 1.0` in the template the absence of `Grouping` in the live config has no effect on rating math, only on bracket-level ranking surfaces (acceptable trade-off for a single in-flight tournament)
- **Three already-grouped tournaments (318868 / 318869 / 318870) left as-is by section D, by design.** Diagnosed evening 2026-04-29: only ~26–45 % of registered participants were assigned, all to bracket 1 group A — the rest ended up with `BracketId IS NULL` due to the section A.4 raw-template `Grouping` copy missing `Brackets[i].MaxRating`. `ProcessGrouping` had already executed at observation time, so a `MaxRating` patch cannot retroactively redistribute participants. Same `RatingMultiplier = 1.0` rationale as the live exclusion above — per-bracket rating math is identical regardless of bracket assignment. Backfill was applied only to the two still-upcoming rows (318871, 318872)
- **Architectural class A vs class C are independent.** Even if WebAdmin validator is tightened (class C), the snapshot effect (class A) will still occur on the next `TournamentJsonConfig` extension. The two backlog items must both land
