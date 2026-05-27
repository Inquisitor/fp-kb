---
status: resolved
executor: Yuriy Burda
branch: MFT @ r16105
jira: https://fishingplanet.atlassian.net/browse/FP-43842
---

# FP-43842: [FTUE][Level Up] Incorrect XP values displayed in the Level Up window

## Summary

In the Level Up window the displayed XP values do not include the XP earned for the last caught fish — the catch that actually triggered the level-up. They should include it and match the XP values shown in the profile. Reported on FTUE (STEAM / qa_code_branch / rev. 54204). The bug must also be checked for multi-level-up cases (a single catch crossing more than one level).

QA hypothesis (Sergii Karchavets, client dev): the client reads XP via `PlayerProfileHelper.GetBaseExpInfo(...)` for `_totalXp.text`, and the `EventCode.ExpGain` event seems to arrive *after* `EventCode.LevelGain` — so at the moment the Level Up window is built, the profile XP is stale (last fish not yet applied).

## Scope

- **MFT r16105** — Fix Level Up window showing XP without the last caught fish
  - One-line change in `GameClientPeer_Game.cs`, `NotifyClientAboutLevelGain`: `SendEventImmediate(eventData)` → `SendEvent(eventData)` for the `EventCode.LevelGain` event; comment updated to explain the ordering intent.

## Root cause & fix mechanics (verified)

Client operations are processed in `GameClientPeer.OnOperationRequest` wrapped in `PauseEvents()` … `finally { ResumeEvents(); }`. While paused (`areEventsPaused == true`), `SendEvent` enqueues into `cachedEvents` and flushes (in insertion order) on `ResumeEvents`; `SendEventImmediate` always sends right away, bypassing the queue.

Catch-fish flow: `GameProcessor` (catch) → `GameClientPeer.IncrementExperience(notify: true)`:
1. `NotifyClientAboutExpGain` → `SendEvent(ExpGain)` → enqueued (paused).
2. `foreach gain in newGains` → `NotifyClientAboutLevelGain` → **was** `SendEventImmediate(LevelGain)` → sent immediately, ahead of the still-queued `ExpGain`.

So the client received `LevelGain` before `ExpGain`; the Level Up window read profile XP (`PlayerProfileHelper.GetBaseExpInfo`) before the last fish's XP had been applied → stale value (QA's hypothesis confirmed). After the fix, `LevelGain` is enqueued after `ExpGain` and flushed in order → window shows correct XP.

- **Multi-level-up** (the case flagged in the description): handled — `IncrementExperience` emits a single `ExpGain` then loops over all gained levels/ranks; every `LevelGain` now enqueues after the `ExpGain`.
- **No timing regression**: `ResumeEvents` runs in the same operation's `finally`, so the whole batch still flushes at the end of the same operation — only ordering changes, not perceptible latency.
- **`SendEventImmediate` was not an intentional "immediate" choice**: introduced at r12074 as part of the FP-31046 RewardManager refactor merge (2024), not a deliberate timing decision for the Level Up window.

## Investigation Journal

- 2026-05-27 — Card created (Phase 1). Source branch MFT per JIRA comment (r16105); commit lives on server `MFT20260325` (sibling checkout, readable from disk). The C# in Sergii's comment is client-side context (how the client reads XP for the window), not the fix.
- 2026-05-27 — Phase 2 audit: `svn log -r 15943:HEAD --search FP-43842 -v` on MFT → only r16105, single file `GameClientPeer_Game.cs`; matches JIRA. Diff = one line (`SendEventImmediate` → `SendEvent`) + comment.
- 2026-05-27 — Verified mechanics: read `SendEvent`/`SendEventImmediate`/`PauseEvents`/`ResumeEvents` (`GameClientPeer_Travel.cs`), the `OnOperationRequest` pause wrapper (`GameClientPeer.cs:1196`), and `IncrementExperience` call order (`GameClientPeer_Game.cs:563` — ExpGain at 579 before the level-gain loop at 587). Confirmed event-ordering root cause and multi-level coverage. `svn blame` → line introduced at r12074 (FP-31046 reward refactor merge), not an intentional immediate-send.
- 2026-05-27 — Delegated to code-reviewer agent (independent verification). Agent confirmed all four mechanics against code; the per-gain method is `ProcessLevelingRewardsAndStats` (calls `NotifyClientAboutLevelGain`, single call site). No change-specific regression found. Noted: other `SendEventImmediate` calls reachable during catch (`FlushContextChangesToClient` for Reel/Together/Leagues) carry unrelated event codes, not Level-Up XP. Pre-existing observations (F-1..F-3 below) surfaced; none caused by this commit.

