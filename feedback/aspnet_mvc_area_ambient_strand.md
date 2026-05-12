---
name: Avoid ASP.NET MVC Areas for admin tools sharing _Layout ActionLinks
description: When a tool's host view inherits a shared _Layout that renders Html.ActionLink to non-Area controllers, an MVC Area's ambient `area` route token strands on the root Default route and produces broken outgoing URLs
type: feedback
---
Do not use ASP.NET MVC Areas for admin tools whose host view (or the shared `_Layout.cshtml` it inherits) renders `Html.ActionLink` / `Url.Action` to non-Area controllers. Use a custom `MapRoute` with explicit `namespaces` constraint instead.

**Why:** ASP.NET MVC's URL generator carries an ambient `area` token derived from the current request's route data. When a shared `_Layout.cshtml` rendered inside an Area context calls e.g. `Html.ActionLink("My Players", "MyPlayers", "Account")`, the generator probes registered routes for a match that includes `area = "<CurrentArea>"`. Root controllers (e.g. `AccountController` outside any Area) cannot be reached this way: the Area's own MapRoute matches but resolves to a non-existent `Areas/<X>/Controllers/AccountController` → 404; the root Default route is skipped because the `area` strand does not match its (empty) data tokens.

Attempting partial fixes does **not** clear the ambient strand:
- `namespaces` constraint on the Area route — still 404 for shared links.
- `controller` regex constraint on the Area route — breaks ALL outgoing links (empty `<a href>`) because the URL generator then rejects every shared `ActionLink` as not matching the constraint.

The only reliable resolutions are:

1. **Don't use Areas** for tools that share a `_Layout` with cross-cutting nav. Use a custom route registered ahead of Default:
   ```csharp
   routes.MapRoute(
       name: "MyTool",
       url: "MyTool/{controller}/{action}/{id}",
       defaults: new { controller = "MyToolController", action = "Index", id = UrlParameter.Optional },
       constraints: new { controller = "MyToolController|OtherToolController" },
       namespaces: new[] { "WebAdmin.Controllers.MyTool" });
   ```
   Place controllers under a namespaced folder (`Controllers/MyTool/`). No ambient `area` token = no strand. Shared `Html.ActionLink("Home", ...)` produces `/Home/Index` cleanly.

2. **Fully isolate** the Area host view (`Layout = null;` or a per-Area `_Layout`). Loses admin chrome — only acceptable for full-screen tools that don't need shared nav.

**How to apply:** before adding a new MVC Area to WebAdmin, verify the host view does NOT inherit `~/Views/Shared/_Layout.cshtml` (which contains shared `_LoginPartial` and similar with ActionLinks to root controllers). If it does, use the custom-route approach. To extend with another tool under the same prefix (e.g. `/Anticheat/...`), broaden the controller regex of the existing custom route rather than introducing an Area.

**Codified for FP-43579 (ARC-007 final resolution).** Original architecture used `Area Anticheat` for tool grouping; smoke caught shared-link 404s; two partial fixes failed; final fix dropped the Area, custom route + namespaced controllers, files moved via `svn move` preserving history. `WebAdmin/Components/AntiCheatTool/README.md` has the per-tool Routing section.
