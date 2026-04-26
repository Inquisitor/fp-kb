---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15957, merged to MFT @ r15982
jira: https://fishingplanet.atlassian.net/browse/FP-43186
---

# FP-43186: [Daily Missions] Daily Mission updates occur with a delay when switching between tabs

## Summary

Bug fix for daily-mission refresh at the regeneration boundary. When the player is sitting on `Missions > Daily` and the timer hits zero, new missions do not appear until the tab is switched (sometimes with up to ~20s delay). Test environment (yellowtest) only — not yet in production.

Author's note: server-initiated scheduled regeneration plus an `isFirstIteration` fix; client now receives fresh missions when it polls; a server-side timer adds a safety net (max ~10s expected delay).

## Scope

- **LBM r15957** — Fix daily mission refresh: server-initiated scheduled regeneration, isFirstIteration fix
- **MFT r15982** — Merge of LBM r15957

Note: feature is in Test environment only, not yet released to production.

## Investigation Journal

- Branch-copy inheritance check: LBM r15957 > MFT base rev r15942 → fix not inherited via copy → explicit merge to MFT needed → done at r15982. ✅
- Executor field (`customfield_11224`) on JIRA is empty; commit author is Yuriy Burda per JIRA comment 2026-04-02.
- Hypothesis "isFirstIteration uncomment is risky" disproven: pattern matches `Container_RefreshMissions`, `Container_AddNewMissions`, and `Container_RefreshDailyMission(singular)`. The bulk-version omission was the actual bug.
- Hypothesis "scheduler may double-fire under re-entrancy" disproven: `ExecutionFiber` is single-threaded; `Dispose()` on already-fired schedule is a no-op; idempotent guard `if (dailyMissionRefreshScheduledTime == nextGeneration) return;`.
- F-1 verified via `svn blame` + `svn log -r 15738` + WebAdmin model read; independent reviewer (`feature-dev:code-reviewer`) confirmed and added scope refinement: GetTime is pond-only (early return on `PondTimeSpent == null`), narrowing impact to fishing-at-regen-boundary case.
- Routing: F-1 → triage (`modules/missions/triage-2026-04.md`) — author clarification, decision-affecting.

## Findings

### F-1: `SaveProfileWithLog` removed from Travel.cs `GetTime` reverts FP-41909 WebAdmin-visibility fix; trade-off appears intentional but undocumented [Low]

**Description:** In `Photon/src-server/Loadbalancing/LoadBalancing/GameServer/GameClientPeer_Travel.cs`, `HandleTimeOperation` → `OperationCode.GetTime` case: `SaveProfileWithLog("DailyMissionsGeneratedOnGetTime")` replaced with `DalFactory.GetLogger().Mission.LogAsync(...)`. `SaveProfileWithLog` is `LogProfileSave + SetProfile` (`Photon/.../Common/IGenericPeer.cs:46`), i.e., a real DB persist; `Mission.LogAsync` is log-only. The original save was introduced by the same author at LBM r15738 (FP-41909) with the rationale "Save profile on mission generation on GetTime to reflect generated missions in WebAdmin", because WebAdmin's `PlayerDailyMissionsModel.Load()` reads the profile from DB (`LoadPlayerProfile`) with no in-memory fallback for online players. After this commit, an online player whose daily missions regenerate during the `GetTime` tick won't have the new missions persisted until another save event runs (level-up, balance change, mission completion, session unload, etc.); WebAdmin sees stale state in the meantime. Scope refinement: `GetTime` is pond-only (early returns if `PondTimeSpent == null`), so this affects only players actively fishing at the regeneration boundary.

