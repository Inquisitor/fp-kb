---
status: resolved
executor: Yuriy Burda
branch: LBM20251201 @ r15950, merged to MFT20260325 @ r15978
jira: https://fishingplanet.atlassian.net/browse/FP-42973
---

# Review: FP-42973 — [Daily Missions] Regeneration of the existing mission becomes unavailable if a player leaves the club

## Summary

Daily Missions: Regenerate-for-1bt button is dead for Club / Premium missions when the player generated them while not in a club, then joined and later left the club (or analogous transitions for Premium). Server returns `InternalServerError` on `RegenerateDailyMission` sub-operation. Fix targets server logic in `LBM` (Content) and is merged up to `MFT` (Code). Bug is reported on the `yellowtest` Test environment — not in production.

## Scope

- **LBM20251201 r15950** — Fix daily mission regeneration denied after leaving club/prem
- **MFT20260325 r15978** — Merge of LBM r15950 into Code branch

## Investigation Journal

- Phase 1 intake: JIRA read; commits taken at face value from executor's comment (Yuriy Burda, 2026-03-30).
- Executor field on JIRA empty — surfaced for triage record, not blocking.
- Branch ancestry (`_index.md`): MFT created at r15943 from LBM:15942. LBM r15950 is **after** the copy point → MFT does not inherit it via branch copy; explicit merge (r15978) is required and present.
- Bug environment: `yellowtest` (Test). Severity calibration: data-integrity findings against historical rows do NOT auto-promote to High — pre-release surface area is empty (see severity-assessment rules).

## Findings

### F-1: Diagnostic log for `not eligible` deny omits `IsLockTaskCompleted` state [Info]

**Description:** The new denial log line in `DailyMissionAdapter.RegenerateMission` records `IsEligible / IsInClub / HasPremium` but not the new `IsLockTaskCompleted` outcome. If a future report says "regen denied even though I was once in the club", the log shows two of three eligibility inputs.

**Investigation:** Read diff; verified the log message in the `!isCurrentlyEligible` branch.

**Resolution:** Skipped — minor diagnostic completeness gap; one-line addition if/when the area is touched again.

**Discovered by:** skill recon

### F-2: `Assert.Inconclusive` in `RegenerateMission_allowed_after_join_and_leave_club` is dead code [Info]

**Description:** The test guards `if (clubMission == null) Assert.Inconclusive(...)`. Fixture (`GenerationSettings.json` Club kind has no `MinLevel`; `BuildProfile` defaults to level 3) guarantees Club mission is generated. The Inconclusive branch is unreachable. If the fixture is ever changed accidentally, the test will silently skip rather than fail loudly.

**Investigation:** code-reviewer agent verified fixture inputs; no conditional path drops Club kind.

**Resolution:** Skipped — cosmetic; no behavioral impact.

**Discovered by:** code-reviewer agent

### F-3: Premium join/leave cycle not test-covered [Info]

**Description:** The fix is symmetric for `DailyMissionKind.Club` and `DailyMissionKind.Premium`, both delegating to the shared `IsLockTaskCompleted` helper. Only the Club case is tested.

**Investigation:** code-reviewer agent verified `HasPremiumCondition` mirrors `IsInClubCondition` exactly, and `DailyMissionUtils.ConvertToMission` creates the lock task for both kinds via the same code path. Implementation cannot diverge between Club and Premium without modifying the helper itself, which is covered by the Club test.

**Resolution:** Skipped — adding a Premium variant would not increase fault detection.

**Discovered by:** code-reviewer agent

## Verdict

**Approve.** Fix is targeted, correct, and aligns server eligibility with client `IsLocked` semantics. Lock-task constant (`Missions_LockedBy`) verified to match between generation site (`DailyMissionUtils.ConvertToMission`) and the new check (`IsLockTaskCompleted`). Diagnostic logging added to all denial branches resolves the original opaque `InternalServerError` symptom. Cross-branch merge into MFT is a clean cherry-pick (identical diff). All Findings are Info-level and Skipped; no blockers.

## Notes

- Bug reported on `yellowtest` (Test). Fix is not yet in production — severity calibrated accordingly.
- Branch-copy inheritance: MFT created from LBM at r15942; fix at r15950 is **after** the copy point, so explicit merge (r15978) was correct and required.
