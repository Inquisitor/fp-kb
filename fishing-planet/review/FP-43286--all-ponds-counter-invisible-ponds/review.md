---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15989, merged to MFT @ r15990
jira: https://fishingplanet.atlassian.net/browse/FP-43286
---

# Review: FP-43286 — All - Waters Missioner achievement not completing

## Summary

Bug fix: achievement "All - Waters Missioner" (id 1146) does not complete after the player satisfies its single stage (2902) condition (do at least one daily-mission task on each visible pond). Root cause per JIRA: `DailyMissionTaskAllPonds` counter includes the test pond (id = 1), so the visible-ponds total never matches the achievement target. Fix per commit message: exclude invisible ponds from the counter.

Feature is currently in Test environment only, not production — affects severity assessment for backfill / stale-counter concerns.

## Scope

- **LBM r15989** — Fix DailyMissionTaskAllPonds counter to exclude invisible ponds
- **MFT r15990** — Merge from LBM r15989 (Content → Code)

## Investigation Journal

- 2026-04-27 — Phase 1 intake done. Executor field (`customfield_11224`) empty in JIRA — surfaced; not blocking.
- Triage-mode active: `<kb>/fishing-planet/server/modules/missions/triage-2026-04.md` (Release 2026.3 Leaderboards).
- User context: feature is in Test only — collapses backfill-class severity (no "stale rows in production" surface).
- VCS audit: `svn log | grep "FP-43286"` on both branches confirms intake commits (LBM r15989, MFT r15990 merge of 15989). No additional FP-43286 commits found. Adjacent r15991/r15992 (FP-41845) are unrelated.
- Branch-copy inheritance: r15989 (LBM) > 15942 (LBM-source-rev for MFT branch copy) → not inherited via copy → explicit merge required. r15990 IS the merge. ✓
- HEAD-verification: no follow-up commits touch `AchievementManager.cs` on either branch since the fix. `GameServerCache.cs` has later edits (FP-43334 r16003/r16012 LBM, r16007/r16013 MFT) but on Buoy-related region, not the PondIds region — no conflict with the fix.
- Verified DB state on local Main: `SELECT PondId, IsActive, IsVisible FROM Ponds WHERE IsActive=1` returns pond id=1 as `IsVisible=0`, all other 27 active ponds `IsVisible=1`. Confirms the JIRA-stated mismatch (target=28 was counting test pond; target=27 is intended count).
- Counter side check: `Shared/ObjectModel/Stats/DailyMissionTaskPondStat.cs` → `PondCompleted(pondId)` increments unique-pond-completions, no `IsVisible` filter. Asymmetric vs new target, but harmless: if a normal player visits 27 visible ponds, counter=27=target → complete; if a QA also visits test pond, counter=28 ≥ target=27 → still complete. Pre-fix the player was stuck at counter=27 < target=28.
- Other consumers of `GameServerCache.ActivePondIds` (Tournaments, Leaderboards, Buoy validation, Club events, Together) intentionally NOT switched — they need full active set, not visibility-filtered. Narrow scope is correct.
- `InitializePondIds(Func, Func, Func = null)` backward-compat fallback `loadActiveVisiblePondIds ?? loadActivePondIds` is hit only by 4 test files (`SharedLib.Tests`); production goes through `InitializePondIdsDefault()` with all three loaders. DailyMission test files explicitly pass `() => pondIds, () => pondIds`, so visibility distinction is not exercised in tests — by-design opt-in to old behavior for fixtures with no test pond.
- Cache-invalidation on admin `IsVisible`-toggle: no path exists, but this is pre-existing for `ActivePondIds` (no listener on `IsActive` toggle either). Server restart picks up new state. Pond visibility changes are release-tied (e.g., R202412-DisableAkhtuba), not daily admin actions. Not a finding for this commit.

## Notes

- Backward-compat fallback in `InitializePondIds` is a deliberate minimal-touch decision (avoids editing 4 test files for mechanical noise). Acceptable.
- Cache-invalidation gap on admin `IsVisible` toggle is pre-existing — would route to `modules/missions/backlog.md` if pursued, but the change frequency is too low to justify (only major release-tied edits).

## Verdict

**Approve.** Fix is narrowly scoped, semantically correct, style-consistent with existing `GetActivePondIds()`. DB state confirms the bug shape. Branch-copy inheritance handled correctly via explicit merge. No findings rise to a triage entry; no JIRA reopen required.
