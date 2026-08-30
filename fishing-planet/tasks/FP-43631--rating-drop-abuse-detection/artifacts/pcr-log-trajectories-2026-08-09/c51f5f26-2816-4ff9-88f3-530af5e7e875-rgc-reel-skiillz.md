---
type: trajectory-card
task: FP-43631
player: RGC_ReeL_SKiiLLz
profile_id: c51f5f26-2816-4ff9-88f3-530af5e7e875
platform: PlayStation
source: c51f5f26-2816-4ff9-88f3-530af5e7e875-rgc-reel-skiillz.tsv
log_window: 2026-07-26T04:35:05Z .. 2026-08-08T09:00:17Z
---

# RGC_ReeL_SKiiLLz (PlayStation) - PCR trajectory

## Summary

| Metric | Value |
| --- | --- |
| PCR at first ledger line (before) | 98 |
| PCR at last ledger line (after) | 139 |
| PCR min | 56 (2026-08-07T00:00:09Z) |
| PCR max | 172 (2026-08-07T08:00:10Z) |
| Ledger entries | 66 |
| Played (scoring-time started) | 32 log-wide / 17 inside SQL window |
| No-shows | 34 log-wide / 27 inside SQL window |
| Prizes (top-3 place) | 14 log-wide / 9 inside SQL window |
| Positive-delta entries | 20 log-wide / 12 inside SQL window |
| Zero-score (played, blank place) | 4 log-wide / 3 inside SQL window |
| Batched flush groups | 9 |
| Registration lines | 74 log-wide / 44 inside SQL window |
| Unregistrations | 1 (374927, 2026-08-04T15:15:20Z) |
| FAILED registrations | 0 |
| CHEAT triggers | 117 |
| Bracket span | NOOBS <-> MIDDLES only; TOPS never reached |

Floor-clamp caveat does not apply here: every printed delta equals the
before->after pair difference across all 66 entries, and PCR never approaches
0 (min 56). No penalty was silently swallowed inside this window, so the
ledger is complete for the period it covers.

Note on the "prizes" definition: for this account the SQL prize count is
reproduced exactly by counting top-3 places (9 in window), not by counting
positive-delta entries (12 in window). Positive delta and prize are not
interchangeable here - place 4 to place 10 finishes also pay positive
(+20, +20, +12, +8, +2).

## Ledger

Bracket = state after the entry. `->` in the bracket column marks a crossing.

