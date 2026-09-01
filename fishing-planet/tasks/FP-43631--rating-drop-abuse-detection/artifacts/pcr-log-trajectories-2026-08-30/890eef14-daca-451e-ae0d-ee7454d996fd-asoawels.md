---
title: PCR trajectory - ASOAWELS (Steam)
task: FP-43631
profile_id: 890eef14-daca-451e-ae0d-ee7454d996fd
platform: Steam
source: 890eef14-daca-451e-ae0d-ee7454d996fd-asoawels.tsv
window: 2026-08-10 .. 2026-08-30
sweep_week: 2026-08-24 .. 2026-08-30
---

# PCR trajectory - ASOAWELS (Steam)

Profile `890eef14-daca-451e-ae0d-ee7454d996fd`. Log dump `890eef14-daca-451e-ae0d-ee7454d996fd-asoawels.tsv`, 372 lines.

## Headline

| Metric | Value |
| --- | --- |
| PCR at start of dump | 28 (pre-value of the first ledger line, 2026-08-16) |
| PCR at end of dump | 56 (2026-08-30T20:00:21Z) |
| PCR max | 137 (2026-08-26T14:00:09Z) |
| PCR min | 14 (2026-08-30T14:00:21Z) |
| Ledger lines | 42 |
| No-shows | 20 (all inside the sweep week) |
| Played, resolved | 24 (18 in the sweep week) |
| Prizes (podium finishes) | 9 (8 in the sweep week) |
| Batched flush groups | 3 |
| CHEAT triggers | 207 |

Never reached the PCR floor: the minimum is 14, so no penalty was clamped and every
before -> after pair in this dump agrees with its printed delta. The ledger is complete;
sparseness is not an issue for this profile.

## Reconciliation with SQL ground truth

Every SQL figure reproduces exactly from the ledger, so shape and volume agree.

| Quantity | SQL (sweep) | Ledger (sweep) | SQL (3wk) | Ledger (3wk) |
| --- | --- | --- | --- | --- |
| Registrations resolved in window | 38 | 38 | 44 | 44 |
| Started scoring, resolved | 18 | 18 | 24 | 24 |
| Zero-score finishes | 3 | 3 | 6 | 6 |
| No-shows | 20 | 20 | 20 | 20 |
| Absence total | -277 | -277 | -277 | -277 |
| Play total | +295 | +295 | +305 | +305 |
| Net | +18 | +18 | +28 | +28 |
| Prizes | 8 (7N/1M/0T) | 8 | 9 (8N/1M/0T) | 9 |
| Played by bracket | 16N/2M/0T | 2 Group B | 22N/2M/0T | 2 Group B |

Notes on the joins:

- `Reg` counts only competitions whose result was processed inside the window. The log
  carries 51 registration lines over three weeks (50 distinct comps, `#330574` registered
  twice); five sweep-week registrations were still unresolved at the cut
  (`#330891`, `#330892`, `#330987`, `#330988`, `#330989`) and one earlier registration was
  cancelled (`#330285`, unregistered 2026-08-21T20:37:56Z). 43 distinct sweep-week
  registrations minus the 5 unresolved = 38, matching SQL.
- `started` is 25 in the log but 24 resolved: `#330891 'Lucky 50'` started scoring at
  2026-08-30T20:46:06Z and had not been processed by the dump cut.
- The two Group B starts (`#330575`, `#330658`) are exactly the SQL "2M played", and the
  single Group B podium (`#330658`) is exactly the SQL "1M prize". Inference, not a logged
  fact: **Group B = the MIDDLES-bracket competition slot here**, Group A = NOOBS.

## Ledger

Status legend: PLAYED = a `Player started scoring time` line exists for that comp;
NO-SHOW = a reward line with no scoring-time start; zero-score = played but the processing
marker printed an empty `Place`. Bracket is derived from PCR (NOOBS <= 100, MIDDLES
101-1000, TOPS >= 1001) and shows the transition when the entry crosses a boundary.

### Weeks 1-2 (2026-08-10 .. 2026-08-23)

