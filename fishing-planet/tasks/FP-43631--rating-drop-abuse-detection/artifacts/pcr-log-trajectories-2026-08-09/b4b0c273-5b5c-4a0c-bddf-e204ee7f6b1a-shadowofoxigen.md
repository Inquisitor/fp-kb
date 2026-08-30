---
type: trajectory-card
task: FP-43631
player: ShadowOfOxigen
profile_id: b4b0c273-5b5c-4a0c-bddf-e204ee7f6b1a
platform: Steam
source: b4b0c273-5b5c-4a0c-bddf-e204ee7f6b1a-shadowofoxigen.tsv
log_window: 2026-07-30T04:28:39Z .. 2026-08-09T20:05:27Z
---

# ShadowOfOxigen (Steam) - PCR trajectory

## Summary

| Metric | Value |
| --- | --- |
| PCR at first ledger line (before) | 142 |
| PCR at last ledger line (after) | 72 |
| PCR min | 0 (2026-08-09T15:46:00Z) |
| PCR max | 264 (2026-08-06T08:00:09Z) |
| Ledger entries | 40 |
| Played (scoring-time started) | 15 log-wide / 14 with a ledger line |
| No-shows | 26 visible in the ledger / 27 per SQL (one swallowed at the floor) |
| Prizes (place <= 3) | 6 |
| Positive-delta ledger rows | 11 |
| Batched flush groups | 5 |
| Registration lines | 59 raw / 56 distinct competitions (9 later unregistered) |
| CHEAT triggers | 198 |
| Bracket span | MIDDLES <-> NOOBS only; TOPS never reached (max 264) |

Floor-clamp caveat applies. One row disagrees with its printed delta:
2026-08-09T15:46:00Z, #329549, printed `-20` but the pair reads `12 -> 0`,
i.e. an actual `-12` with 8 points swallowed by the clamp. Every other row's
printed delta equals its pair difference, and the pairs chain with no gaps
(142 at the first `before`, 72 at the last `after`).

## Ledger

Bracket = state after the entry. `->` in the bracket column marks a crossing.
Delta is derived from the before->after pair, never from the printed value.

