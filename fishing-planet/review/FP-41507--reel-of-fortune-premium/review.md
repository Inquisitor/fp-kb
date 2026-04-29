---
status: resolved
executor: Dmytro Kurylovych
branch: LBM20251201 @ r15625
jira: https://fishingplanet.atlassian.net/browse/FP-41507
---

# Review: FP-41507 — [Reel of Fortune] Premium spin not unlocked after DLC with premium granted via promo code

## Summary

Bug fix: when a non-premium player receives a DLC bundle that includes a premium subscription (via promo code or WebAdmin product grant), the Reel of Fortune window must immediately allow the premium-tier spin instead of showing "Come back tomorrow". Reported on Steam prod 6.0.1 (51609) / Server prod (15600).

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

## Verdict

**Approve.** The fix is correct: the widened condition in `Profile_ProductAdded` plus the new offline adapter init in `ToolsModel_Products.GiveProduct` covers both reported reproducer paths (live promo-code grant via `Profile_ProductAdded` event, and admin-tool offline grant via the explicitly initialized adapter). No double-credit, no missing event listener, no incorrect ordering between subscription and event firing. F-2 accepted as established pattern; remaining findings are polish/info only. JIRA comment: dry `LGTM.` (https://fishingplanet.atlassian.net/browse/FP-41507?focusedId=117083). No merge needed — fix inherited in MFT via branch copy.
