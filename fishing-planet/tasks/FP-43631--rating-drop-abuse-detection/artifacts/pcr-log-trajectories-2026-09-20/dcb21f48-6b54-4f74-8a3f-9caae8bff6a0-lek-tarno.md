---
uid: dcb21f48-6b54-4f74-8a3f-9caae8bff6a0
username: LEK_TARNO
platform: Steam
card_span: 2026-09-07T00:00:00Z .. 2026-09-20T23:59:59Z
charge_window: 2026-09-14 .. 2026-09-20
pcr_at_start: 13
pcr_at_end: 206
pcr_range: 3..214
max_pcr_in_window: 214
net_delta: +193 card span; +115 charge window
registrations: 101 card span; 73 charge window
played: 47 card span; 31 charge window
zero_score: 10 card span; 9 charge window
no_shows: 37 card span; 31 charge window
middles_to_noobs_drops: 6 (no-show 6, zero-score 0); 6 inside charge window
middles_to_noobs_drop_dates:
  - '2026-09-15T02:03:23Z  comp #332303  NO-SHOW  -11  (109 -> 98)  [charge window]'
  - '2026-09-15T10:18:02Z  comp #332307  NO-SHOW  -10  (108 -> 98)  [charge window]'
  - '2026-09-16T09:18:49Z  comp #332313  NO-SHOW  -10  (106 -> 96)  [charge window]'
  - '2026-09-18T01:20:43Z  comp #332475  NO-SHOW  -11  (111 -> 100)  [charge window]'
  - '2026-09-19T01:35:39Z  comp #332572  NO-SHOW  -10  (104 -> 94)  [charge window]'
  - '2026-09-20T00:48:55Z  comp #332660  NO-SHOW  -10  (110 -> 100)  [charge window]'
batched_flush_groups: 11 card span; 10 charge window; largest cluster 6 entries
longest_no_show_streak_hours: 16.7 (run of 6, 2026-09-16T16:00:06Z .. 2026-09-17T08:44:01Z)
presence_gaps: 37 gaps of 2h or more; 182.5 h = 54.3% of the 336 h card span
cheat_triggers: 622 card span; 377 charge window
evidence_completeness: ok
notable:
  - 'charge-window ledger: 71 entries - 31 played, 9 zero-score, 31 no-show'
  - 'charge-window rating split: -506 from unproductive entries, +621 from productive play, net +115'
  - 'largest same-second flush in window: 6 entries at 2026-09-16T09:18:49Z, 5 of them no-show'
  - 'MIDDLES to NOOBS crossings inside the window: 6 on 2026-09-15, 2026-09-15, 2026-09-16, 2026-09-18, 2026-09-19, 2026-09-20'
  - '1 unregistration event, of which 1 in the charge window'
  - 'most frequent cheat triggers: Line has high extension too often x258; Undriven boat moves TOO fast x145; Friction force is too high x70'
  - 'longest silence 2026-09-11T06:18:30Z to 2026-09-12T13:11:08Z, 30.9 h (interior)'
  - 'unproductive entries by activity context: 17 in-gap, 30 in-presence over the card span'
---

# LEK_TARNO - PCR trajectory card

LEK_TARNO, Steam. Card span 2026-09-07T00:00:00Z .. 2026-09-20T23:59:59Z, the full retention of the source log collection. The charge window is 2026-09-14 .. 2026-09-20; everything dated before 2026-09-14 on this card is pre-context and is not part of the charge.

## Ledger

99 participations over the card span, 94 of them carrying a reward line in the log, 72 of them inside the charge window. Status comes from the participation record in the database, not from the log: NO-SHOW where the player never entered, ZERO-SCORE where he entered and finished without a score, PLAYED otherwise. The log supplies the registration time, the presence marks and the PCR chain, and rows it does not carry are marked in the ledger.

