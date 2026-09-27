---
uid: 6b94e751-0d2f-40b0-81ea-fb7c9da0fd14
username: Iron.Claw
platform: Steam
card_span: 2026-09-07T00:00:00Z .. 2026-09-20T23:59:59Z
charge_window: 2026-09-14 .. 2026-09-20
pcr_at_start: 'not logged (the first ledger line, 2026-09-08T08:21:05Z comp #331742, prints an empty before-value; its pcr_after is 30)'
pcr_at_end: 54
pcr_range: 26..142
max_pcr_in_window: 142
net_delta: +54 card span; -28 charge window
registrations: 50 card span; 37 charge window
played: 24 card span; 14 charge window
zero_score: 0 card span; 0 charge window
no_shows: 22 card span; 21 charge window
middles_to_noobs_drops: 5 (no-show 5, zero-score 0); 5 inside charge window
middles_to_noobs_drop_dates:
  - 2026-09-14T23:47:10Z 109->98 NO-SHOW
  - 2026-09-15T12:00:05Z 102->89 NO-SHOW
  - 2026-09-15T20:03:14Z 106->86 NO-SHOW
  - 2026-09-17T09:47:37Z 102->87 NO-SHOW
  - 2026-09-20T10:00:07Z 105->95 NO-SHOW
boundary_behaviour: '100/101 line: closest approach from below 69 (31 short) at 2026-09-18T22:01:18Z (charge window); next entry NO-SHOW, 2.0 h later, to 49; 4 approaches in the charge window, 3 shed on the next entry; 6 downward and 6 upward crossings. 1000/1001 line: never reached, span maximum 142, 859 short of 1001.'
batched_flush_groups: 4 card span; 4 charge window; largest cluster 3 entries
longest_no_show_streak_hours: 6.0 (run of 4, 2026-09-20T10:00:07Z .. 2026-09-20T16:00:11Z)
presence_gaps: 38 gaps of 2h or more; 240.8 h = 71.7% of the 336 h card span
cheat_triggers: 108 card span; 78 charge window
evidence_completeness: ok
notable:
  - 'charge-window ledger: 35 entries - 14 played, 0 zero-score, 21 no-show'
  - 'charge-window rating split: -323 from unproductive entries, +295 from productive play, net -28'
  - '100/101 boundary: rating reached 69 (31 short of 101) at 2026-09-18T22:01:18Z, next entry NO-SHOW 2.0 h later, down to 49'
  - '100/101 boundary: 4 approaches from below inside the charge window, 3 of them followed straight away by an unproductive entry'
  - 'largest same-second flush in window: 3 entries at 2026-09-15T20:03:14Z, 2 of them no-show'
  - 'MIDDLES to NOOBS: 5 unproductive crossings over the card span, 5 of them in the charge window'
  - 'most frequent cheat triggers: Line has high extension too often x71; Friction force is too high x11; Undriven boat moves TOO fast x10'
  - 'longest silence 2026-09-15T20:03:14Z to 2026-09-16T22:02:17Z, 26.0 h (interior)'
---

# Iron.Claw - PCR trajectory card

Iron.Claw, Steam. Card span 2026-09-07T00:00:00Z .. 2026-09-20T23:59:59Z, the full retention of the source log collection. The charge window is 2026-09-14 .. 2026-09-20; everything dated before 2026-09-14 on this card is pre-context and is not part of the charge.

## Ledger

46 reward entries over the card span, 35 of them inside the charge window. Status comes from the participation record in the database, not from the log: NO-SHOW where the player never entered, ZERO-SCORE where he entered and finished without a score, PLAYED otherwise. The log supplies the registration time, the presence marks and the PCR chain, and rows it does not carry are marked in the ledger.

