# PCR trajectory - FM_AirForceZero (PlayStation)

- **ProfileId:** `a8ec6ba8-58e5-491a-a7a1-f5914d2ff332`
- **Source:** `a8ec6ba8-58e5-491a-a7a1-f5914d2ff332-fm-airforcezero.tsv` (217 log rows)
- **Dump window requested:** 2026-08-10 -> 2026-08-30 (sweep week = 2026-08-24 -> 2026-08-30)
- **Log rows actually present:** 2026-08-17T11:32:15Z -> 2026-08-30T11:45:33Z. Nothing before 08-17T11:32:15Z, so the first of the three weeks (08-10..08-16) is not in this file at all.
- **PCR:** start 74 -> end 76 (net +2 over the observed window). Max 128 (2026-08-27T02:35:35Z), min 47 (2026-08-29T09:37:36Z).
- **Bracket:** oscillates across the NOOBS/MIDDLES line (PCR 100) ten times. Never anywhere near TOPS - the ceiling in this dump is 128, so the 1000 boundary is never approached. Roughly 71% of the observed elapsed time is spent in NOOBS.
- **Ledger integrity:** 34 reward lines, and the `(before -> after)` pair agrees with the printed delta on all 34. The chain is continuous end to end (every line's `before` equals the previous line's `after`), so no line is missing and no clamping occurred - he is never near the PCR 0 floor, the deepest point being 47.

Every value below is read from the `(before -> after)` pair, not from the printed delta.

## Ledger

Status: PLAYED = a `Player started scoring time for Competition #<id>` line exists for that competition; NO-SHOW = reward line with no such start line. Blank `Place:` on a PLAYED row = zero-score finish.

### Weeks 1-2 (2026-08-10 -> 2026-08-23) - observed 08-17 to 08-23

| Timestamp (UTC) | Comp ID | Comp name | Status | Place | delta | PCR before->after | Bracket |
|---|---|---|---|---|---|---|---|
| 2026-08-17T14:00:17Z | 376254 | 西伯利亞之可汗 | PLAYED | 3 | +30 | 74 -> 104 | MIDDLES |
| 2026-08-18T14:00:28Z | 376319 | 浮子和江鱈 | PLAYED (zero-score) | - | -7 | 104 -> 97 | NOOBS |
| 2026-08-19T10:32:05Z | 376323 | 狗魚大比拼 | NO-SHOW | - | -11 | 97 -> 86 | NOOBS |
| 2026-08-20T13:14:34Z | 376397 | 西伯利亞之可汗 | PLAYED | 4 | +25 | 86 -> 111 | MIDDLES |
| 2026-08-22T00:00:23Z | 376558 | 驚人之鯉！ | PLAYED (zero-score) | - | -8 | 111 -> 103 | MIDDLES |
| 2026-08-22T02:28:48Z | 376559 | 槍魚家族重聚！ | NO-SHOW | - | -20 | 103 -> 83 | NOOBS |
| 2026-08-23T02:00:17Z | 376647 | 肉的傢伙 | PLAYED (zero-score) | - | -10 | 83 -> 73 | NOOBS |
| 2026-08-23T04:00:07Z | 376648 | 緊握丁鱥！ | PLAYED (zero-score) | - | -7 | 73 -> 66 | NOOBS |
| 2026-08-23T07:51:19Z | 376718 | 花鰱魚垂釣比賽 | PLAYED (zero-score) | - | -7 | 66 -> 59 | NOOBS |
| 2026-08-23T21:43:42Z | 376720 | 微笑，現在是紅矛麗魚時間！ | PLAYED | 3 | +37 | 59 -> 96 | NOOBS |

### Sweep week (2026-08-24 -> 2026-08-30)

