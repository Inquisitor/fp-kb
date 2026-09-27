---
uid: a92ed0c7-bb5e-43ac-971c-7af91fd47d31
username: CrazyGepard
platform: PlayStation
card_span: 2026-09-07T00:00:00Z .. 2026-09-20T23:59:59Z
charge_window: 2026-09-14 .. 2026-09-20
pcr_at_start: 73
pcr_at_end: 135
pcr_range: 0..135
max_pcr_in_window: 135
net_delta: +52 card span; +75 charge window
registrations: 35 card span; 31 charge window
played: 11 card span; 10 charge window
zero_score: 0 card span; 0 charge window
no_shows: 19 card span; 16 charge window
middles_to_noobs_drops: 0 (no-show 0, zero-score 0); 0 inside charge window
middles_to_noobs_drop_dates: []
batched_flush_groups: 3 card span; 3 charge window; largest cluster 3 entries
longest_no_show_streak_hours: 21.9 (run of 8, 2026-09-17T08:00:07Z .. 2026-09-18T05:57:02Z)
presence_gaps: 29 gaps of 2h or more; 279.8 h = 83.3% of the 336 h card span
cheat_triggers: 95 card span; 81 charge window
evidence_completeness: ok
notable:
  - 'charge-window ledger: 26 entries - 10 played, 0 zero-score, 16 no-show'
  - 'charge-window rating split: -227 from unproductive entries, +302 from productive play, net +75'
  - 'largest same-second flush in window: 3 entries at 2026-09-18T05:57:02Z, 3 of them no-show'
  - '2 in-window entries land on rating 0; penalties at the floor leave no ledger line'
  - '1 unregistration event, of which 1 in the charge window'
  - 'most frequent cheat triggers: Avg fish velocity is too high x28; Fish catch distance is long x25; Line has high extension too often x19'
  - 'longest silence 2026-09-12T18:12:16Z to 2026-09-15T07:16:57Z, 61.1 h (interior)'
  - 'unproductive entries by activity context: 17 in-gap, 2 in-presence over the card span'
---

# CrazyGepard - PCR trajectory card

CrazyGepard, PlayStation. Card span 2026-09-07T00:00:00Z .. 2026-09-20T23:59:59Z, the full retention of the source log collection. The charge window is 2026-09-14 .. 2026-09-20; everything dated before 2026-09-14 on this card is pre-context and is not part of the charge.

## Ledger

31 participations over the card span, 30 of them carrying a reward line in the log, 27 of them inside the charge window. Status comes from the participation record in the database, not from the log: NO-SHOW where the player never entered, ZERO-SCORE where he entered and finished without a score, PLAYED otherwise. The log supplies the registration time, the presence marks and the PCR chain, and rows it does not carry are marked in the ledger.