| Comp start       | Registered  | Applied     | RegPCR | StartPCR | Status     | Place | Delta | PCR chain  | Presence    |  Fee | ID     | Competition                            |
|------------------|-------------|-------------|-------:|---------:|------------|------:|------:|:----------:|-------------|-----:|--------|----------------------------------------|
| 2026-09-07 12:00 | 09-07 09:51 | 09-07 14:00 |     13 |       13 | PLAYED     |     1 |    55 |  13 -> 68  | in-presence | 2500 | 331654 | No Ruler - No Party                    |
| 2026-09-07 14:00 | 09-07 13:54 | .           |     13 |       68 | PLAYED     |    11 |     0 | not logged | .           |  500 | 331655 | (no reward line in log)                |
| 2026-09-08 14:00 | 09-08 13:47 | 09-08 16:00 |     68 |       68 | PLAYED     |     8 |    20 |  68 -> 88  | in-presence | 2000 | 331746 | Don't bully me, Shark!                 |
| 2026-09-08 16:00 | 09-08 15:43 | 09-09 08:38 |     68 |       88 | PLAYED     |     6 |    30 | 88 -> 118  | in-gap      | 2500 | 331747 | Meaty Fellas                           |
| 2026-09-09 10:00 | 09-09 09:53 | 09-09 12:00 |    118 |      118 | PLAYED     |    27 |    -3 | 118 -> 115 | in-presence |  300 | 331823 | Falcon Trout Chase                     |
| 2026-09-09 12:00 | 09-09 09:53 | 09-09 14:00 |    118 |      115 | PLAYED     |    25 |    -4 | 115 -> 111 | in-gap      |  500 | 331824 | Lucky Spot                             |
| 2026-09-10 02:00 | 09-10 01:35 | 09-10 04:00 |    111 |      111 | PLAYED     |     2 |    50 | 111 -> 161 | in-presence | 2000 | 331902 | Big Brother                            |
| 2026-09-10 04:00 | 09-10 03:42 | 09-10 06:00 |    111 |      161 | PLAYED     |    21 |    -6 | 161 -> 155 | in-gap      |  900 | 331903 | Jolly Carp                             |
| 2026-09-10 10:00 | 09-10 09:53 | 09-10 12:06 |    155 |      155 | PLAYED     |     1 |    55 | 155 -> 210 | in-presence | 2500 | 331906 | No Ruler - No Party                    |
| 2026-09-10 14:00 | 09-10 13:11 | 09-10 16:00 |    210 |      210 | PLAYED     |    21 |    -3 | 210 -> 207 | in-presence |  300 | 331908 | One by One                             |
| 2026-09-10 16:00 | 09-10 15:52 | 09-11 06:18 |    210 |      207 | PLAYED     |    59 |    -3 | 207 -> 204 | in-gap      |  300 | 331909 | Trout Hunter                           |
| 2026-09-12 14:00 | 09-12 13:11 | 09-12 16:00 |    204 |      204 | PLAYED     |    30 |    -6 | 204 -> 198 | in-presence |  900 | 332088 | Bass Speed Hunt                        |
| 2026-09-12 16:00 | 09-12 15:28 | 09-12 18:00 |    204 |      198 | PLAYED     |    24 |    -6 | 198 -> 192 | in-presence | 1200 | 332089 | Maku-Maku Carnivores                   |
| 2026-09-12 20:00 | 09-12 18:27 | 09-13 03:14 |    192 |        . | NO-SHOW    |     . |   -11 | 161 -> 150 | in-gap      |  500 | 332091 | The Size Matters                       |
| 2026-09-12 22:00 | 09-12 18:27 | 09-13 03:14 |    192 |        . | NO-SHOW    |     . |   -20 | 192 -> 172 | in-gap      | 2500 | 332092 | Hit the Line Jack                      |
| 2026-09-13 00:00 | 09-12 18:27 | 09-13 03:14 |    192 |        . | NO-SHOW    |     . |   -11 | 172 -> 161 | in-gap      |  500 | 332175 | Sturgeon in the Dark                   |
| 2026-09-13 02:00 | 09-12 18:28 | 09-13 04:00 |    192 |        . | NO-SHOW    |     . |   -13 | 150 -> 137 | in-presence |  700 | 332176 | Dream Bream Hunt                       |
| 2026-09-13 04:00 | 09-12 18:28 | 09-13 06:00 |    192 |      137 | PLAYED     |    14 |    -1 | 137 -> 136 | in-gap      | 2000 | 332177 | Big Brother                            |
| 2026-09-13 06:00 | 09-13 05:40 | 09-13 08:00 |    137 |        . | NO-SHOW    |     . |   -10 | 136 -> 126 | in-gap      |  200 | 332178 | Cheesy Cat                             |
| 2026-09-13 08:00 | 09-13 05:41 | 09-13 10:00 |    137 |        . | NO-SHOW    |     . |   -13 | 126 -> 113 | in-presence |  700 | 332179 | Tench Clench!                          |
| 2026-09-13 10:00 | 09-13 05:41 | 09-13 12:00 |    137 |      113 | ZERO-SCORE |     . |    -7 | 113 -> 106 | in-presence |  500 | 332180 | Kaniq Topwater Rodeo                   |
| 2026-09-13 12:00 | 09-13 05:41 | 09-13 14:00 |    137 |      106 | PLAYED     |    51 |    -4 | 106 -> 102 | in-presence |  500 | 332181 | Catfish Trial                          |
| 2026-09-13 14:00 | 09-13 05:41 | 09-13 16:00 |    137 |      102 | PLAYED     |    41 |    -5 | 102 -> 97  | in-presence |  800 | 332182 | Long Asia                              |
| 2026-09-13 16:00 | 09-13 10:04 | 09-13 18:00 |    113 |       97 | PLAYED     |    61 |    -6 |  97 -> 91  | in-gap      |  900 | 332183 | Mighty Three                           |
| 2026-09-13 18:00 | 09-13 10:04 | 09-14 01:39 |    113 |        . | NO-SHOW    |     . |   -10 |  76 -> 66  | in-presence |  500 | 332184 | One of us, Two of Asp                  |
| 2026-09-13 20:00 | 09-13 10:04 | 09-14 01:39 |    113 |        . | NO-SHOW    |     . |   -15 |  91 -> 76  | in-presence | 1500 | 332185 | Marron River Diversity                 |
| 2026-09-13 22:00 | 09-13 10:04 | 09-14 01:39 |    113 |        . | NO-SHOW    |     . |   -20 |  66 -> 46  | in-presence | 4000 | 332186 | Sturgeon Showdown!                     |
| 2026-09-14 00:00 | 09-13 13:03 | 09-14 09:39 |    106 |        . | NO-SHOW    |     . |   -20 |  46 -> 26  | in-gap      | 2500 | 332244 | Tigers Trail                           |
| 2026-09-14 10:00 | 09-14 01:42 | 09-14 12:00 |     46 |       26 | PLAYED     |     8 |    12 |  26 -> 38  | in-presence |  500 | 332249 | The Battle of Kaniq                    |
| 2026-09-14 12:00 | 09-14 01:43 | 09-14 14:00 |     46 |       38 | PLAYED     |     1 |    55 |  38 -> 93  | in-presence | 1200 | 332250 | Living Fossil                          |
| 2026-09-14 14:00 | 09-14 13:43 | 09-14 16:00 |     38 |       93 | PLAYED     |     2 |    50 | 93 -> 143  | in-presence | 2000 | 332251 | Don't bully me, Shark!                 |
| 2026-09-14 16:00 | 09-14 13:46 | 09-14 18:00 |     38 |      143 | ZERO-SCORE |     . |    -8 | 143 -> 135 | in-presence |  900 | 332252 | Grass Сutter Range                     |
| 2026-09-14 18:00 | 09-14 13:46 | 09-15 01:17 |     38 |      135 | ZERO-SCORE |     . |    -5 | 135 -> 130 | in-presence |  200 | 332253 | Gar-mageddon Mud Battle                |
| 2026-09-14 20:00 | 09-14 13:46 | 09-15 01:17 |     38 |        . | NO-SHOW    |     . |   -11 | 130 -> 119 | in-presence |  500 | 332254 | Dancing with Pike                      |
| 2026-09-14 22:00 | 09-14 13:46 | 09-15 01:17 |     38 |        . | NO-SHOW    |     . |   -10 | 119 -> 109 | in-presence |  500 | 332255 | Spin The Trout                         |
| 2026-09-15 00:00 | 09-14 13:46 | 09-15 02:03 |     38 |        . | NO-SHOW    |     . |   -11 | 109 -> 98  | in-presence |  300 | 332303 | Big Red Fish                           |
| 2026-09-15 02:00 | 09-14 17:20 | 09-15 06:09 |    143 |       98 | PLAYED     |     2 |    50 | 78 -> 128  | in-presence | 2500 | 332304 | One Short and One Long                 |
| 2026-09-15 04:00 | 09-14 17:20 | 09-15 06:09 |    143 |        . | NO-SHOW    |     . |   -20 |  98 -> 78  | in-presence | 3500 | 332305 | Night Ruby Snapshot!                   |
| 2026-09-15 06:00 | 09-14 19:01 | 09-15 10:18 |    135 |        . | NO-SHOW    |     . |   -20 | 128 -> 108 | in-gap      | 4000 | 332306 | Norway Outstanding Minnies!            |
| 2026-09-15 08:00 | 09-15 01:26 | 09-15 10:18 |    109 |        . | NO-SHOW    |     . |   -10 | 108 -> 98  | in-gap      |  300 | 332307 | Length Matters                         |
| 2026-09-15 10:00 | 09-15 01:26 | 09-15 12:00 |    109 |        . | NO-SHOW    |     . |   -13 |  98 -> 85  | in-presence |  800 | 332308 | Siberian Khan                          |
| 2026-09-15 12:00 | 09-15 01:26 | 09-15 14:00 |    109 |       85 | PLAYED     |     2 |    42 | 85 -> 127  | in-presence | 1200 | 332309 | Maku-Maku Carnivores                   |
| 2026-09-15 14:00 | 09-15 03:41 | 09-15 16:00 |     98 |        . | NO-SHOW    |     . |   -10 | 127 -> 117 | in-presence |  300 | 332310 | Falcon Trout Chase                     |
| 2026-09-15 16:00 | 09-15 06:10 | 09-16 09:18 |    128 |      117 | PLAYED     |    44 |    -3 |  96 -> 93  | in-gap      |  300 | 332311 | Fly like a Butterfly, Swim like a Bass |
| 2026-09-15 18:00 | 09-15 06:11 | 09-16 09:18 |    128 |        . | NO-SHOW    |     . |   -20 |  93 -> 73  | in-gap      | 2000 | 332312 | Topwater Victory                       |
| 2026-09-15 20:00 | 09-15 13:23 | 09-16 09:18 |     85 |        . | NO-SHOW    |     . |   -10 | 106 -> 96  | in-gap      |  300 | 332313 | One by One                             |
| 2026-09-15 22:00 | 09-15 13:23 | 09-16 09:18 |     85 |        . | NO-SHOW    |     . |   -11 | 117 -> 106 | in-gap      |  500 | 332314 | Steelhead Showdown                     |
| 2026-09-16 00:00 | 09-15 13:23 | 09-16 09:18 |     85 |        . | NO-SHOW    |     . |   -11 |  73 -> 62  | in-gap      |  500 | 332372 | A Truly Unique Race!                   |
| 2026-09-16 02:00 | 09-15 14:28 | 09-16 09:18 |    127 |        . | NO-SHOW    |     . |   -20 |  62 -> 42  | in-gap      | 2500 | 332373 | Meaty Fellas                           |
| 2026-09-16 10:00 | 09-16 09:19 | 09-16 12:00 |     42 |       42 | PLAYED     |     4 |    20 |  42 -> 62  | in-presence |  500 | 332376 | One of us, Two of Asp                  |
| 2026-09-16 12:00 | 09-16 09:19 | 09-16 14:00 |     42 |       62 | PLAYED     |     4 |    22 |  62 -> 84  | in-presence |  500 | 332377 | Lucky Spot                             |
| 2026-09-16 14:00 | 09-16 09:19 | 09-16 16:00 |     42 |        . | NO-SHOW    |     . |   -13 |  84 -> 71  | in-gap      |  700 | 332378 | Strike! And another strike!            |
| 2026-09-16 16:00 | 09-16 12:06 | 09-16 18:00 |     62 |        . | NO-SHOW    |     . |   -20 |  71 -> 51  | in-presence | 4000 | 332379 | Big Speed Hunt!                        |
| 2026-09-16 18:00 | 09-16 12:06 | 09-17 08:44 |     62 |        . | NO-SHOW    |     . |   -15 |  51 -> 36  | in-gap      | 1200 | 332380 | Smile, it’s Jacunda time!              |
| 2026-09-16 20:00 | 09-16 12:06 | 09-17 08:44 |     62 |        . | NO-SHOW    |     . |   -13 |  36 -> 23  | in-gap      |  800 | 332381 | Crank the river                        |
| 2026-09-17 00:00 | 09-16 18:04 | 09-17 08:44 |     51 |        . | NO-SHOW    |     . |   -10 |  23 -> 13  | in-gap      |  300 | 332465 | Ideal Accuracy                         |
| 2026-09-17 02:00 | 09-16 14:31 | 09-17 08:44 |     84 |        . | NO-SHOW    |     . |   -10 |  13 -> 3   | in-gap      |  300 | 332466 | Best Five Bass                         |
| 2026-09-17 10:00 | 09-17 08:45 | 09-17 12:00 |      3 |        3 | PLAYED     |     4 |    40 |  3 -> 43   | in-presence | 2000 | 332470 | Amazing Bass Hunt                      |
| 2026-09-17 12:00 | 09-17 08:45 | 09-17 14:00 |      3 |       43 | PLAYED     |     9 |    15 |  43 -> 58  | in-presence | 2500 | 332471 | Tigers Trail                           |
| 2026-09-17 14:00 | 09-17 08:45 | 09-17 16:00 |      3 |       58 | PLAYED     |     2 |    42 | 58 -> 100  | in-presence | 1500 | 332472 | Lucky 50                               |
| 2026-09-17 16:00 | 09-17 08:45 | 09-17 18:00 |      3 |      100 | PLAYED     |     5 |    15 | 100 -> 115 | in-presence |  200 | 332473 | Breaking Shad                          |
| 2026-09-17 18:00 | 09-17 13:30 | 09-18 01:20 |     43 |      115 | PLAYED     |    20 |    -4 | 115 -> 111 | in-presence |  500 | 332474 | Muskie Topping                         |
| 2026-09-17 20:00 | 09-17 15:27 | 09-18 01:20 |     58 |        . | NO-SHOW    |     . |   -11 | 111 -> 100 | in-presence |  500 | 332475 | Dancing with Pike                      |
| 2026-09-17 22:00 | 09-17 15:27 | 09-18 01:20 |     58 |        . | NO-SHOW    |     . |   -20 | 100 -> 80  | in-presence | 3500 | 332476 | All Fish, All In!                      |
| 2026-09-18 00:00 | 09-17 13:56 | .           |     43 |       80 | PLAYED     |    12 |     0 | not logged | .           |  700 | 332562 | (no reward line in log)                |
| 2026-09-18 02:00 | 09-17 18:43 | 09-18 04:00 |    115 |       80 | PLAYED     |     1 |    30 | 80 -> 110  | in-presence |  300 | 332563 | Zander Zeek Differences                |
| 2026-09-18 04:00 | 09-17 18:43 | 09-18 06:00 |    115 |      110 | PLAYED     |     3 |    37 | 110 -> 147 | in-presence | 1200 | 332564 | Bloody Threat                          |
| 2026-09-18 06:00 | 09-18 01:23 | 09-18 08:00 |     80 |      147 | PLAYED     |    22 |    -5 | 147 -> 142 | in-gap      |  700 | 332565 | Five-Star Pikes!                       |
| 2026-09-18 08:00 | 09-18 01:23 | 09-18 10:11 |     80 |        . | NO-SHOW    |     . |   -10 | 142 -> 132 | in-presence |  300 | 332566 | Falcon Trout Chase                     |
| 2026-09-18 10:00 | 09-18 01:23 | 09-18 12:00 |     80 |      132 | PLAYED     |    32 |    -5 | 132 -> 127 | in-presence |  800 | 332567 | Bobber Burbot                          |
| 2026-09-18 12:00 | 09-18 02:37 | 09-18 14:00 |     80 |      127 | ZERO-SCORE |     . |   -10 | 127 -> 117 | in-presence | 4000 | 332568 | Great Halibut Gathering!               |
| 2026-09-18 14:00 | 09-18 02:37 | 09-18 16:00 |     80 |      117 | PLAYED     |    25 |    -7 | 117 -> 110 | in-presence | 2000 | 332569 | Topwater Victory                       |
| 2026-09-18 16:00 | 09-18 07:26 | 09-18 18:00 |    147 |      110 | PLAYED     |    23 |    -6 | 110 -> 104 | in-presence | 2500 | 332570 | Labeo Twins                            |
| 2026-09-18 18:00 | 09-18 07:26 | 09-19 01:35 |    147 |      104 | PLAYED     |    27 |    -3 |  94 -> 91  | in-presence |  200 | 332571 | Neherrin Minimal                       |
| 2026-09-18 20:00 | 09-18 12:22 | 09-19 01:35 |    127 |        . | NO-SHOW    |     . |   -10 | 104 -> 94  | in-presence |  200 | 332572 | Big Bowfin Hunting                     |
| 2026-09-18 22:00 | 09-18 12:22 | 09-19 01:35 |    127 |        . | NO-SHOW    |     . |   -20 |  91 -> 71  | in-presence | 3500 | 332573 | Night Ruby Snapshot!                   |
| 2026-09-19 00:00 | 09-18 12:22 | 09-19 02:00 |    127 |       71 | PLAYED     |    32 |    -3 |  71 -> 68  | in-presence |  200 | 332650 | Bass Challenge                         |
| 2026-09-19 02:00 | 09-18 17:34 | 09-19 04:00 |     71 |       68 | ZERO-SCORE |     . |    -6 |  68 -> 62  | in-presence |  500 | 332651 | Catfish Trial                          |
| 2026-09-19 04:00 | 09-18 17:34 | 09-19 06:21 |    110 |       62 | PLAYED     |     1 |    35 |  62 -> 97  | in-presence |  500 | 332652 | San Joaquin Extravaganza               |
| 2026-09-19 06:00 | 09-19 03:30 | 09-19 08:00 |     68 |       97 | ZERO-SCORE |     . |    -7 |  97 -> 90  | in-presence |  500 | 332653 | Kaniq Topwater Rodeo                   |
| 2026-09-19 08:00 | 09-19 03:30 | 09-19 12:03 |     68 |       90 | PLAYED     |    18 |    -2 |  90 -> 88  | in-presence |  300 | 332654 | Catch em' All                          |
| 2026-09-19 10:00 | 09-19 03:30 | 09-19 12:03 |     68 |        . | NO-SHOW    |     . |   -15 |  88 -> 73  | in-presence | 1200 | 332655 | Trophy Whiskers                        |
| 2026-09-19 12:00 | 09-19 03:30 | 09-19 14:00 |     68 |       73 | PLAYED     |     1 |    40 | 73 -> 113  | in-presence |  700 | 332656 | Carp Foundation                        |
| 2026-09-19 14:00 | 09-19 03:30 | 09-19 16:00 |     68 |      113 | PLAYED     |     8 |    15 | 113 -> 128 | in-presence | 1500 | 332657 | Red and Shiny                          |
| 2026-09-19 16:00 | 09-19 05:30 | 09-19 18:00 |     62 |      128 | ZERO-SCORE |     . |   -10 | 128 -> 118 | in-presence | 4000 | 332658 | Norway Outstanding Minnies!            |
| 2026-09-19 18:00 | 09-19 15:33 | 09-20 00:48 |    113 |      118 | ZERO-SCORE |     . |    -8 | 118 -> 110 | in-presence |  900 | 332659 | Saltwater Giants                       |
| 2026-09-19 20:00 | 09-19 18:09 | 09-20 00:48 |    118 |        . | NO-SHOW    |     . |   -10 | 110 -> 100 | in-presence |  300 | 332660 | Ideal Accuracy                         |
| 2026-09-19 22:00 | 09-19 18:10 | 09-20 00:48 |    118 |        . | NO-SHOW    |     . |   -20 | 100 -> 80  | in-presence | 3500 | 332661 | Marlin Family Reunion!                 |
| 2026-09-20 00:00 | 09-19 18:08 | 09-20 02:00 |    118 |       80 | ZERO-SCORE |     . |    -6 |  80 -> 74  | in-presence |  500 | 332748 | A Truly Unique Race!                   |
| 2026-09-20 02:00 | 09-19 18:08 | 09-20 04:05 |    118 |       74 | PLAYED     |     1 |    30 | 74 -> 104  | in-presence |  500 | 332749 | Marble Frenzy on the Tiber             |
| 2026-09-20 04:00 | 09-19 18:08 | 09-20 06:00 |    118 |      104 | PLAYED     |     1 |    55 | 104 -> 159 | in-presence | 2500 | 332750 | One Short and One Long                 |
| 2026-09-20 06:00 | 09-19 18:08 | 09-20 08:00 |    118 |      159 | PLAYED     |     1 |    55 | 159 -> 214 | in-presence | 2000 | 332751 | Don't bully me, Shark!                 |
| 2026-09-20 08:00 | 09-20 05:59 | 09-20 10:20 |    104 |      214 | PLAYED     |    39 |    -3 | 214 -> 211 | in-presence |  300 | 332752 | Fly like a Butterfly, Swim like a Bass |
| 2026-09-20 10:00 | 09-20 05:59 | 09-20 12:00 |    104 |      211 | PLAYED     |    20 |    -6 | 211 -> 205 | in-presence | 1200 | 332753 | Maku-Maku Carnivores                   |
| 2026-09-20 12:00 | 09-20 05:59 | 09-20 14:00 |    104 |      205 | PLAYED     |     9 |     8 | 205 -> 213 | in-presence |  700 | 332754 | Danger in the grass                    |
| 2026-09-20 14:00 | 09-20 07:40 | 09-20 16:00 |    159 |      213 | ZERO-SCORE |     . |    -7 | 213 -> 206 | in-presence |  500 | 332755 | Salmon Clash                           |
| 2026-09-20 16:00 | 09-20 05:59 | .           |    104 |      206 | ZERO-SCORE |     . |   -10 | not logged | .           | 4000 | 332756 | (no reward line in log)                |
| 2026-09-20 20:00 | 09-20 16:56 | .           |    206 |        . | NO-SHOW    |     . |   -15 | not logged | .           | 1500 | 332758 | (no reward line in log)                |
| 2026-09-20 22:00 | 09-20 16:56 | .           |    206 |        . | NO-SHOW    |     . |   -20 | not logged | .           | 3000 | 332759 | (no reward line in log)                |

