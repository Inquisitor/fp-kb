---
status: resolved
executor: Dmytro Kurylovych (r15625), Yuriy Burda (r16141)
branch: MFT20260325 @ r16141, merged to NPN20260602 @ r16145
jira: https://fishingplanet.atlassian.net/browse/FP-41507
---

# Review: FP-41507 — [Reel of Fortune] Premium spin not unlocked after DLC with premium granted via promo code

## Summary

Bug fix: when a non-premium player receives a DLC bundle that includes a premium subscription (via promo code or WebAdmin product grant), the Reel of Fortune window must immediately allow the premium-tier spin instead of showing "Come back tomorrow". Reported on Steam prod 6.0.1 (51609) / Server prod (15600).

**Two review rounds:**
- **Round 1** (LBM r15625, Dmytro Kurylovych, Apr 2026) — event-based fix, approved (LGTM). See Scope/Findings/Verdict below.
- **Round 2** (MFT r16141, Yuriy Burda, Jun 2026) — QA reopened: admin-tool grant worked, but promo-code DLC still reproduced. Round-1 event hook (`Profile_ProductAdded`) does not fire for products delivered while the player is offline. Round 2 moves the premium re-check into `InitAvailableSpins` (per-reel-open catch-all). See "## Round 2" section.

## Scope

- **LBM20251201 r15625** — `[ReelOfFortune] [Premium] add premium spins for StarterKit with subscription added; add premium spins on product add from WebAdmin`
  - Add premium spins when a StarterKit product containing a subscription is granted
  - Add premium spins when a product is added via WebAdmin

## Investigation Journal

- ⚠ JIRA Executor field (`customfield_11224`) empty; expected = Dmytro Kurylovych (commit author per JIRA comment)
- Branch-copy inheritance: LBM r15625 ≤ MFT base r15942, so the fix is already inherited in MFT (Code) via branch copy — no merge needed up the chain
- Verified `Profile.OnProductAdded` fires AFTER subscription is set in `PutProductToProfileAndLog` (subscription block lines 1300-1323 vs `OnProductAdded` line 1591), so `HasPremium` is true when handler runs ✓
- Verified `TryAddSpinsForPremium` is idempotent (`AvailableSpinsForPremium != null → Error_CantAddSpins`) — no double-credit risk ✓
- `MockReelOfFortunePeer` is no-op for all network methods — safe for offline use ✓
- Looked for other StarterKit offline-grant paths: `TrackedProductDelivery.DeliverProductOffline` exists but has no callers (orphan API), so not a real coverage gap
- code-reviewer agent (deep delegation) confirmed no critical bugs; surfaced F-2 (offline-state side-effect) which I had not flagged

## Findings

### F-1: Operator precedence relies on implicit grouping in `Profile_ProductAdded` [Low]

**Description:** In `Shared/SharedLib/Fortune/ReelOfFortuneAdapter.cs`, `Profile_ProductAdded` uses `A || B && C` without parentheses. Semantically correct (parses as `PremiumAccount || (StarterKit && HasSubscription)` due to `&&` precedence), but a reader has to apply precedence rules mentally, and a future maintainer adding a third disjunct could easily insert it with the wrong associativity.

**Investigation:** File inspection only; intent vs. parsing verified.

**Resolution:** Skipped — semantically correct, style nit. Can be raised inline as a pre-merge polish suggestion if executor wants to amend; not blocking.

**Discovered by:** skill recon + code-reviewer agent (independent confirmation).

### F-2: `adapter.Init()` in offline WebAdmin path mutates `ReelOfFortuneState` as a side-effect [Medium]

