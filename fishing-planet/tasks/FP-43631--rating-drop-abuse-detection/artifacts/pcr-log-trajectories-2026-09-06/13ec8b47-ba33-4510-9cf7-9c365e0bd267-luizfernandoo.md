---
player: luizfernandoo
uid: 13ec8b47-ba33-4510-9cf7-9c365e0bd267
platform: Steam
ledger_window: 2026-08-24 .. 2026-09-06
ledger_first_entry: 2026-08-31T10:00:14Z
ledger_last_entry: 2026-09-06T04:00:10Z
pcr_at_start: 0
pcr_at_end: 96
pcr_range: 25..122
net_delta: +96
ledger_entries: 18
played_events: 10
zero_score_events: 4
no_show_events: 4
rating_from_played: +193
rating_from_zero_score: -27
rating_from_no_show: -70
batched_flush_groups: 0
longest_no_show_streak:
middles_to_noobs_drops: 2 (no-show 2, zero-score 0)
max_pcr_in_window: 122
failed_registrations: 1 (CompetitionDeniedBanned x1)
cheat_triggers: 104
evidence_completeness: ok
notable:
  - 1 processed competition wrote no reward line
  - PCR crosses the 100 line down 2x (first comp #331235 at 2026-09-03T09:45:04Z, 102 -> 82) and up 2x (first comp #331085 at 2026-09-02T00:00:12Z, 92 -> 122)
  - Largest single moves: +47 comp #331084 PLAYED at 2026-09-01T22:00:12Z; -20 comp #331074 NO-SHOW at 2026-09-01T13:10:22Z
  - 1 failed registration, CompetitionDeniedBanned x1, first 2026-08-30T09:51:28Z
  - 104 CHEAT triggers, most frequent "Line has high extension too often" x45
---

# luizfernandoo -- trajectory card

The ledger records 18 reward entries between 2026-08-31T10:00:14Z and 2026-09-06T04:00:10Z. PCR starts the sequence at 0, ends at 96, and moves inside 25..122 for a net +96. Of those entries 10 follow a recorded scoring start, 4 are in the SQL zero-score set, and 4 have no start line; their deltas sum to +193, -27 and -70 respectively. No two ledger entries share the same second. Around the ledger the log holds 29 registration lines, 15 scoring starts, 1 failed registrations and 104 CHEAT triggers; 1 processed competition produced no reward line.

## PCR ledger

| Timestamp | Comp ID | Comp name | Status | Delta | PCR |
|---|---|---|---|---|---|
| 2026-08-31T10:00:14Z | 330990 | Caça aos Predadores do Emerald | PLAYED | +25 | 0 -> 25 |
| 2026-08-31T12:00:24Z | 330991 | Tench Clench! | PLAYED | +35 | 25 -> 60 |
| 2026-08-31T14:00:12Z | 330992 | Barbel Gent Hunt | PLAYED | +20 | 60 -> 80 |
| 2026-08-31T18:41:58Z | 330993 | Perigo no capim | ZERO-SCORE | -7 | 80 -> 73 |
| 2026-09-01T13:10:22Z | 331074 | Cabo-de-Guerra com Espadim! | NO-SHOW | -20 | 73 -> 53 |
| 2026-09-01T18:00:10Z | 331082 | Grass Сutter Range | ZERO-SCORE | -8 | 53 -> 45 |
| 2026-09-01T22:00:12Z | 331084 | Gigantes de água salgada | PLAYED | +47 | 45 -> 92 |
| 2026-09-02T00:00:12Z | 331085 | Caçada ao Barbo com Cavalheiros | PLAYED | +30 | 92 -> 122 |
| 2026-09-02T14:00:19Z | 331167 | Vermelho e brilhante | PLAYED | -6 | 122 -> 116 |
| 2026-09-02T16:00:26Z | 331168 | Cats 'n Nightcatchers | PLAYED | -4 | 116 -> 112 |
| 2026-09-03T09:45:03Z | 331237 | Fly like a Butterfly, Swim like a Bass | NO-SHOW | -10 | 112 -> 102 |
| 2026-09-03T09:45:04Z | 331235 | Nile Emperor | NO-SHOW | -20 | 102 -> 82 |
| 2026-09-04T00:00:08Z | 331246 | San Joaquin Extravaganza | PLAYED | +35 | 82 -> 117 |
| 2026-09-05T13:08:06Z | 331442 | Sharper than sword! | NO-SHOW | -20 | 117 -> 97 |
| 2026-09-05T18:00:26Z | 331448 | Breaking Shad | ZERO-SCORE | -5 | 97 -> 92 |
| 2026-09-05T20:00:29Z | 331449 | Gar-mageddon Mud Battle | PLAYED | -2 | 92 -> 90 |
| 2026-09-06T02:00:08Z | 331542 | Titãs Vermelhos | ZERO-SCORE | -7 | 90 -> 83 |
| 2026-09-06T04:00:10Z | 331543 | Muskies de cima | PLAYED | +13 | 83 -> 96 |

## SQL cross-check

SQL 2026-08-31..2026-09-06: reg 19, started 15, zero-score 4, no-shows 4, unproductive 8 (42.11%), rating from unproductive -97, from productive play 193, net 96, G-S-B 4-1-0, played N/M/T 13-2-0, prizes N/M/T 5-0-0, total prizes 5, max rating at start 122, current PCR 96.

Ledger 2026-08-31..2026-09-06 sub-range: reg lines 29, scoring starts 15, ledger entries 18, PLAYED 10, ZERO-SCORE 4, NO-SHOW 4, net +96 -- the NO-SHOW count matches SQL (threshold for `degraded` is 5.0 events; flag = ok).
