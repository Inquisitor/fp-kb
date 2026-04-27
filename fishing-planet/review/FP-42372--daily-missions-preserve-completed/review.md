---
status: in-progress
executor: Yuriy Burda
branch: LBM @ r15868, r15878
jira: https://fishingplanet.atlassian.net/browse/FP-42372
---

# Review: FP-42372 — Daily Missions: Server — do not delete completed missions

## Summary

Bug fix for Daily Missions lifecycle. Two issues addressed:

1. Completed missions from the current batch were being dropped from the client-visible set. Now they are preserved on the client as completed.
2. When a player was offline across a regeneration window, old missions stayed in `AllMissions` and were briefly shown to the player. Regeneration is now sequenced earlier so stale missions are evicted before the client gets the data.

Feature is pre-release (Test environment); `Fix Version = 2026.3 Leaderboards`, scheduled 2026-04-29.

## Scope

- **LBM r15868** — Leave completed missions from current batch of missions as completed on client
  - `MissionsManager.cs`: added `else if` branch to remove completed (but not archived) missions from `AllMissions` during the mission-replacement pass
  - `MissionsManager_Client.cs`: removed `mission.MissionId < 0` filter from the completed-missions-in-profile projection
- **LBM r15878** — Reorder mission regeneration to run before `InitMissionsManager`
  - `GameClientPeer_Missions.cs`: moved `DailyMissionAdapter.TryGenerateMissions()` call to before `InitMissionsManager()` / `ConnectMissionsManager()`

## Findings

### F-1: Asymmetric lifecycle cleanup between archived and completed [Info]

**Description:** r15868 removes completed missions from `AllMissions` at daily refresh, while archived missions (handled by `Api_ArchiveMission`) stay in `AllMissions` with `IsArchived=true`. Only `Container_RemoveMission` (cancel) and the new r15868 code perform `AllMissions.Remove`; archival does not.

**Investigation:** File inspection of `MissionsManager_Archived.cs` (`Api_ArchiveMission`) and `MissionsManager.cs` (`Container_RemoveMission`, new r15868 block). Grepped `AllMissions\.(Remove|Add|Clear)` across the module.

**Resolution:** Accepted. Asymmetry is coherent with restart-eligibility: archived missions can be restarted via `Api_RestartArchivedMission`, which needs the object present; completed missions (non-multi-start) cannot restart and are safe to drop.

**Discovered by:** skill recon.

### F-2: `AllMissions.Remove` bypasses `Container_RemoveMission` cleanup [Low-Medium]

**Description:** The new code does `AllMissions.Remove(missionToRemove)` directly. The existing `Container_RemoveMission` also cleans `MissionsReadyToStart`, `GlobalMissions`, hints, and monitoring registrations. For standard daily missions (non-multi-start, non-global) the leaks do not materialize — but the pattern is design-fragile: if daily missions ever become `IsGlobal=true` or `IsMultiStart=true`, the direct `Remove` silently strands state in those collections.

**Investigation:**
- Verified `Core_CompleteMission` in `MissionsManager_Complete.cs` already cleans started-state and hints at completion time, so by refresh-time the mission has no live subscriptions for typical dailies.
- However, `Api_RemoveCompletedMission` (called for `IsMultiStart` missions on completion) re-registers monitoring and re-adds to `MissionsReadyToStart`. For a multi-start daily that then hits `Container_RefreshDailyMissions`, the raw `Remove` would orphan those entries.
- `GlobalMissions` is populated in `Container_AddNewMission` for `IsGlobal` missions; the raw `Remove` leaves entries there.

**Resolution:** Blocking — patch required. Replace `AllMissions.Remove` with `Container_RemoveMission`, or introduce a narrow `Container_RemoveCompletedMission` helper that skips the `MissionCancelled` event.

**Discovered by:** skill recon + agent exploration.

### F-3: r15878 reorder has implicit null-check dependency, no comment [Low]

**Description:** Moving `TryGenerateMissions()` before `InitMissionsManager()` works only because `DailyMissionAdapter.GenerateAllMissions` guards `missionsManager.Container_RefreshDailyMissions(...)` with `if (missionsManager != null)` (line 191 in `DailyMissionAdapter.cs`). The call site in `InitMissions` has no comment or assertion noting this order dependency. A future refactor that makes `TryGenerateMissions` assume a non-null `missionsManager` would silently break the offline-regen scenario this commit fixes.

**Investigation:** Read `DailyMissionAdapter.TryGenerateMissions` and `GenerateAllMissions`; grepped `missionsManager\s*[=!]=\s*null` in the adapter — 5 null-guarded call sites.

**Resolution:** Skipped — the null-guard at the call site in `DailyMissionAdapter.GenerateAllMissions` makes the ordering tolerance obvious from the code; a comment would be WHY-noise per the "comments only for non-obvious intent" preference.

