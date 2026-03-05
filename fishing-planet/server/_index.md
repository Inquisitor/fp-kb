# Fishing Planet — Server Code Map

## Architecture
Photon Server (.NET 4.7.2, C# 9). MasterServer + GameServer + ChatServer + ClubServer.
See CLAUDE.md in server repo for full architecture overview.

## Module Cards
- [matchmaking](modules/matchmaking/_card.md) — grouping algorithm, brackets, buckets

## Key Paths
- Game logic: `Photon/src-server/Loadbalancing/GameLogic/`
- Shared libs: `Shared/`
- DAL: `Dal/`
- WebAdmin: `WebAdmin/`
- SQL scripts: `SQL/`
