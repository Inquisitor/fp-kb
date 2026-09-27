---
uid: bdd6d57e-e41f-475e-b067-c0d990a5a92c
username: xFenrir77
platform: Xbox (Win10 account)
card_span: 2026-09-07T00:00:00Z .. 2026-09-20T23:59:59Z
charge_window: 2026-09-14 .. 2026-09-20
pcr_at_start: 2601
pcr_at_end: 3212
pcr_range: 2601..3235
max_pcr_in_window: 3235
net_delta: +611 card span; +338 charge window
registrations: 73 card span; 48 charge window
played: 39 card span; 25 charge window
zero_score: 7 card span; 4 charge window
no_shows: 15 card span; 10 charge window
middles_to_noobs_drops: 0 (no-show 0, zero-score 0); 0 inside charge window
middles_to_noobs_drop_dates: []
boundary_behaviour: '100/101 line: never reached from above, span minimum 2601, 2501 above 100. 1000/1001 line: never reached from above, span minimum 2601, 1601 above 1000.'
batched_flush_groups: 2 card span; 1 charge window; largest cluster 3 entries
longest_no_show_streak_hours: 0.0 (run of 3, 2026-09-19T20:28:20Z .. 2026-09-19T20:28:21Z)
presence_gaps: 39 gaps of 2h or more; 211.5 h = 63.0% of the 336 h card span
cheat_triggers: 1507 card span; 859 charge window
evidence_completeness: ok
notable:
  - 'charge-window ledger: 39 entries - 25 played, 4 zero-score, 10 no-show'
  - 'charge-window rating split: -138 from unproductive entries, +476 from productive play, net +338'
  - 'bracket boundaries: the rating stays clear of both the 100/101 and the 1000/1001 line for the whole card span, range 2601..3235'
  - 'largest same-second flush in window: 3 entries at 2026-09-19T20:28:20Z, 2 of them no-show'
  - '2 unregistration events, of which 2 in the charge window; 0 failed registration attempts, 0 in window'
  - 'most frequent cheat triggers: Fish catch distance is VERY long x495; Line has high extension too often x231; Line has critical extension too often x167'
  - 'longest silence 2026-09-10T20:00:10Z to 2026-09-11T11:38:32Z, 15.6 h (interior)'
  - 'unproductive entries by activity context: 9 in-gap, 13 in-presence over the card span'
---

# xFenrir77 - PCR trajectory card

xFenrir77, Xbox (Win10 account). Card span 2026-09-07T00:00:00Z .. 2026-09-20T23:59:59Z, the full retention of the source log collection. The charge window is 2026-09-14 .. 2026-09-20; everything dated before 2026-09-14 on this card is pre-context and is not part of the charge.

## Ledger

68 participations over the card span, 61 of them carrying a reward line in the log, 42 of them inside the charge window. Status comes from the participation record in the database, not from the log: NO-SHOW where the player never entered, ZERO-SCORE where he entered and finished without a score, PLAYED otherwise. The log supplies the registration time, the presence marks and the PCR chain, and rows it does not carry are marked in the ledger.

