# Defect Register — fish fight & sync (2026-07-31)

> Deep dive of `fish-fight`. 58 verified defects; IDs: D-x = server fight core, C-x = client, P-x = protocol audit.
> Severity: H = direct desync / gameplay-state loss, M = amplifier / diagnostics blocker, L = hygiene. Branches: server
> NPN20260602, client Win64_CodeBranch r56789. Every claim carries file:line and was verified by direct reading;
> narrative context lives in [fight-tick](fight-tick.md) and [transport-contract](transport-contract.md).

## A. Time & integration (server)

- **D-3 H** Wear not covered by pause: first post-resume update charges the whole paused span at peak forces (3s = -30%
  rod / -7.5% reel; 10s kills the rod + unequips via anyBreaks→GoToInitial). GP:994, WS:242/280, GP:4190-4206
- **D-4 H** Same effect from an ordinary network stall (no Pause op); dt unclamped everywhere. GP:994, ACM:328, LB:163
- **D-1 H** `isFishPassive` skips stamina WITHOUT restarting the stopwatch → first active tick integrates the whole
  passive span at that tick's peak; the flag is a client OR-latch. GP:4161, FTM:130-132
- **D-9 M** Breaker `CoolDown` at value<=0 skips `UpdateTime` → stale priorTime charges a freeze wholesale on the next
  overload (braid leader: full break charge = 0.3s). LB:126-128, LdB:107-109
- **D-2 M** Wear asymmetry: sub-critical fires at most once per call, critical scales with dt; leftover seconds
  discarded. WS:226-234, 242, 155-166
- **C-8 H** Send tempo frame-tied: self-zeroing timer shared by Move/FightFish/UnHitch; fps drop thins the stream, a
  stall severs it — server integrates the hole in one step. Game.cs:777-786

## B. Fight models (server)

- **D-5 H** Strong-fish escape throttle is dead (`lastEscapeCheckTime` never assigned) — rolls at message rate instead
  of 1/s; runs even for "passive" fish. SFE:64, 75
- **D-6 M** Four no-escape `return`s also suppress both tooth cutters (landing net, 5s window, e-reel-pod delay,
  onshore). GP:3999-4020
- **D-12 M** `HandleEscapeFish` accepts a client-declared escape with no validation (recorded as NoStrike). GP:3937-3954
- **D-13 M** `HandleCatchFish` has no distance/line/stamina checks; anti-cheat only scores. GP:4307+
- **D-10 L** `fish` dereferenced unguarded throughout HandleFightFish. GP:3978, 4020, 4082
- **D-11 L** Landing-net check on catch commented out; method dead. GP:4320, ACM:931
- **D-7 L** `escapeStatus = "Strong"` assigned unconditionally after TryEscapeFish. GP:4042

## C. Client send loop

- **C-1 H FIXED client-side 2026-08-10** `lTf` structurally always 0 — unsatisfiable guard (`0 > f && f > 0`).
  Game.cs:803-805/847. Provenance nailed by the client team: correct until r2697, broken by r2698 (2015-03-18,
  commit message "Minor change") which reseeded min/max with zeros — harmless for the three maxima, fatal for the
  minimum; r5359 (2015-11-26) "fixed wrong unhitch" (FP-781) patched the symptom on the wrong side. Dead 10y5m.
  Fix lives in client branch `Unity_Fishing_CodeBranch_Decomposition`, ships with v2, not on prod.
  **Server consequence without a single server edit**: `HitchGenerator.Unhitch` reads `lTf < LowHitchForce &&
  hTf > HighHitchForce`; with `lTf == 0` the left half was ALWAYS true, so "jerk" degenerated into "pull hard".
  After the fix a real slack AND a peak must land in the same 200 ms window -> unhitch-by-jerk becomes RARER.
  The force-the-box path (`CanBreak && hTf > MaxLoad`) is unaffected. Threshold re-tuning is a GD question
  (see backlog); decision pending on whether to hold the client fix until the v2 release.
- **C-7 H** Period latches leak: x4-Move bypasses the accumulator; `IsMovingToRoom` returns after eating the timer;
  suppressed sends still `ResetPeriod()`. Game.cs:201-212, 410-411, 436-438
- **C-9 M** `forceSend` bypasses the gate without resetting it → <150ms pair → second eaten by anti-spam + peaks wiped.
  Game.cs:410, 728-741
- **C-10 M** "Force last move before finish attack" is not actually forced (`forceSend` not passed) — silently dropped ~
  4/5 of the time. client GameActionAdapter.cs:331-333, 356
