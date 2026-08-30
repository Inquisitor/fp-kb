---
type: trajectory-card
task: FP-43631
player: Bongler
profile_id: 9fcd3f1e-df02-47e7-936d-16b70f76dc22
platform: PlayStation
source: 9fcd3f1e-df02-47e7-936d-16b70f76dc22-bongler.tsv
log_window: 2026-08-01T17:52:28Z .. 2026-08-09T04:00:03Z
---

# Bongler (PlayStation) - PCR trajectory

## Summary

| Metric | Value |
| --- | --- |
| PCR at first ledger line (before) | 135 |
| PCR at last ledger line (after) | 106 |
| PCR min | 44 (2026-08-03T18:00:50Z) |
| PCR max | 144 (2026-08-04T08:00:22Z) |
| Ledger entries | 23 |
| Played (scoring-time started) | 8 log-wide / 7 inside SQL window |
| No-shows | 15 |
| Prizes (positive delta) | 4 |
| Batched flush groups | 3 |
| Registration lines | 24 |
| CHEAT triggers | 146 |
| Bracket span | NOOBS <-> MIDDLES only; TOPS never reached |

Floor-clamp caveat does not apply here: every printed delta equals the
before->after pair difference, and PCR never approaches 0 (min 44). No
penalty was silently swallowed inside this window.

## Ledger

Bracket = state after the entry. `->` in the bracket column marks a crossing.

| Timestamp | Comp ID | Comp name | Status | Delta | PCR before->after | Bracket |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-08-01T20:00:33Z | 374633 | Kaniq Topwater Rodeo | PLAYED (place 30) | -5 | 135 -> 130 | MIDDLES |
| 2026-08-03T04:00:14Z | 374835 | Spotted or Banded? | PLAYED (place 26) | -6 | 130 -> 124 | MIDDLES |
| 2026-08-03T06:00:03Z | 374836 | Lucky Ghost Hunt | NO-SHOW | -15 | 124 -> 109 | MIDDLES |
| 2026-08-03T08:00:03Z | 374837 | Falcon Trout Chase | PLAYED (place blank - zero score) | -5 | 109 -> 104 | MIDDLES |
| 2026-08-03T17:21:40Z | 374838 | Idle Ide | NO-SHOW | -13 | 104 -> 91 | MIDDLES -> NOOBS |
| 2026-08-03T17:21:40Z | 374839 | Big Headhunters | NO-SHOW | -13 | 91 -> 78 | NOOBS |
| 2026-08-03T17:21:40Z | 374841 | Steelhead Showdown | NO-SHOW | -11 | 78 -> 67 | NOOBS |
| 2026-08-03T17:21:41Z | 374840 | No Ruler - No Party | NO-SHOW | -20 | 67 -> 47 | NOOBS |
| 2026-08-03T18:00:50Z | 374842 | Big Bowfin Hunting | PLAYED (place 23) | -3 | 47 -> 44 | NOOBS |
| 2026-08-03T20:00:17Z | 374843 | Giant Grouper Roundup! | PLAYED (place 3) PRIZE | +45 | 44 -> 89 | NOOBS |
| 2026-08-04T08:00:22Z | 374921 | Point by Point | PLAYED (place 1) PRIZE | +55 | 89 -> 144 | NOOBS -> MIDDLES |
| 2026-08-04T18:44:15Z | 374923 | Breaking Shad | NO-SHOW | -10 | 144 -> 134 | MIDDLES |
| 2026-08-04T18:44:15Z | 374925 | Barbel Gent Hunt | NO-SHOW | -10 | 134 -> 124 | MIDDLES |
| 2026-08-04T18:44:15Z | 374926 | Tigers Trail | NO-SHOW | -20 | 124 -> 104 | MIDDLES |
| 2026-08-04T20:00:03Z | 374927 | Teenies in the Night | NO-SHOW | -13 | 104 -> 91 | MIDDLES -> NOOBS |
| 2026-08-04T22:00:05Z | 374928 | Cats 'n Nightcatchers | NO-SHOW | -11 | 91 -> 80 | NOOBS |
| 2026-08-05T15:18:58Z | 376069 | Catch em' All | NO-SHOW | -10 | 80 -> 70 | NOOBS |
| 2026-08-05T15:18:58Z | 376070 | Triple Trout! | NO-SHOW | -11 | 70 -> 59 | NOOBS |
| 2026-08-05T18:00:16Z | 376074 | Spotted or Banded? | PLAYED (place 1) PRIZE | +47 | 59 -> 106 | NOOBS -> MIDDLES |
| 2026-08-07T15:22:07Z | 376093 | Lucky Ghost Hunt | NO-SHOW | -15 | 106 -> 91 | MIDDLES -> NOOBS |
| 2026-08-08T20:00:06Z | 376111 | Bass Speed Hunt | NO-SHOW | -15 | 91 -> 76 | NOOBS |
| 2026-08-09T00:00:16Z | 376113 | Big Brother | PLAYED (place 2) PRIZE | +50 | 76 -> 126 | NOOBS -> MIDDLES |
| 2026-08-09T04:00:03Z | 376115 | Woohoo Wahoo! | NO-SHOW | -20 | 126 -> 106 | MIDDLES |

