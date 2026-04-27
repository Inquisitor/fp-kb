---
status: in-progress
executor: Yuriy Burda
branch: LBM20251201 @ r15965, merged to MFT20260325 @ r15966
jira: https://fishingplanet.atlassian.net/browse/FP-42476
---

# FP-42476: [Competitions] [Finishing] Reward windows appears before score window

## Summary

Reward popup windows appeared before the Score window when a competition finished. Server fix:
1. Disable server-side reward announce for the unified tournament/competition flow (client now renders rewards from FinalResults body — coordinated with FP-42448 client-side rework).
2. Add `Storage` to `RewardInventoryItemBrief` and propagate from `ItemReward.Storage` in `RewardUtils.ItemSelector`.
3. Fix `UGCProcess_00_Persistence.LoadRewards` returning the unloaded cache original instead of the populated clone.
4. Attach `competition` to `UserCompetitionException` on `UGCHostSaveCompetition` save errors so the client can identify the offending competition (e.g., `CompetitionWrongNameCustom`).

⚠ Executor field empty in JIRA (expected: Yuriy Burda).

## Scope

- **LBM20251201 r15965** — Disable competition reward announcements, fix reward brief data, add competition itself to UGC creation error
  - `GameClientPeer_Tournaments.cs` — two `announce: true → announce: false` in `ProcessTournamentResult` reward loop
  - `GameClientPeer_UserCompetitions.cs` — `if (ex.Competition == null) ex.Competition = competition;` in `UGCHostSaveCompetition` errorHandler
  - `Reward.cs` — new `StoragePlaces Storage` property on `RewardInventoryItemBrief`
  - `RewardUtils.cs` — `briefReward.Storage = it.Storage;` in `ItemSelector`
  - `UGCProcess_00_Persistence.cs` — `LoadRewards` returns `clonedResult` instead of `result`
- **MFT20260325 r15966** — Merge from LBM20251201 r15965
- **MFT20260325 r15968** — Mergeinfo property fixup (not listed in JIRA comment)

Client (separate scope; reviewer: client team):
- **CodeBranch r52993** — `Reward.cs` mirror: add `Storage` to `RewardInventoryItemBrief`. Yuriy flagged "Needs client merge" — `MainClient` still pending.

## Findings

### F-1: Silent bug fix in `UGCProcess_00_Persistence.LoadRewards` masked by generic commit message [Info]

**Description:** `return result;` → `return clonedResult;` is a real bug fix, not just data hygiene. Before this change, `LoadRewards()` cloned the cached reward, called `LoadRewardViewData(LanguageId)` on the clone, but **returned the original cache object** — so any client requesting UGC reward briefs received items without populated localized view data (Name/ThumbnailBID via `RewardsCache.GetReward(id)` directly). The commit message "fix reward brief data" understates what is in fact a silent data-correctness fix in the UGC creation flow.

**Investigation:** Read `UGCProcess_00_Persistence.LoadRewards` at HEAD; confirmed clone receives `LoadRewardViewData` and is now returned. Sibling files `UGCProcess_*.cs` checked for the same pattern — only `UGCProcess_02_SaveLoadRemove.cs` has a `return result` of unrelated semantics (`result.Length > 0 ? result : null`). No other instances.

**Resolution:** Accepted — fix is correct. Commit-message critique skipped (Info-only signal; not worth a reopen).

**Discovered by:** skill recon, confirmed by code-reviewer agent.

### F-2: `announce: false` applies to Sport and Competition tournament kinds, not just UGC [Info]

**Description:** `ProcessTournamentResult` in `GameClientPeer_Tournaments.cs` runs for all `TournamentKinds` (Sport=1, Competition=3, UserGenerated=4). Both modified `announce:` call sites are in the unconditional reward loop after the kind-specific rating block. JIRA title and description mention only "Competitions", which made this look like a possible scope overshoot affecting Sport reward popups.

**Investigation:** Read `ProcessTournamentResult` to confirm Sport/Competition reach the changed lines (they do). Cross-checked linked JIRA FP-42448 ("Improve competition\\tournament reward window") — Status: Verified, Done. Title and description explicitly cover **both** "tournament" and "змагання", confirming the client-side rework feeds the new reward window from `FinalResults` body for all kinds, not only UGC. Therefore disabling server-side announce for the entire flow is the coordinated change.

**Resolution:** Accepted — intentional and consistent with FP-42448.

**Discovered by:** skill recon, scope-expansion concern raised by code-reviewer agent.

### F-3: `CloneReward()` does not copy `Storage` to `ItemsBrief` — asymmetry with `Items` [Medium]

**Description:** In `Shared/ObjectModel/Common/Reward.cs`, `CloneReward()` clones `this.Items` with `Storage = x.Storage` but clones `this.ItemsBrief` without `Storage`. After the new `Storage` field landed on `RewardInventoryItemBrief`, every clone silently zeroes it (out-of-range for `StoragePlaces` enum: minimum `Equipment = 1`).

**Call site audit** (13 sites, classified by whether `LoadRewardViewData` rebuilds `ItemsBrief` after clone):

