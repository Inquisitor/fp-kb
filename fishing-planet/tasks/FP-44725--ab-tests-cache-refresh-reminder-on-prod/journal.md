---
jira: FP-44725
title: WebAdmin cache-refresh reminder after editing cache-backed tables on PROD
status: planned
executor: Stanislav Samoilov
created: 2026-06-30
type: story
---
# FP-44725: WebAdmin cache-refresh reminder after editing cache-backed tables on PROD

## Status
Just opened (2026-06-30). Scope agreed (reminder + one-click refresh button, generic + self-gating,
PROD-only). No code yet. Born from a Slack incident where an A/B test activated on PROD did not take
effect on PROD / PSPROD / XBPROD until the server cache was refreshed manually.

## Summary
Editing a PROD-editable table (`AbTests`, `EnvironmentVariables`, ...) in the WebAdmin grid and
refreshing the server cache are two decoupled manual steps — a change only reaches the game servers
after a cache refresh, and nothing in the UI links the edit to the refresh, so it is easy to forget.
The task adds a non-blocking reminder shown after a successful row save on PROD, with a button that
refreshes exactly that table's caches in one click.

## Design decisions
- **Reminder + manual button, not auto-refresh.** The grid saves per row, so auto-refreshing on save
  would emit a cache-refresh signal on every cell edit and spam all platform servers. A reminder keeps
  the operator in control (batch several edits, refresh once) and is lightweight — the cache mechanism
  is itself slated for a rework, so we don't over-invest here.
- **Generic + self-gating, not AbTests-only.** The grid CRUD (`HomeController.Create/Update/Destroy`)
  and the client grid config (`GridConfigurator.ConfigureInModel`) are already generic; an AbTests-only
  reminder would mean *adding* a special case. Instead, gate on
  `CacheRefreshHelper.GetCachesToRefreshByTable(table)` returning a non-empty set — covers AbTests now
  and EnvironmentVariables / any future cache-backed table for free; non-cached tables show nothing.
- **PROD-only** (`Settings.IsProd`). On dev/test the cache auto-refreshes on a timer, so the reminder
  is irrelevant there.

## Implementation entry points (SVN working copy, not KB)
- Server CRUD path: `WebAdmin/Controllers/HomeController.cs` — generic `Create` / `Update` / `Destroy`
  (each takes `tableName`); actual capture layer is `CrudHelper.*` (see [data-editing](../../server/modules/data-editing/_card.md)).
- Refresh-by-table: `ToolsModel.RefreshServerCache(out details, tableName)` already maps table -> caches
  via `CacheRefreshHelper.GetCachesToRefreshByTable` -> `CreateCacheRefreshSignal`; log via
  `AdminAction.ServerCacheRefresh`. A thin controller endpoint to invoke it is the new piece. See
  [cache](../../server/modules/cache/_card.md).
- Client UI hook: `WebAdmin/Models/GridConfigurator.cs` (`ConfigureInModel`, shared by all table grids)
  — surface the reminder after a successful save (Kendo grid `RequestEnd` / `Sync`). See
  [web-admin](../../server/modules/web-admin/_card.md).

## Milestones (log)
- 2026-06-30: Opened. Scope brainstormed (superpowers:brainstorming) against the Slack incident; chose
  reminder+button over only-reminder and over auto-refresh; chose generic self-gating over AbTests-only.
  JIRA created (Story, WebAdmin, Tech Debt, Medium, assignee Stanislav).
