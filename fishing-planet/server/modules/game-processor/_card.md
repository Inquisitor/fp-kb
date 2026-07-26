---
module: game-processor
system: fishing
---

# Game Processor
> Per-rod fishing-cycle orchestrator: FSM, action routing, fight models, unsync tolerance. The server half of the future fish-fight sync contract.

## Entry Points
- `GameProcessor` — `Photon/src-server/Loadbalancing/LoadBalancing/GameLogic/GameProcessor.cs` (~5900 LOC per-rod driver; event-driven, no update loop; `DoAfterTransition` is the central dispatcher; rollback patches at ~1518-1569)
- `MultiRodGameProcessor` — same folder (per-peer session: 8 rod slots, `HandsProcessor` pointer, boat/weather/chum/sounder, `RodState` persistence via `CollectPersistedData`/`LoadModels`)
- `GameStateMachine` + `StateTransitions`/`TransitionTargets`/`StateTransitionsIgnore` — same folder (13 states x 35 transitions; whitelist + ignore counters + ping-window `NeedClientReset`)
- `GameActionAdapter.ProcessGameAction` — `DalAdapters/` (opcode -> transition **by enum name** via `Enum.Parse`; mutates request Hashtable and echoes it back as the response)
- `GameClientPeer_Game.HandleGameAction` — `GameServer/` (peer entry; 10s scheduler drives `FightFishInactivityCheck`)

## Key Types
- `TransitionHeader` — ping time + fake-transition probe flag (`"fkt"`)
- `FishTireModel`, `LineBreaker`, `LeaderCutterOn{Slack,Tension}`, `Hooker`, `StrongFishEscapeModel` — fight satellite models (`Photon/src-server/GameModel/`); wall-clock timing, client-supplied inputs
- `AntiCheatFishingManager` — plausibility checks, mostly scoring not rejection (`Photon/src-server/AntiCheat/`)
- `FishingSessionManager` — session rows in Stats DB (`GameLogic/`)

## Dependencies
→ fish-generator (per-rod `FishGenerator`), bite-system (`Pond`/`BiteMap`), licenses, wear, boats, missions (side-channel: `RodInGame = Profile.MissionsContext[Slot]`), anti-cheat, tournaments/FTG
← `GameClientPeer` (all game actions), `TournamentAdapter`/`TogetherAdapter` (`EscapeFishOnRoomEnd`)

## Deep Dives
- [Unsync tolerance](unsync-tolerance.md) — ignore layers, `NeedClientReset` RTT window, rollback table with FP-fix map, entity guards, protocol gotchas

## Related Tasks
- FP-45122: Fish Fight Sync Contract (Server) (epic, To Do) — S0-S6 plan: pins, design round, typed protocol, generation, reconcile, invariants, cleanup
- FP-38709: Unsync Game State Fixes (epic, To Do; 49 children — 33 done, 16 open/on-hold) — desync taxonomy and shipped mechanisms
- FP-44583: client player-core decomposition (phases 0-6); phase 5 (fish-fight) expects a server sync contract from this module

See also: [backlog](backlog.md) | [log](log.md)
