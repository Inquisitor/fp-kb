---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16123
jira: https://fishingplanet.atlassian.net/browse/FP-43904
---

# FP-43904: [FTUE][Tutorial] Reel of Fortune gate vs. tutorial

## Summary

Reel of Fortune (ROF) misbehaves during FTUE:
- **Non-premium**: after passing the tutorial and entering the Global map, ROF appears but the spin fails with `ReelOfFortuneError / Skip_MissionTutorialActive` — the server still treats the tutorial mission as active and blocks the spin.
- **Premium**: ROF appears too early — while still in 3D, right after landing the second fish on Beaver Dam (on reaching level 3), before the tutorial is finished.

Expected: ROF works for both account types, and only appears after the tutorial is passed (or the tutorial mission is manually untracked).

Fix (per executor comment): the old "tutorial-active" ROF gate is replaced with a level-based gate — a new global var `ReelOfFortune.RofMinLevel` (default `4`). Shared fix with linked task FP-43415.

## Scope

> Server-side commit is the review target; client commits noted but out of server-review scope. Audited via `svn log | grep` on MFT — r16123 is the only server commit for FP-43904/FP-43415.

- **MFT20260325 r16123** — Replace ROF gate with RofMinLevel (server, Code branch)
  - `ReelOfFortuneAdapter`: `IS_MISSION_TUTORIAL` (level + active-tutorial-mission check) replaced by `IsReelOfFortuneLocked` (`Level < RofMinLevel`); both gate sites now return `Skip_BelowMinLevel`
  - `GlobalVariablesCache.RofMinLevel` (default `4`); exposed to client vars in `GameClientPeer`
  - SQL patch `MFT.M.2026.05.26-021 [GlobalVariables].sql` — inserts `ReelOfFortune.RofMinLevel = '4'`
  - `GameClientPeer_Game`: removed `CheckForDailyReel()` from the `LevelGained` handler
  - `ReelOfFortuneErrorCode` enum value `6` renamed `Skip_MissionTutorialActive` → `Skip_BelowMinLevel` (numeric value preserved)
  - Tests: setup switched to `RofMinLevel`; added below-min-level skip test
- CodeBranch r54641 — Replace ROF gate with RofMinLevel (client; out of server-review scope)
- Client merge @ r54654 (per Kyrylo Rovnyi comment; client)

## Findings

### F-1: ROF unlock contract now depends purely on level threshold vs. tutorial progress [Low]

**Description:** The gate changed from "tutorial mission active" to a pure `Level < RofMinLevel` check, on both server and client (`RofMinLevel` is pushed into client vars, so the client shows ROF on the same level rule). The whole "ROF only after the tutorial" contract therefore rests on the assumption that the tutorial completes around level `RofMinLevel` (4). Per the bug report a premium account already reaches level 3 inside the tutorial (landing the 2nd fish on Beaver Dam); if premium can reach level 4 before the tutorial ends, the "appears too early" symptom recurs. Conversely, if a non-premium account finishes the tutorial below level 4, ROF stays hidden until level 4 — later than "right after the tutorial".

**Investigation:**
- Read r16123 diff; traced `IsReelOfFortuneLocked => peer.Profile.Level < GlobalVariablesCache.RofMinLevel` in `ReelOfFortuneAdapter`.
- Confirmed `RofMinLevel` is also exposed to the client in `GameClientPeer` (client gates display on the same value) — so client and server agree on the level rule; no client-shows/server-rejects mismatch.
- The remaining variable is purely the tutorial-XP-vs-level curve, which lives in tutorial/balance config, not in this diff.

**Resolution:** Accepted — intentional simplification, coordinated with the FTUE owner; `RofMinLevel` is a tunable global var and QA re-tests both account types. Worth one confirmation at close: does premium reach level 4 only after the tutorial completes (and non-premium reach 4 by tutorial end)? Decision-affecting clarification, non-blocking.

**Discovered by:** skill recon

### F-2: `LevelGained` no longer triggers `CheckForDailyReel` [Info]

**Description:** `GameClientPeer_Game.LevelGained` dropped its `CheckForDailyReel()` call. This stops ROF from popping at the level-up instant mid-3D-session (the premium symptom).

**Investigation:** Grepped all `CheckForDailyReel` call sites — still invoked from `GameClientPeer_Travel` (HandleArriveToRoom / InternalHandleArriveToBase / HandleArriveToPond) and `GameClientPeer_Missions.ActiveMissionChanged`. The daily reel is still granted on arrival/travel and mission-change events, so nothing is lost; only the mid-session level-up trigger is removed, which is the intended behavior.

**Resolution:** Accepted — no regression; aligns with the fix intent.

**Discovered by:** skill recon

## Verification notes

- **Global-var name resolution:** DB key `ReelOfFortune.RofMinLevel` is keyed into the cache as `RofMinLevel` via `GlobalVariablesCache.RemovePrefix` (splits on `.`, returns the suffix); `GetIntValue(nameof(RofMinLevel))` reads it. Admin DB edits take effect (not silently falling back to the code default).
- **SQL patch:** idempotent — guarded by `AppliedPatches` `PatchName` check + `IF NOT EXISTS` on the row; default `4` matches `GlobalVariablesCache.RofMinLevel` fallback.
- **Compile safety:** `IS_MISSION_TUTORIAL` has no remaining references after removal.
- **Enum:** value `6` preserved on rename → wire-compatible; client commit r54641 syncs the client-side enum.
- **Tests:** `CreateProfile` defaults to level 5 (≥ setup's `RofMinLevel=3`), so pre-existing tests stay green; new test exercises the locked path at level 1.

## Verdict

**Approve** (`LGTM.` posted in JIRA by the assignee; issue transitioned). Single, well-scoped, tested commit; root cause (false `Skip_MissionTutorialActive` after tutorial / early premium unlock) addressed by the level gate. No blocking issues.

No server cross-branch merge: source is the Code branch (MFT), which has no upstream merge targets. Client side already merged (r54654).

F-1 (tutorial-completion-vs-level-4 assumption) was surfaced to the assignee; not escalated to JIRA — accepted as a tunable-var / QA matter.

## Investigation Journal

- Executor field (`customfield_11224`) empty in JIRA — executor identified as Yuriy Burda from his commit comment.
- Commit r16123 references both FP-43904 and FP-43415 (shared fix); FP-43415 is linked.
- Mandatory code-reviewer delegation offered; user declined (recon sufficient).
- F-1 routed as decision-affecting clarification for close phase; F-2 accepted inline.
- Close: source is Code branch (MFT) → no upstream server merge; assignee posted `LGTM.` and transitioned the issue, so no review-side JIRA comment was needed.