| Comp start       | Registered  | Applied     | RegPCR | StartPCR | Status  | Place | Delta | PCR chain  | Presence    |  Fee | ID     | Competition                            |
|------------------|-------------|-------------|-------:|---------:|---------|------:|------:|:----------:|-------------|-----:|--------|----------------------------------------|
| 2026-09-07 12:00 | 09-07 09:41 | .           |      . |        . | PLAYED  |    12 |     0 | not logged | .           | 2500 | 331654 | (no reward line in log)                |
| 2026-09-08 06:00 | 09-08 05:18 | 09-08 08:21 |      . |        . | PLAYED  |     1 |    30 |   -> 30    | in-gap      |  300 | 331742 | Trout Hunter                           |
| 2026-09-09 10:00 | 09-09 06:37 | 09-09 13:31 |     30 |       30 | PLAYED  |     6 |    14 |  30 -> 44  | in-gap      |  300 | 331823 | Falcon Trout Chase                     |
| 2026-09-09 16:00 | 09-09 15:41 | 09-09 18:00 |     44 |       44 | PLAYED  |    17 |    -3 |  44 -> 41  | in-presence |  500 | 331826 | Midnight Salmon Galore                 |
| 2026-09-10 10:00 | 09-10 09:35 | 09-10 12:00 |     41 |       41 | PLAYED  |     1 |    55 |  41 -> 96  | in-presence | 2500 | 331906 | No Ruler - No Party                    |
| 2026-09-10 14:00 | 09-10 12:56 | 09-10 16:00 |     96 |       96 | PLAYED  |    22 |    -3 |  96 -> 93  | in-presence |  300 | 331908 | One by One                             |
| 2026-09-10 16:00 | 09-10 14:33 | 09-10 19:54 |     96 |       93 | PLAYED  |     6 |    14 | 93 -> 107  | in-presence |  300 | 331909 | Trout Hunter                           |
| 2026-09-10 20:00 | 09-10 19:55 | 09-10 22:00 |    107 |      107 | PLAYED  |    19 |    -3 | 107 -> 104 | in-presence |  300 | 331911 | Emerald Predator Hunt                  |
| 2026-09-11 06:00 | 09-10 23:11 | 09-11 08:00 |    104 |      104 | PLAYED  |    24 |    -3 | 104 -> 101 | in-gap      |  200 | 331978 | Bass Challenge                         |
| 2026-09-11 10:00 | 09-10 23:13 | 09-11 15:21 |    104 |      101 | PLAYED  |    30 |    -5 | 101 -> 96  | in-gap      |  500 | 331980 | Salmon Clash                           |
| 2026-09-11 20:00 | 09-11 19:47 | 09-11 22:00 |     96 |       96 | PLAYED  |    40 |    -3 |  96 -> 93  | in-gap      |  200 | 331985 | School Bass                            |
| 2026-09-13 00:00 | 09-12 21:30 | 09-13 02:39 |     93 |        . | NO-SHOW |     . |   -11 |  93 -> 82  | in-gap      |  500 | 332175 | Sturgeon in the Dark                   |
| 2026-09-14 00:00 | 09-13 22:38 | 09-14 02:00 |     82 |       82 | PLAYED  |     2 |    50 | 82 -> 132  | in-gap      | 2500 | 332244 | Tigers Trail                           |
| 2026-09-14 02:00 | 09-14 01:41 | 09-14 04:50 |     82 |        . | NO-SHOW |     . |   -20 | 132 -> 112 | in-gap      | 3500 | 332245 | All Fish, All In!                      |
| 2026-09-14 10:00 | 09-14 09:42 | 09-14 13:16 |    112 |      112 | PLAYED  |     8 |    12 | 112 -> 124 | in-presence |  500 | 332249 | The Battle of Kaniq                    |
| 2026-09-14 16:00 | 09-14 13:17 | 09-14 18:00 |    124 |        . | NO-SHOW |     . |   -15 | 124 -> 109 | in-presence |  900 | 332252 | Grass Сutter Range                     |
| 2026-09-14 20:00 | 09-14 18:32 | 09-14 23:47 |    109 |        . | NO-SHOW |     . |   -11 | 109 -> 98  | in-presence |  500 | 332254 | Dancing with Pike                      |
| 2026-09-15 00:00 | 09-14 23:48 | 09-15 02:00 |     98 |        . | NO-SHOW |     . |   -11 |  98 -> 87  | in-presence |  300 | 332303 | Big Red Fish                           |
| 2026-09-15 02:00 | 09-15 00:17 | 09-15 04:03 |     98 |       87 | PLAYED  |     1 |    55 | 87 -> 142  | in-gap      | 2500 | 332304 | One Short and One Long                 |
| 2026-09-15 04:00 | 09-15 01:41 | 09-15 08:09 |     98 |        . | NO-SHOW |     . |   -20 | 122 -> 102 | in-presence | 3500 | 332305 | Night Ruby Snapshot!                   |
| 2026-09-15 06:00 | 09-15 03:44 | 09-15 08:09 |     87 |        . | NO-SHOW |     . |   -20 | 142 -> 122 | in-presence | 4000 | 332306 | Norway Outstanding Minnies!            |
| 2026-09-15 10:00 | 09-15 08:30 | 09-15 12:00 |    102 |        . | NO-SHOW |     . |   -13 | 102 -> 89  | in-presence |  800 | 332308 | Siberian Khan                          |
| 2026-09-15 14:00 | 09-15 13:24 | 09-15 20:03 |     89 |       89 | PLAYED  |     5 |    17 | 89 -> 106  | in-gap      |  300 | 332310 | Falcon Trout Chase                     |
| 2026-09-15 16:00 | 09-15 13:24 | 09-15 20:03 |     89 |        . | NO-SHOW |     . |   -10 |  86 -> 76  | in-gap      |  300 | 332311 | Fly like a Butterfly, Swim like a Bass |
| 2026-09-15 18:00 | 09-15 14:51 | 09-15 20:03 |     89 |        . | NO-SHOW |     . |   -20 | 106 -> 86  | in-gap      | 2000 | 332312 | Topwater Victory                       |
| 2026-09-17 00:00 | 09-16 22:02 | 09-17 02:00 |     76 |       76 | PLAYED  |     5 |    17 |  76 -> 93  | in-presence |  300 | 332465 | Ideal Accuracy                         |
| 2026-09-17 02:00 | 09-17 01:51 | 09-17 04:21 |     76 |       93 | PLAYED  |     4 |    20 | 93 -> 113  | in-gap      |  300 | 332466 | Best Five Bass                         |
| 2026-09-17 04:00 | 09-17 02:50 | 09-17 09:47 |     93 |        . | NO-SHOW |     . |   -11 | 113 -> 102 | in-gap      |  500 | 332467 | Triple the Trout!                      |
| 2026-09-17 06:00 | 09-17 02:50 | 09-17 09:47 |     93 |        . | NO-SHOW |     . |   -15 | 102 -> 87  | in-gap      |  900 | 332468 | Jolly Carp                             |
| 2026-09-17 12:00 | 09-17 02:51 | 09-17 15:22 |     93 |        . | NO-SHOW |     . |   -20 |  87 -> 67  | in-presence | 2500 | 332471 | Tigers Trail                           |
| 2026-09-17 16:00 | 09-17 15:24 | 09-17 18:00 |     67 |       67 | PLAYED  |    17 |    -2 |  67 -> 65  | in-presence |  200 | 332473 | Breaking Shad                          |
| 2026-09-17 18:00 | 09-17 15:38 | 09-17 21:29 |     67 |       65 | PLAYED  |    22 |    -4 |  65 -> 61  | in-gap      |  500 | 332474 | Muskie Topping                         |
| 2026-09-17 22:00 | 09-17 16:16 | 09-18 00:52 |     67 |        . | NO-SHOW |     . |   -20 |  61 -> 41  | in-presence | 3500 | 332476 | All Fish, All In!                      |
| 2026-09-18 04:00 | 09-18 03:48 | 09-18 06:00 |     41 |        . | NO-SHOW |     . |   -15 |  41 -> 26  | in-gap      | 1200 | 332564 | Bloody Threat                          |
| 2026-09-18 08:00 | 09-18 00:58 | 09-18 10:00 |     41 |       26 | PLAYED  |     4 |    20 |  26 -> 46  | in-presence |  300 | 332566 | Falcon Trout Chase                     |
| 2026-09-18 14:00 | 09-18 10:46 | 09-18 16:13 |     46 |        . | NO-SHOW |     . |   -20 |  46 -> 26  | in-presence | 2000 | 332569 | Topwater Victory                       |
| 2026-09-18 16:00 | 09-18 10:46 | 09-18 18:00 |     46 |       26 | PLAYED  |     6 |    22 |  26 -> 48  | in-presence | 2500 | 332570 | Labeo Twins                            |
| 2026-09-18 18:00 | 09-18 10:47 | 09-18 20:00 |     46 |       48 | PLAYED  |    15 |    -1 |  48 -> 47  | in-presence |  200 | 332571 | Neherrin Minimal                       |
| 2026-09-18 20:00 | 09-18 17:48 | 09-18 22:01 |     26 |       47 | PLAYED  |     2 |    22 |  47 -> 69  | in-presence |  200 | 332572 | Big Bowfin Hunting                     |
| 2026-09-18 22:00 | 09-18 20:51 | 09-19 00:01 |     47 |        . | NO-SHOW |     . |   -20 |  69 -> 49  | in-presence | 3500 | 332573 | Night Ruby Snapshot!                   |
| 2026-09-19 00:00 | 09-18 17:02 | 09-19 07:00 |     26 |       49 | PLAYED  |     5 |    17 |  49 -> 66  | in-gap      |  200 | 332650 | Bass Challenge                         |
| 2026-09-19 02:00 | 09-19 01:02 | 09-19 07:00 |     49 |        . | NO-SHOW |     . |   -11 |  66 -> 55  | in-gap      |  500 | 332651 | Catfish Trial                          |
| 2026-09-19 20:00 | 09-19 08:09 | .           |     55 |       55 | PLAYED  |    13 |     0 | not logged | .           |  300 | 332660 | (no reward line in log)                |
| 2026-09-20 04:00 | 09-19 21:35 | 09-20 06:19 |     55 |       55 | PLAYED  |     2 |    50 | 55 -> 105  | in-presence | 2500 | 332750 | One Short and One Long                 |
| 2026-09-20 08:00 | 09-19 23:01 | 09-20 10:00 |     55 |        . | NO-SHOW |     . |   -10 | 105 -> 95  | in-gap      |  300 | 332752 | Fly like a Butterfly, Swim like a Bass |
| 2026-09-20 10:00 | 09-20 06:22 | 09-20 15:41 |    105 |        . | NO-SHOW |     . |   -15 |  95 -> 80  | in-gap      | 1200 | 332753 | Maku-Maku Carnivores                   |
| 2026-09-20 12:00 | 09-20 06:22 | 09-20 15:41 |    105 |        . | NO-SHOW |     . |   -13 |  80 -> 67  | in-gap      |  700 | 332754 | Danger in the grass                    |
| 2026-09-20 14:00 | 09-20 06:22 | 09-20 16:00 |    105 |        . | NO-SHOW |     . |   -13 |  67 -> 54  | in-gap      |  500 | 332755 | Salmon Clash                           |

