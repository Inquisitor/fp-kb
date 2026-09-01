# PCR trajectory - HIflyfishingGH (PlayStation)

- **PlayerId:** `ebc824ac-464e-4186-b896-a937a0599d6c`
- **Source:** `ebc824ac-464e-4186-b896-a937a0599d6c-hiflyfishinggh.tsv` (338 log lines)
- **Dump window:** 2026-08-10 .. 2026-08-30 (three weeks)
- **Sweep week:** 2026-08-24 .. 2026-08-30
- **Log span actually present:** 2026-08-16T14:20:34Z .. 2026-08-30T20:00:24Z
- **Single client throughout:** IP `97.178.139.157`, Mac `bc3329d0461d` (no second device, no IP change)

## Headline

| Metric | Three weeks | Sweep week |
|---|---|---|
| PCR at start of ledger | 57 | 0 |
| PCR at end | 34 | 34 |
| PCR min / max | 0 / 115 | 0 / 115 |
| Competitions resolved (log) | 58 | 20 |
| Played (log-observed / SQL) | 20 / 25 | 10 / 10 |
| No-shows (log-observed / SQL) | 38 / 45 | 9 / 9 |
| Zero-score finishes (log / SQL) | 4 / 4 | 2 / 2 |
| Prizes, place 1-3 (log / SQL) | 6 / 8 | 4 / 4 |
| Batched flush groups | 8 | 2 |
| Bracket crossings | 4 (2 up, 2 down) | 2 (1 up, 1 down) |
| CHEAT triggers | 164 | 34 |

Log-observed counts fall short of SQL only in the three-week column, and by exactly the amount the missing log head explains. Every sweep-week figure matches SQL to the unit.

## Reading notes

- **The log head is missing, the tail is not.** The dump is supposed to start 2026-08-10 but the earliest line of *any* kind is 2026-08-16T14:20:34Z. Six days of registrations, scoring-starts and CHEAT lines are absent - and those line types are never floor-suppressed, so this is a dump-window artifact, not inactivity. It accounts for the whole three-week gap against SQL: 45-38 = 7 no-shows, 25-20 = 5 plays, 8-6 = 2 prizes, absence -662 against a logged nominal -343, play +414 against a logged +304.
- **The first four ledger rows are the tail of a flush that began before the log.** 2026-08-16T14:20:34Z opens at PCR 57 with four no-show penalties already queued (`#376199`, `#376201`, `#376202`, `#376200`), taking 57 -> 7. Their registrations are in the missing head.
- **The before/after chain is unbroken across all 39 logged rows** - 57 at the first row, 34 at the last, with every row's `before` equal to the previous row's `after`. That continuity is what lets the silent rows below be read confidently.
- **Two rows are clamped** - printed delta and before/after pair disagree. Read the pair:
  - 2026-08-20T13:41:18Z `#376462 Big Brother` printed -20, actual **-9** (9 -> 0)
  - 2026-08-22T12:09:20Z `#376638 Saltwater Giants` printed -15, actual **-10** (10 -> 0)
- **Nineteen resolved competitions produced no ledger line at all, and they split into TWO causes - not one.** This matters: the usual assumption that a silent row means "penalty absorbed by the floor" is only half right here.
  - **(a) Delta genuinely zero - mid-table place.** `#377256 Ideal Accuracy` (place 12, 2026-08-29T18:00:31Z) resolved while PCR was **67**, and `#377333 Lucky 50` (place 11, 2026-08-30T20:00:24Z) resolved while PCR was **34**. Neither is anywhere near the floor, and the chain shows no movement across either. A mid-table finish therefore awards 0 and logs nothing. By the same rule `#376554` (place 12) and `#376725` (place 14) are indeterminate - they resolved at PCR 0.
  - **(b) Penalty absorbed by the floor.** The remaining 14 are no-shows resolving while PCR was already 0 (the 08-20 -> 08-23 stretch). Nominally worth roughly -10..-20 each; actually worth 0.
  - Note the asymmetry this creates: place 18 cost -2 (`#376209`), but places 11, 12 and 14 cost nothing. There is a neutral band in the middle of the table that neither rewards nor punishes.
- Bracket column is evaluated on the **post-award** PCR (NOOBS <= 100, MIDDLES 101-1000, TOPS >= 1001). TOPS is never approached - the highest PCR in the whole window is 115.

## Ledger

