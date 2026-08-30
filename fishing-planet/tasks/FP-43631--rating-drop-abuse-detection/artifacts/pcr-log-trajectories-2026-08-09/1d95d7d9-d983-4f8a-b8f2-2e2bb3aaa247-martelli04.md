---
UserId: 1d95d7d9-d983-4f8a-b8f2-2e2bb3aaa247
Username: martelli04
Platform: PlayStation
window: 2026-07-27 -> 2026-08-09
totals:
  pcr_ledger_rows: 27
  played: 11
  no_show: 16
  registrations_logged: 28
  failed_registrations: 0
  cheat_triggers: 28
pcr_range: 34..122
pcr_at_start: 107
pcr_at_end: 104
net_delta: -3
sql_crosscheck:
  sql_window_starts: 2026-08-03T08:00:13Z
  reconciled: true
  reg: 21
  started: 9
  no_shows: 12
  absence: -155
  play: +178
  net: +23
  pcr_final: 104
patterns:
  batched_flush_groups: 2
  bracket_crossings_total: 9
  noobs_to_middles_up: 4
  middles_to_noobs_down: 5
  harvest_cycle: present
notable:
  - "Harvest cycle present and repeated 3x: every rise above PCR 100 is followed within hours by a no-show run that returns PCR to NOOBS before the next competitive entry"
  - "Bracket-selective participation: of 9 registrations made while PCR was in MIDDLES, only 2 were played (both on 2026-08-03, Places 60 and 17, no prize); the other 7 were no-showed. All 9 played comps that produced a top-3 place were entered from NOOBS"
  - "Sharpest single instance: 3 comps registered at 2026-08-07T08:31:08/17/27Z while PCR 122 (MIDDLES) - all 3 no-showed; #376100 registered at 2026-08-07T18:40:17Z once PCR had fallen to 89 (NOOBS) - played, Place 1, +30"
  - "Group letter in the scoring-start line tracks the bracket: the only Group B entries (#374841, #374843) are exactly the two MIDDLES-bracket plays; all 9 NOOBS plays are Group A"
  - "Batched flush 2026-08-05T19:46:23Z: 2 rows in the same second, #376073 NO-SHOW -11 then #376072 PLAYED +20 (76 -> 85)"
  - "Batched flush 2026-08-09T12:12:15Z: 2 rows in the same second, both NO-SHOW, -30 PCR (93 -> 63)"
  - "Largest gain #374740 'Rosso e lucente' PLAYED Place 1 +47 (34 -> 81) at 2026-08-02T22:00:24Z; largest single loss -20 appears 4x, always NO-SHOW"
  - "CHEAT x28 in 4 clusters, top patterns: (40) Fish catch distance is VERY long x11; (1) Line has high extension too often x4; (40) Boat moves TOO fast x3. Clusters map to comps #374843 (x11), #376072 (x14), #376100 (x2, finished Place 1) plus 1 free-roam trigger 2026-08-04T19:03:58Z"
---

# PCR ledger

No clamping anywhere in this trajectory - every `before + delta = after` pair is exact and PCR never approaches 0 (min 34). The bracket column reports the bracket of the post-reward PCR; an arrow marks a boundary crossing.

