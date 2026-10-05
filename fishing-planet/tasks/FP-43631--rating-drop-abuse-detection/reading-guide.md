---
title: FP-43631 — how to read a trajectory card
purpose: What the operator looks for when deciding a case from a card, with the cases that taught it. Companion to methodology.md step 5.
jira: https://fishingplanet.atlassian.net/browse/FP-43631
---

# How to read a trajectory card

All times are UTC, written 22:00Z. Brackets: NOOBS 0-100, MIDDLES 101-1000, TOPS 1001+.

## The one question

Did the player lower his rating on purpose and take prizes at the lowered rating? Absences alone
are not the offence. A prize alone is not the offence. The offence is the pair, in that order.

## Reading the columns

- **`Comp start` against `Registered`.** Registrations made seconds apart are one batch. Note when
  the batch was placed: before the previous competition ended, in the minute its reward was
  applied, hours ahead, or a minute before the start.
- **`Applied`.** A reward or penalty applied within seconds of the competition's end means the
  player was online at that moment. Applied hours later means he was offline and it waited for his
  next login. Several rows applied in the same second are one login, not several decisions.
- **`Online`.** Minutes of game-server presence inside the competition window. 100-120 on a
  NO-SHOW row: he was in the game the whole time and did not enter. 0: he was not in the game.
  The column does not say when inside the window; check the sessions file if it matters.
- **`RegPCR` is blind for batches.** One value is stamped on every slot of a batch, so it cannot
  show what rating he held when each competition ran. Use the chain.
- **`PCR chain`.** `not logged` on a NO-SHOW at rating 0 is the floor swallowing the penalty; the
  SQL row still counts. The order of rows applied in one second is not the order of events.
- **`StartPCR` on a win** can lag one reward behind the chain when two competitions run back to
  back; for the bracket of a prize trust the chain's "before" value.
- **Rows above the charge window** are context: where he came from. A fall from 635 or 295 into the
  week is part of the descent.
- **The last competition of the week** (20:00Z-22:00Z) can change the cohort and the board. A
  fourth prize taken there brings in an account the earlier run did not show. For a candidate
  still registered there, check after 22:00Z whether he entered.
- **A single odd row** (a zero-score, a very short entry) is worth opening in the raw log: entry
  time after the start, minutes in the game, whether anything was scored.

## Signals, strongest first

1. **Win, shed, win.** A prize, absences back down, the next prize at the bottom of them, repeated
   inside the week. `ShrekUndies`: 6 crossings of the 100 line in 7 days, a podium after 5 of them.
   `ChaChaWuu9588`: back to about 77 before each of 3 wins. `Mariusz1029`: 99 down to 5, then 1st
   at 5.