Chronological. `PLAYED (pN)` = a `Player started scoring time` line exists for that competition and it finished in place N; `ZERO-SCORE` = scoring started but the result carries no place; `NO-SHOW` = a result with no scoring-start line. Italic rows produced no ledger line and are placed by their `About to process` marker.

### Weeks 1-2 (2026-08-16 .. 2026-08-23)

| Timestamp | Comp ID | Comp name | Status | delta | PCR before->after | bracket |
|---|---|---|---|---|---|---|
| 2026-08-16T14:20:34Z | 376199 | Spotted or Banded? | NO-SHOW | -15 | 57 -> 42 | NOOBS |
| 2026-08-16T14:20:34Z | 376201 | Cats 'n Nightcatchers | NO-SHOW | -11 | 42 -> 31 | NOOBS |
| 2026-08-16T14:20:35Z | 376202 | Steelhead Showdown | NO-SHOW | -11 | 31 -> 20 | NOOBS |
| 2026-08-16T14:20:35Z | 376200 | Crank the River | NO-SHOW | -13 | 20 -> 7 | NOOBS |
| 2026-08-17T14:01:14Z | 376209 | Trout Hunter | PLAYED (p18) | -2 | 7 -> 5 | NOOBS |
| 2026-08-17T20:00:25Z | 376257 | Ideal Accuracy | PLAYED (p2) | +27 | 5 -> 32 | NOOBS |
| 2026-08-17T22:00:27Z | 376258 | A Truly Unique Race! | PLAYED (p1) | +35 | 32 -> 67 | NOOBS |
| 2026-08-18T02:43:39Z | 376260 | No Ruler - No Party | PLAYED (p4) | +40 | 67 -> 107 | **MIDDLES** (up-cross) |
| 2026-08-18T14:32:58Z | 376317 | Bass Speed Hunt | NO-SHOW | -15 | 107 -> 92 | NOOBS (down-cross) |
| 2026-08-18T14:32:58Z | 376315 | One by One | NO-SHOW | -10 | 92 -> 82 | NOOBS |
| 2026-08-18T14:32:58Z | 376316 | Smile, it's Jacunda Time! | NO-SHOW | -15 | 82 -> 67 | NOOBS |
| 2026-08-19T16:00:10Z | 376398 | Kaniq Topwater Rodeo | ZERO-SCORE | -7 | 67 -> 60 | NOOBS |
| 2026-08-19T18:00:27Z | 376399 | Best Five Bass | PLAYED (p4) | +20 | 60 -> 80 | NOOBS |
| 2026-08-19T20:00:20Z | 376400 | Teenies in the Night | NO-SHOW | -13 | 80 -> 67 | NOOBS |
| 2026-08-20T03:35:23Z | 376402 | Ooh, Barracuda | NO-SHOW | -20 | 67 -> 47 | NOOBS |
| 2026-08-20T03:35:23Z | 376401 | Barbel Gent Hunt | NO-SHOW | -10 | 47 -> 37 | NOOBS |
| 2026-08-20T03:35:23Z | 376403 | Strike! And another strike! | NO-SHOW | -13 | 37 -> 24 | NOOBS |
| 2026-08-20T13:41:18Z | 376460 | Lucky Ghost Hunt | NO-SHOW | -15 | 24 -> 9 | NOOBS |
| 2026-08-20T13:41:18Z | 376462 | Big Brother | NO-SHOW | -9 (clamp, printed -20) | 9 -> 0 | NOOBS |
| *2026-08-20T13:41:18Z* | *376463* | *Marlin Tug of War!* | *NO-SHOW* | *(no line - at floor)* | *0 -> 0* | *NOOBS* |
| *2026-08-20T13:41:18Z* | *376461* | *Meaty Fellas* | *NO-SHOW* | *(no line - at floor)* | *0 -> 0* | *NOOBS* |
| *2026-08-20T14:00:09Z* | *376464* | *Gigante Pirañas* | *NO-SHOW* | *(no line - at floor)* | *0 -> 0* | *NOOBS* |
| *2026-08-20T16:10:25Z* | *376465* | *Maku-Maku Carnivores* | *NO-SHOW* | *(no line - at floor)* | *0 -> 0* | *NOOBS* |
| *2026-08-21T02:05:31Z* | *376470* | *All Fish, All In!* | *NO-SHOW* | *(no line - at floor)* | *0 -> 0* | *NOOBS* |
| *2026-08-21T16:00:29Z* | *376554* | *Bass Challenge* | *PLAYED (p12)* | *(no line)* | *0 -> 0* | *NOOBS* |
| 2026-08-22T12:09:20Z | 376557 | Crank the River | PLAYED (p4) | +25 | 0 -> 25 | NOOBS |
| 2026-08-22T12:09:20Z | 376558 | Jolly Carp | NO-SHOW | -15 | 25 -> 10 | NOOBS |
| 2026-08-22T12:09:20Z | 376638 | Saltwater Giants | NO-SHOW | -10 (clamp, printed -15) | 10 -> 0 | NOOBS |
| *2026-08-22T12:09:20Z* | *376639* | *Scores from the bottom* | *NO-SHOW* | *(no line - at floor)* | *0 -> 0* | *NOOBS* |
| *2026-08-22T12:09:20Z* | *376637* | *Bloody Threat* | *NO-SHOW* | *(no line - at floor)* | *0 -> 0* | *NOOBS* |
| *2026-08-22T12:09:20Z* | *376560* | *Red and Shiny* | *NO-SHOW* | *(no line - at floor)* | *0 -> 0* | *NOOBS* |
| *2026-08-22T12:09:20Z* | *376559* | *Marlin Family Reunion!* | *NO-SHOW* | *(no line - at floor)* | *0 -> 0* | *NOOBS* |
| *2026-08-22T16:00:16Z* | *376642* | *Don't bully me, Shark!* | *NO-SHOW* | *(no line - at floor)* | *0 -> 0* | *NOOBS* |
| *2026-08-22T18:00:25Z* | *376643* | *Moonlight Gars* | *NO-SHOW* | *(no line - at floor)* | *0 -> 0* | *NOOBS* |
| *2026-08-22T20:00:16Z* | *376644* | *Cats 'n Nightcatchers* | *NO-SHOW* | *(no line - at floor)* | *0 -> 0* | *NOOBS* |
| *2026-08-23T02:44:53Z* | *376645* | *Falcon Trout Chase* | *ZERO-SCORE* | *(no line - at floor)* | *0 -> 0* | *NOOBS* |
| *2026-08-23T02:44:53Z* | *376646* | *Salmon Clash* | *NO-SHOW* | *(no line - at floor)* | *0 -> 0* | *NOOBS* |
| *2026-08-23T02:44:53Z* | *376647* | *Meaty Fellas* | *NO-SHOW* | *(no line - at floor)* | *0 -> 0* | *NOOBS* |

