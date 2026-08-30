---
type: trajectory-card
task: FP-43631
player: HalfSand_
profile_id: 67e551f8-a305-4bbd-9c1e-8f96ebdd24b1
platform: PlayStation
source: 67e551f8-a305-4bbd-9c1e-8f96ebdd24b1-halfsand.tsv
log_window: 2026-07-26T14:06:46Z .. 2026-08-09T16:00:33Z
---

# HalfSand_ (PlayStation) - PCR trajectory

## Summary

| Metric | Value |
| --- | --- |
| PCR at first ledger line (before) | 31 |
| PCR at last ledger line (after) | 106 |
| PCR min | 22 (2026-08-08T16:00:10Z) |
| PCR max | 124 (2026-08-04T16:00:18Z) |
| Ledger entries | 27 |
| Played (scoring-time started) | 18 log-wide / 10 inside SQL window |
| No-shows | 10 log-wide / 9 inside SQL window |
| Prizes (podium finish) | 5 log-wide / 4 inside SQL window |
| Batched flush groups | 0 |
| Registration lines | 32 (29 distinct competitions, 3 re-registrations) |
| CHEAT triggers | 41 |
| Bracket span | NOOBS <-> MIDDLES only; TOPS never reached |

Floor-clamp caveat does not apply here. Every printed delta equals the
before->after pair difference, and PCR never approaches 0 (min 22). No
penalty was silently swallowed inside this window, so the sparse-ledger
artifact does not affect this account.

One competition is played but absent from the ledger: 376105
'午夜鲑鱼争夺赛' has a scoring-time line and a processed result (place 12)
but no reward row. That is a genuine zero delta, not a clamp - see the SQL
cross-check, where play +124 only closes if 376105 contributed 0.

## Ledger

Bracket = state after the entry. `->` in the bracket column marks a crossing.
Places are annotated from the (otherwise skipped) processing markers.

