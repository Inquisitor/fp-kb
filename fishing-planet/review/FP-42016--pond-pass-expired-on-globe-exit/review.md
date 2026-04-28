---
status: in-progress
executor: Yuriy Burda
branch: LBM @ r15935
jira: https://fishingplanet.atlassian.net/browse/FP-42016
---

# FP-42016: [PondPass] Expired Pond Pass record stays in player profile after exit to Globe

## Summary

When a player is on a pond and their Pond Pass expires while still in the local map, exiting to the Globe leaves the (now-expired) Pond Pass record in **Active Level Unlocks** in the WebAdmin profile view. Other paths (re-login, pond switch, certain other exits) cleaned up — only the menu exit-to-Globe path missed cleanup.

The fix has two parts:
1. **Imperative cleanup** at `InternalHandleArriveToBase` — calls `Profile.OutdateLockRemovalAndLog()` which mutates `LevelLockRemovals`, removing entries where `EndDate < UtcNow`. This is what closes the reported admin-display bug (admin reads `LevelLockRemovals` directly via `LevelLockRemovalsModel.Init`).
2. **Defensive read-side filter** in `Profile.UnlockedPonds` getter — skips entries where `EndDate <= UtcNow`. Affects `UnlockedPonds` consumers (mission conditions, targeted ads, unlock checks). Not needed for the admin view fix; an unrelated correctness improvement.

## Scope

- **LBM r15935** — Fix expired pond pass records not removed from profile on exit to Globe

> Branch-copy inheritance: MFT (Code) was created at r15943 from LBM:15942. r15935 ≤ 15942 → already inherited in MFT. No merge to MFT needed.
> Stable / OldStable: not in scope. Bug originally reported on test/qa with client r52059 (above Stable's r52058 pin) — Content-level fix.

## Findings

### F-1: Second pond-exit path misses cleanup [Medium]

**Description:** `GameClientPeer.RequestMissionResult` handler (`Photon/src-server/Loadbalancing/LoadBalancing/GameServer/GameClientPeer.cs`, around the `case ProfileSubOperationCode.RequestMissionResult` block, lines ~1951-1990) sets `Profile.PondId = null` and persists the profile via `SaveProfileWithLog("RequestMissionResult")` under `transactionLock` — but does NOT call `Profile.OutdateLockRemovalAndLog()`. If a Pond Pass expires during a mission/day and the player ends the mission via the EOM flow, the same observable admin-display bug reproduces. The fix at `InternalHandleArriveToBase` covers only the menu exit-to-Globe path.

**Investigation:**
- Recon scan of `OutdateLockRemovalAndLog` callers ran; missing call at `RequestMissionResult` not initially noticed.
- code-reviewer agent flagged the gap; verified independently by reading `GameClientPeer.cs:1951-1990`. The save runs under `transactionLock` with `Profile.PondId = null` at line 1977 — no `OutdateLockRemovalAndLog` call before save.
- Mission-end is a plausible user flow when the Pond Pass expiration coincides with day-end; reproducibility depends on client routing the EOM via `RequestMissionResult` rather than `MoveToPond`.

**Resolution:** Question to executor — was `RequestMissionResult` considered? If intentional, accept; otherwise extend the fix with a single `Profile.OutdateLockRemovalAndLog()` next to `Profile.PondId = null`. Reopen-pending until clarified.

**Discovered by:** code-reviewer agent, verified manually.

### F-2: No tests added [Low]

**Description:** The fix lands without test coverage. `Shared/ObjectModel.Tests/LevelLockRemovalTests.cs` is the natural home — already tests `LevelLockRemoval` with `EndDate` boundary cases (unlimited / limited / outdated). Two tests would lock in both halves: `UnlockedPonds` filter behavior (skip expired, keep `EndDate == null`, keep future) and `OutdateLockRemoval` removal (expired entries removed, others kept).

**Investigation:** Read `LevelLockRemovalTests.cs:1-80` — fixture setup is light, no DB; adding tests is ~5-10 min.

**Resolution:** Skipped — note as observation; project does not enforce test-coverage gate for bug fixes. If module backlog desired, can be filed against `LevelLockRemoval` area.

**Discovered by:** code-reviewer agent.

### F-3: Two unrelated changes in one commit [Info]

**Description:** Part 1 (imperative cleanup at exit) fixes the reported admin-display bug. Part 2 (read-side filter on `UnlockedPonds`) is an unrelated correctness improvement for game-logic consumers (`MissionsContext`, `TargetedAdsManager_*`, `HasUnlockCondition`). The two could have been split.

**Resolution:** Accepted — process note only. Bundled scope is small, both changes share the underlying "expired LevelLockRemovals shouldn't be active" theme.

## Notes

- ⚠ JIRA `customfield_11224` (Executor) is empty — expected: Yuriy Burda (commit author of r15935).
- Boundary `EndDate == UtcNow`: `OutdateLockRemoval` keeps it (`<` predicate), `UnlockedPonds` skips it (`>` predicate). Tick-level inconsistency, no practical impact.
- `PaidLockRemoval` has no `EndDate` field (`Shared/ObjectModel/Profile/PaidLockRemoval.cs`) — paid unlocks are permanent; no symmetric filter needed in `UnlockedPonds`. Not a missed case.
- Read-side filter (Part 2) does not regress any consumer — all checked use sites treat absence in `UnlockedPonds` as "not unlocked", which is correct semantics for expired.

## Verdict

**Approve with question.** The reported bug is closed correctly along the menu exit path. F-1 (RequestMissionResult gap) is a related-surface concern requiring author confirmation: extend the fix or document why that path is unaffected. F-2/F-3 are observations.

## Investigation Journal

- 2026-04-28 — Card created (Phase 1). Source branch confirmed via JIRA comment; ancestry check shows r15935 already inherited in MFT.
- 2026-04-28 — Phase 2 audit: `svn log | grep` confirmed r15935 is the only FP-42016 commit on LBM; same r15935 visible in MFT via branch-copy. No discrepancy with JIRA.
- 2026-04-28 — Diff read; recon scan over `OutdateLockRemovalAndLog` callers, `UnlockedPonds` consumers, `LevelLockRemovals` admin-side reads. Verified WebAdmin reads `LevelLockRemovals` directly (not `UnlockedPonds`); confirmed `PaidLockRemoval` has no `EndDate`.
- 2026-04-28 — Delegated to code-reviewer agent. Agent identified `RequestMissionResult` as a second pond-exit path missing cleanup → recorded as F-1. Agent's tests-missing observation → F-2. Agent's split-commit observation → F-3.
