# PCR trajectory - SoRA6r (Steam)

- **ProfileId:** f19ab1bb-4482-459d-9d4b-b8bb753ffffe
- **Source:** `f19ab1bb-4482-459d-9d4b-b8bb753ffffe-sora6r.tsv` (333 log lines)
- **Window:** 2026-08-10 .. 2026-08-30. The first log line is 2026-08-16T04:32:27Z - the opening six days carry no lines for this profile.
- **Sweep week:** 2026-08-24 .. 2026-08-30
- **Bracket rule:** NOOBS <= 100, MIDDLES 101-1000, TOPS >= 1001

## Summary (ledger-observed)

| Metric | Value |
|---|---|
| PCR at first ledger line (before) | 99 |
| PCR at last ledger line (after) | 62 |
| PCR max | 139 (2026-08-16T06:00:07Z) |
| PCR min | 2 (2026-08-23T04:37:47Z) |
| Ledger lines | 43 |
| Started-scoring lines (played) | 19 |
| Registration lines | 47 |
| Unregistration lines | 3 |
| CHEAT triggers | 176 (84 of them inside the sweep week) |
| Batched flush groups (>=2 ledger lines on one timestamp) | 6 |

Every ledger line's printed delta equals its before->after pair, verified for all 43 lines. PCR never reached 0 in this window, so no penalty was clamped away and no ledger line is missing on that account.

## Ledger

### Weeks 1-2 (2026-08-10 .. 2026-08-23)