| Timestamp | Comp ID | Comp name | Status | Delta | PCR before->after | Bracket |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-07-27T02:01:02Z | 374038 | 黑鲈的挑战 | PLAYED (place 2) PRIZE | +27 | 31 -> 58 | NOOBS |
| 2026-07-27T04:00:11Z | 374109 | 大弓鳍鱼狩猎 | PLAYED (place blank - zero score) | -5 | 58 -> 53 | NOOBS |
| 2026-07-27T06:00:11Z | 374110 | 长亚 | PLAYED (place 5) | +20 | 53 -> 73 | NOOBS |
| 2026-07-27T16:00:22Z | 374115 | 强大的三 | PLAYED (place 6) | +22 | 73 -> 95 | NOOBS |
| 2026-07-28T02:00:32Z | 374120 | 硬头鳟大战 | PLAYED (place 8) | +11 | 95 -> 106 | NOOBS -> MIDDLES |
| 2026-07-28T16:00:21Z | 374207 | 鲤鱼起源 | PLAYED (place 24) | -5 | 106 -> 101 | MIDDLES |
| 2026-07-29T02:00:31Z | 374212 | 硬头鳟大战 | PLAYED (place 5) | +19 | 101 -> 120 | MIDDLES |
| 2026-07-29T12:00:11Z | 374314 | 满目皆鱼 | NO-SHOW | -10 | 120 -> 110 | MIDDLES |
| 2026-07-29T14:00:23Z | 374315 | 最好的小口黑鲈 | PLAYED (place blank - zero score) | -5 | 110 -> 105 | MIDDLES |
| 2026-07-31T00:32:25Z | 374417 | 硬头鳟大战 | NO-SHOW | -11 | 105 -> 94 | MIDDLES -> NOOBS |
| 2026-08-04T16:00:18Z | 374925 | 鲃鱼大赛 | PLAYED (place 1) PRIZE | +30 | 94 -> 124 | NOOBS -> MIDDLES |
| 2026-08-06T07:52:21Z | 376073 | 月光雀鳝 | PLAYED (place 30) | -4 | 124 -> 120 | MIDDLES |
| 2026-08-07T08:00:13Z | 376093 | 幸运鬼鲤 | PLAYED (place 24) | -6 | 120 -> 114 | MIDDLES |
| 2026-08-07T10:00:12Z | 376094 | 梦幻欧鳊比赛 | NO-SHOW | -13 | 114 -> 101 | MIDDLES |
| 2026-08-07T12:00:09Z | 376095 | 强大的三 | NO-SHOW | -15 | 101 -> 86 | MIDDLES -> NOOBS |
| 2026-08-07T14:00:21Z | 376096 | 完美精确度 | PLAYED (place 8) | +10 | 86 -> 96 | NOOBS |
| 2026-08-07T16:00:33Z | 376097 | 鳟鱼猎人 | PLAYED (place 19) | -3 | 96 -> 93 | NOOBS |
| 2026-08-08T06:00:05Z | 376104 | 老虎的踪迹 | NO-SHOW | -20 | 93 -> 73 | NOOBS |
| 2026-08-08T10:00:14Z | 376106 | 鲶鱼的测试 | NO-SHOW | -11 | 73 -> 62 | NOOBS |
| 2026-08-08T12:00:10Z | 376107 | 漂亮的鲇形目 | NO-SHOW | -10 | 62 -> 52 | NOOBS |
| 2026-08-08T14:00:10Z | 376108 | 惊人之鲤！ | NO-SHOW | -15 | 52 -> 37 | NOOBS |
| 2026-08-08T16:00:10Z | 376109 | 血腥威胁 | NO-SHOW | -15 | 37 -> 22 | NOOBS |
| 2026-08-08T23:55:56Z | 376110 | 寻觅最大和最小白梭吻鲈 | PLAYED (place 2) PRIZE | +27 | 22 -> 49 | NOOBS |
| 2026-08-09T02:00:21Z | 376114 | 幸运 50 | PLAYED (place 1) PRIZE | +47 | 49 -> 96 | NOOBS |
| 2026-08-09T06:00:14Z | 376116 | 星罗棋布的赤稍雅罗鱼 | PLAYED (place 2) PRIZE | +27 | 96 -> 123 | NOOBS -> MIDDLES |
| 2026-08-09T12:00:08Z | 376119 | 西伯利亚之可汗 | NO-SHOW | -13 | 123 -> 110 | MIDDLES |
| 2026-08-09T16:00:33Z | 376121 | 大小问题！ | PLAYED (place 43) | -4 | 110 -> 106 | MIDDLES |

Not in the ledger:

- 376105 '午夜鲑鱼争夺赛' - registered 2026-08-08T02:46:49Z, scoring started
  06:58:50Z, processed 08:44:53Z with place 12, no reward row. Zero delta.
- 376122 '爆美洲西鲱' - registered 2026-08-09T08:45:52Z, never started, no
  reward row before the log ends. Settles after the window; SQL already
  counts it (see cross-check).

Batched flush groups: none. All 27 entries land at distinct timestamps, each
at its own competition's processing time. This account never had several
competitions settled in a single pass - the penalties arrive one tournament
slot at a time, which is why the 2026-08-08 cascade is spread over ten hours
rather than one second.

## Bracket crossings

Boundary 100/101 (NOOBS <-> MIDDLES) - five crossings, three up and two down.

Upward (NOOBS -> MIDDLES), all caused by played results:

- 2026-07-28T02:00:32Z - 374120 '硬头鳟大战', place 8, +11, 95 -> 106
- 2026-08-04T16:00:18Z - 374925 '鲃鱼大赛', place 1 PRIZE, +30, 94 -> 124
- 2026-08-09T06:00:14Z - 376116 '星罗棋布的赤稍雅罗鱼', place 2 PRIZE, +27, 96 -> 123

Downward (MIDDLES -> NOOBS), all caused by no-show penalties:

- 2026-07-31T00:32:25Z - 374417 '硬头鳟大战', -11, 105 -> 94
- 2026-08-07T12:00:09Z - 376095 '强大的三', -15, 101 -> 86

The asymmetry is total: no played result ever pushed PCR down across the
boundary, and no no-show ever pushed it up. Two of the three upward crossings
are podium wins.

Boundary 1000/1001 (MIDDLES <-> TOPS): no crossings. PCR never exceeded 124.