> **Spine is SQL, not the log** (week-20). Rows marked `(no reward line in log)` are
> participations SQL records and the ledger does not: the competition resolved but no
> `Tournament reward` line was ever written for it. 5 of 99 rows here. Their rating
> delta is real and is in the SQL column; the PCR chain simply skips them, so a chain read
> end-to-end will not reconcile with `CurrentPCR` by exactly those deltas.

Charge-window boundary: the first in-window entry is 2026-09-14T01:39:25Z at PCR 91 before, the last is 2026-09-20T16:00:09Z at PCR 206 after.

## MIDDLES to NOOBS crossings

Brackets: NOOBS 0-100, MIDDLES 101-1000, TOPS 1001+. A crossing is counted when pcr_before is 101 or more and pcr_after is 100 or less on a NO-SHOW or ZERO-SCORE entry, so 110 -> 100 counts and 100 -> 95 does not.

| Date | Timestamp | Comp ID | Status | Δ | PCR before -> after | In charge window |
|---|---|---|---|---|---|---|
| 2026-09-15 | 2026-09-15T02:03:23Z | 332303 | NO-SHOW | -11 | 109 -> 98 | yes |
| 2026-09-15 | 2026-09-15T10:18:02Z | 332307 | NO-SHOW | -10 | 108 -> 98 | yes |
| 2026-09-16 | 2026-09-16T09:18:49Z | 332313 | NO-SHOW | -10 | 106 -> 96 | yes |
| 2026-09-18 | 2026-09-18T01:20:43Z | 332475 | NO-SHOW | -11 | 111 -> 100 | yes |
| 2026-09-19 | 2026-09-19T01:35:39Z | 332572 | NO-SHOW | -10 | 104 -> 94 | yes |
| 2026-09-20 | 2026-09-20T00:48:55Z | 332660 | NO-SHOW | -10 | 110 -> 100 | yes |

