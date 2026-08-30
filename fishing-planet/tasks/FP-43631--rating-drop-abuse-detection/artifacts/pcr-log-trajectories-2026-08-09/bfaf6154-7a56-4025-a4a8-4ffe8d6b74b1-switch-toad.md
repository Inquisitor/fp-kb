---
type: trajectory-card
task: FP-43631
player: switch-toad
profile_id: bfaf6154-7a56-4025-a4a8-4ffe8d6b74b1
platform: PlayStation
source: bfaf6154-7a56-4025-a4a8-4ffe8d6b74b1-switch-toad.tsv
log_window: 2026-07-27T14:25:28Z .. 2026-08-09T22:56:37Z
ledger_window: 2026-08-03T04:00:10Z .. 2026-08-09T22:00:53Z
---

# switch-toad (PlayStation) - PCR trajectory

## Summary

| Metric | Value |
| --- | --- |
| PCR at first ledger line (before) | 63 |
| PCR at last ledger line (after) | 77 |
| PCR min | 0 (2026-08-07T20:00:10Z) |
| PCR max | 158 (2026-08-05T20:00:17Z) |
| Ledger entries | 41 (41 distinct competitions) |
| Played (scoring-time started) | 22 log-wide / 21 processed / 18 with a ledger line |
| No-shows | 23 |
| Prizes | 7 (ledger has 10 positive-delta lines; 7 are >= +40) |
| Batched flush groups | 4 |
| Registration lines | 61 across 51 distinct comps (+14 unregister lines across 11 comps) |
| CHEAT triggers | 338 |
| Bracket span | NOOBS <-> MIDDLES only; TOPS never reached (max 158) |

## Reconciliation against SQL

The log reconciles to SQL exactly once the process markers are used as the
denominator:

| SQL | Log evidence |
| --- | --- |
| Reg 44 | 44 `About to process tournament Competition #` markers, 44 distinct comps |
| started 21 | 22 `started scoring time` comps, minus #376125 (started 2026-08-09T22:07:13Z, never processed before the log cut) |
| zero-score 3 | 3 processed comps with a start but **no reward line at all**: #376098 (2026-08-07T18:00:27Z), #376100 (2026-08-07T22:00:27Z), #376122 (2026-08-09T18:00:29Z) |
| no-shows 23 | 23 ledger lines whose comp has no `started scoring time` |
| absence -316 | sum of NO-SHOW deltas = -316 |
| play +329 | sum of PLAYED **printed** deltas = +329 (true PCR movement is +330) |
| net +13 | 329 - 316 = +13; actual PCR movement is 63 -> 77 = **+14** |
| PCR 77 | last ledger `after` = 77 |
| Prizes 7 = 7N/0M/0T | the 7 ledger lines with delta >= +40 were all registered while PCR was in NOOBS |

Two reasons the ledger is sparser than the registration volume, both logging
artifacts rather than inactivity:

- **Floor clamp.** At 2026-08-07T20:00:10Z (#376099) the printed delta is `-6`
  but the pair reads `5 -> 0`; only 5 points were actually taken. That single
  swallowed point is the whole difference between SQL's net +13 and the +14 the
  ledger pair endpoints show. Every other line has printed == pair difference.
- **Zero-score no-op.** Three processed competitions produced no ledger line
  whatsoever. #376100 was processed while PCR sat at 0, but #376122 was
  processed at PCR 55 - well clear of the floor - so this is a zero-delta
  result being suppressed, not only floor clamping.

The ledger chain is otherwise unbroken: all 41 lines are contiguous
(`after[i] == before[i+1]`), so no line is missing from the middle of the run.

## Ledger

Bracket column = state **after** the entry; `->` marks a crossing. Delta is the
`before -> after` pair difference, not the printed number.

| Timestamp | Comp ID | Comp name | Status | Delta | PCR before->after | Bracket |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-08-03T04:00:10Z | 374835 | Spotted or Banded? | PLAYED | +47 | 63 -> 110 | NOOBS -> MIDDLES |
| 2026-08-04T02:00:10Z | 374846 | Maku-Maku Carnivores | PLAYED | -8 | 110 -> 102 | MIDDLES |
| 2026-08-04T16:26:05Z | 374920 | Grass Сutter Range | NO-SHOW | -15 | 102 -> 87 | MIDDLES -> NOOBS |
| 2026-08-04T16:26:05Z | 374922 | Five-Star Pikes! | NO-SHOW | -13 | 87 -> 74 | NOOBS |
| 2026-08-04T16:26:05Z | 374923 | Breaking Shad | NO-SHOW | -10 | 74 -> 64 | NOOBS |
| 2026-08-04T16:26:05Z | 374919 | Siberian Khan | PLAYED | -5 | 64 -> 59 | NOOBS |
| 2026-08-04T16:26:05Z | 374925 | Barbel Gent Hunt | NO-SHOW | -10 | 59 -> 49 | NOOBS |
| 2026-08-05T00:00:32Z | 374929 | Midnight Salmon Galore | PLAYED | +20 | 49 -> 69 | NOOBS |
| 2026-08-05T02:12:37Z | 374930 | Smile, it’s Jacunda Time! | PLAYED | -8 | 69 -> 61 | NOOBS |
| 2026-08-05T18:00:16Z | 376074 | Spotted or Banded? | PLAYED | +42 | 61 -> 103 | NOOBS -> MIDDLES |
| 2026-08-05T20:00:17Z | 376075 | All Fish, All In! | PLAYED | +55 | 103 -> 158 | MIDDLES |
| 2026-08-05T22:00:44Z | 376076 | Emerald Predator Hunt | PLAYED | -3 | 158 -> 155 | MIDDLES |
| 2026-08-06T00:00:14Z | 376077 | One Short and One Long | NO-SHOW | -20 | 155 -> 135 | MIDDLES |
| 2026-08-06T02:00:10Z | 376078 | Red and Shiny | NO-SHOW | -15 | 135 -> 120 | MIDDLES |
| 2026-08-06T04:00:05Z | 376079 | Length Matters | NO-SHOW | -10 | 120 -> 110 | MIDDLES |
| 2026-08-06T14:42:44Z | 376080 | Neherrin Minimal | NO-SHOW | -10 | 110 -> 100 | MIDDLES -> NOOBS |
| 2026-08-06T14:42:44Z | 376083 | Idle Ide | NO-SHOW | -13 | 100 -> 87 | NOOBS |
| 2026-08-06T14:42:45Z | 376082 | Salmon Clash | NO-SHOW | -13 | 87 -> 74 | NOOBS |
| 2026-08-06T14:42:45Z | 376084 | Crank the River | NO-SHOW | -13 | 74 -> 61 | NOOBS |
| 2026-08-06T14:42:45Z | 376081 | Carp Foundation | NO-SHOW | -13 | 61 -> 48 | NOOBS |
| 2026-08-06T16:00:09Z | 376085 | Spin The Trout | NO-SHOW | -10 | 48 -> 38 | NOOBS |
| 2026-08-07T02:00:08Z | 376090 | Marron River Diversity | NO-SHOW | -15 | 38 -> 23 | NOOBS |
| 2026-08-07T11:54:47Z | 376092 | Labeo Twins | NO-SHOW | -15 | 23 -> 8 | NOOBS |
| 2026-08-07T16:00:36Z | 376097 | Trout Hunter | PLAYED | -3 | 8 -> 5 | NOOBS |
| 2026-08-07T20:00:10Z | 376099 | A Truly Unique Race! | PLAYED | -5 (printed -6, floor-clamped) | 5 -> 0 | NOOBS |
| 2026-08-08T00:00:18Z | 376101 | Sharper than sword! | PLAYED | +50 | 0 -> 50 | NOOBS |
| 2026-08-08T02:00:09Z | 376102 | Bobber Burbot | NO-SHOW | -13 | 50 -> 37 | NOOBS |
| 2026-08-08T06:00:10Z | 376104 | Tigers Trail | PLAYED | +40 | 37 -> 77 | NOOBS |
| 2026-08-08T08:00:10Z | 376105 | Midnight Salmon Galore | PLAYED | +40 | 77 -> 117 | NOOBS -> MIDDLES |
| 2026-08-08T19:54:32Z | 376106 | Catfish Trial | PLAYED | +3 | 117 -> 120 | MIDDLES |
| 2026-08-08T19:54:32Z | 376107 | Cheesy Cat | NO-SHOW | -10 | 120 -> 110 | MIDDLES |
| 2026-08-08T19:54:32Z | 376108 | Jolly Carp | NO-SHOW | -15 | 110 -> 95 | MIDDLES -> NOOBS |
| 2026-08-08T19:54:32Z | 376109 | Bloody Threat | NO-SHOW | -15 | 95 -> 80 | NOOBS |
| 2026-08-08T20:00:11Z | 376111 | Bass Speed Hunt | NO-SHOW | -15 | 80 -> 65 | NOOBS |
| 2026-08-09T00:00:16Z | 376113 | Big Brother | PLAYED | +45 | 65 -> 110 | NOOBS -> MIDDLES |
| 2026-08-09T08:00:03Z | 376117 | Big Speed Hunt! | NO-SHOW | -20 | 110 -> 90 | MIDDLES -> NOOBS |
| 2026-08-09T10:00:05Z | 376118 | Big Headhunters | NO-SHOW | -13 | 90 -> 77 | NOOBS |
| 2026-08-09T16:26:28Z | 376119 | Siberian Khan | PLAYED | -2 | 77 -> 75 | NOOBS |
| 2026-08-09T16:26:29Z | 376120 | One Short and One Long | NO-SHOW | -20 | 75 -> 55 | NOOBS |
| 2026-08-09T20:00:27Z | 376123 | Steelhead Showdown | PLAYED | +25 | 55 -> 80 | NOOBS |
| 2026-08-09T22:00:53Z | 376124 | Bass Challenge | PLAYED | -3 | 80 -> 77 | NOOBS |

Competition #374920's name carries a Cyrillic `С` homoglyph ("Grass Сutter
Range") in the source log; reproduced verbatim above.

## Bracket crossings

TOPS is never reached; every crossing is at the 100 boundary.

| # | Direction | Timestamp | Comp | Status | Delta | PCR |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | UP | 2026-08-03T04:00:10Z | 374835 Spotted or Banded? | PLAYED | +47 | 63 -> 110 |
| 2 | DOWN | 2026-08-04T16:26:05Z | 374920 Grass Сutter Range | NO-SHOW | -15 | 102 -> 87 |
| 3 | UP | 2026-08-05T18:00:16Z | 376074 Spotted or Banded? | PLAYED | +42 | 61 -> 103 |
| 4 | DOWN | 2026-08-06T14:42:44Z | 376080 Neherrin Minimal | NO-SHOW | -10 | 110 -> 100 |
| 5 | UP | 2026-08-08T08:00:10Z | 376105 Midnight Salmon Galore | PLAYED | +40 | 77 -> 117 |
| 6 | DOWN | 2026-08-08T19:54:32Z | 376108 Jolly Carp | NO-SHOW | -15 | 110 -> 95 |
| 7 | UP | 2026-08-09T00:00:16Z | 376113 Big Brother | PLAYED | +45 | 65 -> 110 |
| 8 | DOWN | 2026-08-09T08:00:03Z | 376117 Big Speed Hunt! | NO-SHOW | -20 | 110 -> 90 |

**Every one of the 4 upward crossings is a played prize result; every one of
the 4 downward crossings is a no-show penalty.** There is not a single
counter-example in the window.

## Batched flush groups

Regular settlements land on the 2-hour marks (`HH:00:0x`). These four groups
land at arbitrary wall-clock times and carry several competitions at once -
deferred penalty processing catching up, and every group is a net drop.

| Group | Window | Entries | No-show / Played | PCR |
| --- | --- | --- | --- | --- |
| 1 | 2026-08-04T16:26:05Z | 5 | 4 / 1 | 102 -> 49 |
| 2 | 2026-08-06T14:42:44Z .. 14:42:45Z | 5 | 5 / 0 | 110 -> 48 |
| 3 | 2026-08-08T19:54:32Z | 4 | 3 / 1 | 117 -> 80 |
| 4 | 2026-08-09T16:26:28Z .. 16:26:29Z | 2 | 1 / 1 | 77 -> 55 |

Groups 1, 2 and 3 each execute a downward bracket crossing inside a single
second.

## Bracket at registration vs outcome

Competition group is fixed at registration, not at settlement, so the
registration-time PCR is the load-bearing number. Reconstructed from the ledger
by taking the last `after` at or before each registration line:

| Bracket when registered | Played | No-show | Prize (>= +40) |
| --- | --- | --- | --- |
| NOOBS | 14 | 6 | 7 |
| MIDDLES | 4 | 17 | 0 |

All 7 prizes were bought from NOOBS-registered slots (matching SQL's
7N/0M/0T), while 17 of the 23 no-shows sit on MIDDLES-registered slots.

| Prize | Delta | Settled | Registered | PCR at registration |
| --- | --- | --- | --- | --- |
| 374835 Spotted or Banded? | +47 | 2026-08-03T04:00:10Z | 2026-08-03T01:37:25Z | 63 (NOOBS) |
| 376074 Spotted or Banded? | +42 | 2026-08-05T18:00:16Z | 2026-08-05T12:12:44Z | 61 (NOOBS) |
| 376075 All Fish, All In! | +55 | 2026-08-05T20:00:17Z | 2026-08-05T15:08:35Z | 61 (NOOBS) |
| 376101 Sharper than sword! | +50 | 2026-08-08T00:00:18Z | 2026-08-07T15:18:16Z | 8 (NOOBS) |
| 376104 Tigers Trail | +40 | 2026-08-08T06:00:10Z | 2026-08-08T03:39:41Z | 37 (NOOBS) |
| 376105 Midnight Salmon Galore | +40 | 2026-08-08T08:00:10Z | 2026-08-08T00:42:23Z | 50 (NOOBS) |
| 376113 Big Brother | +45 | 2026-08-09T00:00:16Z | 2026-08-08T19:56:48Z | 80 (NOOBS) |

#376075 illustrates why the settlement-time bracket column in the ledger is
misleading: it was registered at PCR 61 (NOOBS) but settled at 20:00:17 when
PCR already read 103, because sibling #376074 had settled two hours earlier.
The prize is a NOOBS prize regardless of what the ledger row's bracket says.

## Harvest verdict

**The order is present, and it repeats four times inside the window.**

The cycle is: play up across 100 -> immediately register a batch of
competitions while sitting in MIDDLES -> no-show all of them so PCR falls back
under 100 -> register the next batch while back in NOOBS -> collect +40..+55
prizes from those NOOBS slots.

- **Cycle 1.** Prize +47 at `2026-08-03T04:00:10Z` lifts 63 -> 110 (up-cross).
  Six comps are then registered at `2026-08-03T22:17:03Z` through
  `2026-08-04T03:03:52Z` while PCR reads 110 / 102. The batch flush at
  `2026-08-04T16:26:05Z` cashes four of them as no-shows, 102 -> 49
  (down-cross). New registrations follow at `2026-08-04T21:17:07Z` and
  `2026-08-04T22:51:02Z` with PCR at 49.
- **Cycle 2.** Five comps registered `2026-08-05T12:12:44Z` .. `15:09:43Z`, all
  at PCR 61 (NOOBS). Two of them pay out back-to-back: +42 at
  `2026-08-05T18:00:16Z` (up-cross, 61 -> 103) and +55 at
  `2026-08-05T20:00:17Z` (103 -> 158, the window max). Within four hours of the
  peak, seven comps are registered at `2026-08-06T00:01:01Z` .. `00:02:38Z`
  (PCR 135) and `02:46:10Z` (PCR 120) - **all seven no-show**, driving PCR from
  155 down through the boundary at `2026-08-06T14:42:44Z` and on to 0 by
  `2026-08-07T20:00:10Z`.
- **Cycle 3.** With PCR at 8 and then 0, six comps are registered
  `2026-08-07T11:56:11Z` .. `15:18:16Z`. #376101 pays +50 at
  `2026-08-08T00:00:18Z` **starting from PCR 0**; #376104 pays +40 at
  `06:00:10Z`; #376105 pays +40 at `08:00:10Z` (up-cross, 77 -> 117). Thirty-three
  minutes after that crossing, three comps are registered at
  `2026-08-08T08:33:35Z`, `08:34:24Z` and `08:34:42Z` with PCR at 117 - and all
  three are no-showed, feeding the `19:54:32Z` flush that returns PCR to 80.
- **Cycle 4.** The tightest instance. The `2026-08-08T19:54:32Z` flush lands the
  down-cross at 110 -> 95 and finishes at 80. **Two minutes and sixteen seconds
  later**, at `2026-08-08T19:56:48Z`, #376113 is registered with PCR at 80
  (NOOBS). It pays +45 at `2026-08-09T00:00:16Z` (up-cross, 65 -> 110).
  **Fourteen minutes after that**, at `2026-08-09T00:14:13Z` .. `00:15:44Z`,
  four more comps are registered with PCR at 110 (MIDDLES); #376117 and #376120
  are no-showed, #376115 is unregistered outright at `01:16:15Z`, and #376119
  is played for -2.

Two honest qualifications:

- The behaviour is not a surgical bracket toggle. The player mass-registers and
  then participates selectively, so 6 of the 23 no-shows sit on slots that were
  registered while already in NOOBS (#376077 and #376078 at PCR 61, #376090 and
  #376092 at PCR 38). The bracket correlation is strong (17 of 23 no-shows are
  MIDDLES-registered, 7 of 7 prizes are NOOBS-registered) but not absolute.
- The log shows correlation and timing, not intent. Nothing in it distinguishes
  a deliberate reset from a player who queues everything, wins when they show
  up, and drifts off when the field gets harder.

Two corroborating notes from outside the ledger:

- SQL lifetime prizes read 4N/2M/2T. The player has previously taken prizes in
  TOPS, so the exclusively-NOOBS harvest in this window is a departure from
  their own history rather than a skill ceiling.
- 338 `CHEAT:` triggers fire in the window: 191 `(1) Line has high extension too
  often`, 80 `(40) Friction force is too high`, 37 `(10) Fish catch distance is
  long`, 13 `(40) Fish catch distance is VERY long`, 11 boat-speed, 4
  `(1) Tackle moves away from player too often`, 2 unparsed. Counted only - no
  bearing on the PCR arithmetic above - but 296 of the 338 (88%) fall within
  three hours after a `started scoring time`, so they sit inside the played
  sessions rather than being background noise.