| Timestamp (UTC) | Comp ID | Comp name | Status | Place | delta | PCR before->after | Bracket |
|---|---|---|---|---|---|---|---|
| 2026-08-24T05:38:54Z | 376727 | 草魚之天淵之別 | PLAYED (zero-score) | - | -8 | 96 -> 88 | NOOBS |
| 2026-08-24T07:42:09Z | 376784 | 一短一長 | PLAYED (zero-score) | - | -10 | 88 -> 78 | NOOBS |
| 2026-08-24T22:23:59Z | 376786 | Maku-Maku 食肉動物 | PLAYED | 1 | +47 | 78 -> 125 | MIDDLES |
| 2026-08-25T02:00:22Z | 376794 | Neherrin的小魚 | NO-SHOW | - | -10 | 125 -> 115 | MIDDLES |
| 2026-08-25T04:00:09Z | 376795 | 老大哥 | PLAYED (zero-score) | - | -10 | 115 -> 105 | MIDDLES |
| 2026-08-25T06:39:35Z | 376866 | 捕獲鰻形擬長頜魚 | PLAYED (zero-score) | - | -10 | 105 -> 95 | NOOBS |
| 2026-08-25T21:53:04Z | 376868 | 硬頭鱒大戰 | NO-SHOW | - | -11 | 95 -> 84 | NOOBS |
| 2026-08-26T01:59:05Z | 376875 | 鬍鬚 獎杯 | PLAYED (zero-score) | - | -8 | 84 -> 76 | NOOBS |
| 2026-08-26T02:00:27Z | 376876 | Emerald 捕食者捕獵 | NO-SHOW | - | -10 | 76 -> 66 | NOOBS |
| 2026-08-26T09:00:01Z | 376934 | ナイルの帝王 | PLAYED | 2 | +50 | 66 -> 116 | MIDDLES |
| 2026-08-26T23:17:26Z | 376935 | ブラウン川の多様性 | PLAYED (zero-score) | - | -8 | 116 -> 108 | MIDDLES |
| 2026-08-26T23:17:26Z | 376936 | 大きなアミア・カルヴァ釣り | NO-SHOW | - | -10 | 108 -> 98 | NOOBS |
| 2026-08-27T02:35:35Z | 376943 | 完美精确度 | PLAYED | 1 | +30 | 98 -> 128 | MIDDLES |
| 2026-08-27T04:00:27Z | 376944 | 爆美洲西鲱 | PLAYED (zero-score) | - | -5 | 128 -> 123 | MIDDLES |
| 2026-08-27T06:00:08Z | 377018 | 鲤鱼起源 | NO-SHOW | - | -13 | 123 -> 110 | MIDDLES |
| 2026-08-27T08:01:06Z | 377019 | 水上胜利 | PLAYED (zero-score) | - | -10 | 110 -> 100 | NOOBS |
| 2026-08-27T10:45:56Z | 377020 | 夜捕蓝鲶鱼 | NO-SHOW | - | -11 | 100 -> 89 | NOOBS |
| 2026-08-29T03:52:09Z | 377021 | 长亚 | PLAYED (zero-score) | - | -7 | 89 -> 82 | NOOBS |
| 2026-08-29T03:52:10Z | 377022 | 耶! 沙氏刺鲅! | NO-SHOW | - | -20 | 82 -> 62 | NOOBS |
| 2026-08-29T07:26:56Z | 377250 | Tiber 河斑狂妄 | PLAYED (zero-score) | - | -5 | 62 -> 57 | NOOBS |
| 2026-08-29T09:37:36Z | 377251 | 捕获掠食性奖鱼战利品！ | PLAYED (zero-score) | - | -10 | 57 -> 47 | NOOBS |
| 2026-08-29T10:00:11Z | 377252 | 活化石 | PLAYED | 3 | +45 | 47 -> 92 | NOOBS |
| 2026-08-30T11:44:44Z | 377254 | San Joaquin无国界 | NO-SHOW | - | -11 | 92 -> 81 | NOOBS |
| 2026-08-30T11:44:44Z | 377253 | 满目皆鱼 | PLAYED (zero-score) | - | -5 | 81 -> 76 | NOOBS |

**Sweep-week boundary note.** The first sweep-week row, #376727, was *entered* on 08-23 (scoring started 2026-08-23T22:03:26Z) and only settled at 2026-08-24T05:38:54Z. The SQL ground truth attributes competitions by entry, not by settlement, so it excludes that row. With #376727 excluded the ledger reproduces the SQL charge exactly: 15 starts, 11 zero-score finishes, 8 no-shows, absence -96, play +84, net -12, ending PCR 76.

## Batched flushes

Three groups of reward lines settle as one server-side batch (two share a byte-identical timestamp, the third shares its `About to process` second and the reward lines land 1 s apart):

