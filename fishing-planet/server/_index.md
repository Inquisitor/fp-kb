# Fishing Planet — Server Code Map

## Architecture
Photon Server (.NET 4.7.2, C# 9). MasterServer + GameServer + ChatServer + ClubServer.
See CLAUDE.md in server repo for full architecture overview.

## Fishing Gameplay (1 module, 1 planned) → [system overview](modules/_systems/fishing.md)
Cast → bite selection → hook → fight → land. Orchestrator: GameProcessor (5800 LOC).
- [fish-generator](modules/fish-generator/_card.md) — spawning, weight, hooking
- bite-system — probabilistic fish selection, maps, attractors (TODO: create card)

## Tournaments (1 module)
- [matchmaking](modules/matchmaking/_card.md) — grouping algorithm, brackets, buckets

## Key Paths
- Game logic: `Photon/src-server/Loadbalancing/GameLogic/`
- Shared libs: `Shared/`
- DAL: `Dal/`
- WebAdmin: `WebAdmin/`
- SQL scripts: `SQL/`