| Timestamp | Comp ID | Comp name | Status | Delta | PCR before->after | Bracket |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-07-26T06:00:15Z | 374028 | Siberian Khan | PLAYED (place 3) PRIZE | +30 | 98 -> 128 | NOOBS -> MIDDLES |
| 2026-07-26T08:00:09Z | 374029 | Big Headhunters | PLAYED (place 1) PRIZE | +40 | 128 -> 168 | MIDDLES |
| 2026-07-26T10:00:24Z | 374030 | Falcon Trout Chase | PLAYED (place 17) | -2 | 168 -> 166 | MIDDLES |
| 2026-07-27T00:00:44Z | 374037 | Catfish Trial | PLAYED (place 25) | -4 | 166 -> 162 | MIDDLES |
| 2026-07-27T02:01:13Z | 374038 | Bass Challenge | PLAYED (place 28) | -3 | 162 -> 159 | MIDDLES |
| 2026-07-27T04:17:50Z | 374109 | Big Bowfin Hunting | NO-SHOW | -10 | 159 -> 149 | MIDDLES |
| 2026-07-27T06:00:13Z | 374110 | Long Asia | PLAYED (place 8) | +12 | 149 -> 161 | MIDDLES |
| 2026-07-27T21:28:26Z | 374113 | Living Fossil | NO-SHOW | -20 | 161 -> 141 | MIDDLES |
| 2026-07-27T21:28:27Z | 374114 | Giant Grouper Roundup! | NO-SHOW | -20 | 141 -> 121 | MIDDLES |
| 2026-07-28T03:17:05Z | 374119 | Old Buck's Competition | NO-SHOW | -10 | 121 -> 111 | MIDDLES |
| 2026-07-28T06:00:16Z | 374202 | Dancing with Pike | PLAYED (place 4) | +22 | 111 -> 133 | MIDDLES |
| 2026-07-28T20:45:50Z | 374203 | Strike! And another strike! | PLAYED (place blank - zero score) | -7 | 133 -> 126 | MIDDLES |
| 2026-07-29T16:14:44Z | 374211 | One of us,Two of Asp | NO-SHOW | -10 | 126 -> 116 | MIDDLES |
| 2026-07-30T04:00:18Z | 374411 | Emerald Predator Hunt | PLAYED (place 14) | -1 | 116 -> 115 | MIDDLES |
| 2026-07-30T06:00:20Z | 374412 | Length Matters | PLAYED (place 14) | -1 | 115 -> 114 | MIDDLES |
| 2026-07-31T03:44:38Z | 374422 | Lucky Ghost Hunt | NO-SHOW | -15 | 114 -> 99 | MIDDLES -> NOOBS |
| 2026-07-31T03:44:38Z | 374421 | Big Headhunters | NO-SHOW | -13 | 99 -> 86 | NOOBS |
| 2026-08-01T16:45:21Z | 374523 | Marble Frenzy on the Tiber | PLAYED (place 3) PRIZE | +23 | 86 -> 109 | NOOBS -> MIDDLES |
| 2026-08-01T16:45:21Z | 374524 | Yellow Perch Goldrush | PLAYED (place 1) PRIZE | +25 | 109 -> 134 | MIDDLES |
| 2026-08-01T16:45:21Z | 374525 | The Size Matters | NO-SHOW | -11 | 134 -> 123 | MIDDLES |
| 2026-08-01T22:14:01Z | 374633 | Kaniq Topwater Rodeo | PLAYED (place 44) | -5 | 123 -> 118 | MIDDLES |
| 2026-08-01T22:14:01Z | 374634 | Jolly Carp | NO-SHOW | -15 | 118 -> 103 | MIDDLES |
| 2026-08-02T02:00:08Z | 374636 | Sharper than sword! | NO-SHOW | -20 | 103 -> 83 | MIDDLES -> NOOBS |
| 2026-08-02T06:00:07Z | 374732 | Labeo Twins | PLAYED (place 2) PRIZE | +42 | 83 -> 125 | NOOBS -> MIDDLES |
| 2026-08-02T17:52:05Z | 374733 | Spin The Trout | PLAYED (place 4) | +20 | 125 -> 145 | MIDDLES |
| 2026-08-02T17:52:05Z | 374734 | Danger in the grass | NO-SHOW | -13 | 145 -> 132 | MIDDLES |
| 2026-08-02T17:52:06Z | 374735 | C'mon, Carp! | NO-SHOW | -11 | 132 -> 121 | MIDDLES |
| 2026-08-02T20:00:51Z | 374739 | Siberian Khan | PLAYED (place 27) | -5 | 121 -> 116 | MIDDLES |
| 2026-08-03T00:31:28Z | 374741 | Bloody Threat | NO-SHOW | -15 | 116 -> 101 | MIDDLES |
| 2026-08-03T02:02:14Z | 374742 | Midnight Salmon Galore | NO-SHOW | -13 | 101 -> 88 | MIDDLES -> NOOBS |
| 2026-08-03T06:00:11Z | 374836 | Lucky Ghost Hunt | PLAYED (place 1) PRIZE | +47 | 88 -> 135 | NOOBS -> MIDDLES |
| 2026-08-03T08:00:13Z | 374837 | Falcon Trout Chase | PLAYED (place 1) PRIZE | +30 | 135 -> 165 | MIDDLES |
| 2026-08-03T17:07:22Z | 374838 | Idle Ide | NO-SHOW | -13 | 165 -> 152 | MIDDLES |
| 2026-08-03T17:07:22Z | 374840 | No Ruler - No Party | NO-SHOW | -20 | 152 -> 132 | MIDDLES |
| 2026-08-03T17:07:22Z | 374839 | Big Headhunters | NO-SHOW | -13 | 132 -> 119 | MIDDLES |
| 2026-08-03T20:00:09Z | 374843 | Giant Grouper Roundup! | NO-SHOW | -20 | 119 -> 99 | MIDDLES -> NOOBS |
| 2026-08-04T00:00:13Z | 374845 | Zander Zeek Differences | PLAYED (place blank - zero score) | -5 | 99 -> 94 | NOOBS |
| 2026-08-04T04:00:14Z | 374919 | Siberian Khan | PLAYED (place 9) | +8 | 94 -> 102 | NOOBS -> MIDDLES |
| 2026-08-04T06:00:07Z | 374920 | Grass Сutter Range | PLAYED (place blank - zero score) | -8 | 102 -> 94 | MIDDLES -> NOOBS |
| 2026-08-04T11:24:53Z | 374922 | Five-Star Pikes! | NO-SHOW | -13 | 94 -> 81 | NOOBS |
| 2026-08-04T12:00:46Z | 374923 | Breaking Shad | PLAYED (place 2) PRIZE | +22 | 81 -> 103 | NOOBS -> MIDDLES |
| 2026-08-04T16:00:07Z | 374925 | Barbel Gent Hunt | NO-SHOW | -10 | 103 -> 93 | MIDDLES -> NOOBS |
| 2026-08-04T18:00:07Z | 374926 | Tigers Trail | NO-SHOW | -20 | 93 -> 73 | NOOBS |
| 2026-08-04T22:00:25Z | 374928 | Cats 'n Nightcatchers | PLAYED (place 1) PRIZE | +35 | 73 -> 108 | NOOBS -> MIDDLES |
| 2026-08-05T00:00:37Z | 374929 | Midnight Salmon Galore | PLAYED (place 18) | -3 | 108 -> 105 | MIDDLES |
| 2026-08-05T04:00:08Z | 375033 | I will not bully you, Shark! | NO-SHOW | -20 | 105 -> 85 | MIDDLES -> NOOBS |
| 2026-08-05T16:00:17Z | 376073 | Moonlight Gars | PLAYED (place 1) PRIZE | +35 | 85 -> 120 | NOOBS -> MIDDLES |
| 2026-08-05T23:13:19Z | 376076 | Emerald Predator Hunt | NO-SHOW | -10 | 120 -> 110 | MIDDLES |
| 2026-08-06T01:57:16Z | 376077 | One Short and One Long | NO-SHOW | -20 | 110 -> 90 | MIDDLES -> NOOBS |
| 2026-08-06T04:00:05Z | 376079 | Length Matters | PLAYED (place blank - zero score) | -5 | 90 -> 85 | NOOBS |
| 2026-08-06T17:53:17Z | 376085 | Spin The Trout | PLAYED (place 4) | +20 | 85 -> 105 | NOOBS -> MIDDLES |
| 2026-08-06T18:00:05Z | 376086 | Norway Outstanding Minnies! | NO-SHOW | -20 | 105 -> 85 | MIDDLES -> NOOBS |
| 2026-08-06T22:40:23Z | 376088 | Big Red Fish | NO-SHOW | -11 | 85 -> 74 | NOOBS |
| 2026-08-06T22:40:23Z | 376087 | Gar-mageddon Mud Battle | PLAYED (place 10) | +2 | 74 -> 76 | NOOBS |
| 2026-08-07T00:00:09Z | 376089 | Giant Grouper Roundup! | NO-SHOW | -20 | 76 -> 56 | NOOBS |
| 2026-08-07T02:00:35Z | 376090 | Marron River Diversity | PLAYED (place 2) PRIZE | +42 | 56 -> 98 | NOOBS |
| 2026-08-07T04:00:06Z | 376091 | Don't bully me, Shark! | NO-SHOW | -20 | 98 -> 78 | NOOBS |
| 2026-08-07T06:00:11Z | 376092 | Labeo Twins | PLAYED (place 1) PRIZE | +47 | 78 -> 125 | NOOBS -> MIDDLES |
| 2026-08-07T08:00:10Z | 376093 | Lucky Ghost Hunt | PLAYED (place 1) PRIZE | +47 | 125 -> 172 | MIDDLES |
| 2026-08-07T19:47:06Z | 376095 | Mighty Three | NO-SHOW | -15 | 172 -> 157 | MIDDLES |
| 2026-08-07T19:47:06Z | 376096 | Ideal Accuracy | NO-SHOW | -10 | 157 -> 147 | MIDDLES |
| 2026-08-08T00:43:24Z | 376100 | Fly like a Butterfly, Swim like a Bass | NO-SHOW | -10 | 147 -> 137 | MIDDLES |
| 2026-08-08T00:43:25Z | 376101 | Sharper than sword! | NO-SHOW | -20 | 137 -> 117 | MIDDLES |
| 2026-08-08T02:00:10Z | 376102 | Bobber Burbot | NO-SHOW | -13 | 117 -> 104 | MIDDLES |
| 2026-08-08T04:00:04Z | 376103 | Sturgeon Showdown! | NO-SHOW | -20 | 104 -> 84 | MIDDLES -> NOOBS |
| 2026-08-08T06:00:08Z | 376104 | Tigers Trail | PLAYED (place 1) PRIZE | +55 | 84 -> 139 | NOOBS -> MIDDLES |