- `2026-08-26T23:17:26Z` - #376935 (played, zero-score) + #376936 (no-show), 116 -> 98. This is the batch that pushes him under the 100 line.
- `2026-08-29T03:52:09Z` / `03:52:10Z` - #377021 (played, zero-score) + #377022 (no-show), 89 -> 62. Both `About to process` markers are stamped `03:52:09Z`. Entered 2026-08-27T11:17, settled ~40 h later.
- `2026-08-30T11:44:44Z` - #377254 (no-show) + #377253 (played, zero-score), 92 -> 76. Entered 2026-08-29T10:01/10:03, settled ~26 h later. These are the last two ledger lines in the dump.

The two long stalls matter for reading the sweep week: the shape of 08-29 and 08-30 is partly a function of when the server flushed, not of when he played.

## Drain route

Observed window totals: gains +264 (7 results), losses -262 (27 results), net +2.

| Route | Events | Rating lost | Share of loss | Per-event |
|---|---|---|---|---|
| Zero-score finishes (started, blank place) | 17 | -135 | 51.5% | -5 to -10, mean -7.9 |
| No-shows (registered, never started) | 10 | -127 | 48.5% | -10 to -20, mean -12.7 |
| Genuine defeats (started, ranked, negative delta) | 0 | 0 | 0% | - |

Sweep week alone (by settlement date, 24 lines): gains +172, zero-score finishes -96 over 12 events, no-shows -96 over 8 events, genuine defeats 0. By the SQL entry-date convention the zero-score column is 11 events / -88 and the totals are play +84 / absence -96 / net -12.

**Genuine defeats are absent from this dump.** Every one of the 24 played results that produced a reward line is either a prize (7, all with a numeric `Place`) or a zero-score finish (17, all with a blank `Place`). There is no row anywhere in the file where he started, was ranked, and still lost rating. So the drain is a two-way split, not a three-way one: he sheds rating either by not turning up (-127) or by turning up and catching nothing (-135), and the second route is the larger of the two.

Per event, absence is the more expensive move (mean -12.7 vs -7.9), but he does it less often, and the 17 zero-score finishes outweigh the 10 no-shows in total. This matches the SQL reading: he barely no-shows relative to how often he enters and scores nothing.

## Bracket crossings

Ten crossings of the PCR 100 line, five up and five down. No crossing of the 1000 line in either direction (max 128).

| # | Timestamp (UTC) | Comp | Cause | PCR | Direction |
|---|---|---|---|---|---|
| 1 | 2026-08-17T14:00:17Z | #376254 | PLAYED, place 3, +30 | 74 -> 104 | NOOBS -> MIDDLES |
| 2 | 2026-08-18T14:00:28Z | #376319 | PLAYED zero-score, -7 | 104 -> 97 | MIDDLES -> NOOBS |
| 3 | 2026-08-20T13:14:34Z | #376397 | PLAYED, place 4, +25 | 86 -> 111 | NOOBS -> MIDDLES |
| 4 | 2026-08-22T02:28:48Z | #376559 | NO-SHOW, -20 | 103 -> 83 | MIDDLES -> NOOBS |
| 5 | 2026-08-24T22:23:59Z | #376786 | PLAYED, place 1, +47 | 78 -> 125 | NOOBS -> MIDDLES |
| 6 | 2026-08-25T06:39:35Z | #376866 | PLAYED zero-score, -10 | 105 -> 95 | MIDDLES -> NOOBS |
| 7 | 2026-08-26T09:00:01Z | #376934 | PLAYED, place 2, +50 | 66 -> 116 | NOOBS -> MIDDLES |
| 8 | 2026-08-26T23:17:26Z | #376936 | NO-SHOW, -10 | 108 -> 98 | MIDDLES -> NOOBS |
| 9 | 2026-08-27T02:35:35Z | #376943 | PLAYED, place 1, +30 | 98 -> 128 | NOOBS -> MIDDLES |
| 10 | 2026-08-27T08:01:06Z | #377019 | PLAYED zero-score, -10 | 110 -> 100 | MIDDLES -> NOOBS |

All five upward crossings are prize results he actually played. Of the five downward crossings, **three are played zero-score finishes and only two are no-shows**. That split is the core finding of this card.

