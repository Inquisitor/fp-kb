---
title: FP-43631 — Rating-drop abuse detection & ban methodology
purpose: Self-contained operational playbook for the weekly FP-43631 cycle. Hand-off ready.
jira: https://fishingplanet.atlassian.net/browse/FP-43631
---

# FP-43631 — Rating-drop abuse detection & ban methodology

## Overview

Players exploit the matchmaking system (launched 2026-04-29) by registering for Competition-kind
tournaments and not showing up, accruing `NoShowRatingPenalty` to deflate their `CompetitionRating`
(PCR) and dropping into the easier **NOOBS bracket [PCR 0-100]** where they farm low-difficulty
prizes. The MIDDLES bracket is **[101-1000]**, TOPS/MASTERS is **[1001+]**.

The task runs as a **weekly loop**: a Sunday sweep across three platform PROD databases selects
candidates from the past week's competitions, each candidate is reviewed from a trajectory card,
competition bans land through SQL equivalent to the WebAdmin action, three persistence layers are
verified, and the Community/Support team gets the same cohort as a sheet.

All times are UTC and written with a Z suffix: 22:00Z.

## Domain glossary

- **PCR** — `Profiles.CompetitionRating` (int). The deflated value is the exploit lever.
- **Bracket** — NOOBS (PCR 0-100), MIDDLES (101-1000), TOPS / MASTERS (1001+). These are the
  standard bands; a competition may configure its own via `MinRating` in its grouping JSON.
- **`TournamentParticipants.BracketId` is NOT the rating band** *(established week-17)*. It is the
  bucket the player ended up in once matchmaking had balanced the field at competition start.
  Everyone starts in the bucket matching his own band, then undersized buckets pull participants
  from their neighbours, and a bucket still short of `MinSize` merges — with the nearest stronger
  bucket by preference, with the weaker one only when there is no stronger. So a strong player can
  legitimately appear in bucket 1: week-17 found a rating of 20562 there. Agreement with the
  standard bands runs about 92% and concentrates its misses in thin or oddly-configured
  competitions. See `<kb>/fishing-planet/server/modules/matchmaking/_card.md` and the FP-41746 GDD.
  **Consequence for this task**: `BracketId` is usable as a cohort-level signal and must not carry
  an individual verdict. Derive the bracket from `CompetitionRatingAtStart` instead — it is exact
  where present, but it is **not always present, prize rows included** *(corrected week-20)*.
  `AppL33` in week-19 carried `Started` 26 against a split of 24 and `TotalPrizes` 4 against a
  split of 3; the unclassified prize was the NOOBS one, taken on the account's first event at
  PCR 0. The gap runs one way: a row with no rating at start is an early event, and early events
  are bottom-bracket by definition, so what drops out of the split is the aggravating half — and
  the wrong figure reached Support unflagged. The screen's `BracketCoverage` column reports the
  shortfall and the parser fills it from the ledger PCR chain (step 4). The `Played_NMT` and
  `Prizes_NMT` columns were computed from the label up to and including week-14; where the two
  disagree the label **overstated** the share won in the bottom bracket.
- **No-show** — `TournamentParticipants.IsStarted = 0`. Player registered, did not start. Penalty
  is applied to PCR regardless.
- **Batched-flush group** — multiple `Tournament reward Competition #X added CompetitionRating`
  ledger entries logged at the same exact second timestamp. Mechanically this is the server
  reconciling queued offline penalties on next login. Useful signature when paired with intent
  evidence (climb-then-flush, NOOBS-bracket prize concentration).
- **Climb-then-flush** — PLAYED entry pushes PCR into MIDDLES, followed within hours by NO-SHOW
  entries dropping it back below 100. The classic bracket-farming move.
- **MIDDLES → NOOBS drop** — single **unproductive** entry, no-show or zero-score, where
  `pcr_before >= 101 AND pcr_after <= 100` *(boundary corrected week-20: NOOBS is 0-100 inclusive
  and MIDDLES starts at 101, so a 110 -> 100 move is a drop and a 100 -> 95 move is not. The old
  `>= 100 / < 100` form counted NOOBS-internal moves and missed real crossings; harmless while the
  field was descriptive, load-bearing now that rule 5 fires at exactly 2. Widened week-20; the
  parser has counted both since
  week-18 and the card reports the split)*.
- **Stale flag** — `IsCompetitionsBanned = true` with `BanEndDate` in the past OR NULL. The
  canonical game-engine check `ProfileLogic.IsCompetitionsBannedNow()` is the AND of
  `IsCompetitionsBanned = true` AND `BanEndDate > now` — null/past BanEnd means **not effectively
  banned**. See `<memory>/feedback_competitions_banned_semantic.md`.

## The weekly cycle — step by step

The cycle runs Sundays. Window is the prior Mon-Sun (e.g. week-7 sweep on 2026-06-21 covered
2026-06-15 → 2026-06-21). Ban effective date is Monday-aligned.

### 1. Detection query

The detection query is a broad first pass: it selects more accounts than will be banned and hands
every one of them to the review.

Run `artifacts/detection-screen.sql` on each platform PROD MAIN after 22:00Z on Sunday, with
`@WindowStart` set to the window's Monday 00:00Z and `@WindowEnd` to the following Monday 00:00Z.

The week's last competition ends at 22:00Z and its prizes land seconds later; an earlier run can
miss an account whose fourth prize came in that slot. An earlier run is for orientation only; the
cohort is the run after 22:00Z.

**The window is bounded at both ends and selects on `EndDate`.** A competition belongs to the week
in which it ends, and that matches the leaderboard: `UpdateCompetitiveLeaderboards()` derives the
period from `UtcNow` when the row is written, and the scheduled end path writes it 2 seconds after
`EndDate` (the deferred review path does not apply to `KindId = 3`). The two differ only under a
processing stall. Selecting on `StartDate` would take a different set: it pulls in the Sunday
22:00Z competition, which belongs to the next week, and drops the previous Sunday's. The upper
bound is required: without it the result depends on when the query is run. Re-check this match if
the competition grid or the end-processing path changes.

Screening criteria:

- `Unproductive >= 6` — registrations that produced no competitive result: **no-shows plus
  zero-score finishes**. Disqualifications are excluded: a DQ follows a ban, so those accounts are
  already decided and counting them only adds noise.
- `UnproductiveSharePct >= 30` (share of registrations that were unproductive)
- `RatingFromUnproductive <= -90` (rating lost through those events)
- `TotalPrizes > 3` — players who shed rating without cashing anything are not the enforcement
  target

**Why zero-score counts (week-18).** Rating can be shed by entering and catching nothing just as
well as by not appearing — at roughly half the cost per event (-5..-10 against -10..-20), which
only means the player needs about twice as many of them. Measured over August across all three
platforms: of 109 accounts that both earn rating when they produce a result and take 4+ prizes
while rated at or below 100, the no-show-only criteria caught 70 and the drain-inclusive criteria
caught 91 — **+21 recall, nothing lost**. Cost is about a third more candidates per cycle.

A 35% share threshold was measured against 30% on the week-18 window and rejected: it saved one
review slot and lost one such account.

This also matters for what is coming. FP-45377 abolishes `NoShowRatingPenalty` outright. When it
ships, the zero-score finish becomes the *only* way to shed rating, and a no-show-only screen
stops detecting anything at all.

Output columns are documented in the SQL header. The script is parameterized by `@WindowStart`
only; the thresholds themselves have stayed unchanged since week-3 — week-18 changed what is
counted, not where the lines sit.

**What ordinary behaviour looks like** *(measured week-18, Steam, sweep week 2026-08-31..2026-09-06)*.
Among players with at least 5 registrations in the week — the only population the screen can ever
reach, since it requires 6 unproductive events — the no-show share distributes like this:

| share | players | avg registrations | share of all no-shows |
|---|---:|---:|---:|
| exactly 0% | 182 | 11.7 | 0% |
| under 20% | 82 | 16.3 | 15% |
| 20-40% | 57 | 12.9 | 24% |
| 40-60% | 22 | 13.1 | 18% |
| 60-80% | 14 | 12.4 | 14% |
| 80-100% | 38 | 6.6 | 30% |

Of 395 players, 67% sit below 20% and 46% never miss anything at all. Only 19% are at 40% or above.
The 30% screening threshold falls inside the 20-40% band, which holds 14% of players, so the exact
fraction it excludes was not resolved — but it is clearly not a threshold that passes everyone.

The heaviest band is not the enforcement target: the 38 players at 80-100% average 6.6 registrations
and are people who signed up a few times and skipped nearly all of it. They contribute 30% of all
no-shows and nothing to prize extraction. The accounts this task exists for sit in the 40-80% bands,
where the share is high *and* the registration volume is ordinary.

**Do not compare this threshold against a participation-weighted aggregate.** The overall no-show
rate across all participations in the same week is 38.42%, which looks as though the threshold
passes everyone — but that figure is inflated by one-off registrants with near-100% absence, and it
answers a different question. A per-player threshold is compared against a per-player distribution.
This mistake was made and corrected in week-18.

**Three connections**: `[F2P] STEAM PROD MAIN`, `[F2P] PS PROD MAIN`, `[F2P] XB PROD MAIN`. Run
the same SQL on each; cohort size at this stage is typically 15-30.

**Example (week-7)**: 26 total — 9 Steam, 15 PS, 2 Xbox.

### 1.5 Risk zone — who has to be judged before the payout

The weekly reward pays the **top 10 by wins** (`CompetitiveRatingWeeklyHistory`,
`DimensionTypeId = 2`). Monthly and yearly boards pay too, and more richly — see the note at the end
of this section. The cycle's success condition is narrow: **no unconvicted abuser collects a top-10
reward.** Everything else — the bans themselves, the handoff, the paperwork — can land on Monday
without loss.

**The deadline is soft, and the softness has a price** *(corrected week-20)*. A prize is not the
irreversible loss this section used to claim. It can be annulled after the fact and passed to the
next player on the table, an offline delivery can be caught before it lands, a missed prize can be
granted late. But every one of those is a **manual compensation action**: operator time, and players
disturbed because of our delay. They are last resorts — they work, and their cost is the reason to
judge the risk zone first, not a licence to run late.

**The asymmetry decides which way to err at the boundary.** Moving a prize **down** the table is
honest and comparatively cheap. Moving it **up** is not: taking a prize from someone who turns out
innocent and handing it to the player above him cannot be put right except by clawing it back from
that player or by paying it out twice. So a case still undecided when the board closes keeps its
prize, and the conviction follows on the next cycle. Err towards letting a prize go, never towards
taking one.

A ban **vacates the place**: measured week-18 on Xbox, both candidates banned out of the would-be
top 10 disappeared from the board and 2 players on 2 wins each were paid in their stead. So banning
someone promotes everyone below them, and the zone that must be judged in time is wider than the
prize zone itself.

**Risk zone = top (10 + N) per platform**, where N is the number of candidates on that platform.
Leaderboards are per-platform, and only a ban on the same board can lift anyone. The bound is
deliberately loose: the exact figure is recursive and the loose one is a minute of arithmetic.

**The board is final from 22:00 UTC on Sunday** *(established week-20)*. A competition belongs to
the week in which it ends, so the last one counting to a week is the one ending at 22:00; anything
starting at 22:00 ends at midnight and belongs to the next week. Compute the risk zone after 22:00
and the figures cannot move.

The drift allowance this step carried in week-19 — bounding a candidate's remaining climb by the
competitions he is still registered for — is **withdrawn**. It answers a question that cannot arise,
and on its first use it gave a wrong answer, crediting a candidate with a possible extra win from a
competition that could not count to his week.

**Tie-break, and why it does not open a route.** Places within an equal win count are ordered by the
timestamp at which the count was reached, earliest first — verified across 3 tie groups in period 20260907.
The winner of the boundary competition therefore holds the earliest possible timestamp of
the following period and heads every tie he is in. Measured across 20 finalised weekly periods on
Steam: a single win was **never once rewarded**, the fewest wins ever paid was 2, and the closest a
single win came was 14th place against a paying depth of 10. The position is real and worth nothing;
do not spend review time on it.

**Monthly and yearly boards pay as well, and the prizes get richer with the period** *(recorded
week-20)*. `PopulateCompetitiveLeaderboardRewards` seeds rewards as the cross product of
{Played, Won, Rating} × {Weekly, Monthly, Yearly} × 10 places, and `DistributeLeaderboardRewards`
returns early only for `Played` — so 6 of the 9 boards pay. This section previously said the other
dimensions pay nothing, which was wrong, and the cycle has checked the weekly board only since
week-8. What follows from it:
- every cycle, after the weekly risk zone, check the month's cohort so far against the monthly
  top 10 and ask only whether anyone is within reach — remaining wins needed against the
  candidate's observed rate. Out of reach is a line in the record and nothing more;
- on the **last sweep of the month** the monthly check is binding, exactly as the weekly one is;
- in December the same for the yearly board, with margin, because the yearly prize is the largest
  and a 4-week ban is the weakest instrument against a counter that has been accumulating since
  the matchmaking launch of 2026-04-29.