Batched flush groups (several competitions settled in one processing pass):

- 2026-07-27T21:28:26Z / :27Z - 374113, 374114 (161 -> 121, -40)
- 2026-07-31T03:44:38Z - 374422, 374421 (114 -> 86, -28)
- 2026-08-01T16:45:21Z - 374523, 374524, 374525 (86 -> 123, +37)
- 2026-08-01T22:14:01Z - 374633, 374634 (123 -> 103, -20)
- 2026-08-02T17:52:05Z / :06Z - 374733, 374734, 374735 (125 -> 121, -4)
- 2026-08-03T17:07:22Z - 374838, 374840, 374839 (165 -> 119, -46)
- 2026-08-06T22:40:23Z - 376088, 376087 (85 -> 76, -9)
- 2026-08-07T19:47:06Z - 376095, 376096 (172 -> 147, -25)
- 2026-08-08T00:43:24Z / :25Z - 376100, 376101 (147 -> 117, -30)

Seven of the nine groups are net-negative; the two that are not still contain
a no-show inside them (374525 at -11, 376088 at -11).

## Bracket crossings

Boundary 100/101 (NOOBS <-> MIDDLES) - 21 crossings, 11 up and 10 down, in
14 days. Net +1, consistent with opening in NOOBS (98) and closing in
MIDDLES (139).