## Findings

All findings are pre-existing and non-blocking — none caused by r16105. Recorded for completeness.

### F-1: No event-ordering test coverage [Low]

**Description:** `LevelingTest.cs` covers `LevelingManager.IncrementExperience` (progression, multi-level, rank cross) but operates below the `GameClientPeer` layer; the `cachedEvents` queue and `SendEvent`/`ResumeEvents` ordering — the exact mechanism this fix relies on — is not unit-tested. A regression that re-introduced immediate send for `LevelGain` would not be caught.

**Investigation:** Read `LevelingTest.cs` (asserts gain counts, no peer/event capture). Verified the ordering path lives in `GameClientPeer_Travel.cs` (`cachedEvents` flush) — testable only via a mock peer capturing the send sequence.

**Resolution:** Skipped — pre-existing gap; the project does not gate bug fixes on coverage, and the fix is correct without it. Could be filed against the leveling/event area if desired.

**Discovered by:** code-reviewer agent (confirmed against recon).

### F-2: Dead commented `PauseEvents()/ResumeEvents()` around the level-gain block [Info]

**Description:** `GameClientPeer_Game.cs` (`ProcessLevelingRewardsAndStats`, ~lines 425-453) carries commented-out pause/resume scaffolding around the `NotifyClientAboutLevelGain` call — leftover from an earlier experiment, not introduced by r16105.

**Investigation:** File inspection only; `svn blame` shows the live `SendEventImmediate` line came from r12074 (unrelated reward refactor), so the commented scaffolding predates this fix.

**Resolution:** Pre-existing — out of scope here. Could be removed in a separate cleanup.

**Discovered by:** skill recon.

### F-3: Nested `IncrementExperience` via level-up reward with `Experience > 0` [Info]

**Description:** A level-up reward whose `Reward.Experience > 0` would, through `RewardManager.ProcessReward` → `PutExpRewardToProfile` → `IncrementExperience(notify: true)`, enqueue a nested `ExpGain`/`LevelGain` between outer gains in a multi-level loop, skewing order. No level-up reward data sets `Experience` today, and the behavior is identical before/after the fix.

**Investigation:** code-reviewer traced the `ProcessReward(..., sendEvent: false)` → `PutExpRewardToProfile` call chain; confirmed no current reward data carries `Experience`.

**Resolution:** Accepted — latent, data-gated, unaffected by this change. Noted only.

**Discovered by:** code-reviewer agent.

## Branch reach

r16105 is on **MFT (Code) only** — new commit (r16105 > MFT copy source r15942), not branch-copy-inherited. The `SendEventImmediate` for `LevelGain` dates to r12074 (2024), so the ordering bug exists on every active branch's GameServer, not just Code. Reported on qa_code_branch; Fix Version `2026.4 FTUE Steam/EGS`. Whether to merge down to Content (LBM) / Stable is a close-phase decision — the Level Up window is not FTUE-specific, so the bug is general, but merge direction is Content → Code (Code does not merge down). Flag for the close phase / team.

## Verdict

**Approve.** The one-line change (`SendEventImmediate` → `SendEvent` for `LevelGain`) correctly fixes the reported bug: under the `OnOperationRequest` event-pause, `ExpGain` was queued while `LevelGain` was sent immediately and overtook it, so the Level Up window read profile XP before the last fish's XP applied. Enqueuing `LevelGain` restores ExpGain→LevelGain order; multi-level-up is handled by construction (single `ExpGain`, then ordered per-gain `LevelGain`s). No timing regression (`ResumeEvents` flushes within the same operation), no change-specific regression found by independent agent review. Findings F-1..F-3 are pre-existing and non-blocking. Open item for close phase: decide Content/Stable reach (bug is general, fix is currently Code-only).