| Comp start       | Registered  | Applied     | RegPCR | StartPCR | Status     | Place | Delta |  PCR chain   | Presence    |  Fee | ID     | Competition                  |
|------------------|-------------|-------------|-------:|---------:|------------|------:|------:|:------------:|-------------|-----:|--------|------------------------------|
| 2026-09-07 06:00 | .           | 09-07 08:00 |   2556 |     2601 | PLAYED     |     2 |    50 | 2601 -> 2651 | in-gap      | 4000 | 159924 | いじめないよ、サメ！                   |
| 2026-09-07 20:00 | 09-07 16:09 | 09-07 22:00 |   2651 |     2651 | PLAYED     |     2 |    50 | 2651 -> 2701 | in-gap      | 3500 | 159931 | Night Ruby Snapshot!         |
| 2026-09-08 20:00 | 09-08 08:54 | 09-08 22:00 |   2701 |     2701 | ZERO-SCORE |     . |    -7 | 2701 -> 2694 | in-gap      |  800 | 159975 | Bobber Burbot                |
| 2026-09-09 16:00 | 09-09 12:32 | 09-09 18:00 |   2694 |     2694 | PLAYED     |     8 |    10 | 2694 -> 2704 | in-gap      |  300 | 160028 | Length Matters               |
| 2026-09-10 00:00 | 09-09 17:28 | 09-10 02:00 |   2694 |     2704 | PLAYED     |     4 |    40 | 2704 -> 2744 | in-presence | 3000 | 160032 | Trophy Carnivores Hunt!      |
| 2026-09-10 02:00 | 09-09 17:28 | 09-10 04:00 |   2694 |     2744 | PLAYED     |     7 |    25 | 2744 -> 2769 | in-gap      | 3500 | 160033 | Sharper than sword!          |
| 2026-09-10 08:00 | 09-10 07:26 | 09-10 10:00 |   2769 |        . | NO-SHOW    |     . |   -15 | 2769 -> 2754 | in-gap      |  900 | 160069 | Lucky Ghost Hunt             |
| 2026-09-10 12:00 | 09-10 07:26 | 09-10 14:00 |   2769 |     2754 | PLAYED     |    14 |    -1 | 2754 -> 2753 | in-gap      |  300 | 160071 | One by One                   |
| 2026-09-10 14:00 | 09-10 13:50 | 09-10 16:00 |   2754 |        . | NO-SHOW    |     . |   -13 | 2753 -> 2740 | in-presence |  700 | 160072 | Danger in the grass          |
| 2026-09-10 16:00 | 09-10 07:26 | .           |   2769 |     2740 | PLAYED     |    11 |     0 |  not logged  | .           |  800 | 160073 | (no reward line in log)      |
| 2026-09-10 18:00 | 09-10 07:26 | 09-10 20:00 |   2769 |     2740 | PLAYED     |     5 |    19 | 2740 -> 2759 | in-gap      |  500 | 160074 | Dancing with Pike            |
| 2026-09-11 12:00 | 09-11 11:38 | 09-11 14:00 |   2759 |     2759 | PLAYED     |    14 |    -1 | 2759 -> 2758 | in-presence | 1500 | 160114 | Red and Shiny                |
| 2026-09-11 14:00 | 09-11 11:38 | 09-11 16:00 |   2759 |     2758 | PLAYED     |     3 |    45 | 2758 -> 2803 | in-presence | 4000 | 160115 | I will not bully you, Shark! |
| 2026-09-11 16:00 | 09-11 11:38 | 09-11 18:00 |   2759 |     2803 | PLAYED     |    16 |    -2 | 2803 -> 2801 | in-gap      |  500 | 160116 | The Battle of Kaniq          |
| 2026-09-11 18:00 | 09-11 11:38 | 09-11 20:00 |   2759 |        . | NO-SHOW    |     . |   -10 | 2801 -> 2791 | in-presence |  200 | 160117 | School Bass                  |
| 2026-09-12 06:00 | 09-12 01:35 | .           |   2791 |     2791 | PLAYED     |    12 |     0 |  not logged  | .           |  300 | 160169 | (no reward line in log)      |
| 2026-09-12 08:00 | 09-11 20:17 | 09-12 10:00 |   2791 |     2791 | PLAYED     |     1 |    40 | 2791 -> 2831 | in-presence |  800 | 160170 | Siberian Khan                |
| 2026-09-12 10:00 | 09-12 01:35 | 09-12 12:00 |   2791 |     2831 | PLAYED     |     1 |    35 | 2831 -> 2866 | in-gap      |  500 | 160171 | The Size Matters             |
| 2026-09-12 20:00 | 09-12 11:59 | 09-12 22:00 |   2831 |     2866 | PLAYED     |     2 |    50 | 2866 -> 2916 | in-gap      | 3500 | 160176 | Sharper than sword!          |
| 2026-09-13 06:00 | 09-13 03:25 | 09-13 08:00 |   2916 |        . | NO-SHOW    |     . |   -15 | 2916 -> 2901 | in-presence |  900 | 160217 | Lucky Ghost Hunt             |
| 2026-09-13 08:00 | 09-13 03:25 | 09-13 10:00 |   2916 |     2901 | PLAYED     |    18 |    -2 | 2901 -> 2899 | in-presence |  300 | 160218 | Emerald Predator Hunt        |
| 2026-09-13 10:00 | 09-13 03:25 | .           |   2916 |     2899 | PLAYED     |    13 |     0 |  not logged  | .           |  200 | 160219 | (no reward line in log)      |
| 2026-09-13 12:00 | 09-13 03:25 | 09-13 14:00 |   2916 |     2899 | ZERO-SCORE |     . |    -7 | 2899 -> 2892 | in-presence |  700 | 160220 | Carp Foundation              |
| 2026-09-13 14:00 | 09-13 03:25 | 09-13 19:00 |   2916 |     2892 | ZERO-SCORE |     . |    -8 | 2892 -> 2884 | in-gap      | 1500 | 160221 | Gigante Pirañas              |
| 2026-09-13 16:00 | 09-13 05:22 | 09-13 19:00 |   2916 |        . | NO-SHOW    |     . |   -10 | 2884 -> 2874 | in-gap      |  500 | 160222 | Scores from the bottom       |
| 2026-09-13 22:00 | 09-13 11:40 | 09-14 00:01 |   2899 |     2874 | PLAYED     |     3 |    45 | 2874 -> 2919 | in-gap      | 3500 | 160225 | Marlin Family Reunion!       |
| 2026-09-14 08:00 | 09-14 06:04 | 09-14 11:30 |   2919 |        . | NO-SHOW    |     . |   -10 | 2919 -> 2909 | in-presence |  200 | 160272 | Old Buck's Competition       |
| 2026-09-14 12:00 | 09-14 11:31 | 09-14 14:29 |   2909 |     2909 | PLAYED     |     5 |    35 | 2909 -> 2944 | in-presence | 4000 | 160274 | Norway Outstanding Minnies!  |
| 2026-09-14 14:00 | 09-14 11:31 | 09-14 16:00 |   2909 |     2944 | PLAYED     |     5 |    17 | 2944 -> 2961 | in-gap      |  300 | 160275 | Trout Hunter                 |
| 2026-09-14 16:00 | 09-14 13:53 | 09-14 18:00 |   2909 |        . | NO-SHOW    |     . |   -11 | 2961 -> 2950 | in-gap      |  500 | 160276 | Muskie Topping               |
| 2026-09-14 18:00 | 09-14 13:53 | 09-14 20:00 |   2909 |        . | NO-SHOW    |     . |   -10 | 2950 -> 2940 | in-presence |  300 | 160277 | Length Matters               |
| 2026-09-14 20:00 | 09-14 13:53 | 09-14 22:26 |   2909 |     2940 | PLAYED     |    17 |    -3 | 2940 -> 2937 | in-gap      | 1200 | 160278 | Carnivores Maku-Maku         |
| 2026-09-15 00:00 | 09-14 13:53 | 09-15 07:11 |   2909 |     2937 | PLAYED     |    21 |    -5 | 2937 -> 2932 | in-presence |  800 | 160280 | ウキとのカワメンタイ                   |
| 2026-09-15 16:00 | 09-15 07:12 | 09-15 18:00 |   2932 |     2932 | PLAYED     |     2 |    50 | 2932 -> 2982 | in-presence | 4000 | 160312 | I will not bully you, Shark! |
| 2026-09-15 18:00 | 09-15 08:54 | 09-15 20:00 |   2932 |     2982 | PLAYED     |     8 |     7 | 2982 -> 2989 | in-presence |  200 | 160313 | School Bass                  |
| 2026-09-16 06:00 | 09-15 18:03 | .           |   2982 |     2989 | PLAYED     |    13 |     0 |  not logged  | .           |  800 | 160341 | (no reward line in log)      |
| 2026-09-16 08:00 | 09-15 20:34 | .           |   2989 |        . | NO-SHOW    |     . |     . |  not logged  | .           | 3000 | 160342 | (no reward line in log)      |
| 2026-09-16 16:00 | 09-16 08:28 | 09-16 18:00 |   2989 |     2989 | PLAYED     |     7 |    14 | 2989 -> 3003 | in-presence |  500 | 160346 | The Battle of Kaniq          |
| 2026-09-16 18:00 | 09-16 08:28 | 09-16 20:00 |   2989 |     3003 | ZERO-SCORE |     . |    -5 | 3003 -> 2998 | in-presence |  500 | 160347 | Marble Frenzy on the Tiber   |
| 2026-09-16 20:00 | 09-16 18:15 | 09-16 22:00 |   3003 |     2998 | PLAYED     |    22 |    -5 | 2998 -> 2993 | in-gap      |  700 | 160348 | Five-Star Pikes!             |
| 2026-09-17 08:00 | 09-17 02:12 | 09-17 10:00 |   2993 |        . | NO-SHOW    |     . |   -11 | 2993 -> 2982 | in-presence |  500 | 160387 | Moonlight Gars               |
| 2026-09-17 12:00 | 09-17 02:12 | 09-17 14:00 |   2993 |     2982 | PLAYED     |     9 |     6 | 2982 -> 2988 | in-presence |  500 | 160389 | Scores from the bottom       |
| 2026-09-17 14:00 | 09-17 02:12 | 09-17 16:00 |   2993 |     2988 | PLAYED     |     3 |    45 | 2988 -> 3033 | in-presence | 3000 | 160390 | Giant Grouper Roundup!       |
| 2026-09-17 16:00 | 09-17 10:00 | 09-17 18:00 |   2982 |     3033 | PLAYED     |    10 |     4 | 3033 -> 3037 | in-presence |  700 | 160391 | Carp Foundation              |
| 2026-09-17 18:00 | 09-17 10:00 | 09-17 20:00 |   2982 |     3037 | PLAYED     |     2 |    50 | 3037 -> 3087 | in-presence | 3500 | 160392 | Woohoo Wahoo!                |
| 2026-09-17 20:00 | 09-17 19:47 | 09-17 22:00 |   3037 |     3087 | ZERO-SCORE |     . |    -7 | 3087 -> 3080 | in-gap      |  700 | 160393 | Strike! And another strike!  |
| 2026-09-18 08:00 | 09-18 04:48 | .           |   3080 |     3080 | PLAYED     |    13 |     0 |  not logged  | .           | 1500 | 160442 | (no reward line in log)      |
| 2026-09-18 12:00 | 09-18 04:48 | 09-18 14:00 |   3080 |     3080 | PLAYED     |     8 |    15 | 3080 -> 3095 | in-gap      |  900 | 160444 | Lucky Ghost Hunt             |
| 2026-09-18 14:00 | 09-18 04:48 | 09-18 16:00 |   3080 |        . | NO-SHOW    |     . |   -11 | 3095 -> 3084 | in-presence |  500 | 160445 | The Size Matters             |
| 2026-09-18 16:00 | 09-18 04:48 | 09-18 18:00 |   3080 |     3084 | PLAYED     |    20 |    -4 | 3084 -> 3080 | in-presence |  500 | 160446 | Triple the Trout!            |
| 2026-09-18 18:00 | 09-18 12:07 | 09-18 20:00 |   3080 |     3080 | PLAYED     |    24 |    -7 | 3080 -> 3073 | in-presence | 2000 | 160447 | Don't bully me, Shark!       |
| 2026-09-18 20:00 | 09-18 09:25 | 09-18 22:00 |   3080 |     3073 | PLAYED     |     3 |    45 | 3073 -> 3118 | in-presence | 3500 | 160448 | Marlin Family Reunion!       |
| 2026-09-18 22:00 | 09-18 12:07 | 09-19 00:00 |   3080 |     3118 | PLAYED     |     2 |    50 | 3118 -> 3168 | in-presence | 3000 | 160449 | Marlin Tug of War!           |
| 2026-09-19 00:00 | 09-18 12:07 | 09-19 02:00 |   3080 |     3168 | ZERO-SCORE |     . |    -7 | 3168 -> 3161 | in-gap      |  800 | 160450 | Bobber Burbot                |
| 2026-09-19 04:00 | 09-18 23:44 | 09-19 06:00 |   3118 |     3161 | PLAYED     |    17 |    -2 | 3161 -> 3159 | in-gap      |  300 | 160529 | One by One                   |
| 2026-09-19 10:00 | 09-19 05:40 | 09-19 12:00 |   3161 |     3159 | ZERO-SCORE |     . |    -7 | 3159 -> 3152 | in-presence |  500 | 160532 | Salmon Clash                 |
| 2026-09-19 12:00 | 09-19 11:24 | 09-19 20:28 |   3159 |     3152 | PLAYED     |    17 |    -2 | 3152 -> 3150 | in-presence |  200 | 160533 | Yellow Perch Goldrush        |
| 2026-09-19 14:00 | 09-19 11:24 | 09-19 20:28 |   3159 |        . | NO-SHOW    |     . |   -13 | 3150 -> 3137 | in-presence |  700 | 160534 | Big Headhunters              |
| 2026-09-19 16:00 | 09-19 11:24 | 09-19 20:28 |   3159 |        . | NO-SHOW    |     . |   -11 | 3122 -> 3111 | in-presence |  500 | 160535 | A Truly Unique Race!         |
| 2026-09-19 18:00 | 09-19 13:47 | 09-19 20:28 |   3152 |        . | NO-SHOW    |     . |   -15 | 3137 -> 3122 | in-presence | 1500 | 160536 | Gigante Pirañas              |
| 2026-09-19 20:00 | 09-19 13:48 | 09-19 22:00 |   3152 |     3111 | PLAYED     |     3 |    45 | 3111 -> 3156 | in-presence | 3500 | 160537 | Night Ruby Snapshot!         |
| 2026-09-19 22:00 | 09-19 13:48 | 09-20 00:00 |   3152 |     3156 | PLAYED     |     1 |    55 | 3156 -> 3211 | in-presence | 4000 | 160538 | No te haré daño, ¡Tiburón!   |
| 2026-09-20 06:00 | 09-20 00:09 | 09-20 08:00 |   3211 |     3211 | PLAYED     |    14 |    -1 | 3211 -> 3210 | in-presence |  800 | 160588 | Crank the river              |
| 2026-09-20 10:00 | 09-20 00:09 | 09-20 12:00 |   3211 |     3210 | PLAYED     |     7 |    25 | 3210 -> 3235 | in-presence | 3000 | 160590 | Trophy Carnivores Hunt!      |
| 2026-09-20 12:00 | 09-20 08:43 | 09-20 14:00 |   3210 |     3235 | PLAYED     |    21 |    -3 | 3235 -> 3232 | in-gap      |  200 | 160591 | Bass Challenge               |
| 2026-09-20 14:00 | 09-20 07:18 | 09-20 17:04 |   3211 |        . | NO-SHOW    |     . |   -10 | 3232 -> 3222 | in-gap      |  300 | 160592 | Emerald Predator Hunt        |
| 2026-09-20 16:00 | 09-20 12:56 | 09-20 18:00 |   3235 |        . | NO-SHOW    |     . |   -10 | 3222 -> 3212 | in-gap      |  200 | 160593 | Breaking Shad                |
| 2026-09-20 22:00 | 09-20 21:19 | .           |   3212 |     3212 | ZERO-SCORE |     . |    -8 |  not logged  | .           | 1500 | 160596 | (no reward line in log)      |

