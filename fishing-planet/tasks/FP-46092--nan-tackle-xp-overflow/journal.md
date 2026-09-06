---
jira: https://fishingplanet.atlassian.net/browse/FP-46092
title: "NaN values in tackle position cause caught fish to grant over a billion XP"
status: investigating
executor: Stanislav Samoilov
created: 2026-09-06
type: bug
platforms: [Steam]
parent: FP-41583
---
# FP-46092: NaN tackle position overflows fish XP; the affected player is a suspected cheater

## Status
Bug filed 2026-09-06 (FP-46092). Root cause on the server is established from the log arithmetic
(see Summary). The affected player has Denuvo detections (`NoFishFight.dll`, module blocklist) since
2026-09-03, so the compensation question is parked. The evidence pack on his fish fights is pulled and
summarised: from 2026-09-03 the fights collapse to about 5 s regardless of fish weight, the implied
reel speed reaches 99 m/s against a 6 m/s ceiling before, and 62% of fish are landed with stamina
at or above 0.99 (none before). Tables in [artifacts/fight-metrics.md](artifacts/fight-metrics.md),
chart in [artifacts/fight-charts.png](artifacts/fight-charts.png), raw pulls next to them. Server
`cheatLog` was pulled but is treated as noise per the user (the detector spams). Debug profile flags
(127) were switched on for the player on 2026-09-06 while he was fishing; the detailed lines still need
a look. Next: ban decision, then the XP/reward revert and the server fix.

## Summary
On 2026-09-05 16:55 UTC the player landed a 96.9 kg European Sea Sturgeon on a bottom rod that sat on
a boat rod stand; the catch granted 1,073,751,659 XP, level 60 -> 110 plus 161 ranks, 211 level/rank
rewards (5,064,000 silver, 1,084 gold, premium doubling included). A second overflow catch happened on
2026-09-06 (rank 161 -> 340). Players complained to Support about the leaderboard position.

Server-side chain (verified by reproducing the logged numbers bit for bit):
1. `GameProcessor.ExtractParamsFromRequest` accepts `TerminalTacklePosition` from the client without a
   NaN/Infinity check; the client sent `(NaN;NaN;NaN)`.
2. `GameProcessor.HandleAttackFinished` derives `hookDistance` from it and passes NaN to
   `FishExperienceCalculator.SetHookingDistance`.
3. `FishValueModulator.CalculateExperienceRatio`: the fish (force 203) is stronger than the tackle
   (max load 29.5), so the bonus branch interpolates by hooking distance; NaN in, NaN ratio out.
4. `FishExperienceCalculator.GetFinalExperience` casts NaN to `int` in an unchecked context, which
   yields `int.MinValue` (-2147483648) as the tackle bonus.
5. `FishExperienceData.Recalculate` sums in `int`: 6571 - 2147483648 = -2147477077; the premium bonus
   (x1.5) computed from that in float is -1073738560; the second sum wraps to +1073751659.
6. `LevelingManager.IncrementExperience` fills experience to the level cap and pours the remainder
   (966,781,041) into ranks.

The NaN itself: in all six NaN cycles of this player (2026-09-05/06) the rod was put on the rod stand
after the bite was confirmed (client physics had already attached the fish, `SuspendReelClip` -> server
log "Line clip cleared"), and the next message from the client for that rod carried NaN. A client
code trace (Explore agent, local CodeBranch checkout) found no cache or sanitiser on the tackle send
path (`GameActionAdapter.TacklePosition` -> `Hook.transform.position`, a `+=` accumulator in
`HookController.SyncWithSim` that turns any Inf into a sticky NaN), while `PlayerPosition` on the same
messages has a NaN guard. Candidate physics triggers on the stand path (line collapsed to one spring,
stretch constraint disabled, hooked fish body rebuilt) are plausible but unproven; given the Denuvo
detections, memory tampering is the more likely origin. No client ticket filed (no evidence).

Fix direction agreed for the server ticket: invalid tackle coordinates are ignored; when the data for
the tackle bonus is corrupted, no bonus is granted and the fish yields its base XP.

## Player facts (2026-09-06)
- UserId `88236613-788f-4fcc-a8b5-7b229b8ed1fc`, nickname `snxth`, Steam, client 6.0.13 rev. 56736.
- Profile: level 110, rank 340, CheatRating 19762, HighestCheat 100, premium subscription until 2026-10-02.
- Pre-incident state derived from the logs: level 60, 2,531,512 XP.
- Server `cheatLog`: 370 records, dominated by "Fish catch distance is VERY long" (up to 272 m),
  "Boat moves TOO fast" (347 m/s), "Undriven boat moves TOO fast", "Boat updates time is incorrect",
  "Fish goes to player too often", "Line has high extension too often".
- Denuvo: module blocklist detections `NoFishFight.dll`, first 2026-09-03 18:42 (portal time), then
  daily; see [artifacts/denuvo-detections.md](artifacts/denuvo-detections.md).
- Fight profile from `FishFact`, UTC days: 2026-08-30/31 heavy fish (max 293 kg) fought 65-73 s on
  average, max 1148 s; from 2026-09-03 fish of 270-490 kg are landed in 5-14 s on average.
  See [artifacts/fishfact-daily.md](artifacts/fishfact-daily.md).
