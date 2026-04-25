---
status: resolved
executor: Dmytro Kurylovych
branch: LBM @ r15615..r15649
jira: https://fishingplanet.atlassian.net/browse/FP-41492
related: FP-40033, FP-43514
---

# Review: FP-41492 — [Missions] [Rewards] completed mission restarted if reward delivery failed

## Summary

Player completed mission #1640 ("Interrogate Krampus Eel Minions") on Nintendo, but reward delivery failed (pondpasses #16028/16029/16030 weren't propagated to the NX platform), causing the mission to restart instead of staying completed.

Two-pronged fix:
1. **Containment** — wrap reward delivery (`RewardManager.ProcessReward`) in try-catch so failures no longer break mission processing.
2. **Prevention** — validate Products/Rewards/Items/Licenses caches against platform/region at startup; surface validation errors in WebAdmin; force lazy-load validation; reorganize cache initialization by dependency levels.

Note on release status: the originating bug came from a Daily Missions event (Krampus Hunt) that lives on Test, but the changes touch the *general* mission/reward delivery path and shared caches — both in production. Release-status gate does NOT apply to this review.

## Scope

### LBM

#### Containment
- **r15615** — [Missions] [Rewards] wrap ProcessReward in Missions into try-catch block
- **r15616** — [WebAdmin] [PlayerTools] make bold Missions link
- **r15617** — [WebAdmin] [MergedLog] highlight MissionException text in log

#### Cache validation (Products/Rewards)
- **r15621, r15626** — [Rewards] [Caches] validate Products/Items in FortuneCache
- **r15622** — [Rewards] [Delivery] use MonetizationCache in RewardManager.ProcessReward
- **r15630** — [Rewards] [Caches] validate Products/Licenses in RewardsCache
- **r15631** — [Rewards] [Caches] validate Products/Licenses/Items for Products in MonetizationCache

#### Validation infrastructure
- **r15632** — [WebAdmin] [Config] add all platforms into DEV web.config
- **r15636, r15638, r15643** — [Server] [Caches] unify caches validation message format; unify affected caches check; use ItemCache in RewardsCache validation
- **r15637** — [Caches] [Validation] add option to force validation of caches in LazyLoad mode
- **r15649** — [Caches] [Validation] invert SkipLazyLoadValidation to have lazy-load validation active by default

#### Cache refactoring (collateral)
- **r15640** — [Caches] fix namespace of EulaCache
- **r15641** — [Caches] simplify DalUtilities.ItemFactory.ItemCategoryCacheFunction
- **r15642** — [Caches] implement ThirdPartAdsCache by separating code from MonetizationCache
- **r15645** — [Caches] sort caches initialization code by dependency levels; add cache dependencies; load all caches in WebAdmin

## Investigation Journal

- 2026-04-25 — Card created at intake; commit list taken from JIRA comments verbatim (15 logical changes, 18 revisions). VCS audit deferred to Phase 2.
- Triage file active: `modules/missions/triage-2026-04.md`. Author-clarification + decision-affecting findings route there; non-decision-affecting → JIRA only.
- Release-status gate: initially proposed to apply (Krampus Hunt is on Test). Corrected by user: only the Daily Missions event lives on Test; the general missions/reward path and shared caches touched here are in production. Gate **does not apply** — severity stands as-is for data-integrity findings.
- 2026-04-25 — VCS audit complete. `svn log --search "FP-41492" -r 15400:HEAD` on LBM working copy returned exactly 18 revisions: r15615/16/17, r15621/22/26, r15630/31/32, r15636/37/38/40/41/42/43/45, r15649. All match JIRA comments — no extras, no omissions. Executor-quality: clean.
- 2026-04-25 — Sequential walk of all 11 logical groups completed. Two findings raised: F-1 (containment narrow-scope; pre-existing for 16 sites; needs author clarification on intent) and F-2 (failure-mode change in `MonetizationCache.GetProduct`; benign alone, compounds with F-1). Several minor observations recorded under Notes.
- Hypothesis "lost IsActive validation in `RewardUtils.ValidateRewards` (r15636)" investigated and disproven: `VW_AllItems` view filters `WHERE i.IsActive = 1` so `ItemCache` never contains inactive items, and `GetItem` returns null for them — validation still detects the case (just merges "not found" / "inactive" into one error message). No regression.
- 2026-04-25 — Independent code-reviewer agent pass run on user request ("надо всё перепроверить"). Results integrated:
  - F-1 confirmed; count corrected from 16 → 15 (TwitchManager has an outer-loop catch — but `MarkTwitchDropDelivered` is still pre-catch and skipped). Per-site exposure grading added.
  - F-2 **refuted** as a failure-mode change. `ProcessProductRewards` already threw `InvalidOperationException` at line 243 on null product *before* r15622. The change is a logging-detail change only. Severity dropped from Low-Medium to Info; combined-with-F-1 amplification claim withdrawn.
  - Independent reviewer also verified: `isTwitchReward` signature inlining (r15636), `Validate()` return-type migration (r15637), ThirdPartyAdsCache extraction ordering (r15642), cache init reorder integrity (r15645), `SkipLazyLoadValidation` inversion (r15649) — no behavioral regressions in any of these.
  - Test coverage gap noted (no unit tests for new validation paths) — consistent with existing pattern in the codebase, pre-existing.
