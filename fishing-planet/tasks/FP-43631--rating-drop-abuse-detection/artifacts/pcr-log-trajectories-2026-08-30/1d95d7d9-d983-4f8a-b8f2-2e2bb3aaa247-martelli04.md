# Trajectory card - martelli04 (PlayStation)

- **UserId:** `1d95d7d9-d983-4f8a-b8f2-2e2bb3aaa247`
- **Source:** `1d95d7d9-d983-4f8a-b8f2-2e2bb3aaa247-martelli04.tsv` (142 lines)
- **Window:** 2026-08-10 -> 2026-08-30 (first event actually present: 2026-08-17T18:28:17Z - the first week is not in the dump)
- **Sweep week:** 2026-08-24 -> 2026-08-30

## Headline

| Metric | Value |
| --- | --- |
| PCR at start (first ledger `before`) | 41 |
| PCR at end (last ledger `after`) | 124 |
| PCR min / max | 23 / 144 |
| Ledger entries (rewards) | 26 |
| Process markers | 27 (one comp, #376790, processed with no reward line) |
| Registrations in log | 29 lines / 28 distinct comps (1 re-registration, 2 unregistrations) |
| Scoring sessions started | 16 (6 in weeks 1-2, 10 in the sweep week) |
| `CHEAT:` triggers | 41 (10 x code 1, 3 x code 10, 28 x code 40) |
| Batched flush groups | 5 |
| Bracket range touched | NOOBS <-> MIDDLES only; TOPS never approached; floor (0) never approached |

Printed delta and the `before -> after` pair agree on **all 26** ledger lines - PCR never came near the 0 floor (min 23), so there is no clamp artifact anywhere in this dump.

## Ledger

Bracket is evaluated on the resulting PCR: NOOBS `<= 100`, MIDDLES `101-1000`, TOPS `>= 1001`.
`delta` is the **printed** value; `PCR before->after` is the authoritative pair.

### Weeks 1-2 (2026-08-10 -> 2026-08-23)

| Timestamp | Comp ID | Comp name | Status | delta | PCR before->after | bracket |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-08-17T18:28:17Z | 376196 | Intervallo di Carpe erbivore | NO-SHOW [^a] | -15 | 41 -> 26 | NOOBS |
| 2026-08-20T13:54:16Z | 376323 | Manicaretto di Muskie | PLAYED (Place 18) | -3 | 26 -> 23 | NOOBS |
| 2026-08-21T09:14:43Z | 376465 | Carnivori Maku-Maku | PLAYED (Place 6) | +22 | 23 -> 45 | NOOBS |
| 2026-08-21T12:00:11Z | 376552 | Brucia il labirinto | PLAYED (Place 3) **top-3** | +45 | 45 -> 90 | NOOBS |
| 2026-08-21T14:00:04Z | 376553 | Gemelli Labeo | PLAYED, ZERO-SCORE (Place empty) | -8 | 90 -> 82 | NOOBS |
| 2026-08-21T23:00:15Z | 376554 | Sfida di Spigole | PLAYED (Place 3) **top-3** | +23 | 82 -> 105 | **NOOBS -> MIDDLES** |
| 2026-08-22T08:23:43Z | 376558 | Carpa jolly | NO-SHOW | -15 | 105 -> 90 | **MIDDLES -> NOOBS** |
| 2026-08-22T21:43:06Z | 376642 | Non fare il prepotente con me, squalo! | NO-SHOW | -20 | 90 -> 70 | NOOBS |
| 2026-08-22T21:43:10Z | 376640 | Caccia al barbo di Gent | PLAYED, ZERO-SCORE (Place empty) | -5 | 70 -> 65 | NOOBS |
| 2026-08-22T22:00:08Z | 376645 | Caccia alla Trota su Falcon | NO-SHOW | -10 | 65 -> 55 | NOOBS |
| 2026-08-23T00:00:07Z | 376646 | Scontro di salmoni | NO-SHOW | -13 | 55 -> 42 | NOOBS |

[^a]: Neither a `Player registered` nor a `Player started scoring time` line exists for #376196 anywhere in the dump - both fall before the first visible event (2026-08-17T18:28:17Z). The regex rule yields NO-SHOW; the row sits inside the truncated head and cannot be confirmed either way. Its `Place:` field is empty.

### Sweep week (2026-08-24 -> 2026-08-30)

| Timestamp | Comp ID | Comp name | Status | delta | PCR before->after | bracket |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-08-25T07:42:38Z | 376790 | Raduno di cernie giganti! | PLAYED (Place 11) | | *(no ledger line)* [^b] | NOOBS (42) |
| 2026-08-25T10:00:10Z | 376868 | Scontro finale di Trota Steelhead | PLAYED (Place 1) **top-3** | +35 | 42 -> 77 | NOOBS |
| 2026-08-25T12:00:20Z | 376869 | Khan Siberiano | PLAYED (Place 2) **top-3** | +35 | 77 -> 112 | **NOOBS -> MIDDLES** |
| 2026-08-26T11:21:30Z | 376871 | Manicaretto di Muskie | PLAYED (Place 48) | -4 | 112 -> 108 | MIDDLES |
| 2026-08-26T11:21:30Z | 376874 | Punto fortunato | NO-SHOW | -11 | 108 -> 97 | **MIDDLES -> NOOBS** |
| 2026-08-26T11:21:30Z | 376873 | Vola come una farfalla, nuota come un Bass | NO-SHOW | -10 | 97 -> 87 | NOOBS |
| 2026-08-26T14:22:19Z | 376937 | Intervallo di Carpe erbivore | PLAYED, ZERO-SCORE (Place empty) | -8 | 87 -> 79 | NOOBS |
| 2026-08-26T16:00:14Z | 376938 | Caccia ai carnivori da trofeo! | PLAYED (Place 5) | +35 | 79 -> 114 | **NOOBS -> MIDDLES** |
| 2026-08-26T19:05:58Z | 376939 | Cattura la Trota con lo spinning | PLAYED (Place 1) **top-3** | +30 | 114 -> 144 | MIDDLES |
| 2026-08-28T11:54:49Z | 377023 | Sfida di Spigole | PLAYED (Place 41) | -3 | 144 -> 141 | MIDDLES |
| 2026-08-28T11:54:49Z | 377024 | Frenesia di marmo sul Tevere | NO-SHOW | -10 | 141 -> 131 | MIDDLES |
| 2026-08-28T18:17:26Z | 377133 | Uno corto e uno lungo | NO-SHOW | -20 | 131 -> 111 | MIDDLES |
| 2026-08-28T18:17:26Z | 377134 | Minimo Neherrin | NO-SHOW | -10 | 111 -> 101 | MIDDLES |
| 2026-08-29T17:58:12Z | 377135 | Non fare il prepotente con me, squalo! | PLAYED (Place 23) | -7 | 101 -> 94 | **MIDDLES -> NOOBS** |
| 2026-08-29T17:58:12Z | 377136 | Intervallo di Carpe erbivore | NO-SHOW | -15 | 94 -> 79 | NOOBS |
| 2026-08-29T20:00:21Z | 377257 | Brucia il labirinto | PLAYED (Place 3) **top-3** | +45 | 79 -> 124 | **NOOBS -> MIDDLES** |
| 2026-08-30T18:29:51Z | 377335 | Rodeo topwater kanik | registered only | | *(not yet processed at dump end)* | MIDDLES (124) |

[^b]: #376790 was played (session started 2026-08-24T16:04:06Z) to a Place-11 finish and its `About to process` marker is present at 2026-08-25T07:42:38Z, but **no** `Tournament reward` line follows. PCR was 42 at the time, far clear of the floor, so this is not the at-zero clamp artifact - the finish simply moved no rating. The next ledger line confirms it: #376868 opens at `before = 42`.

Registration churn not shown in the tables above: on 2026-08-28 he registered for #377132 `Caccia al Rosso Notturno!` at 11:56:34 and unregistered 4 s later at 11:56:38 (no penalty, no result); and he unregistered from #377136 at 11:57:07 only to re-register 2 s later at 11:57:09 - that one then became a -15 no-show.

### Flush batches

Five processing passes emit more than one ledger line at once:

| Timestamp | Comps flushed | PCR walk |
| --- | --- | --- |
| 2026-08-22T21:43:06-10Z | 376642, 376640 | 90 -> 65 |
| 2026-08-26T11:21:30Z | 376871, 376874, 376873 | 112 -> 87 |
| 2026-08-28T11:54:49Z | 377023, 377024 | 144 -> 131 |
| 2026-08-28T18:17:26Z | 377133, 377134 | 131 -> 101 |
| 2026-08-29T17:58:12Z | 377135, 377136 | 101 -> 79 |

Four of the five share an identical second; the 08-22 pair spans 4 s (process markers at 21:43:06 and 21:43:09) and is one pass by the same reading.

## Bracket crossings

The 1000 boundary is never touched - PCR never exceeds 144. The 0 floor is never touched - PCR never drops below 23. All crossings are at the 100 line.

**Upward across 100 - 4 crossings, every one caused by a played result:**

| Timestamp | Comp | Cause | PCR |
| --- | --- | --- | --- |
| 2026-08-21T23:00:15Z | #376554 Sfida di Spigole | PLAYED, Place 3 | 82 -> 105 |
| 2026-08-25T12:00:20Z | #376869 Khan Siberiano | PLAYED, Place 2 | 77 -> 112 |
| 2026-08-26T16:00:14Z | #376938 Caccia ai carnivori da trofeo! | PLAYED, Place 5 | 79 -> 114 |
| 2026-08-29T20:00:21Z | #377257 Brucia il labirinto | PLAYED, Place 3 | 79 -> 124 |

**Downward across 100 - 3 crossings, two of them caused by a no-show:**

| Timestamp | Comp | Cause | PCR |
| --- | --- | --- | --- |
| 2026-08-22T08:23:43Z | #376558 Carpa jolly | NO-SHOW | 105 -> 90 |
| 2026-08-26T11:21:30Z | #376874 Punto fortunato | NO-SHOW | 108 -> 97 |
| 2026-08-29T17:58:12Z | #377135 Non fare il prepotente con me, squalo! | PLAYED, Place 23 | 101 -> 94 |

The third down-crossing is nominally a played defeat, but it only had 1 point of work left to do: the no-show pair #377133 / #377134 had already walked 131 -> 101 in a single flush at 2026-08-28T18:17:26Z, parking the player exactly on the MIDDLES floor.

Tempo of the excursions above the line:

- entered 2026-08-21T23:00:15Z, left 2026-08-22T08:23:43Z - **9 h 23 min**, ended by a no-show;
- entered 2026-08-25T12:00:20Z, left 2026-08-26T11:21:30Z - **23 h 01 min**, ended by a no-show;
- entered 2026-08-26T16:00:14Z, left 2026-08-29T17:58:12Z - **3 d 2 h**, the only long stay, and it produced 1 win (#376939, already in flight when the boundary was crossed), 2 defeats and 5 no-shows;
- entered 2026-08-29T20:00:21Z - still there when the dump ends.

## Prizes

The dump contains **no prize-award event** - the recognised regex set has none, and no such line is present. SQL reports 7 prizes for the three-week window, all in NOOBS (`7N/0M/0T`).

Six top-3 finishes are visible in the dump, with the PCR each was taken at:

| Timestamp | Comp | Place | PCR before | bracket at payout |
| --- | --- | --- | --- | --- |
| 2026-08-21T12:00:11Z | #376552 Brucia il labirinto | 3 | 45 | NOOBS |
| 2026-08-21T23:00:15Z | #376554 Sfida di Spigole | 3 | 82 | NOOBS |
| 2026-08-25T10:00:10Z | #376868 Scontro finale di Trota Steelhead | 1 | 42 | NOOBS |
| 2026-08-25T12:00:20Z | #376869 Khan Siberiano | 2 | 77 | NOOBS |
| 2026-08-26T19:05:58Z | #376939 Cattura la Trota con lo spinning | 1 | 114 | MIDDLES |
| 2026-08-29T20:00:21Z | #377257 Brucia il labirinto | 3 | 79 | NOOBS |

Five of the six pay out with PCR in NOOBS. The sixth (#376939) pays out at 114, but was **registered at 2026-08-26T13:22:08Z with PCR 87** - inside NOOBS - which is consistent with SQL's `0M` prize count if the competition's division is fixed at registration. Two further positive results are not top-3 and are not counted as prizes here: #376465 (Place 6, +22) and #376938 (Place 5, +35). The mapping top-3 -> prize is inference from the `Place:` field, not read from the log.

## Harvest pattern

**The order is present, and it repeats three times.** Play lifts PCR toward and across 100, absence pulls it back under, and the next strong finish is taken from NOOBS.

| # | Play lifts toward / across 100 | Absence pulls back under | Strong finish taken from NOOBS |
| --- | --- | --- | --- |
| 1 | 08-21T09:14:43 +22 (P6), 12:00:11 +45 (P3), 23:00:15 +23 (P3): **23 -> 105**, crosses up | 08-22T08:23:43 no-show -15 -> 90; then -20, -10, -13 (plus a -5 zero-score) down to **42** by 08-23T00:00:07 | 08-25T10:00:10 #376868 **Place 1**, before **42**; 08-25T12:00:20 #376869 **Place 2**, before **77** -> 112 |
| 2 | 08-25T12:00:20 +35 (P2): **77 -> 112**, crosses up | 08-26T11:21:30 single flush: -4 (P48), no-show -11 (crosses down), no-show -10 -> 87; 14:22:19 zero-score -8 -> **79** | 08-26T16:00:14 #376938 **Place 5**, before **79** -> 114; 19:05:58 #376939 **Place 1** -> 144 |
| 3 | 08-26T16:00:14 +35, 19:05:58 +30: **79 -> 144**, crosses up | 08-28T11:54:49 -3 / no-show -10; 18:17:26 no-shows -20, -10 -> 101; 08-29T17:58:12 -7 (crosses down), no-show -15 -> **79** | 08-29T20:00:21 #377257 **Place 3**, before **79** -> 124 |

Re-entry into competition after each drop is fast, and it is the sharpest single fact in this dump:

- **2026-08-29T17:58:12Z** the flush drops him to 79 (NOOBS). **2026-08-29T17:59:09Z - 57 seconds later** he registers for #377257. He starts it at 18:58:23 and finishes **Place 3**, +45, at 20:00:21.
- **2026-08-26T11:21:30Z** the flush drops him from 112 to 87 (NOOBS). **2026-08-26T11:22:26Z - 56 seconds later** he registers for #376937. At 13:21:48 and 13:22:08, still at 87, he registers #376938 and #376939, which return **Place 5** and **Place 1** (+65 combined).
- **2026-08-25T07:44:07 - 07:44:55Z**, two minutes after #376790's Place-11 result leaves him at 42, he registers four competitions in 48 seconds; two of them return **Place 1** and **Place 2**.

Two honest qualifications:

1. The lift and the payout are largely the **same events** - each up-crossing of 100 *is* a strong finish, so this is not a quiet ramp followed by a separate harvest phase. What is separate and repeated is the *descent*: absence removes the rating play just earned, always before anything is scored from inside MIDDLES.
2. The descents are not purely absence. Cycles 2 and 3 mix in a Place-48 and a Place-23 defeat and a zero-score finish. But those contribute -4, -7 and -8 against -21, -30 and -55 of absence in the same descents.

The net effect of the cycle is a player who spends nearly all his competitive time in NOOBS while repeatedly demonstrating top-3 capability there: **every gain in the window lands in a NOOBS-classified competition, and every MIDDLES event loses rating** (3 played -> places 48, 41, 23, worth -14 total; 6 no-shows worth -76).

## Drain route

Whole visible window (2026-08-17 -> 2026-08-30), using the authoritative `before -> after` pairs (printed deltas agree throughout):

| Route | Comps | Rating lost | Share of drain |
| --- | --- | --- | --- |
| No-shows | 11 | **-149** | 79.7 % |
| Zero-score finishes | 3 (#376553, #376640, #376937) | **-21** | 11.2 % |
| Genuine defeats | 4 (#376323 P18, #376871 P48, #377023 P41, #377135 P23) | **-17** | 9.1 % |
| **Total drain** | 18 | **-187** | |
| Gains from played results | 8 | +270 | |
| **Net** | | **+83** (41 -> 124) | |

Sweep week alone (2026-08-24 -> 2026-08-30):

| Route | Comps | Rating lost |
| --- | --- | --- |
| No-shows | 6 | **-76** |
| Zero-score finishes | 1 (#376937) | **-8** |
| Genuine defeats | 3 (#376871, #377023, #377135) | **-14** |
| **Total drain** | 10 | **-98** |
| Gains | 5 | +180 |
| **Net** | | **+82** (42 -> 124) |

The ledger closes exactly in both cases: `41 - 149 - 21 - 17 + 270 = 124`; `42 - 76 - 8 - 14 + 180 = 124`.

Absence is the dominant drain route - about four fifths of everything lost - but note the direction of the net: this player is **not** shedding rating overall. He ends the window 83 points *above* where the dump picks him up, and the sweep week alone is +82. The no-shows do not sink him; they keep him oscillating around 100.

## Reconciliation with SQL

SQL is authoritative for volume; the ledger is authoritative for shape.

| Quantity | SQL (3 weeks) | Ledger (visible, from 08-17) | Difference |
| --- | --- | --- | --- |
| Registrations | 33 | 28 distinct comps registered (plus #376196, registered before the dump) | 4-5 in the truncated head |
| Started (played) | 17 | 16 | 1 in the head |
| Zero-score | 3 | 3 (#376553, #376640, #376937) | exact |
| No-shows | 16 (48.5 %) | 11 | 5 in the head |
| Absence | -227 | -149 | -78 in the head |
| Play | +262 | +232 | +30 in the head |
| Net | +35 | +83 | -48 in the head |
| Prizes | 7 = 7N/0M/0T | 6 top-3 finishes visible, 5 paid out below 100 (the 6th registered below 100) | 1 in the head |

Working the difference backwards, the missing head (2026-08-10 -> 2026-08-17) holds **1 played result worth +30, 5 no-shows worth -78, and PCR 89 at window start**: `89 - 78 + 30 = 41`, the first visible `before`. That +30 is very likely the 7th prize.

SQL's bracket-run split (`NOOBS 3 runs / MIDDLES 2 runs`; `MIDDLES: 3 played -14, 6 no-shows -76, 0 prizes`) has exactly one arithmetic solution over the visible ledger:

- **MIDDLES played (-14):** #376871 (-4), #377023 (-3), #377135 (-7)
- **MIDDLES no-shows (-76):** #376874 (-11), #376873 (-10), #377024 (-10), #377133 (-20), #377134 (-10), #377136 (-15)

That is, **all MIDDLES activity in the whole three weeks falls inside the sweep week**, in two runs (08-25/26 and 08-28/29), and every single MIDDLES event is a loss; everything else - all 8 positive results and all 7 prizes - is NOOBS. This assignment is *derived* from the SQL sums plus the 2-run and 0-prize constraints, not read off the log: the log's own bracket axis (player PCR at the reward) puts #376873 at 97 and #376939 at 114, which does not fit, so the SQL letters index the competition's own division rather than the player's PCR at payout. Flagged, not asserted.

## Anti-cheat

41 `CHEAT:` triggers, heavily weighted to the severe code:

- **28 x code (40)** - `Fish catch distance is VERY long` (19; up to 11.35 against a limit of 5.25), `Undriven boat moves TOO fast` (7; up to 385.5 against a max of 5), `Boat moves TOO fast` (2; 291.9 and 383.9 against a max of 23)
- **10 x code (1)** - `Line has high extension too often` (9; up to 1.0 against a limit of 0.4), `Distance from tackle to attacking fish is long while reeling` (1)
- **3 x code (10)** - `Line has critical extension too often` (up to 0.538 against a limit of 0.1)

Distribution across the 16 scoring sessions - 9 dirty, 7 clean:

| Session start | Comp | Result | Triggers |
| --- | --- | --- | --- |
| 2026-08-20T14:07:03Z | #376465 | Place 6, +22 | 1 |
| 2026-08-21T10:24:33Z | #376552 | Place 3, +45 | 2 |
| 2026-08-21T13:02:40Z | #376553 | zero-score, -8 | 1 |
| 2026-08-21T14:00:35Z | #376554 | Place 3, +23 | 1 |
| 2026-08-24T16:04:06Z | #376790 | Place 11, no ledger line | 5 (boat 291.9 / undriven 290.3) |
| 2026-08-25T10:14:45Z | #376869 | Place 2, +35 | 1 |
| 2026-08-26T14:31:00Z | #376938 | Place 5, +35 | **23** (boat 383.9 / undriven 385.5, 11 x long catch distance) |
| 2026-08-28T18:28:01Z | #377135 | Place 23, -7 | 4 |
| 2026-08-29T18:58:23Z | #377257 | Place 3, +45 | 3 |

Clean sessions: #376323, #376640, #376868 (Place 1), #376871, #376937, #376939 (Place 1), #377023.

The single heaviest session (#376938, 23 triggers in 42 minutes) is also the up-crossing of 100 on 2026-08-26T16:00:14Z. Every session in the dump runs from the same IP **87.11.200.71** and the same MAC **f8461c41b4f4** - 16 of 16, no variation.