> **Spine is SQL, not the log** (week-20). Rows marked `(no reward line in log)` are
> participations SQL records and the ledger does not: the competition resolved but no
> `Tournament reward` line was ever written for it. 7 of 68 rows here. Their rating
> delta is real and is in the SQL column; the PCR chain simply skips them, so a chain read
> end-to-end will not reconcile with `CurrentPCR` by exactly those deltas.

Charge-window boundary: the first in-window entry is 2026-09-14T00:01:12Z at PCR 2874 before, the last is 2026-09-20T18:00:11Z at PCR 3212 after.

## Boundary behaviour

Brackets: NOOBS 0-100, MIDDLES 101-1000, TOPS 1001+. This section records what the rating series does near each bracket line and nothing else. An **approach from below** is a local maximum of the rating series whose value is at or below the line, that is a value the rating rises to and then leaves downward (or the last value in the span). For each approach the table gives what the very next ledger entry was and how long after. No threshold is applied and no conclusion is drawn here.

Observed rating range over the card span: 2601..3235 (bracket at span start TOPS, at span end TOPS).

### The 100/101 line

The rating never falls to or below the 100/101 line in the card span. The lowest it gets is 2601 at 2026-09-07T08:00:05Z, 2501 above 100, so there is no approach to this line from below and no crossing in either direction.

