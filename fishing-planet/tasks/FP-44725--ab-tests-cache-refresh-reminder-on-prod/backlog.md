# FP-44725 Backlog

## Implementation
- [ ] Server: in `HomeController.Create/Update/Destroy`, on success, when `Settings.IsProd` and
  `GetCachesToRefreshByTable(tableName)` is non-empty, return a "needs refresh" flag + the table name
  in the JSON response
- [ ] Server: thin endpoint to trigger refresh-by-table (wraps existing `RefreshServerCache(out _, tableName)`),
  with `AdminAction.ServerCacheRefresh` logging
- [ ] Client: in `GridConfigurator.ConfigureInModel`, on grid `RequestEnd`/`Sync`, show a non-blocking
  reminder with a "Refresh cache" button when the response carries the flag; report success/failure
- [ ] Verify behaviour: AbTests edit on PROD shows reminder; button refreshes that table's caches;
  non-cached table shows nothing; non-PROD unchanged

## Related
- Interim safeguard ahead of the planned server-cache mechanism rework (keep lightweight)
- Touches modules: [data-editing](../../server/modules/data-editing/_card.md),
  [cache](../../server/modules/cache/_card.md), [web-admin](../../server/modules/web-admin/_card.md)