## Harvest pattern

The temporal order is present and repeats three times. Played results lift
PCR toward and over 100, no-shows walk it back under 100, and every podium
prize is taken while the account sits in NOOBS.

Cycle 1 - climb, drift down, harvest.
2026-07-27T02:01:02Z through 2026-07-28T02:00:32Z: five straight played
results carry PCR 31 -> 106, crossing up at 2026-07-28T02:00:32Z. The account
then gives the ground back: a no-show at 2026-07-29T12:00:11Z (-10) and a
second at 2026-07-31T00:32:25Z (-11) cross it back down to 94. Six days
later, at 2026-08-04T16:00:18Z, 374925 '鲃鱼大赛' is played for place 1 -
scoring started 14:24:30Z with PCR at 94 - for +30, 94 -> 124.

Cycle 2 - decay by play, drop by absence, win back.
From 2026-08-06T07:52:21Z to 2026-08-07T08:00:13Z two low-placement played
results erode 124 -> 114. Then the no-shows: 2026-08-07T10:00:12Z (-13,
114 -> 101) and 2026-08-07T12:00:09Z (-15, 101 -> 86), crossing down. Scoring
for 376096 '完美精确度' starts at 2026-08-07T12:15:45Z - 15 minutes and 36
seconds after the crossing that put PCR at 86 - and takes place 8
(+10, 86 -> 96).

Cycle 3 - the clearest instance.
Five consecutive no-shows on 2026-08-08 at 06:00:05Z, 10:00:14Z, 12:00:10Z,
14:00:10Z and 16:00:10Z drive PCR 93 -> 22, the deepest point in the window.
Six competitions had been registered in a 124-second burst at
2026-08-08T02:46:49Z - 02:48:53Z; five of them are exactly these no-shows.
Scoring for 376110 '寻觅最大和最小白梭吻鲈' starts at 2026-08-08T16:07:18Z -
7 minutes 8 seconds after the last of those penalties landed - and takes
place 2 at
23:55:56Z (+27, 22 -> 49). Two more podiums follow immediately from the
lowered position: 2026-08-09T02:00:21Z place 1 (+47, 49 -> 96) and
2026-08-09T06:00:14Z place 2 (+27, 96 -> 123), the last of which crosses back
up into MIDDLES. The window then closes the loop with a no-show at
2026-08-09T12:00:08Z (-13, 123 -> 110).

Prize positions confirm the shape. The PCR in force when scoring started for
each podium finish: 31 (374038), 94 (374925), 22 (376110), 49 (376114),
96 (376116). All five are <= 100 - every prize this account has ever won was
harvested from NOOBS. No podium was ever taken from MIDDLES. The four
competitions played while in MIDDLES (374207 place 24, 376073 place 30,
376093 place 24, 376121 place 43) all lost rating.

Qualifier: the descents are not exclusively absence-driven. 374207, 376073,
376093 and 376121 are played competitions with poor placement and small
negative deltas. But every large drop is a no-show, and both downward
boundary crossings are no-shows. The log records no intent; the ordering -
register in bulk, play none, fall under 100, then take place 1 or 2 within
hours of bottoming out - is the harvest shape.

## Registration behaviour

Three unregister/re-register pairs, all within seconds:

- 2026-08-07T12:54:10Z -> 13:03:52Z (376097 '鳟鱼猎人', 9m42s). Played,
  place 19.
- 2026-08-08T10:02:05Z -> 10:02:08Z (376108 '惊人之鲤！', 3 seconds). Filed
  four hours into the no-show cascade; still no-showed at 14:00:10Z (-15).
- 2026-08-08T23:57:26Z -> 23:57:28Z (376114 '幸运 50', 2 seconds). Filed 90
  seconds after the 376110 prize landed; played for place 1 at
  2026-08-09T02:00:21Z (+47).

The 2-3 second pairs are re-registrations, not schedule changes.

## Anti-cheat context