- **C-14 L** `iPt` sampled, not latched — short pulls invisible; `hRlF` written twice. Game.cs:696, 419+426
- **C-15 H** Rod-on-stand fight path (`GameActionAdapter.FightFishOnPod`) has NO `CanSendGameActions` guard, while
  the in-hands `FightFish` has it as the first line — the pod version keeps sending after the game action is
  finished, with the rod disassembled, or under pause. (client team, 2026-08-10)
- **C-16 H** Same pod path hardcodes three arguments to `false` instead of live values: `isPoolingOrStriking`,
  `isWithLandingNet`, `forceSend`. Server therefore NEVER sees "pulling or striking" from a rod on a stand, and
  `wLn` arrives as a definite `false` — collapsing the third state ("unknown") that exists on the in-hands path.
  Fight on the stand is not silent, but arrives impoverished. (client team, 2026-08-10)
- **C-17 M** `b` (AnyBreaks) is DEAD ON ARRIVAL on the client: decoded into `result.AnyBreaks` and never read by
  anyone. The only wire key of the seven server-written response keys that has no consumer; all others
  (`lBp`, `fRf`, `wLn` echo, `bI`, `rU`, wear triples) are live and load-bearing. (client team, 2026-08-10)

## D. Events & queues (client)

- **C-3 H** Rod-switch event queue drains exactly ONE item; single live caller; rod-on-pod drain call commented out —
  pod events never drain; correct loop sits in the dead #else. FishSpawner.cs:114-137, RodInitialize.cs:610/792
- **C-4 H** `FishHooked` dropped while the prefab loads → 5s tech-hook → client "TechnicalEscape" against a fighting
  server; `FishIsLoading` exists but unchecked. FishSpawner.cs:185-207, 871-981
- **C-13 M** Cycle filter triplicated with divergences; none on `GameActionResult`; slot 0 exempt; dereference before
  guard. FishSpawner.cs:147-156 + clones
- **P-6 M** `EventId` absent on broadcasts and Lite events → gap detection would false-positive. Room.cs:517-532,
  LiteGame.cs:745+
- **P-27 L** `EventId++` before send: a failed send burns a number forever. GCPE:208,216
- **P-30 L** `RodCantBeUsed` and `ItemsUpdated` carry no `FishingCycle`. GCPE:453-474

## E. Responses, errors, duplicates

- **P-2 H** Duplicate-"success": swallowed transition returns `ReturnCode=0` with the client's own Hashtable —
  indistinguishable from success; "server data" = own request. SM:119-120, GP:1941, GAA:173-177
- **P-19 H** Wrong-fish (ConfirmBite/FinishAttack) and missing fish/template (CatchFish) return success while state
  already moved. GP:3562-3577, 3617-3625, 4328-4344
- **C-2 H** `CatchFish` reports success on a suppressed send; retry loop + `ServerConnectionWasNotEstablished` bail-out
  both dead (8 clones). client GAA:390-402, LureStates.cs:1230+
- **C-5 H** Server errors: one Debug log, no rollback anywhere; second subscriber is a TODO stub. FishSpawner.cs:
  455-466, PC:6851-6855
- **C-11 M** On error responses slot/cycle not parsed — everything logs as `fishing[0]`. ORH:763-833
- **P-1 H** Two "no response at all" paths (pause latches) — the operation hangs with no outcome. GAA:36, 71
- **P-18 M** Business vetoes and crashes both 32662; StateTransitionException not distinguished; prod rewrites text to
  "Operation error". GAA:28,147-166; GCPE:175-181
- **P-20 M** `Reset` with uninitialized processor: warn + success. GAA:110-116
- **P-26 M** 4th duplicate: error response but usually no NeedClientReset (2·RTT window just refreshed by the success).
  SM:186-207
- **P-25 M** After TakeFish/ReleaseFish/FinishMove, Initial swallows ANY 7 transitions, not just duplicates. SM:174-184
- **D-8 M** Move dropped unlimitedly during the fight: each FightFish self-loop re-arms budget 7 and silences the desync
  detector. SM:113 + STI:15
- **P-29 L** `IsRealtimePriorityModeOn` set before the Throw transition, never cleared on rejection. GAA:119-120
- **P-21 L** Unguarded casts kill ops: `"gM"` on LeaveLocation, `"iD"` on UpdateFeedings, EAW casts. MRGP:770, 1296-1316

## F. Reconcile & identity

