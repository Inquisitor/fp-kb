---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15738
jira: https://fishingplanet.atlassian.net/browse/FP-41909
---

# Review: FP-41909 — DAILY MISSIONS: Server - Debug tools tweaks

## Summary

WebAdmin debug tools for daily missions (`Player/DailyMissions`, `Player/Missions`) needed tweaks:
1. Ability to regenerate a single mission instead of all missions.
2. Ability to regenerate a mission while the player is online (or at minimum surface a clear failure when generation is rejected because the player is online).

Implementation routes WebAdmin actions through the Game Server via new `AdminActions`, persists profile state on mission generation, and tightens types in mission-related WebAdmin operations.

## Scope

- **LBM r15738** — Daily-missions debug tooling: AdminActions routing + profile persistence + type hardening
  - Add AdminActions for daily-missions processing on Game Server so WebAdmin actions are supported for online players
  - Save profile on mission generation in `GetTime` so generated missions are reflected in WebAdmin
  - Refactor missions-related WebAdmin operations and models to use proper types (`int` instead of `string`)
  - Handle missing cases of maintaining profile state in consistency with mission context
  - Minor code-style changes

## Investigation Journal

- 2026-04-26 — Card created at intake. Phase 1 completed before any diff/code reading. Sole commit per JIRA comment: LBM r15738.
- 2026-04-26 — Release-status note from user prompt: feature is on Test, not in production. Severity calibration follows FP-42164 lesson (no "existing bad rows" surface for data-integrity findings).
- 2026-04-26 — JIRA hygiene: `customfield_11224` (Executor) empty. Expected value per JIRA comment authorship: Yuriy Burda. ⚠ surfaced, not auto-filled.
- 2026-04-26 — Triage-file `D:/kb/fishing-planet/server/modules/missions/triage-2026-04.md` is already active for the 2026.3 release pass; minor concerns from this review may route there per `memory/batch-triage-mode.md` rules.
- 2026-04-26 — Branch ancestry: r15738 ≤ MFT base-rev 15942 → already inherited via branch copy in MFT (Code). No `svn merge` is required; merge notation will be omitted from JIRA on closure.
- 2026-04-26 — Module clarification (per user): the relevant module is **daily-missions** (generator of daily missions), distinct from `missions` (mission processing/conditions). KB has no `daily-missions/` folder yet; the triage-file `modules/missions/triage-2026-04.md` is mis-located (its H1 reads "Daily Missions"; the existing FP-42372 entry references daily-missions logic). Routing decision deferred to Phase 4 — if pre-existing gaps surface, we choose between creating a stub `modules/daily-missions/` or accepting the existing `missions/` location.

## Findings

### F-1: `new char[';']` typo in `SendMissionAdminActionToPlayer` silently breaks split [Low-Medium]

**Description.** `Shared/SharedLib/Missions/MissionHelper.cs` → `SendMissionAdminActionToPlayer` builds the chat-message payload via:
```csharp
dependencies?.Split(new char[';'], StringSplitOptions.RemoveEmptyEntries)
```
`new char[';']` allocates `new char[59]` (the `';'` literal is implicitly converted to `int` and used as the array length), giving 59 default-initialized `'\0'` characters as the separator set instead of `[';']`. Since input strings do not contain `'\0'`, no split occurs and the entire `";"-joined` payload arrives as a single-element `string[]` on the receiver. The receiver (`MissionsManager_Admin.ProcessMissionAction → "TuneDependencies"`) assigns this directly to `MissionsContext.tunedDependenciesDynamic`, so dependency-monitoring is fed `["a;b;c"]` instead of `["a","b","c"]` — the feature can never match a real mission code.

The previous logic in r15737 lived inside `MissionsManager_Admin.cs` and split correctly: `MissionInstanceId.Split(';').Select(s => s.Trim()).Where(s => !string.IsNullOrEmpty(s)).ToArray()`. So this is a regression introduced when the split was relocated to the helper, plus the `.Trim()` and `IsNullOrEmpty` filtering were also dropped.

**Mitigating context:** the WebAdmin "Monitor" button that triggers `TuneDependencies` is currently HTML-commented in `Missions.cshtml` (`<!--td colspan="3">…<td-->`), so the broken path is unreachable from the UI today. The bug is dormant.

**Investigation.** Read `svn diff -c 15738` for `MissionHelper.cs` and `MissionsManager_Admin.cs`; compared old/new TuneDependencies handling. Grep for `SendMissionAdminActionToPlayer|TuneDependencies` to confirm the only producer is `PlayerController.Missions(POST)` line 883 and the only triggering UI is `Missions.cshtml` lines 16, 211, 270 — all gated behind the commented-out Monitor input. Verified the C# parsing of `new char[';']` (semicolon converted to `int`-sized char array, all-zero) by language semantics.