| Timestamp | Comp ID | Comp name | Status | delta | PCR before->after | Bracket |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-08-16T16:00:19Z | 329883 | Catfish Trial | PLAYED, Place 8 | +11 | 28 -> 39 | NOOBS |
| 2026-08-21T00:00:19Z | 330160 | Big Red Fish | PLAYED, Place 16 | -2 | 39 -> 37 | NOOBS |
| 2026-08-21T07:11:37Z | 330224 | School Bass | PLAYED, Place 2 - PRIZE | +22 | 37 -> 59 | NOOBS |
| 2026-08-21T08:00:06Z | 330227 | Bobber Burbot | PLAYED, zero-score | -7 | 59 -> 52 | NOOBS |
| 2026-08-21T10:00:07Z | 330228 | Catfish Trial | PLAYED, zero-score | -6 | 52 -> 46 | NOOBS |
| 2026-08-21T12:00:11Z | 330229 | Bass Speed Hunt | PLAYED, zero-score | -8 | 46 -> 38 | NOOBS |

Registration `#330285 'Salmon Clash'` (2026-08-21T20:10:52Z) was cancelled by the player
27 minutes later - no penalty, no ledger line.

---

### SWEEP WEEK (2026-08-24 .. 2026-08-30)

| Timestamp | Comp ID | Comp name | Status | delta | PCR before->after | Bracket |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-08-25T06:00:09Z | 330499 | Falcon Trout Chase | PLAYED, Place 2 - PRIZE | +27 | 38 -> 65 | NOOBS |
| 2026-08-25T22:00:08Z | 330507 | Great Halibut Gathering! | PLAYED, Place 10 | +10 | 65 -> 75 | NOOBS |
| 2026-08-26T09:25:32Z | 330508 | One by One | PLAYED, Place 3 - PRIZE | +20 | 75 -> 95 | NOOBS |
| 2026-08-26T14:00:09Z | 330573 | Marron River Diversity | PLAYED, Place 2 - PRIZE | +42 | 95 -> 137 | NOOBS -> MIDDLES |
| 2026-08-26T16:00:08Z | 330574 | Marlin Family Reunion! | PLAYED, zero-score | -10 | 137 -> 127 | MIDDLES |
| *2026-08-26T18:00:15Z* | *330575* | *Teenies in the Night* | *PLAYED, Place 11, Group B* | *no ledger line* | *127 (unchanged)* | *MIDDLES* |
| 2026-08-26T20:00:14Z | 330576 | Grass Сutter Range | NO-SHOW | -15 | 127 -> 112 | MIDDLES |
| 2026-08-26T22:00:14Z | 330577 | Breaking Shad | NO-SHOW | -10 | 112 -> 102 | MIDDLES |
| 2026-08-27T08:11:12Z | 330578 | Sturgeon Showdown! | PLAYED, Place 15 | -2 | 102 -> 100 | MIDDLES -> NOOBS [batch A] |
| 2026-08-27T08:11:13Z | 330648 | Siberian Khan | NO-SHOW | -13 | 100 -> 87 | NOOBS [batch A] |
| 2026-08-27T14:00:08Z | 330654 | Marlin Tug of War! | NO-SHOW | -20 | 87 -> 67 | NOOBS |
| 2026-08-27T18:00:15Z | 330656 | Salmon Clash | PLAYED, Place 1 - PRIZE | +40 | 67 -> 107 | NOOBS -> MIDDLES |
| 2026-08-27T20:00:15Z | 330657 | Grass Сutter Range | PLAYED, zero-score | -8 | 107 -> 99 | MIDDLES -> NOOBS |
| 2026-08-27T22:00:15Z | 330658 | Ideal Accuracy | PLAYED, Place 1 - PRIZE, Group B | +30 | 99 -> 129 | NOOBS -> MIDDLES |
| 2026-08-28T08:35:29Z | 330659 | Sturgeon in the Dark | PLAYED, zero-score | -6 | 129 -> 123 | MIDDLES [batch B] |
| 2026-08-28T08:35:29Z | 330716 | Muskie Topping | NO-SHOW | -11 | 123 -> 112 | MIDDLES [batch B] |
| 2026-08-28T08:35:29Z | 330717 | Bobber Burbot | NO-SHOW | -13 | 112 -> 99 | MIDDLES -> NOOBS [batch B] |
| 2026-08-28T08:35:29Z | 330718 | Amazing Bass Hunt | NO-SHOW | -20 | 99 -> 79 | NOOBS [batch B] |
| 2026-08-28T08:35:29Z | 330719 | Best Five Bass | NO-SHOW | -10 | 79 -> 69 | NOOBS [batch B] |
| 2026-08-28T20:00:15Z | 330725 | Bass Speed Hunt | PLAYED, Place 2 - PRIZE | +42 | 69 -> 111 | NOOBS -> MIDDLES |
| 2026-08-28T22:00:08Z | 330726 | Woohoo Wahoo! | NO-SHOW | -20 | 111 -> 91 | MIDDLES -> NOOBS |
| 2026-08-29T00:00:13Z | 330727 | Dancing with Pike | NO-SHOW | -11 | 91 -> 80 | NOOBS |
| 2026-08-29T02:00:10Z | 330788 | Gigante Pirañas | PLAYED, Place 2 - PRIZE | +42 | 80 -> 122 | NOOBS -> MIDDLES |
| 2026-08-29T17:29:01Z | 330789 | Idle Ide | NO-SHOW | -13 | 122 -> 109 | MIDDLES [batch C] |
| 2026-08-29T17:29:01Z | 330791 | One of us, Two of Asp | NO-SHOW | -10 | 109 -> 99 | MIDDLES -> NOOBS [batch C] |
| 2026-08-29T17:29:01Z | 330792 | Lucky Ghost Hunt | NO-SHOW | -15 | 99 -> 84 | NOOBS [batch C] |
| 2026-08-29T17:29:01Z | 330790 | Steelhead Showdown | NO-SHOW | -11 | 84 -> 73 | NOOBS [batch C] |
| 2026-08-29T22:00:18Z | 330798 | Nile Emperor | PLAYED, Place 6 | +30 | 73 -> 103 | NOOBS -> MIDDLES |
| 2026-08-30T00:00:13Z | 330799 | Big Red Fish | NO-SHOW | -11 | 103 -> 92 | MIDDLES -> NOOBS |
| 2026-08-30T02:00:10Z | 330881 | Sharper than sword! | NO-SHOW | -20 | 92 -> 72 | NOOBS |
| 2026-08-30T04:00:09Z | 330882 | Bloody Threat | NO-SHOW | -15 | 72 -> 57 | NOOBS |
| 2026-08-30T06:00:06Z | 330883 | Tench Clench! | NO-SHOW | -13 | 57 -> 44 | NOOBS |
| 2026-08-30T08:00:07Z | 330884 | Siberian Khan | NO-SHOW | -13 | 44 -> 31 | NOOBS |
| 2026-08-30T12:00:10Z | 330886 | Teenies in the Night | NO-SHOW | -13 | 31 -> 18 | NOOBS |
| 2026-08-30T14:00:21Z | 330887 | Midnight Salmon Galore | PLAYED, Place 19 | -4 | 18 -> 14 | NOOBS |
| 2026-08-30T16:00:16Z | 330888 | Zander Zeek Differences | PLAYED, Place 5 | +17 | 14 -> 31 | NOOBS |
| *2026-08-30T18:00:26Z* | *330889* | *Falcon Trout Chase* | *PLAYED, Place 12* | *no ledger line* | *31 (unchanged)* | *NOOBS* |
| 2026-08-30T20:00:21Z | 330890 | Cats 'n Nightcatchers | PLAYED, Place 3 - PRIZE | +25 | 31 -> 56 | NOOBS |