| Timestamp | Comp ID | Comp name | Status | Delta | PCR before->after | Bracket |
|---|---|---|---|---|---|---|
| 2026-08-16T06:00:07Z | 329878 | 梦幻欧鳊比赛 | PLAYED, place 1 (prize) | +40 | 99 -> 139 | NOOBS -> **MIDDLES** (up-cross) |
| 2026-08-16T12:00:11Z | 329881 | 雀鳝末日泥战！ | PLAYED, place blank (zero-score) | -5 | 139 -> 134 | MIDDLES |
| 2026-08-17T16:00:18Z | 329952 | 巨型 食人鱼 | PLAYED, place 25 (defeat) | -6 | 134 -> 128 | MIDDLES |
| 2026-08-17T18:00:20Z | 329953 | Maku-Maku 食肉动物 | PLAYED, place 25 (defeat) | -6 | 128 -> 122 | MIDDLES |
| 2026-08-18T04:42:19Z | 329954 | 夜捕鲟鱼 | PLAYED, place 20 (defeat) | -4 | 122 -> 118 | MIDDLES |
| 2026-08-18T18:04:53Z | 330029 | 活化石 | NO-SHOW | -20 | 118 -> 98 | MIDDLES -> **NOOBS** (down-cross) |
| 2026-08-19T02:21:51Z | 330030 | 击！再击！ | NO-SHOW | -13 | 98 -> 85 | NOOBS (batch 1/4) |
| 2026-08-19T02:21:51Z | 330031 | 草中惊奇 | NO-SHOW | -13 | 85 -> 72 | NOOBS (batch 2/4) |
| 2026-08-19T02:21:51Z | 330102 | 比剑更锋利！ | NO-SHOW | -20 | 72 -> 52 | NOOBS (batch 3/4) |
| 2026-08-19T02:21:51Z | 330032 | 逐个 | NO-SHOW | -20 | 52 -> 32 | NOOBS (batch 4/4) |
| 2026-08-19T08:00:10Z | 330104 | Tiber 河斑狂妄 | PLAYED, place 3 (prize) | +23 | 32 -> 55 | NOOBS |
| 2026-08-19T10:00:05Z | 330105 | 捕获鳗形拟长颌鱼 | NO-SHOW | -20 | 55 -> 35 | NOOBS |
| 2026-08-19T12:00:05Z | 330106 | 鲑鱼冲突 | NO-SHOW | -13 | 35 -> 22 | NOOBS |
| _2026-08-19T14:00:15Z_ | _330107_ | _幸运 50_ | _PLAYED, place 11 - processed, no ledger line (zero delta)_ | _-_ | _(22)_ | _NOOBS_ |
| 2026-08-19T16:00:18Z | 330108 | 雀鳝末日泥战！ | PLAYED, place 3 (prize) | +20 | 22 -> 42 | NOOBS |
| 2026-08-19T18:00:13Z | 330109 | 最长欧洲鳗鲡 | PLAYED, place 1 (prize) | +30 | 42 -> 72 | NOOBS |
| 2026-08-20T12:46:58Z | 330154 | 星罗棋布的赤稍雅罗鱼 | PLAYED, place 4 (prize) | +20 | 72 -> 92 | NOOBS |
| 2026-08-20T14:00:07Z | 330155 | 梦幻欧鳊比赛 | NO-SHOW | -13 | 92 -> 79 | NOOBS |
| 2026-08-20T16:00:12Z | 330156 | 夜捕蓝鲶鱼 | PLAYED, place 1 (prize) | +35 | 79 -> 114 | NOOBS -> **MIDDLES** (up-cross) |
| 2026-08-21T02:49:55Z | 330157 | 鲽鱼盛会！ | NO-SHOW | -20 | 114 -> 94 | MIDDLES -> **NOOBS** (down-cross, batch 1/3) |
| 2026-08-21T02:49:55Z | 330159 | Maku-Maku 食肉动物 | NO-SHOW | -15 | 94 -> 79 | NOOBS (batch 2/3) |
| 2026-08-21T02:49:55Z | 330158 | Kaniq水面系牛仔竞技 | NO-SHOW | -13 | 79 -> 66 | NOOBS (batch 3/3) |
| 2026-08-21T06:00:05Z | 330226 | 水上胜利 | NO-SHOW | -20 | 66 -> 46 | NOOBS |
| 2026-08-21T08:00:07Z | 330227 | 浮子和江鳕 | PLAYED, place 1 (prize) | +40 | 46 -> 86 | NOOBS |
| 2026-08-21T13:20:34Z | 330228 | 鲶鱼的测试 | NO-SHOW | -11 | 86 -> 75 | NOOBS (batch 1/2) |
| 2026-08-21T13:20:34Z | 330229 | 鲈鱼速度狩猎 | NO-SHOW | -15 | 75 -> 60 | NOOBS (batch 2/2) |
| 2026-08-21T18:17:23Z | 330230 | 耶! 沙氏刺鲅! | NO-SHOW | -20 | 60 -> 40 | NOOBS (batch 1/2) |
| 2026-08-21T18:17:23Z | 330231 | 野鲮双胞胎 | NO-SHOW | -15 | 40 -> 25 | NOOBS (batch 2/2) |
| 2026-08-23T04:37:47Z | 330293 | 西伯利亚之可汗 | NO-SHOW | -13 | 25 -> 12 | NOOBS (batch 1/2) |
| 2026-08-23T04:37:47Z | 330295 | 像蝴蝶一样飞翔，像鲈鱼一样游泳 | NO-SHOW | -10 | 12 -> 2 | NOOBS (batch 2/2, window min) |

### Sweep week (2026-08-24 .. 2026-08-30)

