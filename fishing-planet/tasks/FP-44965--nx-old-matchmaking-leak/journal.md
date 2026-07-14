---
jira: https://fishingplanet.atlassian.net/browse/FP-44965
title: "Nintendo: old group-based matchmaking leaked to prod via template content"
status: completed
executor: Stanislav Samoilov
created: 2026-07-14
type: bug
platforms: [Nintendo]
parent: FP-41583
related: FP-43625, FP-41746, FP-43553
---
# FP-44965: Old group-based matchmaking active on Nintendo prod

## Status
Completed 2026-07-14. NX prod ran a pre-LBM binary where the matchmaking grouping gate is content-only (no feature flag); a single stale competition template (168 "The Size Matters", old pre-rename `Groups` schema) carried a `Grouping` block, so competitions generated from it grouped participants while the feature is unreleased on Nintendo. Remediated on prod by manually stripping `$.Grouping` from template 168 and from the one already-generated future tournament (11251) — post-fix sweep shows 0 grouped competition templates and 0 future/live grouped tournaments. DEV/TEST/QA run the full new matchmaking release intentionally and were left untouched. Investigation write-up posted to FP-44965; ingress tracing (which NX content pour introduced the block) handed to QA and the ticket moved to QA. The 5 malformed-JSON templates are deferred to the LBM rollout.

## Summary
Support reported that on Nintendo the competition "The Size Matters" runs the new group-division matchmaking, and competition rating changes as it would after the leaderboards release — while leaderboards are not released on the platform. Other competitions appear to run on the old system.

Investigation shows NX runs a pre-LBM binary (KNW-level or older): zero LBM patches applied, `TournamentParticipants` still in the old schema (`GroupId`/`GroupName`/`IsRated`/`IsCanceled`), the matchmaking cleanup patch `LBM.M.2026.03.08-028-v2` not applied. In that old binary the grouping gate in `MatchmakingLogic.MakeGroups` is content-only (`KindId == Competition && Grouping != null`) — there is no env or platform flag. The moment template 168 gained a `Grouping` block, grouping switched on.

The "rating changes like after leaderboards" part is expected and unrelated to grouping: `IsRatingByPlaceEnabled = N` on NX means the old rating rules run for every competition (always did), and the 2026-05-01 leaderboards write-pipeline enablement (`Leaderboards.Is*UpdateOn = Y`, UI/Jobs/Rewards = N, `IsLeaderboardsOn = N`) writes ratings without a visible board.

## Key findings

### NX prod (Main)
- LBM patches applied: 0 (KNW: 2). `TournamentParticipants` columns `GroupId`/`GroupName`/`IsRated`/`IsCanceled` present → old schema, cleanup patch `LBM.M.2026.03.08-028-v2` not applied.
- Template inventory: 265 templates, 123 competitions (94 active). Exactly ONE competition template carries `Grouping`: template 168 "The Size Matters" (old schema `Groups`/`GroupId`/`GroupName`, `MinSize=20`, brackets Newbies/Midles/Tops at MinRating 0/101/1001).
- Tournaments from template 168: 25 pre-grouping rows (2025-06-22 … 2026-02-15), then 18 grouping rows from 2026-03-06 (8 archived + 10 live). Config entered the template in the 2026-02-15 … 2026-03-06 window; no `DataChanges` audit trail on prod (not edited via WebAdmin — likely content sync QA→PROD or direct SQL).
- Reported tournaments 9229 / 10250 / 10709 all started and grouped 100% of participants (21–23 each, one group). Nearest upcoming grouped tournament: 11251, start 2026-07-25 06:00 UTC.
- Side finding: 5 NX competition templates have invalid JSON (`ISJSON = 0`) — matches the `FinishPoint` unquoted-keys class from FP-43553; the FixUp normalization never reached NX.

### Mobile prod
Clean: 0 templates with `Grouping`; 0 tournaments (including archive) with `Grouping`.

## Plan / next steps
See [backlog](backlog.md). Prod remediation done (template 168 + tournament 11251 stripped manually). Remaining: post the investigation write-up to JIRA, identify the ingress channel for the stale `Grouping` (so it does not return on the next content sync), and handle the 5 malformed-JSON templates separately.

## Milestones
- 2026-07-14: Scan of NX + Mobile prod completed; root cause (content-activated legacy matchmaking on a pre-LBM NX binary) identified. JIRA FP-44965 filed under epic FP-41583 (Bug, Scrum Team Other, Platform Nintendo), assigned to Stanislav. KB task record created.
- 2026-07-14: Full NX-stack scan (DEV/TEST/QA/CERT/PROD). DEV/TEST/QA confirmed on the full new matchmaking release — new `Brackets` schema, 44 LBM patches + cleanup, `IsLeaderboardsOn=Y` / `IsRatingByPlaceEnabled=Y`, 103 grouped competition templates — so grouping there is the intended feature, not a leak. A DEV→PROD content sync was rejected: it would either spread `Grouping` onto the old prod binary across 140 future competitions, or break on the schema mismatch (old prod binary reads `Groups`, DEV ships `Brackets`). Prod remediated manually and surgically (no `RegenerateFutureCompetitions`): stripped `$.Grouping` from template 168 and from tournament 11251 (0 registrations; JSON validity preserved, `ISJSON=1`). Post-fix sweep: 0 competition templates and 0 future/live tournaments carry `Grouping` on NX prod. `RegenerateFutureCompetitions` cutoff verified (`RemoveFutureCompetetiveActivities` deletes `WHERE RegistrationStart > now+2h`); template 168 opens registration 12h before start, so the effective don't-touch horizon is ~14h from `StartDate` (2h buffer + 12h registration window) — and the action would have wiped/regenerated all 140 in-window competitions to fix one, which is why the single-row edit was chosen.
- 2026-07-14: Investigation write-up posted to FP-44965 (comment 129978). Ingress working hypothesis (per team lead): a parasitic edit that slipped into an NX content sync while pouring unrelated content — still to be confirmed so it does not recur on the next sync.
- 2026-07-14: QA handoff comment posted to FP-44965 and the ticket moved to QA to trace the ingress via NX content pours (QA-owned; check window 2026-01-01 → early March 2026, few pours). The 5 malformed-JSON competition templates left untouched — they normalize when the LBM binary/content lands on NX. Server-side remediation complete; task closed.