41 CHEAT triggers across the window, by signature: "Friction force is too
high" 25, "Undriven boat moves TOO fast" 7 (up to 22.49 against a max of 5 at
2026-07-27T15:13:58Z), "Line has high extension too often" 3, and one each of
"Boat moves TOO fast" (43.21 vs max 30 at 2026-07-27T15:13:46Z), "Line has
critical extension too often", "Fish catch distance is long", "Fish goes to
player too often when it should not", "Distance from tackle to attacking fish
is long while reeling" and "Attack time is VERY short".

The two highest-scoring sessions carry triggers: the 376114 place-1 session
(2026-08-09T00:46:03Z - 01:02:07Z) has nine, and the 376116 place-2 session
one. Two friction triggers at 2026-08-05T03:18:58Z / 03:36:15Z and one at
2026-08-06T09:22:53Z fall outside any tournament scoring session.

One MAC throughout - bc33291d7e01 - across six distinct IPs in four unrelated
ranges: 107.151.235.106 / .86 / .66 (07-26 to 08-05 and again 08-09),
223.240.185.239 (08-07), 156.250.2.51 and 156.225.180.167 (08-08),
156.236.16.136 (08-09).

## SQL cross-check

SQL ground truth: PCR 106, reg 19, started 10, zero-score 0, no-shows 9
(47.4%), absence -122, play +124, net +2, prizes 4 = 4N/0M/0T,
played 6N/3M/1T, lifetime 2/3/0.

The SQL window opens at 2026-08-04, not at the head of the log. Restricting
the ledger to entries from 2026-08-04 onward reproduces SQL exactly:

- Reg 19 - registrations on/after 2026-08-04 cover exactly 19 distinct
  competitions (374925, 376073, 376093-376097, 376104-376110, 376114, 376116,
  376119, 376121, 376122).
- Started 10 - 374925, 376073, 376093, 376096, 376097, 376105, 376110,
  376114, 376116, 376121.
- No-shows 9 (47.4%) - the remaining 9, and 9/19 = 47.37%.
- Play +124 - sum of the 10 started competitions' deltas
  (+30, -4, -6, +10, -3, 0, +27, +47, +27, -4) is exactly +124. This is what
  pins 376105 at 0: any other value breaks the sum.
- Zero-score 0 - all 10 started competitions in the window carry a numeric
  place (1, 30, 24, 8, 19, 12, 2, 1, 2, 43). The two blank-place played
  entries (374109, 374315) sit at 2026-07-27 and 2026-07-29, before the SQL
  window.
- PCR 106 - matches the last ledger line, and the arithmetic closes:
  94 + 12 (sum of all in-window logged deltas) = 106.
- Prizes 4 = 4N/0M/0T - podium finishes in the window are 374925 (place 1),
  376110 (place 2), 376114 (place 1), 376116 (place 2), played at PCR 94, 22,
  49 and 96. All <= 100. Confirms 4N/0M/0T with no residual.
- Lifetime 2/3/0 - the log holds exactly two place-1 finishes (374925,
  376114) and three place-2 finishes (374038, 376110, 376116), no place-3.
  The account's entire podium history therefore falls inside this 14-day
  dump.

One residual on the absence side:

- SQL absence -122, but only 8 of the 9 no-shows have a reward row inside the
  window. Their deltas (376094 -13, 376095 -15, 376104 -20, 376106 -11,
  376107 -10, 376108 -15, 376109 -15, 376119 -13) sum to -112. The missing
  -10 is 376122 '爆美洲西鲱', SQL's 9th no-show, which has no reward row
  before the log ends at 2026-08-09T16:00:33Z. Net +2 = 124 - 122 follows
  once it is included; the logged net is +12 because that penalty had not
  landed yet.

Cannot be reconstructed from the ledger:

- "Played 6N/3M/1T". Classifying each of the 10 started competitions by the
  PCR in force at its "started scoring time" gives 7N/3M/0T. The M count
  matches exactly; the single T does not - PCR never exceeded 124, so no
  TOPS-bracket entry is derivable from PCR at all. As with other accounts in
  this batch, SQL's bracket label for played sessions must come from
  something other than PCR at play time. Left unexplained rather than
  rationalised.

Log-wide totals, for reference, run well past the SQL window: 27 ledger
entries, 18 played, 10 no-shows, 29 distinct competitions registered,
5 podium finishes.