Italic rows are processing markers with **no** reward line: a mid-table finish that scored
zero rating change emits no ledger entry at all. They are shown for completeness of the
played/no-show classification and carry delta 0.

Still open at the dump cut (registered or started, not yet processed): `#330891 'Lucky 50'`
(started 2026-08-30T20:46:06Z), `#330892`, `#330987`, `#330988`, `#330989`.

## Bracket crossings

Only the 100 boundary is ever touched; PCR peaks at 137, so the 1000 boundary is never
approached and there are no TOPS entries anywhere in the dump.

**Upward (NOOBS -> MIDDLES), 6 crossings - every one caused by a played result:**

| Timestamp | Comp | Cause |
| --- | --- | --- |
| 2026-08-26T14:00:09Z | 330573 Marron River Diversity | PLAYED Place 2, +42 (95 -> 137) |
| 2026-08-27T18:00:15Z | 330656 Salmon Clash | PLAYED Place 1, +40 (67 -> 107) |
| 2026-08-27T22:00:15Z | 330658 Ideal Accuracy | PLAYED Place 1, +30 (99 -> 129) |
| 2026-08-28T20:00:15Z | 330725 Bass Speed Hunt | PLAYED Place 2, +42 (69 -> 111) |
| 2026-08-29T02:00:10Z | 330788 Gigante Pirañas | PLAYED Place 2, +42 (80 -> 122) |
| 2026-08-29T22:00:18Z | 330798 Nile Emperor | PLAYED Place 6, +30 (73 -> 103) |

