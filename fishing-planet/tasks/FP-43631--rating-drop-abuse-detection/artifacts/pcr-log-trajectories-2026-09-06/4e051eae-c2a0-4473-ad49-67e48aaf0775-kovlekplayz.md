---
player: kovlekplayz
uid: 4e051eae-c2a0-4473-ad49-67e48aaf0775
platform: XBox
ledger_window: 2026-08-24 .. 2026-09-06
ledger_first_entry: 2026-08-24T14:50:50Z
ledger_last_entry: 2026-09-06T16:24:30Z
pcr_at_start: 32
pcr_at_end: 30
pcr_range: 0..63
net_delta: -21
ledger_entries: 32
played_events: 10
zero_score_events: 0
no_show_events: 22
rating_from_played: +236
rating_from_zero_score: 0
rating_from_no_show: -257
batched_flush_groups: 9
longest_no_show_streak: 6 entries over 17h
middles_to_noobs_drops: 0 (no-show 0, zero-score 0)
max_pcr_in_window: 63
failed_registrations: 0
cheat_triggers: 39
evidence_completeness: ok
notable:
  - 5 processed competitions wrote no reward line
  - 2026-08-24T14:50:50Z: 4 ledger entries flushed in one second
  - Largest single moves: +30 comp #159143 PLAYED at 2026-08-25T20:33:26Z; -20 comp #159205 NO-SHOW at 2026-08-26T12:51:55Z
  - 6 consecutive NO-SHOW entries from 2026-08-24T14:50:50Z to 2026-08-25T07:51:43Z
  - 39 CHEAT triggers, most frequent "Avg fish velocity is too high" x30
  - 2026-08-24T14:50:50Z comp #159023 printed -15 but PCR moved 8 -> 0 (floor 0)
---

# kovlekplayz -- trajectory card

The ledger records 32 reward entries between 2026-08-24T14:50:50Z and 2026-09-06T16:24:30Z. PCR starts the sequence at 32, ends at 30, and moves inside 0..63 for a net -21. Of those entries 10 follow a recorded scoring start, 0 are in the SQL zero-score set, and 22 have no start line; their deltas sum to +236, 0 and -257 respectively. 9 same-second flush groups contain at least one NO-SHOW entry, the largest holding 4 entries. Around the ledger the log holds 35 registration lines, 10 scoring starts, 0 failed registrations and 39 CHEAT triggers; 5 processed competitions produced no reward line.

## PCR ledger

| Timestamp | Comp ID | Comp name | Status | Delta | PCR |
|---|---|---|---|---|---|
| 2026-08-24T14:50:50Z | 159022 | Hecht-Walzer | NO-SHOW | -11 | 32 -> 21 |
| 2026-08-24T14:50:50Z | 159021 | Karpfenquellen | NO-SHOW | -13 | 21 -> 8 |
| 2026-08-24T14:50:50Z | 159023 | Amur-Fänger | NO-SHOW | -15 | 8 -> 0 |
| 2026-08-24T14:50:50Z | 159020 | Die große Kahlhechtjagd | NO-SHOW | +22 | 0 -> 22 |
| 2026-08-25T07:51:43Z | 159089 | Glückliche 50 | NO-SHOW | -15 | 22 -> 7 |
| 2026-08-25T07:51:43Z | 159090 | Falcon-Forellenjagd | NO-SHOW | -10 | 7 -> 0 |
| 2026-08-25T12:24:39Z | 159142 | Einer nach dem Anderen | PLAYED | +12 | 0 -> 12 |
| 2026-08-25T20:33:26Z | 159143 | Langes Asien | PLAYED | +30 | 12 -> 42 |
| 2026-08-26T06:27:16Z | 159148 | Die große Kahlhechtjagd | PLAYED | +17 | 42 -> 59 |
| 2026-08-26T06:27:16Z | 159149 | Hol Dir alle | NO-SHOW | -10 | 59 -> 49 |
| 2026-08-26T06:27:17Z | 159150 | Muskie von Oben | NO-SHOW | -11 | 49 -> 38 |
| 2026-08-26T12:51:55Z | 159204 | Emerald Lake Raubfischjagd | PLAYED | +25 | 38 -> 63 |
| 2026-08-26T12:51:55Z | 159205 | Riesenzackenbarsch-Überfall! | NO-SHOW | -20 | 63 -> 43 |
| 2026-08-26T12:51:55Z | 159206 | Teenies bei Nacht | NO-SHOW | -13 | 43 -> 30 |
| 2026-08-26T23:15:47Z | 159211 | Wettkampf des alten Buck | NO-SHOW | -10 | 30 -> 20 |
| 2026-08-27T07:00:10Z | 159213 | Der große rote Fisch | NO-SHOW | -11 | 20 -> 9 |
| 2026-08-27T19:12:57Z | 159273 | Hecht-Walzer | PLAYED | +30 | 9 -> 39 |
| 2026-08-27T19:12:57Z | 159277 | Woohoo Wahoo! | NO-SHOW | -20 | 39 -> 19 |
| 2026-08-27T19:12:58Z | 159274 | Marmorrausch am Tiber | NO-SHOW | -10 | 19 -> 9 |
| 2026-08-27T19:12:58Z | 159275 | Große Karpfenjäger | NO-SHOW | -13 | 9 -> 0 |
| 2026-09-04T14:55:07Z | 159749 | Kleinkram am Neherrin River | PLAYED | +20 | 0 -> 20 |
| 2026-09-04T20:10:12Z | 159753 | Großer Bruder | NO-SHOW | -20 | 20 -> 0 |
| 2026-09-04T20:10:12Z | 159751 | Mit sehendem Auge, schwimmt der Barsch | PLAYED | +27 | 0 -> 27 |
| 2026-09-05T07:49:24Z | 159755 | Der große rote Fisch | NO-SHOW | -11 | 27 -> 16 |
| 2026-09-05T07:49:24Z | 159756 | Kein Lineal – keine Party | NO-SHOW | -20 | 16 -> 0 |
| 2026-09-05T07:49:24Z | 159754 | Emerald Lake Raubfischjagd | PLAYED | +25 | 0 -> 25 |
| 2026-09-05T19:39:35Z | 159811 | Hecht-Walzer | NO-SHOW | -11 | 25 -> 14 |
| 2026-09-06T06:00:07Z | 159879 | Maifisch nach Maß | PLAYED | +20 | 14 -> 34 |
| 2026-09-06T14:04:56Z | 159881 | Amur-Fänger | NO-SHOW | -15 | 34 -> 19 |
| 2026-09-06T14:04:56Z | 159883 | Hol Dir alle | NO-SHOW | -10 | 19 -> 9 |
| 2026-09-06T14:04:56Z | 159882 | Einer von uns für zwei Rapfen | NO-SHOW | -10 | 9 -> 0 |
| 2026-09-06T16:24:30Z | 159884 | Muskie von Oben | PLAYED | +30 | 0 -> 30 |

## SQL cross-check

SQL 2026-08-31..2026-09-06: reg 13, started 5, zero-score 0, no-shows 8, unproductive 8 (61.54%), rating from unproductive -108, from productive play 122, net 14, G-S-B 1-2-2, played N/M/T 5-0-0, prizes N/M/T 5-0-0, total prizes 5, max rating at start 27, current PCR 30.

Ledger 2026-08-31..2026-09-06 sub-range: reg lines 15, scoring starts 5, ledger entries 12, PLAYED 5, ZERO-SCORE 0, NO-SHOW 7, net +25 -- the NO-SHOW count is 1 below SQL (threshold for `degraded` is 5.0 events; flag = ok).