- Before/after split at 2026-09-03 ([artifacts/fight-metrics.md](artifacts/fight-metrics.md)):

  | Metric (caught fish)                          | before (251) | after (258) |
  |-----------------------------------------------|--------------|-------------|
  | fight duration median, s                      | 12.4         | 5.3         |
  | seconds per kg, p10                           | 0.60         | 0.06        |
  | implied reel speed = hooked distance / fight, max m/s | 6.1  | 98.8        |
  | fights under 10 s with fish over 50 kg        | 0            | 37          |
  | fight median when fish force > 2x tackle load | 68.0 s       | 5.6 s       |
  | stamina at catch median (fishingLog, 14 days) | 0.940        | 0.993       |
  | share landed with stamina >= 0.99             | 0%           | 62%         |

  The cheat is toggled, not permanent: a few post-09-03 fights are honest-looking (e.g. 105 kg
  sturgeon 324 s at stamina 0.77 on 09-06 05:38, 126 kg Nile perch 457 s at stamina 0.54 on 09-06
  06:58), the rest are 5-7 s regardless of weight, including 300 m hooked distances.
- Stamina is computed by the server (`FishTireModel`, a tire timer running during the fight; the
  debug flags add a periodic "Fish stamina: N" line), so stamina 1.0 at catch is a consequence of the
  5-second fight, not an independent signal. The server never requires a tired fish to land it: the
  client reports the catch, and the server anti-cheat's "Fish catch distance" check shows the fish
  20-300 m away at that moment. Independent per-fish discriminators for a future detector: hooked
  distance divided by fight duration against the reel's max speed, and fish-to-player distance at
  the catch.
- Since 2026-09-06 ~16:00 UTC the player fishes with an electric bottom rod (`Sigma F 210 NE`,
  `IsElectricOverload: True`, `ElectricAutoWinding`); its max load (89) narrows the force/load ratio,
  so compare same-tackle fights when charting the last hours.

## Plan / artifacts
- [x] Server root cause and bug ticket FP-46092.
- [x] Daily fight profile from `FishFact` ([artifacts/fishfact-daily.md](artifacts/fishfact-daily.md)).
- [x] Raw pulls: [fishfact-hooked.csv](artifacts/fishfact-hooked.csv) (hooked or caught fish since 2026-08-07),
      [fishingsessionscatch.csv](artifacts/fishingsessionscatch.csv) (fish force, min max load, cycle
      and fight durations), [fishinglog-fights.tsv](artifacts/fishinglog-fights.tsv) (per fight from
      the 14-day `fishingLog`: hooked -> caught/gone, stamina, exp, tire-timer warnings, stand usage,
      cycle report counters). `cheatLog` pulled and dropped as noise.
- [x] Metrics and charts: [analyze_fights.py](artifacts/analyze_fights.py) ->
      [fight-metrics.md](artifacts/fight-metrics.md), [fight-charts.png](artifacts/fight-charts.png);
      interactive page [fight-charts.html](artifacts/fight-charts.html) built by
      [build_charts_html.py](artifacts/build_charts_html.py) (self-contained, open in a browser:
      period chips, date range, min weight, hover tooltips, table view, light/dark).
- [x] Stats side effect of the NaN position: in `FishFact` the four NaN cycles (carp 09-05 10:17,
      sturgeon 16:55, dogfish 17:08, halibut 09-06 14:58) have `CaughtAt` and `Exp` but no `HookedAt`,
      `HookedDistance`, `IsStriking` or `FinishAttackSeconds`: the hooked update never lands when the
      distance is NaN. Candidate Research bullet for FP-46092.
- [x] Detailed `fishingLog` lines after the debug flags (checked 2026-09-06 ~16:55 UTC): periodic
      `Fish stamina: N` from `FishTireModel` (stays at 1 through the fights), `Throw: POSITION/ANGLES`,
      `[CLN]: TakeClick/ReleaseClick` coordinates, `HINT Debug: Start/Finish live bait attack`, one
      `FishGoneSpeed4x Fish escaped on fast reeling`. Nothing that changes the picture; the stamina
      series could be plotted per fight if needed.
- [ ] Decide on the player (ban) and on the XP/reward revert; the revert query and the admin steps
      are in [artifacts/remediation.md](artifacts/remediation.md).
- [ ] Server fix per the ticket's desired outcome.

## Milestones
- 2026-09-06: Incident analysed from the merged log; arithmetic of the overflow reproduced exactly.
  Bug FP-46092 filed (Bugs Sprint, Scrum Team Other, Epic FP-41583). Reference
  `jira_bug_ticket_format.md` extended with content rules. Player identified as a suspected cheater
  (Denuvo + server cheatLog); KB task opened for the fight-history evidence pack.
- 2026-09-06: Evidence pack pulled (FishFact, FishingSessionsCatch, fishingLog fights) and summarised;
  before/after 2026-09-03 the fight duration, implied reel speed and stamina at catch separate cleanly.
  Server cheatLog set aside as noise per the user.
- 2026-09-06 ~22:10 UTC: Global leaderboard rows of the player corrected on Steam PROD Main by the user
  with [artifacts/leaderboard-fix.sql](artifacts/leaderboard-fix.sql) before the weekly finalization at
  00:00 UTC: Experience minus 2,147,483,610 (the two overflow catches less their legit base XP) on the
  Weekly 20260831, Monthly 20260901 and Yearly 20260101 rows, `ExperienceExp` likewise. Result verified:
  4,171,580 / 3,723,990 / 5,315,235, tie-breaker 5,546,439. The player quit at 18:57 UTC; today's logs
  hold no third overflow (167 XP lines, one abnormal). The profile itself still carries the bugged XP
  (level 110, rank 340); the next catch would rewrite `ExperienceExp` from the profile total but not
  `Experience`.