- 2026-04-25 — Per-site deep-dive completed (each of the 15 unprotected `ProcessReward` callers read with surrounding context). Findings split into Cat A (try-catch appropriate, ~8 sites, Low severity), Cat B (abort-on-throw correct; needs transactional design instead of try-catch, 4 sites, Medium severity), Cat C (TwitchManager — outer catch insufficient, needs per-iteration). F-1 severity recalibrated from blanket Medium to Low/Medium split.
- 2026-04-25 — Author unavailable (no longer at company); routing decision made unilaterally by reviewer + user. Cat A+C → new JIRA follow-up ticket. Cat B → KB design debt in newly created `modules/rewards/` (card + log + backlog).
- 2026-04-25 — Branch ancestry verified: all FP-41492 commits (r15615..r15649) ≤ LBM:15942 → inherited via branch copy in MFT (Code branch base rev: 15943). No `svn merge` needed; JIRA closing comment will omit `Merged → MFT` line.
- 2026-04-25 — Closure executed. `modules/rewards/` created (card + log + backlog) to host design-debt entry for the 4 transactional-delivery sites. Filed FP-43514 (Story, assignee Stanislav, "Relates" → FP-41492) for the 8 try-catch retrofit sites + TwitchManager per-iteration refactor.

## Findings

### F-1: Try-catch added only in Missions; 15 other `ProcessReward` call sites unchanged [Pre-existing] [Cat A: Low; Cat B: Medium]

**Description.** r15615 wraps `RewardManager.ProcessReward` in try-catch only inside `GameClientPeer_Missions.cs`. Grep + per-site reading shows 17 call sites total: Missions (now protected), TwitchManager (has an outer-loop catch but post-reward `MarkTwitchDropDelivered` is still pre-catch and skipped on throw), and 15 unprotected callers. Several of them have post-reward state updates that will be skipped on exception. Per-site exposure (verified by independent reviewer pass):

| Call site                                                 | Post-call state at risk on throw                                                                                                         |
|-----------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| `GameClientPeer_Tournaments.cs` (main + secondary winner) | `MarkRewardReceived` skipped + reward writeback skipped → tournament can be re-collected                                                 |
| `GameClientPeer_Leagues.cs` (Champ + Season)              | `SaveProfileWithLog` skipped → profile desync                                                                                            |
| `GameClientPeer_Inventory.cs` (`GiveReward`)              | `SaveProfileWithLog("GiveReward")` skipped                                                                                               |
| `GameClientPeer_Game.cs` (level-up)                       | `NotifyClientAboutLevelGain` + `TargetedAdsManager.LevelGained` skipped                                                                  |
| `ProfileAdapter.cs` (`ClaimReward`)                       | `profile.RemoveReward(rewardId)` skipped → reward stays pending → on retry, items can be granted twice while products keep failing       |
| `AchievementManager.cs`                                   | `NotifyClientAboutAchivement` skipped                                                                                                    |
| `BonusManager.cs` (DailyBonus)                            | `SendEvent(eventData)` skipped                                                                                                           |
| `TwitchManager.cs`                                        | outer catch exists but `MarkTwitchDropDelivered` is between `ProcessReward` and the catch → skipped on throw → re-delivery on next login |
| `PromoCodesManager.cs`                                    | no post-call state                                                                                                                       |
| `AchievementCommand.cs` (admin command)                   | low-severity (admin path)                                                                                                                |
| `TargetedAdsManager_SendEvent.cs` (LoyaltyBonus)          | logging only                                                                                                                             |
| `GameClientPeer_ThirdPartyAds.cs`                         | no post-call state                                                                                                                       |
| `GameClientPeer_Fortune.cs`                               | no post-call state                                                                                                                       |