| Timestamp | Comp ID | Comp name | Status | Delta | PCR before->after | Bracket |
|---|---|---|---|---|---|---|
| 2026-08-25T16:00:20Z | 330504 | 雀鳝末日泥战！ | PLAYED, place 8 (no prize) | +7 | 2 -> 9 | NOOBS |
| 2026-08-26T08:00:08Z | 330570 | 最长欧洲鳗鲡 | PLAYED, place 1 (prize) | +30 | 9 -> 39 | NOOBS |
| 2026-08-26T18:00:11Z | 330575 | 夜间少年 | PLAYED, place 1 (prize) | +40 | 39 -> 79 | NOOBS |
| 2026-08-27T04:30:34Z | 330578 | 与鲟鱼的对决！ | NO-SHOW | -20 | 79 -> 59 | NOOBS |
| 2026-08-27T16:10:36Z | 330655 | 月光雀鳝 | PLAYED, place 2 (prize) | +30 | 59 -> 89 | NOOBS |
| 2026-08-28T02:55:35Z | 330659 | 夜捕鲟鱼 | NO-SHOW | -11 | 89 -> 78 | NOOBS |
| 2026-08-28T12:05:42Z | 330721 | 微笑，现在是红矛丽鱼时间！ | PLAYED, place blank (zero-score) | -8 | 78 -> 70 | NOOBS |
| 2026-08-28T14:00:12Z | 330722 | 像蝴蝶一样飞翔，像鲈鱼一样游泳 | PLAYED, place 1 (prize) | +30 | 70 -> 100 | NOOBS (stops exactly on the 100 ceiling) |
| 2026-08-28T20:08:42Z | 330725 | 鲈鱼速度狩猎 | NO-SHOW | -15 | 100 -> 85 | NOOBS |
| 2026-08-29T05:22:39Z | 330727 | 与狗鱼共舞 | NO-SHOW | -11 | 85 -> 74 | NOOBS |
| 2026-08-29T08:00:08Z | 330791 | 星罗棋布的赤稍雅罗鱼 | PLAYED, place 1 (prize) | +30 | 74 -> 104 | NOOBS -> **MIDDLES** (up-cross) |
| 2026-08-29T16:00:10Z | 330795 | 大小问题！ | NO-SHOW | -11 | 104 -> 93 | MIDDLES -> **NOOBS** (down-cross) |
| 2026-08-30T04:46:30Z | 330798 | 尼罗河霸主 | NO-SHOW | -20 | 93 -> 73 | NOOBS (batch 1/2) |
| 2026-08-30T04:46:30Z | 330799 | 大红色的鱼 | NO-SHOW | -11 | 73 -> 62 | NOOBS (batch 2/2) |

Open at the end of the dump: registrations for #330886 (夜间少年) and #330887 (午夜鲑鱼争夺赛), both at 2026-08-30T04:47, never started, results not yet processed inside the log window.

## Bracket crossings

| # | Timestamp | Direction | Cause | PCR |
|---|---|---|---|---|
| 1 | 2026-08-16T06:00:07Z | up over 100 | PLAYED #329878, place 1, +40 | 99 -> 139 |
| 2 | 2026-08-18T18:04:53Z | down under 101 | NO-SHOW #330029, -20 | 118 -> 98 |
| 3 | 2026-08-20T16:00:12Z | up over 100 | PLAYED #330156, place 1, +35 | 79 -> 114 |
| 4 | 2026-08-21T02:49:55Z | down under 101 | NO-SHOW #330157, -20 (head of a 3-line batch) | 114 -> 94 |
| 5 | 2026-08-29T08:00:08Z | up over 100 | PLAYED #330791, place 1, +30 | 74 -> 104 |
| 6 | 2026-08-29T16:00:10Z | down under 101 | NO-SHOW #330795, -11 | 104 -> 93 |

No 1000-boundary crossings - the profile never came near TOPS. Every up-crossing is a played first place; every down-crossing is a no-show penalty; the window holds no counter-example.

Near miss: 2026-08-28T14:00:12Z, PLAYED #330722 place 1, +30, lands on exactly 100 - the NOOBS ceiling - without crossing.

## Time spent above the boundary

