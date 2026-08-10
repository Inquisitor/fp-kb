# Fight Tick — the ordered server pipeline

> Deep dive of `fish-fight`. All line numbers = branch `NPN20260602`. Verified 2026-07-31 by direct reading. Shorthand:
> GP = GameProcessor.cs, SM = GameStateMachine.cs, WS = WearSystem.cs, FTM = FishTireModel.cs, SFE =
> StrongFishEscapeModel.cs, FG = FishGenerator.cs, LB/LdB = Line/LeaderBreaker.cs, LCS/LCT =
> LeaderCutterOnLineSlack/Tension.cs.

## One FightFish message, in order

| # | Where              | Step                                                                                                                                                                                                                | Early exit    |
|---|--------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------|
| 0 | GP:1908-1918       | Clock advance: `rodConfig.CurrentTime` += wall delta between transitions; `FishFightDuration` += delta (excludes rod-on-stand, INCLUDES pause)                                                                      | —             |
| 1 | GP:1938-1941       | `ExtractParamsFromRequest` (peaks `hTf/hRdF/hRlF`, flags `p/l/iF/iR`, `fC`, `lL`, `rS`, `wLn` on FightFish only); then `transitionData.Clear()` — same Hashtable becomes the response                               | —             |
| 2 | GP:1943            | `CheckAppliedForces` — overload breaks BEFORE the handler: LineBreaker/LeaderBreaker accumulate `dt*rate` (cooldown x0.5); break → `BreakXxxLoseTackle` + `GoToInitial`                                             | break         |
| 3 | GP:3961-3981       | Mission context; anti-cheat feed (`FishForce` may be stale when passive) + `Update(PlayerAction.Fight)`                                                                                                             | —             |
| 4 | GP:3986-3991       | Wear: `UpdateWearSystem(Fight)` — `UtcNow - priorWearTime`, unclamped, pause-blind; `anyBreaks` → `GoToInitial`                                                                                                     | tackle broke  |
| 5 | GP:3993, 4157-4167 | Stamina: `UpdateFishTire` — skipped when `isFishPassive` (stopwatch NOT restarted); echoes `fRf`                                                                                                                    | —             |
| 6 | GP:3995-3999       | Echo `wLn`; landing net → `return` (skips escapes AND cutters)                                                                                                                                                      | landing net   |
| 7 | GP:4005-4020       | No-escape windows, each a bare `return` (also skipping cutters): 5s post-hook (`FishNoEscapePeriod`); e-reel-on-pod delay; "fish onshore within 2 rod lengths"                                                      | windows       |
| 8 | GP:4032-4043       | Escapes: `GenerateEscape` (only `!isFishPassive`; slack gated by `fish.Weight > NoEscapeFishWeight` + per-fish `SlackEscapeDelay`) → `StrongFishEscapeModel.TryEscapeFish()` (runs even for passive; throttle dead) | escape → Move |
| 9 | GP:4089-4129       | Tooth cutters (both skipped when passive): slack cutter (probability grows with slack duration), tension cutter (threshold 0.8 of MaxLoad, roll per second) → `GoToInitial`                                         | cut           |

## Clocks and pause coverage

`HandlePauseGame` (GP:4190-4197) pauses exactly: `fishTireModel`, both cutters, `lineBreaker`, `leaderBreaker`.
Everything else keeps ticking.

| Clock                      | Consumer                                                                   | Paused?                                       | dt clamp?                                                                                  |
|----------------------------|----------------------------------------------------------------------------|-----------------------------------------------|--------------------------------------------------------------------------------------------|
| `Stopwatch`                | FishTireModel                                                              | yes                                           | no (dt>1s only logged); not restarted on passive skip                                      |
| `UtcNow - priorTime`       | Line/LeaderBreaker                                                         | yes (subtracts span)                          | no; `CoolDown` at value<=0 skips `UpdateTime` → stale priorTime charges a freeze wholesale |
| `UtcNow - start - inPause` | both cutters                                                               | yes                                           | single roll per gap, slack-cutter probability inflated by gap                              |
| `UtcNow - priorWearTime`   | **WearSystem**                                                             | **NO**                                        | no — 3s pause under overload = -30% rod / -7.5% reel; 10s kills the rod                    |
| `UtcNow`                   | no-escape windows, StrongFishEscapeModel, `lineSlackStartDate`, anti-cheat | no                                            | no                                                                                         |
| `rodConfig.CurrentTime`    | tension-escape throttle, bite timing                                       | no (pause folds into first post-resume delta) | —                                                                                          |

Peak semantics: every rate consumer multiplies a peak-derived rate by the FULL inter-message dt (FTM:170-188, WS:
242/280, LB:115, LdB:95). Only sub-critical wear keeps a 1s-window max (WS:173-178, 226-234) — and fires at most once
per call regardless of elapsed time.

## Escape decision tree (compressed)

```
landing net?  ──────────────────────────► no escape (return)
master gate: (!DebugNoEscape && !MissionFishBox.NoEscape) || DebugAlwaysEscape
[W1] 5s post-hook window (fishFightStart, wall clock, not paused) ─► return
[W2] e-reel-on-pod delay (set when auto-winding turned off on stand) ─► return
[W3] fish onshore & distanceToTackleOnStrike < rod.Length*2 ─► return
checkLineSlackForFish = weight > NoEscapeFishWeight && slack lasted > SlackEscapeDelay
E1 (only !passive): GenerateEscape — needs slack||isForced; throttled 1s by rodConfig.CurrentTime;
   p = (1 - hookProbability) * MouthStrength * timeModifier(.1/.5/1 by attempt)  [FG:1543-1657]
E2 (even passive): StrongFishEscape — armed at attack when playerForce/fishForce < 0.165;
   guaranteed period 30s, then ramp to certain escape at fishMaxFightTimeout∈[60,300]s;
   throttle DEAD (lastEscapeCheckTime never assigned) → rolls at message rate [SFE:66-87]
no escape && !slack && !forced → ResetEscapeTimes (attempt modifier restarts at .1)
```

## Break decision tree (compressed)

```
CheckAppliedForces (every client transition):
  hTf > line.MaxLoad   → lineBreaker.value += dt/breakTimeout(lineLength); value>=1 = break
  else cooldown x0.5 (skips time update at value<=0!)
  hTf > leader.MaxLoad && !lineOverloaded → leaderBreaker (mono 0.9s / braid 0.3s full charge)
  break → BreakLeader/LineLoseTackle → GoToInitial, line -3m
HandleFightFish tail (skipped when passive or any no-escape return fired):
  slack cutter:   slack && toothSharpness>toughness; p grows with slack duration
  tension cutter: !slack && hTf/MaxLoad >= 0.8; p = toothSharpness - toughness, roll 1/s
Wear (durability -> 0): rod/reel unequip via ApplyWearTo*, line break via Wear reason
```

## Catch path facts

- `HandleCatchFish` (GP:4307-4549): NO distance / line-length / stamina validation; guards only `fish != null` and
  `CurrentFishTemplate != null` — both fail as **silent no-op with ReturnCode=0** while the FSM already advanced to
  `Catch`. `FishCaught` event is emitted from a deferred `EnqueueSafeAction` lambda (cycle id read at execution time).
- `HandleTakeFish`: real validations (cage exists/durability/tournament C&R + capacity) — the only fight-path op that
  rejects with meaningful errors; failure also sends `ErrorEvent` (TakeFishFailed) with compressed cage JSON.
- `HandleReleaseFish`: no validations at all.
- Anti-cheat across the fight is scoring-only (`reportCheat`); the single reject-adjacent call is `ValidateTakeFish`
  followed by an explicit throw.
