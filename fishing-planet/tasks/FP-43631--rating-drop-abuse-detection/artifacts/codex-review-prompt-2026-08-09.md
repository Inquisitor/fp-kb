# Review request — replacing the bracket-flavor rule in the FP-43631 detection methodology

## Context

FP-43631 is a weekly operational cycle detecting competitive-rating abuse in Fishing Planet.
Players deliberately shed Personal Competition Rating (PCR) so that matchmaking places them in a
lower bracket, where they win prizes easily. Brackets: NOOBS 0-100, MIDDLES 101-1000, TOPS 1001+.
PCR is clamped at zero, so penalties landing at the floor move nothing.

The detection query gates on: no-shows >= 6, no-show share >= 30%, rating lost to no-shows <= -90,
total prizes > 3. Cohort is then reviewed per candidate.

Full methodology: `D:/kb/fishing-planet/tasks/FP-43631--rating-drop-abuse-detection/methodology.md`
Deep dive on the rating write paths and the PCR floor:
`D:/kb/fishing-planet/server/modules/matchmaking/rating-application.md`

## What is being changed and why

Standing rule 1 defines the enforcement target by *absolute* flavor: prizes concentrated in NOOBS.
Candidates whose prizes sat in MIDDLES/TOPS were classified as flavor mismatch and repeatedly given
WATCH; standing rule 7 direction 2 went further and let such candidates be *closed* as non-targets
after three unchanged cycles. Two were closed on that basis (Panonski_Alas, X1aoDouYa).

Re-examination of that excluded group produced the data below, which suggests the same
harvest-the-bracket-below mechanism operating at the MIDDLES/TOPS boundary rather than the
NOOBS/MIDDLES one. Measurements are cumulative since matchmaking launch (Steam 2026-04-29,
PS 2026-05-06).

Per-bracket play, prizes and rating economics (N/M/T = NOOBS/MIDDLES/TOPS):

| Player | PCR | Played N/M/T | Prizes N/M/T | Rating from play in M | in T | Rating from absence | Prizes in window | Lifetime prizes |
|---|---|---|---|---|---|---|---|---|
| EsseDouble | 843 | 8/170/5 | 3/21/1 | +1318 | +42 | -730 | 25 | 32 |
| X1aoDouYa | 874 | 0/75/6 | 0/20/1 | +1027 | +54 | -704 | 21 | 70 |
| TrcikLowFiv | 1017 | 2/114/3 | 2/30/1 | +1382 | +55 | -581 | 33 | 60 |
| JIALIN0720 | 772 | 0/81/3 | 0/20/0 | +1168 | -15 | -1273 | 20 | 172 |
| autoteo78 | 778 | 0/39/14 | 0/13/0 | +440 | +32 | -702 | 13 | 39 |
| Bas_di08 | 989 | 0/87/28 | 0/19/0 | +1164 | -63 | -1125 | 19 | 31 |
| Panonski_Alas | 996 | 0/177/72 | 0/37/5 | +1822 | +36 | -1289 | 42 | 87 |
| VM_Vigor | 1071 | 0/158/37 | 0/25/3 | +1453 | +118 | -1436 | 28 | 41 |
| LZ23J7KS | 1042 | 2/19/224 | 1/5/18 | +318 | +850 | -3551 | 24 | 227 |

LZ23J7KS is treated as a different mechanism: he plays and wins in TOPS, harvests no lower bracket.

Population check for deliberate capping just below 1000 (competition-active players, density per
100 rating points): Steam 900-949 = 50, 950-1000 = 47, 1001-1050 = 92. PS 44 / 65 / 84. No pile-up
below the boundary; peak density sits immediately above it.

## Proposed replacement — a bracket-relative test in three components

**Component 1 — harvest share.** `TopBracketReached` = max BracketId over the player's
participations in the window. `HarvestShare` = share of prizes taken in brackets strictly below
`TopBracketReached`. Fires at >= 60% with >= 3 participations in the top bracket reached. A player
who never rose above his residence bracket scores zero and is not flagged.

**Component 2 — conversion differential.** `Conv(bracket)` = prizes / played in that bracket.
Compute `expected = played_in_top_bracket x Conv(harvest bracket)`. The component is admissible
only when `expected >= 5`, and fires when `observed <= expected / 2`. Computed on the cumulative
window, not the weekly one (on a 7-day window `expected` never reaches 5).

Re-scored: Panonski_Alas expected 15.0 observed 5 (fires); Bas_di08 expected 6.1 observed 0
(fires); autoteo78 expected 4.7 observed 0 (borderline admissibility); VM_Vigor expected 5.8
observed 3 (does NOT fire).

**Component 3 — descent by absence rather than defeat.** Rating from actual play is strongly
positive while net rating change is flat or negative, with the difference accounted for by no-shows
and DQs. An honest player at his ceiling has play-rating near zero; he descends by losing, not by
being absent.

**Composition.** Component 3 is necessary (the descent must be chosen). Component 1 establishes
where the payoff is collected. Component 2 corroborates when admissible; its silence is not
exculpatory.

**Anti-capping variant.** A player who deliberately never crosses into the bracket above defeats
component 1 by construction (`TopBracketReached` equals his residence bracket, harvest share zero).
For that case the proposal is: component 3 as trigger, plus a misplacement measure as the evidence
of payoff — a composed prize score `gold/Ng + silver/Ns + bronze/Nb >= 1` against the promotion
thresholds of his bracket (12/15/20 for MIDDLES), plus the existing standing rule 5 (climb-then-
flush cycles visible in the Mongo trajectory ledger).

## Questions

1. Component 2's decision rule. Is `expected >= 5` plus `observed <= expected/2` defensible, or
   should this be an explicit tail probability (e.g. Poisson or binomial one-sided test at a stated
   level)? The `>= 5` came from the conventional minimum expected count; the `/2` is intuition.
   Note the base conversion rate is itself estimated from the same player's data, not known.

2. Component 3's robustness. What honest player profile produces strongly positive rating from
   play together with heavy no-show losses? Enumerate the benign explanations we should be
   excluding, and say whether any of them survive the other components.

3. Whether the anti-capping variant actually closes the gap, or leaves a residual blind spot. The
   misplacement measure uses lifetime counters that accumulate over years, so a long-tenured honest
   veteran scores high; is pairing it with component 3 sufficient to separate them?

4. Component 1's constants (60% share, 3 participations) have no derivation. Propose a basis, or
   say if the component should be reformulated.

5. Is reversing the two rule 7 direction 2 closures justified on the evidence above, or is there a
   reading of that data consistent with legitimate play that we have not considered?

6. Most important: describe a farming strategy that defeats all three components simultaneously,
   given the mechanics stated at the top. Assume the player knows the bracket boundaries and the
   detection gate thresholds.

Answer concretely and prioritise disagreement over confirmation. Where you think a component is
unsound, say what to replace it with.
