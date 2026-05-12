---
module: web-admin
status: stub
system: operations
code_paths:
  - WebAdmin/
---

# WebAdmin
> ASP.NET MVC admin panel for FP server operations: player management, moderation, content, stats, reports, environment config. **Umbrella stub** — concrete sub-modules per controller area to be carved by FP-43424 Pass 2/3. This card covers the entry surface and WebAdmin-wide gotchas; the embed pattern for new SPA-style tools lives in the deep-dive.

## Entry Points
- `Global.asax.cs` — startup; ~40 cache systems init + Photon network connections
- `App_Start/RouteConfig.cs` — conventional `{controller}/{action}/{id}` Default route; tool-specific custom routes registered ahead of it (see [embedded-vue-pattern.md → Routing](embedded-vue-pattern.md#routing))
- `Views/Shared/_Layout.cshtml` — global admin chrome; loads `Site.css`, `Layout.css`, Kendo MVC, jQuery (UI + Kendo widgets)
- `Views/Shared/_PlayerToolsPartial.cshtml` — per-player sidebar; sections: Player Details / Inventory / Tools / Profile Json / Moderation / Player Activity / Raw Profile Json

## Key Types
TBD — full controller / model inventory pending FP-43424 Pass 2/3. Observed surface (non-exhaustive): `PlayerController` (+ partials `_Logs`, `_Tools`), `HomeController`, `StatsController`, `ReportsController`, `SettingsController`, `LogsController`, `ToolsController`, `ClubsController`, `DailyMissionsController`, `EnvironmentController`, `MessageController`, `PushNotificationsController`, `WeatherInfoController`. Models follow `<Topic>Model` with `Fill(...) + Data` projection (e.g. `MongoLogModel`, `ScreensModel`, `MergedMongoLogModel`, `CheatLogModel`).

## Dependencies
- → [dal](../dal/_card.md), [cache](../cache/_card.md), Photon ChatServer / ClubServer / MasterServer, Kendo MVC
- ← all consumers of admin-mutated state (game-wide)

## Deep Dives
- [embedded-vue-pattern.md](embedded-vue-pattern.md) — Vue 3 + TS + Vite island embedded in Razor host. Covers stack rationale, project layout, csproj integration, routing (custom route, NOT Areas), Kendo widget bridge, layout constraints, new-tool checklist. Reference for any new SPA-style admin tool.

## WebAdmin-wide gotchas (firm)
- **Kendo `+` literal** — Kendo `ClientTemplate` strings eat literal `+`. Use `%2B` (URL-encoded). See user CLAUDE.md memory.
- **`TableEditModel.Create()` factory** — every new table/view entity edited via admin needs a `case` in the factory (`Models/TableEditModel.cs`); otherwise `ArgumentNullException` at runtime.

## Gotchas codified to KB
- [aspnet_mvc_area_ambient_strand](../../../../feedback/aspnet_mvc_area_ambient_strand.md) — don't use MVC Areas for tools sharing `_Layout` ActionLinks; ambient `area` token strands on root Default route. Use custom route + namespace constraint instead.
- [vue_island_bare_semantic_tags](../../../../feedback/vue_island_bare_semantic_tags.md) — bare `<header>/<footer>/<aside>/<main>/<nav>` in Vue islands receive admin's global CSS (e.g. `header { height: 135px }`). Use `<div class="<component>-header">` instead.

## Related Tasks
- FP-43579 (closed 2026-05-12, code shipped 2026-05-05 LBM r16063 / MFT r16064): AntiCheat Game Session Analysis — first Vue 3 + TS island in admin. Canonical embedded-vue pattern. Replaces legacy `TargetedAdsPlanningTool` (Vue 2 + Vuetify, broken admin chrome — see deep-dive's contrast table).

See also: [log](log.md). Sub-modules to be carved by FP-43424 Pass 2/3.