Compute the zone **before** dispatching the trial, and order the cohort by leaderboard position.
Candidates outside the zone are still judged in the same run and banned the same way — they are
simply not on the critical path, and if the clock runs out they can be applied Monday morning or
handed to Support.

### 2. Reading order

Order the cohort by board place and read the reward zone first. Before reading, mark from the
detection output: REPEAT (sets the term), already banned elsewhere (nothing to apply), returning
WATCH (rules 4 and 8 apply). Nothing else is decided before the card is read.

### 3. Trajectory dump — Mongo Tournament-log

Each candidate gets a Tournament-log slice from the `tournamentLog` collection (schema `main2`,
not `main` which is stale), covering the detection window plus whatever pre-context is still
available.

**`tournamentLog` retains fourteen days and no more** *(measured week-17: the whole Steam PROD
collection spanned exactly 2026-08-16..2026-08-30)*. The "3-week slice" this step used to claim
was never delivered — in an ordinary cycle the detection window is the last 7 days and 14 days of
retention covers it with a week to spare, so nobody noticed. Ask for a wider window and the query
returns silently truncated data: every card in week-17 began on the same day, six days after the
window opened.

Consequences, and they bite:
- **Never conclude anything about a period older than fourteen days from the ledger.** Week-17
  produced findings of the form "no boundary crossing" and "confined to PCR 0..60" that were true
  of the ledger and false of the record.
- **Beyond fourteen days, SQL is the only source.**
  `TournamentIndividualResults.Rating` per participation reconstructs the trajectory, and
  `TournamentParticipants.CompetitionRatingAtStart` / `...AtReg` (FP-43816)
  give the rating actually carried into each competition.
- **SQL is complete, but it is split** *(established week-18)*. Competitions older than roughly 60
  days move to `ArchiveTournaments` / `ArchiveTournamentParticipants` /
  `ArchiveTournamentIndividualResults`. The split is clean — measured 2026-09-13, the live tables
  begin 2026-07-15 08:00 and the archive runs up to 2026-07-15 06:00, reaching back to 2017 — and
  the archive carries the FP-43816 columns, so `CompetitionRatingAtReg` and
  `CompetitionRatingAtStart` survive it.
  **The failure mode is silent.** A query against the live tables for anything older than the cutoff
  returns no rows, which reads as "the player was not active" rather than "this is the wrong table".
  Any claim about a period beyond 2 months must query the archive, and any claim of absence over
  such a period is worthless without it. Note also that `KindId = 3` predates matchmaking, which
  launched 2026-04-29, so the archive contains competitive rows from the old mode as well.
  Date-filter accordingly.
- When the charge spans more than two weeks, say so in the pre-trial context and supply the SQL
  reconstruction alongside the card, or the judges will read the gap as absence of evidence.

**One consolidated aggregate** (introduced week-7) runs once per platform Mongo PROD with all
UserIds in `$in: [...]`. The query is in `artifacts/pcr-trajectory-queries-<date>.js`. UserIds
are globally unique FP GUIDs — each platform's Mongo returns only its own candidates.

Output rows: `<UserId>\t<ISO timestamp>\t<verbatim Message>`. Save as three per-platform .tsv
files in `artifacts/pcr-log-trajectories-<date>/` (typical sizes: Steam 3-7 MB, PS 8-15 MB,
Xbox 0.5-2 MB).

Then split into per-candidate .tsv via `grep "^\"<uid>"` + `sed` to strip the UserId column.
Bash template:

```bash
declare -A SLUG=( ["<uid>"]="<slug>" ... )
for uid in "${!SLUG[@]}"; do
  slug="${SLUG[$uid]}"
  {
    echo "line"
    cat steam-dump.tsv ps-dump.tsv xb-dump.tsv \
      | grep -F "\"$uid" \
      | sed -E 's/^"[0-9a-f-]{36}\t/"/'
  } > "${uid}-${slug}.tsv"
done
```

The 3 platform-level dumps are transient buffer — they get deleted after split, only the
per-candidate files survive.

**Slug rules**: lowercase, kebab-case, underscores → dashes, collapse multiple dashes. Example
mappings: `IIGot-_-Smoked` → `iigot-smoked`, `M4R5H_57_` → `m4r5h-57`, `LEBOOGIEEEE` → `leboogieeee`.

### 4. Parser agent — distill raw .tsv into trajectory cards

A general-purpose subagent reads the 24 (or however many) per-candidate raw .tsv files and emits
one `<uid>-<slug>.md` trajectory card per input. The agent recognises these event types via regex
anchors:

- **PCR ledger entry**: `Tournament reward Competition #(\d+) '(.*)' added CompetitionRating (-?\d+) \((-?\d+) -> (-?\d+)\)` — the spine.
- **Played-confirmation**: `Player started scoring time for Competition #(\d+)` — PLAYED iff
  present for the comp, NO-SHOW iff absent for a comp with a reward entry.
- **ZERO-SCORE** *(added week-18, spelled out here week-20)* — a started competition that produced
  nothing. The ledger cannot tell an empty start from a scored one, so the status is **fed in from
  the SQL competition ids**, not derived from the log: a comp id on that list with a
  played-confirmation is ZERO-SCORE rather than PLAYED. Carry the status through to the ledger
  table and to `middles_to_noobs_drops`. `batched_flush_groups` and `longest_no_show_streak_hours`
  stay **no-show-only by design** — they are about absence, not about shedding route.
  *Where the list comes from*: it is produced ad hoc from the same step-1 connection as the screen,
  one query per platform returning `UserId, TournamentId` for rows matching the screen's zero-score
  predicate (started, not disqualified, `Score` and `SecondaryScore` both zero), and pasted into
  the parser prompt beside the platform map. The screen itself emits only the aggregate
  `ZeroScore`, so it cannot serve as the source. This has worked since week-18 and was simply
  never written down.
  **Pull the list over the card's span, not the screen's window** *(week-20)*. The card carries the
  sweep week plus up to 14 days of pre-context, so a list cut to the sweep week alone tags a
  zero-score event in the pre-context as PLAYED. Since `middles_to_noobs_drops` counts both routes
  and rule 5 fires at exactly 2 drops, the mismatch would count a no-show drop in the pre-context
  and silently drop a zero-score one beside it — the same event, the same week, a different answer
  depending on route. Same row predicate, widened dates.
- **Registration**: `Player registered for Competition #(\d+)` and `Registration for tournament Competition #(\d+) ... failed`.
- **Process marker** (skip): `About to process tournament Competition #`.
- **Cheat trigger** (count + capture notable): `CHEAT: ...`.

Everything else (`Fish caught`, `Fish accounted`, `Fish is not scored`, scoring listings, `Update overall`, `Player finished`, `Competitive activity`, etc.) is IGNORED for the card.

The card's frontmatter computes:
- `pcr_range` / `pcr_at_start` / `pcr_at_end` / `net_delta`
- `batched_flush_groups` — same-second clusters of size >= 2 with at least one NO-SHOW
- `longest_no_show_streak_hours` — longest run of >= 5 consecutive no-shows
- `middles_to_noobs_drops` — counter of pcr_before>=101 AND pcr_after<=100 AND status IN
  (NO-SHOW, ZERO-SCORE) *(widened week-20 to match the glossary; report the split, e.g.
  `5 (no-show 5, zero-score 0)`)*. Rule 5's operative test reads this field, so a zero-score
  drainer would score 0 here under a NO-SHOW-only definition and the test would silently fail to
  reach him. **The parser has in fact counted both since week-18** — 75 `ZERO-SCORE` ledger rows
  in that cycle, 21 in week-19, and 3 cards across the two carry a non-zero zero-score component —
  so this line documents existing behaviour rather than changing it, and cross-cycle comparisons
  under rules 4 and 8(a) are already like-for-like back to week-18. Do not introduce a correction
  for a discontinuity that is not there
- `cheat_triggers` count
- `notable[]` — up to 8 short verbatim-style descriptions of significant events
- `presence_gaps` *(added week-20)* — every interval of 2 hours or more inside the window carrying
  **no log line of any type** for that user, reported as `start -> end (Nh)`, plus the share of
  window hours spent inside such gaps. **Use every line's timestamp for this, not only the five
  recognised types** — the whole point is whether the account was visible at all, so scoring
  listings, `Fish caught`, `Update overall` and the rest all count as presence even though they
  are ignored for the card body. Then mark each unproductive ledger entry `in-gap` or `in-presence`
  by where its timestamp falls.
  **What this can and cannot say.** The ledger timestamp is the flush moment, so `in-presence`
  locates when the penalty was *applied*, not when the competition ran; it does not by itself prove
  the player chose to skip that competition. What the field does deliver is the bound: a candidate
  dark for twenty hours cannot be argued about the same way as one who was logged in and catching
  fish throughout. Tying an absence to its own competition's start window needs the competition
  start times, which the ledger does not carry — see the backlog item on dumping
  `CompetitionId -> StartDate` alongside step 3.
- `bracket_recovery` *(added week-20)* — where the SQL row's `BracketCoverage` is not `ok`, the
  bracket split is short because those rows carry no `CompetitionRatingAtStart`. Resolve each one
  from the ledger: the `pcr_before` of the competition's own reward entry is the rating the player
  carried into it, so the bracket follows from the same 0-100 / 101-1000 / 1001+ bands. Report the
  completed split on the card and list the recovered competitions here. The shortfall is a data
  gap to be filled, not a thin record — see the standing defect list in step 5.

The body is the full chronological PCR ledger as a markdown table (`Timestamp | Comp ID | Comp name | Status | Δ | PCR`).

The agent prompt is the same shape every cycle — the only variables are: input directory, output
directory, SQL sanity-check table, player → platform map. **CRITICAL** instruction in the
prompt: do NOT invent data; if a file is empty, return empty; if a regex doesn't match, leave the
field blank. The week-5 first attempt was thrown away because the agent hallucinated synthetic
data; the current prompt explicitly forbids this.

### 4.5 Evidence completeness check (post-Codex refinement)

Before dispatching the cohort to trial, cross-check the parser's counts against the Step 1 SQL
numbers per candidate — **NO-SHOW, ZERO-SCORE and their sum against SQL `NoShows`, `ZeroScore` and
`Unproductive`** *(widened week-20; it checked no-shows alone)*. If any of the three differs from
SQL by more than 20% OR by more than 5 absolute events (whichever is larger), flag the card with
`evidence_completeness: degraded` and include the SQL/parser diff in the pre-trial context.
Checking no-shows alone leaves a hole now that zero-score feeds `middles_to_noobs_drops`: a parser
miss on the zero-score half moves rule 5's operative count without tripping the flag.
**Degraded evidence caps confidence at 7** *(week-20; it used to read "prefer WATCH")*. It is not
a release and not a route to WATCH in itself — the same treatment rule 3 now gets, and for the same
reason: thin or doubtful evidence limits how confidently a case can be decided, it does not decide
it. The two caps do not stack. Where the trajectory signature is independently overwhelming the
judge convicts under the cap and says so (Da Sneaky Snake week-10 is the worked example:
completeness flagged, severity sufficient, BAN sustained).