**Description:** `WebAdmin/Models/Tools/ToolsModel_Fortune.cs` → `InitReelOfFortuneAdapter` calls `adapter.Init()`, which routes through `Execute("Init", ...)` → `InitAvailableSpins(now)`. When `today != state.LastCheckTime && today != state.LastSpinTime.Date`, the day-rollover block clears `AvailableSpinsForPremium`/`AvailablePremiumGoldenSpins`, resets `DaySpinNumber`/`DayGoldenSpinNumber`/`DayRewards`, increments `GoldenSpinDayNumber`, and re-credits regular spins — all written into the offline profile that is then saved. This means a WebAdmin product grant silently advances the player's reel-of-fortune day. If the admin grants on day X and the player next logs in day X+1, the player's golden rotation has effectively skipped one day vs. the no-grant baseline (rollover would fire again at login). The `Init()` call also pre-reads `FortuneCache.GetRewardsForLevel`, which is why `FortuneCache.InitDefault()` had to be added to `Global.asax.cs`. The bug fix itself works regardless: the constructor's event subscription (`Profile.ProductAdded += Profile_ProductAdded`) is what credits premium spins on the subsequent `OnProductAdded`. So `adapter.Init()` is not required for the fix; it follows the established `InitClubAdapter` pattern.

**Investigation:**
- Read `ReelOfFortuneAdapter.Init` → `Execute` → `InitAvailableSpins` to confirm the mutation surface
- Confirmed `Init()` is not on the critical path for the bug fix (subscription happens in ctor, ProductAdded handler doesn't go through `Execute`)
- Cross-checked `InitClubAdapter` (`ToolsModel_Clubs.cs`) — same pattern (`profile.Init(); adapter.Init();`), so this is the established WebAdmin convention, not a one-off mistake
- Day-rollover impact on `GoldenSpinDayNumber` wraps modulo `daysInRotation` (`ValidateGoldenSpinDay`), so long-term variety isn't broken; only short-term skew

**Resolution:** Accepted for this fix — established WebAdmin pattern (mirrors `InitClubAdapter`), marginal user-visible impact (player may skip one golden-rotation day if admin-grant happens on day X and player next logs in day X+1). Author no longer on the team. Filed to module backlog: [`<kb>/fishing-planet/server/modules/reel-of-fortune/backlog.md`](../../server/modules/reel-of-fortune/backlog.md) for re-examination next time anything in `ToolsModel_Fortune.cs` or the ROF offline path is touched.

**Discovered by:** code-reviewer agent (independent verification flagged the side-effect; I had marked it Info as a duplicate-Init pre-existing pattern — agent's framing is sharper).

### F-3: New `Profile_ProductAdded` branch is not test-covered [Low]

**Description:** `Shared/SharedLib.Tests/ReelOfFortuneTests.cs` — the `AddSubscription(...)` extension hardcodes `TypeId = ProductTypes.PremiumAccount`. None of the existing tests fire `OnProductAdded` with `TypeId = StarterKit && HasSubscription = true`. The new condition (line 71) is therefore untested. Functionally low risk because the credit logic (`TryAddSpinsForPremium`) checks `Profile.HasPremium`, not `TypeId`; but a regression on the condition expression itself (e.g., a future refactor breaking the precedence in F-1) would slip past CI.

**Investigation:** File inspection of `AddSubscription` helper and test methods; confirmed StarterKit branch is unhit.

**Resolution:** Author clarification (no consequences) — recommend adding a `Test_NewSpinsAvailable_OnGetStarterKitWithSubscription` analogous to `Test_NewSpinsAvailable_OnGetPremium`. Module backlog if executor declines.

**Discovered by:** skill recon + code-reviewer agent (independent confirmation).

### F-4: Adapter is never `Dispose()`d in `InitReelOfFortuneAdapter` [Info]

**Description:** The adapter subscribes three events on the offline `Profile` and is never disposed. Currently safe because the request-scoped `Profile` is GC'd shortly after `SavePlayerProfile` returns, taking the adapter with it. `InitClubAdapter` follows the same pattern. Concern is forward-looking: a future caller that retains the profile longer than request-scope would leak event subscriptions.

**Investigation:** File inspection only; cross-checked `InitClubAdapter` for prior art.

**Resolution:** Skipped — no current leak, pre-existing pattern across the WebAdmin codebase.

**Discovered by:** code-reviewer agent.

## Verdict (Round 1)

**Approve.** The fix is correct: the widened condition in `Profile_ProductAdded` plus the new offline adapter init in `ToolsModel_Products.GiveProduct` covers both reported reproducer paths (live promo-code grant via `Profile_ProductAdded` event, and admin-tool offline grant via the explicitly initialized adapter). No double-credit, no missing event listener, no incorrect ordering between subscription and event firing. F-2 accepted as established pattern; remaining findings are polish/info only. JIRA comment: dry `LGTM.` (https://fishingplanet.atlassian.net/browse/FP-41507?focusedId=117083). No merge needed — fix inherited in MFT via branch copy.

> **Round 1 outcome:** QA (Kateryna Kozachenko, 2026-04-29, Steam v6.0.9 test build 16046) found the admin-tool grant works but the **promo-code DLC path still reproduces** (product id 15984 Power Boost Pack). Task reopened → Round 2.

---

## Round 2 — Reopen fix (promo-code / offline-delivery path, MFT r16141)

### Scope (Round 2)

- **MFT20260325 r16141** — `Unlock Reel of Fortune premium spins same day premium is gained (cover product was bought while offline path)`
  - Adds `else → TryAddSpinsForPremium()` branch to `ReelOfFortuneLogic.InitAvailableSpins`
  - Two new unit tests in `Shared/ObjectModel.Tests/Fortune/ReelOfFortuneLogicTests.cs`
- **NPN20260602 r16145** — Merge from MFT r16141

### Investigation (Round 2)

- Root cause: pre-fix `InitAvailableSpins` acted only in the `!HasPremium` branch (removed premium spins). On same-day premium gain via offline delivery, the `!HasPremium` branch is skipped and the daily-reset block is skipped (`today == LastCheckTime` set on the earlier reel-open), so premium spins never get granted until the next day ("Come back tomorrow"). Fix adds `else → TryAddSpinsForPremium()`, which grants immediately because `AvailableSpinsForPremium` is still `null`.
- Why Round 1 missed it: the event hook `ReelOfFortuneAdapter.Profile_ProductAdded` fires only while the adapter is subscribed (player online). Promo-code DLC is delivered offline, so the event never fires for that path. `InitAvailableSpins` runs on every reel open → catch-all independent of how premium was gained.
- Correctness verified: `TryAddSpinsForPremium` guard `AvailableSpinsForPremium != null` blocks same-day re-grant after spending (field becomes `0`, not `null`); `InitAvailableSpins` return value drives only `UserLog` in `ReelOfFortuneAdapter.Execute`, state persists regardless. Both new tests walked step-by-step (incl. interaction with the daily-reset block) — correct.
- No interaction with Round-1 F-2 (day-rollover side-effect in offline WebAdmin path): the new `else` branch does not touch the day-rollover block.
- code-reviewer agent (deep delegation) — no high-confidence issues; confirmed no double-grant, guard sufficiency, test correctness, return-value impact.
- Intake note: JIRA Executor field (`customfield_11224`) empty; Round-2 commit author per JIRA comment = Yuriy Burda.

### Findings (Round 2)

#### R2-F1: Reopen fix not propagated to Stable (LBM = live) [Medium]

**Description:** Round-1 fix (LBM r15625) shipped to Stable/live. Round-2 fix landed only on MFT (Content) → NPN (Code). LBM inherits r15625 but NOT the new `InitAvailableSpins` catch-all, so the promo-code/offline-grant path still reproduces on live until the next release ships. Decision-affecting: if this must close on the current live release, the fix needs merging to LBM as well.

**Investigation:** `svn log | grep FP-41507` — LBM returns only r15625; r16141 present on MFT, merged NPN r16145, absent on LBM. LBM ancestry inherits r15625 (≤ source rev) but not r16141. Offline-path event-hook miss confirmed via `ReelOfFortuneAdapter.Profile_ProductAdded`.

**Resolution:** Accepted — MFT (Content) ships in next week's release; Content→Code is the correct target train. No LBM (Stable) backport needed. Not a code defect.

**Discovered by:** skill recon + code-reviewer agent (independent confirmation).

### Verdict (Round 2)

**Approve.** Minimal, correct, well-targeted: moving premium re-evaluation into `InitAvailableSpins` makes it a catch-all independent of how premium was gained, covering the offline/promo-code delivery path the Round-1 event hook missed. No double-grant, same-day re-grant guard is sound, two added unit tests exercise the fixed path and the guard. Independent code-reviewer agent found no high-confidence issues. R2-F1 accepted (MFT/Content ships next week — correct targeting). No open items.
