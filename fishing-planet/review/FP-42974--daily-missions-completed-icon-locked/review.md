---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15951, merged to MFT @ r15979
jira: https://fishingplanet.atlassian.net/browse/FP-42974
---

# Review: FP-42974 — [Daily Missions] Completed Club/Premium mission icon changes to a padlock

## Summary

Bug: after completing a Club or Premium daily mission, the check-mark icon sometimes changes to a padlock (Locked state) following a pin change or returning to the Globe; the only client-side cure is regenerating missions. Reported on `yellowtest` (Test environment, not prod). Per JIRA comment from Sergii Karchavets, the client side was patched separately (r52871) and the server change ensures `IsCompleted` missions are not also flagged `IsLocked` in `ObjectModel.MissionOnClient`.

## Scope

- **LBM r15951** — Fix completed daily mission may become locked after completion
- **MFT r15979** — Merge from LBM r15951

## Findings

### F-1: Archived/Failed completed Club mission can still ship `IsLocked=true` [Low]

**Description:** `MissionsManager_Client.GetMissionsArchived` and `GetMissionsFailed` (`Shared/ObjectModel/Mission/MissionsManager_Client.cs`) pass the profile entry `pm` to `ConvertToMissionOnClient` and then force `missionClient.IsCompleted = false`. The fix's gate reads `missionInProfile?.IsCompleted` — for archived/failed entries whose stored `IsCompleted=false`, the gate is bypassed and the lock-task LINQ runs against the fresh `Mission`. A previously-completed Club/Premium mission, after the player loses eligibility, can therefore re-emerge in the archived/failed list with `IsLocked=true` even though the active-missions path now reports it correctly.

**Investigation:** Read full `ConvertToMissionOnClient` body. Delegated to `feature-dev:code-reviewer` agent — agent enumerated the 5 producers of `MissionOnClient.IsLocked` (`GetMissionForClient`, `GetMissionsStarted`, `GetMissionsCompleted`, `GetMissionsArchived`, `GetMissionsFailed`, `GetActiveMissionForClient`) and flagged archived path as the only producer that overrides `IsCompleted` post-call without re-asserting `IsLocked`. Verified manually — confirmed the override on archived/failed paths. Visibility on the client (whether the Archived/Failed UI tabs render the padlock) is not verified here — would need client-side check before any patch.

**Resolution:** Pre-existing — pre-dates LBM r15951; fix scope is limited to the active-display bug from FP-42974. Not blocking. Routing to `modules/missions/backlog.md` for follow-up triage.

**Discovered by:** code-reviewer agent.

## Investigation Journal

- Phase 1 intake: executor = Yuriy Burda (per JIRA comment 112113); JIRA `Executor` field set 2026-04-27 to Yuriy Burda — hygiene OK
- Note from user: feature lives on Test environment only, not yet released to prod — relevant for severity calibration; no production data state to backfill
- Triage file in scope: `<kb>/fishing-planet/server/modules/missions/triage-2026-04.md` (release 2026.3 batch). F-1 is pre-existing → routed to module backlog, NOT triage (triage entry rule #2)
- Audited LBM r15900:HEAD and MFT r15943:HEAD via `svn log | grep "FP-42974"` — exactly LBM r15951 + MFT r15979, matches JIRA at face value
- MFT r15979 is content-identical to LBM r15951 (same code + test diff) plus `svn:mergeinfo` property; no additional review needed
- `IsLocked` producer audit (via agent): 5 callers funnel through `ConvertToMissionOnClient` — no parallel serializer paths bypass the fix
- `UserCompetitionPublic.IsLocked` is unrelated (Tournaments domain), excluded from scope

## Verdict

**Approve.** Fix is targeted and correct — `IsLocked` computation moved after profile-state copy and gated on `missionInProfile?.IsCompleted`. Two unit tests added (regression + non-regression) exercise the real `ConvertToMission` rebuild pipeline rather than hand-crafted stubs. F-1 documents an adjacent pre-existing gap on the archived/failed paths but does not block this fix.
