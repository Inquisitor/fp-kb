# Transport Contract — what actually rides the wire

> Deep dive of `fish-fight`. Server = NPN20260602, client = Win64_CodeBranch (r56789). Verified 2026-07-31.

## Client send loop (`Game.cs`, per rod slot)

- `MinUpdateTimeout = .2f`; the gate accumulates `Time.deltaTime` and **zeroes** on fire (no `-= 0.2`) → real rate 4.62
  msg/s @60fps, 4.29 @30fps; below 5 fps the "window" degenerates to a frame. One shared timer for `Move`, `FightFish`,
  `UnHitch` — transitional phases halve each stream.
- Peak accumulator (`UpdateForces`, Game.cs:799-828): maxima of `hTf/hRdF/hRlF/fF`, max `rS`, and OR-latches for
  `p/l/iF/iR/cA/iPS` (+ inverted latches for bobber/lying). The server sees "did X happen at any instant", never a duty
  cycle. `iPt` (pull trigger) is the exception: sampled at send time, not latched.
- Leaks: x4-reeling uses the 3-arg `Move` overload that neither accumulates nor resets; `IsMovingToRoom` bails after
  consuming the timer; a suppressed send still runs `ResetPeriod()` (peaks destroyed untransmitted); `forceSend`
  bypasses the gate without resetting it → guaranteed <150ms pair, second eaten by the 150ms anti-spam.
- `lTf` is structurally always 0 (unsatisfiable guard `0 > f && f > 0`, Game.cs:803-805). Server reads `lTf` only in
  `HandleUnhitch` snag rolls (`lTf < 1 && hTf > 2` — the min clause is thus always true) and telemetry.

## Responses, duplicates, errors (server)

- Success = echo of the SAME request Hashtable: `transitionData.Clear()` in `DoAfterTransition`, handlers write results
  in place, adapter returns it. Control opcodes (Reset/Pause/Resume/LeaveLocation/UpdateFeedings) skip the transition
  block → response is a verbatim request echo.
- **Swallowed duplicate** (ignore budgets: 3 same-transition, 7 static per state, 7 any-in-Initial): `ReturnCode=0` but
  no handler ran and no `Clear()` happened → the client receives its OWN request as "server data". Structurally
  indistinguishable from success.
- Error = `ReturnCode` (32656 InvalidTransition / 32662 everything else incl. preview vetoes) + `DebugMessage`;
  production rewrites the text to `"Operation error. Request ID: N"`. No data block; any inventory delta of the failed
  op is dropped (`ReturnCode == 0` gate).
- Two "no response at all" paths: repeated ops under pause / `CanNotResume` latch → `return null` — the operation hangs
  with no outcome.

## Identity: cycle, EventId, ping echo

- `fishingCycleId` (server) is a per-slot MIRROR of the last accepted client value; issued by the client on `Throw`. Not
  persisted in `RodState` → after reconnect all server events carry cycle **0** until the first accepted transition; the
  client filter (strict `<`, plus `CanReceiveEvents` mute between FinishMove and Throw) drops them — including
  `NeedClientReset`.
- `EventId` increments only on peer-directed events (`GameClientPeerExtensions.SendEvent`, a `new` method); `LocalEvent`
  broadcasts and Lite room events carry none; the counter is per-peer-object (resets on reconnect), non-atomic, and
  burns numbers on failed sends.
- Client ping echoes `ResponseId` = id of the last operation response OF ANY KIND (zeroed by any response without
  `RequestId`) — server stores it into a diagnostics string only. `GameEvent` DTO has no id field at all. "Half-ready
  acking" is not acking anything.
- `NeedClientReset` payload = CURRENT server state as a free string; reachable domain is exactly {"Initial","Move"}
  (Reset path always Initial; Rollback returns Initial/Move/null — null emits nothing). Client's 2-case handler is
  complete today; the domain is not fixed anywhere (not future-proof). Parameter-type collisions: code 185 is string
  here, Hashtable on transitions, int bitfield on FSMEvent.

## Client-side event handling

- `FishSpawner.OnGameEvent`: strict `<` cycle filter (slot 0 exempt; 3 diverging copies of the filter exist;
  `GameActionResult` has none — and on error responses slot/cycle are not even parsed → `fishing[0]`).
- Rod-switch deferral queue (`#define ROD_EVENTS_QUEUE`): drain (`ProcessWaitingEvents`) dequeues EXACTLY ONE action;
  single live caller (`RodInitialize.cs:610`); rod-on-pod call site commented out → pod events never drain; the correct
  `for` loop sits in the dead `#else` branch.
- `FishHooked` arriving while the fish prefab is still loading (Addressables) is dropped with a Debug log → fish stays
  `Undefind` → 5s tech-hook → client sends `EscapeFish("TechnicalEscape")` against a server mid-fight. `FishIsLoading`
  flag exists but is not consulted.
- Server errors: one Debug log, zero rollback; the second subscriber is a TODO stub. `CatchFish` reports success even
  when the send was suppressed by anti-spam; the retry loop and the `ServerConnectionWasNotEstablished` bail-out are
  both dead (8 clones across tackle families).

## Threading

`IsRequestFiberEnabled` (application-scoped, read at startup): **True** in
test/cbt/pstest/xbtest/mobtest/yellowtest/dima configs, default **False** on prod. When ON, non-broadcast ops run on a
per-peer PoolFiber while RaiseEvent/Get/SetProperties/ChangeGroups stay on the receive thread → `EventId++`/`RequestId`
races become real, and Ping queues behind game actions (RTT conflated with queue depth). QA and prod run different
concurrency models.