**Discovered by:** skill recon.

### F-4: Only `GetMissionsCompleted` historically had the `MissionId < 0` filter [Info]

**Description:** The filter that r15868 removes (`|| mission.MissionId < 0 return null`) existed only in `GetMissionsCompleted`. Siblings `GetMissionsStarted`, `GetMissionsArchived`, `GetMissionsFailed` never had it. `MissionId < 0` is the convention for runtime-generated missions (dailies use negative IDs via `Interlocked.Decrement`), so the filter was specifically excluding daily missions from the completed view while letting them through started/archived/failed views.

**Investigation:** Read all four methods in `MissionsManager_Client.cs`. Negative-ID convention confirmed in `MissionsContext.GetNextMissionId` (agent found).

**Resolution:** Accepted — removal is correct. Observation useful as a hint that the filter was a symptomatic patch for a bug that is now being fixed properly. No action.

**Discovered by:** skill recon.

### F-5: `Container_RefreshDailyMissions` does not acquire `lockObject` [Low, pre-existing]

**Description:** Other `Container_*` methods in `MissionsManager` (`Container_AddNewMission`, `Container_RemoveMission`, `Container_RefreshMissions`) enter `lock (lockObject) { ... }`. `Container_RefreshDailyMissions` does not. r15868 adds direct mutation (`AllMissions.Remove`) in this unlocked method, which is consistent with the existing `foreach (...) { Api_ArchiveMission(...) }` already mutating indirectly, but inconsistent with sibling-method discipline.

**Investigation:** Grepped `lock\s*\(lockObject` in `MissionsManager.cs` — 5 hits, `Container_RefreshDailyMissions` absent.

**Resolution:** Pre-existing gap. In the peer execution model, mission mutations likely run single-threaded per peer (ExecutionFiber), so the absence is probably safe in practice — but the pattern diverges from siblings without explanation. Worth filing as a separate cleanup if consistent locking is a goal. Not blocking this review.

**Discovered by:** skill recon.

### F-6: No tests accompany the fix [Low]

**Description:** Both commits touch mission lifecycle. `svn diff -c 15868 --summarize` and `svn diff -c 15878 --summarize` show only production files changed — no test additions. `MissionsTests.cs` and `DailyMissionsPerformanceTests.cs` do not cover `GetMissionsCompleted` or `Container_RefreshDailyMissions` paths.

**Investigation:** Grepped the test project for `GetMissionsCompleted|RefreshDailyMissions|IsCompleted.*AllMissions` — no matches.

**Resolution:** Pre-existing test gap. r15868's correctness is subtle (two independent-looking changes wire together) — exactly the kind of change that benefits from a regression test. Worth noting to the author, not blocking given pre-release status.

**Discovered by:** skill recon.

### F-7: Silent no-op when a code in `removingMissionCodes` is not in `AllMissions` [Info]

**Description:** `Container_RefreshDailyMissions` does `var missionToRemove = AllMissions.FirstOrDefault(...); if (missionToRemove is { ... })` — if the lookup returns null, both branches fail silently, no log. This is a pre-existing behavior not introduced by the fix.

**Investigation:** File inspection of the method body before and after the diff.

**Resolution:** Accepted. Likely covers benign cases (concurrent regen, already-removed mission). Could warrant a `Log.Debug` for observability but not actionable here.

**Discovered by:** manual scan.

## Investigation Journal

- 2026-04-24: Card created post-intake, pre-exploration, per updated process draft.
- 2026-04-24: Explored lifecycle via agent + targeted reads. Initial hypothesis "fix creates dead zone" proven wrong — r15868 is two independent changes (client filter + server cleanup) that solve distinct problems. Findings F-1 through F-7 compiled.
- 2026-04-24: F-2 moved to `modules/missions/triage-2026-04.md` (batch-triage mode) for Monday review with Yuriy. F-5 and F-6 moved to `modules/missions/backlog.md` as pre-existing module gaps. F-1, F-4, F-7 accepted inline.
- 2026-04-24: Verified r15868 and r15878 are on LBM at revisions ≤ r15942 (MFT copy source) — both inherited into MFT via branch copy at r15943. No merge action needed. Confirmed by reading `svn log` on `MissionsManager.cs` in MFT — r15868 appears in history.
- 2026-04-27: After release-triage discussion with author, F-2 escalated to Blocking. Patch expected — replace raw `AllMissions.Remove` in `Container_RefreshDailyMissions` with `Container_RemoveMission`, or introduce a narrow `Container_RemoveCompletedMission` helper that skips the `MissionCancelled` event. Rejection comment posted to JIRA; review back to in-progress until patch lands.