**Discovered by.** Skill recon (pattern-spot on `new char[char]` syntax during diff read).

**Resolution.** Filed → `modules/missions/triage-2026-04.md`. Author clarification needed (intentional drop of `Trim`/`IsNullOrEmpty`? Monitor UI revival plan?), and the triage meeting decides patch-vs-accept-with-caveat.

### F-2: Dead `Admin_ClearDailyMissions` and empty-stub `Admin_RegenerateDailyMissions` in `MissionsManager_Admin.cs` [Low]

**Description.** The diff adds two `private` methods at the end of `MissionsManager_Admin.cs` (lines 261, 272):
- `Admin_ClearDailyMissions()` — body iterates `AllMissions.Where(m => m.MissionId < 0)` and calls `Core_RemoveStartedMission`.
- `Admin_RegenerateDailyMissions(int? missionId)` — empty body, just `return true;`.

Both are unreferenced anywhere in the codebase (grep on the symbol names returns only the definitions). The actual daily-mission Clear/Regenerate flow lives in the new partial class `DailyMissionAdapter_Admin.cs` and is dispatched from `GameClientPeer_Missions.ProcessMissionAction` via the `dailyMissionActions` HashSet. The stubs in `MissionsManager_Admin.cs` look like an early WIP that was abandoned when the architecture pivoted to the adapter — but were not deleted.

The empty `Admin_RegenerateDailyMissions` is the more confusing of the two: a future reader looking at `MissionsManager_Admin.cs` to understand "how does daily-mission regeneration work" finds an empty stub returning `true` and may believe regeneration is a no-op.

**Investigation.** `Grep -n "Admin_ClearDailyMissions|Admin_RegenerateDailyMissions"` over the LBM tree — only matches are the definitions on lines 261 and 272.

**Discovered by.** Skill recon (the empty stub stood out during diff read; grep confirmed zero callers).

**Resolution.** Filed → `modules/missions/triage-2026-04.md`. Author clarification needed (leftover WIP vs intended call sites elsewhere); triage meeting decides delete-vs-wire-up.

### F-3: Trailing newline missing in `DailyMissions.cshtml` [Info]

**Description.** `WebAdmin/WebAdmin/Views/Player/DailyMissions.cshtml` ends with `}` and no final newline (`\ No newline at end of file` in the diff). Project convention (KB `feedback_trailing_newline.md`) requires files end with a newline.

**Investigation.** File inspection only.

**Resolution.** Skipped — cosmetic file-hygiene; not worth a follow-up commit on its own. If Yuriy patches F-1/F-2, fold in a trailing-newline fix opportunistically.

## Notes

- **Type hardening across the API surface.** The conversion from `string MissionInstanceId / TaskInstanceId / GroupInstanceId` to `int? missionInstanceId / taskInstanceId / groupInstanceId` (with `?? throw new ArgumentNullException`) is a clean refactor — fail-fast at the parse layer instead of `int.Parse` blowing up mid-switch. Caller `PlayerController` updated consistently.
- **Online routing for daily mission admin actions.** New `GameClientPeer_Missions.ProcessMissionAction` dispatches `ClearDailyMissions` and `RegenerateDailyMissions` to `DailyMissionAdapter.ProcessMissionAction`, leaving the rest with the existing `missionsManager` path. This is the headline JIRA #2 fix.
- **Single-mission regeneration.** `DailyMissionAdapter.AdminRegenerateMission(int missionId)` regenerates exactly one mission, replaces it in `Context.CurrentMissions`, moves the old one to `Context.RecentMissions` with `IsRegenerated = true`. Matches JIRA #1.
- **`Context` vs `context` change in `MissionsManager.cs:392`.** `Context` is just the public property over the private `context` field (`MissionsManager_Context.cs:15-34`). Functionally identical when used as a getter — purely stylistic.
- **`Task.WaitAll(Task.Delay(2000))` → `await Task.Delay(2000)`.** Correct fix for a sync-on-async block, made possible by promoting the action to `async Task<ActionResult>`.
- **`force: true` parameter on `TryGenerateMissions`.** Cleanly explicit alternative to the previous "reset GenerationTime to MinValue, then call TryGenerateMissions and rely on `ShouldRegenerateMissions()` to flip" indirection. Used by `AdminRegenerateAllMissions`.
- **`OnceCompletedMissions` cleanup in `RemoveMissionsFromProfile`.** Removing entries from this list erases "ever completed" history for the affected mission codes — appears intentional (admin wants the regenerated mission to be re-completable), but worth being aware of as a side-effect of regenerate/clear.