Total 6 (no-show 6, zero-score 0); 6 inside the charge window.

## Batched flushes and no-show streaks

Same-second clusters of two or more reward entries containing at least one NO-SHOW: **11** over the card span, **10** inside the charge window; largest cluster 6 entries.

| Timestamp | Entries | No-show | Zero-score | Played | Net Δ |
|---|---|---|---|---|---|
| 2026-09-13T03:14:03Z | 3 | 3 | 0 | 0 | -42 |
| 2026-09-14T01:39:25Z | 3 | 3 | 0 | 0 | -45 |
| 2026-09-15T01:17:19Z | 3 | 2 | 1 | 0 | -26 |
| 2026-09-15T06:09:24Z | 2 | 1 | 0 | 1 | +30 |
| 2026-09-15T10:18:02Z | 2 | 2 | 0 | 0 | -30 |
| 2026-09-16T09:18:49Z | 6 | 5 | 0 | 1 | -75 |
| 2026-09-17T08:44:01Z | 4 | 4 | 0 | 0 | -48 |
| 2026-09-18T01:20:43Z | 3 | 2 | 0 | 1 | -35 |
| 2026-09-19T01:35:39Z | 3 | 2 | 0 | 1 | -33 |
| 2026-09-19T12:03:01Z | 2 | 1 | 0 | 1 | -17 |
| 2026-09-20T00:48:55Z | 3 | 2 | 1 | 0 | -38 |

