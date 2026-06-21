# FP-44389 Backlog

All release-prep items resolved. Kept as the record; nothing open.

## Applied to current checklist
- [x] Env Vars block: `IgnoreWrongStrikeWhileHookPendingOnFloat = Y` (enable QA/CBT/PROD after release) — FP-43884
- [x] Online Conversion: movable step + codes `RemoveDeprecatedBuoys` (1), `FixDepletedItems` (2), `ResetLevel1SpawnPoint` (3) + optional post-release background run
- [x] Custom DB script row for `R202606-TournamentParticipantRatingBackfill.sql` (FP-43816) — review approved, Post-Release placement
- [x] Removed the 3 Offline Profile Conversion steps (no offline conversion this release)
- [x] Webhooks and Twitch deploy steps marked "no changes" (both unchanged since fork)

## Verifications (resolved)
- [x] A/B Test Platform #10 (Targeted Ads) — origin = liveops request (code-less); OFF/OFF confirmed by liveops
- [x] DataPump — QA->PROD routine sync covers FP-43334 (Ponds) and FP-43400 (GlobalVariables); no new table needed
- [x] Server Configuration — none required this release
- [x] Checklist (v16) fully validated: all template markers removed, content intact
- [x] "Regenerate future competitions" unconditional press is INTENTIONAL — destructive by design (`RegenerateFutureCompetitions()` -> `RemoveFutureCompetitiveActivities()` + `RandomizeCompetitions()`), but standard every release (schedule grid generated ~2 weeks ahead; adding/removing templates invalidates it). "Refresh FUTURE Competition Configs" is the in-place ConfigJson patch on top.

## Template fixes (recurring)
- [x] `0-DataPrepare.sql` -> `_DataPrepare.sql` corrected
- [x] Movable Online/auto Profile Conversion step added
- [x] Conversion-step duplication fixed by splitting voices — author-facing info-panel (🚧 + lookup query, removed on instantiation) vs operator-facing description
- [ ] When FP-44393 ships (ReleaseTool by Code): switch the template conversion step from numeric `<id>` to Code — tracked in FP-44393 and noted in [`reference/release_checklist_field.md`](../../../reference/release_checklist_field.md)

## Process improvements
- [x] Idea: run profile conversions by Code instead of numeric ConversionId -> filed FP-44393 (Story, epic FP-25824, Team Other)
- [x] Codify `Server Release Checklist Steps` field check into kb-close-task + jira-review-close -> mandatory "Closure / review gate" in `reference/release_checklist_field.md` (Step 9 / Step 2b; not in open — it finalizes nothing)
- [x] Author KB reference for release-checklist field semantics + option->step mapping + SQL-sweep method -> `reference/release_checklist_field.md` (registered in CLAUDE.md)
