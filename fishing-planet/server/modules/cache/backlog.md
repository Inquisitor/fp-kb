# Backlog — Cache

- [ ] Document cache dependency graph (`VW_AllCacheDependencies`) — full map of what triggers what
- [ ] Document pond config pipeline: `BaseConfigJson` → SP `GetPondConfig` (merges `RandomizedAcceleratorsJson`) → `PondConfigurations` cache → `MultilingualPonds` cache. Column-level settings bypass JSON via `PondDto` → `MakeEqualTo()`
- [ ] Document `Caches.Refresh()` flow: signal-based refresh, `GetRefreshOrder()` transitive dependency resolution, `PrepareRefresh`/`PerformRefresh` two-phase pattern
- [ ] Map all `GameServerCache` cache entities and their initialization order