Upward (NOOBS -> MIDDLES), every one caused by a PLAYED result:

- 2026-07-26T06:00:15Z - 374028 'Siberian Khan', place 3, 98 -> 128
- 2026-08-01T16:45:21Z - 374523 'Marble Frenzy on the Tiber', place 3, 86 -> 109
- 2026-08-02T06:00:07Z - 374732 'Labeo Twins', place 2, 83 -> 125
- 2026-08-03T06:00:11Z - 374836 'Lucky Ghost Hunt', place 1, 88 -> 135
- 2026-08-04T04:00:14Z - 374919 'Siberian Khan', place 9, 94 -> 102
- 2026-08-04T12:00:46Z - 374923 'Breaking Shad', place 2, 81 -> 103
- 2026-08-04T22:00:25Z - 374928 'Cats 'n Nightcatchers', place 1, 73 -> 108
- 2026-08-05T16:00:17Z - 376073 'Moonlight Gars', place 1, 85 -> 120
- 2026-08-06T17:53:17Z - 376085 'Spin The Trout', place 4, 85 -> 105
- 2026-08-07T06:00:11Z - 376092 'Labeo Twins', place 1, 78 -> 125
- 2026-08-08T06:00:08Z - 376104 'Tigers Trail', place 1, 84 -> 139

Nine of the eleven are top-3 prizes.

Downward (MIDDLES -> NOOBS), nine of ten caused by no-show penalties:

- 2026-07-31T03:44:38Z - 374422 'Lucky Ghost Hunt', 114 -> 99 (no-show)
- 2026-08-02T02:00:08Z - 374636 'Sharper than sword!', 103 -> 83 (no-show)
- 2026-08-03T02:02:14Z - 374742 'Midnight Salmon Galore', 101 -> 88 (no-show)
- 2026-08-03T20:00:09Z - 374843 'Giant Grouper Roundup!', 119 -> 99 (no-show)
- 2026-08-04T06:00:07Z - 374920 'Grass Сutter Range', 102 -> 94 (PLAYED, zero score)
- 2026-08-04T16:00:07Z - 374925 'Barbel Gent Hunt', 103 -> 93 (no-show)
- 2026-08-05T04:00:08Z - 375033 'I will not bully you, Shark!', 105 -> 85 (no-show)
- 2026-08-06T01:57:16Z - 376077 'One Short and One Long', 110 -> 90 (no-show)
- 2026-08-06T18:00:05Z - 376086 'Norway Outstanding Minnies!', 105 -> 85 (no-show)
- 2026-08-08T04:00:04Z - 376103 'Sturgeon Showdown!', 104 -> 84 (no-show)

Boundary 1000/1001 (MIDDLES <-> TOPS): no crossings. PCR never exceeded 172,
so TOPS is not in play for this account at all.

## Harvest pattern

The temporal order is present and it is the dominant structure of this log,
not an occasional coincidence. It repeats about ten times in 14 days. The
account never stops oscillating across the single 100/101 boundary: 21
crossings, and every entry into a competition happens from below the line
except when it was pushed above the line minutes earlier.