### The 1000/1001 line

The rating never falls to or below the 1000/1001 line in the card span. The lowest it gets is 2601 at 2026-09-07T08:00:05Z, 1601 above 1000, so there is no approach to this line from below and no crossing in either direction.

## MIDDLES to NOOBS crossings

A crossing is counted when pcr_before is 101 or more and pcr_after is 100 or less on a NO-SHOW or ZERO-SCORE entry, so 110 -> 100 counts and 100 -> 95 does not.

None. No ledger entry in the card span moves from 101 or above to 100 or below on a no-show or zero-score entry.

## Batched flushes and no-show streaks

Same-second clusters of two or more reward entries containing at least one NO-SHOW: **2** over the card span, **1** inside the charge window; largest cluster 3 entries.

| Timestamp | Entries | No-show | Zero-score | Played | Net Δ | Window |
|---|---|---|---|---|---|---|
| 2026-09-13T19:00:25Z | 2 | 1 | 1 | 0 | -18 | pre-window |
| 2026-09-19T20:28:20Z | 3 | 2 | 0 | 1 | -30 | charge |

Longest run of consecutive NO-SHOW ledger entries: **3 entries**, spanning 0.0 h, 2026-09-19T20:28:20Z .. 2026-09-19T20:28:21Z.

The run that covers the longest elapsed time is a different one: 2 entries over 2.0 h, 2026-09-14T18:00:08Z .. 2026-09-14T20:00:09Z.