### SWEEP WEEK - 2026-08-24 .. 2026-08-30

| Timestamp | Comp ID | Comp name | Status | delta | PCR before->after | bracket |
|---|---|---|---|---|---|---|
| *2026-08-24T01:42:04Z* | *376725* | *Big Red Fish* | *PLAYED (p14)* | *(no line)* | *0 -> 0* | *NOOBS* |
| 2026-08-24T13:37:46Z | 376784 | One Short and One Long | PLAYED (p2) | +50 | 0 -> 50 | NOOBS |
| 2026-08-24T16:00:10Z | 376789 | Kaniq Topwater Rodeo | ZERO-SCORE | -7 | 50 -> 43 | NOOBS |
| 2026-08-24T18:00:11Z | 376790 | Giant Grouper Roundup! | NO-SHOW | -20 | 43 -> 23 | NOOBS |
| 2026-08-24T20:00:26Z | 376791 | Best Five Bass | PLAYED (p1) | +30 | 23 -> 53 | NOOBS |
| 2026-08-24T22:00:23Z | 376792 | Zander Zeek Differences | PLAYED (p5) | +17 | 53 -> 70 | NOOBS |
| 2026-08-25T14:14:08Z | 376793 | All Fish, All In! | ZERO-SCORE | -10 | 70 -> 60 | NOOBS |
| 2026-08-25T14:14:08Z | 376794 | Neherrin Minimal | NO-SHOW | -10 | 60 -> 50 | NOOBS |
| 2026-08-27T12:37:42Z | 376943 | Ideal Accuracy | NO-SHOW | -10 | 50 -> 40 | NOOBS |
| 2026-08-28T16:00:14Z | 377133 | One Short and One Long | PLAYED (p1) | +55 | 40 -> 95 | NOOBS |
| 2026-08-28T18:00:22Z | 377134 | Neherrin Minimal | PLAYED (p3) | +20 | 95 -> 115 | **MIDDLES** (up-cross) |
| 2026-08-28T20:00:15Z | 377135 | Don't bully me, Shark! | NO-SHOW | -20 | 115 -> 95 | NOOBS (down-cross) |
| 2026-08-28T22:00:18Z | 377136 | Grass Сutter Range | NO-SHOW | -15 | 95 -> 80 | NOOBS |
| 2026-08-29T02:12:56Z | 377137 | Midnight Salmon Galore | NO-SHOW | -13 | 80 -> 67 | NOOBS |
| 2026-08-29T02:12:56Z | 377138 | Triple Trout! | NO-SHOW | -11 | 67 -> 56 | NOOBS |
| 2026-08-29T16:00:18Z | 377255 | Labeo Twins | PLAYED (p9) | +11 | 56 -> 67 | NOOBS |
| *2026-08-29T18:00:31Z* | *377256* | *Ideal Accuracy* | *PLAYED (p12)* | *(no line - delta 0)* | *67 -> 67* | *NOOBS* |
| 2026-08-30T02:44:36Z | 377259 | Ooh, Barracuda | NO-SHOW | -20 | 67 -> 47 | NOOBS |
| 2026-08-30T02:44:36Z | 377260 | Siberian Khan | NO-SHOW | -13 | 47 -> 34 | NOOBS |
| *2026-08-30T20:00:24Z* | *377333* | *Lucky 50* | *PLAYED (p11)* | *(no line - delta 0)* | *34 -> 34* | *NOOBS* |