- **P-3 H** Cycle not persisted: after reconnect events carry 0 → the client filter's outer guard
  (`FishingCycleId > 0`) bypasses the whole check for 0, so such events are accepted UNVALIDATED — no freshness
  compare, no `CanReceiveEvents`. Symptom is "accept stale unchecked", NOT "drop" (record corrected 2026-08-05 after
  the client team's re-check; verified FishSpawner.cs:151-155 + clones). PersistentData.cs:84-128
- **P-4 M** On Reset the response echoes the new cycle while the NeedClientReset event carries the stale one. GAA:
  108/171 vs GP:1660
- **P-5 M** FishCaught sent from a deferred lambda, reads cycle at execution time. GP:4413, 4439
- **C-6 M** NeedClientReset handler: no default branch, no log; `transition`/`tacklePosition` decoded and discarded;
  Initial for a pod rod ignored. (Complete for today's {Initial,Move} domain; contract implicit.) PC:4366-4393
- **P-16 M** Type collisions on parameter codes 185/186: string / Hashtable / int bitfield on the same code. GP:
  1616-1617, 1892
- **P-17 M** NRE in `Rollback` for server-internal transitions (Header==null) — masks InvalidTransition. GP:1531
- **C-12 M** Ping echoes `ResponseId` (last response of any kind, zeroed by responses without RequestId), not an event
  id; `GameEvent` has no id at all. PSC_Time.cs:51, GameEvent.cs

## G. Inventory (same audit, feeds the rod-replace hold design)

- **P-9 H** An error response silently discards the accumulated inventory delta. GCPE:157
- **P-13 H** No versioning/sequence on inventory state at all — divergence undetectable, unrecoverable without full
  profile reload. InventoryTracking.cs:463-537
- **P-10/11 M** Empty diff drops the event incl. rodSlot payload; nested transactions discard rodSlot/onCatch. GCPE:
  312-324, 464-465
- **P-12 M** `Upd` always ships value-type defaults (LeaderLength:0, ShimsCount:0...) — "0" indistinguishable from "not
  applicable". InventoryTracking.cs:11-17, 66-125
- **P-14/15 L** Dead DTO fields RodSlot/OnCatch; two wire shapes for `ItemsUpdated` on one event code.
  InventoryTracking.cs:532-533, GCPE:445-466

## I. Inventory mutations vs the fight FSM (server, found 2026-08-10)

> Only `HandleUseRepairKits` gates on slot FSM phase (`state != Initial` -> reject) — the pattern to generalise.
> Existing compensators (`GameProcessor.Rod` setter resets the FSM on rod-object change; `UnloadGameProcessor` on
> broken/unequipped) fire only when `UpdateRodInGameEngine` reaches `ActivateSlot`/`SetupGameProcessor` WITH a
> changed rod object.

- **D-14 M** Parameter setters have no cast/FSM guard at any layer — `SetLeaderLength` (which does not even call the
  existing `CanSetLeaderLength`), `SetActiveQuiverTip`, `SetShimsCount`, `SetClipLength`: applied in any fight state.
- **D-15 H** `RodSetupEquip`: no guard, `EquipSetup` performs raw moves without `Can*` checks, and the handler never
  calls `UpdateRodInGameEngine` — mass equipment replacement of an active slot with no processor sync. Heaviest path.
- **D-16 H** Batch `MoveItems` moves the casted rod itself (`CheckParent` only inspects an item's PARENT) and skips
  `UpdateRodInGameEngine` after a successful batch — live FSM left unsynchronised.
- **D-17 M** `SwapRods` is NOT covered by the compensators: the handler notifies the engine about `replacementItem`
  only, so the outgoing rod keeps a live FSM on its slot.
- **D-18 M** Stand two-step: an equipment op on a stand rod is rejected with `RodCantBeModifiedWhenCasted`, the
  compensation clears `IsCasted` but deliberately skips the FSM reset for stand rods — a repeat of the same op then
  passes cleanly and mutates equipment under a live fight. Works through the four families whose exceptions carry the
  error name (`ReplaceItem`, `CombineItem`, `SubordinateItem`, `SplitAndReplace`); `MoveItem` does not trigger it.
- **D-19 L** `Inventory_Can` holds three `IsCasted` checks, but two of them (`CanPutRodOnStand`,
  `CanTakeRodFromStand`) are DEAD — their only callers live in the fully commented-out `GameClientPeer_MultiRods.cs`;
  the live stand path (`InventoryOperationCode.PutRodOnStand`) checks nothing.

## H. Ping & threading

- **P-23 M** Desync-detector window and TPM toggle fed by raw unvalidated client `PingTime`. GCP:1708, SM:188-195
- **P-8 M** Threading model differs by config between QA (fiber ON) and prod (OFF) — repro asymmetry; `EventId++`/
  `RequestId` non-atomic under ON. Config\*, GCPE:123, 208
- **P-22 L** Ping params read without ContainsKey guards — malformed ping kills the op. GCP:1706-1708
- **P-24 L** Under fiber ON, ping queues behind game actions — RTT conflated with queue depth. GCP:1433-1435