## Presence

Gaps are intervals of two hours or more inside the card span with no log line of any type in `bdd6d57e-e41f-475e-b067-c0d990a5a92c-xfenrir77-presence.tsv` (5377 lines retained inside the span). The interval from the card-span start to the first logged line and from the last logged line to the card-span end are included and labelled.

**39 gaps, 211.5 h in total, 63.0% of the 336 h card span** (205.5 h interior, 6.0 h at the card-span edges).

Leading and trailing gaps against the card-span edges do **not** dominate the figure: they account for 6.0 h of the 211.5 h total, 2.9% of it; the remaining 205.5 h is interior silence.

| Gap | Hours | Kind |
|---|---|---|
| 2026-09-07T00:00:00Z -> 2026-09-07T06:02:17Z | 6.0 | leading |
| 2026-09-07T08:00:05Z -> 2026-09-07T16:09:01Z | 8.1 | interior |
| 2026-09-07T22:00:09Z -> 2026-09-08T08:54:47Z | 10.9 | interior |
| 2026-09-08T08:54:47Z -> 2026-09-08T19:21:46Z | 10.4 | interior |
| 2026-09-08T22:00:06Z -> 2026-09-09T12:32:56Z | 14.5 | interior |
| 2026-09-09T14:03:55Z -> 2026-09-09T16:25:06Z | 2.4 | interior |
| 2026-09-09T18:00:09Z -> 2026-09-10T00:51:31Z | 6.9 | interior |
| 2026-09-10T04:00:05Z -> 2026-09-10T07:26:07Z | 3.4 | interior |
| 2026-09-10T07:26:43Z -> 2026-09-10T10:00:02Z | 2.6 | interior |
| 2026-09-10T10:00:06Z -> 2026-09-10T13:22:07Z | 3.4 | interior |
| 2026-09-10T20:00:10Z -> 2026-09-11T11:38:32Z | 15.6 | interior |
| 2026-09-11T20:17:31Z -> 2026-09-12T01:35:15Z | 5.3 | interior |
| 2026-09-12T01:35:23Z -> 2026-09-12T07:13:11Z | 5.6 | interior |
| 2026-09-12T12:00:09Z -> 2026-09-12T18:20:05Z | 6.3 | interior |
| 2026-09-12T22:00:13Z -> 2026-09-13T03:25:05Z | 5.4 | interior |
| 2026-09-13T05:22:19Z -> 2026-09-13T08:00:02Z | 2.6 | interior |
| 2026-09-13T16:00:02Z -> 2026-09-13T18:00:02Z | 2.0 | interior |
| 2026-09-13T19:00:25Z -> 2026-09-13T22:42:55Z | 3.7 | interior |
| 2026-09-14T00:01:12Z -> 2026-09-14T06:04:19Z | 6.1 | interior |
| 2026-09-14T06:04:19Z -> 2026-09-14T10:00:02Z | 3.9 | interior |
| 2026-09-15T02:00:02Z -> 2026-09-15T07:11:09Z | 5.2 | interior |
| 2026-09-15T08:54:47Z -> 2026-09-15T16:01:59Z | 7.1 | interior |
| 2026-09-15T20:34:20Z -> 2026-09-16T06:16:46Z | 9.7 | interior |
| 2026-09-16T08:28:25Z -> 2026-09-16T16:32:16Z | 8.1 | interior |
| 2026-09-16T22:00:14Z -> 2026-09-17T02:12:24Z | 4.2 | interior |
| 2026-09-17T02:12:58Z -> 2026-09-17T10:00:02Z | 7.8 | interior |
| 2026-09-17T10:00:26Z -> 2026-09-17T12:52:46Z | 2.9 | interior |
| 2026-09-17T22:00:07Z -> 2026-09-18T04:48:36Z | 6.8 | interior |
| 2026-09-18T04:48:54Z -> 2026-09-18T08:01:29Z | 3.2 | interior |
| 2026-09-18T10:00:02Z -> 2026-09-18T12:06:14Z | 2.1 | interior |
| 2026-09-19T02:00:08Z -> 2026-09-19T05:23:44Z | 3.4 | interior |
| 2026-09-19T06:00:17Z -> 2026-09-19T11:24:06Z | 5.4 | interior |
| 2026-09-19T14:00:02Z -> 2026-09-19T16:00:02Z | 2.0 | interior |
| 2026-09-19T16:00:02Z -> 2026-09-19T18:00:02Z | 2.0 | interior |
| 2026-09-19T18:00:02Z -> 2026-09-19T20:00:02Z | 2.0 | interior |
| 2026-09-20T00:09:25Z -> 2026-09-20T06:46:07Z | 6.6 | interior |
| 2026-09-20T08:43:08Z -> 2026-09-20T10:56:23Z | 2.2 | interior |
| 2026-09-20T18:00:11Z -> 2026-09-20T21:19:15Z | 3.3 | interior |
| 2026-09-20T21:19:15Z -> 2026-09-20T23:33:23Z | 2.2 | interior |

