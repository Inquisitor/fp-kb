---
status: resolved
executor: Yevhenii Shust
branch: MFT @ r16031
jira: https://fishingplanet.atlassian.net/browse/FP-43407
---

# Review: FP-43407 — Boat rent logs incorrect price in analytics

## Summary

Bug fix: when renting a boat, the SQL Stats analytics table received the wrong amount.
Two call sites in `GameClientPeer_Monetization.cs` passed `price.PricePerDay * daysCount`
to `analytics.LogRentBoat(...)` instead of `fullPrice`. The Trade Log (`DbLog.Trade`) on
the following line already logged the correct `fullPrice`, so the two records diverged:

- Scenario 1 (tournament, hourly rent): analytics logged `PricePerDay × daysCount`, Trade Log logged `PricePerHour × InGameDuration`.
- Scenario 2 (premium, free rent): analytics logged full undiscounted price, Trade Log logged 0.

Reporter (Stanislav) supplied the exact lines and the fix in the JIRA description.

## Scope

- **MFT r16031** — Fixed: pass `fullPrice` to `analytics.LogRentBoat` at both rent sites.

> Branch-copy note: NPN (Code) forked from MFT at r16130; r16031 ≤ r16130, so the fix is
> already inherited into Code via branch copy. No merge to Code needed (verify in Phase 2 / close).

## Findings

### F-1: Out-of-scope `hoursCount` change is a functional no-op [Info]

**Description:** At the tournament call site the executor also changed the 3rd argument of
`analytics.LogRentBoat(...)` from `null` to `profile.Tournament.InGameDuration` (param `hoursCount`).
`AnalyticsAdapter.LogRentBoat` ignores `hoursCount` entirely — it only decomposes `fullPrice` into
`Silver/Gold/ClubTokensSpentInShop` on `AnalyticsDataDto`; `boatId`, `daysCount`, `hoursCount` (3 of 5
params) are all discarded. So the change does not make duration reach analytics; it only alters the
call's appearance. Not a regression (`boatId`/`daysCount` were already dropped pre-fix) and no NRE risk
(`profile.Tournament` is non-null inside the `Profile.Tournament != null` branch). Harmless but
misleading — reads as if tournament hours are now recorded when they are not.

Note: `AnalyticsDataDto` already exposes matching fields — `BoatId`, `Duration`, `ItemCount` — that
`LogRentBoat` leaves unset. So fully recording boat/duration in analytics needs only wiring in the
adapter body (`data.BoatId = boatId; data.Duration = hoursCount ?? daysCount;`), NOT a DTO schema
extension. The executor's JIRA comment ("perhaps this also needs to be added to AnalyticsDataDto")
assumed the fields are absent without checking the DTO — they are present. (DB-column persistence of
these DTO fields not traced in this review.)

**Investigation:** Read `LogRentBoat` body (`AnalyticsAdapter.cs`); confirmed only `fullPrice` flows into the DTO. Confirmed branch guard ensures `profile.Tournament` non-null. Independent code-reviewer agent reproduced the same conclusion (confidence 85).

**Resolution:** Accepted — harmless. If recording tournament duration/boatId in analytics is desired, that is a separate enhancement (extend `AnalyticsDataDto` + `LogRentBoat` body), already flagged by the executor in his JIRA comment.

**Discovered by:** skill recon + code-reviewer agent.

## Notes

- Premium scenario: `fullPrice` now applies `PremiumAccountBoatRentMultiplier` (= 0), so analytics logs 0, matching `DbLog.Trade`. Pre-existing business logic, not introduced here.
- VCS audit: single commit r16031 (yevhenii.shust), branch MFT — matches intake exactly; no missing/extra commits; commit message follows convention.

## Verdict

**approve.** Core bug fixed correctly at both call sites — analytics now logs `fullPrice`, consistent
with `DbLog.Trade` in all three scenarios (tournament hourly, regular daily, premium-free). Only an
Info-level observation (F-1, inert out-of-scope change); no blockers.

## Investigation Journal

- Intake: executor = commit author (Yevhenii Shust) per JIRA comment, not assignee (Stanislav). JIRA Executor field `customfield_11224` empty — detect-only flag.
- ENV in description says `[MFT][CodeBranch]` (April), but role table now has MFT = Content, NPN = Code. Fix committed to MFT (Content); inheritance check applies for Code.
- Description code-evidence header reads "LBM" while fix landed on MFT — reporter copy-paste artifact, not an executor issue. Same bug latent in LBM (Stable) but Content fixes only merge upward to Code; any Stable backport is a separate decision, out of this review's scope.
- F-1 routed to Notes/Accepted (no consequences); underlying analytics-DTO enhancement left to executor's own JIRA comment, not filed defensively.