| Comp start       | Registered  | Applied     | RegPCR | StartPCR | Status  | Place | Delta | PCR chain  | Presence    |  Fee | ID     | Competition                            |
|------------------|-------------|-------------|-------:|---------:|---------|------:|------:|:----------:|-------------|-----:|--------|----------------------------------------|
| 2026-09-07 20:00 | 09-07 19:09 | 09-08 07:16 |     73 |        . | NO-SHOW |     . |   -15 |  73 -> 58  | in-gap      | 2500 | 378135 | Labeo-Zwillinge                        |
| 2026-09-10 04:00 | 09-10 03:47 | 09-10 06:00 |     58 |       58 | PLAYED  |     1 |    25 |  58 -> 83  | in-gap      |  300 | 378384 | Einer nach dem Anderen                 |
| 2026-09-10 12:00 | 09-10 09:09 | 09-11 12:08 |     83 |        . | NO-SHOW |     . |   -13 |  83 -> 70  | in-gap      |  500 | 378388 | Der Kampf um Kaniq                     |
| 2026-09-12 16:00 | 09-12 15:07 | 09-12 18:12 |     70 |        . | NO-SHOW |     . |   -20 |  70 -> 50  | in-gap      | 3000 | 378591 | Marlin-Tauziehen!                      |
| 2026-09-15 08:00 | 09-15 07:16 | 09-15 10:00 |     50 |       50 | PLAYED  |     1 |    25 |  50 -> 75  | in-gap      |  200 | 378880 | Kleinkram am Neherrin River            |
| 2026-09-15 22:00 | 09-15 16:37 | 09-16 06:31 |     75 |        . | NO-SHOW |     . |   -20 |  62 -> 42  | in-gap      | 3500 | 378887 | Nächtliche Rubin-Jagd!                 |
| 2026-09-16 00:00 | 09-15 16:37 | 09-16 06:31 |     75 |        . | NO-SHOW |     . |   -13 |  75 -> 62  | in-gap      |  700 | 378888 | Faule Aland                            |
| 2026-09-16 14:00 | 09-16 10:03 | 09-16 16:00 |     42 |       42 | PLAYED  |     1 |    47 |  42 -> 89  | in-presence | 1500 | 378973 | Vielfalt am Fluss Marron               |
| 2026-09-16 18:00 | 09-16 16:13 | 09-17 03:46 |     89 |        . | NO-SHOW |     . |   -11 |  89 -> 78  | in-gap      |  500 | 378975 | Mondschein-Knochenhecht                |
| 2026-09-17 04:00 | 09-17 03:47 | 09-17 06:24 |     78 |       78 | PLAYED  |     2 |    22 | 78 -> 100  | in-gap      |  300 | 379072 | Einer nach dem Anderen                 |
| 2026-09-17 06:00 | 09-17 04:49 | 09-17 08:00 |     78 |        . | NO-SHOW |     . |   -10 | 100 -> 90  | in-gap      |  300 | 379073 | Zander Zeemannsgarn                    |
| 2026-09-17 08:00 | 09-17 04:49 | 09-17 10:00 |     78 |        . | NO-SHOW |     . |   -15 |  90 -> 75  | in-gap      | 1200 | 379074 | Maku-Maku-Karnivore                    |
| 2026-09-17 10:00 | 09-17 04:49 | 09-17 12:00 |     78 |        . | NO-SHOW |     . |   -20 |  75 -> 55  | in-gap      | 2500 | 379075 | Kaiser des Nils                        |
| 2026-09-17 12:00 | 09-17 04:50 | 09-17 14:00 |     78 |        . | NO-SHOW |     . |   -15 |  55 -> 40  | in-presence |  900 | 379076 | Mächtige Drei                          |
| 2026-09-17 14:00 | 09-17 04:50 | 09-17 16:00 |     78 |        . | NO-SHOW |     . |   -13 |  40 -> 27  | in-presence |  700 | 379077 | Drücken Sie die Schleie                |
| 2026-09-17 18:00 | 09-17 17:31 | 09-18 05:57 |     27 |        . | NO-SHOW |     . |   -11 |  17 -> 6   | in-gap      |  500 | 379079 | Weiß auf Schwarz                       |
| 2026-09-17 20:00 | 09-17 17:32 | 09-18 05:57 |     27 |        . | NO-SHOW |     . |   -10 |  27 -> 17  | in-gap      |  300 | 379080 | Mit sehendem Auge, schwimmt der Barsch |
| 2026-09-17 22:00 | 09-17 17:32 | 09-18 05:57 |     27 |        . | NO-SHOW |     . |   -15 |   6 -> 0   | in-gap      | 1500 | 379081 | Glückliche 50                          |
| 2026-09-18 10:00 | 09-18 08:55 | 09-18 12:00 |      0 |        0 | PLAYED  |     1 |    35 |  0 -> 35   | in-presence |  500 | 379218 | Auf die Größe kommt es an              |
| 2026-09-18 14:00 | 09-18 12:45 | 09-18 16:00 |     35 |       35 | PLAYED  |     2 |    27 |  35 -> 62  | in-presence |  500 | 379220 | Pack den Forelle!                      |
| 2026-09-18 18:00 | 09-18 17:26 | 09-19 05:04 |     62 |       62 | PLAYED  |     8 |    11 |  62 -> 73  | in-gap      |  300 | 379222 | Der große rote Fisch                   |
| 2026-09-18 20:00 | 09-18 19:01 | 09-19 05:04 |     62 |        . | NO-SHOW |     . |   -11 |  45 -> 34  | in-gap      |  300 | 379223 | Komm schon, Karpfen!                   |
| 2026-09-18 22:00 | 09-18 19:00 | 09-19 05:04 |     62 |        . | NO-SHOW |     . |   -15 |  73 -> 58  | in-gap      | 2000 | 379224 | Gefleckt oder gebändert?               |
| 2026-09-19 00:00 | 09-18 19:01 | 09-19 05:04 |     62 |        . | NO-SHOW |     . |   -15 |  34 -> 19  | in-gap      | 1200 | 379225 | Blutige Bedrohung                      |
| 2026-09-19 02:00 | 09-18 19:01 | 09-19 05:04 |     62 |        . | NO-SHOW |     . |   -13 |  58 -> 45  | in-gap      |  700 | 379226 | Karpfenquellen                         |
| 2026-09-19 04:00 | 09-18 19:01 | 09-19 06:00 |     62 |        . | NO-SHOW |     . |   -20 |  19 -> 0   | in-gap      | 4000 | 379325 | Ich werde dir nichts tun, Hai!         |
| 2026-09-19 18:00 | 09-19 15:29 | 09-19 20:00 |      0 |        0 | PLAYED  |     1 |    25 |  0 -> 25   | in-gap      |  300 | 379332 | Hol Dir alle                           |
| 2026-09-20 08:00 | 09-20 05:43 | 09-20 10:00 |     25 |       25 | PLAYED  |     4 |    20 |  25 -> 45  | in-gap      |  200 | 379407 | Barsch Herausforderung                 |
| 2026-09-20 16:00 | 09-20 15:30 | 09-20 18:00 |     45 |       45 | PLAYED  |     1 |    55 | 45 -> 100  | in-presence | 2000 | 379411 | Erstaunliche Barschjagd                |
| 2026-09-20 20:00 | 09-20 18:22 | 09-20 22:00 |    100 |      100 | PLAYED  |     2 |    35 | 100 -> 135 | in-presence |  800 | 379413 | Der Fluss der Сrank                    |
| 2026-09-20 22:00 | 09-20 18:25 | .           |    100 |        . | NO-SHOW |     . |   -15 | not logged | .           |  900 | 379414 | (no reward line in log)                |