Longest run of five or more consecutive no-show entries: 16.7 (run of 6, 2026-09-16T16:00:06Z .. 2026-09-17T08:44:01Z).

## Presence

Gaps are intervals of two hours or more inside the card span with no log line of any type in `dcb21f48-6b54-4f74-8a3f-9caae8bff6a0-lek-tarno-presence.tsv`. The interval from the card-span start to the first logged line and from the last logged line to the card-span end are included and labelled.

**37 gaps, 182.5 h in total, 54.3% of the 336 h card span** (172.6 h interior, 9.9 h at the card-span edges).

| Gap | Hours | Kind |
|---|---|---|
| 2026-09-07T00:00:00Z -> 2026-09-07T09:51:10Z | 9.9 | leading |
| 2026-09-07T09:51:10Z -> 2026-09-07T12:05:27Z | 2.2 | interior |
| 2026-09-07T16:00:15Z -> 2026-09-08T13:47:45Z | 21.8 | interior |
| 2026-09-08T18:00:02Z -> 2026-09-09T08:38:23Z | 14.6 | interior |
| 2026-09-09T14:00:22Z -> 2026-09-10T01:35:25Z | 11.6 | interior |
| 2026-09-10T06:00:09Z -> 2026-09-10T09:53:02Z | 3.9 | interior |
| 2026-09-10T18:00:02Z -> 2026-09-11T06:18:30Z | 12.3 | interior |
| 2026-09-11T06:18:30Z -> 2026-09-12T13:11:08Z | 30.9 | interior |
| 2026-09-12T18:28:39Z -> 2026-09-12T22:00:02Z | 3.5 | interior |
| 2026-09-12T22:00:02Z -> 2026-09-13T00:00:02Z | 2.0 | interior |
| 2026-09-13T00:00:02Z -> 2026-09-13T02:00:02Z | 2.0 | interior |
| 2026-09-13T20:00:02Z -> 2026-09-13T22:00:02Z | 2.0 | interior |
| 2026-09-13T22:00:02Z -> 2026-09-14T00:00:02Z | 2.0 | interior |
| 2026-09-14T02:00:02Z -> 2026-09-14T09:39:41Z | 7.7 | interior |
| 2026-09-14T20:00:02Z -> 2026-09-14T22:00:02Z | 2.0 | interior |
| 2026-09-14T22:00:02Z -> 2026-09-15T00:00:02Z | 2.0 | interior |
| 2026-09-15T04:00:02Z -> 2026-09-15T06:00:02Z | 2.0 | interior |
| 2026-09-15T08:00:02Z -> 2026-09-15T10:00:02Z | 2.0 | interior |
| 2026-09-15T18:00:02Z -> 2026-09-15T20:00:02Z | 2.0 | interior |
| 2026-09-15T20:00:02Z -> 2026-09-15T22:00:02Z | 2.0 | interior |
| 2026-09-15T22:00:02Z -> 2026-09-16T00:00:02Z | 2.0 | interior |
| 2026-09-16T00:00:02Z -> 2026-09-16T02:00:02Z | 2.0 | interior |
| 2026-09-16T02:00:02Z -> 2026-09-16T04:00:02Z | 2.0 | interior |
| 2026-09-16T04:00:02Z -> 2026-09-16T09:18:49Z | 5.3 | interior |
| 2026-09-16T20:00:02Z -> 2026-09-16T22:00:02Z | 2.0 | interior |
| 2026-09-16T22:00:02Z -> 2026-09-17T02:00:02Z | 4.0 | interior |
| 2026-09-17T02:00:02Z -> 2026-09-17T04:00:02Z | 2.0 | interior |
| 2026-09-17T04:00:02Z -> 2026-09-17T08:44:01Z | 4.7 | interior |
| 2026-09-17T08:45:41Z -> 2026-09-17T10:50:27Z | 2.1 | interior |
| 2026-09-17T20:00:02Z -> 2026-09-17T22:00:02Z | 2.0 | interior |
| 2026-09-17T22:00:02Z -> 2026-09-18T00:00:02Z | 2.0 | interior |
| 2026-09-18T20:00:02Z -> 2026-09-18T22:00:02Z | 2.0 | interior |
| 2026-09-18T22:00:02Z -> 2026-09-19T00:00:02Z | 2.0 | interior |
| 2026-09-19T10:00:02Z -> 2026-09-19T12:00:02Z | 2.0 | interior |
| 2026-09-19T20:00:02Z -> 2026-09-19T22:00:02Z | 2.0 | interior |
| 2026-09-19T22:00:02Z -> 2026-09-20T00:00:02Z | 2.0 | interior |
| 2026-09-20T18:00:02Z -> 2026-09-20T22:00:02Z | 4.0 | interior |