| Timestamp | Comp ID | Comp name | Status | Delta | PCR before->after | Bracket |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-08-02T16:14:56Z | 329462 | Пструговий Перфекціонізм | PLAYED (place 21, Group B) | -3 | 142 -> 139 | MIDDLES |
| 2026-08-03T04:00:12Z | 329477 | Минь і Поплавок | PLAYED (place 8, Group B) | +12 | 139 -> 151 | MIDDLES |
| 2026-08-03T20:04:13Z | 329485 | Кривава Загроза | PLAYED (place 4, Group B) | +32 | 151 -> 183 | MIDDLES |
| 2026-08-04T08:00:08Z | 329491 | Червоні Гіганти | PLAYED (place 3, Group B) PRIZE | +25 | 183 -> 208 | MIDDLES |
| 2026-08-04T14:00:15Z | 329494 | Червоні Титани | PLAYED (place 11, Group B) - NO LEDGER LINE | | | MIDDLES |
| 2026-08-04T18:06:47Z | 329496 | Полюванння на Золоту Рибку | PLAYED (place 4, Group B) | +17 | 208 -> 225 | MIDDLES |
| 2026-08-04T20:00:14Z | 329497 | Стисніть Лина! | PLAYED (place 6, Group B) | +17 | 225 -> 242 | MIDDLES |
| 2026-08-06T08:00:09Z | 329514 | Кривава Загроза | PLAYED (place 6, Group B) | +22 | 242 -> 264 | MIDDLES |
| 2026-08-06T10:00:26Z | 329515 | П’ятеро за Одного | PLAYED (place 30, Group B) | -3 | 264 -> 261 | MIDDLES |
| 2026-08-07T04:51:36Z | 329520 | Потрійний Пструг!! | NO-SHOW | -11 | 261 -> 250 | MIDDLES |
| 2026-08-07T04:51:37Z | 329519 | Сомове Випробування | NO-SHOW | -11 | 250 -> 239 | MIDDLES |
| 2026-08-07T04:51:37Z | 329521 | Ловля Басів для Асів | NO-SHOW | -20 | 239 -> 219 | MIDDLES |
| 2026-08-07T04:51:37Z | 329523 | Лосось Приходить Опівночі | NO-SHOW | -13 | 219 -> 206 | MIDDLES |
| 2026-08-07T04:51:37Z | 329522 | Кренкова річка | NO-SHOW | -13 | 206 -> 193 | MIDDLES |
| 2026-08-07T12:22:52Z | 329527 | Trophy Whiskers | NO-SHOW | -15 | 193 -> 178 | MIDDLES |
| 2026-08-07T12:22:52Z | 329526 | Trophy Carnivores Hunt! | NO-SHOW | -20 | 178 -> 158 | MIDDLES |
| 2026-08-07T12:22:52Z | 329528 | Top Notch Walleye | NO-SHOW | -11 | 158 -> 147 | MIDDLES |
| 2026-08-07T14:42:06Z | 329529 | Атака на Корнішського Джека | NO-SHOW | -20 | 147 -> 127 | MIDDLES |
| 2026-08-07T16:00:07Z | 329530 | Полювання на великій швидкості! | NO-SHOW | -20 | 127 -> 107 | MIDDLES |
| 2026-08-07T18:00:12Z | 329531 | Довжина Має Значення | NO-SHOW | -10 | 107 -> 97 | MIDDLES -> NOOBS |
| 2026-08-07T20:00:11Z | 329532 | Пресвятий Короп! | NO-SHOW | -15 | 97 -> 82 | NOOBS |
| 2026-08-07T22:00:11Z | 329533 | Плямисте Щастя | NO-SHOW | -11 | 82 -> 71 | NOOBS |
| 2026-08-08T00:00:12Z | 329534 | Удар! І ще удар! | PLAYED (place 3, Group A) PRIZE | +30 | 71 -> 101 | NOOBS -> MIDDLES |
| 2026-08-08T09:23:23Z | 329535 | Зустріч родини Марлінів! | NO-SHOW | -20 | 101 -> 81 | MIDDLES -> NOOBS |
| 2026-08-08T09:23:23Z | 329536 | Смугастого чи Плямистого? | NO-SHOW | -15 | 81 -> 66 | NOOBS |
| 2026-08-08T09:23:23Z | 329538 | Сан-Хоакін без кордонів! | NO-SHOW | -11 | 66 -> 55 | NOOBS |
| 2026-08-08T09:23:24Z | 329537 | Мармурова лихоманка на Тибрі | NO-SHOW | -10 | 55 -> 45 | NOOBS |
| 2026-08-08T10:00:08Z | 329539 | Посміхніться, час Якунди! | PLAYED (place 1, Group A) PRIZE | +47 | 45 -> 92 | NOOBS |
| 2026-08-08T12:00:08Z | 329540 | Оце так Лящ! | PLAYED (place 2, Group A) PRIZE | +35 | 92 -> 127 | NOOBS -> MIDDLES |
| 2026-08-08T14:01:28Z | 329541 | Битва на річці Канік | PLAYED (place 14, Group A) | -1 | 127 -> 126 | MIDDLES |
| 2026-08-08T16:00:09Z | 329542 | Довга та Коротка | NO-SHOW | -20 | 126 -> 106 | MIDDLES |
| 2026-08-08T18:00:10Z | 329543 | Шкільний Басс | NO-SHOW | -10 | 106 -> 96 | MIDDLES -> NOOBS |
| 2026-08-08T20:00:12Z | 329544 | Амур з Розмахом | NO-SHOW | -15 | 96 -> 81 | NOOBS |
| 2026-08-09T03:43:43Z | 329545 | Щаслива п'ятдесятка | NO-SHOW | -15 | 81 -> 66 | NOOBS |
| 2026-08-09T03:43:43Z | 329546 | Сомове Випробування | NO-SHOW | -11 | 66 -> 55 | NOOBS |
| 2026-08-09T03:43:43Z | 329547 | Банзай Тунець! | NO-SHOW | -20 | 55 -> 35 | NOOBS |
| 2026-08-09T15:46:00Z | 329548 | Пструговий Перфекціонізм | NO-SHOW | -10 | 35 -> 25 | NOOBS |
| 2026-08-09T15:46:00Z | 329551 | Лінивий В'язь | NO-SHOW | -13 | 25 -> 12 | NOOBS |
| 2026-08-09T15:46:00Z | 329549 | Все включено: Риболовля без меж! | NO-SHOW | -12 (printed -20, clamped) | 12 -> 0 | NOOBS (floor) |
| 2026-08-09T18:00:13Z | 329555 | Морські Гіганти | PLAYED (place 3, Group A) PRIZE | +37 | 0 -> 37 | NOOBS |
| 2026-08-09T20:00:12Z | 329556 | Нічні Рибки | PLAYED (place 2, Group A) PRIZE | +35 | 37 -> 72 | NOOBS |

