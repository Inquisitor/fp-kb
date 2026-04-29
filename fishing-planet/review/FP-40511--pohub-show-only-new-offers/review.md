---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15889
jira: https://fishingplanet.atlassian.net/browse/FP-40511
---

# Review: FP-40511 — POHub: show only new PO on first login, all PO afterwards

## Summary

Change to Personal Offers (PO) hub window flow: when a new PO triggers on player login, the POHub window must contain ONLY the products of the new offer. After the player closes it, no second window with older PO appears — they continue straight to the next flow (e.g., Welcome Ads). On subsequent logins, behavior reverts to the old one — the POHub window contains all currently active PO products.

Per JIRA comments, this required server-side identification of "new" vs "old" offers (Ivan Dobra → Yuriy Burda handoff at id 107039). Implemented in a single LBM commit.

## Scope

- **LBM r15889** — Personal Offers: show only new offers on player login if any, otherwise show all offers (old behavior).

## How the fix works

`PersonalOfferNotificationState` enum has three states: `NotSent` → `Scheduled` → `Sent` ([TargetedAd.cs L530](../../server/modules/...) — values are `NotSent`, `Scheduled`, `Sent`). The "new offer" identifier is `NotificationState == NotSent` — i.e., not yet shown to the player.

The diff in `TargetedAdsManager_PersonalOffers.cs` makes three coordinated changes to `InitializePersonalOffers()` and the chain reactivation block:

1. **Per-offer scheduling tightened** — was: schedule any active eligible offer on login. Now: schedule only if `NotificationState == NotSent` (i.e., genuinely new). Also adds curly braces (was a one-liner — now compliant with `.editorconfig` `csharp_prefer_braces`).
2. **Fallback "show all" path** — if `IsJustLoggedIn` and no offer was scheduled by step 1 (`.All(o => NotificationState != Scheduled)`), iterate again and schedule every active eligible offer. Restores old behavior when there's nothing new.
3. **Reactivation reset** — in the `Expired → Active` transition (`Expired` case, "Chain reactivated after timeout"), reset `NotificationState` to `NotSent`. This is what closes FP-42015 too — see Findings F-2.

Per spec from FP-40511 description and Stanislav Rudakov's comment 93476, this matches: first PO trigger on login → only new offer; otherwise → all offers.

## Cross-branch propagation

- **LBM (Content) r15889 → MFT (Code)**: MFT base = LBM r15942, so r15889 ≤ 15942 → **inherited via branch copy** in MFT, no merge needed. (Confirmed in `_index.md` → Server Branch Ancestry.)
- **KNW (Stable)**: NOT inherited (KNW base = JLM r14592). Per FP-42015 comment id 110191 (Yuriy Burda), decision pending whether to merge given hotfix fix-version.
- **IMV (OldStable)**: NOT inherited (IMV base = HFH r13732). No merge intent stated.

## Findings

### F-1: Chain advancement transitions do not reset `NotificationState` — likely intentional, worth confirming [Info]

**Description:** In `TargetedAdsManager_PersonalOffers.cs`, three branches transition `PersonalOfferChainState` back to `Active`:

- `Expired → Active` (chain reactivated after timeout, ~L592–593) — DOES reset `NotificationState = NotSent` (the new line in r15889).
- `ChainElementCooldown → Active` (~L527, "Chain element cooldown has passed. Triggering next offer in chain") — does NOT reset.
- `ChainEndCooldown → Active` (~L557, "Chain rerun cooldown has passed. Restarting chain and triggering first offer") — does NOT reset.

After the cooldown advancements, the offer stays at the previous `Sent` state. Consequences:
- On the next login, `InitializePersonalOffers` per-offer loop won't pick it as "new" (NotSent gate) → it falls into the "show all" fallback. That matches the spec ("on subsequent logins, all offers shown").
- During gameplay, `UpdatePersonalOffers` (~L249–268) won't schedule a popup either (no NotSent → Scheduled transition fires when state is Sent and offer is Active).