## Reconciliation against SQL ground truth

The sweep week reconciles to the unit, which validates the PLAYED/NO-SHOW classification.

| SQL (sweep) | SQL value | Ledger-derived | Match |
|---|---|---|---|
| PCR | 34 | 34 (last row `after`) | exact |
| Reg | 19 | 18 registered in-window + `#376784` (registered 2026-08-23T16:06:37Z, ran into the sweep) | exact |
| Started | 10 | 10 scoring-start lines dated 08-24 or later | exact |
| Zero-score | 2 | `#376789`, `#376793` | exact |
| No-shows | 9 (47.4%) | `#376790 #376794 #376943 #377135 #377136 #377137 #377138 #377259 #377260` | exact |
| Absence | -132 | 20+10+10+20+15+13+11+20+13 = 132 | exact |
| Play | +166 | +50-7+30+17-10+55+20+11 = 166 | exact |
| Net | +34 | +34 | exact |
| Prizes 4 = 4N/0M/0T | 4 | places 1-3: `#376784`(p2) `#376791`(p1) `#377133`(p1) `#377134`(p3), all awarded at NOOBS PCR | exact |
| Played 10N/0M/0T | all NOOBS | no scoring-start line falls inside either MIDDLES window | exact |

Three-week figures differ only by the missing 08-10..08-15 log head. The prize definition that reproduces SQL is **place 1-3** (sweep 4/4 exact; three weeks 6 logged + 2 in the missing head = 8).

## Bracket crossings

Four crossings, all of the 100 boundary. The 1000 boundary is never approached - peak PCR is 115.

| # | Timestamp | Direction | Cause | Comp | Movement |
|---|---|---|---|---|---|
| 1 | 2026-08-18T02:43:39Z | NOOBS -> MIDDLES | **played result** (place 4) | `#376260 No Ruler - No Party` | 67 -> 107 |
| 2 | 2026-08-18T14:32:58Z | MIDDLES -> NOOBS | **no-show** | `#376317 Bass Speed Hunt` | 107 -> 92 |
| 3 | 2026-08-28T18:00:22Z | NOOBS -> MIDDLES | **played result** (place 3) | `#377134 Neherrin Minimal` | 95 -> 115 |
| 4 | 2026-08-28T20:00:15Z | MIDDLES -> NOOBS | **no-show** | `#377135 Don't bully me, Shark!` | 115 -> 95 |

Every upward crossing is caused by a played result; every downward crossing by a no-show. Time spent in MIDDLES: **11h 49m** (excursion A) and **1h 59m** (excursion B) - about 4% of the 14-day logged span. **No competition was registered or started while PCR was in MIDDLES**, in either window. That, not any bracket-timing manoeuvre, is what produces SQL's `Played 25N/0M/0T` and `Prizes 8N/0M/0T`.

## Batched flush groups

Eight groups in which two or more absence penalties resolved in a single same-second batch.