Batched flush groups (several competitions settled in one processing pass):

- 2026-08-03T17:21:40Z / :41Z - 374838, 374839, 374841, 374840 (104 -> 47, -57)
- 2026-08-04T18:44:15Z - 374923, 374925, 374926 (144 -> 104, -40)
- 2026-08-05T15:18:58Z - 376069, 376070 (80 -> 59, -21)

## Bracket crossings

Boundary 100/101 (NOOBS <-> MIDDLES) - six crossings, three each way.

Downward (MIDDLES -> NOOBS), all caused by no-show penalties:

- 2026-08-03T17:21:40Z - 374838 'Idle Ide', 104 -> 91
- 2026-08-04T20:00:03Z - 374927 'Teenies in the Night', 104 -> 91
- 2026-08-07T15:22:07Z - 376093 'Lucky Ghost Hunt', 106 -> 91

Upward (NOOBS -> MIDDLES), all caused by prize wins:

- 2026-08-04T08:00:22Z - 374921 'Point by Point', place 1, 89 -> 144
- 2026-08-05T18:00:16Z - 376074 'Spotted or Banded?', place 1, 59 -> 106
- 2026-08-09T00:00:16Z - 376113 'Big Brother', place 2, 76 -> 126

Boundary 1000/1001 (MIDDLES <-> TOPS): no crossings. PCR never exceeded 144.

## Harvest pattern

The temporal order is present and repeats three times: PCR is walked below
100 by no-show penalties, a prize is then taken while the account sits in
NOOBS, the prize pushes PCR back above 100, and the next batch of no-shows
walks it down again.

Cycle 1 - descend, then harvest within minutes.
The 2026-08-03T17:21:40Z/:41Z flush drops PCR 104 -> 47 in one pass (four
no-shows). Scoring for 374842 starts at 2026-08-03T17:35:29Z, 14 minutes
after that flush, and 374843 'Giant Grouper Roundup!' is played the same
evening for place 3 at 2026-08-03T20:00:17Z (+45, 44 -> 89) - collected at
PCR 44, deep in NOOBS.

Cycle 2 - win, then immediately stack no-shows.
2026-08-04T08:00:22Z: 374921 'Point by Point', place 1, +55, 89 -> 144
(crosses up into MIDDLES). Between 2026-08-04T08:00:59Z and 08:01:29Z -
37 to 67 seconds after that win - six competitions are registered
(374924, 374926, 374927, 374928, 374923, 374925). Not one of them has a
"started scoring time" line. They settle as no-shows across
2026-08-04T18:44:15Z, 20:00:03Z, 22:00:05Z and 2026-08-05T15:18:58Z,
carrying PCR 144 -> 59. Registration for the next played competition
(376074) is filed at 2026-08-05T15:19:51Z - 53 seconds after the flush that
bottomed PCR at 59 - and it is played at 16:54:49Z for place 1
(+47, 59 -> 106).