**Floor absorption is the first cause to rule out, and it is exempt from the flag** *(week-20)*.
A penalty landing on an already-zero rating writes no ledger line at all (week-12), and the parser
tags statuses onto ledger rows — so for a candidate parked at the floor the parser count is
structurally below SQL with nothing wrong anywhere. That is exactly rule 9's population: maximum
PCR under 100, the bottom-bracket farmer. Flagging him `degraded` would cap his confidence at 7
for the very reason rule 3 says must not shelter him ("unavailable where the ledger merely looks
thin because the rating sat at the floor"), handing him through the other door what rule 3 refuses
at the front. Where the window contains `-> 0)` ledger entries and the shortfall is consistent
with them, record the divergence in the pre-trial context and do **not** set `degraded`.

Other causes, which do set it: Support pre-action redacting tail ledger entries, tail entries
appearing after the parser ran, or a parser regex missing a variant. Observed cases: Gustyn112
week-9 (parser 10 vs SQL 15, diff −5), alphaBiTsoop16 week-10 (parser 26 vs SQL 50, diff −24).
Both remained BAN because signature severity dominated, but recurring disagreement is a
data-integrity signal that warrants investigation.

### 5. Adversarial trial — workflow with prosecutor / defense / judge per case

A `Workflow` script (using the `Workflow` MCP tool) runs three subagents per candidate in a
`pipeline()`:

- **Prosecutor** (parallel with Defense): reads the trajectory card, argues BAN with severity
  score 1-10, cites specific evidence (timestamps, batched-flush events, climb-then-flush
  cycles, MIDDLES drops), proposes duration `2W-NEW` or `4W-REPEAT`.
- **Defense** (parallel with Prosecutor): reads the same card, argues `EXONERATE` / `WATCH` /
  `CONCEDE` with doubt score and alternative explanations (server-flush artifact, skill-cap
  oscillation, sample-size objection on a fresh-lifetime candidate, chronic over-registration,
  etc.). **Bracket flavor is no longer a defense** — prizes sitting in MIDDLES or TOPS rather
  than NOOBS does not answer the charge in rule 1.
- **Judge** (sequential after both arguments): reads both arguments, may consult the case file
  for verification, renders `finalVerdict` (BAN / WATCH / EXONERATE), `banDuration`, `reasoning`,
  `prosecutorResponse`, `defenseResponse`, `confidence` 1-10.

**What `confidence` means, and what it does not** *(stated week-20)*. It measures how firmly the
finding is established, **not** how serious the case is and **not** whether the verdict clears
some bar. **There is no minimum confidence for BAN.** A capped case is convicted at the cap, with
the reason for the cap named in the reasoning. This has to be said because the record shows judges
treating the number as a threshold — ZellyRolled (week-19) and Lay_D14S (week-5) both returned
WATCH at exactly 7, the latter writing "conviction threshold not met" in terms. Left unsaid, the two caps
below would quietly restore the defeater that week-20 removed: cap at 7, judge reads 7 as "not
enough for a ban", and the thin-record candidate walks exactly as before.

The caps are rule 3 (thin record) and step 4.5 (degraded evidence). Both cap at 7. A case carrying
both is still capped at 7, not lower — they do not compound.

Schemas (`PROSECUTOR_SCHEMA`, `DEFENSE_SCHEMA`, `JUDGE_SCHEMA`) are typed via JSON Schema so the
subagent's StructuredOutput is forced and parseable. The whole workflow is ~3N agent calls
(N = cohort size); ~5-7 minutes for 24 cases.

**Pre-trial context** per case is mandatory — the `context` field on each `CASES[]` entry must
flag: `status` (NEW / REPEAT / Support-pre-actioned / stale-flag), watchlist holdover with the
prior-cycle flavor, the relevant SQL summary line, and any methodology refinement that applies.
Without this the trial loses calibration.

**Verify the case context against the card before dispatch** *(added week-18)*. Every factual claim
in a `CASES[]` context line must be checked against the candidate's trajectory card. Week-18 sent
"never leaves NOOBS in the window" for a player whose card recorded a peak of 125; the judge caught
it, but the same sentence survived into the outward CS report and was removed only at adversarial
review. `MaxRatingAtStart` is the rating carried *into* a competition and is routinely lower than
the weekly peak — never read one as the other.

**Defects the brief must carry** *(added week-18)*. The pre-trial brief is not only case context; it
must restate the standing findings about what this evidence can and cannot show, because each
cycle's prosecutors and defenders start from nothing and will otherwise re-derive them badly or not
at all. Omitting one is not a small loss: the week-18 first hearing returned 4 BAN of 17 against 11
of 16 the cycle before, purely because the brief left out the week-12 flush-moment finding and the
prosecution built its sequence cases on the artifact. The list, all binding on both sides:
- a same-second ledger group is a flush moment, not evidence of presence or of decision order
  (week-12);
- a flat absence cadence across the rating range is not exculpatory — a player winning inside the
  bottom bracket must shed continuously to stay there, and the equilibrium is the signal (week-12,
  operator);
- the ledger under-reports: a competition can carry a process marker and no reward line, so a ledger
  count is a floor and absence of an entry is not evidence that nothing happened (week-18);
- printed rating deltas overstate the loss where rating floors at zero (week-12);
- `presence_gaps` bounds the argument, it does not settle it (week-20). A candidate dark for
  twenty hours and one logged in and catching fish throughout cannot be argued about the same way,
  and both sides must work from the field rather than from assertion. But the ledger timestamp is
  the flush moment, so `in-presence` says when the penalty landed, not that the player was at his
  keyboard while the competition ran. Neither side may treat the mark as proof of choice, and a
  long silence is not exculpatory on its own — a player can be absent because he is absent;
- an unclassified bracket is **not** a defence argument (week-20). Where `BracketCoverage` reports
  a shortfall, rows exist whose `CompetitionRatingAtStart` is absent; the parser resolves them from
  the ledger PCR chain and the split on the card is complete. Missing classification is a data gap
  that has already been filled, never a reason to read the record as thin, and it does not feed
  `evidence_completeness`;
- the charge is the SQL sweep week; the card's fourteen-day aggregates are shape, order and timing
  only (week-17);
- what rule 1(a)'s temporal limb can be proved from at all: the rating chain of resolved
  competitions, never the ordering inside one second (week-18).

**The outage defence is not available by default** *(settled week-18)*. Planned downtime cancels
competitions outright — including recurring ones — so it cannot produce no-shows at all. Unplanned
incidents are rare, and when one happens the result is normally compensated or the competition
voided, so it does not silently sit in the data as absence. **Whether an incident occurred in the
sweep week is a question for the operator, not for a query.** Unless the operator says there was
one, neither side may attribute absences to it.

Measured once for completeness, week-18 on Steam: if absences were incident-caused they would
cluster, since unrelated players entering the same competitions would also fail to appear. The
platform-wide no-show rate was 38.42% across 82 competitions; the competitions our candidates
skipped averaged 41.06%, and none was at twice the baseline. The fields they missed filled normally.
Recorded so the argument does not get re-opened from scratch; not a standing check.

**Fish release as an aggravating signal — measured and not present** *(week-18)*. Releasing caught
fish is the one action that reduces a result on purpose, so a release landing in a competition that
ended with no score would be directly aggravating. Measured once across the week-18 cohort: releases
occur and are sometimes heavy (34 across 12 competitions for the heaviest candidate), but the
intersection with zero-score competitions was **empty** — players release where they go on to score,
which is ordinary keepnet management under scoring rules that cap what the net can hold. Not made a
standing check. Revisit if a party raises it in argument, or if scoring rules change in a way that
makes release profitable.

**Standing rules the judge prompt enforces:**

1. (rewritten week-14) BAN is for **bracket-relative harvesting**: taking prizes in a bracket
   below the one the player's own play would place him in, having arrived there by shedding
   rating. The mechanism is not specific to NOOBS — it operates at every bracket boundary, and
   the standing exclusion of MIDDLES/TOPS candidates as "flavor mismatch" was wrong. Two things
   must hold together:
   **(a) chosen descent** *(amended week-18)* — rating from **productive** play is positive while
   net rating is flat or falling, with the gap accounted for by **unproductive participation**,
   *and* the ledger shows the temporal order: play lifts the player toward the boundary, the shed
   pulls him back, prizes are then taken below it. Aggregate signs alone are not enough; the
   sequence is the evidence.
   *Productive* means started, not disqualified, and actually scored something. *Unproductive*
   means a no-show or a start that produced nothing. The distinction is not cosmetic: a zero-score
   finish is formally play and carries a negative rating, so under the old wording it dragged
   "rating from play" downwards and the drainer read as an honest player losing — the more he shed,
   the more innocent he looked. FM_AirForceZero (week-17) is the worked example: 17 of his 26
   starts produced nothing against only 10 no-shows.
   Note what the split does *not* fix. It leaves the sums unchanged, so a candidate whose net
   rating is **rising** still fails this limb — FM_AirForceZero's net was +37 and he was held on
   WATCH for that reason, not because of the drain route. Where a rising net sits alongside heavy
   shedding, rule 5 is the provision that reaches it — but only above the threshold rule 5 states,
   and only at the MIDDLES/NOOBS boundary its counter measures. Below the threshold the rising net
   stands and this limb fails. At another boundary rule 5 has nothing to say, and the limb must be
   proved directly from the rating chain instead.
   **(b) payoff below the ceiling** *(amended week-17)* — prizes concentrated in a bracket below
   the one the player's own results place him in. The ceiling is the **higher** of:
   (i) the highest bracket he actually reaches with meaningful exposure in the window, and
   (ii) the bracket his rating would sit in **without the penalties he took by unproductive
   participation — no-shows and zero-score starts alike** *(corrected week-20; the wording said
   "by not appearing" and so refunded only the no-show half)*.
   **Compute it one way and one way only: rating on entering the window + `RatingFromProductivePlay`.**
   Do not compute it as net minus `RatingFromUnproductive`; the two disagree for any candidate
   carrying a disqualification, because DQ rating sits in neither column, and a ceiling that
   depends on which formula the judge picked is not evidence. Note honestly what the pinned route
   does with DQ: since DQ rating is in neither column, `entering + RatingFromProductivePlay` omits
   it, i.e. it **does** refund the DQ penalty. That is accepted as the price of one unambiguous
   formula, and it is inert in practice — `Disqualifications` was 0 for every candidate across
   weeks 18, 19 and 20 but one. Where a candidate does carry a DQ, say so and state the ceiling
   both with and without it. Where (ii) is used, state both figures.
   The correction matters most for the drainer the screen was widened to catch in week-18: refund
   only his no-shows and a zero-score drainer's ceiling comes out near his actual rating, limb (b)
   fails, and he is acquitted on the precise route he used.
   *Why (ii) exists*: the week-14 wording exempted precisely the most deflated accounts. A player
   already pushed to the floor has no bracket above him inside the window, so there was nothing
   for his prizes to be "below", and the same-bracket carve-out then sheltered him. Six of the ten
   week-17 first-hearing WATCH verdicts were this, including an account that entered the window at
   927 and ended at 0 with 83 no-shows in 89 entries.
   *The counterfactual is a first-order estimate, not a simulation*: without the penalties he
   would have faced a different bracket, different opponents and different results. It is evidence
   of displacement, not a prediction of his score. Anchor it on the recorded
   `CompetitionRatingAtStart`/`AtReg`, and prefer the endpoint reconstruction as a cross-check —
   assessed and applied rating diverge by design (see the rating-application deep dive).
   Absence alone is not BAN. Rating shed by *losing* rather than by absence is not BAN — that is
   an honest player at his ceiling. A player who plays and cashes in the same bracket is not a
   target of this task however much rating he sheds there — **but that carve-out applies only if
   the counterfactual ceiling is also that same bracket**, otherwise it automatically shelters
   anyone already lying on the floor.
   *Corroboration where exposure allows*: conversion in the harvest bracket materially above
   conversion in the top bracket reached — one-sided two-proportion comparison (Fisher for small
   samples) with a rate ratio at or below one half, computed on the **cumulative** window, never
   the weekly one. Its silence is not exculpatory. Raw prize share is descriptive only: it tracks
   exposure, so it identifies which bracket is being harvested and does not itself carry
   enforcement.
2. REPEAT status alone is not automatic BAN if the trajectory pattern is weak. Where the pattern
   is weak, WATCH applies to a REPEAT just as it would to a NEW candidate. The bracket in which
   the prizes sit is not what makes a pattern weak — see rule 1.
3. (reframed week-13; counter corrected week-19; **turned from a defeater into a confidence cap
   week-20**) Data-sufficiency objection, and the **only** leniency available on evidentiary
   grounds: fewer than **15 registrations** in the window. This is a claim about how much evidence
   exists, not about who the player is. Unavailable where SQL volume is high and the ledger merely
   looks thin because the rating sat at the floor (see Step 4.5).
   **Rule 3 does not release.** A thin record caps the confidence of a conviction at **7** and
   obliges the judge to name it as the reason for the cap. Conviction on a thin record is
   available; confident conviction is not. As a hard defeater the rule published an immunity band:
   the screen's own floor is 10 events, so a candidate between 10 and 14 was released whatever the
   severity of everything else — 10 unproductive of 14, -150 rating and 4 pure-NOOBS prizes walked
   automatically. The cap closes that band without pretending the record is thicker than it is, and
   it removes the precedence question the defeater created against rules 4, 8 and 9, none of which
   now have anything to be defeated by. Measured over weeks 18 and 19: 1 candidate per cycle falls
   under the threshold, so the cap changes the treatment of about 1 case a cycle and adds no
   material volume.
   **Count events, not games.** Between weeks 13 and 19 the counter was "fewer than 10 competitions
   PLAYED", and that measures the wrong thing: the offence consists of *not* playing, so the harder
   a candidate drains the fewer games he has and the more readily the leniency shelters him. At a
   68% unproductive share it takes more than 30 registrations to reach 10 games. Week-19 released
   two candidates on the old counter, one of them (ZellyRolled) with limb 1(b) expressly found met
   and the rule 5 signature verified on the rating chain — the pattern was established and the
   release rested on a single missing game. That required an operator override to correct.
   **Why 15 and not 10.** The screen requires at least 6 unproductive events and more than 3 prizes,
   and a prize requires a start, so **every candidate reaching review has at least 10 events by
   construction**. A threshold of 10 on events could therefore never fire — it is the floor, not a
   measure. 15 sits above the floor and reaches the cases the rule is actually for: at 11 events a
   candidate is 6 unproductive and 5 played with 4 prizes, a stark ratio on denominators far too
   small to carry it. Do not lower this to 10 for symmetry with the screen; that is the mistake this
   note exists to prevent.
4. (broadened week-13) Any candidate returning to the cohort after a prior WATCH whose NOOBS
   flavor has appeared or grown (NOOBS prizes appear or increase, or MIDDLES->NOOBS drops appear
   or increase) is BAN without further deliberation. Previously scoped to watchlist entries
   only; broadened because rule 6's withdrawal removed the wording that carried the other cases.
5. (week-7 Kacumi refinement; **operative test added week-20**) Net-positive PCR alone does NOT
   defeat the bracket-farming hypothesis when the climbs are followed by no-show flushes and
   re-engagement at NOOBS-bracket competitions. The climb is the up-arc of a climb-and-cash cycle,
   not climber behavior. Only use net-positive as defense when there is NO climb-then-flush
   signature.
   **What the rule does, exactly.** It supplies limb 1(a) where, and only where, the trajectory
   shows at least **2 downward crossings of the MIDDLES/NOOBS boundary caused by unproductive
   participation, inside the charge window** — the card's `middles_to_noobs_drops`, which counts
   that boundary and no other. **The 2 must fall in the sweep week**, not anywhere in the card's
   fourteen days: the charge is the sweep week and the card's longer aggregates are shape, order
   and timing only (standing defect list). The counter as printed spans the whole card, so read
   the dates off the ledger before applying the threshold. Lesky2123 (week-19) is the worked
   warning — both his drops are dated 08-31 and 09-02 against a charge window of 09-07..09-13, so
   he does **not** satisfy this test, and the ledger row that cited him as satisfying it was wrong.
   FOGGIA1920's two are in-window and do.
   A TOPS→MIDDLES drainer is therefore outside this test as written. **Do not route him to limb
   1(b)** — that is the payoff limb and cannot supply 1(a), so the redirection would leave him
   with no conviction route at all. Prove limb 1(a) for him directly from the rating chain: the
   shedding, the boundary it crosses and the re-engagement below it are all in the ledger, and the
   limb asks for chosen descent, not for a particular boundary. Record the case so the counter can
   be widened if the shape recurs. Below the threshold rule 5 only removes the net-positive
   defence and supplies no limb, and a judge may not convict on rule 5 alone.
   **Rule 5 never supplies limb 1(b)**, which must still be proved on its own — a candidate with
   2 or more drops whose prizes all sit in MIDDLES satisfies rule 5 and fails 1(b), and that is an
   acquittal on the charge, not a technicality. The threshold is 2 because a single crossing can be
   a bad week; a return is a pattern.
6. (**REWRITTEN week-13 — the week-8 KingYakO2 novice-deference version is withdrawn**)
   **There is no standalone novice deference.** A thin record is handled by rule 3 and only
   rule 3. Affirmatively: **low lifetime volume is AGGRAVATING when in-window extraction is
   high.** The screen already requires >= 6 unproductive events, >= 30% share, <= -90 rating from
   no-shows AND more than 3 prizes, so every candidate reaching review has already demonstrated
   both volume and cashing. If a large share of the candidate's lifetime prize count was earned
   inside the window, their entire competitive record consists of the conduct under review --
   the pattern in its strongest form, not an excuse for it. The judge computes the ratio
   explicitly (in-window `TotalPrizes` against lifetime `Gold`+`Silver`+`Bronze`) and states it.
   Two arguments are expressly closed to the defense: (i) a **recovery-climb**, because rule 5
   already classifies the climb as the up-arc of a climb-and-cash cycle; (ii) **absence from a
   later cohort**, because a candidate can simply pause -- absence proves nothing either way.
   *Basis for the rewrite*: across weeks 8-13 the deference branch produced twelve WATCH
   verdicts and not one was later vindicated; every traceable case ended in a ban by us or by
   Support. The week-13 Support-blind A/B re-ran the same 18-candidate cohort under both
   versions -- the old rules missed two players Support had independently banned
   (ELPEZGORDO12, ZacKasoN), the rewrite missed none, and no confident BAN flipped the other
   way. See `bans-2026-08-02.md`.
7. (week-8 TR-dennisfb refinement; **direction 2 withdrawn week-14**) High-PCR sandbagging WATCH
   (PCR >= 800 OR Lifetime TOPS >= 5) carries a one-cycle clock. **Direction 1**: if the harvest
   signature of rule 1 appears next cycle, rule 4 fires (BAN).
   **Direction 2 is withdrawn.** It let a candidate be closed as "not FP-43631 target" after
   three unchanged upper-bracket cycles, on the reasoning that only NOOBS farming was in scope.
   Rule 1 no longer says that, so the basis is gone. Two closures made under it
   (Panonski_Alas week-12, X1aoDouYa week-13) are reversed and both return to the cohort.
   They do **not** return equal: Panonski_Alas carries a corroborated conversion differential
   (5 prizes in 72 TOPS starts against 37 in 177 MIDDLES starts) and goes to trial as a live
   candidate; X1aoDouYa is reopened only — his TOPS exposure is thin and positive, the reading
   "strong MIDDLES player, occasional TOPS entrant, chronic no-shower" survives the aggregate
   table, and trajectory timing plus recurrence must decide rather than the summary numbers.
   Persistent upper-bracket presence without the rule 1 signature is no longer grounds to close,
   but it is not grounds to ban either — such candidates simply keep rolling forward on WATCH.
   **Uniformity (week-13)**: two candidates with the same multi-cycle upper-bracket profile must
   receive the same disposition. Note the limit found in practice -- an instruction alone does
   not achieve this, because each candidate is judged independently and the judges cannot see
   one another. Week-13 produced EXONERATE for X1aoDouYa and WATCH for EsseDouble on
   near-identical profiles. Consistency inside a family needs an operator pass over the family
   as a whole, not a clause in the rule.
8. (week-9 CreekSamurai refinement / week-10 validation / broadened week-13) Persistence check
   on **any** prior WATCH, not only a novice one. Rule 4 auto-BAN fires next cycle if ANY of:
   (a) at least one additional MIDDLES->NOOBS drop compared to prior cycle, (b) NOOBS prize
   count grew by >= 2, (c) `UnproductiveSharePct` maintained above 30% on a >= 20% larger sample
   (`Registrations` grew materially without proportional growth in **productive** finishes, i.e.
   `Started` minus `ZeroScore` — a zero-score drainer's `Started` grows in step with his
   registrations, so the old gloss excluded exactly the shape this clause was widened for).
   Validated week-10:
   CreekSamurai returned with 8 M->N drops (up from 3) satisfying condition (a) with margin --
   Support pre-actioned at the exact 2W duration our rule would have applied.
9. (week-10 sandaljepitt refinement) **Within-bracket detector** for cases entirely inside the
   NOOBS bracket [0..100] where rules 1/4/6 miss because no MIDDLES->NOOBS drops and no
   climb-then-flush arcs are possible. Rule 9 fires on ALL of: (a) `UnproductiveSharePct` >= 40
   (higher than the screening threshold of 30%), (b) `Prizes_NMT` >= 4N with 0M and 0T (pure NOOBS
   flavor), (c) max PCR across the trajectory window < 100 (never climbs into MIDDLES), (d) at
   least 10 `Registrations` in the sweep window (avoid tiny-sample false positives). Judge should
   accept "within-bracket abuse" as a load-bearing BAN argument even without cross-bracket
   evidence. **Precedence (corrected week-13; rule 3 clause updated week-20): rule 9 stands on its
   own and is NOT outranked by any consideration of the player's inexperience. Rule 3 no longer
   defeats it either — a thin record caps confidence instead of releasing.** Do not read that as
   reviving clause (d): 10 registrations is the screen's structural floor, so (d) is satisfied by
   every candidate who reaches review and decides nothing either way. The live constraint on a thin
   rule 9 case is rule 3's confidence cap.
   The earlier week-12 precedence — rule 6 outranking rule 9 on a first-cycle candidate — is
   withdrawn: in the week-13 A/B it was the mechanism that let ZacKasoN through (rule 9's gates
   all fired at PCR 4 with pure 4N flavor, and the deference branch suppressed them) while
   Support banned him for a month. Discovered from sandaljepitt week-10 dissent -- Support
   pre-actioned 2W (rating-drop duration; cheat bans are permanent on FP), trial WATCH under
   the then-current rule 6, alignment counter 27/28 at the time.

**Why 30 and 40 did not move when the metric did** *(week-20)*. Rules 8(c) and 9(a) read
`UnproductiveSharePct`, not `NoShowSharePct`; the glossary's boundary drop counts any unproductive
entry. Both thresholds were always defined relative to the screening threshold — rule 9(a) says so
in its own text — and the screening threshold moved from no-shows to unproductive participation in
week-18, so the rules follow it and the numbers keep their meaning: 30 is "at the screening
threshold", 40 is "clearly above it". They are not stale figures awaiting recalibration. Until this
was written down the judges were substituting the new metric silently, without recording that they
had departed from the text — KovlekPlayz and sidelong-beak10 in week-19 both did. The rules as
written could never have reached a zero-score drainer at all: Myky0576 (week-18) ran 27 zero-score
finishes against 1 no-show, a no-show share near 2% and an unproductive share near 67%.

Output is `{ trials: [{ name, platform, status, prosArg, defArg, verdict }] }` — extract
verdicts via:

```python
import json
with open('<task-output>') as f:
    data = json.load(f)
for t in data['result']['trials']:
    v = t.get('verdict', {})
    print(t['name'], v.get('finalVerdict'), v.get('banDuration'), v.get('confidence'))
```

**Persist the verdicts** *(added week-20)*. The workflow's output lives in a session-temporary file
and does not survive the session. Immediately after the run, write the verdicts to
`pcr-log-trajectories-<date>/_verdicts.md` alongside the cards: one entry per candidate carrying
name, platform, board rank, verdict, duration, confidence, the rules the judge actually relied on,
the counterfactual ceiling where one was computed, and the reasoning. Leave the prosecution and
defence arguments out — they run to hundreds of kilobytes and are only useful while the case is
live. The result is on the order of 100 KB and belongs in the cycle commit.

Week-19 is the cautionary case: its ban record cites a 6/6 split, per-case confidences and a finding
that limb 1(b) was met, and a week later none of that could be checked against anything in the
repository. That cycle also carried an operator override — precisely the decision a later reader
will want to audit. Its verdicts were recovered on 2026-09-20 only because the temporary file
happened to still be on disk.

**An operator override requires a blind re-hearing** *(added week-20)*. Where the operator
overrides a verdict, the case goes back through prosecution, defence and judge on the full brief,
with no mention that an override happened, and the result is written into the cycle record whether
it confirms the override or contradicts it. 3 agents.

The re-hearing does not bind. The operator sees what the trial cannot — board position, links
between accounts, history across cycles — so it informs the record rather than reversing the
decision. What it audits is **the reason, not the outcome**, because the reason is what turns into
methodology here. Week-19 is the whole argument: the ZellyRolled override was correct on the merits
(5 boundary drops, which rule 5 reaches) but its recorded ground was rule 3, and rule 3 was
rewritten the same night on that ground. The verdict in fact rested on two independent legs and
named limb 1(a) as "not relied on". A re-hearing would have shown that before the rule changed.
Week-18 did re-hear its two overrides blind and both came back convicted at 8 and 9, which is what
made those overrides confirmed rather than merely unopposed.

Two re-hearings contradicting overrides in a row is a signal in itself: either the criterion the
operator is applying is wrong, or it is right and belongs in the standing rules so the judges can
apply it themselves. The week-12 leaderboard-urgency criterion has decided 3 cases and is still not
written down — see the backlog.

#### Direct reading

The operator may replace the tribunal with a direct reading. Cards are read one at a time with
the assistant, the reward zone first, against the standing rules. The verdict and its ground are
written to `_verdicts.md` as each case is decided. A decision against the standing rules is marked
as an operator decision and gets a blind re-hearing.

One pack per cycle: every candidate is decided before the bans are run, so there is one data pull,
one ban script, one sync and one ban-log run. A candidate who appears only in the run after 22:00Z
is pulled once and joins the same pack.

The full reading guide, with the cases behind each point, is [`reading-guide.md`](reading-guide.md).
Read it before the first card of a cycle. In short, what the operator looks for:

- **What the shedding bought.** A prize taken right after a run of absences, at a rating the
  absences produced, is the offence. Absences followed by nothing are not.
- **Registrations placed to be missed.** A batch registered right after a prize, or at a rating
  peak, and then not attended; a slot registered while the prize competition is still running;
  slots added when the rating has not yet fallen far enough.
- **Win, shed, win.** The same cycle repeated inside the week: a prize, absences back down, the
  next prize at the bottom of them.
- **In the game during the absence.** `Online` near the full window on a missed competition means
  the player was in the game and chose not to enter. Offline absences are weaker and can be a
  schedule; they still count when they are placed as above.
- **Where the player ends the week.** A player who climbs out of the bottom bracket and wins above
  it is watched, not banned, even with a ban history. A player who returns to the same low rating
  before every win is banned.
- **Careful single registrations**, made shortly before a competition the player then attends,
  are ordinary play.
- **Same bracket throughout.** A player who plays and takes prizes in one bracket, with the
  counterfactual ceiling in that bracket too, gains nothing from absences: no case.

An expired ban sets the term if the player is convicted; it does not decide the case.

### 6. Ban execution — three layers

Trial-confirmed BAN verdicts (minus any already-Support-actioned with future BanEnd) go into
three persistence layers, atomic per layer.

**Layer 1: Profile ban** — `artifacts/bans-<date>.sql`. Atomic `SET XACT_ABORT ON` + `BEGIN TRAN`,
ends with manual COMMIT/ROLLBACK after the verify SELECT. Run on each platform PROD MAIN. WHERE
clause is the canonical not-effectively-banned check:

```sql
WHERE NOT (ISNULL(p.IsCompetitionsBanned, 0) = 1
       AND p.CompetitionsBanEndDate IS NOT NULL
       AND p.CompetitionsBanEndDate > GETUTCDATE())
```

This mirrors `ProfileLogic.IsCompetitionsBannedNow()` and covers stale-flag-with-NULL-date rows
correctly. **The older form** `ISNULL(IsCompetitionsBanned, 0) = 0 OR (BanEnd IS NOT NULL AND BanEnd <= GETUTCDATE())` **misses stale-flag rows with NULL BanEnd** — discovered week-6, fixed
week-7. See `<memory>/feedback_competitions_banned_semantic.md`.

Other things the SQL sets per row: `CompetitionsBanEndDate = b.BanUntil`, `AdminComment` audit
note appended (existing comment preserved), `IsInfluencer = 0` if it was 1.

**`AdminComment` carries the reason and the duration — nothing else.** It is a production player
record, so it must not describe how the case was decided: no mention of the review mechanism, no
internal role names, no tooling. Shape to keep:

```
Auto-ban by Stan via FP-43631 follow-up <date> - rating-drop abuse (week-<n>) (<NEW|REPEAT> until <date>)
```

Cycles 6-12 leaked an internal review description into this field and it reached 52 profiles
across the three platforms; `artifacts/fix-admincomment-2026-07-27.sql` is the idempotent
remediation. When building the next cycle's ban script by copying the previous one, check this
line first — that copy step is exactly how the wording propagated for seven cycles. See
`<kb>/feedback/no_kb_refs_in_code.md`.

**Layer 2: Leaderboard ban** — `artifacts/leaderboard-ban-sync.sql` (shared script, not
date-specific). Propagates active Profile bans to `CompetitiveRatingsCurrent.IsBanned = 1`
across Weekly/Monthly/Yearly periods. Must be COMMITted separately — the gotcha that caused
week-3/4/6 incidents was forgetting the COMMIT here. Verify SELECT shows `RowsExpectedToFlip` /
`RowsActuallyFlipped` so a mismatch is visible.

**Layer 3: Mongo banLog** — `artifacts/ban-log-backfill-<date>.js`. One expression, run whole on
each platform Mongo, safe to run twice. The line imitates the WebAdmin format (author "Stanislav
Samoilov", reason `'FP-43631 follow-up - rating-drop abuse (week-<n>)'` for a first offence or
`'... (week-<n>, recidivism)'` for a repeat, `until` matching the ban end) and carries the commit
time of the pack that banned the account.

The script finds which accounts belong to this platform by a `diagIpLog` lookup (180 days of
retention, indexed by UserId), inserts only the lines not already present, and returns how many it
inserted, how many were present, how many are not on this platform, and whether the cycle's line
count matches the accounts found here. The platform of each account and the expected count per
platform are written beside the rows as comments for the reader; the script does not use them. The
operator checks that the three platform counts add up to the cohort. The file in the KB is never
edited after a run. Between cycles only `CYCLE`, `MSG`, the commit times and `ROWS` change.

**Ban term.** First offence: one calendar month from the Monday after the sweep. Repeat: two
calendar months. Example: sweep Sunday 2026-10-04, Monday 2026-10-05, ban until 2026-11-05 or
2026-12-05. The term always covers the month of the offence. Agreed with the CS lead 2026-09-29.

**A repeat is any expired competition ban, whatever it was for.** The detection query reads it as
`IsCompetitionsBanned` set with `CompetitionsBanEndDate` in the past. `Profiles` carries only the
end date, so the query cannot tell when or why the earlier ban was issued. The type matters and the
reason does not: `IsCompetitionsBanned` is competition-specific, so a chat or purchase ban never
reaches this test, and among competition bans the term does not depend on the cause. Support's
banLog entries carry no reason, so the cause is usually unknown anyway.

### 7. Verification — 3-layer post-ban check

Run `artifacts/verify-bans-<date>.sql` on each platform PROD MAIN. The script lists every banned
UserId with expected platform + BanEnd, joins to `Profiles`, `Users`, and an aggregated
`CompetitiveRatingsCurrent` (counts of Wk/Mo/Yr banned vs not-banned). It outputs `Prof_Status`
and `LB_Status` columns reading `OK` / `not on this DB` (expected for off-platform UserIds) /
`FAIL: ...` (investigate).

Plus a Mongo banLog check via MCP DataGrip — three aggregate queries (one per platform Mongo)
with `$match: { Message: /week-N/, UserId: { $in: [...] } }` confirming all expected rows are
present with the right NEW/REPEAT flag.

The standing rule from week-3/4 incidents (Xbox LB sync forgotten, Steam profile not COMMITted,
Mongo backfill ran on wrong connection): **verify all three layers per platform individually,
every cycle**.

**The leaderboard check must be split by `PeriodId`, not aggregated across periods (week-14).**
The sweep runs on Sunday and `CompetitiveRatingsCurrent` rolls to the next weekly period around
the same time, so by verification time a player can carry rows for both the closing week and the
new one. A check that only counts banned-vs-not-banned across all rows returns `OK` when the new
week is banned and the **closing** week — the one the imminent reward run pays out on — is not.
Assert explicitly that the closing week's row exists and is banned; the weekly `PeriodId` is the
window's Monday as `yyyymmdd` (sweep 2026-08-09 → closing period `20260803`, new `20260810`).
Caught only because the operator flagged the rollover; the script as written would have passed.

**Aggregate these checks database-side.** The MCP result view truncates at ten rows, and a
per-row listing of ten banned players across three period types is far past that — a verdict read
off the visible rows is a verdict read off an arbitrary subset. Return counts, not rows.

**Block C — the net** *(added week-18)*. Blocks A and B look only at accounts that were banned, so
neither can see a candidate the review did not convict standing in the money. Block C takes the
whole reviewed cohort and reports anyone inside the closing period's risk zone. It is a net, not the
primary control — the risk zone of step 1.5 is what actually protects the payout, and block C
catches the case where the zone was computed wrong or the board moved after it was.

Separate the two findings in the output. A **convicted** candidate without a ban is a failure and
must be fixed before the payout. An **acquitted** one standing in the money is information, not an
alarm: week-18 acquitted a candidate at 6th place who duly collected, and that was the correct
outcome of a reasoned acquittal. Flagging both identically will make the check cry wolf and it will
stop being read.

### 8. Community/Support handoff

`artifacts/cs-report-<date>.md` plus three per-platform TSVs:
- `cs-report-<date>-steam.tsv`
- `cs-report-<date>-ps.tsv`
- `cs-report-<date>-xb.tsv`

The TSVs are the actual data Support pastes into the shared Google Sheet (new tab per cycle).
Verdict column is normalized to two values for cleanness: **BANNED** (banned by us this cycle
OR pre-actioned by Support before our sweep) and **WATCH** (reviewed, not banning under our
methodology). Internal sub-categories (which BANNED rows are ours vs Support's, which WATCH is
which flavor) get explained in the `cs-report-<date>.md` Reading notes — not in the TSV.

The TSV column order is documented in `cs-report-<date>.md` and follows the SQL output, **minus the
internal diagnostics**: `BracketCoverage`, `PlaceZero` and `DqWithPlace` are ours, not Support's,
and are stripped before the handoff *(week-20)*. Where `BracketCoverage` was not `ok`, what Support
receives is the **recovered** bracket split from the card, not the short one the screen emitted —
that is the whole point of recovering it.
Per-bracket cells use `N / M / T` with spaces (`8 / 12 / 0`) on purpose because Google Sheets
auto-parses `8/12/0` as a date.

**Two-phase TSV write**: pre-ban the TSV captures the snapshot at sweep time (used to brief the
md report); post-ban the SQL is re-run and the BANNED rows' `IsBanned` / `BanEnd` columns get
refreshed to reflect the just-set ban. If the post-ban refresh lands right after the same-session
commit, **use `git commit --amend --no-edit`** to fold it into the ban-pack commit rather than a
separate refresh commit. See `<memory>/feedback_post_ban_tsv_amend.md`.

### 9. Slack handoff to CS lead

A conversational Russian-language prose message to the CS team lead summarizing the cycle:
total banned, recidivism notes, watchlist escalators, support cross-check, watchlist that
remains. Draft saved transiently as `artifacts/slack-cs-<date>.md` during the session, sent by
the human, then deleted before commit.

Register is **conversational colleague**, not commits/JIRA-style technical. Specific rules from
`<memory>/feedback_slack_cs_register.md`:

- Open with a standalone courtesy paragraph for off-hours sends: "Это отложенное сообщение."
- Use colloquial substitutes: `нубики` / `нубы` / `сидение в нубах` / `метагейм` / `банвейв` /
  `WATCH-лист` (capslock + dash for the last, mirrors the TSV Verdict column)
- Frame lists as cross-cycle comparison material, not delegated work
- Subject is the player, not the tool: "научились играть аккуратнее, чтобы обойти фильтры"
  beats "обходить наш фильтр"
- Prose paragraphs, not bullets
- Names sparingly
- Close: `Если что — пиши.`
- Minimal markdown overall

### 10. JIRA comment

`https://fishingplanet.atlassian.net/browse/FP-43631`. Posted via Atlassian MCP. Register is
**impersonal/passive — no `we`/`our`/`us`**. See `<memory>/feedback_jira_impersonal_register.md`.

Replace patterns:
- `we didn't re-ban any of them` → `none of the four were re-banned`
- `our 2W standard` → `the 2W standard`
- `our review` → `the trial review`
- `our week-4 ban` → `the FP-43631 week-4 ban`
- `banned by us 4 → 17` → `banned this cycle 4 → 17`

Structure mirrors weeks 5-7:
1. **Bold opener**: `**Week-N follow-up complete.**`
2. **Bans paragraph** with all banned player names as webadmin links:
   - Steam: `https://steam-webadmin.fishingplanet.com/Player/PlayerCard?userId=<lowercase-uuid>`
   - PS: `https://ps-webadmin.fishingplanet.com/Player/PlayerCard?userId=<lowercase-uuid>`
   - Xbox: `https://xb-webadmin.fishingplanet.com/Player/PlayerCard?userId=<lowercase-uuid>`
3. **REPEAT paragraph** with concrete recidivism details (which week's ban expired when, how
   fast they came back)
4. **Most decisive cases** highlighted by name
5. **Support cross-check** paragraph — list pre-actioned with their wide-cohort presence, note
   trial-Support alignment count
6. **Watchlist escalators** paragraph if any fired
7. **Watchlist remaining** paragraph with brief reason per row
8. **Leaderboard sanity check**: `period <YYYYMMDD>` top-10 by Wins, count how many of cohort
   appear, list the names with rank
9. **Funnel vs prior cycle**: `wide no-show cohort A → B, tight farm-gated A → B, banned this cycle A → B`

ASCII rules from the global config DON'T apply here — JIRA accepts and renders `—` / `→` /
smart quotes / etc. natively. ASCII-only is **commits and code** only.

### 11. KB commit

Single commit per cycle covering: SQL ban script, JS banLog backfill, verify SQL, ban execution
md, CS report md + 3 TSVs, trajectory queries JS, trajectory cards directory, journal
milestones append.

Commit message describes **what changed in the KB**, not the contents of the artefacts. The
weekly ban-pack is the same shape every cycle (SQL ban script, JS banLog backfill, verify SQL,
ban execution md, CS report md + TSVs, trajectory queries JS, trajectory cards, journal
milestones) — collapse it to one bullet. Add a separate bullet only when something durable
beyond the weekly artefact set landed (new playbook file, new shared script, methodology rule
change, etc.).

Template:

```
FP-43631: [RatingDropAbuse] Week-N report[; <extra change if any>]
+ Week-N ban-pack and CS handoff
+ <durable addition not part of the weekly artefacts, if any>
= <durable change to existing KB file, if any>
(Story: [Server][Community] Find players dropping Competitive Rating to exploit new Matchmaking)
https://fishingplanet.atlassian.net/browse/FP-43631
```

Bullet rules from the global commit-message spec:
- `+` for additions, `=` for changes
- One bullet per file/change; don't restate what's in the file
- ASCII-only (`—` → `--`, `→` → `->`, smart quotes → ASCII)
- Backticks via single-quoted heredoc `cat <<'EOF'` — **do NOT escape backticks with `\`** or
  they ship as `\token\` in the log. See `<memory>/feedback_heredoc_backticks.md`.

The raw Mongo dump TSVs (the 3 per-platform files at step 3, and the 24 per-candidate raw .tsv
files post-split) are **NOT committed** — they're transient parser-agent buffer. Only the
distilled `<uid>-<slug>.md` cards are kept (~100-200 KB total instead of 15+ MB).

The trajectory queries JS file (`pcr-trajectory-queries-<date>.js`) IS committed — it's the
recipe to regenerate the dumps if ever needed.

A transient `_parse.py` script written by the parser agent may end up in the directory; it's
small (~15 KB) and reusable, so leave it in or remove based on cleanliness preference (week-6
removed it, week-7 kept it).

If the post-ban TSV refresh happens right after the ban-pack commit, **amend instead of a
separate commit** — see `<memory>/feedback_post_ban_tsv_amend.md`.

## Per-cycle artifact naming

Date in filenames is the **sweep date** (Sunday), not the ban date (Monday). E.g. week-7 sweep
on 2026-06-21 → all files dated `2026-06-21`, ban date is 2026-06-22.

```
artifacts/
├── bans-<sweep-date>.sql                           # Profile ban + audit
├── bans-<sweep-date>.md                            # execution record + trial verdicts table
├── ban-log-backfill-<sweep-date>.js                # Mongo banLog inserts
├── verify-bans-<sweep-date>.sql                    # 3-layer post-ban check
├── cs-report-<sweep-date>.md                       # CS handoff narrative
├── cs-report-<sweep-date>-{steam,ps,xb}.tsv        # CS handoff data
├── pcr-trajectory-queries-<sweep-date>.js          # Mongo aggregate (recipe)
└── pcr-log-trajectories-<sweep-date>/
    ├── <uid>-<slug>.md   × N                       # distilled trajectory cards (kept)
    └── _parse.py                                   # optional helper from parser agent
```

Static shared artifacts (not per-cycle):
- `artifacts/detection-screen.sql` — the canonical detection query. Only `@WindowStart` and
  `@WindowEnd` change between cycles, and **the values committed in the file are last cycle's, not
  this one's** — the dates are run parameters that happen to live in the source, so the committed
  state is always one week stale by design. Set both before running. Renamed from
  `week3-cs-report.sql` in week-20; it had carried the name of its first cycle for 17 weeks and
  records written before then refer to it by the old name.
- `artifacts/leaderboard-ban-sync.sql` — LB sync, idempotent, safe to re-run

## Key concepts that distinguish BAN from WATCH

**This section is a map, not the law** *(rewritten week-20)*. The standing rules in step 5 govern;
where the two disagree, step 5 wins and this block is wrong and must be fixed. It drifted badly
between weeks 13 and 20 — describing a withdrawn rule 6, a rule 3 that has since stopped
releasing, and a rule 5 without its operative test — and a judge working from it applied a
different rule set than one working from step 5.

**There are three independent conviction routes**, and only the first needs rule 1's two limbs:
rule 1 (both limbs), **rule 9** (the within-bracket farmer, who satisfies limb 1(a) and fails
1(b) because there is no bracket below him to be displaced into), and **rules 4 and 8** (the
returning-WATCH ladder, "BAN without further deliberation", which asks for no limb analysis at
all). Failing rule 1 is not an acquittal until the other two have been checked.

**Route 1 — rule 1, both limbs, plus the profile check:**
1. **Chosen descent** — limb 1(a). Either net-negative PCR over the window with the gap
   attributable to unproductive participation, **or** net-positive where rule 5's operative test
   is met: at least 2 `middles_to_noobs_drops`. Net-positive alone is not a defence and is not a
   bar.
2. **Payoff below the ceiling** — limb 1(b). Prizes concentrated below the higher of the bracket
   he actually reaches and his counterfactual ceiling (entering rating + `RatingFromProductivePlay`).
   NOOBS concentration is the common case, not the required one: the mechanism is bracket-relative
   and operates at every boundary. Rule 5 never supplies this limb.
3. **Lifetime profile does not structurally exclude the shape** — fresh accounts pass trivially;
   long-tenured MIDDLES/TOPS veterans need a flavour change toward the lower bracket.

**WATCH where all three routes fail** — none of these is sufficient on its own, because rule 9 and
the rules 4/8 ladder convict without rule 1:
- limb 1(b) fails on **both** ceilings: neither the bracket actually reached with meaningful
  exposure nor the counterfactual ceiling rises above the bracket the prizes sit in, so the
  shedding bought no displacement — **and** rule 9 does not fire
- the prize signature sits in one bracket only, no ceiling above it can be established, and the
  player is not inside the bottom bracket (where rule 9 governs instead); under rule 7 a high-PCR
  sandbagging WATCH carries a one-cycle clock
- sandbagging entirely inside TOPS: PCR above 1000 throughout **and** prizes in TOPS. A player
  above 1000 taking MIDDLES prizes is displaced and belongs under rule 1
- the returning-WATCH ladder has not fired — rules 4 and 8 carry the escalation on the clock

**Not WATCH routes, though they were once written here:**
- *a thin record* — rule 3 caps conviction confidence at 7 since week-20; it does not release,
  and there is no minimum confidence for BAN
- *novice deference* — withdrawn in week-13. Low lifetime volume is **aggravating** where
  in-window extraction is high, not mitigating
- *degraded evidence* — caps confidence the same way, and does not decide the verdict

**Within-bracket abuse pattern** (post-week-10 sandaljepitt, rule 9 formalized): a player
farming NOOBS prizes entirely below PCR 100 (never climbs into MIDDLES, no MIDDLES->NOOBS
drops possible) satisfies limb 1(a) but fails limb 1(b) by absence-of-signal. Rule 9 (see
Standing rules section) closes this gap: high `UnproductiveSharePct` + pure NOOBS flavor + max PCR
below 100 across the window + >= 10 `Registrations`. Judges should accept within-bracket abuse
as load-bearing BAN evidence even without cross-bracket signature.

**Watchlist escalation rule** (rule 4): a player carried over from a prior cycle's watchlist
who shows flavor change to pure NOOBS this cycle is BAN without further deliberation. Fired
cleanly across cycles:
- Week-7: `rabolio41100` (from week-6), `maminapokorny83` (from week-5)
- Week-8: `MonsterFish_fuark` (from week-6), `Matiamo_PL` (from week-7)
- Week-10: `CreekSamurai` (from week-9 novice-deference WATCH — validation of rule 6/8 ladder)

**FarantirPL non-return** (week-9 novice-deference WATCH → did not appear in week-10 cohort) is
the parallel data point confirming rule 6 correctly declined to BAN on cycle 1. Rule 6 -> rule
4/8 escalation ladder demonstrated both directions in the same follow-up cycle (week-10).

## Trial-Support alignment

Cross-checking the wide cohort against Mongo banLog `Competition ban` entries reveals which
players Support had already actioned before the sweep. These get logged in the bans-md under
`support_pre_actioned_trial_confirmed` and are NOT re-banned (their Support BanEnd typically
runs past the 2W standard; the Step 6 SQL WHERE clause skips them automatically).

Running alignment counter — independently confirmed BAN verdicts on Support-actioned candidates
at the rating-drop vector:

| Cycle   | Support pre-actioned | Trial verdict alignment | Cumulative |
|---------|---------------------:|-------------------------|-----------:|
| Week-6  | 0 in rating-drop domain (`VM_NPWP` was anti-cheat-orthogonal) | n/a       | 0/0        |
| Week-7  | 4 (Kacumi, poink, A-J-Rimmer-BSC, nowa_zajawka)              | 4 conf 9-10/10 BAN | 18/18 |
| Week-8  | 2 (Adlerblut-Slayer, TR-dennisfb)                             | 2 conf 10/10 BAN   | 20/20 |
| Week-9  | 2 (ArTeM209, Gustyn112)                                       | 2 conf 9-10/10 BAN | 22/22 |
| Week-10 | 7 (JFF_Gothyka, LaccFarro, CreekSamurai, MLG720YOLO, Da Sneaky Snake, CraddiePoosta, **sandaljepitt**) | 6 confirmed BAN + **1 dissent (sandaljepitt: trial WATCH conf 7)** | **27/28** |
| Week-11 | 5 (yevhen331, sen1a, evgeniy3311, Ricky27sampei, **LZ23J7KS**) | 4 confirmed BAN + **1 dissent (LZ23J7KS: trial WATCH conf 7 under rule 7 direction 2)** | **32/34** |
| Week-12 | 3 (KondaFlk, VGB_N4rkos060905, rascof molotov) | 3 confirmed BAN, conf 9-10, all defense CONCEDE | **35/37** |
| Week-13 | 7 (LuizFernandoo, BarbosUa, MORPH3US, ELPEZGORDO12, aperno, La_Iena_River_, ZacKasoN) | **First Support-blind run.** Under the previous rules 5 of 7 confirmed (ELPEZGORDO12 and ZacKasoN released under rule 6); under the revised rules **7 of 7** | **42/44** |

**No longer maintained from week-18.** The counter stopped being updated after week-13 and nobody
missed it, which is the answer to whether it was doing work. It was always a sanity check rather
than a validation -- the post-Codex caveat below says so -- and the Support-blind change of week-13
did not convert it into one, because a real measurement needs blind replay of prior weeks against
later observed persistence, not a running tally of agreements. The rows above are kept as a record
of cycles 6-13. Support overlap is still noted per cycle in the ban record, where it belongs as
context for the operator; it is not scored.

**Independence note (week-13)**: from this cycle the review is run **Support-blind** -- the
pre-trial context carries no indication of who Support has already actioned, and NEW/REPEAT
status is set from our own ban history only. The cross-check happens afterwards, at the operator
step. This removes the correlated-reasoning weakness that made the counter a sanity check rather
than a validation, and it is what made the rule-6 measurement possible: with Support status
visible the judges would most likely have banned the two missed candidates for the wrong reason
and the defect would have stayed invisible. The counter above records the revised-rules figure.

**Interpretation caveat (post-Codex)**: the alignment counter is a sanity check, not a
validation metric. Independence is weak because Support-pre-actioned status is included in the
pre-trial context field (methodology Step 5), so the judge is not blind to Support's action
when rendering the verdict. Kept for operational awareness; a real validation would require
blind replay of prior weeks (strip labels/status/history, mix in non-cohort negatives, score
against later observed persistence + leaderboard extraction).

**sandaljepitt (first dissent)**: Support pre-actioned at 2W for rating-drop (cheat bans on FP
are permanent -- the 2W duration confirms the vector). Trial gave WATCH under rule 6
novice-deference (Lifetime 5) with load-bearing structural argument: PCR range 0..69 entirely
inside NOOBS bracket, 0 MIDDLES->NOOBS drops -- no cross-bracket signature. Support saw enough;
trial framework did not. This is the within-bracket blind spot rule 9 candidate would address
(see Standing rules section).

## Methodology refinements over cycles

Each new refinement is documented in the bans-<date>.md `methodology_refinement` frontmatter
section the cycle it's discovered, then carried forward via memory rules.

| Cycle | Refinement | Memory rule |
|---|---|---|
| week-3 | Mongo Tournament-log batched-flush as intent evidence | (in journal) |
| week-4 | Three-layer verify per platform individually (post-incidents) | (in journal) |
| week-5 | Adversarial trial introduced; one-cycle WATCH downgrade pattern (Lay_D14S) | (in journal) |
| week-5 | Slack CS register: conversational, no bullets, "нубики" | `feedback_slack_cs_register.md` |
| week-6 | Verdict column reduced to BANNED/WATCH for cleaner CS sheet | (in journal) |
| week-6 | Fresh-lifetime + 3+ wins needs joint test (net-negative + MIDDLES exposure) | (in journal) |
| week-6 | Watchlist-to-ban escalation requires flavor change to NOOBS prizes | (in journal) |
| week-6 | `IsCompetitionsBannedNow()` canonical semantic; SQL WHERE clause gotcha | `feedback_competitions_banned_semantic.md` |
| week-6 | Heredoc backticks: do NOT escape with `\` in single-quoted heredocs | `feedback_heredoc_backticks.md` |
| week-7 | Net-positive PCR alone doesn't defeat bracket-farming (Kacumi calibration) | (in journal) |
| week-7 | Slack register: standalone courtesy opener, метагейм/банвейв/WATCH-лист | `feedback_slack_cs_register.md` (updated) |
| week-7 | JIRA register: impersonal/passive, no we/our/us | `feedback_jira_impersonal_register.md` |
| week-7 | Mongo trajectory: one consolidated `$in` aggregate per platform, not N queries | (in journal) |
| week-7 | Post-ban TSV refresh: amend ban-pack commit, not separate commit | `feedback_post_ban_tsv_amend.md` |
| week-7 | Re-ban WHERE clause adopts canonical form | (in `bans-2026-06-21.sql`) |
| week-8 | Novice-deference rule 6: NEW first-cycle + TotalPrizes < 10 → WATCH with week+1 escalation bias | (in `bans-2026-06-28.md` KingYakO2 case) |
| week-8 | High-PCR sandbagging rule 7: one-cycle clock on WATCH; NOOBS shift → BAN under rule 4 | (in `bans-2026-06-28.md` TR-dennisfb case) |
| week-8 | Mongo banLog backfill ships with active `insertMany([...])` blocks (no `//` prefix) | (in Step 11 above) |
| week-8 | Post-ban TSV refresh: `git commit --amend --no-edit` on the ban-pack commit | `feedback_post_ban_tsv_amend.md` |
| week-8 | Monthly leaderboard sanity check added to the cycle (period 20260601 top-50 across 3 platforms) | (in `bans-2026-06-28.md`) |
| week-9 | Rule 8 novice-deference ladder: WATCH once, auto-BAN on pattern persistence (validated week-10 CreekSamurai) | (in `bans-2026-07-05.md`) |
| week-9 | June monthly LB back-fill script: `monthly-lb-ban-june-2026.sql` (kept for future cycles; June run was no-op) | (in `bans-2026-07-05.md`) |
| week-9 | Commit-message rule: describe what changed in KB, not artefact contents; weekly ban-pack collapses to one bullet | (in Step 11 above) |
| week-10 | Sink-comp repeat targeting: same competition ID NO-SHOWed twice by same UserId is smoking-gun intent evidence that overrides sample-size defense | (in `bans-2026-07-12.md` Miron_33 case) |
| week-10 | First Trial-Support dissent on rating-drop (sandaljepitt): rule 9 candidate for within-bracket detector | (in `bans-2026-07-12.md` and standing rules above) |
| week-10 | LaccFarro operational case: our week-6 REPEAT trial-confirmed but Support already covered him at 5W; WHERE clause correctly skipped Profile update, Mongo banLog audit entry inserted (record of intent) | (in `bans-2026-07-12.md`) |
| week-10 | Codex consultation deferred followups: (a) methodology.md stale — this update addresses it; (b) two-phase blind→informed verdict architecture; (c) alignment counter is sanity check not validation, real falsification needs blind replay; (d) blind spots list — boundary camouflage (sandaljepitt), start-but-throw pivot (ZeroScore column unused), data-source SQL/Mongo reconciliation gate | (in `bans-2026-07-12.md`) |
| week-11 | Rule 7 direction 2 EMPIRICALLY VALIDATED for closure: LZ23J7KS (2nd Trial-Support dissent) confirms TOP-flavor MASTERS sandbagger family (LZ23J7KS/JIALIN0720/Bas_di08/VM_Vigor/Panonski_Alas) exits FP-43631 scope. Support scope broader; our methodology targets NOOBS-farming only | (in `bans-2026-07-19.md`) |
| week-11 | Rule 6 → rule 4/8 ladder VALIDATED SECOND TIME: evgeniy3311 (was W10 WATCH conf 7 Lifetime 10) escalated +11 NOOBS prizes → Support pre-actioned at 2W matching rule 4 auto-BAN. First was CreekSamurai w9→w10. Off-ramp works | (in `bans-2026-07-19.md`) |
| week-11 | Rule 6 in-window vs lifetime ambiguity flag: La_Iena_River_ (Lifetime 54, in-window TotalPrizes 6) triggered rule 6 novice-deference. On the standard wide-cohort where TotalPrizes gates are 4-11, rule 6 fires broadly. **Recommend clarifying: "Lifetime prizes < 10" is the KingYakO2-intent threshold; in-window prizes are a separate factor** | (in `bans-2026-07-19.md`) |
| week-11 | Rule 9 vs rule 6 collision flag: TurboBandz6351 hit ALL rule 9 gates (NS 46%, pure 5N, max PCR 81 < 100, Reg 29 >= 10) AND rule 6 novice-deference (Lifetime 5). Judge resolved via rule 6 override + rule 8 persistence clock. **Formalize precedence: rule 6 wins on first-cycle NEW, rule 8 carries the escalation** | (in `bans-2026-07-19.md`) |
| week-11 | Cheat-vector orthogonality precedent: Belion019 (Xbox) had 88 CHEAT triggers active (Undriven boat / Fish catch distance / Line high extension) alongside a clean rating-drop pattern (4 Kacumi + 6 batched flushes + 1 M→N). Trial BAN 2W on rating-drop grounds only, cheat vector orthogonal (AntiCheat framework separate scope). No methodology change; rules fire independently | (in `bans-2026-07-19.md`) |
| week-12 | **PCR-floor evidence gap, code-verified** — the rating is clamped at zero and the ledger write is conditional on it changing, so a penalty landing on an already-zero rating emits NO ledger line. Volume must come from SQL, the card is authoritative only for shape, and a sparse card for a floored candidate is an artifact rather than exculpatory. Also: the printed Delta is the assessed penalty while the parenthetical is the clamped movement. Retroactively explains the parser-vs-SQL divergence open since week-9 | `<kb>/fishing-planet/server/modules/matchmaking/rating-application.md` |
| week-12 | Ledger gap has TWO causes and must not be read as one metric: floor absorption (above) vs queued application (assessed but player not reconnected — the batched-flush signature). Discriminator: presence of any `-> 0)` line in the window. Exact per-candidate `floor_shots` needs a comp-id level join — deferred | (in `bans-2026-07-26.md`) |
| week-12 | **Boundary-targeting discriminator** emerged independently across judges: deliberate deflation should cluster near the bracket boundary, since shedding rating deep inside NOOBS buys nothing. Used to decline rule 1 on four candidates. **Operator partially rejects it** — a player who wins inside NOOBS accrues rating that must be shed continuously, so deep-bracket no-shows are ceiling maintenance and the equilibrium is the signal. Useful as corroboration; its absence should not alone defeat rule 1. To settle with the CS lead | (in `bans-2026-07-26.md`) |
| week-12 | **First operator override of a verdict** (dreadloc). Criterion: presence in the platform weekly Won leaderboard top-10, scoped to NOOBS-flavor extraction. Rationale: top-10 is where prizes are actually taken, so deferring on a player converting a suppressed rating into rewards defers past the payout. Canonical ranking per `<kb>/.../leaderboards/data-model.md`. Deliberately NOT applied to X1aoDouYa / autoteo78 (MIDDLES-bracket wins) nor La_Iena_River_ (qualifies on flavor but trend is upward — held, re-check next cycle) | (in `bans-2026-07-26.md`) |
| week-12 | Rule 7 direction 2 produced its **first actual closure**: Panonski_Alas EXONERATEd and exits tracking rather than rolling forward on another WATCH. Family remainder: X1aoDouYa, EsseDouble, autoteo78 | (in `bans-2026-07-26.md`) |
| week-12 | Briefing defect caught by a judge: same-second batched groups are **flush moments**, not proof of contemporaneous presence. Future briefs must state this explicitly so prosecutors stop arguing "he was online while burning parallel registrations" | (in `bans-2026-07-26.md`) |
| week-12 | Rule 6 wording corrected in the brief to **LIFETIME** prizes < 10 (the KingYakO2 intent), resolving the w11 in-window/lifetime ambiguity. Rule 9 precedence made explicit: rule 6 outranks rule 9 on a first-cycle NEW candidate, but not on a returning one — which is what carried TurboBandz6351 to BAN | (in `bans-2026-07-26.md`) |
| week-13 | **Rule 6 rewritten from leniency into aggravator; the week-8 novice-deference version withdrawn.** Measured by an A/B over the same 18 candidates with identical evidence, both runs Support-blind: previous rules 11 BAN and released two players Support had banned, revision 14 BAN and released none, no confident BAN destabilised. Basis: twelve deference WATCH verdicts across weeks 8-13, zero ever vindicated | `bans-2026-08-02.md`; rule 6 in Standing rules |
| week-13 | **Absence from a later cohort retired as evidence.** Previously recorded as validating a WATCH (FarantirPL w9 and several w10 candidates); FarantirPL returned this cycle at 70% no-show after two absent cycles. Now an explicitly closed defense alongside the recovery-climb | (in `bans-2026-08-02.md`) |
| week-13 | Rules 3, 4, 8, 9 adjusted alongside rule 6 — rule 3 becomes the sole evidentiary leniency and is framed as data-sufficiency, rules 4 and 8 broadened from watchlist/novice scope to any returning WATCH, rule 9 precedence corrected so inexperience no longer outranks the within-bracket detector (the w12 precedence is withdrawn — it is what released ZacKasoN) | (in `bans-2026-08-02.md`) |
| week-13 | **Review is now run Support-blind** and the cross-check moved to the operator step. Recommended permanently — it converts the alignment counter from a sanity check into a real measurement | (alignment table above) |
| week-13 | **Uniformity cannot be achieved by instruction.** The rule 7 uniformity clause did not bind: X1aoDouYa drew EXONERATE and EsseDouble WATCH on near-identical profiles in both runs, because judges are independent and cannot see one another. Family-level consistency needs an operator pass | (in `bans-2026-08-02.md`) |
| week-13 | **Ban durations raised to 4W NEW / 8W REPEAT** after measured recidivism intervals (13-31 days after a 2W ban lapsed). CS lead proposed permanent for repeat offenders; 4W/8W is the interim step. Support's own duration practice found to be split between operators (one month vs two weeks in the same week) | (in `bans-2026-08-02.md`) |
| week-13 | Registration attempts while banned examined as a candidate aggravator and **rejected** — the client is sent the ban end date but shows a static message without it, so a banned player cannot learn when the ban ends and retries are the rational response. Not evidence of intent. Withholding the date may be deliberate policy. Verified counts differ from the parser's (two message formats exist, only one was recognised) | (in `bans-2026-08-02.md`, `banned_registration_attempts_RETRACTED`) |
| week-18 | **Screen counts unproductive participation** — no-shows plus zero-score finishes, DQ excluded from the zero-score branch only. `ZERO-SCORE` added as a third card status, fed from SQL competition ids because the ledger cannot distinguish an empty start from a scored one | (step 1; `bans-2026-09-06.md`) |
| week-18 | **The brief must carry the standing defect list.** Omitting the week-12 flush-moment finding cost an entire hearing: 4 BAN of 17 on the first pass, 5 more on re-hearing with the list restored. A process failure, not a rules failure — rule 1 was not changed | (step 5; `bans-2026-09-06.md`) |
| week-18 | **Case context verified against the card before dispatch.** `MaxRatingAtStart` is the rating carried into a competition, not the weekly peak; conflating them put a false claim into the trial and then into the outward handoff | (step 5) |
| week-18 | **Risk zone computed before the trial** — top (10 + N) per platform, N = candidates on that platform. A ban vacates the place and promotes those below into the money, measured on Xbox. Prizes are the only irreversible loss, so the zone is the critical path and everything outside it can wait | (step 1.5) |
| week-18 | **Block C sweeps the whole cohort**, not only those banned, distinguishing convicted-but-unapplied (a failure) from acquitted-in-the-money (information) | (step 7) |
| week-18 | **Outage defence closed.** Planned downtime cancels competitions outright, so it produces no absences; unplanned incidents are rare and are a question for the operator, not a query. Measured once and found absent | (step 5) |
| week-18 | **SQL is complete but split** at roughly 60 days into `Archive*` tables, which do carry the FP-43816 columns. The failure mode is silent — the live tables simply return nothing for older periods, which reads as inactivity | (step 3) |
| week-18 | **Trial-Support alignment counter retired.** Unmaintained since week-13 and never a validation; Support overlap stays as per-cycle context in the ban record, unscored | (alignment table above) |
| week-19 | **Rule 3 counts events, not games, and the threshold moves to 15.** The old counter (fewer than 10 PLAYED) measured the wrong quantity -- the offence is not playing, so the heaviest drainers had the fewest games and were sheltered most readily. It released 2 of 12 candidates this cycle, one with the pattern expressly established, and needed an operator override to correct. 10 events is the screen's structural floor and cannot serve as a threshold | (step 5 rule 3; `bans-2026-09-13.md`) |
| week-20 | **Screen window cut on `EndDate` and bounded at both ends.** A competition belongs to the week it ends in, and the scheduled end path writes the board row 2 seconds after `EndDate` while the review path does not apply to `KindId = 3`, so screen and board agree except under a processing stall; the old `StartDate` filter selected a different set and had no upper bound, so its span depended on run time. Measured: same 83 competitions, 1 candidate different each way, and the one missed was a returning WATCH | (step 1; `detection-screen.sql`) |
| week-20 | **`week3-cs-report.sql` renamed `detection-screen.sql`** after 17 weeks under the name of its first cycle. Committed window dates are always last cycle's -- they are run parameters living in source | (step 1) |
| week-20 | **Board is final from 22:00 UTC Sunday; the week-19 drift allowance is withdrawn.** Tie-break is by earliest timestamp, so the boundary competition's winner heads his tie group -- measured worthless: across 20 weekly periods a single win was never rewarded, best placing 14th against a paying depth of 10 | (step 1.5) |
| week-20 | **Trial verdicts are persisted** to `pcr-log-trajectories-<date>/_verdicts.md`. Week-19's cited a 6/6 split and per-case confidences that could not be checked a week later; recovered only because the temporary file happened to survive | (step 5) |
| week-20 | **REPEAT counts any expired competition ban, whatever it was for.** Support-blindness belongs to the trial, not to the tariff; the 2 were conflated in week-13. The type matters and the reason does not -- a policy, not a finding. Corrected in the same pass: the section claimed the query filters on a ban date after the matchmaking launch. It does not and cannot -- `Profiles` holds only the end date, so a long pre-launch ban is indistinguishable from a recent one | (step 6) |
| week-20 | **The BAN/WATCH summary block rewritten and subordinated to the standing rules.** It had drifted since week-13 -- describing the withdrawn novice deference, a rule 3 that no longer releases, a rule 5 without its operative test, net-negative PCR as a requirement, and NOOBS concentration as the required rather than the common case -- so a judge working from the summary applied a different rule set than one working from step 5. It now says in its first line that step 5 governs | (Key concepts section) |
| week-20 | **Limb 1(b)'s counterfactual ceiling refunds unproductive participation, not just no-shows.** The wording still read "the penalties he took by not appearing" after week-18 widened everything around it, so a zero-score drainer's ceiling came out near his actual rating, limb (b) failed and he was acquitted on the precise route he used -- the Myky0576 shape, invisible again by a different mechanism. Found by Codex on the consistency pass; neither the reviewer nor the operator caught it | (step 5 rule 1(b)) |
| week-20 | **`confidence` measures how firmly the finding is established, and there is no minimum confidence for BAN.** A capped case is convicted at the cap with the cap's reason named. Without saying so, the two caps introduced this cycle -- rule 3 for a thin record, step 4.5 for degraded evidence, both at 7 -- would have quietly restored the defeater rule 3 stopped being: the record shows ZellyRolled and Lay_D14S both returned WATCH at exactly 7, the last writing "conviction threshold not met" in terms. The caps do not compound | (step 5) |
| week-20 | **An operator override now requires a blind re-hearing**, recorded either way, informing rather than binding. It audits the reason, not the outcome: the ZellyRolled override was right on the merits but its recorded ground was rule 3, and rule 3 was rewritten the same night on that ground, while the verdict actually rested on two legs and named limb 1(a) as not relied on. Week-18 re-heard its 2 overrides and both came back convicted at 8 and 9 | (step 5) |
| week-20 | **The payout deadline is soft and the softness is priced; monthly and yearly boards pay too.** A prize is not irreversible -- it can be annulled and passed down the table, an offline delivery caught, a missed prize granted late -- but each is a manual compensation action costing operator time and disturbing players, so the zone is judged first and lateness is not free. The asymmetry decides the boundary case: moving a prize down the table is honest and cheap, taking one from someone who turns out innocent is neither, so an undecided case keeps its prize and conviction follows next cycle. Urgency was what produced the week-18 and week-19 overrides, and it rested on an irreversibility that does not exist. Separately: 6 of the 9 boards pay, not 1 -- Won and Rating on weekly, monthly and yearly | (step 1.5) |
| week-20 | **`presence_gaps` on the card: intervals of 2h or more with no log line of any type, and every unproductive entry marked `in-gap` or `in-presence`.** The outage defence, the over-registration argument and the operator's memory were all standing in for a measurement nobody took; a judge had already reconstructed it by hand for AdmiralAckbar98 from lines the parser was told to discard. Anchored on the flush moment, so it bounds the argument rather than settling it -- completing it needs competition start times, which the ledger does not carry | (step 4; step 5 defect list) |
| week-20 | **Rules 8(c) and 9(a) and the glossary now read unproductive participation, not no-shows.** The screening threshold moved in week-18 and the rules that reference it did not follow, so judges were substituting the new metric silently; as written the rules could never reach a zero-score drainer -- Myky0576 ran 27 zero-score finishes against 1 no-show. Thresholds of 30 and 40 are unchanged because both were defined relative to the screening threshold, not as absolute figures. Rule 9's own floor of 10 registrations is live again now that rule 3 caps rather than defeats | (step 5 rules 8, 9; glossary) |
| week-20 | **`CompetitionRatingAtStart` is not always populated, prize rows included, and the screen now says so.** `AppL33` lost 2 plays and 1 prize from the bracket split in week-19, and the lost prize was the NOOBS one on his first event at PCR 0 -- the split understated exactly the evidence that aggravates, and the wrong figure went to Support. New `BracketCoverage` column reconciles the split against its own totals; the parser recovers the missing brackets from the ledger PCR chain. Recovery, not leniency: the shortfall does not feed `evidence_completeness` and is not a defence argument | (step 1; step 4; step 5 defect list) |
| week-20 | **Rule 3 stops being a defeater and becomes a confidence cap of 7.** As a defeater it published an immunity band between the screen's floor of 10 events and the threshold of 15, inside which any severity walked automatically, and it left rule 9(d)'s own floor of 10 as dead text while creating an undefined precedence against rule 4's "BAN without further deliberation". Measured over weeks 18 and 19, 1 candidate a cycle falls under 15 -- KovlekPlayz at 13 and Lesky2123 at 14 -- so the cap costs no material volume. Cancelled registrations are correctly absent from the counter: an unregistration before start is free and sheds nothing | (step 5 rule 3) |
| week-20 | **Rule 5 gets an operative test: it supplies limb 1(a) at 2 or more `middles_to_noobs_drops`, and below that only strips the net-positive defence.** Judges had read it both ways on the same brief -- as a charging provision for seagate22022, Myky0576 and codeco (all BAN) and as a defence-stripper for KovlekPlayz, Lesky2123 and AppL33 (all WATCH) -- and one judge recorded the tension as unresolved without it being picked up. A rising net fails limb 1(a) by arithmetic, so the whole Kacumi shape the rule was written for was convictable or not depending on which judge drew it. Measured against week-19: ZellyRolled 5 drops, FOGGIA1920 2, Lesky2123 2 all satisfy the test; YOUTUBE-Eduzera-YT has 0 and stays outside it, correctly -- his trajectory sits in 434..535 and never approaches a boundary. **Corrected the same cycle:** the 2 drops must fall inside the charge window, and on that reading Lesky2123 does not qualify -- both his are dated 08-31 and 09-02 against a window of 09-07..09-13 | (step 5 rule 5) |

## Example: week-7 walkthrough (2026-06-22 ban date)

Detection: `week3-cs-report.sql @WindowStart='2026-06-15'` × 3 PROD MAIN → 26 candidates.

Trajectory dump: single aggregate over 26 UserIds × 3 Mongo PROD → 3 per-platform .tsv (15 MB
total), split via grep+cut → 26 per-candidate .tsv (~7 MB), parser agent → 26 .md cards
(~200 KB).

Adversarial trial: 78-agent workflow (26 × 3 roles), ~6 minutes, returned 21 BAN + 5 WATCH + 0
EXONERATE.

Support cross-check: 4 candidates already actioned by Support before sweep (Kacumi, poink,
A-J-Rimmer-BSC, nowa_zajawka). Trial confirmed BAN for all 4 at confidence 9-10/10. Not
re-banned.

Bans applied: 17 (12 NEW × 2W → 2026-07-06, 5 REPEAT × 4W → 2026-07-20) across Steam 7, PS 8,
Xbox 2.

Verification: 3-layer clean on all three platforms, zero incidents this cycle.

Handoff: `cs-report-2026-06-21.md` + 3 TSVs (9/15/2 rows) to shared sheet; Slack to CS lead in
conversational register; JIRA comment 125330 in impersonal register; KB git commit `fe13c4c`
(37 files, amended with post-ban TSV refresh).

Methodology refinement caught: net-positive PCR alone doesn't defeat bracket-farming hypothesis
(Kacumi case — week-6 WATCH became Support-banned, week-7 trajectory confirmed the signature
was always real).

## File references for hand-off

This document is the entry point. Concrete recent examples for every step are in:

- `artifacts/detection-screen.sql` — detection query
- `artifacts/bans-2026-07-12.sql` — most recent ban execution
- `artifacts/bans-2026-07-12.md` — most recent execution record with full trial verdicts + refinements ledger
- `artifacts/ban-log-backfill-2026-07-12.js` — Mongo banLog backfill
- `artifacts/verify-bans-2026-07-12.sql` — 3-layer verify
- `artifacts/leaderboard-ban-sync.sql` — LB sync (shared, not date-specific)
- `artifacts/monthly-lb-ban-june-2026.sql` + `-verify.sql` — one-shot LB back-fill scripts (kept for future cycles when Steam patch actually unbans on Profile expiry; the June run was a no-op)
- `artifacts/cs-report-2026-06-21.md` — most recent CS handoff narrative
- `artifacts/cs-report-2026-06-21-{steam,ps,xb}.tsv` — most recent TSVs
- `artifacts/pcr-trajectory-queries-2026-06-21.js` — consolidated trajectory query
- `artifacts/pcr-log-trajectories-2026-06-21/<26 .md cards>` — distilled trajectory cards

Memory rules accessed via `<memory>/MEMORY.md` SQL Conventions / VCS / JIRA sections:

- `feedback_competitions_banned_semantic.md` — IsCompetitionsBanned semantic + SQL gotcha
- `feedback_slack_cs_register.md` — Slack CS register rules
- `feedback_jira_impersonal_register.md` — JIRA passive voice rule
- `feedback_jira_post_preview.md` — paste final text inline before posting
- `feedback_heredoc_backticks.md` — single-quoted heredoc backtick literal
- `feedback_post_ban_tsv_amend.md` — amend ban-pack for post-ban TSV refresh
- `feedback_sql_nolock_session.md` — WITH (NOLOCK) on every read in this task

Journal `<task>/journal.md` is append-only and carries the cycle-by-cycle history.
`<task>/backlog.md` tracks deferred items.

## Deferred architectural refinements (post-Codex, not yet implemented)

Documented for future work. Each item is a real improvement identified in the Codex
consultation post-week-10; not blocking for the weekly cycle but worth acting on.

- **Two-phase blind→informed verdict.** Split the judge into two calls: (1) blind pattern
  verdict reading only the trajectory card (no status, no watchlist history, no Support
  action) — output one of `NOOBS-farm / non-target sandbagging / novice-uncertain / insufficient`;
  (2) informed duration/escalation decision reading blind verdict + pre-trial context (status,
  Support action, watchlist holdover, recidivism). Reduces the correlated-reasoning bias where
  the current single-phase judge sees Support-pre-actioned status in the context field before
  rendering its BAN/WATCH call, undermining the alignment counter's independence. Implementation:
  modify the workflow script in `.claude/…/workflows/scripts/fp43631-*-adversarial-review-*.js`
  to add a blind-pattern agent before the judge.
- **ZeroScore column as second detection path.** The current gate treats `IsStarted=1 AND
  Score=0` (zero-score) as a legitimate play. A farmer who starts a comp and immediately
  disconnects/idles achieves the same NOOBS-drain outcome as a no-show without triggering the
  `IsStarted=0` signature. `detection-screen.sql` already emits `ZeroScore` per candidate; add
  a second-path detection query `zero-score-abuse.sql` that gates on `ZeroScore >= 6` AND
  `NoShowSharePct < 30` (i.e. the population no-show gate misses) AND `TotalPrizes > 3`. Run
  alongside the no-show gate; merge cohorts for the trial.
  **Done in week-18 by another route** *(closed week-20)*: zero-score was folded into the screen
  itself rather than given a companion query. The gate now counts unproductive participation —
  no-shows plus zero-score finishes — on a single pass, so there is no second cohort to merge and
  no `NoShowSharePct < 30` carve-out to maintain.
- **Blind falsification test.** The alignment counter is a sanity check, not validation
  (Codex critique). A real falsification would replay 1-2 prior weeks blind: strip Support
  pre-action flags, watchlist history, and prior verdict labels from the pre-trial context;
  add non-cohort negatives (Support-Competition-banned players NOT in the wide cohort;
  cheat-vector bans; random high-no-show players with 0 prizes). Score blind verdict against
  later observed persistence, leaderboard extraction, and independent Support action. Not
  worth doing weekly, but a good end-of-quarter check.
- **Rule 8 numerical persistence formalized above** (concrete thresholds added in-line at rule
  8). This item retained as a followup for tightening the thresholds after more validation
  cycles.
- **Persistent high-PCR sandbagger auto-close** (rule 7 direction 2 above): once formalized,
  add a "3-cycle sandbagger" auto-close bookkeeping check to the sample triage step (Step 2)
  so operators don't manually re-list VM_Vigor / Panonski_Alas indefinitely.