He is in MIDDLES for five stretches totalling about 89 h out of the ~310 h observed: 08-17T14:00 -> 08-18T14:00 (24 h), 08-20T13:14 -> 08-22T02:28 (37 h), 08-24T22:23 -> 08-25T06:39 (8 h), 08-26T09:00 -> 08-26T23:17 (14 h), 08-27T02:35 -> 08-27T08:01 (5 h). Everything else is NOOBS.

## Harvest order - partially present, and the middle beat is wrong

The question is whether played results push PCR up toward a boundary, no-shows then pull it back down, and prizes are collected in the lower bracket.

**What holds.** All seven prizes were taken while sitting in NOOBS, at PCR 74, 86, 59, 78, 66, 98 and 47 (mean 72.6). That is 7N/0M/0T, exactly what SQL reports, and PCR is pushed back under the 100 line five times so that the next prize is again a NOOBS prize. The oscillation about the boundary is real and repeats.

**What does not hold: the middle beat.** Absence is not what puts him back under the line. Three of the five downward crossings are competitions he entered and finished with no score:

- `2026-08-18T14:00:28Z` #376319, played, blank place, -7, 104 -> 97
- `2026-08-25T06:39:35Z` #376866, played, blank place, -10, 105 -> 95
- `2026-08-27T08:01:06Z` #377019, played, blank place, -10, 110 -> 100

Only two are no-shows:

- `2026-08-22T02:28:48Z` #376559, -20, 103 -> 83
- `2026-08-26T23:17:26Z` #376936, -10, 108 -> 98

**One clean instance of the alleged order exists.** `2026-08-26T23:17:26Z` the no-show on #376936 takes him 108 -> 98, under the line; 3 h 18 min later at `2026-08-27T02:35:35Z` he takes place 1 in #376943 for +30 from PCR 98. That is absence-drop-then-harvest, once.

**The other no-show crossing does not fit.** `2026-08-22T02:28:48Z` #376559 -20 puts him at 83, but the next prize is `2026-08-23T21:43:42Z` (+37), 43 h later and only after three further played zero-score finishes had walked him down 83 -> 73 -> 66 -> 59. The absence did not stage that harvest; play did.

**Counter-evidence on the three biggest prizes.** The PCR floor each big prize was collected from was reached by playing, not by skipping:

- +47 at `2026-08-24T22:23:59Z` from 78, reached by two played zero-score finishes (`2026-08-24T05:38:54Z` 96 -> 88, `2026-08-24T07:42:09Z` 88 -> 78).
- +50 at `2026-08-26T09:00:01Z` from 66, the last two steps down being `2026-08-26T01:59:05Z` played 84 -> 76 and `2026-08-26T02:00:27Z` no-show 76 -> 66.
- +45 at `2026-08-29T10:00:11Z` from 47, reached by two played zero-score finishes (`2026-08-29T07:26:56Z` 62 -> 57, `2026-08-29T09:37:36Z` 57 -> 47).

**The beat that actually recurs is prize -> immediate re-registration -> give it back.** Within minutes of every prize he registers one to three more competitions, and those entries are what returns the gain:

- `2026-08-24T22:23:59Z` +47 (78 -> 125), then #376794 registered `22:25:20Z`, #376866 `22:25:45Z`, #376795 `22:28:14Z`. All three settle -10 each, back to 95 by `2026-08-25T06:39:35Z`.
- `2026-08-26T09:00:01Z` +50 (66 -> 116), then #376936 registered `09:02:33Z` (-10 no-show) and #376941 `09:02:59Z` (unregistered 7 s later).
- `2026-08-27T02:35:35Z` +30 (98 -> 128), then #377019 registered `02:36:40Z`, settling -10.
- `2026-08-29T10:00:11Z` +45 (47 -> 92), then #377254 registered `10:01:45Z`, settling -11 as a no-show.

So the sawtooth is genuine and every tooth peaks with a prize taken from NOOBS, but the descent is driven mainly by entering competitions and not scoring in them. On the specific three-beat order asked about - play up, absence down, prize in the lower bracket - the answer is: present once (08-26T23:17:26 -> 08-27T02:35:35), absent as a pattern.

## SQL cross-check

