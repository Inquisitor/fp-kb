---
player: kovlekplayz
uid: 4e051eae-c2a0-4473-ad49-67e48aaf0775
platform: XBox
ledger_window: 2026-08-31 .. 2026-09-13
charge_window: 2026-09-07 .. 2026-09-13
ledger_first_entry: 2026-09-04T14:55:07Z
ledger_last_entry: 2026-09-13T10:51:52Z
pcr_at_start: 0
pcr_at_end: 17
pcr_range: 0..117
max_pcr_in_window: 117
net_delta: -1
ledger_entries: 41
played_events: 15
zero_score_events: 0
no_show_events: 26
rating_from_played: 347
rating_from_zero_score: 0
rating_from_no_show: -348
batched_flush_groups: 9
longest_no_show_streak: 6 entries over 11h
middles_to_noobs_drops: 1 (no-show 1, zero-score 0)
failed_registrations: 0
cheat_triggers: 38
evidence_completeness: ok
notable:
  - Comp #159756 at 2026-09-05T07:49:24Z prints CompetitionRating -20 but moves 16 -> 0 (-16 actual); rating clamped at 0, printed figure overstates the loss.
  - Comp #159882 at 2026-09-06T14:04:56Z prints CompetitionRating -10 but moves 9 -> 0 (-9 actual); rating clamped at 0, printed figure overstates the loss.
  - Comp #160168 at 2026-09-12T08:49:20Z prints CompetitionRating -15 but moves 2 -> 0 (-2 actual); rating clamped at 0, printed figure overstates the loss.
  - Same-second cluster at 2026-09-12T08:49:20Z: 5 ledger entries (server reconciliation moment).
  - Crossed below PCR 100 at 2026-09-11T17:25:26Z on comp #160113 (102 -> 92, NO-SHOW).
  - Crossed above PCR 100 at 2026-09-11T07:49:11Z on comp #160074 (92 -> 117, PLAYED).
  - Longest unbroken NO-SHOW run: 6 entries, 2026-09-11T21:34:45Z to 2026-09-12T08:49:20Z (11h).
  - 38 CHEAT triggers, 2026-09-04T10:32:55Z to 2026-09-13T11:19:57Z; first: CHEAT: (10) Fish is too far from tackle when finish attack Actual: 1.80366265773773, Limit (max): 1.54999995231628
---

# kovlekplayz - trajectory card

The ledger holds 41 PCR entries between 2026-09-04T14:55:07Z and 2026-09-13T10:51:52Z, opening at PCR 0 and closing at PCR 17 for a net -1. Of those entries 15 are PLAYED (+347 rating), 0 ZERO-SCORE (0) and 26 NO-SHOW (-348). PCR after values span 0..117, with a maximum of 117. The 100 boundary is crossed downward 1 time and upward 1 time. 9 same-second entry clusters contain at least one NO-SHOW. The longest unbroken NO-SHOW run is 6 entries over 11h. The same log carries 38 CHEAT trigger lines.

## PCR ledger

