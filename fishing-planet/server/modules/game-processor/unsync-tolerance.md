# Unsync Tolerance — how the server survives client/server desync

> Deep dive of `game-processor`. All mechanisms that tolerate or repair client/server state divergence in the fishing layer. Verified against MFT branch code (July 2026) and the FP-38709 epic history.

## Layered model

Requests flow peer → `GameActionAdapter` → `MultiRodGameProcessor` → `GameStateMachine` → `GameProcessor`. Desync defense is layered in the same order: gate → ignore → repair → guard.

### Layer 0 — adapter gating (`GameActionAdapter.ProcessGameAction`)
- Pause gate: while `IsGamePaused`, only `Resume/Pause/Reset/Unboard/RestoreBoatPosition/LeaveLocation` pass (`GameActionCodeExtensions.IsAllowedOnPause`). Repeated violations are answered once, then swallowed (`GameIsPausedErrorSent`).
- `InvalidTransition` is caught and classified as `ErrorCode.GameActionTransitionError`; logging rate-limited to 1/s per peer unless `IsDetailedLogging`.
- `Reset` with null processor is a warn + swallow (not fatal); other opcodes with null processor throw.

### Layer 1 — FSM ignore counters (`GameStateMachine`)
- **Duplicate ignore**: after every successful transition, up to `MaxIgnoreTransitions = 3` repeats of the same transition are silently swallowed.
- **Static per-state ignore** (`StateTransitionsIgnore`, budget `MaxIgnoreStaticTransitions = 7`):
  `Move ← {FightFish, UnHitch}`, `Hitch ← {Move}`, `WithItem ← {UnHitch}`, `FishFight ← {Move}`, `Catch ← {FightFish}`.
  Design rule (FP-39262, Won't Do): only *repeating* transitions may be ignored — ignoring one-shot transitions (`ConfirmBite`, `FinishAttack`) would mask client-only infinite fishing.
- **Initial-state flood tolerance**: up to `MaxIgnoreTransitionsInInitialState = 7` stray transitions while in `Initial` (covers late-action bursts after a cycle ends).
- **Post-reset pre-arm**: every `Reset` pre-arms `FinishMove` to be ignored (the most common trailing client action).

### Layer 2 — repair: `NeedClientReset` + rollback
- Emission window (`TryRaiseNeedClientReset`): only after the machine has had no successful transition for `clamp(2*AvgPing, 2000ms, 10000ms)`, then rate-limited to 1/s (`needClientResetEventInterval`). Averages come from three `QueueIntFilter(10)` windows (ping / inter-op interval / op duration).
- Rollback target (`GameProcessor.Rollback`, ~1518-1569) — each rule is a shipped bug fix:

  | Server state | Client transition   | Rollback to | Fix      |
  |--------------|---------------------|-------------|----------|
  | Initial      | anything            | Initial     | baseline |
  | Cast         | Move / UnHitch      | Initial     | FP-36773 (missed `Water`) |
  | Move         | Throw / Water       | Initial     | FP-38042 (missed `FinishMove`) |
  | Move         | ConfirmBite         | Move        | FP-37453 (skipped `Attack`; logs FishId) |
  | Move         | FinishAttack        | Move        | FP-36774 (skipped `Attack`; logs FishId) |
  | Attack       | UnHitch             | Move        | FP-36776 (stale hitch from prev cycle) |
  | FishFight    | UnHitch             | Move        | FP-38021 (stale hitch from prev cycle) |

- `DoNeedClientReset`: if server is in `Hitch`, fires `ReleaseTackle` first; then `GoToInitial`/`GoToMove`; sends `EventCode.NeedClientReset` with target state, offending transition, slot, `FishingCycle`, and `TerminalTacklePosition` on rollback-to-Move.
- **Fake transitions** (`"fkt"` in the Hashtable, `TransitionHeader.IsFakeTransition`): probes that bypass all ignore paths — an invalid probe immediately triggers rollback. Editor-only simulation hotkeys exist on the client.
- Client half of the protocol is **incomplete** (FP-36584, On Hold): the client `NeedClientReset` handler does not rewind line to `TerminalTacklePosition` on rollback-to-Move, nor take the rod out of water on rollback-to-Initial.

### Layer 3 — entity guards
- **Wrong fish**: `HandleConfirmBite`/`HandleAttackFinished` check `fish.InstanceId == fishId` from the request; mismatch → fish escape stats (`Unsync` reason) + `GoToMove`.
- **FishingCycleId** (`"fC"`): per-rod cast counter; client sends it in every fishing op, server echoes it in every response and event; client drops events with a lower id. This is a *cycle*-granularity generation counter — there is no per-transition state version.
- **Throw identity validation** (`DoBeforeTransition`): client rod id vs server in-hands rod; mismatch → `SendEventRodCantBeUsed` (`RodNotExistOnThrow` / `NoRodInHandsOnThrow` / `AnotherRodInHandsOnThrow`) + throw.
- **Uninitialized processor**: `HandleAccessToUninitializedProcessor` — first hit per slot sends `RodCantBeUsed` (`RodIsUnequippedUnsync` / `GameProcessorIsNotInitialized`) and throws `InvalidOperationException`; later hits throw the lighter `InvalidTransition`. Latch cleared on next `Throw`/`Reset` for the slot.
- **Inventory-unsync**: chum referencing a nonexistent item and `PutRodOnStand` without processor produce `!INVENTORY-UNSYNC!` errors (first one reported, then muted).
- **Lifecycle resets**: `ResetState` on leave-location/tournament-end (gated to Idle slots after FP-36278), `Teleport` resets non-Initial/non-Catch FSMs, `Unload` reports leaving-in-impossible-state to anti-cheat.

## Protocol gotchas (transport layer)
- Opcode → transition mapping is **by enum name** (`Enum.Parse(typeof(Transitions), actionCode.ToString())`); values do not match. Server-only transitions (`Attack`, `HookFish`, `AttachItem`, `LoseItem`, `ReleaseTackle`) have no opcodes.
- The request `Hashtable` is **cleared and repopulated in place** by handlers (`transitionData.Clear()` in `DoAfterTransition`), then echoed back as `GameActionData`. Request and response share one object.
- Short string keys with **collisions by context**: `"iR"` = RodId vs IsReeling; `"iF"` = FeederId vs IsForced; `"b"` = AnyBreaks (S→C) vs boat type (C→S).
- On error the response carries `ReturnCode`/`DebugMessage` and **no** `GameActionData`; slot + cycle + opcode are always echoed for correlation.

## Known gaps (open in FP-38709, July 2026)
- Reconnect/room-change lifecycle family: FP-39270, FP-39275..FP-39278 (stale client rods spam a fully-reset server; "Access non-initialized game processor").
- End-of-time with rods on stands: FP-38912, FP-39264 (server resets SM, client keeps sending actions; boat-rent-expiry reset while ashore).
- Fight edge races: FP-36780 (server escape vs client `CatchFish`), FP-36781 (`FightFish` without hooking).
- Client rollback handler completion: FP-36584.

Timing note: fight satellite models (`FishTireModel`, `LineBreaker`, `LeaderCutterOn*`) advance on wall-clock (`Stopwatch`/`UtcNow`) with pause/resume — outcomes are server-computed, but inputs (forces, line length, `isReeling`) and pacing are client-driven.