Cycle 3 - same shape, slower.
2026-08-07T15:22:07Z (-15, 106 -> 91) and 2026-08-08T20:00:06Z
(-15, 91 -> 76) are both no-shows walking PCR back under 100. Scoring for
376113 'Big Brother' starts at 2026-08-08T22:54:51Z, 2h54m after the second
of those, and it takes place 2 at 2026-08-09T00:00:16Z (+50, 76 -> 126).
The window then closes with another no-show, 2026-08-09T04:00:03Z
(-20, 126 -> 106).

All four prizes were collected at NOOBS-level PCR: before-values 44, 89, 59
and 76. No prize was ever taken from MIDDLES. The only competitions played
while in MIDDLES (374633 place 30, 374835 place 26, 374837 zero score) all
lost rating.

The one qualifier: the descents are driven by no-shows for competitions the
account registered for, and the 2026-08-04T08:00:59Z-08:01:29Z burst is a
deliberate-looking bulk registration filed a minute after the win that
lifted PCR into MIDDLES. The log does not record intent, but the ordering -
win, register six, play none, drop back under 100, register and win again
within a minute of hitting bottom - is exactly the harvest shape.

## Anti-cheat context

146 CHEAT triggers across the window. Every one of the eight played sessions
carries triggers; the recurring signatures are "Fish catch distance is long",
"Friction force is too high", "Line has high extension too often",
"Stamina has grown or remain unchanged on rowing", "Fish has low
fighting/passive time ratio" and "Undriven boat moves TOO fast" (up to
546.25 against a max of 5 at 2026-08-03T19:22:21Z, in the session that took
place 3). A block of seven friction triggers at 2026-08-05T00:25:40Z -
02:03:52Z falls outside any tournament scoring session.

All sessions report the same IP and MAC: 71.197.78.171 / 70662a413170.

## SQL cross-check

SQL ground truth: PCR 106, reg 22, started 7, zero-score 1, no-shows 15
(68.2%), absence -207, play +183, net -24, prizes 4 = 4N/0M/0T,
played 4N/2M/1T, lifetime 3/1/2.

Agrees:

- PCR at end 106 - matches the last ledger line exactly.
- No-shows 15 - the ledger has exactly 15 entries with no matching
  "started scoring time".
- Absence -207 - sum of the 15 no-show deltas is exactly -207.
- Play +183 - sum of played deltas excluding the 2026-08-01 entry
  (-6, -5, -3, +45, +55, +47, +50) is exactly +183.
- Net -24 and the arithmetic close: 130 - 207 + 183 = 106.
- Prizes 4, all NOOBS - the four positive entries were taken at
  before-PCR 44, 89, 59, 76, all <= 100. Confirms 4N/0M/0T.

Window offset (not a conflict):

- The log holds 24 registration lines and 8 played sessions vs SQL's 22 and
  7. The difference is the 2026-08-01 activity (374633 registered 17:52:28Z,
  played 19:09:26Z, settled 20:00:33Z) sitting before the SQL window, plus
  374924 'Woohoo Wahoo!' - registered 2026-08-04T08:00:59Z with no reward
  line anywhere in the dump. 24 - 1 - 1 = 22 and 8 - 1 = 7.
- The SQL window therefore opens at PCR 130, not the 135 the log starts from.

Cannot be reconstructed from the ledger:

- "Played 4N/2M/1T". Classifying each played session by the PCR in force at
  its "started scoring time" gives 5N/3M log-wide, 5N/2M inside the SQL
  window - and no T at all, since PCR never passed 144. SQL's bracket label
  for played sessions must come from the competition's own division rather
  than from PCR at play time; the two do not mean the same thing here.
- "Lifetime 3/1/2" is outside this window entirely.
- "Zero-score 1" corresponds to 374837 'Falcon Trout Chase': scoring started
  at 2026-08-03T06:29:53Z but the result line carries a blank Place and -5
  rating.