### How the in-gap / in-presence column is derived

Every reward write is itself a logged line, so measured against the raw presence stream all 61 ledger entries would trivially read in-presence. The column therefore tests each timestamp against the **activity stream**: the presence stream with the server-side tournament-batch lines removed (`About to process tournament Competition #...` and `Tournament reward Competition #...`, 127 lines). On that stream there are 47 gaps of two hours or more totalling 227.6 h, 67.7% of the card span, and an entry reads in-gap when its own timestamp falls inside one of them, that is when the player produced no other log line of any kind for at least two hours around the moment the rating moved.

**The ledger timestamp is the moment the rating was applied, not the moment the competition ran.** Tournament results are processed in server-side batches after a competition closes, so in-presence does not by itself prove the player was online while the competition ran or that he chose to skip it, and in-gap does not prove he was away while it ran.

Unproductive entries (NO-SHOW plus ZERO-SCORE) by activity context: **9 in-gap, 13 in-presence** over the card span; 5 and 9 respectively inside the charge window.

| Timestamp | Comp ID | Status | PCR before -> after | Context | Window |
|---|---|---|---|---|---|
| 2026-09-08T22:00:06Z | 159975 | ZERO-SCORE | 2701 -> 2694 | in-gap | pre-window |
| 2026-09-10T10:00:06Z | 160069 | NO-SHOW | 2769 -> 2754 | in-gap | pre-window |
| 2026-09-10T16:00:05Z | 160072 | NO-SHOW | 2753 -> 2740 | in-presence | pre-window |
| 2026-09-11T20:00:10Z | 160117 | NO-SHOW | 2801 -> 2791 | in-presence | pre-window |
| 2026-09-13T08:00:05Z | 160217 | NO-SHOW | 2916 -> 2901 | in-presence | pre-window |
| 2026-09-13T14:00:08Z | 160220 | ZERO-SCORE | 2899 -> 2892 | in-presence | pre-window |
| 2026-09-13T19:00:25Z | 160221 | ZERO-SCORE | 2892 -> 2884 | in-gap | pre-window |
| 2026-09-13T19:00:25Z | 160222 | NO-SHOW | 2884 -> 2874 | in-gap | pre-window |
| 2026-09-14T11:30:46Z | 160272 | NO-SHOW | 2919 -> 2909 | in-presence | charge |
| 2026-09-14T18:00:08Z | 160276 | NO-SHOW | 2961 -> 2950 | in-gap | charge |
| 2026-09-14T20:00:09Z | 160277 | NO-SHOW | 2950 -> 2940 | in-presence | charge |
| 2026-09-16T20:00:08Z | 160347 | ZERO-SCORE | 3003 -> 2998 | in-presence | charge |
| 2026-09-17T10:00:05Z | 160387 | NO-SHOW | 2993 -> 2982 | in-presence | charge |
| 2026-09-17T22:00:07Z | 160393 | ZERO-SCORE | 3087 -> 3080 | in-gap | charge |
| 2026-09-18T16:00:06Z | 160445 | NO-SHOW | 3095 -> 3084 | in-presence | charge |
| 2026-09-19T02:00:08Z | 160450 | ZERO-SCORE | 3168 -> 3161 | in-gap | charge |
| 2026-09-19T12:00:06Z | 160532 | ZERO-SCORE | 3159 -> 3152 | in-presence | charge |
| 2026-09-19T20:28:20Z | 160534 | NO-SHOW | 3150 -> 3137 | in-presence | charge |
| 2026-09-19T20:28:20Z | 160536 | NO-SHOW | 3137 -> 3122 | in-presence | charge |
| 2026-09-19T20:28:21Z | 160535 | NO-SHOW | 3122 -> 3111 | in-presence | charge |
| 2026-09-20T17:04:05Z | 160592 | NO-SHOW | 3232 -> 3222 | in-gap | charge |
| 2026-09-20T18:00:11Z | 160593 | NO-SHOW | 3222 -> 3212 | in-gap | charge |