> **Spine is SQL, not the log** (week-20). Rows marked `(no reward line in log)` are
> participations SQL records and the ledger does not: the competition resolved but no
> `Tournament reward` line was ever written for it. 1 of 31 rows here. Their rating
> delta is real and is in the SQL column; the PCR chain simply skips them, so a chain read
> end-to-end will not reconcile with `CurrentPCR` by exactly those deltas.

Charge-window boundary: the first in-window entry is 2026-09-15T10:00:08Z at PCR 50 before, the last is 2026-09-20T22:00:38Z at PCR 135 after.

## MIDDLES to NOOBS crossings

Brackets: NOOBS 0-100, MIDDLES 101-1000, TOPS 1001+. A crossing is counted when pcr_before is 101 or more and pcr_after is 100 or less on a NO-SHOW or ZERO-SCORE entry, so 110 -> 100 counts and 100 -> 95 does not.

None. No ledger entry in the card span moves from 101 or above to 100 or below on a no-show or zero-score entry.

## Batched flushes and no-show streaks

Same-second clusters of two or more reward entries containing at least one NO-SHOW: **3** over the card span, **3** inside the charge window; largest cluster 3 entries.

| Timestamp | Entries | No-show | Zero-score | Played | Net Δ |
|---|---|---|---|---|---|
| 2026-09-18T05:57:02Z | 3 | 3 | 0 | 0 | -36 |
| 2026-09-19T05:04:11Z | 3 | 2 | 0 | 1 | -17 |
| 2026-09-19T05:04:12Z | 2 | 2 | 0 | 0 | -26 |