2. **Registrations placed to be missed.**
   - A batch placed right after a prize and not attended (`UlfsonUlfstroem`, `DCUK420`,
     `BoraxHook`: "took a prize, registered dummies").
   - A batch placed while the prize competition was still running, when he already knew his place
     (`ShrekUndies` 01:48:38 during the 00:00Z competition; `ChaChaWuu9588` 01:43 for 10:00Z).
   - More slots added when the rating had not fallen far enough (`ShrekUndies` 03:34:44, two more
     after one absence left him at 96).
   - More slots added after a bad result in the upper bracket (`BoraxHook`: "got beaten in
     MIDDLES, added registrations to shed harder").
   - A batch at a rating peak, all of it missed (`kojldyn` at 112 and at 115; `HalfSand_` nightly
     6-slot batches; `ArticSquid71` 6 slots every morning, the evening ones never attended).
   - A slot registered a minute before the start and then sat out in the game
     (`Fuzzytacos6571` 15:59:20 for 16:00Z, 120 minutes online).
   - A batch placed within minutes of every reward, all of it missed, and each next entry made at
     100 or below (`thebig35994`: 4 minutes, 3 minutes, the last minute of the competition; 6
     played, 15 missed). The plainest form there is.
   - Inside one batch the cheap slots are played and the slots that cost 20 are missed
     (`mr.GreeM`).
   - A registration 38 seconds after the reward that took him above 100, both slots missed
     (`JoeCoviDodo`).
3. **In the game during the absence**, most telling right before or right after a podium. A run of
   in-game absences that ends at a low rating and is followed by a 1st place needs no further
   proof (`HalfSand_` 5 in a row, 142 down to 77, then 1st; `AmazingQuestHero45` 2 in a row at 120
   and 117 minutes, then 1st at 0). A win followed at once by absences rules out a bad mood.
4. **Hours he never attends.** He registers every day for a block of hours where his own record
   shows no attendance at all (`BoraxHook` 18:00Z-04:00Z, `HalfSand_` 16:00Z-22:00Z, `DCUK420`
   18:00Z-06:00Z). Being really away in those hours is not a defence: it is what makes the slot a
   dependable way to shed.
5. **Cannot hold the bracket above.** Podiums in most games below the line and almost none above
   it (`ELTITOGRAVY6` 6 in 7 against 1 in 11; `ShrekUndies` placed 23rd-39th at 117-142). He knows
   where he wins. "Played honestly for a day, then started shedding" (`ELTITOGRAVY6`).
6. **The cheap shed.** A zero-score entry costs about half an absence. Entered seconds after the
   start, 30 minutes in the game, nothing scored, right after a win (`LaterGENJI`, competition
   160817). A player whose scored entries bring prizes does not score nothing in half of his
   entries by accident (`zezinho_curuja`: 9 of 19 entries empty, 4 prizes in the other 10). An
   entry with no counted fish, an empty place and a non-zero secondary score costs nothing; next
   to a run of zero-score entries it is suspicious (`Panonski_Alas`).
7. **The whole record is the fortnight.** A fresh account whose lifetime prizes were nearly all
   taken in the window is the pattern at its plainest, not a beginner (`AmazingQuestHero45`).
8. **Inside the bottom bracket all week.** Never above 100, most registrations missed, nearly every
   game a prize (`TMRyuko` 5 in 6, `Fuzzytacos6571` 5 in 5, `BoraxHook` 6 in 7). There is no line
   to cross, so count nothing by crossings; rule 9 carries it.
9. **Parking under a line.** Stops at exactly 100 or 1000, or a few points short, and sheds from
   there without crossing. Counters that count crossings read zero. The bracket is taken from the
   rating at the start, so 100 is still the bottom one: `Tho1324` came down from 125 to exactly
   100 by 2 absences and took a 1st place at 100.
10. **Unregistrations.** A player who cancels 10 or more registrations in a fortnight knows how to
    avoid a penalty; his absences are a choice (`zezinho_curuja` 10, `MP_Alan` 13).

## What clears a player

- **Same bracket throughout.** Plays and takes prizes in one bracket and the counterfactual ceiling
  is in that bracket too: absences buy nothing (`anatoly2026`, `silvery_harvest8`, `xFenrir77` in
  TOPS). "Looks like shedding but has gained nothing yet" is WATCH.
- **Climbing out.** Starts at the floor, climbs past 100 and wins there (`ScionHades8639`: 0 to
  146, a 1st at 116). Prizes taken on the way up from a floor he was already on are not prizes
  bought by this week's shedding.
- **Careful single registrations**, made shortly before a competition he then plays.
- **A schedule that explains the absences**: missed slots sit in one block of hours and the rate of
  absence does not rise with the rating. Test three explanations against each other: schedule
  (absence by hour), rating management (absence by rating held), mood (place in the last game
  before the absence).
- **Sheds that are the end of a visit.** Open the sessions file. `STARI40K_YT`: each of 3 sheds
  coincided with leaving the game for a day or two, the last right after a 23rd place; 15
  registrations and 4 visits in the week. Possibly on tilt, plays little: WATCH, and a ban if he
  goes under the line and takes prizes there.
- **Far from any line.** A thousand points clear of a boundary, shedding changes nothing
  (`EZ-Enlightened1`).
- **Keeps entering near the line and losing honestly.** `NotTheTheFace` turned back from about 980
  three times but kept playing at 975-983; a player parking under 1001 would stop entering there.

## Borderline calls

- **Batches decide a close case.** `christdu7340`: net rising, half his prizes 2nd and 3rd places,
  "almost a pity" — banned because the absences came in batches and bracketed the podiums, with
  three 120-minute in-game absences.
- **No batches, exactly on every threshold of the detection query**: WATCH and read first next week
  (`mregan52`).
- **Winning above the line too does not clear him** if he is back below before the next wins
  (`LaterGENJI` won at 121, `ChaChaWuu9588` at 107 and 112).
- **An honest run between two sheds does not clear him.** `kojldyn` climbed 0 to 115 in 4 days of
  real play, then missed 10 slots registered in 2 batches at the peak, back to 0, prize at 0. "He
  proved to himself he could get out, then shed again."
- **A schedule reading is withdrawn when the shape repeats.** `kojldyn` was read as a night player
  one week; the next week the same batch-at-the-peak returned and he was banned. A returning WATCH
  with the same shape is banned even when the counters of rules 4 and 8 do not fire.
- **A ban history sets the term, not the verdict.** `ScionHades8639` and `ChaChaWuu9588` returned
  the same night their bans ended; one was climbing out (WATCH), one was repeating the shape (BAN,
  repeat).
- **Thin volume is not a shelter** when every game is a prize (`Fuzzytacos6571`: 20 registrations,
  5 played, 5 prizes).
- **Offline absences alone are weak.** They become strong by placement: after a prize, at a peak,
  on hours never attended (`DCUK420`: 1 in-game absence, banned on placement).
- **Shedding in the middle of a bracket is watched, not banned.** It may be deliberate: a player can
  work out that absences far from any line are not punished and use them to slow his rise
  (`1st_Demigod`, `anatoly2026`). Keep him on WATCH and ban when the counterfactual ceiling crosses
  into the bracket above, the more so when that repeats week after week.
- **Shedding ahead of the line is banned.** `MP_Alan`: middle bracket only, 724..941, ceiling 1083.
  At the fortnight's peak he placed 2 slots 2 minutes after the reward and sat through both in the
  game, then missed 3 of a batch of 4: 941 down to 866. The schedule reading that cleared him
  earlier is withdrawn. `Panonski_Alas`: hovers at 1000, all prizes below it, ceiling 1098, the
  same shape for months; "on the edge", banned as a repeat because he behaves suspiciously.
- **The week before can decide the case.** `popeye-43`: net +97 and 1 crossing in the week, hard to
  call. A week earlier he took a 2nd place and then missed a batch of 6 night slots, 106 down to 0;
  the week's prizes follow from that floor. Keep the earlier week on the card: without it the
  shedding would not have been established.
- **A WATCH returning with the same shape, or a mild week followed by a plain one, is banned**
  (`JoeCoviDodo`, `mr.GreeM`, `keeno1`).
- **An old ban still sets the repeat term** when the present shedding is plain, even if it predates
  the leaderboards (`Mariusz1029`, ban ended 2025-02-15).
- **A decision against the standing rules** is recorded as an operator decision and re-heard blind
  (`LaterGENJI`, `ChaChaWuu9588`: net rising, 1 crossing).

## Not signals

- The counterfactual ceiling and "prizes below the earned level" set a floor only: they also catch
  cleared players. No case when the count is zero; no conviction from the count alone.
- Entrance fee. Lead time between registration and start. Sitting in the game through a missed
  competition taken by itself (an ordinary strong player does it too). Never stopping to register
  for a bad hour (nobody stops).
- A rename during the week. Track by UserId.
- Anti-cheat triggers: a separate matter.
- Retries to register while banned: the client does not show when the ban ends.

## Board and reward zone

- Read the reward zone first. A candidate still undecided when rewards are distributed keeps his
  reward; do not ban to be safe.
- A ban frees a place and lowers the reward cutoff. Rank the board again after the bans.
- A cleared player in the reward zone receives the reward; record it as decided, not as a miss.
- An account already banned elsewhere for longer than our term is left alone, with no ban-log line.