The #329494 row is listed at its "About to process" timestamp for ordering
only; it has a process marker and a place, but no
`added CompetitionRating` line anywhere in the dump, so delta and PCR are
left blank rather than guessed.

Comp names are logged in whichever locale the processing pass ran under:
#329526/#329527/#329528 appear in Ukrainian at registration and English at
settlement, #329532/#329533 the other way round. Same competitions.

Batched flush groups (several competitions settled in one processing pass):

- 2026-08-07T04:51:36Z / :37Z - 329520, 329519, 329521, 329523, 329522 (261 -> 193, -68)
- 2026-08-07T12:22:52Z - 329527, 329526, 329528 (193 -> 147, -46)
- 2026-08-08T09:23:23Z / :24Z - 329535, 329536, 329538, 329537 (101 -> 45, -56)
- 2026-08-09T03:43:43Z - 329545, 329546, 329547 (81 -> 35, -46)
- 2026-08-09T15:46:00Z - 329548, 329551, 329549 (35 -> 0, -35 visible, more absorbed by the floor)

Every batched flush is all-no-show. No played competition ever settles in a
batch.

## Bracket crossings

Boundary 100/101 (NOOBS <-> MIDDLES) - five crossings.

Downward (MIDDLES -> NOOBS), all caused by no-show penalties:

- 2026-08-07T18:00:12Z - 329531 'Довжина Має Значення', 107 -> 97
- 2026-08-08T09:23:23Z - 329535 'Зустріч родини Марлінів!', 101 -> 81
- 2026-08-08T18:00:10Z - 329543 'Шкільний Басс', 106 -> 96

Upward (NOOBS -> MIDDLES), both caused by prize wins:

- 2026-08-08T00:00:12Z - 329534 'Удар! І ще удар!', place 3, 71 -> 101
- 2026-08-08T12:00:08Z - 329540 'Оце так Лящ!', place 2, 92 -> 127

Boundary 1000/1001 (MIDDLES <-> TOPS): no crossings. PCR never exceeded 264,
so the upper boundary is not in play anywhere in this window.

Both upward excursions are erased within hours by penalties that were already
queued: 101 -> 81 at 2026-08-08T09:23:23Z (9h23m after the first) and
126 -> 106 -> 96 at 2026-08-08T16:00:09Z / 18:00:10Z (4h after the second).
The account is never able to hold MIDDLES once the absence backlog exists.

## Harvest pattern

The three-beat order asked about - play lifts PCR toward a bracket boundary,
absence pulls it back below, prizes then get taken in the lower bracket - is
**only partly present**. Beats two and three are present and tightly timed.
Beat one is not.

What the ledger actually shows is two phases, not a repeating lift-drop cycle.

