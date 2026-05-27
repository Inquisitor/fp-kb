---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15889, MFT @ r16117
jira: https://fishingplanet.atlassian.net/browse/FP-40511
---

# Review: FP-40511 — POHub: show only new PO on first login, all PO afterwards

## Summary

Change to Personal Offers (PO) hub window flow: when a new PO triggers on player login, the POHub window must contain ONLY the products of the new offer. After the player closes it, no second window with older PO appears — they continue straight to the next flow (e.g., Welcome Ads). On subsequent logins, behavior reverts to the old one — the POHub window contains all currently active PO products.

Per JIRA comments, this required server-side identification of "new" vs "old" offers (Ivan Dobra → Yuriy Burda handoff at id 107039).

**Two review cycles:**
- **Cycle 1** (LBM r15889, approved 2026-04-29) — see [Cycle 1 sections](#cycle-1-resolved-then-reopened) below.
- **Cycle 2** (MFT r16117) — current. QA reopened: r15889's "show only new" gate did not actually take effect on the login popup (build 16046, Steam v6.0.9 still showed all PO after Welcome Screen). New commit "Defer Personal Offers login popup until login events are processed" addresses the timing.

## Scope

- **MFT r16117** (cycle 2, current) — Defer Personal Offers login popup until login events are processed.
- **LBM r15889** (cycle 1, approved) — Personal Offers: show only new offers on player login if any, otherwise show all offers (old behavior).

## Re-review intake (cycle 2)

QA reopen (Kateryna Kozachenko, comment id 117181, 2026-04-29):
- Env: Steam v6.0.9 (53499), test server build 16046.
- AR: after enabling new PO and entering the game, the post-Welcome-Screen window shows ALL PO (old + new).
- ER: it should show only the NEW PO (old ones not shown in a separate window on first start).

So r15889's `NotSent` gate did not produce the intended "new only" popup at this build. Executor's cycle-2 commit (MFT r16117) "Defer Personal Offers login popup until login events are processed" — hypothesis to verify in Phase 2: the popup was being assembled before login events finished processing, so the `NotSent`/`IsJustLoggedIn` state used by `InitializePersonalOffers` was not yet settled.

### Open questions for Phase 2 (cycle 2)

- Confirm r16117 exists on MFT and matches the commit message.
- Diff inspection: what is the "login events processed" signal it now waits on? How does deferral change the order relative to `InitializePersonalOffers`?
- **Cross-branch direction concern (raise actively):** cycle-1 fix was on LBM (Content); cycle-2 fix is on MFT (Code). Content → Code is the normal merge direction, so a Code-only fix does NOT flow back to LBM (Content) or to the release branches below it. Need to determine which branch the live/release build comes from and whether r16117 must also land on LBM. Build 16046 (where QA tested) must be mapped to a branch.
- Does r16117 supersede or complement the r15889 mechanism? (i.e., is the `NotSent` gate still load-bearing, or did deferral make part of it redundant?)

## Re-review findings (cycle 2 — MFT r16117)

### What r16117 changes

Root cause of the reopen: cycle-1's "new vs old" classification ran inside `InitializePersonalOffers()`, which executes at manager init (`TargetedAdsManager.cs` L77) — **before** login events trigger fresh PO. So the `NotSent`/`IsJustLoggedIn` gate operated on incomplete state, and the popup ended up showing all offers.

r16117 replaces in-place classification with a deferred single-shot popup:
- New per-peer field `_loginPopupPending`. Set `true` at the start of login handling (`TargetedAdsManager_ReceiveEvent.cs` L36, right after the `IsJustLoggedIn` guard).
- `InitializePersonalOffers()`: cycle-1 gate + "show all" fallback **removed**; on login the method validates offers then early-returns without sending (`_personalOffersInitialized = true` moved above the return).
- `UpdatePersonalOffers()`: `if (_loginPopupPending) return;` — during login, Finalize is the sole sender.
- `TargetedAdsManager_SendEvent.cs`: after `ProcessEventsUnsafe()`, if `_loginPopupPending` → call new `FinalizeLoginPersonalOffersPopup()`. In the trigger loop, `TriggerPersonalOffer(ad) && !_loginPopupPending` — triggered offers aren't sent immediately during login.
- New `FinalizeLoginPersonalOffersPopup()`: reads full `Context.PersonalOffers`, computes `popupCandidates` (Active + `CanDisplayPersonalOfferPopup`), `newOffers = candidates where NotificationState != Sent`; pops up `newOffers` if any else all candidates; marks Scheduled → notifies → Scheduled → Sent.

Ordering is now correct: Finalize runs after all login events (incl. triggers) are processed, so it sees the complete offer set. The `Expired → Active` `NotSent` reset from r15889 is untouched and still load-bearing for the reactivation case.

### F-5: cycle-2 fix is on MFT (Code) only; bug was reported/tested on LBM (Content) build 16046 [Medium → Accepted: MFT-only release]

**Description:** r16117 lives only on MFT. QA reopened against build **16046, which is an LBM revision** (verified: r16046 changed paths are under `/branches/LBM20251201/`). LBM HEAD still carries the cycle-1 (broken) logic; MFT HEAD carries cycle-2. Merge direction is Content → Code, so a Code-only fix does **not** flow down to LBM. If the verification/release build for this ticket comes from LBM, the bug persists despite r16117.

**Investigation:**
- `svn log | grep FP-40511` on MFT → r16117 (single commit); on LBM after r15889 → none.
- `svn log -v -r 16046` → paths under `/branches/LBM20251201/` → build 16046 is LBM.
- `svn cat` of `TargetedAdsManager_PersonalOffers.cs` HEAD on both branches: LBM has cycle-1 markers ("Schedule new and restored", "On login with no new offers"); MFT has cycle-2 markers (`_loginPopupPending`, `FinalizeLoginPersonalOffersPopup`). Divergence confirmed.

**Resolution:** Accepted — release ships only from MFT (Code), confirmed by task owner 2026-05-27. The fix is on the correct branch; no LBM backport required. QA must re-test on an MFT build (the original failing build 16046 was LBM and is not the release target). Heads-up (not blocking): LBM still carries the cycle-1 logic in this file; if future content work on LBM ever touches `TargetedAdsManager_PersonalOffers.cs` and merges up to MFT, watch for a conflict/regression on this code — low likelihood since it is gameplay, not content/balance.

**Discovered by:** skill recon (cross-branch audit).

### F-6: `_loginPopupPending` not cleared if `ProcessEventsUnsafe()` throws [Low]

**Description:** In `TargetedAdsManager_SendEvent.ProcessEvents()`, `FinalizeLoginPersonalOffersPopup()` is called after `ProcessEventsUnsafe()` inside the same `try`. If `ProcessEventsUnsafe()` throws, Finalize is skipped and `_loginPopupPending` stays `true`; `UpdatePersonalOffers()` then early-returns on every subsequent call until the next `ProcessEvents()` cycle clears it.

**Investigation:** Read `ProcessEvents()` (L42–58). Confirmed both calls share one try/catch. `FinalizeLoginPersonalOffersPopup()` sets `_loginPopupPending = false` as its first statement, so Finalize throwing does not strand the flag. The stranding is specific to `ProcessEventsUnsafe()` throwing. It is self-recovering: the next `ProcessEvents()` (per-request, frequent in an active session) re-enters, completes `ProcessEventsUnsafe()`, sees the still-set flag, and runs Finalize.

**Resolution:** Accepted with note — consequence is a one-cycle popup delay plus suppressed PO updates in the gap, not a permanent break. A `finally { if (_loginPopupPending) FinalizeLoginPersonalOffersPopup(); }` (or clearing the flag in `finally`) would make it exception-proof, but the self-recovery makes this optional. Worth flagging to executor; not blocking.

**Discovered by:** skill recon.

### F-7: approach abandons cycle-1 in-place gate; `NotSent != Sent` "new" classification [Info]

**Description:** `FinalizeLoginPersonalOffersPopup` classifies "new" as `NotificationState != Sent` (i.e., `NotSent` or `Scheduled`). Freshly triggered offers are `Scheduled` (set in `TriggerPersonalOffer`); reactivated-after-timeout offers are `NotSent` (the r15889 reset); previously shown active offers are `Sent`. So new = fresh+reactivated, old = already-shown — matches the spec. The fallback (no new → show all candidates) preserves the "subsequent login shows all" rule.

**Investigation:** Traced the three `NotificationState` producers (`TriggerPersonalOffer` → Scheduled; `Expired→Active` reset → NotSent; init/send loop → Sent). Confirmed the `!= Sent` predicate maps to spec semantics. Verified the `Expired→Active` reset still present on MFT HEAD.

**Resolution:** Accepted — the deferred-popup approach is a sound fix for the ordering root cause and is cleaner than the cycle-1 in-place gate.

**Discovered by:** skill recon.

### F-8: ~~tournament popup flag slips through Finalize~~ — WITHDRAWN (tournament gate works) [not an issue]

**Original hypothesis (disproven):** a freshly-triggered offer arrives at Finalize already `Scheduled` (from `TriggerPersonalOffer` L75); `CanDisplayPersonalOfferPopup` excludes it from `offersToPopup` but does not reset it, so `NotifyClientAboutTargetedAds` (L371, before the Scheduled→Sent flip) would emit `PersonalOfferShowNotification = true` for a tournament offer.

**Why it is wrong:** the hypothesis requires a `Scheduled` offer to exist during a tournament. It cannot.
- `CheckAdConditions` returns `PlayerInTournament` when `peer.Profile.Tournament != null && !config.ShowInTournament` (`TargetedAdsManager_SendEvent.cs` L470–471).
- `TriggerPersonalOffer(ad)` has a single caller (`TargetedAdsManager_SendEvent.cs` L149), gated by `checkResult == Passed` (L130). During a tournament the result is `PlayerInTournament ≠ Passed`, so no PO is triggered → no `Scheduled`-via-trigger offer exists.
- Existing offers reach Finalize in `NotSent`/`Sent`. For `NotSent`: `popupCandidates` excludes it (tournament) → not in `offersToPopup` → stays `NotSent` → `NotifyClientAboutTargetedAds` sends it with `PersonalOfferShowNotification = (NotSent == Scheduled) = false` → silent, no popup. Correctly gated.

**Not a regression (diff comparison):** for the realistic case (tournament login, existing `NotSent` offer), both versions gate via `CanDisplayPersonalOfferPopup` — cycle-1 in the `InitializePersonalOffers` per-offer gate + "show all" fallback; r16117 in `popupCandidates`. Same gate, same silent result. The only theoretical leak (an offer persisted as `Scheduled` from a prior crashed session) is handled identically — i.e. equally unhandled — in both versions, so it is pre-existing and negligible, not introduced by r16117.

**Resolution:** Withdrawn. The tournament gate is preserved; no action. (The delegated agent's "infinite re-popup" mechanism was also wrong — Finalize's final loop over `allOffers` flips `Scheduled → Sent`.)

**Discovered by:** code-reviewer agent (hypothesis); disproven during verification after task owner flagged the tournament requirement.

## Verdict (cycle 2)

**Code: approve.** r16117 correctly addresses the reopen root cause — the popup is now deferred (`_loginPopupPending`) until login events (including fresh PO triggers) are processed, then assembled once in `FinalizeLoginPersonalOffersPopup` with the complete offer set. The "new = `!= Sent`" classification maps to the spec; the `Expired → Active` `NotSent` reset from r15889 remains load-bearing. Independent agent check found no logic defect after the one hypothesis (infinite re-popup) was disproven.

**F-5 resolved (2026-05-27):** release ships only from MFT — the fix is on the correct branch, no LBM backport needed. QA to re-verify on an MFT build (not the original LBM build 16046). With this, the verdict stands as a clean **approve**.

Non-blocking note for executor: F-6 (clear `_loginPopupPending` in `finally` to be exception-proof). F-8 was investigated and withdrawn — tournament gate verified intact, no regression.

## Investigation Journal (cycle 2)

- 2026-05-27 — Re-review opened after QA reopen (Kateryna, comment 117181, build 16046 Steam v6.0.9). Executor (cycle-2 commit) = Yuriy Burda, confirmed via `customfield_11224`.
- 2026-05-27 — Phase 2: `svn log | grep FP-40511` → MFT r16117 (single commit), none on LBM after r15889. `svn log -v -r 16046` → LBM revision (build QA tested = LBM). `svn cat` HEAD both branches → LBM still cycle-1, MFT cycle-2 → divergence confirmed (F-5). Read full r16117 diff + `InitializePersonalOffers`/`UpdatePersonalOffers`/`FinalizeLoginPersonalOffersPopup`/`ProcessEvents` and call site `TargetedAdsManager.cs` L77. Traced ordering: Init early-returns on login, Finalize runs at end of ProcessEvents after triggers — correct.
- 2026-05-27 — Phase 2 delegation: code-reviewer agent. Surfaced one Medium hypothesis (stuck-`Scheduled` infinite re-popup). Disproven on verification — Finalize's final loop iterates `allOffers` and flips `Scheduled → Sent`. Initially recorded an inverse edge as F-8. Agent confirmed clean on: ordering within the three files, slide-flag correctness, double-send, `TriggerPersonalOffer` short-circuit side effects, `_personalOffersInitialized` move, concurrency (`_syncRoot`-guarded).
- 2026-05-27 — F-8 withdrawn after task owner flagged the tournament `ShowInTournament` requirement. Verified `CheckAdConditions` returns `PlayerInTournament` (≠ Passed) and `TriggerPersonalOffer`'s sole caller is gated by `Passed` → no PO triggers during a tournament → no `Scheduled` offer exists to leak. Existing `NotSent` offers stay silent through Finalize. Compared cycle-1 vs r16117 diffs: tournament gate (`CanDisplayPersonalOfferPopup`) preserved, no regression.

---

## Cycle 1 (resolved, then reopened)

> The sections below are the cycle-1 review of LBM r15889. The verdict (Approve) held for that commit's logic, but QA found the intended behavior did not actually manifest at runtime — see Re-review intake above. Retained as-is for history; cycle-2 findings are appended at the bottom.

### How the fix works

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