**Downward (MIDDLES -> NOOBS), 6 crossings - 4 by no-show, 2 by a played result:**

| Timestamp | Comp | Cause |
| --- | --- | --- |
| 2026-08-27T08:11:12Z | 330578 Sturgeon Showdown! | PLAYED Place 15, -2 (102 -> 100) |
| 2026-08-27T20:00:15Z | 330657 Grass Сutter Range | PLAYED zero-score, -8 (107 -> 99) |
| 2026-08-28T08:35:29Z | 330717 Bobber Burbot | NO-SHOW, -13 (112 -> 99) |
| 2026-08-28T22:00:08Z | 330726 Woohoo Wahoo! | NO-SHOW, -20 (111 -> 91) |
| 2026-08-29T17:29:01Z | 330791 One of us, Two of Asp | NO-SHOW, -10 (109 -> 99) |
| 2026-08-30T00:00:13Z | 330799 Big Red Fish | NO-SHOW, -11 (103 -> 92) |

The boundary is crossed 12 times in 4 days. PCR is not drifting - it is being cycled.

## Harvest pattern

**The temporal order is present, and it repeats six times inside the sweep week.**
The cycle is: a podium finish drives PCR above 100 -> a run of no-shows (plus the
occasional zero-score finish) drives it back under 100 -> the next podium is taken while
PCR is back in NOOBS.

| # | Push up (played) | Pull down | Prize taken in the lower bracket |
| --- | --- | --- | --- |
| 1 | 2026-08-26T14:00:09Z +42 -> 137 | 08-26T16:00:08Z .. 08-27T14:00:08Z: 4 no-shows + 2 weak plays -> 67 | 2026-08-27T18:00:15Z `#330656` Place 1 at PCR 67 |
| 2 | 2026-08-27T18:00:15Z +40 -> 107 | 2026-08-27T20:00:15Z zero-score -8 -> 99 | 2026-08-27T22:00:15Z `#330658` Place 1 at PCR 99 |
| 3 | 2026-08-27T22:00:15Z +30 -> 129 | 2026-08-28T08:35:29Z batch: 4 no-shows + 1 zero-score -> 69 | 2026-08-28T20:00:15Z `#330725` Place 2 at PCR 69 |
| 4 | 2026-08-28T20:00:15Z +42 -> 111 | 08-28T22:00:08Z and 08-29T00:00:13Z: 2 no-shows -> 80 | 2026-08-29T02:00:10Z `#330788` Place 2 at PCR 80 |
| 5 | 2026-08-29T02:00:10Z +42 -> 122 | 2026-08-29T17:29:01Z batch: 4 no-shows -> 73 | 2026-08-29T22:00:18Z `#330798` Place 6 at PCR 73 |
| 6 | 2026-08-29T22:00:18Z +30 -> 103 | 08-30T00:00:13Z .. 08-30T14:00:21Z: 6 no-shows + 1 weak play -> 14 | 2026-08-30T16:00:16Z `#330888` Place 5 at PCR 14, then 2026-08-30T20:00:21Z `#330890` Place 3 at PCR 31 |

