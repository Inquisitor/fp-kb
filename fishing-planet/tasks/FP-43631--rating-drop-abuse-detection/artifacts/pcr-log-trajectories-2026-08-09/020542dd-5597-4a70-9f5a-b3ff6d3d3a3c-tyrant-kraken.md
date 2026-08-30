---
type: trajectory-card
task: FP-43631
player: Tyrant-Kraken
profile_id: 020542dd-5597-4a70-9f5a-b3ff6d3d3a3c
platform: Steam
source: 020542dd-5597-4a70-9f5a-b3ff6d3d3a3c-tyrant-kraken.tsv
log_window: 2026-07-26T05:51:18Z .. 2026-08-09T22:35:47Z
---

# Tyrant-Kraken (Steam) - PCR trajectory

## Summary

| Metric | Value |
| --- | --- |
| PCR at first ledger line (before) | 481 |
| PCR at last ledger line (after) | 953 |
| PCR min | 481 (opening value, 2026-07-26T10:00:07Z) |
| PCR max | 1069 (2026-08-04T20:00:15Z) |
| Ledger entries | 98 |
| Played (scoring-time started) | 69 of the 98 ledger rows; 74 scoring-start events log-wide |
| No-shows | 29 log-wide / 23 inside the SQL window |
| Prizes (top-3 finish) | 17 log-wide / 4 inside the SQL window |
| Batched flush groups | 1 |
| Registration lines | 106 (plus 4 `Player unregistered from Competition #`) |
| CHEAT triggers | 1340 |
| Bracket span | MIDDLES <-> TOPS only; NOOBS never reached |

Floor-clamp caveat does not apply. Every printed delta equals the
before->after pair difference, and PCR never comes near 0 (log-wide minimum
481, in-window minimum 936). No penalty was silently swallowed, so the
ledger is complete for this account.

Two distinct machines appear. All but two sessions run from
Mac `00FFEF6846A2` on 98.96.208.x / 112.193.31.x. Competition #327925
(2026-07-26T20:21:10Z, IP 45.195.138.156) and #328091
(2026-07-28T14:34:05Z, IP 154.86.5.164) run from Mac `6CB311915126`.

## Ledger

Bracket = state after the entry. `->` in the bracket column marks a crossing.
Place is taken from the process marker for the same competition.