Phase 1, 2026-08-02T16:14:56Z .. 2026-08-06T10:00:26Z - play only, no
absence at all. Nine competitions played (all Group B), PCR climbs
142 -> 264. This lift moves *away* from the only boundary in reach (100) and
gets nowhere near 1001. It is not a setup for a boundary drop; it is just
five days of ordinary play, and its placements are mediocre
(21, 8, 4, 3, 11, 4, 6, 6, 30 - one podium in nine).

Phase 2, 2026-08-07T04:51:36Z .. 2026-08-09T15:46:00Z - a single one-way
absence collapse, 264 -> 0. Twenty-six visible no-show penalties, plus at
least one fully swallowed at the floor. It crosses 100 downward once at
2026-08-07T18:00:12Z and never climbs back for more than a few hours.

Prize collection sits entirely inside phase 2 and always at the bottom of it.
Three times, a no-show flush ends and a scoring session starts almost
immediately afterwards:

- 2026-08-07T22:00:11Z the run of penalties bottoms at 71; scoring for
  #329534 starts 2026-08-07T22:46:30Z (46 minutes later) - and it is the
  first session ever logged in Group A, from a new IP. Place 3,
  +30 at 2026-08-08T00:00:12Z.
- 2026-08-08T09:23:24Z the four-competition flush ends at 45; scoring for
  #329539 starts 2026-08-08T09:29:11Z - **5 minutes 47 seconds later**.
  Place 1, +47 at 2026-08-08T10:00:08Z. #329540 follows at 10:34:23Z for
  place 2, +35.
- 2026-08-09T15:46:00Z the flush drives PCR to the 0 floor; #329555 and
  #329556 are registered at 2026-08-09T15:49:08Z and 15:49:12Z -
  **3 minutes 8 seconds after hitting the floor** - and both are played and
  both podium (place 3 +37, place 2 +35).

Five of the six prizes are taken at NOOBS-level PCR (before-values 71, 45,
92, 0, 37). The single MIDDLES prize is #329491 at 2026-08-04T08:00:08Z,
before any absence existed. That split reproduces SQL's 5N/1M/0T exactly.

So the honest statement of shape: **there is no "lift toward the boundary,
then dump" cycle here.** There is one sustained sink from 264 to 0 driven
purely by absence, and every prize after the sink is collected at or near the
floor, with scoring sessions starting minutes after each flush. The upward
moves through 100 are the prizes themselves, not a preparatory lift - and the
pending absence backlog immediately ratchets the account back under 100 each
time.

## Registration behaviour

The absence is generated by bulk registration bursts, not by isolated
forgotten entries. Registrations filed within seconds of one another:

- 2026-08-06T15:34:55Z .. 15:35:31Z - 329519..329523 (5), none played
- 2026-08-07T04:53:01Z .. 04:54:34Z - 329526..329531 (6), none played
- 2026-08-07T12:24:09Z .. 12:26:26Z - 329532, 329533, 329535, 329534 (4), one played (#329534, place 3)
- 2026-08-08T01:06:35Z .. 01:07:14Z - 329536..329541 (6), three played (places 1, 2, 14)
- 2026-08-08T12:41:54Z .. 12:42:13Z - 329542..329547 (6), none played
- 2026-08-08T19:31:29Z .. 19:31:36Z - 329548, 329549, 329550 (3), none played
- 2026-08-09T15:49:08Z .. 15:49:12Z - 329555, 329556 (2), both played, both podium
- 2026-08-09T17:49:02Z .. 17:49:08Z - 329557, 329558, 329559 (3), unresolved at window end
- 2026-08-09T20:05:08Z .. 20:05:27Z - 329560..329563 (4), unresolved at window end

Nine registrations were cancelled by an explicit unregister (328255, 329448,
329456, 329486, 329487, 329499, 329505, 329529 re-registered one second
later, 329556 re-registered nine seconds later), so the account does know how
to withdraw. It simply stops doing so from 2026-08-06 onwards.

## Anti-cheat context

198 CHEAT triggers, all inside played scoring sessions. Signature breakdown:

| Count | Weight | Signature |
| --- | --- | --- |
| 67 | (1) | Line has high extension too often |
| 35 | (1) | Attack time is short |
| 30 | (10) | Fish catch distance is long |
| 24 | (10) | Avg fish velocity is too high |
| 13 | (10) | Attack time is VERY short |
| 12 | (40) | Undriven boat moves TOO fast |
| 5 | (10) | Line has critical extension too often |
| 4 | (40) | Last 5 fish have low fighting/passive time ratio on a LONG distance |
| 4 | (40) | Friction force is too high |
| 2 | (40) | Boat moves TOO fast |
| 2 | (10) | Fish has low fighting/passive time ratio |

The heaviest sessions are #329485 (2026-08-03), #329497 (2026-08-04),
#329514 (2026-08-06, which also carries the three "Last 5 fish ... LONG
distance" weight-40 triggers) and #329555/#329556 (2026-08-09, the two
floor-level podiums).

