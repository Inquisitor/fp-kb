# FP-43631 — Backlog

## Done
- [x] Discovery SQL drafted, validated against ground-truth (Steam 3 + later `bafa56a3`)
- [x] Threshold calibrated: NoShows ≥ 10, NoShowSharePct ≥ 30, RatingFromNoShow_DQ ≤ -150
- [x] Cohort scan on Steam / PS / Xbox
- [x] Pre-finalization surgical leaderboard ban: 29 abusers (STEAM 13, PS 6, XB 10) → `bans-2026-05-11.md`
- [x] JIRA comment with column reference posted on FP-43631
- [x] **Post-finalize verification** (Query G on `CompetitiveRatingWeeklyHistory` across STEAM/PS/XB): 100% ban success — none of the 29 reached the reward list.
- [x] **Durable account ban** — handed off to Community/Support; they applied `Profiles.IsCompetitionsBanned` with their standard policy. Out of our hands from here.
- [x] **Residual scan** — Query B re-run with relaxed threshold `NoShowSharePct ≥ 30` across STEAM/PS/XB yielded 107 candidates total. Full list shared with Support via the same Google Sheet; ban actions applied by them.
- [x] **Fold the zero-score drain into the same detector** (done week-18). The screen now counts unproductive registrations -- no-shows plus zero-score finishes, DQ excluded because it follows a ban. Rule 1(a) now reads rating from *productive* play, so a zero-score finish no longer drags the earnings figure down and makes the drainer look like an honest loser. Measured over August across all three platforms: recall on capable bottom-bracket harvesters 70/109 -> 91/109, nothing lost, about a third more candidates per cycle; a 35% share threshold was tried and rejected. Residual, not covered: a candidate whose net rating is *rising* still fails rule 1(a) whichever route he sheds by -- rule 5 is what reaches that shape.

## Immediate
- [ ] **Counterfactual PCR as the displacement measure.** Replaces the lifetime prize score, which
  is old evidence of skill standing in for current misplacement. Replay the player's rating
  without no-show/DQ penalties from matchmaking launch (or a fixed recent window) and test, at the
  moment of each lower-bracket prize, whether the no-absence rating would have placed him in the
  bracket above: *prize taken while actual bracket = MIDDLES but no-absence PCR >= 1001*. Inputs
  already exist (`TournamentIndividualResults.Rating` per participation plus the
  `IsStarted`/`IsDisqualified` flags). Note it is a first-order estimate, not a true
  counterfactual — removing the penalties would have changed bracket, opponents and results, so it
  answers "what if he had kept what he earned" and is admissible as evidence, not as simulation.
  Solves the capping case natively: a capper's no-absence rating clears the boundary while his
  actual rating sits below it. Raised in the week-14 Codex review
  (`artifacts/codex-review-2026-08-09.md`)
- [ ] **Re-examine the screening thresholds.** The numbers have been unchanged since week-3 (>= 6
  events, >= 30% share, <= -90 rating, > 3 prizes) even though week-18 changed what is counted,
  which makes them a stable boundary a player can sit just underneath. Loosening catches the careful case at the cost of cohort size;
  quantify the trade-off before changing anything
- [ ] **Check the outage explanation.** A platform or connection incident produces no-shows that
  look chosen. Testable and never tested: whether a candidate's no-show timestamps coincide with
  those of unrelated players. Cheap enough to run as a standing pre-trial filter

## Open questions / Deferred
- [x] **Zero-score policy** — handed off to Community team monitoring; they will raise a separate ticket if abuse pivots from no-show to zero-score.
- [x] **Future no-shows** — Community monitors abuse manually; no proactive detection on our side. Planned mitigations are out-of-scope here:
  - Server-side "consecutive no-show penalty" (idea, no ticket yet) — Community will spawn a ticket if recidivism becomes a pattern.
  - GDD-level: per-bracket prize caps (MaxWins / Max2nd / Max3rd) — natural progression pushes successful abusers out of NOOBS, removing the incentive entirely.
  - Twink/multi-account detection by IP / MAC — separate planned ticket.
- [x] **Mobile / Nintendo passes** — no action until matchmaking ships on those platforms. If structural mitigations (per-bracket prize caps, twink detection) land first, this may never be needed. Otherwise: re-use `discovery-sql.sql` + `weekly-leaderboard-ban.sql` from this task with the appropriate `@WindowStart` per platform launch date.
- [x] **Threshold drift** — Community monitors complaint volume; they will spawn a new ticket (or reopen this one) if the 30% share threshold stops separating signal from noise.

## Out of scope (separate task / GDD work)
- The structural fix (MaxWins / MaxMedals cap per bracket so no-show abuse becomes pointless) is a GDD-level change — separate ticket. This task delivered the *detection + reactive ban* loop only.
