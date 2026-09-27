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
- [x] **Fold the zero-score drain into the same detector** (done week-18). The screen now counts unproductive registrations -- no-shows plus zero-score finishes, DQ excluded because it follows a ban. Rule 1(a) now reads rating from *productive* play, so a zero-score finish no longer drags the earnings figure down and makes the drainer look like an honest loser. Measured over August across all three platforms: recall on capable bottom-bracket harvesters 70/109 -> 91/109, nothing lost, about a third more candidates per cycle; a 35% share threshold was tried and rejected. Residual, not covered: a candidate whose net rating is *rising* still fails rule 1(a) whichever route he sheds by -- rule 5 reaches that shape at the MIDDLES/NOOBS boundary and only there (week-20); at any other boundary limb 1(a) must be proved directly from the rating chain.

## Next, before anything else

- [ ] **State the offence formally and collapse the rules into it.** Decided 2026-09-20 after the
  week-20 cycle, where the tribunal acquitted two players at confidence 9 that the operator
  identified by eye in under a minute. The definition:

  > A player holds his matchmaking rating below what he has earned, and collects prizes at that
  > suppressed level.

  Two measured quantities, both already in the screen:
  1. **Suppression** = (rating entering the window + `RatingFromProductivePlay`) − actual rating.
     The gap is accounted for by unproductive participation, which is voluntary.
  2. **Collection while suppressed** = at the moment of a prize, the counterfactual rating sits in
     a higher bracket than the actual one.

  No boundary crossings, no sign of net, no prize flavour, no `MaxRatingAtStart`. Rules 1, 4, 5, 6
  and 9 are all proxies for this measure and each leaks at a different edge: crossings leak on
  boundary-cappers (`CrazyGepard` parks at exactly 100, `HavocHHH` at 988 against a TOPS floor of
  1001 — neither ever crosses), the net sign leaks on risers, prize flavour leaks in the upper
  brackets, and `MaxRatingAtStart` has produced a false bracket claim in three cycles running.

  Validated against the whole week-20 deadline cohort: it reproduces every correct verdict
  **and** catches the two the tribunal missed, while correctly clearing `HalfSand_` (counterfactual
  588 against actual 384..505, same bracket) and `xFenrir77` (TOPS with nothing above).

  What is missing is only the per-prize computation — the counterfactual must be evaluated at the
  moment of each prize, not at the window's end. Inputs exist: `TournamentIndividualResults.Rating`
  per participation plus `TournamentParticipants.CompetitionRatingAtStart`, live tables back ~60
  days and the `Archive*` tables to 2017. One query and one card column.

  This supersedes the "Counterfactual PCR as the displacement measure" item below, which has been
  open since week-14 and is the same idea left unimplemented while the proxies were patched.

- [ ] **Record the boundary-parking shape, and understand why no rule saw it.** Week-20 found it
  five times in one cohort once the card was told to report approach-and-shed instead of
  crossings:

  | | Line | Peak held | Next unproductive entry | Approaches that shed |
  |---|---|---|---|---|
  | `CrazyGepard` | 100/101 | **exactly 100** | same day, 5 no-shows at 2h intervals | 2 of 2 |
  | `Bas_di08` | 1000/1001 | **exactly 1000** | +2.6 h | 4 of 4 |
  | `HavocHHH` | 1000/1001 | 988 | same second | repeatedly |
  | `MP_Alan` | 1000/1001 | 987 | +5.7 h | 5 of 11 |
  | `flacheman2` | 100/101 | 75 | **+12 minutes** | 1 of 1 |

  100 is the highest rating that is still NOOBS; 1000 the highest still MIDDLES. A player who
  stops exactly there and sheds has done the most deliberate thing available to him — and every
  counter we have reads zero, because they all count **crossings** and he never crosses.

  The general lesson is bigger than the shape. **The nine standing rules crystallised out of past
  trial errors, not out of the offence.** Rule 5 came from Kacumi, 6 from KingYakO2, 7 from
  TR-dennisfb, 8 from CreekSamurai, 9 from sandaljepitt — each one a patch for a verdict that came
  out wrong. A rule set built that way can only ever cover mistakes already made visible; it is
  blind by construction to any shape that has not yet produced a noticed failure, and it grows
  monotonically without ever getting closer to describing what the abuse is. Three agents then
  apply that patch list to each case and call the result a trial.

  What was asked for originally was the opposite: give the agents knowledge of what players can
  do, so they recognise behaviour. Restore that. The brief should carry the repertoire (no-show
  flushing, zero-score finishing, climb-and-dump, parking under a line, batch-register-and-abandon,
  farming a weaker field) as described behaviour with worked examples, plus what ordinary play
  looks like, plus the one question the case turns on — not a list of conditions to check.

