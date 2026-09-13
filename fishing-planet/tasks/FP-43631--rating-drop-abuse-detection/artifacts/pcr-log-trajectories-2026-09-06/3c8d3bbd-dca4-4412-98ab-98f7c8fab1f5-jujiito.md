---
player: jujiito
uid: 3c8d3bbd-dca4-4412-98ab-98f7c8fab1f5
platform: PlayStation
ledger_window: 2026-08-24 .. 2026-09-06
ledger_first_entry: 2026-09-01T15:19:58Z
ledger_last_entry: 2026-09-06T22:00:29Z
pcr_at_start: 0
pcr_at_end: 166
pcr_range: 0..166
net_delta: +156
ledger_entries: 17
played_events: 13
zero_score_events: 1
no_show_events: 3
rating_from_played: +218
rating_from_zero_score: -7
rating_from_no_show: -55
batched_flush_groups: 2
longest_no_show_streak:
middles_to_noobs_drops: 1 (no-show 0, zero-score 1)
max_pcr_in_window: 166
failed_registrations: 0
cheat_triggers: 104
evidence_completeness: degraded
notable:
  - Zero-score comp #376873, #376876, #377332, #377611 have no ledger entry in window
  - 21 processed competitions wrote no reward line; PCR chain reads 0 there
  - PCR crosses the 100 line down 1x (first comp #377806 at 2026-09-05T12:59:13Z, 101 -> 94) and up 2x (first comp #377805 at 2026-09-04T18:00:16Z, 81 -> 116)
  - Largest single moves: +40 comp #377704 PLAYED at 2026-09-03T18:00:12Z; -20 comp #377422 NO-SHOW at 2026-09-01T15:19:59Z
  - 104 CHEAT triggers, most frequent "Fish catch distance is VERY long" x22
  - 2026-09-01T15:19:59Z comp #377424 printed -20 but PCR moved 10 -> 0 (floor 0)
---

# jujiito -- trajectory card

The ledger records 17 reward entries between 2026-09-01T15:19:58Z and 2026-09-06T22:00:29Z. PCR starts the sequence at 0, ends at 166, and moves inside 0..166 for a net +156. Of those entries 13 follow a recorded scoring start, 1 is in the SQL zero-score set, and 3 have no start line; their deltas sum to +218, -7 and -55 respectively. 2 same-second flush groups contain at least one NO-SHOW entry. Around the ledger the log holds 39 registration lines, 22 scoring starts, 0 failed registrations and 104 CHEAT triggers; 21 processed competitions produced no reward line.

## PCR ledger

| Timestamp | Comp ID | Comp name | Status | Delta | PCR |
|---|---|---|---|---|---|
| 2026-09-01T15:19:58Z | 377420 | El Tamaño Importa | PLAYED | +30 | 0 -> 30 |
| 2026-09-01T15:19:59Z | 377422 | ¡Redada en los meros gigantes! | NO-SHOW | -20 | 30 -> 10 |
| 2026-09-01T15:19:59Z | 377424 | Uno pequeño y otro largo | NO-SHOW | -20 | 10 -> 0 |
| 2026-09-03T17:13:03Z | 377703 | Lucky Ghost Hunt | PLAYED | +37 | 0 -> 37 |
| 2026-09-03T18:00:12Z | 377704 | El río de las cranks | PLAYED | +40 | 37 -> 77 |
| 2026-09-04T13:15:26Z | 377705 | Competición del Anciano Buck | PLAYED | -3 | 77 -> 74 |
| 2026-09-04T16:47:45Z | 377804 | La Batalla de las Cabezas de Acero | PLAYED | +7 | 74 -> 81 |
| 2026-09-04T18:00:16Z | 377805 | Cachuelo perezoso | PLAYED | +35 | 81 -> 116 |
| 2026-09-05T12:59:13Z | 377807 | ¿Con manchas o con bandas? | NO-SHOW | -15 | 116 -> 101 |
| 2026-09-05T12:59:13Z | 377806 | Flotador y Lota | ZERO-SCORE | -7 | 101 -> 94 |
| 2026-09-05T16:00:26Z | 377931 | Prueba de Bagre | PLAYED | +22 | 94 -> 116 |
| 2026-09-05T18:55:23Z | 377932 | Cachuelo perezoso | PLAYED | +35 | 116 -> 151 |
| 2026-09-06T11:28:55Z | 377933 | ¡Vamos, Carpas! | PLAYED | -4 | 151 -> 147 |
| 2026-09-06T14:13:59Z | 378024 | ¡Banzai de atunes! | PLAYED | -5 | 147 -> 142 |
| 2026-09-06T18:00:35Z | 378026 | Lucioperca Zeek diferencias | PLAYED | -1 | 142 -> 141 |
| 2026-09-06T20:00:25Z | 378027 | Catán Lunar | PLAYED | +19 | 141 -> 160 |
| 2026-09-06T22:00:29Z | 378028 | Uno de nosotros, dos de Aspio | PLAYED | +6 | 160 -> 166 |

## SQL cross-check

SQL 2026-08-31..2026-09-06: reg 28, started 18, zero-score 2, no-shows 10, unproductive 12 (42.86%), rating from unproductive -165, from productive play 209, net 44, G-S-B 1-3-1, played N/M/T 12-6-0, prizes N/M/T 4-1-0, total prizes 5, max rating at start 151, current PCR 160.

Ledger 2026-08-31..2026-09-06 sub-range: reg lines 29, scoring starts 19, ledger entries 17, PLAYED 13, ZERO-SCORE 1, NO-SHOW 3, net +156 -- the NO-SHOW count is 7 below SQL (threshold for `degraded` is 5.0 events; flag = degraded).