| MIDDLES window | Duration | Comps started while in MIDDLES | Result |
|---|---|---|---|
| 2026-08-16T06:00:07Z -> 2026-08-18T18:04:53Z | ~2d 12h | 4 (#329881, #329952, #329953, #329954) | places blank / 25 / 25 / 20 - zero prizes, -21 net |
| 2026-08-20T16:00:12Z -> 2026-08-21T02:49:55Z | 10h 50m | 0 | - |
| 2026-08-29T08:00:08Z -> 2026-08-29T16:00:10Z | 8h 00m | 0 | - |

All 13 rewarded plays (the 12 SQL-counted prizes plus the place-8 +7) were entered at a PCR inside NOOBS. The only four MIDDLES entries are the 08-16..08-18 block, and every one of them lost rating.

## Registration timing around the up-crossings

| Up-cross | Penalty that reversed it | Registration of that penalty comp | Relative timing |
|---|---|---|---|
| 2026-08-16T06:00:07Z (139) | #330029 at 2026-08-18T18:04:53Z | 2026-08-18T15:11:57Z | registered ~2d after the crossing, once four MIDDLES plays had already bled 139 -> 118 |
| 2026-08-20T16:00:12Z (114) | #330157 at 2026-08-21T02:49:55Z | 2026-08-20T11:19:09Z | registered 4h41m **before** the crossing - a standing pool of unattended entries |
| 2026-08-29T08:00:08Z (104) | #330795 at 2026-08-29T16:00:10Z | 2026-08-29T08:44:19Z | registered 44m **after** the crossing, together with #330798 at 08:44:27Z |

## Cross-check against SQL

| Quantity | SQL | Ledger | Note |
|---|---|---|---|
| Sweep: registrations | 16 | 16 | matches |
| Sweep: started | 7 | 7 | matches |
| Sweep: zero-score | 1 | 1 (#330721) | matches |
| Sweep: no-shows | 9 (56.3%) | 7 penalty lines + 2 registrations still open | matches once #330886/#330887 process |
| Sweep: play | +159 | +159 | matches exactly |
| Sweep: absence | -125 | -99 | gap -26 |
| Sweep: net | +34 | +60 | difference is the same -26 |
| Sweep: prizes | 5 (5N/0M/0T) | 5 podium finishes (+30/+40/+30/+30/+30); the +7 place-8 line is not a prize | matches |
| 3wk: registrations | 47 | 47 | matches |
| 3wk: started | 20 | 19 | one start predates the log's first line |
| 3wk: zero-score | 2 | 2 (#329881, #330721) | matches |
| 3wk: no-shows | 27 | 25 penalty lines + 2 open | matches once #330886/#330887 process |
| 3wk: play | +376 | +346 | gap +30, consistent with the missing 20th start |
| 3wk: absence | -409 | -383 | gap -26, same as the sweep week |
| 3wk: prizes | 12 (12N/0M/0T) | 12 podium/paid finishes, every one entered in NOOBS | matches |
| 3wk: net | -33 | -37 (99 -> 62) | follows from the two gaps above |

Both absence gaps are exactly -26, and both windows share the same two unprocessed registrations (#330886, #330887 at 2026-08-30T04:47). That is the arithmetically consistent reading; the dump ends at 2026-08-30T04:47:52Z, before either result was processed, so the log cannot confirm it directly.

## Notes

- The ledger prints only non-zero changes: #330107 was played (start 2026-08-19T12:11:20Z), processed at 14:00:15Z with place 11, and produced no ledger line. 44 process markers against 43 reward lines.
- Three unregistrations: #330028 (2026-08-18T13:04:06Z), #330291 (2026-08-22T10:08:32Z), #330295 (2026-08-22T10:08:47Z, re-registered 50s later at 10:09:37Z and then no-showed).
- 176 CHEAT triggers across 19 played sessions, 84 of them in the sweep week. The 2026-08-28 session on #330722 - the place-1 win that landed on exactly 100 - carries roughly 50 triggers on its own: attack-time-short, catch-distance-long, friction-too-high.
- Client MAC is constant across the whole window (C87F5407C334); source IPs move between 66.160.191.x and 107.151.235.x.