## Immediate
- [ ] **Counterfactual PCR as the displacement measure.** Replaces the lifetime prize score, which
  is old evidence of skill standing in for current misplacement. Replay the player's rating
  without penalties from unproductive participation — no-shows and zero-score starts, **not** DQ,
  which follows a ban rather than a choice — from matchmaking launch (or a fixed recent window),
  and test, at the moment of each lower-bracket prize, whether that rating would have placed him
  in the bracket above: *prize taken while actual bracket = MIDDLES but unpenalised PCR >= 1001*.
  Aligned week-20 with limb 1(b)(ii), which is computed as entering rating +
  `RatingFromProductivePlay`. Inputs
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
- [ ] **Define the card span by competition start on both edges.** The left edge currently comes
  from the award date in the log while the SQL spine starts at the competition start date, so the
  two disagree. Week-20 result: 6 rows on 5 cards for competitions starting 2026-09-06 whose
  rewards landed on 09-07 — they appear in the ledger with an empty `Registered` because the spine
  never covered them. Harmless that cycle, every one of them sitting in pre-context well outside
  the charge window, but it is the same boundary error the sweep window had. Fix in the generator,
  not by hand-editing cards
- [ ] **One lead sentence for every card.** `Iron.Claw` still opens the ledger with the old
  log-era wording ("N reward entries over the card span") while the other 15 read "N participations
  over the card span, M of them carrying a reward line in the log". His card was the hand-built
  template the rest were generated from and it never got the regenerated lead

## From the week-20 adversarial review (2026-09-20)

Reviewer agent plus Codex, both briefed to refute. Findings already acted on in the same session
are not listed here — they are in the methodology refinement ledger. What remains:

- [ ] **Measure recidivism after a ban expires.** We write our own `banLog` line on every backfill,
  so our prior bans are distinguishable from Support's by the message text. One query over every
  account whose ban has expired — unproductive share and `Prizes_NMT` flavour in the first two
  weeks back. Resumption is a confirmed true positive; a clean return is weak evidence the other
  way. Cheapest instrumentation we have against an unmeasured false-positive rate
- [ ] **Measure false positives properly.** Inject 2-3 negative controls per cycle: non-candidates
  matched on registrations and prize count but with unproductive share 10-20%, cards built
  identically, no marker. Every conviction of a control is a measured false positive. Deferred
  since week-10 while the ban durations doubled
- [x] **Classify absences by presence, not by assumption.** `presence_gaps` added to the parser
  brief in week-20: intervals >= 2h with no log line of any type, each unproductive entry marked
  `in-gap` or `in-presence`
- [ ] **Finish the presence test: dump `CompetitionId -> StartDate` alongside step 3.** The
  week-20 `presence_gaps` field anchors on the ledger timestamp, which is the flush moment, so it
  bounds what can be argued but does not tie an absence to its own competition's start window.
  With the start times a no-show taken while the player was demonstrably active during that
  competition becomes provable, which is what settles the outage defence, the over-registration
  argument and the operator gate together
- [x] **Defuse the urgency that produces overrides.** Settled week-20, and not by a new rule. A
  provisional pre-payout ban was considered and rejected: the irreversible part of the sanction is
  the denied prize, which lands immediately, so "provisional" would have been a name only. A
  Saturday hearing for the risk zone was considered and rejected on operator cost. What the
  urgency actually rested on was a false claim that a prize cannot be recovered — §1.5 now records
  that it can, at the price of manual compensation, and that an undecided case keeps its prize
- [x] **Re-hear after an override** — made standing in week-20 (step 5). Blind re-hearing on the
  full brief, result recorded either way, informs rather than binds; it audits the reason, not the
  outcome, because the reason is what becomes methodology
- [ ] **The leaderboard-urgency criterion is still unwritten.** The week-12 "dreadloc criterion"
  — top-10 presence on the weekly Won board with NOOBS-flavour extraction — has decided 3 cases,
  is not in the standing rules, and a judge expressly rejected it as "not a rule" hours before the
  operator overrode on it. Either write it in or stop deciding on it
