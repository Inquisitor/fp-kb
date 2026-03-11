# Fishing Planet — Server Code Map

## Architecture
Photon Server (.NET 4.7.2, C# 9). MasterServer + GameServer + ChatServer + ClubServer.
See CLAUDE.md in server repo for full architecture overview.

## Fishing Gameplay → [system overview](modules/_systems/fishing.md)
Cast → bite selection → hook → fight → land. Orchestrator: GameProcessor (5800 LOC).
- [fish-generator](modules/fish-generator/_card.md) — spawning, weight, hooking
- bite-system — probabilistic fish selection, maps, attractors (TODO: create card)

## Missions
- [missions](modules/missions/_card.md) — conditions, interactions, progression (stub)

## Tournaments
- [matchmaking](modules/matchmaking/_card.md) — grouping algorithm, brackets, buckets

## Infrastructure
- [dal](modules/dal/_card.md) — repository-pattern DAL, reflection-based mapping (SQL Server + MongoDB)

## Key Paths
- Game logic: `Photon/src-server/Loadbalancing/GameLogic/`
- Shared libs: `Shared/`
- DAL: `Dal/`
- WebAdmin: `WebAdmin/`
- SQL scripts: `SQL/`