| # | Timestamp | Comps | Movement | Note |
|---|---|---|---|---|
| 1 | 2026-08-16T14:20:34-35Z | 4 no-shows | 57 -> 7 (-50) | tail of a flush begun before the log window |
| 2 | 2026-08-18T14:32:58Z | 3 no-shows | 107 -> 67 (-40) | ends MIDDLES excursion A |
| 3 | 2026-08-20T03:35:23Z | 3 no-shows | 67 -> 24 (-43) | |
| 4 | 2026-08-20T13:41:17-18Z | 4 no-shows | 24 -> 0 (-24 actual, -70 nominal) | drives PCR to the floor; 2 rows silent |
| 5 | 2026-08-22T12:09:20Z | 6 no-shows + 1 win | 0 -> 25 -> 0 | the win lands first, the flush erases it in the same second; 4 rows silent |
| 6 | 2026-08-23T02:44:53Z | 2 no-shows + 1 zero-score | 0 -> 0 | entirely at the floor, no ledger lines |
| 7 | 2026-08-29T02:12:56Z | 2 no-shows | 80 -> 56 (-24) | |
| 8 | 2026-08-30T02:44:36Z | 2 no-shows | 67 -> 34 (-33) | closes the window |

A ninth batch, 2026-08-25T14:14:08Z, pairs one zero-score (-10) with one no-show (-10) - 70 -> 50 - and is excluded above for carrying only a single absence penalty.

## Harvest pattern

**The three-beat harvest order keyed to a bracket boundary is NOT present.** Play does lift PCR and absence does pull it back, but the third beat - prizes deliberately collected in the lower bracket after the pull-back - does not hold up, and the second beat is not a reaction to the first.

The two candidate episodes, in full:

**Excursion A**
- `2026-08-17T20:00:25Z` played p2, +27, 5 -> 32 (prize)
- `2026-08-17T21:51:13Z` .. `2026-08-17T21:51:28Z` registers `#376315`, `#376316`, `#376317`
- `2026-08-17T22:00:27Z` played p1, +35, 32 -> 67 (prize)
- `2026-08-18T02:43:39Z` played p4, +40, 67 -> **107** - crosses into MIDDLES
- `2026-08-18T14:32:58Z` the three comps registered at 21:51 resolve as no-shows: 107 -> 92 -> 82 -> 67

**Excursion B**
- `2026-08-28T12:47:53Z` .. `2026-08-28T12:49:06Z` registers `#377134`, `#377138`, `#377137`
- `2026-08-28T16:00:14Z` played p1, +55, 40 -> 95 (prize)
- `2026-08-28T16:33:47Z` / `16:33:54Z` registers `#377135`, `#377136`
- `2026-08-28T18:00:22Z` played p3, +20, 95 -> **115** - crosses into MIDDLES
- `2026-08-28T20:00:15Z` no-show -20, 115 -> 95 - back in NOOBS after 1h 59m 53s
- `2026-08-28T22:00:18Z` no-show -15, 95 -> 80; `2026-08-29T02:12:56Z` no-shows -13 and -11, 80 -> 56

Why the harvest reading fails:

1. **The no-shows were registered before the boundary was crossed, not after.** In excursion A all three (`21:51:13Z`, `21:51:22Z`, `21:51:28Z` on 08-17) predate the `2026-08-18T02:43:39Z` crossing by nearly five hours. In excursion B, `#377137`/`#377138` were registered at `12:48`/`12:49` and `#377135`/`#377136` at `16:33`, all before the `18:00:22Z` crossing. The descent was already scheduled while PCR was still mid-NOOBS; it cannot be a response to arriving in MIDDLES.
2. **He overshoots the boundary instead of stopping short of it.** Someone managing the 100 line would hold at 95-100. He goes to 107 and to 115, and in excursion B the overshoot comes from a place-3 finish he played out in full.
3. **The prizes cause the rise, they are not the payoff after the fall.** The two largest awards of the window, +55 (`2026-08-28T16:00:14Z`) and +50 (`2026-08-24T13:37:46Z`), are what push PCR upward. In excursion B the prize at `16:00:14Z` *precedes* the crossing at `18:00:22Z`, which precedes the pull-back at `20:00:15Z` - the opposite of the harvest order. No prize is collected after either pull-back within the observed window.

**What is present is a floor-anchored sawtooth, not a boundary-anchored one.** The oscillation is real and large - 57 -> 7 -> 107 -> 0 -> 70 -> 0 -> 115 -> 34 - but its lower attractor is PCR 0, not the 100 line. PCR reaches the floor twice (`2026-08-20T13:41:18Z` and `2026-08-22T12:09:20Z`) and sits there for roughly 46 hours across the 08-20 -> 08-23 stretch, during which 14 no-show penalties land and cost nothing at all.