Every one of the 8 sweep-week podiums was taken with PCR at or below 99, i.e. in NOOBS.
The highest pre-prize PCR in the whole dump is 99 (`#330658`, 2026-08-27T22:00:15Z) - and
that one competition is the single MIDDLES prize, because it was **registered** at
2026-08-27T19:36:45Z while PCR stood at 107 and was assigned Group B, then played and won
after `#330657` had dropped PCR back to 99 two hours earlier at 2026-08-27T20:00:15Z. Time
above 100 is spent almost entirely on no-shows: of the 20 penalties, 8 land while PCR is in
MIDDLES and the rest continue the descent through NOOBS.

Cycle 2 is the tightest instance: the profile spent 2 hours in MIDDLES
(2026-08-27T18:00:15Z -> 20:00:15Z), shed the excess with a single zero-score finish, and
took a Place 1 two hours later.

## Drain route

Rating shed by category (before -> after pairs, not printed deltas):

| Route | Sweep week | Share | Three weeks | Share |
| --- | --- | --- | --- | --- |
| No-shows (20 entries) | -277 | 90.2% | -277 | 83.9% |
| Zero-score finishes (3 / 6 entries) | -24 | 7.8% | -45 | 13.6% |
| Genuine defeats (played, ranked, negative) | -6 | 2.0% | -8 | 2.4% |
| **Total shed** | **-307** | | **-330** | |

Detail:

- **No-shows** - all 20 fall in the sweep week; per-entry penalties run -10 to -20.
- **Zero-score finishes** - sweep: `#330574` -10, `#330657` -8, `#330659` -6 (= -24);
  weeks 1-2 add `#330227` -7, `#330228` -6, `#330229` -8 (= -21).
- **Genuine defeats** - sweep: `#330578` Place 15 -2, `#330887` Place 19 -4 (= -6);
  weeks 1-2 add `#330160` Place 16 -2. Two more ranked finishes (`#330575` Place 11,
  `#330889` Place 12) cost nothing at all.

Rating is drained overwhelmingly by absence, not by losing. Genuine defeat accounts for
2% of the sweep-week loss; the profile essentially never loses a competition it actually
fishes - of 24 resolved played competitions, 9 are podiums and only 3 produce a ranked
loss totalling -8.

## Notable

- **The 100 boundary is cycled, not crossed once.** 6 up, 6 down in 4 days, and each of
  the 8 sweep-week prizes was taken with PCR <= 99.
- **Every upward crossing is a played result; two thirds of the downward ones are
  no-shows.** Nothing pushes PCR up except fishing, and nothing pulls it down except
  not fishing.
- **Batched flush groups (3).** Off-cadence catch-up processing lands several results on
  one timestamp: 2026-08-27T08:11:12-13Z (2 comps), 2026-08-28T08:35:29Z (5 comps),
  2026-08-29T17:29:01Z (4 comps). Batch B alone moves PCR 129 -> 69 in one second.
- **Registration bursts precede the no-show batches.** 2026-08-27T23:03:42-23:04:27Z
  registers `#330717`/`#330718`/`#330719` in 45 seconds - all three are no-showed in
  batch B. 2026-08-28T20:23:37-20:23:55Z registers `#330789`/`#330790`/`#330791`/`#330792`
  in 18 seconds - all four are no-showed in batch C.
- **Zero-delta finishes emit no ledger line.** `#330575` Place 11 and `#330889` Place 12
  were played and processed but produce no `CompetitionRating` entry, the same class of
  logging artifact as a penalty on a floor-clamped account. Ledger row count (42) is
  therefore below processed-competition count (44).
- **No floor clamping in this dump.** PCR min is 14, so before/after pairs and printed
  deltas agree on every line and the SQL totals reproduce exactly.
- **207 CHEAT triggers across the window**, concentrated in the sessions that produce the
  podiums. Top types: friction force too high (78), line high extension too often (57),
  undriven boat too fast (20), fish catch distance VERY long (17). Constant identity
  throughout: IP 84.115.214.28, MAC 9C6B00801695.
- **`#330574 'Marlin Family Reunion!'` was registered, unregistered, re-registered.**
  Registered 2026-08-26T09:28:47Z, unregistered 10:18:35Z, registered again 13:56:36Z,
  then played to a zero-score finish (-10). Compare `#330285` on 2026-08-21, unregistered
  and never re-entered - unregistration is a penalty-free exit the profile does use, which
  makes the 20 no-shows a choice rather than an oversight.