**Investigation:** Read full method bodies of `InitializePersonalOffers` and `UpdatePersonalOffers`. Walked all `SetState(PersonalOfferChainState.Active)` call sites. Compared spec semantics in FP-40511 description ("on subsequent logins → all offers") vs Expired→Active reactivation case (PO chain expired, now meets re-trigger conditions → it's effectively a fresh chain). Per-element advancement and chain-rerun fall under "subsequent logins" semantics, so absence of NotSent reset is consistent with spec.

**Resolution:** Accepted — the asymmetric reset reads as intentional (full re-run of chain after timeout = new offer; in-chain advancement = continuation of an "old" offer). Worth a short comment in the code so a future reader doesn't propagate the reset to all three sites.

**Discovered by:** skill recon (post-diff full-file read).

### F-2: FP-42015 fix mechanism is the `Expired → Active` reset, not the `IsJustLoggedIn` gate [Info]

**Description:** FP-42015 reproduction has the player exit, re-enter, play until `TimeoutDays` expires (chain reactivates), then go to Globe — at which point the unpurchased PO must re-appear in POHub. The `IsJustLoggedIn` gate is true only at the moment of re-entry; by the time the chain reactivates and the player goes to Globe, `IsJustLoggedIn` is no longer relevant.

The actual fix path for FP-42015:
1. `UpdatePersonalOffers` ticks during gameplay; when `TimeoutDays` expires, the chain transitions `Expired → Active` (line ~580–597) and (post-r15889) resets `NotificationState = NotSent`.
2. The same `UpdatePersonalOffers` then runs the switch at L249–268, hits `case NotSent when offer.Active`, and — if `CanDisplayPersonalOffersOnCurrentScreen()` and `CanDisplayPersonalOfferPopup(offer)` are true — schedules the popup.
3. Going to Globe satisfies the screen check, popup fires.

**Investigation:** Re-read `UpdatePersonalOffers` switch and confirmed that without the NotSent reset (pre-r15889), a reactivated chain would stay at `Sent`, and neither the `NotSent when Active` nor `Sent when !Active` branches would fire — popup would never trigger again until the player re-logs in. With the reset, the popup fires mid-session as expected.

**Resolution:** Accepted — clean. The fix does close FP-42015 as a side effect of the third diff change, not via the login-flow logic. This is consistent with FP-42015 closure path described in comment id 110190.

**Discovered by:** skill recon (cross-ticket trace).

### F-3: No test coverage for `InitializePersonalOffers` or `NotificationState` state transitions [Info]

**Description:** `Grep` for `InitializePersonalOffers` and `PersonalOfferNotificationState` in any `*Test*.cs` returns zero hits. Both the per-offer scheduling gate and the fallback path are uncovered, as is the reactivation reset.

**Investigation:** Searched test projects. No coverage exists today.

**Resolution:** Pre-existing — out of scope for this review. Worth filing on the Personal Offers / TargetedAds module backlog if the team wants to harden against regressions in this area.

**Discovered by:** skill recon.

### F-4: Trailing whitespace after `&&` on line 135 [Info]

**Description:** `if (offer.Active && \n` — trailing space after the `&&` operator before the newline.

**Investigation:** Visible in the diff itself (`offer.Active && ` with a trailing space).

**Resolution:** Skipped — cosmetic, almost certainly invisible to reviewers without diff highlighting.

**Discovered by:** skill recon.

## Notes

- The fallback condition `initializedOffers.All(o => o.NotificationState != Scheduled)` returns true on an empty collection. Benign — inner `foreach` is a no-op. Not worth changing.
- Initial offer creation (`TriggerPersonalOffer`, ~L69) sets `NotificationState = Scheduled` directly, bypassing the new InitializePersonalOffers gate. So a brand-new chain triggered while the player is online doesn't depend on the IsJustLoggedIn flag — it's already Scheduled and will show via the next NotifyClientAboutTargetedAds cycle. Consistent with spec.
- Related JIRA: FP-42015 closes by virtue of this fix (downstream symptom). See [`../FP-42015--pohub-restart-missing-product/review.md`](../FP-42015--pohub-restart-missing-product/review.md).

## Verdict

**Approve.** Fix correctly implements FP-40511 spec via three coordinated changes in a single file. The asymmetric `NotificationState` reset (only on `Expired → Active`) reads as intentional per spec. No regressions surfaced for the `ChainElementCooldown` and `ChainEndCooldown` paths beyond pre-existing behavior. The fix also closes FP-42015 via the reactivation reset path — that connection is sound and verifiable from the diff alone.

Cross-branch: MFT (Code) inherits r15889 via branch copy (LBM r15889 ≤ MFT base r15942) — no merge needed. KNW (Stable) backport is a release-management decision (executor's open question, JIRA comment id 110191) — out of scope for code-review approval.

## Investigation Journal

- 2026-04-28 — Card opened in response to user redirect: original review request was for FP-42015, but FP-42015 has no dedicated commit and is closed via this task's fix. FP-40511 is the substantive review.
- 2026-04-28 — Phase 2: Verified r15889 on LBM (single file: `TargetedAdsManager_PersonalOffers.cs`), executor = yuriy.burda. r15890 unrelated (FP-42232). Read full diff and surrounding `InitializePersonalOffers` and `UpdatePersonalOffers` methods to trace state machine. Walked all `SetState(PersonalOfferChainState.Active)` sites — three exist; only one (Expired→Active) gets the NotSent reset → F-1 raised then accepted as intentional after spec re-read. Traced FP-42015 fix path through `UpdatePersonalOffers` switch — F-2 confirms the Expired→Active reset is what unlocks the popup mid-session. No test coverage found → F-3.
- 2026-04-28 — Phase 2 delegation: code-reviewer agent ran independent check against six concrete concerns (concurrency, `.All()` × invalidEntries interaction, fallback-vs-step1 gate consistency, Expired→Active early-return leakage, Pond Pass `ExpiringByPurchase→Expired` edge, `IsJustLoggedIn` signal validity). All six verified clean against the actual code. Agent additionally confirmed `NotificationState` is serialized (correctly preserved across sessions) and `DeactivatedInternally` is `[JsonIgnore]` (both gates check `offer.Active`, so cross-platform offers excluded from both paths). No new findings surfaced.