| Timestamp | Comp ID | Comp name | Status | Delta | PCR before->after | Bracket |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-07-26T10:00:07Z | 327919 | 击！再击！ | PLAYED (place 1) PRIZE | +40 | 481 -> 521 | MIDDLES |
| 2026-07-26T12:00:14Z | 327920 | 鲈鱼速度狩猎 | PLAYED (place 6) | +22 | 521 -> 543 | MIDDLES |
| 2026-07-26T14:00:12Z | 327921 | 微笑，现在是红矛丽鱼时间！ | PLAYED (place blank - zero score) | -8 | 543 -> 535 | MIDDLES |
| 2026-07-26T16:00:16Z | 327922 | San Joaquin无国界 | PLAYED (place 15) | -1 | 535 -> 534 | MIDDLES |
| 2026-07-26T18:00:31Z | 327923 | 午夜鲑鱼争夺赛 | PLAYED (place 41) | -5 | 534 -> 529 | MIDDLES |
| 2026-07-27T10:00:07Z | 328006 | Marron 河多样性 | PLAYED (place 3) PRIZE | +37 | 529 -> 566 | MIDDLES |
| 2026-07-27T18:00:13Z | 328010 | 夜间少年 | PLAYED (place 4) | +25 | 566 -> 591 | MIDDLES |
| 2026-07-27T20:00:17Z | 328011 | Falcon 湖鳟鱼追逐 | PLAYED (place 1) PRIZE | +30 | 591 -> 621 | MIDDLES |
| 2026-07-27T22:00:18Z | 328012 | 满目皆鱼 | PLAYED (place 1) PRIZE | +25 | 621 -> 646 | MIDDLES |
| 2026-07-28T06:39:58Z | 328013 | 长亚 | PLAYED (place 19) | -4 | 646 -> 642 | MIDDLES |
| 2026-07-28T10:00:09Z | 328088 | 血腥威胁 | PLAYED (place 7) | +18 | 642 -> 660 | MIDDLES |
| 2026-07-28T16:00:26Z | 328091 | 巨型 食人鱼 | PLAYED (place 49) | -6 | 660 -> 654 | MIDDLES |
| 2026-07-28T22:00:26Z | 328094 | San Joaquin无国界 | PLAYED (place 9) | +7 | 654 -> 661 | MIDDLES |
| 2026-07-29T02:00:20Z | 328096 | 惊人之鲤！ | PLAYED (place 5) | +27 | 661 -> 688 | MIDDLES |
| 2026-07-29T10:00:09Z | 328178 | 老大哥 | PLAYED (place 1) PRIZE | +55 | 688 -> 743 | MIDDLES |
| 2026-07-30T05:55:27Z | 328248 | 来吧，鲤鱼！ | NO-SHOW | -11 | 743 -> 732 | MIDDLES |
| 2026-07-30T05:55:27Z | 328184 | 紧握丁鱥！ | PLAYED (place 7) | +14 | 732 -> 746 | MIDDLES |
| 2026-07-30T10:09:40Z | 328250 | Neherrin的小鱼 | PLAYED (place 9) | +5 | 746 -> 751 | MIDDLES |
| 2026-07-30T14:00:14Z | 328253 | 一个接一个 | PLAYED (place 4) | +17 | 751 -> 768 | MIDDLES |
| 2026-07-30T16:00:25Z | 328254 | 月光雀鳝 | PLAYED (place 40) | -4 | 768 -> 764 | MIDDLES |
| 2026-07-30T18:00:20Z | 328255 | 浮子和江鳕 | PLAYED (place 29) | -5 | 764 -> 759 | MIDDLES |
| 2026-07-30T20:00:15Z | 328256 | Marron 河多样性 | PLAYED (place 2) PRIZE | +42 | 759 -> 801 | MIDDLES |
| 2026-07-31T04:00:13Z | 329441 | 惊人之鲤！ | PLAYED (place 16) | -2 | 801 -> 799 | MIDDLES |
| 2026-07-31T06:00:08Z | 329442 | 来吧，鲤鱼！ | PLAYED (place 1) PRIZE | +35 | 799 -> 834 | MIDDLES |
| 2026-07-31T08:00:12Z | 329443 | Maku-Maku 食肉动物 | PLAYED (place 14) | -1 | 834 -> 833 | MIDDLES |
| 2026-07-31T10:00:08Z | 329444 | 鲈鱼速度狩猎 | PLAYED (place 1) PRIZE | +47 | 833 -> 880 | MIDDLES |
| 2026-07-31T16:00:13Z | 329447 | 尼罗河霸主 | PLAYED (place 3) PRIZE | +45 | 880 -> 925 | MIDDLES |
| 2026-08-01T08:00:07Z | 329455 | 红光闪闪 | PLAYED (place 2) PRIZE | +42 | 925 -> 967 | MIDDLES |
| 2026-08-01T10:00:19Z | 329456 | 漂亮的鲇形目 | PLAYED (place 20) | -3 | 967 -> 964 | MIDDLES |
| 2026-08-01T12:00:05Z | 329457 | 与鲟鱼的对决！ | PLAYED (place blank - zero score) | -10 | 964 -> 954 | MIDDLES |
| 2026-08-01T14:00:17Z | 329458 | 点状或细纹？ | PLAYED (place 20) | -6 | 954 -> 948 | MIDDLES |
| 2026-08-01T18:00:13Z | 329460 | 夜间少年 | PLAYED (place 3) PRIZE | +30 | 948 -> 978 | MIDDLES |
| 2026-08-01T20:00:09Z | 329461 | 野鲮双胞胎 | PLAYED (place 1) PRIZE | +47 | 978 -> 1025 | MIDDLES -> TOPS |
| 2026-08-01T22:00:13Z | 329462 | 鳟鱼猎人 | NO-SHOW | -10 | 1025 -> 1015 | TOPS |
| 2026-08-02T00:00:19Z | 329463 | 夜捕蓝鲶鱼 | PLAYED (place 2) PRIZE | +30 | 1015 -> 1045 | TOPS |
| 2026-08-02T02:00:09Z | 329464 | 微笑，现在是红矛丽鱼时间！ | NO-SHOW | -15 | 1045 -> 1030 | TOPS |
| 2026-08-02T10:00:07Z | 329468 | 旗鱼拉锯大战！ | NO-SHOW | -20 | 1030 -> 1010 | TOPS |
| 2026-08-02T12:00:16Z | 329469 | Marron 河多样性 | PLAYED (place 20) | -6 | 1010 -> 1004 | TOPS |
| 2026-08-02T14:00:37Z | 329470 | 无尽鳟鱼！ | PLAYED (place 42) | -3 | 1004 -> 1001 | TOPS |
| 2026-08-02T16:00:14Z | 329471 | 鲈鱼大师 | NO-SHOW | -10 | 1001 -> 991 | TOPS -> MIDDLES |
| 2026-08-02T18:00:10Z | 329472 | 花鲢鱼垂钓比赛 | PLAYED (place blank - zero score) | -7 | 991 -> 984 | MIDDLES |
| 2026-08-03T00:00:07Z | 329475 | 挪威杰出的小家伙们！ | NO-SHOW | -20 | 984 -> 964 | MIDDLES |
| 2026-08-03T04:00:07Z | 329477 | 浮子和江鳕 | PLAYED (place blank - zero score) | -7 | 964 -> 957 | MIDDLES |
| 2026-08-03T06:00:12Z | 329478 | 别惹我，鲨鱼！ | PLAYED (place 36) | -7 | 957 -> 950 | MIDDLES |
| 2026-08-03T12:00:11Z | 329481 | 鞍带石斑鱼围捕！ | PLAYED (place 7) | +25 | 950 -> 975 | MIDDLES |
| 2026-08-03T14:00:19Z | 329482 | Kaniq水面系牛仔竞技 | PLAYED (place 22) | -5 | 975 -> 970 | MIDDLES |
| 2026-08-03T16:00:33Z | 329483 | 像蝴蝶一样飞翔，像鲈鱼一样游泳 | PLAYED (place 50) | -3 | 970 -> 967 | MIDDLES |
| 2026-08-03T18:00:12Z | 329484 | 幸运鬼鲤 | PLAYED (place 2) PRIZE | +42 | 967 -> 1009 | MIDDLES -> TOPS |
| 2026-08-03T20:00:17Z | 329485 | 血腥威胁 | PLAYED (place 7) | +18 | 1009 -> 1027 | TOPS |
| 2026-08-03T22:00:22Z | 329486 | 强大的三 | PLAYED (place 31) | -6 | 1027 -> 1021 | TOPS |
| 2026-08-04T00:00:12Z | 329487 | 一个接一个 | NO-SHOW | -10 | 1021 -> 1011 | TOPS |
| 2026-08-04T02:00:11Z | 329488 | 夜捕鲟鱼 | NO-SHOW | -11 | 1011 -> 1000 | TOPS -> MIDDLES |
| 2026-08-04T04:00:05Z | 329489 | 的河流小胖饵 | NO-SHOW | -13 | 1000 -> 987 | MIDDLES |
| 2026-08-04T06:00:04Z | 329490 | 夜间少年 | NO-SHOW | -13 | 987 -> 974 | MIDDLES |
| 2026-08-04T08:00:17Z | 329491 | 大红色的鱼 | PLAYED (place 23) | -4 | 974 -> 970 | MIDDLES |
| 2026-08-04T10:00:07Z | 329492 | 老大哥 | PLAYED (place 3) PRIZE | +45 | 970 -> 1015 | MIDDLES -> TOPS |
| 2026-08-04T14:00:25Z | 329494 | 鲑鱼冲突 | PLAYED (place 38) | -5 | 1015 -> 1010 | TOPS |
| 2026-08-04T16:00:11Z | 329495 | 尼罗河霸主 | PLAYED (place 5) | +35 | 1010 -> 1045 | TOPS |
| 2026-08-04T18:00:23Z | 329496 | 黄金鲈淘金热 | PLAYED (place 8) | +7 | 1045 -> 1052 | TOPS |
| 2026-08-04T20:00:15Z | 329497 | 紧握丁鱥！ | PLAYED (place 6) | +17 | 1052 -> 1069 | TOPS |
| 2026-08-05T00:00:17Z | 329499 | Maku-Maku 食肉动物 | PLAYED (place 16) | -2 | 1069 -> 1067 | TOPS |
| 2026-08-05T02:00:08Z | 329500 | 草鱼之天渊之别 | NO-SHOW | -15 | 1067 -> 1052 | TOPS |
| 2026-08-05T04:00:07Z | 329501 | 硬头鳟大战 | NO-SHOW | -11 | 1052 -> 1041 | TOPS |
| 2026-08-05T08:00:07Z | 329502 | 月光雀鳝 | NO-SHOW | -11 | 1041 -> 1030 | TOPS |
| 2026-08-05T10:00:09Z | 329503 | 漂亮的鲇形目 | NO-SHOW | -10 | 1030 -> 1020 | TOPS |
| 2026-08-05T12:00:16Z | 329504 | 满目皆鱼 | PLAYED (place 6) | +12 | 1020 -> 1032 | TOPS |
| 2026-08-05T14:00:08Z | 329505 | 星罗棋布的赤稍雅罗鱼 | NO-SHOW | -10 | 1032 -> 1022 | TOPS |
| 2026-08-05T16:00:20Z | 329506 | 别惹我，鲨鱼！ | PLAYED (place 22) | -7 | 1022 -> 1015 | TOPS |
| 2026-08-05T22:00:07Z | 329509 | 全鱼畅钓，全包尽享！ | NO-SHOW | -20 | 1015 -> 995 | TOPS -> MIDDLES |
| 2026-08-06T00:00:09Z | 329510 | 寻觅最大和最小白梭吻鲈 | NO-SHOW | -10 | 995 -> 985 | MIDDLES |
| 2026-08-06T02:00:09Z | 329511 | 野鲮双胞胎 | PLAYED (place 5) | +27 | 985 -> 1012 | MIDDLES -> TOPS |
| 2026-08-06T10:00:12Z | 329515 | 最好的小口黑鲈 | NO-SHOW | -10 | 1012 -> 1002 | TOPS |
| 2026-08-06T12:00:19Z | 329516 | 红光闪闪 | PLAYED (place 25) | -6 | 1002 -> 996 | TOPS -> MIDDLES |
| 2026-08-06T16:00:18Z | 329518 | 无尽鳟鱼！ | NO-SHOW | -10 | 996 -> 986 | MIDDLES |
| 2026-08-06T18:00:11Z | 329519 | 鲶鱼的测试 | NO-SHOW | -11 | 986 -> 975 | MIDDLES |
| 2026-08-06T20:00:11Z | 329520 | 三种鳟鱼！ | NO-SHOW | -11 | 975 -> 964 | MIDDLES |
| 2026-08-06T22:00:12Z | 329521 | 惊险的鲈鱼捕猎 | PLAYED (place 8) | +20 | 964 -> 984 | MIDDLES |
| 2026-08-07T00:00:08Z | 329522 | 的河流小胖饵 | PLAYED (place blank - zero score) | -7 | 984 -> 977 | MIDDLES |
| 2026-08-07T02:00:10Z | 329523 | 午夜鲑鱼争夺赛 | NO-SHOW | -13 | 977 -> 964 | MIDDLES |
| 2026-08-07T10:00:16Z | 329527 | 胡须 奖杯 | PLAYED (place 10) | +6 | 964 -> 970 | MIDDLES |
| 2026-08-07T20:00:18Z | 329532 | 惊人之鲤！ | PLAYED (place 16) | -2 | 970 -> 968 | MIDDLES |
| 2026-08-08T00:00:13Z | 329534 | 击！再击！ | PLAYED (place 6) | +17 | 968 -> 985 | MIDDLES |
| 2026-08-08T02:00:08Z | 329535 | 枪鱼家族团聚！ | NO-SHOW | -20 | 985 -> 965 | MIDDLES |
| 2026-08-08T04:00:05Z | 329536 | 点状或细纹？ | NO-SHOW | -15 | 965 -> 950 | MIDDLES |
| 2026-08-08T06:00:06Z | 329537 | Tiber 河斑狂妄 | NO-SHOW | -10 | 950 -> 940 | MIDDLES |
| 2026-08-08T08:00:12Z | 329538 | San Joaquin无国界 | PLAYED (place 25) | -4 | 940 -> 936 | MIDDLES |
| 2026-08-08T10:00:08Z | 329539 | 微笑，现在是红矛丽鱼时间！ | PLAYED (place 3) PRIZE | +37 | 936 -> 973 | MIDDLES |
| 2026-08-08T12:00:08Z | 329540 | 梦幻欧鳊比赛 | PLAYED (place 1) PRIZE | +40 | 973 -> 1013 | MIDDLES -> TOPS |
| 2026-08-08T14:00:25Z | 329541 | Kaniq之战 | PLAYED (place 38) | -5 | 1013 -> 1008 | TOPS |
| 2026-08-08T16:00:18Z | 329542 | 一短一长 | PLAYED (place 24) | -7 | 1008 -> 1001 | TOPS |
| 2026-08-08T18:59:56Z | 329543 | 鲈鱼大师 | NO-SHOW | -10 | 1001 -> 991 | TOPS -> MIDDLES |
| 2026-08-08T22:00:08Z | 329545 | 幸运 50 | NO-SHOW | -15 | 991 -> 976 | MIDDLES |
| 2026-08-09T02:00:07Z | 329547 | 金枪鱼大战！ | NO-SHOW | -20 | 976 -> 956 | MIDDLES |
| 2026-08-09T10:00:08Z | 329551 | 懒惰的高体雅罗鱼 | PLAYED (place 4) | +25 | 956 -> 981 | MIDDLES |
| 2026-08-09T12:00:06Z | 329552 | 从零开始 | NO-SHOW | -10 | 981 -> 971 | MIDDLES |
| 2026-08-09T14:00:16Z | 329553 | 水上胜利 | PLAYED (place 22) | -7 | 971 -> 964 | MIDDLES |
| 2026-08-09T16:00:11Z | 329554 | Neherrin的小鱼 | PLAYED (place blank - zero score) | -5 | 964 -> 959 | MIDDLES |
| 2026-08-09T18:00:21Z | 329555 | 海水巨鱼 | PLAYED (place 26) | -6 | 959 -> 953 | MIDDLES |

