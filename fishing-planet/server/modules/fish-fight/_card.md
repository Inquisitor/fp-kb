---
module: fish-fight
system: fishing
---

# Fish Fight
> The fight loop (stamina, escapes, breaks, tooth cuts, catch) on the server, its client counterpart, and the sync contract between them. Fully event-driven: the server has NO simulation tick — every model integrates wall clock between two accepted client messages carrying PEAK forces.

## Entry Points
- Server pipeline: `CheckAppliedForces` (pre-handler, breaks) → `HandleFightFish` (~GP:3956-4130 in NPN20260602) inside `GameProcessor.DoAfterTransition`; catch: `HandleCatchFish`/`HandleTakeFish`/`HandleReleaseFish`; client-declared escape: `HandleEscapeFish` (no validation)
- Fight models (`Photon/src-server/GameModel/` + `GameLogic/`): `FishTireModel` (stamina), `FishGenerator.GenerateEscape`/`CheckTensionEscape`, `StrongFishEscapeModel` (dead throttle!), `LeaderCutterOnLineSlack/Tension`, `LineBreaker`/`LeaderBreaker`, `WearSystem`
- Client counterpart (Win64_CodeBranch): `FishStates` (fish FSM, 11 states, `Behavior ∈ {Undefind, Hook, Go}`, 5s tech-hook), `FishSpawner` (events, cycle filter, rod-switch queue), `Game` (send loop: 0.2s frame-tied gate, peak accumulator), tackle FSMs (`LureStates`/`FloatStates`/`FeederStates`)

## Key Facts
- Client flag `"p"` (isFishPassive) disables stamina + escape + both tooth cutters in one go; stamina stopwatch keeps running → next active tick integrates the whole passive span at peak force
- dt is unclamped in EVERY integrator; pause covers tire/cutters/breakers but NOT wear (`priorWearTime`) — 3s pause under overload = -30% rod durability
- Lure hooks LOCALLY on the client (path completed); float/feeder hook only on the server `FishHooked` event — asymmetric sensitivity to event loss
- `NeedClientReset` reachable payload domain is exactly {`Initial`, `Move`} — client's 2-case handler is complete today, contract implicit

## Dependencies
→ [game-processor](../game-processor/_card.md) (FSM, routing, unsync layers — see its [unsync-tolerance](../game-processor/unsync-tolerance.md)), fish-generator (fish + escape), anti-cheat (scoring only), licenses (catch verdict)
← client fight stack (see above); TournamentAdapter/TogetherAdapter (`EscapeFishOnRoomEnd`)

## Deep Dives
- [Fight tick](fight-tick.md) — ordered server pipeline, clocks/pause coverage, escape and break decision trees
- [Transport contract](transport-contract.md) — send loop, peak/latch semantics, responses/duplicates/events, cycle & EventId identity
- [Defect register](defect-register.md) — 58 verified defects (D=server fight, C=client, P=protocol) with file:line

## Related Tasks
- FP-45122: Fish Fight Sync Contract (Server) — this module is the D1/D2 ground truth; convention-9 pins committed SRV r16427-r16429 (2026-08-16), scopes in [log](log.md)
- FP-38709: Unsync Game State Fixes — historical desync taxonomy

See also: [backlog](backlog.md) | [log](log.md)