| Timestamp | Comp ID | Comp name | Status | Delta | PCR |
|---|---|---|---|---|---|
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
| 2026-09-07T16:00:06Z | 159928 | Flussbarschrausch | NO-SHOW | -10 | 30 -> 20 |
| 2026-09-08T03:36:44Z | 159929 | Wettkampf des alten Buck | PLAYED | +22 | 20 -> 42 |
| 2026-09-08T03:36:45Z | 159933 | Forellenperfektionist | NO-SHOW | -10 | 42 -> 32 |
| 2026-09-08T03:36:45Z | 159930 | Große Karpfenjäger | NO-SHOW | -13 | 32 -> 19 |
| 2026-09-08T03:36:45Z | 159932 | Präzisionswahn | NO-SHOW | -10 | 19 -> 9 |
| 2026-09-08T14:00:07Z | 159971 | Pack den Forelle! | PLAYED | +23 | 9 -> 32 |
| 2026-09-09T12:46:44Z | 159973 | Die große Kahlhechtjagd | PLAYED | +20 | 32 -> 52 |
| 2026-09-10T03:32:49Z | 160029 | Streik! Und noch ein Streik! | PLAYED | +30 | 52 -> 82 |
| 2026-09-10T13:01:12Z | 160067 | Falcon-Forellenjagd | NO-SHOW | -10 | 82 -> 72 |
| 2026-09-10T13:01:12Z | 160068 | Marmorrausch am Tiber | NO-SHOW | -10 | 72 -> 62 |
| 2026-09-10T13:01:12Z | 160070 | Vielfalt am Fluss Marron | NO-SHOW | -15 | 62 -> 47 |
| 2026-09-10T13:01:13Z | 160069 | Glücksjagd auf Karpfen-Albino | NO-SHOW | -15 | 47 -> 32 |
| 2026-09-10T14:00:08Z | 160071 | Einer nach dem Anderen | PLAYED | +20 | 32 -> 52 |
| 2026-09-10T18:16:49Z | 160073 | Der Fluss der Сrank | PLAYED | +40 | 52 -> 92 |
| 2026-09-11T07:49:11Z | 160074 | Hecht-Walzer | PLAYED | +25 | 92 -> 117 |
| 2026-09-11T17:25:26Z | 160112 | Bartelpokal | NO-SHOW | -15 | 117 -> 102 |
| 2026-09-11T17:25:26Z | 160113 | Forellenperfektionist | NO-SHOW | -10 | 102 -> 92 |
| 2026-09-11T17:25:26Z | 160114 | Rot und glänzend | NO-SHOW | -15 | 92 -> 77 |
| 2026-09-11T21:34:45Z | 160116 | Der Kampf um Kaniq | PLAYED | -2 | 77 -> 75 |
| 2026-09-11T21:34:45Z | 160117 | Schulbarsch | NO-SHOW | -10 | 75 -> 65 |
| 2026-09-12T08:49:20Z | 160120 | Fünf-Sterne-Hechte! | NO-SHOW | -13 | 65 -> 52 |
| 2026-09-12T08:49:20Z | 160119 | Pack den Forelle! | NO-SHOW | -10 | 52 -> 42 |
| 2026-09-12T08:49:20Z | 160118 | Angriff auf den Riesen-Nilhecht | NO-SHOW | -20 | 42 -> 22 |
| 2026-09-12T08:49:20Z | 160121 | Erstaunliche Barschjagd | NO-SHOW | -20 | 22 -> 2 |
| 2026-09-12T08:49:20Z | 160168 | Glücksjagd auf Karpfen-Albino | NO-SHOW | -15 | 2 -> 0 |
| 2026-09-12T11:44:20Z | 160170 | Sibirischer Khan | PLAYED | +30 | 0 -> 30 |
| 2026-09-13T05:16:21Z | 160178 | Die Fünf besten Barsche | NO-SHOW | -10 | 30 -> 20 |
| 2026-09-13T05:16:21Z | 160179 | Flamme das Labyrinth | NO-SHOW | -20 | 20 -> 0 |
| 2026-09-13T10:51:52Z | 160218 | Emerald Lake Raubfischjagd | PLAYED | +17 | 0 -> 17 |

## SQL cross-check

SQL sweep covers the charge window 2026-09-07..2026-09-13 only; the 14-day ledger legitimately exceeds it.

| SQL column | SQL value |
|---|---|
| Registrations | 32 |
| Started | 11 |
| ZeroScore | 0 |
| NoShows | 21 |
| Unproductive | 21 |
| UnproductiveSharePct | 65.63 |
| RatingFromUnproductive | -276 |
| RatingFromProductivePlay | 247 |
| NetDelta | -29 |
| Gold-Silver-Bronze | 1-2-6 |
| Played N/M/T | 11-0-0 |
| Prizes N/M/T | 9-0-0 |
| TotalPrizes | 9 |
| MaxRatingAtStart | 92 |
| CurrentPCR | 17 |
| LifetimeG-S-B | 6-8-15 |

Ledger restricted to the charge sub-range (2026-09-07..2026-09-13):

| Measure | Ledger (charge sub-range) | SQL | Agreement |
|---|---|---|---|
| Distinct comps with a registration line | 33 (33 lines) | 32 | differs |
| Distinct comps with a start line | 11 (11 lines) | 11 | match |
| ZERO-SCORE ledger entries | 0 | 0 | match |
| NO-SHOW ledger entries | 19 | 21 | differs |
| Unproductive (no-show + zero-score) | 19 | 21 | differs |
| Rating from unproductive | -251 | -276 | differs |
| Rating from productive play | +225 | 247 | differs |
| Net delta | -26 | -29 | differs |
| PLAYED ledger entries | 10 | (no direct SQL column) | n/a |

Completeness rule: flag `degraded` when the charge-sub-range NO-SHOW count falls below SQL by more than max(20%, 5 events). SQL NoShows 21, ledger 19, shortfall 2, threshold 5.0 -> **ok**.