JIRA decision list (#98703) listed "переглянути аналогічні блоки коду видачі нагороди" as a separate decision item, marked DECIDED. The realized follow-up was preventive (cache validation in r15621–r15631), not containment elsewhere. Cache validation reduces the likelihood of a throw but does not eliminate it (runtime DB exceptions, transient infrastructure failures, malformed runtime data).

The pattern is **pre-existing**, not introduced by r15615. r15615 narrowed the gap (Missions covered) without closing it.

**Investigation.**
- Hypothesis: only Missions wrapped → confirmed by grep `RewardManager\.ProcessReward` (17 hits) + per-site read.
- Hypothesis: post-reward state updates exist at multiple sites → confirmed by per-site reading (Tournaments, Leagues, ProfileAdapter, others above).
- Independent reviewer pass corrected count from 16 to 15 — TwitchManager has an outer-loop catch, but pre-catch state-update is still skipped (separate row above).
- Counter-argument considered: cache validation as preventive measure may suffice in practice. Partial — validation catches startup-time mismatches, but transient runtime exceptions (DB connection blips, deserialization failures, race-condition reads) are not covered by validation.

**Discovered by.** Skill recon (grep + diff comparison against JIRA decision list); independent code-reviewer pass refined the count and per-site grading.

**Severity recalibration after deeper per-site analysis (2026-04-25).** Realistic post-PR throw probability is low — cache validation (r15621/30/31) covers the data-related root cause; only transient DB exceptions / runtime corner cases remain. The 15 sites split into three categories by **whether the same try-catch pattern as Missions is appropriate**:

**Cat A — try-catch is appropriate (post-call state should run regardless; reward is a bonus on top of completed action) [Low]:**
- `GameClientPeer_Game.cs` (level-up) — Profile.ExpToThisLevel already incremented; reward grant secondary
- `AchievementManager.cs` — achievement & stage already updated in profile
- `BonusManager.cs` (DailyBonus) — `RewardDays` counter already incremented; better fix may be reordering counter after reward
- `GameClientPeer_Fortune.cs` (RoF spin) — no post-state but client awaiting result event
- `GameClientPeer_ThirdPartyAds.cs`, `PromoCodesManager.cs`, `TargetedAdsManager_SendEvent.cs` (LoyaltyBonus), `AchievementCommand.cs` (admin) — minor / no post-state
- Caveat: A1/A2 mutate `eventData` inside `ProcessReward` — naive try-catch would let `NotifyClient*` send a partial-reward notification. Fix needs eventData snapshot/restore or skip-notification-on-catch.

**Cat B — try-catch is NOT appropriate; abort-on-throw is the correct current behavior [Medium]:**
- `GameClientPeer_Tournaments.cs` (main + secondary) — `MarkRewardReceived` would fake completion → tournament re-collect on retry, items doubled
- `GameClientPeer_Leagues.cs` (Champ + Season) — `SaveProfileWithLog` would persist partial state
- `ProfileAdapter.cs` (`ClaimReward`) — `RemoveReward` would mark claimed without delivery → reward lost; current abort behavior preserves re-claim, but partial-delivery on re-claim still doubles items
- `GameClientPeer_Inventory.cs` (`GiveReward` admin) — admin grant audit, same pattern
- These need **transactional reward delivery** (decision item #3 in JIRA, never realized), not try-catch retrofit. Separate architectural concern.

**Cat C — `TwitchManager.cs` [Medium]:** has outer-loop catch but `MarkTwitchDropDelivered` is pre-catch and skipped. Correct fix is per-iteration try-catch around the foreach body, not a single outer-loop catch.

**Resolution.** Accept-with-narrow-scope. Author choice was defensible per Cat B reasoning. Decision-item #2 in JIRA was honored as prevention, not containment everywhere — reasonable engineering trade-off given the transactional-delivery scope.

Routing of follow-up:
- **Cat A + Cat C** → file new JIRA ticket "Extend reward delivery resilience" (concrete patches, ~8 sites, manageable scope). Linked from this review.
- **Cat B** → KB design debt in `modules/rewards/backlog.md` ("Transactional reward delivery") — surfaces on next reward incident or monetization architecture work. Module created 2026-04-25 from this review's data.

### F-2: r15622 — error message detail loss on missing product (not a failure-mode change) [Info]

**Description.** Initially flagged as a failure-mode change (DAL returned null → cache throws). Independent reviewer corrected this: `ProcessProductRewards` (`RewardManager.cs:230`) **already threw `InvalidOperationException`** on null products at line 243, *before* r15622. The pre-r15622 path was: DAL returns null → `if (productDto == null)` logs detailed error message ("Error processing reward. Product #X for lang Y and platform Z not found!") + throws. The post-r15622 path: cache throws directly with a different message ("Cached products #X not found for language Y") and bypasses the verbose log.

Net effect: **logging detail change only, not exception propagation change**. The `if (productDto == null)` branch is unreachable in cache-populated apps (Game, WebAdmin), but reachable in apps using the DAL fallback inside `MonetizationCache.GetProduct` itself (lines 571–578, used when `MultilingualProducts == null` — i.e., apps that do not call `MonetizationCache.InitDefault()`, such as Master/Club/AsyncProcessor).

**Investigation.**
- Initial hypothesis: r15622 changes failure mode null→throw — partially confirmed (cache throws), but **disproven for caller propagation**: `ProcessProductRewards` already had `throw new InvalidOperationException(message)` at line 243.
- Verified by reading `RewardManager.cs:237-244` (current state) — explicit throw on null-product branch.
- Combined-with-F-1 amplification claim: refuted. The 15 unprotected sites were already exposed to this throw before r15622; r15615/r15622 do not change their exposure level.

**Discovered by.** Skill recon, refuted by independent reviewer's reading of `ProcessProductRewards`. Recorded as Info to document the flagging-then-refutation cycle.

**Resolution.** No action. The change is an error-message-format change, not a behavioral change.

## Notes

- **Hardcoded whitelist by name in MonetizationCache.ValidateProducts (r15631).** `IgnoreValidateProducts = ["Mega Bass Bundle"]` matches by product name, fragile to renames. Comparable list `IgnoreValidateLicenses = [240, 250 /* Akhtuba */]` correctly uses IDs with comments. Style-only — not a finding.
- **WebAdmin startup time impact (r15645).** WebAdmin now loads many more caches than before (per JIRA #99089: "WebAdmin initializes all caches to run validation for all of them"). Mitigated in DEBUG by enabling `LazyLoad` + `SkipLazyLoadValidation` in `CachingDebugConfig` (r15649). Production WebAdmin: slower startup, broader validation coverage. Trade-off accepted.
- **Validation linear search performance (r15636).** `RewardUtils.ValidateRewards` uses `rewards.Values.Any(r => r.Name == ...)` and `RewardsCache.TwitchRewards.Cache.Values.Any(r => r.RewardId == ...)` instead of pre-built HashSets/dictionaries. O(n²) on reward count. Acceptable because validation runs at startup / cache refresh, not in the hot path.
- **Removed verbose `Log.Info("X initiated!")` in init paths (r15645).** Slight loss of init-progress observability, but errors still surface via `Caches.OnLoadException` / `Log.Error`. Cleanup, not a regression.
- **`MonetizationCache.GetProduct` strict throw vs `GetProductBrief` returns-null on missing product** — the two helpers have inconsistent failure modes. Validation code uses `GetProductBrief` (returns null), runtime `ProcessReward` uses `GetProduct` (throws). Asymmetry is documented here for future readers. Not action-needed.