If one number supports a harvest reading it is this: the largest prize of the sweep week, +50 for place 2 in `#376784 One Short and One Long` at `2026-08-24T13:37:46Z`, was awarded from **PCR 0** - a floor reached by the batched flush at `2026-08-22T12:09:20Z`. That is "absence drags down, prize taken at the bottom" - but the bottom in question is the floor, and NOOBS is the only bracket this account ever competes in, so the prize could not have been won anywhere else. No bracket choice is being exercised.

## Drain route

Rating is shed **overwhelmingly by no-shows**. Genuine defeats are almost nil.

Using the before/after pairs (actual loss after clamping), across the 39 logged rows:

| Route | Loss | Share | Events |
|---|---|---|---|
| No-shows | **327** | **92.6%** | 24 logged rows (+14 more absorbed by the floor at 0 cost) |
| Zero-score finishes | **24** | **6.8%** | 3 logged (`#376398` -7, `#376789` -7, `#376793` -10); a 4th, `#376645`, landed at the floor |
| Genuine defeats | **2** | **0.6%** | 1 row only - `#376209 Trout Hunter`, place 18, -2 |
| **Total** | **353** | | |

Sweep week alone:

| Route | Loss | Share |
|---|---|---|
| No-shows | **132** | **88.6%** |
| Zero-score finishes | **17** | **11.4%** |
| Genuine defeats | **0** | **0%** |
| **Total** | **149** | |

Notes on the split:

- On nominal (printed) deltas the no-show figure is 343 rather than 327; the 16-point difference is the two clamped rows. On SQL's three-week nominal basis absence is -662, the extra 319 being the 14 floor-absorbed penalties in-window plus 7 in the missing log head.
- **He does not lose by losing.** In 20 logged plays exactly one finish was bad enough to cost rating, and it cost 2 points. Every other played competition either gained rating or was a zero-score walk-out. The account's entire downward movement is manufactured by not turning up.
- Zero-score finishes are worth separating as a third route: the player starts scoring, is logged as present, and still takes a penalty (-7 to -10). That is cheaper than a no-show (-10 to -20), which makes the choice to no-show rather than idle out the more expensive one.

## Notable observations

- **164 CHEAT triggers across 20 sessions**, heavily clustered. Breakdown: 35 "Undriven boat moves TOO fast" (peaks of 12.5 against a limit of 5), 31 "Line has high extension too often", 30 "Friction force is too high", 29 "Fish catch distance is long", 19 "Fish catch distance is VERY long" (peaks above 27 against a limit of 6), 9 "Fish goes to player too often when it should not", 4 "Fish is too far from tackle when finish attack", 3 "Line has critical extension too often", 3 "Amount of reeled out line during fight is very low. Probable stamina hack. (Confidence level = 3/4)", 1 "Distance from tackle to attacking fish is long while reeling".
- **The heaviest cheat sessions produce the biggest prizes.** `2026-08-28T14:16:35Z` .. `16:00:13Z`, `#377133 One Short and One Long`: 20 triggers including six "Fish catch distance is VERY long" above 23m, result place 1, +55 - the largest single award in the window. Similarly `2026-08-24T04:29:39Z` `#376784`: 3 triggers, place 2, +50.
- **A 53-minute burst on 2026-08-20T18:01:10Z .. 18:54:38Z produced 30 CHEAT triggers, including all three stamina-hack flags, with no competition running.** It falls between `#376465`'s result (16:10) and `#376470`'s registration (21:16), so it is free-roam play, not tournament play.
- **`#376315 One by One` was registered, unregistered and re-registered within 3 seconds** (`2026-08-17T21:51:13Z`, `21:51:15Z`, `21:51:16Z`) - the only unregister event in the file. It then went unplayed.
- Registrations arrive in tight bursts of 4-6 competitions seconds apart (`2026-08-20T03:37:46Z` .. `03:38:13Z` registers six; `2026-08-24T13:39:59Z` .. `13:40:30Z` registers six). Few are subsequently played. This is bulk enrolment followed by selective attendance, and it is the mechanical origin of both the 64.3% three-week no-show rate and the batched flushes.
- **No `FAILED: Register in competition` lines and no `Registration for tournament Competition #` lines appear in this dump** - every registration used the `Player registered for Competition #` form and none failed.
- Single IP and single MAC across all 20 scoring sessions; no evidence of account sharing or device rotation.