- [ ] **Cost of the trial.** 10 of 12 week-19 verdicts are reproducible from 8 columns. Consider a
  deterministic rubric pass first (every limb, both ceiling routes, each rule's fire/no-fire, the
  per-prize counterfactual timeline) and reserve agents for the residual and for proposed
  overrides. Persist prosecution and defence output, not only the judge's — the defence's value is
  currently unmeasurable because its output is discarded
- [ ] **Rebuild the week-18 distribution table.** It is keyed to no-show share over players with
  >= 5 registrations, while the screen gates on unproductive share and cannot reach anyone below
  ~10 events. Rebuild over the population the screen can actually reach and re-read 30% against it
- [ ] **`IsEnded = 1` keeps the screen run-time dependent.** The upper bound halved the problem,
  not removed it: the flag is set by end-processing, so a stalled competition is absent at sweep
  time and present on a re-run
- [ ] **The 2-hour grid is template data, not a system property.** Duration comes from an
  unvalidated template field and the generation anchor is `MAX(EndDate)`, so one off-grid or
  hand-made competition shifts the whole subsequent grid permanently with no warning. The week-20
  `EndDate` agreement depends on the grid holding
- [ ] **Front-loading wins is free.** `CompetitionsWonTs` is overwritten on every win and ordering
  is `Won DESC, Ts ASC`, so at an equal count the player who finished his wins earlier in the week
  takes the higher place. Week-19's cutoff was 3 wins on all 3 platforms. The week-20 conclusion
  that the tie-break is worthless was drawn from the 1-win boundary case, which is the one case
  where it holds
- [ ] **Text hygiene left from the week-20 consistency passes** (reviewer agent + Codex, both run
  after the edits; none of these changes a verdict or reaches Support):
  - SQL header legend still documents `Prizes_NMT` as `Place<=3`; the query now uses
    `Place IN (1,2,3)`;
  - the `BracketCoverage` comment claims DQ is kept out of the comparison. DQ rows carrying a
    place are in fact counted on **both** sides and cancel, so the check is sound and the comment
    is not;
  - §1.5 records that 6 boards pay but gives a reach procedure for `Won` only — the `Rating`
    boards have none;
  - the week-20 ledger row still ends "rule 9's own floor of 10 is live again", which the body
    now correctly denies;
  - step 4's preamble says "five recognised types" over a list of six;
  - glossary "Climb-then-flush" and rule 5's opening prose still say no-show where the operative
    counter is unproductive;
  - the backlog item on the rejected pre-payout ban calls the denied prize "the irreversible
    part", against §1.5;
  - `bans-2026-09-13.md` keeps "the rewrite is not uniformly stricter" after its only example was
    withdrawn. It is false by construction: at 6+ unproductive events and under 15 registrations
    a candidate has fewer than 10 games, so the new counter shelters a strict subset of the old.
- [ ] **Label the expected divergences on the card's cross-check table.** Several rows are
  routinely marked `differs` for benign reasons — registrations because a cancellation leaves the
  ledger but not SQL, net delta because rating application is deferred — which trains the reader
  to ignore the word. (Raised as "the completeness check is one-directional"; that finding was
  **withdrawn** on checking: step 4.5 reads "differs by more than 20% OR by more than 5 absolute
  events", which is symmetric, and the divergences cited were registration counts, not the
  no-show, zero-score and unproductive counts the check compares since week-20.)
- [ ] **The week-18 "brief defect" explanation is single-cause.** seagate22022's first-hearing rule
  5 failure rested on registration timestamps, which the restored flush-moment finding does not
  touch. The 4 -> 9 swing has at least two causes and one was fixed
- [x] **Closed the stale deferred item** for a separate `zero-score-abuse.sql`: week-18 folded
  zero-score into the main screen instead, so it was done by another route (marked in the
  methodology's deferred-refinements section, week-20)
- [x] **Corrected the week-19 record**: `bans-2026-09-13.md` claimed the new rule 3 would shelter
  Lesky2123 where the old counter did not. Both shelter him — `Started` 8 against the old line of
  10, `Registrations` 14 against the new 15. Correction noted in place, week-20
- [x] **`IsResultReviewed` is never set for Competitions** — confirmed week-20 from the code, no
  query needed. The property exists on `TournamentBase` and `TournamentTemplate`, is read in 4
  places in `TournamentEndAdapter`, and is assigned nowhere; it is not on `TournamentDto` and has
  no column. Review is a Sport-tournament concern, so competitions always take the scheduled end
  path and the board row is written `EndDate + 2s`

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