Two network identities, one machine: IP 83.6.201.208 on all nine Group B
sessions, IP 83.6.130.109 on all six Group A sessions, MAC D8BBC1A93EE1
throughout. The IP change coincides exactly with the group change at
2026-08-07T22:46:30Z.

## SQL cross-check

SQL ground truth: PCR 72, reg 41, started 14, zero-score 0, no-shows 27
(65.9%), absence -400, play +305, net -95, prizes 6 = 5N/1M/0T,
played 6N/8M/0T, lifetime 1/4/3.

Agrees:

- PCR 72 - matches the last ledger line exactly (37 -> 72).
- Reg 41 - the dump holds exactly 41 `About to process tournament` markers.
- Prizes 6 = 5N/1M/0T - the six place<=3 finishes are #329491 (played in
  MIDDLES) and #329534, #329539, #329540, #329555, #329556 (all played in
  NOOBS). Exact match.
- No-shows 27 vs 26 ledger rows without a scoring start - see the floor
  artifact below; the arithmetic closes.
- Absence -400 vs -372 summed from the visible no-show pairs. The 28-point
  gap is exactly what the floor ate: 8 points clamped on #329549
  (printed -20, pair 12 -> 0) plus a penalty on a 27th competition that
  produced no ledger line at all because PCR was already 0.

The floor artifact:

- #329550 'Сибірський Хан' was registered 2026-08-08T19:31:36Z alongside
  #329548 and #329549, was never unregistered, and has neither a process
  marker nor a reward line. Its two burst siblings both settled in the
  2026-08-09T15:46:00Z flush that ended at PCR 0. A no-show penalty landing
  on an account already at 0 emits nothing, which is the documented logging
  gap - so the sparse tail of this ledger is an artifact, not a quiet period.
  26 visible + 1 invisible = SQL's 27.

The one-unit gap on the play side:

- The log has 15 `started scoring time` lines; SQL counts 14 started and
  splits them 6N/8M. Group A starts = 6, Group B starts = 9. The extra is
  #329494 'Червоні Титани': scoring started 2026-08-04T12:17:31Z, processed
  2026-08-04T14:00:15Z with place 11, and no `added CompetitionRating` line
  anywhere. It is the single competition that both the SQL played count and
  the PCR ledger omit. Whatever suppressed its reward line also kept it out
  of the SQL play tally.
- SQL play +305 vs +302 summed from the fourteen played pairs
  (+12+32+25+17+17+22+30+47+35+37+35 minus 3+3+1). The 3-point residue is
  most plausibly #329494's own settlement, but the log carries no value for
  it, so it is left unclaimed rather than reconstructed.

Bracket labels line up cleanly here, unlike some sibling cards: SQL's
played 6N/8M matches the Group A / Group B split of the scoring sessions, and
every Group B session ran at PCR 139-264 (MIDDLES) while every Group A
session ran at PCR <= 101 (NOOBS). The group letter in the scoring-start line
tracks the PCR bracket in force at that moment.

"Zero-score 0" is consistent: every process marker for a competition with a
scoring start carries a numeric place. "Lifetime 1/4/3" is outside this
window.