### How the in-gap / in-presence column is derived

Every reward write is itself a logged line, so measured against the raw presence stream all 94 ledger entries would trivially read in-presence. The column therefore tests each timestamp against the **activity stream**: the presence stream with the server-side tournament-batch lines removed (`About to process tournament Competition #...` and `Tournament reward Competition #...`, 190 lines). On that stream there are 43 gaps of two hours or more totalling 199.2 h, 59.3% of the card span, and an entry reads in-gap when its own timestamp falls inside one of them, that is when the player produced no other log line of any kind for at least two hours around the moment the rating moved.

**The ledger timestamp is the moment the rating was applied, not the moment the competition ran.** Tournament results are processed in server-side batches after a competition closes, so in-presence does not by itself prove the player was online while the competition ran or that he chose to skip it, and in-gap does not prove he was away while it ran.

Unproductive entries (NO-SHOW plus ZERO-SCORE) by activity context: **17 in-gap, 30 in-presence** over the card span; 13 and 27 respectively inside the charge window.

## Other log events

| Event | Card span | Charge window |
|---|---|---|
| `Player registered for Competition #` | 101 | 73 |
| `Player unregistered from Competition #` | 1 | 1 |
| failed registration attempts | 0 | 0 |
| `Player started scoring time for Competition #` | 60 | 42 |
| `CHEAT:` triggers | 622 | 377 |