## Other log events

| Event | Card span | Charge window |
|---|---|---|
| `Player registered for Competition #` | 73 | 48 |
| `Player unregistered from Competition #` | 2 | 2 |
| failed registration attempts | 0 | 0 |
| `Player started scoring time for Competition #` | 52 | 31 |
| `CHEAT:` triggers | 1507 | 859 |

Failed registrations are counted separately and are never folded into the registration count.

### Cheat triggers by kind

Numeric payloads inside a trigger message are collapsed to `N` so variants of the same check group into one row.

| Trigger | Card span | Charge window |
|---|---|---|
| Fish catch distance is VERY long | 495 | 303 |
| Line has high extension too often | 231 | 173 |
| Line has critical extension too often | 167 | 119 |
| Throw.Same player position and rotation N times in row | 157 | 11 |
| Undriven boat moves TOO fast | 151 | 83 |
| Friction force is too high | 90 | 48 |
| Tackle is further than max cast length | 80 | 54 |
| Boat moves TOO fast | 41 | 21 |
| Fish catch distance is long | 36 | 18 |
| Attack time is VERY short | 31 | 15 |
| Tackle moves away from player too often | 12 | 6 |
| Attack time is short | 5 | 3 |
| Last N fish have low fighting/passive time ratio on a LONG distance Nm and reeling time: Ns | 3 | 1 |
| (slot N). Trying to leave location without processor reset | 3 | 0 |
| Fish goes to player too often when it should not | 3 | 3 |
| Stamina has grown or remain unchanged on rowing | 1 | 0 |
| Fish reeling time is VERY short when distance to fish is Nm | 1 | 1 |