| Timestamp | Comp ID | Comp name | Status | Delta | PCR before->after | Bracket |
|---|---:|---|---|---:|---|---|
| 2026-07-27T18:11:31Z | 374116 | Le dimensioni contano | NO-SHOW | -11 | 107 -> 96 | MIDDLES -> NOOBS |
| 2026-07-27T20:00:05Z | 374117 | Brucia il labirinto | NO-SHOW | -20 | 96 -> 76 | NOOBS |
| 2026-07-29T20:12:01Z | 374318 | Brucia il labirinto | NO-SHOW | -20 | 76 -> 56 | NOOBS |
| 2026-08-01T20:11:02Z | 374520 | Imperatore del Nilo | NO-SHOW | -20 | 56 -> 36 | NOOBS |
| 2026-08-02T20:00:32Z | 374739 | Khan Siberiano | PLAYED | -2 | 36 -> 34 | NOOBS |
| 2026-08-02T22:00:24Z | 374740 | Rosso e lucente | PLAYED | +47 | 34 -> 81 | NOOBS |
| 2026-08-03T08:00:13Z | 374837 | Caccia alla Trota su Falcon | PLAYED | +27 | 81 -> 108 | NOOBS -> MIDDLES |
| 2026-08-03T16:00:36Z | 374841 | Scontro finale di Trota Steelhead | PLAYED | -4 | 108 -> 104 | MIDDLES |
| 2026-08-03T20:00:22Z | 374843 | Raduno di cernie giganti! | PLAYED | -4 | 104 -> 100 | MIDDLES -> NOOBS |
| 2026-08-04T17:28:00Z | 374844 | Luccio al chiaro di luna | NO-SHOW | -11 | 100 -> 89 | NOOBS |
| 2026-08-05T10:47:42Z | 374929 | Salmoni di mezzanotte a bizzeffe | NO-SHOW | -13 | 89 -> 76 | NOOBS |
| 2026-08-05T19:46:23Z | 376073 | Luccio al chiaro di luna | NO-SHOW | -11 | 76 -> 65 | NOOBS |
| 2026-08-05T19:46:23Z | 376072 | Tiro alla fune con i Marlin! | PLAYED | +20 | 65 -> 85 | NOOBS |
| 2026-08-06T00:00:24Z | 376077 | Uno corto e uno lungo | PLAYED | +15 | 85 -> 100 | NOOBS |
| 2026-08-07T06:31:24Z | 376089 | Raduno di cernie giganti! | NO-SHOW | -20 | 100 -> 80 | NOOBS |
| 2026-08-07T08:00:10Z | 376093 | Caccia all’albino fortunato | PLAYED | +42 | 80 -> 122 | NOOBS -> MIDDLES |
| 2026-08-07T10:31:19Z | 376094 | Caccia all'abramide da sogno | NO-SHOW | -13 | 122 -> 109 | MIDDLES |
| 2026-08-07T16:00:09Z | 376097 | Cacciatore di trote | NO-SHOW | -10 | 109 -> 99 | MIDDLES -> NOOBS |
| 2026-08-07T18:38:38Z | 376098 | Uno per uno | NO-SHOW | -10 | 99 -> 89 | NOOBS |
| 2026-08-07T20:00:08Z | 376099 | Una gara davvero unica! | NO-SHOW | -11 | 89 -> 78 | NOOBS |
| 2026-08-07T22:00:22Z | 376100 | Vola come una farfalla, nuota come un Bass | PLAYED | +30 | 78 -> 108 | NOOBS -> MIDDLES |
| 2026-08-08T14:00:04Z | 376108 | Carpa jolly | NO-SHOW | -15 | 108 -> 93 | MIDDLES -> NOOBS |
| 2026-08-09T12:12:15Z | 376109 | Minaccia sanguinosa | NO-SHOW | -15 | 93 -> 78 | NOOBS |
| 2026-08-09T12:12:15Z | 376111 | Caccia alla Spigola ad alta velocità | NO-SHOW | -15 | 78 -> 63 | NOOBS |
| 2026-08-09T16:00:20Z | 376121 | Le dimensioni contano | PLAYED | +25 | 63 -> 88 | NOOBS |
| 2026-08-09T20:00:09Z | 376123 | Scontro finale di Trota Steelhead | NO-SHOW | -11 | 88 -> 77 | NOOBS |
| 2026-08-09T22:00:40Z | 376124 | Sfida di Spigole | PLAYED | +27 | 77 -> 104 | NOOBS -> MIDDLES |

## Played entries: bracket at entry vs. result

Bracket is read from the PCR standing at the moment the scoring-start line was written.

| Scoring start | Comp ID | PCR at entry | Bracket | Group | Place | Delta |
|---|---:|---:|---|---|---:|---:|
| 2026-08-02T18:23:36Z | 374739 | 36 | NOOBS | A | 15 | -2 |
| 2026-08-02T20:16:49Z | 374740 | 36 | NOOBS | A | 1 | +47 |
| 2026-08-03T06:02:14Z | 374837 | 81 | NOOBS | A | 2 | +27 |
| 2026-08-03T14:05:27Z | 374841 | 108 | MIDDLES | B | 60 | -4 |
| 2026-08-03T18:17:59Z | 374843 | 104 | MIDDLES | B | 17 | -4 |
| 2026-08-05T13:07:32Z | 376072 | 76 | NOOBS | A | 8 | +20 |
| 2026-08-05T22:27:47Z | 376077 | 85 | NOOBS | A | 9 | +15 |
| 2026-08-07T06:45:38Z | 376093 | 80 | NOOBS | A | 2 | +42 |
| 2026-08-07T21:13:51Z | 376100 | 78 | NOOBS | A | 1 | +30 |
| 2026-08-09T14:16:19Z | 376121 | 63 | NOOBS | A | 3 | +25 |
| 2026-08-09T20:48:13Z | 376124 | 77 | NOOBS | A | 2 | +27 |

The 9 entries inside the SQL window split 7 NOOBS / 2 MIDDLES, matching the SQL `Played 7N/2M/0T` exactly. The two MIDDLES entries are the only ones that failed to place (60th and 17th); every top-3 finish was made from NOOBS.

## Registrations by bracket at registration time

| Bracket at registration | Registered | Played | No-show | Pending |
|---|---:|---:|---:|---:|
| MIDDLES | 9 | 2 | 7 | 0 |
| NOOBS | 19 | 9 | 9 | 1 |

Pending: #376125 'A macchie o a pinima?' registered 2026-08-09T20:34:54Z, no reward row before the dump ends.

## Cross-check against SQL

The dump reaches 6 ledger rows further back than the SQL window. Restricting the ledger to rows from 2026-08-03T08:00:13Z onward reconciles perfectly:

- 21 ledger rows = SQL Reg 21
- 9 PLAYED = SQL started 9; 12 NO-SHOW = SQL no-shows 12 (57.1%)
- sum of NO-SHOW deltas = -155 = SQL absence -155
- sum of PLAYED deltas = +178 = SQL play +178
- 81 (PCR before #374837) -> 104 (final) = +23 = SQL net +23
- final PCR 104 = SQL PCR 104

SQL prize breakdown 5 = 5N/0M/0T is consistent with the ledger: the 5 prize-shaped finishes in the window (#374837 Place 2, #376093 Place 2, #376100 Place 1, #376121 Place 3, #376124 Place 2) were all entered from NOOBS; the two MIDDLES entries placed 60th and 17th.