### Cheat triggers by kind

Numeric payloads inside a trigger message are collapsed to `N` so variants of the same check group into one row.

| Trigger | Card span | Charge window |
|---|---|---|
| Line has high extension too often | 258 | 178 |
| Undriven boat moves TOO fast | 145 | 90 |
| Friction force is too high | 70 | 20 |
| Fish catch distance is long | 58 | 32 |
| Throw.Same player position and rotation N times in row | 49 | 49 |
| Fish goes to player too often when it should not | 33 | 0 |
| Fish catch distance is VERY long | 3 | 2 |
| Attack time is short | 2 | 2 |
| Distance from tackle to attacking fish is long while reeling | 1 | 1 |
| Boat moves TOO fast | 1 | 1 |
| Line has critical extension too often | 1 | 1 |
| Fish reeling time is short when distance to fish is Nm | 1 | 1 |

## SQL cross-check, charge window 2026-09-14 .. 2026-09-20

| Measure | From log | From SQL | Verdict |
|---|---|---|---|
| Registrations | 73 | 72 | differs (+1) |
| Started, played plus zero-score | 40 | 42 | differs (-2) |
| Zero-score | 9 | 10 | differs (-1) |
| No-shows | 31 | 30 | differs (+1) |
| Unproductive, no-show plus zero-score | 40 | 40 | match |
| Rating from unproductive | -506 | -506 | match |
| Rating from productive play | +621 | +621 | match |
| Net delta | +115 | +115 | match |
| PCR after last in-span entry vs CurrentPCR | 206 | 206 | match |
| Highest pcr_before in window vs MaxRatingAtStart | 214 | 214 | match |