Batched flush groups (several competitions settled in one processing pass):

- 2026-07-30T05:55:27Z - 328248 (NO-SHOW -11), 328184 (PLAYED +14); 743 -> 746, net +3

Only one batch in 98 entries. Four further entries land off the 2-hour
settlement cadence but alone: 2026-07-28T06:39:58Z (#328013, ~8.5h late),
2026-07-30T10:09:40Z (#328250), 2026-08-08T18:59:56Z (#329543).

Played but absent from the ledger (no reward line at all, therefore delta 0
or settled outside the dump): #327925 (place 11, played 2026-07-26T20:21:10Z),
#328005 (place 12, played 2026-07-27T06:49:07Z), #329476 (place 11, played
2026-08-03T00:39:22Z), #329556 (place 11, played 2026-08-09T18:10:13Z),
#329558 (played 2026-08-09T22:06:47Z, still running at end of dump).

## Bracket crossings

Boundary 100/101 (NOOBS <-> MIDDLES): **no crossings**. The account never
drops below 481 log-wide, and never below 936 inside the SQL window. NOOBS is
never touched, which is why SQL reports 0N prizes.

Boundary 1000/1001 (MIDDLES <-> TOPS): ten crossings, five each way, all
inside the last eight days of the window.

Upward (MIDDLES -> TOPS) - every one driven by a played competition with a
large positive delta:

- 2026-08-01T20:00:09Z - 329461 '野鲮双胞胎', place 1, +47, 978 -> 1025
- 2026-08-03T18:00:12Z - 329484 '幸运鬼鲤', place 2, +42, 967 -> 1009
- 2026-08-04T10:00:07Z - 329492 '老大哥', place 3, +45, 970 -> 1015
- 2026-08-06T02:00:09Z - 329511 '野鲮双胞胎', place 5, +27, 985 -> 1012
- 2026-08-08T12:00:08Z - 329540 '梦幻欧鳊比赛', place 1, +40, 973 -> 1013

Downward (TOPS -> MIDDLES) - four of five driven by no-show penalties:

- 2026-08-02T16:00:14Z - 329471 '鲈鱼大师', NO-SHOW, -10, 1001 -> 991
- 2026-08-04T02:00:11Z - 329488 '夜捕鲟鱼', NO-SHOW, -11, 1011 -> 1000
- 2026-08-05T22:00:07Z - 329509 '全鱼畅钓，全包尽享！', NO-SHOW, -20, 1015 -> 995
- 2026-08-06T12:00:19Z - 329516 '红光闪闪', PLAYED place 25, -6, 1002 -> 996
- 2026-08-08T18:59:56Z - 329543 '鲈鱼大师', NO-SHOW, -10, 1001 -> 991

The 2026-08-06 crossing is the exception: a played competition with a weak
result finished the job that a no-show one competition earlier (#329515,
-10, 1012 -> 1002) had started.

## Harvest pattern

**The play-up / absence-down oscillation is present and repeats five times.
The "prizes then taken in the lower bracket" leg is present but does not
hold for all four in-window prizes, and the registration timestamps argue
against it being deliberate.**

### The order that is present

From 2026-08-01T20:00:09Z onward PCR is pinned in a 936-1069 band and crosses
the 1000 line ten times in eight days. Every upward crossing is a played
competition (+27 to +47); four of five downward crossings are no-show
penalties (-10 to -20). No-show penalties are always in [-20, -10]; played
losses are never worse than -10. So absence is structurally the heavier
downward force, and play is the only upward force.

Two cycles show the full shape with prizes at the bottom:

**Cycle A, 2026-08-03 / 08-04.** No-show -20 at 2026-08-03T00:00:07Z drops
PCR 984 -> 964; two weak played results take it to 950 by
2026-08-03T06:00:12Z. At 2026-08-03T09:21:02Z and 09:23:08Z, with PCR at 950
(MIDDLES), #329481 and #329485 are registered; both are played (+25, +18).
At 2026-08-03T15:54:46Z, PCR 970 (MIDDLES), #329484 is registered, played at
16:50:02Z, and takes place 2 for +42 at 2026-08-03T18:00:12Z - the upward
crossing, 967 -> 1009. Then, at PCR 1027 (TOPS), a burst of five
registrations lands in 22 seconds (2026-08-03T21:01:44Z - 21:02:06Z:
#329487, #329488, #329489, #329490, #329492). Four of those five are never
played and settle as -10, -11, -13, -13 across 2026-08-04T00:00:12Z -
06:00:04Z, carrying PCR 1021 -> 974 and crossing back down at
2026-08-04T02:00:11Z. The fifth, #329492, is played at 2026-08-04T08:11:13Z
for place 3, +45, 970 -> 1015 - back into TOPS.

**Cycle B, 2026-08-07 / 08-08.** This is the cleanest instance. At
2026-08-07T22:48:24Z - 22:48:44Z, PCR 968 (MIDDLES), six competitions are
registered in 20 seconds: #329538, #329539, #329540, #329535, #329536,
#329537. The three that settle overnight are no-shows - -20 at
2026-08-08T02:00:08Z, -15 at 04:00:05Z, -10 at 06:00:06Z - taking PCR
985 -> 936, the in-window minimum. The three that settle in the morning are
all played: #329538 place 25 (-4, 936), then #329539 place 3 (+37,
936 -> 973) at 2026-08-08T10:00:08Z and #329540 place 1 (+40, 973 -> 1013)
at 12:00:08Z. Both prizes are collected at MIDDLES-level PCR (936 and 973),
and the second one crosses back up into TOPS. Two weak played results
(-5, -7) walk PCR to 1001, then no-shows -10, -15, -20 at
2026-08-08T18:59:56Z, 22:00:08Z and 2026-08-09T02:00:07Z drop it to 956.

### Where the order breaks

- **All four in-window prizes were taken while PCR sat in MIDDLES**
  (before-values 967, 970, 936, 973), so by PCR-at-collection the split is
  4M/0T, not SQL's 3M/1T. The split only reconciles when the bracket is read
  at *registration* time: #329484 registered at PCR 970 (M), #329539 and
  #329540 at PCR 968 (M), but #329492 registered 2026-08-03T21:02:06Z at
  PCR 1027 - **TOPS**. That gives exactly 0N/3M/1T. So one of the four
  prizes was entered from the *upper* bracket, which is the opposite of a
  harvest.
- **The no-shows and the prize entries come from the same registration
  burst.** In cycle B all six competitions - the three skipped and the three
  played, including both prizes - were registered within 20 seconds of each
  other at the same PCR. The absence therefore cannot have been used to
  position the account for the prize entries; the slate was fixed before any
  of it settled.
- **The skipped slots are the overnight ones.** In cycle B the no-shows are
  the 02:00 / 04:00 / 06:00 UTC settlements and the played ones are 08:00 /
  10:00 / 12:00. The same split appears in cycle A (00:00 - 06:00 skipped,
  08:00 played) and on 2026-08-05 (02:00, 04:00, 08:00 skipped). Roughly
  two thirds of all 29 no-shows settle between 22:00 and 08:00 UTC. A sleep
  schedule explains the pattern at least as well as intent does.
- **Absence is not concentrated above the boundary.** Splitting the 29
  no-shows by the PCR in force before the penalty gives 14 with PCR >= 1001
  and 15 with PCR <= 1000. If the account were ducking below 1000 to farm,
  absence would cluster just above the line and attendance below it. It does
  not.
- **The account never goes near the 100 boundary.** Nothing in this
  trajectory touches NOOBS, so there is no low-bracket farming of the kind
  the FP-43631 pattern describes - only oscillation around 1000.

### Verdict on the harvest ordering

The mechanical order - play lifts toward a boundary, absence pulls back
below it, a prize is then taken from the lower side - is observably present
on 2026-08-03/04 and 2026-08-07/08. What is missing is any evidence that the
absence was *chosen* to produce it: the registrations are filed in bulk
seconds apart regardless of PCR, one prize was entered from TOPS, and the
skipped competitions are the nocturnal ones. This trajectory reads as
shotgun over-registration plus a sleep cycle that happens to produce the
harvest shape, not as a rating-drop mechanism. The far stronger signal on
this account is the anti-cheat volume, not the PCR shape.

## Anti-cheat context

1340 CHEAT triggers over 15 days - by a wide margin the dominant feature of
this dump. Breakdown:

| Signature | Count |
| --- | --- |
| Line has high extension too often | 407 |
| Friction force is too high | 212 |
| Attack time is short / VERY short | 210 |
| Undriven boat moves TOO fast | 193 |
| Throw. Same player position and rotation N times in row | 143 |
| Fish catch distance is long / VERY long | 94 |
| Amount of reeled out line during fight is low / very low (stamina hack) | 30 |
| Avg fish velocity is too high | 22 |
| Fish has low fighting/passive time ratio | 10 |
| Boat updates time is incorrect | 8 |
| Fish is too far from tackle when finish attack | 4 |
| Distance from tackle to attacking fish is long | 3 |
| Boat moves TOO fast | 2 |
| Fish goes to player too often when it should not | 2 |

Peak observed values: undriven boat speed 15.04 against a max of 5
(2026-07-26T10:22:44Z), reeled-out line 0 against a minimum of 0.01
(2026-07-27T18:43:41Z and 2026-07-26T15:16:20Z, confidence 3/4), identical
throw position/rotation repeated 21 times in a row against a limit of 5
(2026-08-09T22:33:43Z). Triggers accompany essentially every scoring session,
including all four prize sessions.

## SQL cross-check

SQL ground truth: PCR 953, reg 58, started 35, zero-score 3, no-shows 23
(39.7%), absence -289, play +278, net -11, prizes 4 = 0N/3M/1T,
played 0N/22M/13T, lifetime 14/8/5.

The dump is wider than the SQL window. The SQL window opens immediately
after the 2026-08-03T00:00:07Z entry (#329475, 984 -> 964) and closes after
the 2026-08-09T18:00:21Z entry (#329555, 959 -> 953). Every volume figure
reconciles exactly on that window:

- **PCR 953** - the last ledger line, exactly.
- **Net -11** - 964 -> 953 across the window.
- **No-shows 23** - the 23 ledger entries from #329477 onward with no
  matching scoring-start line.
- **Absence -289** - the sum of those 23 deltas is exactly -289.
- **Play +278** - -289 + 278 = -11, and the window's played deltas sum to
  +278 by difference.
- **Started 35** - 33 played ledger rows in the window plus #329476 (played
  2026-08-03T00:39:22Z) and #329556 (played 2026-08-09T18:10:13Z), neither of
  which has a reward line. 33 + 2 = 35.
- **Reg 58** - 35 + 23 = 58.
- **Zero-score 3** - #329477, #329522 and #329554, each with a scoring-start
  line and a blank Place on the process marker. (Three more zero-score
  sessions - #327921, #329457, #329472 - sit before the window.)
- **Prizes 4 = 0N/3M/1T** - the four top-3 finishes in the window are
  #329484 (place 2), #329492 (place 3), #329539 (place 3), #329540
  (place 1). Classified by the PCR bracket in force at *registration*, that
  is 3 MIDDLES and 1 TOPS (#329492, registered at PCR 1027), exactly
  matching. Classified by PCR at collection it would be 4M/0T, so the SQL
  bracket label is a registration-time property.

Cannot be reproduced from the ledger:

- **Played 0N/22M/13T.** Three candidate rules were tested against the 35
  in-window played sessions and none lands on 22/13: PCR at registration
  gives 25M/10T, PCR at scoring start gives 23M/12T, and the log's own
  Group B / Group C label gives 24/11. The 0N is confirmed either way - PCR
  never drops to 100. The 22/13 split must come from a competition property
  not printed in this log.
- **Lifetime 14/8/5** is outside this window entirely.

Log-wide totals for reference (not comparable to SQL): 98 ledger entries,
69 played / 29 no-shows, absence -375, play +847, net +472 (481 -> 953),
106 registration lines, 17 top-3 finishes.