The order, per cycle: a no-show run drags PCR under 100 into NOOBS -> the
next competition is entered while sitting in NOOBS -> it takes a top-3 prize
-> the prize payout itself pushes PCR back over 100 into MIDDLES -> the next
no-show run drags it back down. The distinguishing detail versus a naive
"climb then dump" reading is that the upward push and the prize are the same
event. This account does not climb toward the boundary and then dump before
harvesting; it harvests from below the line, gets carried above it by the
payout, and the absences return it below the line in time for the next
harvest.

Cycle - clearest single demonstration (2026-08-07 / 08-08).
2026-08-07T08:00:10Z: 376093 'Lucky Ghost Hunt', place 1, +47, 125 -> 172,
the log's peak. Six consecutive no-show penalties follow with no played
competition anywhere between them: 2026-08-07T19:47:06Z (-15, -10),
2026-08-08T00:43:24Z/:25Z (-10, -20), 02:00:10Z (-13), 04:00:04Z (-20). PCR
walks 172 -> 84, crossing under 100 at 2026-08-08T04:00:04Z. Scoring for
376104 'Tigers Trail' starts at 2026-08-08T05:00:43Z - 60 minutes after that
crossing - and takes place 1 at 06:00:08Z for +55, 84 -> 139. Within three
minutes of that win, at 2026-08-08T08:59:52Z-09:00:17Z, six new competitions
are registered five seconds apart (376107, 376108, 376109, 376110, 376111,
376112). None has a "started scoring time" line before the dump ends.

Cycle - tightest turnaround (2026-08-07 early).
2026-08-07T04:00:06Z: 376091 'Don't bully me, Shark!' no-show, -20, 98 -> 78.
Scoring for 376092 'Labeo Twins' starts at 2026-08-07T04:14:05Z - 14 minutes
after the penalty landed - at PCR 78, and takes place 1 at 06:00:11Z for +47,
78 -> 125.

Cycle - deepest trough (2026-08-06 / 08-07).
2026-08-06T18:00:05Z (-20, 105 -> 85), 22:40:23Z (-11, 85 -> 74) and
2026-08-07T00:00:09Z (-20, 76 -> 56) walk PCR to the log minimum of 56.
Scoring for 376090 'Marron River Diversity' starts at 2026-08-07T00:58:09Z,
58 minutes after the trough, at PCR 56 - the lowest entry PCR in the log -
and takes place 2 at 02:00:35Z for +42, the joint-largest payout of the
period.

Cycle - the same shape earlier (2026-08-04 / 08-05).
2026-08-04T16:00:07Z (-10, 103 -> 93) and 18:00:07Z (-20, 93 -> 73) drop PCR
to 73. Scoring for 374928 'Cats 'n Nightcatchers' starts at 21:19:57Z at PCR
73, place 1 at 22:00:25Z, +35, 73 -> 108. Then 2026-08-05T04:00:08Z (-20,
105 -> 85) puts it back in NOOBS, and scoring for 376073 'Moonlight Gars'
starts at 15:26:00Z at PCR 85, place 1 at 16:00:17Z, +35, 85 -> 120.

Cycle - and again (2026-08-02 / 08-03).
2026-08-02T02:00:08Z (-20, 103 -> 83) -> 374732 entered at 05:23:00Z at PCR
83, place 2, +42, 83 -> 125. 2026-08-03T02:02:14Z (-13, 101 -> 88) -> 374836
entered at 05:13:57Z at PCR 88, place 1, +47, 88 -> 135.

Entry-PCR of the 14 top-3 finishes, in order: 98, 128, 86, 86, 83, 88, 135,
81, 73, 85, 56, 78, 125, 84. Eleven of fourteen were entered at PCR <= 100,
i.e. from NOOBS. The three exceptions (128, 135, 125) are not counter-
examples: each was the second leg of a back-to-back pair entered shortly
after the previous prize had just pushed PCR over the line - 374029 entered
2026-07-26T06:05:36Z, 5 minutes after 374028 settled; 374837 entered
2026-08-03T07:08:33Z, 68 minutes after 374836 settled; 376093 entered
2026-08-07T07:09:48Z, 70 minutes after 376092 settled. The account was in
MIDDLES on those three occasions only because it had just been put there.

