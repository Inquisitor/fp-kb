---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15889
jira: https://fishingplanet.atlassian.net/browse/FP-42015
---

# Review: FP-42015 — PO product not shown in POHub after exiting to Globe

## Summary

Bug: an unpurchased Personal Offer (PO) product did not re-appear in the POHub window after the player exited a local map to the Globe, while a previously purchased PO did re-appear. Reproduced on test build 6.0.4 r52059. Root cause and fix attributed by executor to FP-40511, shipped as a single commit in the LBM branch (r15889). FP-42015 itself has no dedicated commit — the bug closes by virtue of the FP-40511 fix.

## Scope

- **LBM r15889** — Fix attributed via FP-40511 (per JIRA comment id 110190). No commit message references FP-42015 directly.

> Source-branch claim ("LBM") and revision ("r15889") taken at face value from JIRA — to be verified in Phase 2 via `svn log` against the LBM branch URL and against the FP-40511 commit content.

## Verification path

Closes via FP-40511 r15889 — there is no FP-42015-specific commit. The fix path:

1. During gameplay, `TimeoutDays` expires for the unpurchased PO chain.
2. `UpdatePersonalOffers` ticks → chain transitions `Expired → Active` (inside `UpdatePersonalOfferState`, ~L580–597).
3. r15889 adds `offer.NotificationState = PersonalOfferNotificationState.NotSent;` at L593, so the reactivated chain becomes "fresh" again.
4. Same `UpdatePersonalOffers` then runs the switch at L249–268 — `case NotSent when offer.Active` fires, and (gated by `CanDisplayPersonalOffersOnCurrentScreen()` and `CanDisplayPersonalOfferPopup`) sets `NotificationState = Scheduled`.
5. Going to Globe satisfies the screen check, popup fires.

Pre-r15889: the reactivated chain stayed at `NotificationState = Sent` from prior popup, so neither switch case (`NotSent when Active` / `Sent when !Active`) fired — popup never re-triggered until next login.

## Cross-branch propagation

- LBM (Content) r15889 → MFT (Code): inherited via branch copy (LBM r15889 ≤ MFT base r15942). Verified by `svn log` on `TargetedAdsManager_PersonalOffers.cs` in MFT — r15889 appears in history.
- KNW (Stable): NOT inherited. Backport decision is open per FP-40511 comment thread (executor asked whether hotfix fix-version warrants KNW merge). Out of scope for code-review approval — release-management call.
- IMV (OldStable): NOT inherited; no merge intent.

## Verdict

**Approve.** Bug closes correctly via the FP-40511 fix path described above. No regressions for surrounding state-machine paths beyond what was reviewed in FP-40511.

Data-transfer plan (per JIRA comment id 103406, Stanislav Rudakov 2026-02-10): GD must reset PO "Reset Date" → QA validates → datatransfer to PROD with next ServerHotfix. Tracked in JIRA, not in this review's scope.

## Investigation Journal

- 2026-04-28 — Card opened. Executor confirmed via `customfield_11224` lookup = Yuriy Burda (matches commit-attribution comment author).
- 2026-04-28 — Phase 2 deferred to FP-40511 review (where the actual diff lives). Verification path traced through `UpdatePersonalOffers` switch and confirmed in FP-40511 review F-2.
- 2026-04-29 — Closed: JIRA comment 117078, status → resolved.
