---
status: stub
---

# Caching

## Entry Points
- `Caches` — `Shared/SharedLib/Caching/Caches.cs` (cache registry, refresh orchestration)
- `GameServerCache` — `Shared/SharedLib/Config/GameServerCache.cs` (pond, location, item caches)

## Key Types
- `CachedEntity<T>` — single cache entry with load function + refresh
- `CachedEntityDependenciesDto` — dependency declaration (from `VW_AllCacheDependencies`)

## Dependencies
- → DAL (data loading via DalFactory providers)
- ← GameServer, MasterServer, WebAdmin (all consumers)

## Deep Dives
(none yet)

## Related Tasks
- FP-43334 — review revealed non-obvious pond config pipeline (2026-04-15)