**Why removal is plausibly intentional (anti-thundering-herd design):** The companion change in this commit — server-side scheduler with `GenerationRefreshJitterSeconds = 10` per-user jitter — exists precisely to avoid a synchronized burst at the daily regeneration moment. `SavePlayerProfile` (`Dal/Sql.MsSql/Profile/SqlProfileProvider.cs:134`) is a full-blob stored-proc write of ~25 columns including four large JSON payloads (`ProfileJson`, `StatsJson`, `FishCageJson`, `DailyMissionJson`); the existing in-code comment at line 143 already flags mass-save pressure ("*On shutdown there is a mass of profiles being saved to DB / Need to increase timeout to make sure all profiles were saved*", timeout bumped to 180s). Wiring a `SaveProfileWithLog` into the scheduler path would have negated jitter's benefit for DB load — 10K concurrent online players × multi-MB profile write spread over only 10s ≈ ~1K writes/sec of large blobs, which is the burst the jitter is supposed to eliminate. Removing the save in `GetTime` follows for design consistency: no regen path triggers a forced full-profile write. Persistence is deferred to the next natural save event.

The `GetTime` path specifically is *not* strictly anti-burst (per-player pond ticks are not synchronized to midnight), so this slice is more about consistency than performance. Either way, the WebAdmin staleness window for an online player at the regen boundary is the trade-off, and it is undocumented in the commit message and in `modules/missions/log.md`.

**Investigation:**
- Read `IGenericPeer.cs:46` → `SaveProfileWithLog` = `LogProfileSave + SetProfile` (real DB write).
- `svn blame -r 15956 GameClientPeer_Travel.cs` → line authored at r15738 by Yuriy Burda.
- `svn log -r 15738` rationale: "Save profile on mission generation on GetTime to reflect generated missions in WebAdmin".
- Read `WebAdmin/Models/Players/PlayerDailyMissionsModel.cs` and `Controllers/PlayerController.cs` → both read profile via `DalFactory.GetProfileProvider().LoadPlayerProfile(...)`, no online-player in-memory branch.
- Read `ProcessMissions(bool, OperationCode?, OperationResponse)` (`GameClientPeer_Missions.cs:937`) → confirmed no profile save (sends data to client only).
- Read `SqlProfileProvider.SavePlayerProfile` (`Dal/Sql.MsSql/Profile/SqlProfileProvider.cs:134`) → full-blob stored-proc write with 4 JSON columns; line 143 in-code comment confirms mass-save is a known pain point with bumped 180s timeout.
- Connected jitter design (`GenerationRefreshJitterSeconds`) to save-removal: if jitter spreads regen across 10s, a per-refresh full-profile save would still cause ~1K writes/sec at midnight peak — consistent with the anti-burst rationale.
- Independent reviewer (`feature-dev:code-reviewer`) confirmed F-1 via direct read of `HandleTimeOperation` and added pond-only scope refinement.

**Resolution:** Triage — confirm with Yuriy that the removal is part of the anti-thundering-herd design (jitter spreads scheduler timing; suppressing forced save avoids midnight DB burst) and that GetTime-path removal is for consistency. On confirmation → Accept and document the trade-off in `modules/missions/log.md` (WebAdmin sees stale daily missions for online players between regen and next natural save event; conscious trade-off vs. mass-save burst). If not intentional → restore the save with a different burst-mitigation strategy (e.g., per-user jitter on the save itself, or only save on `GetTime` since GetTime ticks are already de-synchronized across players).

**Discovered by:** skill recon (verified by `feature-dev:code-reviewer` agent; rationale framing refined after user pointed out jitter's purpose vs. profile-blob save cost).

## Verdict

**Approve, with one triage clarification.**

Core fix is correct and well-shaped:
- `isFirstIteration = true` uncomment in bulk `Container_RefreshDailyMissions` is the right correctness fix; matches the established pattern in sibling refresh methods.
- Server-side scheduler (`ScheduleNextDailyMissionRefresh` / `OnScheduledDailyMissionRefresh`) is a sound safety net: single-fiber execution, correct teardown in `UnloadMissions`, idempotent re-arming guard, deterministic per-user jitter to spread regeneration burst, spontaneous `EventCode.MissionMessage` push to client via the `response == null` branch in `ProcessMissions`.
- Logging normalization across all four generation sources (Init / ForceProcessMissions / GetTime / ScheduledRefresh) is a useful consistency improvement.
- MFT merge identical to LBM commit (only line offsets and `svn:mergeinfo`).
- F-1 (silent FP-41909 regression on the GetTime path) does not block; pending Yuriy's clarification on intent.