Longest run of five or more consecutive no-show entries: 21.9 (run of 8, 2026-09-17T08:00:07Z .. 2026-09-18T05:57:02Z).

## Presence

Gaps are intervals of two hours or more inside the card span with no log line of any type in `a92ed0c7-bb5e-43ac-971c-7af91fd47d31-crazygepard-presence.tsv`. The interval from the card-span start to the first logged line and from the last logged line to the card-span end are included and labelled.

**29 gaps, 279.8 h in total, 83.3% of the 336 h card span** (260.6 h interior, 19.2 h at the card-span edges).

| Gap | Hours | Kind |
|---|---|---|
| 2026-09-07T00:00:00Z -> 2026-09-07T19:09:34Z | 19.2 | leading |
| 2026-09-07T19:09:34Z -> 2026-09-07T22:00:02Z | 2.8 | interior |
| 2026-09-07T22:00:02Z -> 2026-09-08T07:16:46Z | 9.3 | interior |
| 2026-09-08T07:16:46Z -> 2026-09-10T03:47:30Z | 44.5 | interior |
| 2026-09-10T06:00:06Z -> 2026-09-10T09:09:12Z | 3.2 | interior |
| 2026-09-10T09:09:12Z -> 2026-09-10T14:00:02Z | 4.8 | interior |
| 2026-09-10T14:00:02Z -> 2026-09-11T12:08:19Z | 22.1 | interior |
| 2026-09-11T12:08:19Z -> 2026-09-12T15:07:31Z | 27.0 | interior |
| 2026-09-12T15:07:31Z -> 2026-09-12T18:00:02Z | 2.9 | interior |
| 2026-09-12T18:12:16Z -> 2026-09-15T07:16:57Z | 61.1 | interior |
| 2026-09-15T10:00:08Z -> 2026-09-15T16:31:29Z | 6.5 | interior |
| 2026-09-15T16:37:36Z -> 2026-09-16T00:00:02Z | 7.4 | interior |
| 2026-09-16T00:00:02Z -> 2026-09-16T02:00:02Z | 2.0 | interior |
| 2026-09-16T02:00:02Z -> 2026-09-16T06:31:06Z | 4.5 | interior |
| 2026-09-16T06:31:07Z -> 2026-09-16T10:03:51Z | 3.5 | interior |
| 2026-09-16T20:00:02Z -> 2026-09-17T03:46:41Z | 7.8 | interior |
| 2026-09-17T17:33:28Z -> 2026-09-17T20:00:02Z | 2.4 | interior |
| 2026-09-17T20:00:02Z -> 2026-09-17T22:00:02Z | 2.0 | interior |
| 2026-09-17T22:00:02Z -> 2026-09-18T00:00:02Z | 2.0 | interior |
| 2026-09-18T00:00:02Z -> 2026-09-18T05:57:02Z | 6.0 | interior |
| 2026-09-18T05:57:02Z -> 2026-09-18T08:55:19Z | 3.0 | interior |
| 2026-09-18T20:00:02Z -> 2026-09-18T22:00:02Z | 2.0 | interior |
| 2026-09-18T22:00:02Z -> 2026-09-19T00:00:02Z | 2.0 | interior |
| 2026-09-19T00:00:02Z -> 2026-09-19T02:00:02Z | 2.0 | interior |
| 2026-09-19T02:00:02Z -> 2026-09-19T04:00:02Z | 2.0 | interior |
| 2026-09-19T06:00:05Z -> 2026-09-19T15:29:13Z | 9.5 | interior |
| 2026-09-19T20:00:34Z -> 2026-09-20T05:43:56Z | 9.7 | interior |
| 2026-09-20T05:43:56Z -> 2026-09-20T08:49:17Z | 3.1 | interior |
| 2026-09-20T10:00:17Z -> 2026-09-20T15:30:28Z | 5.5 | interior |

### How the in-gap / in-presence column is derived