> **Spine is SQL, not the log** (week-20). Rows marked `(no reward line in log)` are
> participations SQL records and the ledger does not: the competition resolved but no
> `Tournament reward` line was ever written for it. 2 of 48 rows here. Their rating
> delta is real and is in the SQL column; the PCR chain simply skips them, so a chain read
> end-to-end will not reconcile with `CurrentPCR` by exactly those deltas.


The before-value of the 2026-09-08T08:21:05Z entry (comp #331742) is printed empty in the source line (`added CompetitionRating +30 ( -> 30)`). It is left blank here and excluded from every before-based derivation; no value is inferred for it.

Charge-window boundary: the first in-window entry is 2026-09-14T02:00:08Z at PCR 82 before, the last is 2026-09-20T16:00:11Z at PCR 54 after.

## Boundary behaviour

Brackets: NOOBS 0-100, MIDDLES 101-1000, TOPS 1001+. This section records what the rating series does near each bracket line and nothing else. An **approach from below** is a local maximum of the rating series whose value is at or below the line, that is a value the rating rises to and then leaves downward (or the last value in the span). For each approach the table gives what the very next ledger entry was and how long after. No threshold is applied and no conclusion is drawn here.

Observed rating range over the card span: 26..142 (bracket at span start unknown, at span end NOOBS).

### The 100/101 line

**Closest approach from below over the card span:** 96, 4 short of 101, at 2026-09-10T12:00:07Z (comp #331906, PLAYED +55).
The next ledger entry is 4.0 h later: PLAYED, -3, to 93.

**Closest approach from below inside the charge window:** 69, 31 short of 101, at 2026-09-18T22:01:18Z (comp #332572, PLAYED +22).
The next ledger entry is 2.0 h later: NO-SHOW, -20, to 49.

Every approach from below, card span. "Next entry" is the immediately following ledger entry; "next unproductive" is the first following NO-SHOW or ZERO-SCORE entry, which may be the same one.

| Peak | Short of 101 | Reached at | Window | Next entry | PCR after it | Next unproductive | PCR after it |
|---|---|---|---|---|---|---|---|
| 44 | 56 | 2026-09-09T13:31:09Z | pre-window | PLAYED -3, 4.5 h | 41 | NO-SHOW, 85.1 h | 82 |
| 96 | 4 | 2026-09-10T12:00:07Z | pre-window | PLAYED -3, 4.0 h | 93 | NO-SHOW, 62.7 h | 82 |
| 46 | 54 | 2026-09-18T10:00:13Z | charge | NO-SHOW -20, 6.2 h | 26 | NO-SHOW, 6.2 h | 26 |
| 48 | 52 | 2026-09-18T18:00:10Z | charge | PLAYED -1, 2.0 h | 47 | NO-SHOW, 6.0 h | 49 |
| 69 | 31 | 2026-09-18T22:01:18Z | charge | NO-SHOW -20, 2.0 h | 49 | NO-SHOW, 2.0 h | 49 |
| 66 | 34 | 2026-09-19T07:00:47Z | charge | NO-SHOW -11, 0.0 h | 55 | NO-SHOW, 0.0 h | 55 |

Repeats of the up-then-shed shape inside the charge window: **3 of the 4 in-window approaches are followed immediately by an unproductive entry** (6 approaches and 3 such repeats over the whole card span).

Crossings of the line: **6 downward** (pcr_before at or above 101, pcr_after at or below 100) and **6 upward** over the card span.

| Direction | Timestamp | Comp ID | Status | Δ | PCR before -> after | Window |
|---|---|---|---|---|---|---|
| up | 2026-09-10T19:54:33Z | 331909 | PLAYED | +14 | 93 -> 107 | pre-window |
| down | 2026-09-11T15:21:22Z | 331980 | PLAYED | -5 | 101 -> 96 | pre-window |
| up | 2026-09-14T02:00:08Z | 332244 | PLAYED | +50 | 82 -> 132 | charge |
| down | 2026-09-14T23:47:10Z | 332254 | NO-SHOW | -11 | 109 -> 98 | charge |
| up | 2026-09-15T04:03:26Z | 332304 | PLAYED | +55 | 87 -> 142 | charge |
| down | 2026-09-15T12:00:05Z | 332308 | NO-SHOW | -13 | 102 -> 89 | charge |
| down | 2026-09-15T20:03:14Z | 332312 | NO-SHOW | -20 | 106 -> 86 | charge |
| up | 2026-09-15T20:03:14Z | 332310 | PLAYED | +17 | 89 -> 106 | charge |
| up | 2026-09-17T04:21:28Z | 332466 | PLAYED | +20 | 93 -> 113 | charge |
| down | 2026-09-17T09:47:37Z | 332468 | NO-SHOW | -15 | 102 -> 87 | charge |
| up | 2026-09-20T06:19:27Z | 332750 | PLAYED | +50 | 55 -> 105 | charge |
| down | 2026-09-20T10:00:07Z | 332752 | NO-SHOW | -10 | 105 -> 95 | charge |

### The 1000/1001 line

The rating never reaches the 1000/1001 line in the card span. The highest it gets is 142 at 2026-09-15T04:03:26Z, 859 short of 1001, so there is no approach to this line to describe and no crossing in either direction.

## MIDDLES to NOOBS crossings

A crossing is counted when pcr_before is 101 or more and pcr_after is 100 or less on a NO-SHOW or ZERO-SCORE entry, so 110 -> 100 counts and 100 -> 95 does not.

**5 over the card span** (no-show 5, zero-score 0), **5 of them inside the charge window**.

| Date | Timestamp | Comp ID | Comp name | Status | Δ | PCR before -> after | Window |
|---|---|---|---|---|---|---|---|
| 2026-09-14 | 2026-09-14T23:47:10Z | 332254 | Dancing with Pike | NO-SHOW | -11 | 109 -> 98 | charge |
| 2026-09-15 | 2026-09-15T12:00:05Z | 332308 | Siberian Khan | NO-SHOW | -13 | 102 -> 89 | charge |
| 2026-09-15 | 2026-09-15T20:03:14Z | 332312 | Topwater Victory | NO-SHOW | -20 | 106 -> 86 | charge |
| 2026-09-17 | 2026-09-17T09:47:37Z | 332468 | Jolly Carp | NO-SHOW | -15 | 102 -> 87 | charge |
| 2026-09-20 | 2026-09-20T10:00:07Z | 332752 | Fly like a Butterfly, Swim like a Bass | NO-SHOW | -10 | 105 -> 95 | charge |

## Batched flushes and no-show streaks

Same-second clusters of two or more reward entries containing at least one NO-SHOW: **4** over the card span, **4** inside the charge window; largest cluster 3 entries.

| Timestamp | Entries | No-show | Zero-score | Played | Net Δ | Window |
|---|---|---|---|---|---|---|
| 2026-09-15T08:09:11Z | 2 | 2 | 0 | 0 | -40 | charge |
| 2026-09-15T20:03:14Z | 3 | 2 | 0 | 1 | -13 | charge |
| 2026-09-17T09:47:37Z | 2 | 2 | 0 | 0 | -26 | charge |
| 2026-09-20T15:41:02Z | 2 | 2 | 0 | 0 | -28 | charge |

Longest run of consecutive NO-SHOW ledger entries: **4 entries**, spanning 6.0 h, 2026-09-20T10:00:07Z .. 2026-09-20T16:00:11Z.

The run that covers the longest elapsed time is a different one: 3 entries over 8.0 h, 2026-09-14T18:00:13Z .. 2026-09-15T02:00:09Z.

## Presence

Gaps are intervals of two hours or more inside the card span with no log line of any type in `6b94e751-0d2f-40b0-81ea-fb7c9da0fd14-iron-claw-presence.tsv` (3122 lines retained inside the span). The interval from the card-span start to the first logged line and from the last logged line to the card-span end are included and labelled.

**38 gaps, 240.8 h in total, 71.7% of the 336 h card span** (231.1 h interior, 9.7 h at the card-span edges).

Leading and trailing gaps against the card-span edges do **not** dominate the figure: they account for 9.7 h of the 240.8 h total, 4.0% of it; the remaining 231.1 h is interior silence.

| Gap | Hours | Kind |
|---|---|---|
| 2026-09-07T00:00:00Z -> 2026-09-07T09:41:05Z | 9.7 | leading |
| 2026-09-07T09:41:05Z -> 2026-09-07T12:05:05Z | 2.4 | interior |
| 2026-09-07T14:00:12Z -> 2026-09-08T05:18:07Z | 15.3 | interior |
| 2026-09-08T08:21:05Z -> 2026-09-09T06:37:42Z | 22.3 | interior |
| 2026-09-09T06:37:42Z -> 2026-09-09T10:00:42Z | 3.4 | interior |
| 2026-09-09T13:31:09Z -> 2026-09-09T15:41:22Z | 2.2 | interior |
| 2026-09-09T18:37:51Z -> 2026-09-10T09:35:13Z | 15.0 | interior |
| 2026-09-10T23:13:33Z -> 2026-09-11T06:01:40Z | 6.8 | interior |
| 2026-09-11T08:00:18Z -> 2026-09-11T10:26:11Z | 2.4 | interior |
| 2026-09-11T12:00:02Z -> 2026-09-11T15:21:22Z | 3.4 | interior |
| 2026-09-11T15:21:22Z -> 2026-09-11T19:47:18Z | 4.4 | interior |
| 2026-09-11T22:00:32Z -> 2026-09-12T21:30:48Z | 23.5 | interior |
| 2026-09-12T21:30:48Z -> 2026-09-13T02:00:02Z | 4.5 | interior |
| 2026-09-13T02:39:10Z -> 2026-09-13T22:38:06Z | 20.0 | interior |
| 2026-09-14T04:50:48Z -> 2026-09-14T09:42:43Z | 4.9 | interior |
| 2026-09-14T13:17:25Z -> 2026-09-14T18:00:02Z | 4.7 | interior |
| 2026-09-14T18:32:56Z -> 2026-09-14T22:00:02Z | 3.5 | interior |
| 2026-09-15T06:00:02Z -> 2026-09-15T08:00:02Z | 2.0 | interior |
| 2026-09-15T08:30:31Z -> 2026-09-15T12:00:02Z | 3.5 | interior |
| 2026-09-15T16:00:02Z -> 2026-09-15T18:00:02Z | 2.0 | interior |
| 2026-09-15T18:00:02Z -> 2026-09-15T20:00:02Z | 2.0 | interior |
| 2026-09-15T20:03:14Z -> 2026-09-16T22:02:17Z | 26.0 | interior |
| 2026-09-16T22:02:17Z -> 2026-09-17T00:04:39Z | 2.0 | interior |
| 2026-09-17T06:00:02Z -> 2026-09-17T08:00:02Z | 2.0 | interior |
| 2026-09-17T09:47:37Z -> 2026-09-17T14:00:02Z | 4.2 | interior |
| 2026-09-17T21:29:41Z -> 2026-09-18T00:00:02Z | 2.5 | interior |
| 2026-09-18T00:58:09Z -> 2026-09-18T03:48:58Z | 2.8 | interior |
| 2026-09-18T03:48:58Z -> 2026-09-18T06:00:02Z | 2.2 | interior |
| 2026-09-18T06:00:05Z -> 2026-09-18T08:22:07Z | 2.4 | interior |
| 2026-09-18T10:47:11Z -> 2026-09-18T16:00:02Z | 5.2 | interior |
| 2026-09-19T02:00:02Z -> 2026-09-19T04:00:02Z | 2.0 | interior |
| 2026-09-19T04:00:02Z -> 2026-09-19T07:00:47Z | 3.0 | interior |
| 2026-09-19T08:09:55Z -> 2026-09-19T11:59:27Z | 3.8 | interior |
| 2026-09-19T12:30:07Z -> 2026-09-19T21:03:20Z | 8.6 | interior |
| 2026-09-19T23:01:34Z -> 2026-09-20T04:01:56Z | 5.0 | interior |
| 2026-09-20T06:22:51Z -> 2026-09-20T10:00:02Z | 3.6 | interior |
| 2026-09-20T12:00:02Z -> 2026-09-20T14:00:02Z | 2.0 | interior |
| 2026-09-20T16:00:11Z -> 2026-09-20T21:47:11Z | 5.8 | interior |

### How the in-gap / in-presence column is derived

Every reward write is itself a logged line, so measured against the raw presence stream all 46 ledger entries would trivially read in-presence. The column therefore tests each timestamp against the **activity stream**: the presence stream with the server-side tournament-batch lines removed (`About to process tournament Competition #...` and `Tournament reward Competition #...`, 94 lines). On that stream there are 42 gaps of two hours or more totalling 258.7 h, 77.0% of the card span, and an entry reads in-gap when its own timestamp falls inside one of them, that is when the player produced no other log line of any kind for at least two hours around the moment the rating moved.

**The ledger timestamp is the moment the rating was applied, not the moment the competition ran.** Tournament results are processed in server-side batches after a competition closes, so in-presence does not by itself prove the player was online while the competition ran or that he chose to skip it, and in-gap does not prove he was away while it ran.

Unproductive entries (NO-SHOW plus ZERO-SCORE) by activity context: **12 in-gap, 10 in-presence** over the card span; 11 and 10 respectively inside the charge window.

| Timestamp | Comp ID | Status | PCR before -> after | Context | Window |
|---|---|---|---|---|---|
| 2026-09-13T02:39:10Z | 332175 | NO-SHOW | 93 -> 82 | in-gap | pre-window |
| 2026-09-14T04:50:48Z | 332245 | NO-SHOW | 132 -> 112 | in-gap | charge |
| 2026-09-14T18:00:13Z | 332252 | NO-SHOW | 124 -> 109 | in-presence | charge |
| 2026-09-14T23:47:10Z | 332254 | NO-SHOW | 109 -> 98 | in-presence | charge |
| 2026-09-15T02:00:09Z | 332303 | NO-SHOW | 98 -> 87 | in-presence | charge |
| 2026-09-15T08:09:11Z | 332306 | NO-SHOW | 142 -> 122 | in-presence | charge |
| 2026-09-15T08:09:11Z | 332305 | NO-SHOW | 122 -> 102 | in-presence | charge |
| 2026-09-15T12:00:05Z | 332308 | NO-SHOW | 102 -> 89 | in-presence | charge |
| 2026-09-15T20:03:14Z | 332312 | NO-SHOW | 106 -> 86 | in-gap | charge |
| 2026-09-15T20:03:14Z | 332311 | NO-SHOW | 86 -> 76 | in-gap | charge |
| 2026-09-17T09:47:37Z | 332467 | NO-SHOW | 113 -> 102 | in-gap | charge |
| 2026-09-17T09:47:37Z | 332468 | NO-SHOW | 102 -> 87 | in-gap | charge |
| 2026-09-17T15:22:21Z | 332471 | NO-SHOW | 87 -> 67 | in-presence | charge |
| 2026-09-18T00:52:04Z | 332476 | NO-SHOW | 61 -> 41 | in-presence | charge |
| 2026-09-18T06:00:05Z | 332564 | NO-SHOW | 41 -> 26 | in-gap | charge |
| 2026-09-18T16:13:46Z | 332569 | NO-SHOW | 46 -> 26 | in-presence | charge |
| 2026-09-19T00:01:43Z | 332573 | NO-SHOW | 69 -> 49 | in-presence | charge |
| 2026-09-19T07:00:48Z | 332651 | NO-SHOW | 66 -> 55 | in-gap | charge |
| 2026-09-20T10:00:07Z | 332752 | NO-SHOW | 105 -> 95 | in-gap | charge |
| 2026-09-20T15:41:02Z | 332753 | NO-SHOW | 95 -> 80 | in-gap | charge |
| 2026-09-20T15:41:02Z | 332754 | NO-SHOW | 80 -> 67 | in-gap | charge |
| 2026-09-20T16:00:11Z | 332755 | NO-SHOW | 67 -> 54 | in-gap | charge |

## Other log events

| Event | Card span | Charge window |
|---|---|---|
| `Player registered for Competition #` | 50 | 37 |
| `Player unregistered from Competition #` | 0 | 0 |
| failed registration attempts | 0 | 0 |
| `Player started scoring time for Competition #` | 26 | 15 |
| `CHEAT:` triggers | 108 | 78 |

Failed registrations are counted separately and are never folded into the registration count.

### Cheat triggers by kind

Numeric payloads inside a trigger message are collapsed to `N` so variants of the same check group into one row.

| Trigger | Card span | Charge window |
|---|---|---|
| Line has high extension too often | 71 | 44 |
| Friction force is too high | 11 | 9 |
| Undriven boat moves TOO fast | 10 | 10 |
| Fish catch distance is long | 7 | 6 |
| Fish catch distance is VERY long | 4 | 4 |
| Fish goes to player too often | 3 | 3 |
| Boat updates time is incorrect | 1 | 1 |
| Line has critical extension too often | 1 | 1 |

## SQL cross-check, charge window 2026-09-14 .. 2026-09-20

| Measure | From log | From SQL | Verdict |
|---|---|---|---|
| Registrations | 37 | 36 | differs (+1) |
| Started, `Player started scoring time` lines | 15 | 15 | match |
| Played plus zero-score reward entries | 14 | 15 | differs (-1) |
| Zero-score | 0 | 0 | match |
| No-shows | 21 | 21 | match |
| Unproductive, no-show plus zero-score | 21 | 21 | match |
| Unproductive share of window entries, % | 60.0 | 58.33 | differs (+1.67) |
| Rating from unproductive | -323 | -323 | match |
| Rating from productive play | +295 | +295 | match |
| Net delta | -28 | -28 | match |
| PCR after last in-span entry vs CurrentPCR | 54 | 54 | match |
| Highest pcr_before in window vs MaxRatingAtStart | 142 | 112 | differs (+30) |
| Highest pcr_before among PLAYED entries in window vs MaxRatingAtStart | 112 | 112 | match |

Registrations from the log count `Player registered for Competition #` lines timestamped inside the window; the SQL Reg column attributes a registration to the competition rather than to the moment the player pressed register, so the two need not agree at the window edges. Registrations are not part of the evidence_completeness test. The exact basis of the SQL MaxRatingAtStart column cannot be recovered from the log, so both candidate readings are shown and neither is part of the test.

SQL reference row: Reg 36, Started 15, ZeroScore 0, NoShows 21, Unproductive 21, Share 58.33%, RatingFromUnproductive -323, RatingFromProductivePlay +295, NetDelta -28, G/S/B 1/3/0, Total 4, Played N/M/T 14/1/0, Prizes N/M/T 4/0/0, CurrentPCR 54, MaxRatingAtStart 112, Lifetime G/S/B 3/3/-.

### evidence_completeness: ok

Rule: a row is flagged when the log and SQL differ by more than 20% of the SQL figure or by more than 5 absolute events, whichever is larger. Only no-shows, zero-score and their sum are in scope.

| In-scope measure | From log | From SQL | Difference | Tolerance | Flagged |
|---|---|---|---|---|---|
| Zero-score | 0 | 0 | +0 | 5.0 | no |
| No-shows | 21 | 21 | +0 | 5.0 | no |
| Unproductive, no-show plus zero-score | 21 | 21 | +0 | 5.0 | no |

Chain continuity: 46 reward entries, **0 breaks** - every entry's pcr_before equals the previous entry's pcr_after across the whole card span. No rating-changing reward line is missing from the retained log between the first and the last entry, so any shortfall against SQL comes from penalties absorbed at the rating floor (which write no line at all) or from window attribution, not from lost log lines.

- No in-scope row exceeds the tolerance.