## SQL cross-check, charge window 2026-09-14 .. 2026-09-20

| Measure | From log | From SQL | Verdict |
|---|---|---|---|
| Registrations | 48 | 41 | differs (+7) |
| Started, `Player started scoring time` lines | 31 | 31 | match |
| Played plus zero-score reward entries | 29 | 31 | differs (-2) |
| Zero-score | 4 | 4 | match |
| No-shows | 10 | 10 | match |
| Unproductive, no-show plus zero-score | 14 | 14 | match |
| Unproductive share of window entries, % | 35.9 | 34.15 | differs (+1.75) |
| Rating from unproductive | -138 | -138 | match |
| Rating from productive play | +476 | +476 | match |
| Net delta | +338 | +338 | match |
| PCR after last in-span entry vs CurrentPCR | 3212 | 3212 | match |
| Highest pcr_before in window vs MaxRatingAtStart | 3235 | 3235 | match |
| Highest pcr_before among PLAYED entries in window vs MaxRatingAtStart | 3235 | 3235 | match |

Registrations from the log count `Player registered for Competition #` lines timestamped inside the window; the SQL Reg column attributes a registration to the competition rather than to the moment the player pressed register, so the two need not agree at the window edges. Registrations are not part of the evidence_completeness test. The exact basis of the SQL MaxRatingAtStart column cannot be recovered from the log, so both candidate readings are shown and neither is part of the test.

SQL reference row: Reg 41, Started 31, ZeroScore 4, NoShows 10, Unproductive 14, Share 34.15%, RatingFromUnproductive -138, RatingFromProductivePlay +476, NetDelta +338, G/S/B 1/3/4, Total 8, Played N/M/T 0/0/31, Prizes N/M/T 0/0/8, CurrentPCR 3212, MaxRatingAtStart 3235, Lifetime G/S/B 27/25/27.

### evidence_completeness: ok

Rule: a row is flagged when the log and SQL differ by more than 20% of the SQL figure or by more than 5 absolute events, whichever is larger. Only no-shows, zero-score and their sum are in scope.

| In-scope measure | From log | From SQL | Difference | Tolerance | Flagged |
|---|---|---|---|---|---|
| Zero-score | 4 | 4 | +0 | 5.0 | no |
| No-shows | 10 | 10 | +0 | 5.0 | no |
| Unproductive, no-show plus zero-score | 14 | 14 | +0 | 5.0 | no |

Chain continuity: 61 reward entries, **0 breaks** - every entry's pcr_before equals the previous entry's pcr_after across the whole card span. No rating-changing reward line is missing from the retained log between the first and the last entry, so any shortfall against SQL comes from penalties absorbed at the rating floor (which write no line at all) or from window attribution, not from lost log lines.

- No in-scope row exceeds the tolerance.