Registrations from the log count `Player registered for Competition #` lines timestamped inside the window; the SQL Reg column attributes a registration to the competition rather than to the moment the player pressed register, so the two need not agree at the window edges. Registrations are not part of the evidence_completeness test.

SQL reference row: Reg 72, Started 42, ZeroScore 10, NoShows 30, Unproductive 40, Share 55.56%, RatingFromUnproductive -506, RatingFromProductivePlay +621, NetDelta +115, G/S/B 7/4/1, Total 12, Played N/M/T 21/21/0, Prizes N/M/T 9/3/0, CurrentPCR 206, MaxRatingAtStart 214, Lifetime G/S/B 9/5/1.

### evidence_completeness: ok

Rule: a row is flagged when the log and SQL differ by more than 20% of the SQL figure or by more than 5 absolute events, whichever is larger. Only no-shows, zero-score and their sum are in scope.

Chain continuity: 94 reward entries, **0 breaks** - every entry's pcr_before equals the previous entry's pcr_after across the whole card span. No rating-changing reward line is missing from the retained log between the first and the last entry, so any shortfall against SQL comes from penalties absorbed at the rating floor (which write no line at all) or from window attribution, not from lost log lines.

- No in-scope row exceeds the tolerance.

Zero-score ids from the SQL list with no reward entry anywhere in the card span: #332756.
