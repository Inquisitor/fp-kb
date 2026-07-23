# Fishing Planet — Server Code Map

## Architecture
Photon Server (.NET 4.7.2, C# 9). MasterServer + GameServer + ChatServer + ClubServer.
See CLAUDE.md in server repo for full architecture overview.

## Fishing Gameplay → [system overview](modules/_systems/fishing.md)
Cast → bite selection → hook → fight → land. Orchestrator: GameProcessor (5800 LOC).
- [fish-generator](modules/fish-generator/_card.md) — spawning, weight, hooking
- bite-system — probabilistic fish selection, maps, attractors (TODO: create card)

## Inventory
- [equipment-rules](modules/equipment-rules/_card.md) — rod template catalog, leader/rod subtype groups, runtime equip validation, client UI parallel-compatibility caveat

## Missions
- [missions](modules/missions/_card.md) — conditions, interactions, progression (stub)

## Tournaments
- [matchmaking](modules/matchmaking/_card.md) — grouping algorithm, brackets, buckets

## Leaderboards
- [leaderboards](modules/leaderboards/_card.md) — Competitive / Global / Fish boards; per-type Update / UI / Jobs / Rewards pipeline gates

## Shared Game Services
- [rewards](modules/rewards/_card.md) — reward delivery pipeline (items, licenses, products, currency)
- [balance](modules/balance/_card.md) — currency balance mutation + ledger logging primitive (`BalanceHelper`); `preventNegativeBalance` = no downward zero-crossing (stub)
- [reel-of-fortune](modules/reel-of-fortune/_card.md) — daily two-wheel mini-game; per-profile state, AB-test/country gating, premium-spin allocation on subscription grant (stub)

## Chat
- [chat-server](modules/chat-server/_card.md) — Photon Chat app: channel membership, message dispatch/fan-out, Mongo persistence; FP-33074 root causes (membership reorder + channel eviction) + fix design

## Infrastructure
- [dal](modules/dal/_card.md) — repository-pattern DAL, reflection-based mapping (SQL Server + MongoDB)
- [cache](modules/cache/_card.md) — cache registry, refresh orchestration, dependency graph (stub)

## Operations & Admin
- [web-admin](modules/web-admin/_card.md) — ASP.NET MVC admin panel; **umbrella stub** with patterns, gotchas, deep-dive: [embedded-vue-pattern.md](modules/web-admin/embedded-vue-pattern.md) (Vue 3 + TS island for new tools). Per-controller sub-modules TBD (FP-43424 Pass 2/3).
- [data-editing](modules/data-editing/_card.md) — admin table-edit + DataChanges commit-log (audit / replay / restore); read-only-join leak gotcha

## Monetization
- [product-local-prices](modules/product-local-prices/_card.md) — regional pricing: rates, exchange, rounding, beautify
- [local-shop](modules/local-shop/_card.md) — per-pond item shop; LocalShop stores only Price (level/rarity/currency from InventoryItems); Premium ×1.0 / Common ×1.5; pond 119 (FTUE) ×1.0
- [twitch-drops](modules/twitch-drops/_card.md) — Twitch account linking + Drop entitlement delivery; spans linking site / Photon delivery / AsyncProcessor token refresh; no-email capture/backfill + reward gate (epic FP-44593)

## Configuration & Deployment
- [configuration](modules/configuration/_card.md) — per-env / per-component server config; `Source` platform-list semantics, deployment topology, prod reference matrix, canonical `Source` rules

## Key Paths
- Game logic: `Photon/src-server/Loadbalancing/GameLogic/`
- Shared libs: `Shared/`
- DAL: `Dal/`
- WebAdmin: `WebAdmin/`
- SQL scripts: `SQL/`