| Measure | SQL | Ledger | Verdict |
|---|---|---|---|
| Sweep week: starts | 15 | 15 | exact |
| Sweep week: zero-score | 11 | 11 | exact |
| Sweep week: no-shows | 8 | 8 | exact |
| Sweep week: absence | -96 | -96 | exact |
| Sweep week: play | +84 | +84 | exact |
| Sweep week: net | -12 | -12 | exact |
| Sweep week: PCR end | 76 | 76 | exact |
| Sweep week: prizes | 4 (4N/0M/0T) | 4, all from NOOBS | exact |
| 3 weeks: no-shows | 10 | 10 | exact |
| 3 weeks: absence | -127 | -127 | exact |
| 3 weeks: zero-score | 17 | 17 | exact |
| 3 weeks: prizes | 7 (7N/0M/0T) | 7, all from NOOBS | exact |
| 3 weeks: registrations | 36 | 35 stuck (44 distinct comps, 9 backed out) | 1 short |
| 3 weeks: starts | 26 | 25 | 1 short |
| 3 weeks: play | +164 | +129 | -35 short |

Everything the sweep week charges is reproduced line for line. The three-week shortfalls are all on the *positive* side and all sit in the unlogged 08-10..08-16 stretch: one registration, one start, and about +35 of rating gain. Nothing on the loss side is missing - the absence figure matches to the point.

## Notable

1. **He is banned from competitions at the end of the dump.** `2026-08-30T11:45:33Z` - registration for #377330 failed with `TournamentRegistrationDeniedBanned`, 49 seconds after the last reward line. The trajectory does not decay to a stop; it is cut off.
2. **61 CHEAT triggers, and they cluster on the wins.** Triggers occur in exactly 7 of the 25 scoring sessions - #376254 (7), #376319 (1), #376397 (6), #376560 (13), #376786 (16), #376934 (12), #377252 (6). Five of those sessions are prize finishes worth +30, +25, +47, +50 and +45, i.e. **+197 of his +264 total gain came out of cheat-flagged sessions**. The two clean prize sessions are #376720 (+37) and #376943 (+30). Kinds: line-high-extension x32, undriven-boat-too-fast x17, catch-distance-long x6, catch-distance-VERY-long x5, low-fighting/passive-ratio x1.
3. **One competition was processed with no ledger line at all.** #376560 started `2026-08-22T02:37:01Z` and was processed `2026-08-22T21:43:55Z` with a blank `Place:`, but no `Tournament reward` line exists. PCR continuity is intact across it (83 before, 83 after), and he was at 83 - nowhere near the 0 floor - so this is a genuine zero-delta settlement, not a floor-clamp suppression. It is also the session with 13 cheat triggers.
4. **Nine registrations were backed out before they could cost anything** - #376321, #376465, #376637, #376719, #376721, #376791, #376869, #376941, #377025 - several within seconds (#376719 registered `2026-08-23T05:09:07Z`, unregistered `05:09:09Z`). #376935 was registered and unregistered three times (`2026-08-25T21:55`, `2026-08-26T02:01`, `2026-08-26T03:59`) before the fourth registration stuck at `2026-08-26T07:33:43Z` and was played to a -8 zero-score. Unregistration is the free exit; the ten no-shows are the ones he did not back out of.
5. **One machine, eleven exit IPs.** MAC `00d9d1a5e155` on all 25 sessions. IPs span three blocks: `38.77.225.{143,144,174,208,209,238,239}`, `66.160.191.{46,66,67}`, `107.151.183.76`. The address changes between sessions but the hardware never does.
6. **Competition names are logged in three different languages for the same competition.** #376934 registers under one name and settles under another; #376935 and #376943 likewise appear in Traditional Chinese, Japanese and Simplified Chinese on different lines. Name matching across log lines is unsafe - match on competition id only.
7. **Two of the seven prizes did not reach MIDDLES.** #376720 (+37, `2026-08-23T21:43:42Z`) took him 59 -> 96 and #377252 (+45, `2026-08-29T10:00:11Z`) took him 47 -> 92. He had dug himself deep enough that even a place-3 finish left him in NOOBS - which is what a genuine drain looks like, not a controlled hover just under the line.
8. **The dump is short at the front, not the back.** The last event is the ban at `2026-08-30T11:45:33Z`, so the sweep week is fully covered. The missing stretch is 08-10..08-16, which is why the three-week play figure reads +129 here against SQL's +164. Use SQL for three-week volume; this file is authoritative only for shape and only from 08-17 on.