Every reward write is itself a logged line, so measured against the raw presence stream all 30 ledger entries would trivially read in-presence. The column therefore tests each timestamp against the **activity stream**: the presence stream with the server-side tournament-batch lines removed (`About to process tournament Competition #...` and `Tournament reward Competition #...`, 60 lines). On that stream there are 30 gaps of two hours or more totalling 290.0 h, 86.3% of the card span, and an entry reads in-gap when its own timestamp falls inside one of them, that is when the player produced no other log line of any kind for at least two hours around the moment the rating moved.

**The ledger timestamp is the moment the rating was applied, not the moment the competition ran.** Tournament results are processed in server-side batches after a competition closes, so in-presence does not by itself prove the player was online while the competition ran or that he chose to skip it, and in-gap does not prove he was away while it ran.

Unproductive entries (NO-SHOW plus ZERO-SCORE) by activity context: **17 in-gap, 2 in-presence** over the card span; 14 and 2 respectively inside the charge window.

## Other log events

| Event | Card span | Charge window |
|---|---|---|
| `Player registered for Competition #` | 35 | 31 |
| `Player unregistered from Competition #` | 1 | 1 |
| failed registration attempts | 0 | 0 |
| `Player started scoring time for Competition #` | 11 | 10 |
| `CHEAT:` triggers | 95 | 81 |

### Cheat triggers by kind

Numeric payloads inside a trigger message are collapsed to `N` so variants of the same check group into one row.

| Trigger | Card span | Charge window |
|---|---|---|
| Avg fish velocity is too high | 28 | 14 |
| Fish catch distance is long | 25 | 25 |
| Line has high extension too often | 19 | 19 |
| Undriven boat moves TOO fast | 9 | 9 |
| Fish is too far from tackle when finish attack | 6 | 6 |
| Friction force is too high | 3 | 3 |
| Distance from tackle to attacking fish is long while reeling | 3 | 3 |
| Last N fish have low fighting/passive time ratio on a LONG distance Nm and reeling time: Ns | 2 | 2 |

## SQL cross-check, charge window 2026-09-14 .. 2026-09-20

| Measure | From log | From SQL | Verdict |
|---|---|---|---|
| Registrations | 31 | 26 | differs (+5) |
| Started, played plus zero-score | 10 | 10 | match |
| Zero-score | 0 | 0 | match |
| No-shows | 16 | 16 | match |
| Unproductive, no-show plus zero-score | 16 | 16 | match |
| Rating from unproductive | -227 | -227 | match |
| Rating from productive play | +302 | +302 | match |
| Net delta | +75 | +75 | match |
| PCR after last in-span entry vs CurrentPCR | 135 | 135 | match |
| Highest pcr_before in window vs MaxRatingAtStart | 100 | 100 | match |

Registrations from the log count `Player registered for Competition #` lines timestamped inside the window; the SQL Reg column attributes a registration to the competition rather than to the moment the player pressed register, so the two need not agree at the window edges. Registrations are not part of the evidence_completeness test.

SQL reference row: Reg 26, Started 10, ZeroScore 0, NoShows 16, Unproductive 16, Share 61.54%, RatingFromUnproductive -227, RatingFromProductivePlay +302, NetDelta +75, G/S/B 5/3/0, Total 8, Played N/M/T 10/0/0, Prizes N/M/T 8/0/0, CurrentPCR 135, MaxRatingAtStart 100, Lifetime G/S/B 8/3/-.

### evidence_completeness: ok

Rule: a row is flagged when the log and SQL differ by more than 20% of the SQL figure or by more than 5 absolute events, whichever is larger. Only no-shows, zero-score and their sum are in scope.

Chain continuity: 30 reward entries, **0 breaks** - every entry's pcr_before equals the previous entry's pcr_after across the whole card span. No rating-changing reward line is missing from the retained log between the first and the last entry, so any shortfall against SQL comes from penalties absorbed at the rating floor (which write no line at all) or from window attribution, not from lost log lines.

- No in-scope row exceeds the tolerance.