- **Covered by rebuild:** `UGCProcess_00_Persistence.LoadRewards`, `LeaguesAdapterExtensions`, `GameClientPeer_Leaderboards` (3 sites).
- **Not covered:** `TournamentEndAdapter:818`, `LeaderboardsAdapter_Global/_Fish/_Competitive`, `RewardUtils.InheritReward`, `DailyMissionGenerator`, `Mission.Clone`, `RewardManager.ProcessReward`, `ListAchievementCommand` (CLI, irrelevant).

**Why Medium and not Low:** `TournamentEndAdapter:818` is exactly the path that feeds `tournamentFinalResult.CurrentPlayerResult.Reward` — i.e., the body the client now reads to render the reward window after `announce: false`. The clone happens inside the `RewardMultiplier > 0` bracket on Competition tournaments, so any item-reward in a bracket-multiplier Competition will lose `Storage` in `ItemsBrief` precisely in the flow this task fixes. Storage being a new field means there's no prior-state regression, but this is incomplete delivery of the same fix that JIRA describes.

**Investigation:** Read `Reward.CloneReward()` — confirmed asymmetry. Greped all 13 `.CloneReward()` call sites. Read each call site to classify rebuild presence. Inspected `TournamentEndAdapter.AssignTournamentReward` — confirmed CloneReward path on Competition+RewardMultiplier branch; clone reaches `tournamentFinalResult.CurrentPlayerResult.Reward` without rebuild. Verified `RewardUtils.ItemSelector` (where Yuriy added `briefReward.Storage = it.Storage`) is only called from `LoadRewardViewData`'s `Brief()` rebuild — not from `CloneReward()`.

**Resolution:** **Blocking** — minimal fix (one line: add `Storage = x.Storage` to the `ItemsBrief` selector in `CloneReward()`) symmetrizes clone with `Items` and closes all 8 unrebuilt paths. Author confirmed reopen acceptable.

**Discovered by:** code-reviewer agent; severity raised after Yuriy's call-site audit + `TournamentEndAdapter` flow trace.

### F-4: JIRA hygiene — Executor field empty + r15968 not listed [Info]

**Description:** `customfield_11224` (Executor) is null. Commit r15968 on MFT (svn:mergeinfo property fix) is not listed in the JIRA comment alongside r15966.

**Investigation:** Read JIRA fields directly (`jq` on raw JSON). Read `svn log -v -r 15968` — modifies only `/branches/MFT20260325` directory entry (mergeinfo property).

**Resolution:** Skipped — both are minor process noise; r15968 is a property fix without code impact.

**Discovered by:** skill recon.

## Investigation Journal

- 2026-04-27: Card created. Pre-flight reads done. JIRA read; Executor field empty — flagged but not blocking. Branch role verified via `_index.md`: LBM=Content, MFT=Code → merge direction Content→Code correct.
- 2026-04-27: Phase 2 audit. SVN audit of LBM/MFT for FP-42476 found extra MFT r15968 (mergeinfo) not in JIRA — captured as F-4. Branch-copy inheritance check: r15965 (15965) > MFT base from LBM:15942, so explicit merge required and present at r15966. ✓
- 2026-04-27: Recon raised two main concerns: (a) hidden bug fix `return result → clonedResult`, (b) potential scope overshoot of `announce: false` to Sport tournaments. Delegated to code-reviewer agent for independent verification.
- 2026-04-27: Agent confirmed concern (b) at code level, raised additional `CloneReward()` Storage asymmetry. Verified concern (b) intentional via cross-read of FP-42448 (Verified+Done, covers both tournament and competition). F-2 collapsed from High to Info.
- 2026-04-27: Verified F-3 — `LoadRewardViewData` rebuilds `ItemsBrief`, mitigates main UGC path. Other `CloneReward()` sites (TournamentEndAdapter, Leaderboards adapters, DailyMissions, Mission, RewardManager) lack the rebuild but are not regressions since `Storage` is a new field.
- 2026-04-27: Re-traced F-3 through `TournamentEndAdapter.AssignTournamentReward` — confirmed Competition+RewardMultiplier path produces `tournamentFinalResult.CurrentPlayerResult.Reward` from `CloneReward()` without rebuild, feeding the same client-side reward window the fix targets. F-3 raised Low → Medium. Discussed offline with executor; reopen agreed.
- 2026-04-27: Reject comment posted ([comment 116560](https://fishingplanet.atlassian.net/browse/FP-42476?focusedId=116560&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-116560)). Transition to reopen done by user out-of-band. Verified MainClient already received CodeBranch r52993 via `kr` at r53103.

## Verdict

**Reject — reopen for F-3 fix.** Author (Yuriy) agreed in offline discussion. F-3 is a one-line symmetry fix in `Reward.CloneReward()`; covers the same flow this task targets.

Other findings:
- F-1 — accepted (hidden bug fix is correct; commit-message critique skipped).
- F-2 — accepted (intentional, coordinated with FP-42448 client work).
- F-4 — skipped (process noise).

Cross-branch on existing commits:
- LBM r15965 → MFT r15966 already merged ✓.
- After F-3 fix lands on LBM, will need explicit merge to MFT (LBM=Content, MFT=Code; merge direction Content→Code).
- Client `MainClient` still pending CodeBranch r52993 — Yuriy's own note; out of scope for this server review.
