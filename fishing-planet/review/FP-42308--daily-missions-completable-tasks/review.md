---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15849
jira: https://fishingplanet.atlassian.net/browse/FP-42308
---

# Review: FP-42308 — Daily Missions: guarantee generated tasks are completable

## Summary

Bug report: a daily mission "Catch fish more than 140 cm using any Carp gear" was generated for a level-56 player, but no such fish are catchable on any Carp rod at any level. Fix introduces greedy compatibility filtering — for each daily-mission condition, the candidate-fish set (from player's available ponds, narrowed by the fish category) is consulted; condition values that no candidate fish supports are dropped from the selection pool.

Environment: Test (not production).

## Scope

- **LBM r15849** — Daily Missions - Try guarantee the generated tasks will be unique
  - Add `candidateFish` field built from `context.AvailablePonds` × `task.FishCategoryId`
  - Add `BuildCandidateFish` / `NarrowCandidateFish` and per-condition `FishMeets*Condition` predicates
  - Add `compatibilityFilter` to `GetOtherCondition`; pre-filter selection pools in `GetFishLength` / `GetFishWeight` / `GetBaitLure` / `GetTackleTemplate` / `GetDragStyle` / `GetTimeOfDay` / `GetPlace`
  - Add 6 new tests covering tackle×length / tackle×weight / baitlure×length / fishform×dragstyle / all-compatible / empty-candidates
  - Soften `TestPondSettingsService.GetPondLocalFish` to return empty array on missing pond key

## Findings

### F-1: UTF-8 BOM removed from two of five touched files [Low]

**Description**: r15849 stripped the UTF-8 BOM from `Shared/SharedLib/DailyMissions/CatchFishTasks/TaskBuilderBase_OtherConditions.cs` and `Shared/SharedLib.Tests/DailyMissions/CatchFishTasks/TestSettings/TestPondSettingsService.cs` (visible in the diff: `-﻿using ObjectModel...` → `+using ObjectModel...`). The other three touched files preserved BOM. `.editorconfig` enforces `charset = utf-8-bom` for `*.cs`. Still missing on HEAD.

**Investigation**:
- `head -c 3` on HEAD: `TaskBuilderBase_OtherConditions.cs` and `TestPondSettingsService.cs` start with `usi` (no BOM); other three start with `EF BB BF u`.
- Diff confirms the regression originated in r15849.

**Resolution**: Skipped — hygiene only, fix on Test, no user impact, trivial to restore alongside future edits to those files.

### F-2: Commit message says "unique", JIRA / description say "completable" [Info]

**Description**: SVN-коммит r15849 имеет заголовок `Daily Missions - Try guarantee the generated tasks will be unique`, но описание тикета и JIRA-комментарий автора говорят про **completable** (выполнимость). Код реализует именно последнее. Похоже на опечатку в commit message.

**Resolution**: Skipped — commit message неизменяем, не системно.

## Investigation Journal

- ⚠ JIRA `customfield_11224` (Executor) empty; expected `Yuriy Burda` per the SVN comment. Detect-only — not blocking.
- Branch ancestry: r15849 ≤ MFT base r15942 → fix inherited via branch copy in MFT. Verified via `svn log` on `TaskBuilderBase.cs` in MFT URL — r15849 visible. No cross-merge required; comment omits `Merged → MFT`.
- HEAD verification per FP-42190 (commit ~2 months old): substantial follow-up evolution — r15867 (FP-42355) removed `AvailablePonds` field, replaced with `GetSelectedPonds()` delegate; r15891 (FP-42429) added FishForm-not-applicable drop and zero-weight pool drop; r15900 (FP-42527) added trolling-pond filter; r15903 (FP-42549) refactored candidate-fish flow + renamed `LocalFish` → `CandidateFish`.
- Hypotheses ruled out by HEAD-check:
  - NRE on `context.AvailablePonds` if null → superseded by r15867 (field removed).
  - "avg-not-max" length/weight filter is too aggressive → kept on HEAD; policy decision (predictable completability over edge-case reachability), tests cement the behavior.
  - Order-dependence of `task.Conditions` → by-design: greedy narrowing makes downstream conditions consistent with earlier picks; reverse order may drop a different condition but never introduces an incompletable mission.
- Triage routing for `missions/triage-2026-04.md`: zero new entries — F-1 (hygiene, no decision needed) and F-2 (no actionable answer) both fail the 3-way AND.
- Severity context: feature is on Test, not production → release-status gate per FP-42164 collapses any data-integrity flavor of severity to Skipped.