The reward gradient is consistent with the shape: the four largest payouts in
the log (+42, +47, +47, +55) were all collected from entry PCR 56, 78, 88 and
84, while the competitions played from MIDDLES largely lost rating
(374030 place 17 -2, 374037 place 25 -4, 374038 place 28 -3, 374633 place 44
-5, 374739 place 27 -5, 374929 place 18 -3).

One behavioural qualifier the log records directly: the account knows how to
unregister. 374927 'Teenies in the Night' was registered 2026-08-04T07:30:55Z
and unregistered at 15:15:20Z - the only cancellation in 74 registration
lines. Every other unattended registration was left to settle as a no-show
penalty. The log does not record intent, but the no-shows are not an
artifact of not knowing the cancel path exists.

## Anti-cheat context

117 CHEAT triggers across the window:

- 84 x (1) Line has high extension too often
- 17 x (10) Fish catch distance is long
- 7 x (40) Fish catch distance is VERY long
- 4 x (40) Undriven boat moves TOO fast (peak 11.44 against a max of 5 at
  2026-08-08T05:20:54Z, inside the session that took place 1)
- 1 x (1) Distance from tackle to attacking fish is long while reeling
- 1 x (10) Avg fish velocity is too high
- 1 x (40) Fish goes to player too often when it should not
- 2 x (40) Last 5 fish have low fighting/passive time ratio on a LONG distance
  (2026-08-07T01:57:14Z and 01:57:44Z, ratios ~-1e-15 against a min of 0.2,
  in the session that took place 2 from PCR 56)

The heaviest trigger bursts sit inside the prize-winning sessions: 36 line
extension triggers during 374732 (place 2), 23 during 376092 (place 1), and
11 catch-distance / boat-speed triggers during 376104 (place 1).

All sessions report the same IP and MAC: 174.65.198.174 / 78c881bc23b4.

## SQL cross-check

SQL ground truth: PCR 139, reg 44, started 17, zero-score 3, no-shows 27
(61.4%), absence -406, play +365, net -41, prizes 9 = 8N/1M/0T,
played 14N/3M/0T, lifetime 9/3/2.

Agrees - the SQL window is identified with confidence as "registrations from
2026-08-03 onward, excluding the one unregistration". Five independent counts
land exactly on that slice:

- PCR 139 - matches the last ledger line (2026-08-08T06:00:08Z, 84 -> 139).
- Reg 44 - 45 registration lines from 2026-08-03 onward, minus 374927 which
  was unregistered. 45 - 1 = 44.
- Started 17 - exactly 17 "started scoring time" lines from 2026-08-03
  onward (33 log-wide).
- No-shows 27 (61.4%) - 44 - 17 = 27, and 27/44 = 61.4%.
- Zero-score 3 - 374845, 374920, 376079 are the played-with-blank-place
  entries inside the window (374203 on 2026-07-28 is the fourth, log-wide).
- Prizes 9 - exactly 9 top-3 finishes inside the window (14 log-wide).

Does not agree - the delta sums, and the reason is the dump cutoff:

- SQL absence -406 vs the ledger's -318 across the 20 settled no-shows in
  window; SQL play +365 vs the ledger's +369 across the 16 settled played
  entries.
- The dump ends at 2026-08-08T09:00:17Z; the SQL pull is dated 2026-08-09.
  Eight competitions registered inside the SQL window have no reward line
  anywhere in this log: 374924 'Woohoo Wahoo!' (registered
  2026-08-04T07:30:29Z), 376106 'Catfish Trial' (started
  2026-08-08T08:04:45Z, never settled) and the six registered
  2026-08-08T08:59:52Z-09:00:17Z (376107-376112).
- The gap is arithmetically consistent with those eight settling after the
  cutoff: SQL net -41 against the ledger window's +51 means the missing
  settlements net -92 across 8 competitions, ~-11.5 each, squarely inside
  the observed penalty range of -5 to -20. Their actual values are not in
  this log and are not asserted here.

Cannot be reconstructed from the ledger:

- "Prizes 9 = 8N/1M/0T" and "played 14N/3M/0T". Classifying by the PCR in
  force when scoring started gives 7N/2M for the nine in-window prizes and
  12N/5M for the seventeen in-window played sessions - and no T at all,
  since PCR never passed 172. As on the Bongler card, SQL's N/M/T label must
  come from the competition's own division rather than from player PCR at
  play time; the two do not mean the same thing.
- "Lifetime 9/3/2" is outside this window entirely.
