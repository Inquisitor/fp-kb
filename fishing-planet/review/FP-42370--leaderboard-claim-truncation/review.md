---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15934
jira: https://fishingplanet.atlassian.net/browse/FP-42370
---

# Review: FP-42370 — [Leaderboards] Monthly Top 100 reward Claim window doesn't close

## Summary

On Test, when a player claimed the Monthly Top 100 Rating Leaderboard reward, the reward window did not close after pressing Claim and an error appeared in the player log, although the reward (item + premium) was granted. Per executor: rewards that contain a loot table are logged separately into the Stats `LootTableStats` table, and a column was too narrow, so the insert raised an error that broke the Claim response that should close the window.

Feature is on Test environment, not production yet.

## Scope

- **LBM r15934** — Fix leaderboard reward claim error due to LootTableStats column truncation
  - Stats server DB pre-updated (column width increased), so no release step needed

## Investigation Journal

- 2026-04-26: Phase 1 intake — branch (LBM) and commit (r15934) taken from executor's JIRA comment as-is per Phase 1 protocol.
- 2026-04-26: VCS audit on LBM and MFT (URL-based `svn log` over `r15000:HEAD` grepped for `FP-42370`). Only `r15934` references the ticket on either branch. No unposted commits. (`svn log --search` returned empty in both WC and URL modes — fell back to `svn log | grep`; suspect known `--search` quirk when WC mergeinfo is sparse, not specific to this ticket.)
- 2026-04-26: Inheritance check on MFT (Code) — MFT base is LBM:r15942, so r15934 ≤ 15942 → inherited via branch copy (no merge required). Closure comment will omit `Merged → MFT`.
- 2026-04-26: Hypothesis "what column truncates" — original schema (`BRA.S.2021.09.29-010`) has `Source varchar(32), SourceId varchar(32)`. `Source` is fed `BalanceMovementType.ToString()`; longest leaderboard-related enum is `CompetitiveLeaderboardReward` = 28 chars (within 32). `SourceId` is fed `entityId`, which for leaderboard claims is `message.Period.CompositeId`. CompositeId chains 3-4 fragments (`{TournamentKind}{DimensionType}{Type}#{PeriodId}` for Competitive) and easily exceeds 32. Conclusion: truncation hits `SourceId`, not `Source`. Patch widens both to 64 — covers the symptom and gives headroom.
- 2026-04-26: Convention check — sibling `SqlAnalyticsProvider.cs` already uses `try/catch (Exception) { Log.Error(e); }` around fire-and-forget inserts (e.g., `SaveActionStats`). New try/catch in `SqlLootTableLog.Log` matches that convention; `Logger.Error` includes `userId, source, entityId, ex` for diagnosis.
- 2026-04-26: Side-effect-on-old-bug hypothesis — checked `RewardManager.ProcessReward` (no `IsRewardGiven` gate before reward application) and `ProfileAdapter.ClaimReward` (`profile.RemoveReward(rewardId)` is AFTER `ProcessReward`). In the old code, `Loot.Log` threw at the END of `ProcessReward` (after item+premium delivery, after `MarkRewardGiven`); the propagating exception skipped `RemoveReward`, so the deferred reward stayed in `GivenRewards`. A retry would re-run `ProcessReward` → double-deliver item/premium. JIRA description reports single delivery, suggesting QA didn't retry. Stale `GivenRewards` entries on Test profiles could re-deliver on next Claim after the fix lands. Surfaced as F-1 (Info, QA verification).
- 2026-04-26: SQL patch sanity — file `LBM.S.2026.03.18-011 [LootTableStats].sql` matches naming convention (Branch=LBM, DB=S, Date=2026.03.18, Seq=011, Topic=[LootTableStats]); PatchName inside (`LBM.S.2026.03.18-011`) matches without `[Topic]` suffix. Idempotent via `AppliedPatches` gate; `ALTER COLUMN` is itself a no-op when column already at target width.
- 2026-04-26: User declined code-reviewer agent — small commit, hypotheses already verified via direct file reads.
- 2026-04-26: User dismissed F-1 — QA regenerate Test profiles multiple times daily, so any pre-fix orphan `GivenRewards` entries are unlikely to persist long enough to matter. Single delivery on Test is acceptable. F-1 dropped to Skipped; JIRA comment trimmed to dry LGTM.

## Findings

### F-1: Old failure may have left orphan `GivenRewards` on Test profiles — possible double-delivery on next Claim [Info]

**Description:** In the pre-fix code, `Loot.Log` threw at the very end of `RewardManager.ProcessReward` — after item/premium delivery and `MarkRewardGiven` (lines 73-130 of `RewardManager.cs`). In `ProfileAdapter.ClaimReward` the call sequence is `RewardManager.ProcessReward(...)` then `profile.RemoveReward(rewardId)`; the propagating exception skipped `RemoveReward`, so the deferred reward stayed in `GivenRewards`. `ProcessReward` does not gate on `IsRewardGiven` before reward application, so a retry from the affected player would re-run delivery and double-grant the item/premium. JIRA description reports a single delivery, suggesting QA did not retry the broken Claim. After the fix lands, the truncation no longer occurs and any orphan `GivenRewards` entries left from earlier failures will be successfully removed on next Claim — but the trailing reward delivery would still be the *second* one for that player.

**Investigation:**
- `RewardManager.ProcessReward` (`RewardManager.cs`) — line 130 `Loot.Log` is the last statement; no `IsRewardGiven` check before reward application.
- `ProfileAdapter.ClaimReward` (`ProfileAdapter.cs`) — `profile.RemoveReward(rewardId)` runs AFTER `RewardManager.ProcessReward(...)`. `MarkRewardGiven(reward.RewardId)` inside ProcessReward records history but doesn't gate the next delivery.
- `Profile_Rewards.cs` — `GetReward(Guid id)` returns the deferred reward by Guid; `RemoveReward(Guid id)` removes it; no automatic cleanup elsewhere.

**Resolution:** Skipped. Per user: QA regenerate Test profiles multiple times per day, so any orphan `GivenRewards` entries from pre-fix failures are unlikely to still exist. Pre-existing gap (no `IsRewardGiven` gate inside `ProcessReward`) is out of scope.

**Discovered by:** skill recon

## Verdict

LGTM. Fix is correct and defense-in-depth: column widening (Source/SourceId 32 → 64) addresses the immediate truncation root cause for leaderboard claims, where `entityId` is `Period.CompositeId` (a 3-4 fragment chain that exceeds 32 bytes for Monthly Top 100 Rating). The added `try/catch (Exception) { Logger.Error(...) }` makes `LootTableStats` insertion fire-and-forget, matching the convention already used in `SqlAnalyticsProvider`. SQL patch follows project naming and is idempotent via `AppliedPatches`.

