# AntiCheat Game Session Analysis — Architecture

This document captures architectural decisions for the v1 implementation. Requirements (what to build) live in [requirements.md](requirements.md). This document covers how to build it.

Cross-references: [journal](../journal.md), [LureKing notes](lureking-notes.md), [UI geometry calibration](ui-geometry-calibration.md).

## Closure of Phase 2 design questions

| ID      | Decision                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
|---------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| RES-001 | Vue 3 + TS + Vite embeds in WebAdmin Razor page without conflicts. **Verified by working scaffold spike** (see [Scaffold Spike Verification](#scaffold-spike-verification-res-001)). Root cause of past `TargetedAdsPlanningTool` embedding failure was Vuetify's global CSS reset (`ress.css` bundled in `chunk-vendors.css`), not Vue. Fix: no UI kit, scoped styles per component.                                                                                                                                                                              |
| RES-002 | **Closed 2026-05-03.** Runtime values measured in Unity Editor play mode via `uloop` CLI (not prefab YAML — runtime layout is overridden by code). Canvas: HUD_UI ScreenSpaceOverlay 1920×1080 reference, CanvasScaler ScaleWithScreenSize + **Expand** match mode. Buttons: KEEP=PriorityButton (canvas X 980-1230), RELEASE=Button (canvas X 690-940), both Y 92-154. Catch panel: 610-1310 × 18-408. Verified against LureKing empirical (663,89)/(473,89) at ~1136-wide window — math reconciles. Values written to [`uiGeometry.ts`](#ui-geometry-constants). |
| ARC-001 | Vue 3 + TS + Vite, embed via `<div data-initial-state="...">` + `createApp().mount()`. Native HTML controls, light Kendo CSS classes (`k-button`, `k-textbox`), Kendo Dropdown via jQuery-bridge with stop-criteria. Build via `vite build --watch` (no HMR).                                                                                                                                                                                                                                                                                                      |
| ARC-002 | ASP.NET MVC Area `Anticheat` (new pattern for WebAdmin, justified for tool grouping). Controller + Models per existing convention (no Services layer). 3 AJAX endpoints (Screenshots paged 20 / Events one-shot / MonitorInfo). DAL: `GetPlayerScreens` extended with optional date-range + skip/take params (variant B), plus new `GetPlayerScreensCount` for paging UI.                                                                                                                                                                                          |
| ARC-003 | JSON shapes for initial state + 3 AJAX responses documented in [Data Contracts](#data-contracts-arc-003).                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ARC-004 | 3 components in v1: `ScreenshotStrip` + `HeatmapView` + `CalibrationPanel`. State owned by `App.vue`, propagated via props/emits. No store (Pinia) in v1.                                                                                                                                                                                                                                                                                                                                                                                                          |
| ARC-005 | Single localStorage key `anticheat:gameSessionAnalysis:monitorCalibrations`, schema `v: 1`, LRU eviction at >100 entries. Composable `usePlayerCalibration(userId)`.                                                                                                                                                                                                                                                                                                                                                                                               |
| ARC-006 | Future phases plug in via prop-driven composition; no preemptive abstraction layers. See [Future-Phase Compatibility](#future-phase-compatibility-arc-006).                                                                                                                                                                                                                                                                                                                                                                                                        |

## Top-Level Structure

The tool is a **Vue 3 island embedded in a Razor host page** under an ASP.NET MVC Area:

```
URL: /Anticheat/GameSessionAnalysis?userId=<id>&from=<date>&to=<date>
                ↓
Razor view (Areas/Anticheat/Views/GameSessionAnalysis/Index.cshtml)
  - Renders admin chrome via _PlayerToolsPartial
  - Renders Razor filter form (userId + Kendo date pickers)
  - Renders <div id="anti-cheat-app" data-initial-state='{userId, dateRange}'>
  - Loads <link>/<script> for built Vite output
                ↓
Vue 3 island
  - createApp(App, JSON.parse(div.dataset.initialState)).mount('#anti-cheat-app')
  - On mount: kicks off 3 parallel AJAX requests to populate state
  - Filter form submit intercepted by JS → AJAX refresh, history.pushState (no full reload)
```

Filter form is **outside Vue** (Razor partial with Kendo DateTimePickers). Apply-button submit is intercepted by a JS handler that dispatches a `CustomEvent('anticheat:refresh', { detail: { userId, from, to } })` on the `#anti-cheat-app` mount element. Vue's `main.ts` registers an `addEventListener` for this event during mount and re-fetches AJAX data without page reload. URL is updated via `history.pushState` so the filter is shareable / bookmarkable.

Why CustomEvent and not a global function (`window.AntiCheatTool.refresh()`)? No global namespace pollution; mount-order race is explicit (if the event fires before Vue mounts, the listener is not attached and the event is silently dropped — visible in DevTools as "no listeners" rather than a TypeError on undefined `window.AntiCheatTool`); idiomatic for the future SPA migration where refresh is triggered by router state, not a global call.

## Scaffold Spike Verification (RES-001)

A minimal Vue 3 + TS + Vite scaffold was built and embedded in a real Razor page in the local admin to verify the embed pattern works. Spike scope: minimal `App.vue` with state-dump and a `.k-button`, no AJAX, no real components.

**Build metrics**:

- `yarn build` runtime: ~490ms (10 modules transformed)
- `main.js` size: 62 KB (24.81 KB gzipped) — entire Vue 3 runtime + scaffold code
- `style.css` size: 0.41 KB (0.24 KB gzipped) — scoped styles only
- For comparison: `TargetedAdsPlanningTool`'s `chunk-vendors.js` is 600+ KB (Vuetify dominates)

**What was verified**:

- Vue 3 mounts on `<div id="anti-cheat-app">` and renders content
- `createApp(App, { initialState }).mount(el)` consumes JSON from `data-initial-state` attribute correctly
- `vite.config.ts` `outDir: '../../Scripts/vue/anti-cheat'` lands files in expected location
- `<script type="module" src="~/Scripts/vue/anti-cheat/main.js">` loads via IIS without MIME issues (after the file actually exists — see gotcha below)
- Admin chrome (`_Layout.cshtml`) wraps the Vue island cleanly: header, top menu, footer all render normally; Vue scoped styles do not leak; admin's global CSS (`Site.css`, Kendo) does not leak into Vue tree
- `<style scoped>` produces `[data-v-XXXXXXXX]` attribute selectors (verified in built `style.css`) — guarantees no style escape
- `.k-button` class in Vue template is styled by admin's globally-loaded `kendo.default.min.css` — visual consistency works
- Vue reactive state (`ref`, click counter) updates DOM correctly within the island
- No console errors, no network failures (after build artifacts present)

**Gotcha discovered: Areas Views need their own `_ViewStart.cshtml`**

By default, ASP.NET MVC Views in an Area folder do NOT inherit `~/Views/_ViewStart.cshtml`. The first attempt rendered the view without admin chrome (`_Layout` not applied). Fix: create `Areas/Anticheat/Views/_ViewStart.cshtml` with `@{ Layout = "~/Views/Shared/_Layout.cshtml"; }`. This file must be registered in `WebAdmin.csproj` as `<Content>`.

This file is part of the v1 file inventory (see [Build & Deploy](#build--deploy)).

**Files created during the spike** (committed as the v1 baseline):

- Frontend: `Components/AntiCheatTool/{package.json, tsconfig.json, vite.config.ts, .gitignore, src/main.ts, src/App.vue, src/shims-vue.d.ts}`
- Backend: `Areas/Anticheat/{AnticheatAreaRegistration.cs, Controllers/GameSessionAnalysisController.cs, Models/GameSessionAnalysis/GameSessionAnalysisPageModel.cs}`
- Razor host: `Areas/Anticheat/Views/{Web.config, _ViewStart.cshtml, GameSessionAnalysis/Index.cshtml}`
- Menu link: `Views/Player/CheatContent.cshtml` updated with `<li>@Html.ActionLink("Game Session Analysis", "Index", "GameSessionAnalysis", new { area = "Anticheat" }, null)</li>`
- Build output: `Scripts/vue/anti-cheat/{main.js, style.css}`

The scaffold's `App.vue` will be replaced by the v1 component tree (`ScreenshotStrip` + `HeatmapView` + `CalibrationPanel`); the embed plumbing stays.

## Frontend Stack (ARC-001)

### Choice rationale

**Vue 3 + TypeScript + Vite. No UI kit.**

Why Vue 3 (not vanilla / not Vue 2):

- Cross-cutting reactive state across multiple coordinated views (calibration → heatmap, slider → frames, screenshot pick → canvas redraw) is the kind of UI Vue's reactivity primitives (`ref`, `computed`, `watchEffect`) simplify substantially.
- TypeScript catches contract drift between server JSON and client consumption — the `Models/` C# classes have direct TS counterparts in `src/types/`.
- Vue 2 is on maintenance; Vue 3 with `<script setup>` is the current idiomatic API and has better TS support.
- Strategic R&D: this is the first embedded Vue 3 island in WebAdmin, prepares the codebase for eventual SPA migration.

Why no UI kit:

- Vuetify (existing `TargetedAdsPlanningTool`'s choice) bundles `ress.css` reset into `chunk-vendors.css` with unscoped global rules: `html { box-sizing: border-box; ... }`, `* { padding: 0; margin: 0 }`, `details, main { display: block }`, etc. Loading that CSS into the admin layout breaks Kendo grids, sidebar typography, table spacing throughout.
- Quasar / Element Plus / Naive UI / PrimeVue (styled mode) all carry similar global resets.
- Headless libraries (Reka UI / Floating Vue) are options for specific widgets if v1 calibration UX demands them; not preemptively bundled.

Why Vite (not vue-cli-service):

- vue-cli-service is on maintenance mode (webpack 4 underneath).
- Vite uses esbuild for dev (~200ms full-project rebuild for ~30 files) vs webpack's ~3-5 seconds.
- Vite production output via Rollup yields smaller bundles for our target.

### Vue project layout

```
WebAdmin/Components/AntiCheatTool/
├── package.json, tsconfig.json, vite.config.ts
├── README.md                            ← DOC-001
├── src/
│   ├── main.ts                          ← entry: createApp().mount()
│   ├── App.vue                          ← root component, owns all cross-cutting state
│   ├── components/
│   │   ├── ScreenshotStrip.vue
│   │   ├── HeatmapView.vue
│   │   └── CalibrationPanel.vue
│   ├── kendo/
│   │   └── KendoDropdown.vue            ← jQuery widget bridge (B-bridge)
│   ├── composables/
│   │   ├── usePlayerCalibration.ts      ← localStorage I/O, LRU eviction
│   │   └── useApiClient.ts              ← AJAX wrappers for 3 endpoints
│   ├── calibration/
│   │   └── uiGeometry.ts                ← UI rect placeholders (RES-002 swap target)
│   └── types/
│       ├── ClickEvent.ts
│       ├── Screenshot.ts
│       ├── MonitorInfo.ts
│       └── CalibrationData.ts
└── (dist/ not committed; output redirects to ../../Scripts/vue/anti-cheat/)
```

### Build commands

| Command            | Purpose                                                                    |
|--------------------|----------------------------------------------------------------------------|
| `yarn build`       | Production build, one-shot. Used for pre-commit assets.                    |
| `yarn build:watch` | Dev cycle: rebuilds on file save (~1-3s), no HMR. F5 in browser to reload. |
| `yarn lint`        | ESLint across `src/`                                                       |
| `yarn type-check`  | `vue-tsc --noEmit` for TS contract validation                              |

`vite.config.ts` outputs to `../../Scripts/vue/anti-cheat/` with stable filenames (no hash) — `main.js`, `style.css` — so Razor `<script>`/`<link>` tags can reference them statically.

### Browser targets

Chrome, Firefox, modern Edge (Chromium). Safari and IE11 explicitly out of scope.

`vite.config.ts → build.target: 'esnext'`. No polyfills, no transpilation for legacy.

### TypeScript strictness

`tsconfig.json` enables `"strict": true` (which implies `noImplicitAny`, `strictNullChecks`, `strictFunctionTypes`, `strictBindCallApply`, `alwaysStrict`, `strictPropertyInitialization`). Plus `forceConsistentCasingInFileNames` and `isolatedModules`.

This is the **contract for typed JSON flowing from C# `JsonConvert.SerializeObject(model.Data)` into TypeScript interfaces** — null-vs-undefined boundaries are explicit, no implicit `any` in event handlers, no truthiness on possibly-null values without an explicit narrow.

If a type assertion (`as`) seems necessary, prefer a narrowing function instead (e.g. `function isClickEvent(x: unknown): x is ClickEvent { ... }`). Reasons: assertion silently passes a wrong shape through to runtime; narrowing function does runtime verification.

**Loosening strictness requires a comment explaining why and a corresponding TODO** — do not silently disable.

## Backend Layering (ARC-002)

### Area structure

```
WebAdmin/Areas/Anticheat/
├── AnticheatAreaRegistration.cs
├── Controllers/
│   └── GameSessionAnalysisController.cs
├── Models/
│   └── GameSessionAnalysis/
│       ├── GameSessionAnalysisPageModel.cs           ← Index View
│       ├── GameSessionAnalysisScreenshotsModel.cs    ← AJAX paged
│       ├── GameSessionAnalysisEventsModel.cs         ← AJAX one-shot, with truncation cap
│       └── GameSessionAnalysisMonitorInfoModel.cs    ← AJAX one-shot
└── Views/
    ├── Web.config                                     ← required for Razor in Area
    └── GameSessionAnalysis/
        └── Index.cshtml
```

### Area registration

```csharp
public class AnticheatAreaRegistration : AreaRegistration
{
    public override string AreaName => "Anticheat";

    public override void RegisterArea(AreaRegistrationContext context)
    {
        context.MapRoute(
            "Anticheat_default",
            "Anticheat/{controller}/{action}/{id}",
            new { action = "Index", id = UrlParameter.Optional });
    }
}
```

`Global.asax.cs` already calls `AreaRegistration.RegisterAllAreas()` — no startup changes needed.

Future anti-cheat tools (e.g. `ClickPatternMatcher`) add new controllers under `Areas/Anticheat/Controllers/` without RouteConfig edits.

### Controller signatures

```csharp
[CustomAuthorize(Roles = "Abuse")]
public class GameSessionAnalysisController : BaseController
{
    public ActionResult Index(string userId, DateTime? from = null, DateTime? to = null);
    public JsonResult Screenshots(string userId, DateTime from, DateTime to,
                                   int page = 1, int pageSize = 20);
    public JsonResult Events(string userId, DateTime from, DateTime to);
    public JsonResult MonitorInfo(string userId, DateTime from, DateTime to);
}
```

Controller-level `[CustomAuthorize(Roles = "Abuse")]` covers all 4 actions. No per-action authorization required.

### Models pattern

Each model follows the existing WebAdmin convention seen in `MongoLogModel`, `TargetedAdsPlanningModel`, etc.:

- Fields holding input parameters and output data
- `Fill(...)` method that fetches from DAL and projects
- `Data` property exposing a JSON-friendly anonymous projection for `JsonResponse(model.Data)`

No new layer (Services / Domain / etc.) is introduced. WebAdmin's convention is Controller (thin) → Model (does work) → DAL providers.

### DAL changes — extend `GetPlayerScreens` with optional date range + paging

| Endpoint          | Source                 | Method                                                                                                                      |
|-------------------|------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| Events            | Mongo `fishingLog`     | `new LogBase("fishing").Find(userId, from, to)`, filtered by `Message.StartsWith("TakeClick"/"ReleaseClick")`, parse coords |
| Screenshots       | SQL `Stats.Screens`    | `DalFactory.GetAnalyticsProvider().GetPlayerScreens(userGuid, from, to, skip, take)` — extended signature, see below        |
| Screenshots count | SQL `Stats.Screens`    | `DalFactory.GetAnalyticsProvider().GetPlayerScreensCount(userGuid, from, to)` — new method for paging UI                    |
| MonitorInfo       | Mongo `diagSysInfoLog` | `new LogBase("diagSysInfo").Find(userId, from, to)`, parse `Monitor` field, distinct values                                 |
| Screenshot bytes  | SQL `Stats.Screens`    | Existing `/Player/GetScreen?id=N` endpoint (reused as-is, not duplicated)                                                   |

The existing `GetPlayerScreens(Guid userId)` takes no date filter — it returns *all* of a player's screenshots ordered by timestamp DESC. For active players over multiple weeks this is wasteful both server-side (full table scan by `UserId`) and client-side (large response).

**Decision: variant B — extend the existing method with optional parameters** (rather than add a parallel `GetPlayerScreensInRange` overload):

```csharp
// IAnalyticsProvider.cs
IEnumerable<ScreenDto> GetPlayerScreens(
    Guid userId,
    DateTime? from = null,
    DateTime? to = null,
    int? skip = null,
    int? take = null);

int GetPlayerScreensCount(
    Guid userId,
    DateTime? from = null,
    DateTime? to = null);
```

Why variant B over a separate overload:

- The existing SQL is simple — one `SELECT ... WHERE UserId = @UserId ORDER BY Timestamp DESC` — adding optional `AND Timestamp >= @from AND Timestamp <= @to` plus `OFFSET/FETCH` is a clean local change.
- Existing call site `ScreensModel.Fill(userId) → GetPlayerScreens(userGuid)` continues to work unchanged (all new params are nullable defaults).
- `/Player/Screens` view becomes capable of paging if/when it needs it, without further DAL work.
- One method, one SQL, one indexing story to maintain.

`skip`/`take` use SQL-native semantics (OFFSET/FETCH); the controller-side `page`/`pageSize` AJAX params translate to `skip = (page - 1) * pageSize`, `take = pageSize`.

`GetPlayerScreensCount` is a separate small method because the row count is needed for the paging UI but doesn't fit cleanly into a streaming `IEnumerable<ScreenDto>` return.

### Index view (Razor host)

Approximate shape (~50 lines):

```cshtml
@model GameSessionAnalysisPageModel
@{ Layout = "~/Views/Shared/_Layout.cshtml"; ViewBag.Title = "AntiCheat: Game Session Analysis"; }

@Html.Partial("_PlayerToolsPartial")
<hgroup class="title"><h1>@ViewBag.Title</h1></hgroup>

<form id="anticheat-filter">
    <input id="userId" name="userId" value="@Model.UserId" />
    <input id="from"   name="from" />
    <input id="to"     name="to" />
    <input type="submit" class="k-button" value="Apply" />
</form>

<div id="anti-cheat-app"
     data-initial-state="@Json.Serialize(Model.Data)"></div>

<link href="~/Scripts/vue/anti-cheat/style.css" rel="stylesheet" />
<script src="~/Scripts/vue/anti-cheat/main.js"></script>
<script>
    document.getElementById('anticheat-filter').addEventListener('submit', function(e) {
        e.preventDefault();
        var fd = new FormData(e.target);
        var qs = new URLSearchParams(fd).toString();
        history.pushState({}, '', '?' + qs);
        document.getElementById('anti-cheat-app').dispatchEvent(
            new CustomEvent('anticheat:refresh', {
                detail: { userId: fd.get('userId'), from: fd.get('from'), to: fd.get('to') }
            })
        );
    });
    $(document).ready(function() {
        CreateKendoUtcDateTimePickerFor('#fromPicker', '#from');
        CreateKendoUtcDateTimePickerFor('#toPicker',   '#to');
    });
</script>
```

Date picker initialization uses the existing `CreateKendoUtcDateTimePickerFor` helper — same pattern as `Views/Player/FishingLog.cshtml`. `kendo.culture("en-SE")` (set globally in admin) provides ISO date format `YYYY-MM-DD HH:mm:ss`.

### Link from `_PlayerToolsPartial.cshtml`

In the Moderation section, alongside `Cheating log` / `Screens` / `Telemetry`:

```cshtml
@if (AuthHelper.IsInRole("Abuse", User))
{
    <a href="/Player/CheatLog?userId=@userId">Cheating log</a>
    <a href="/Player/Screens?userId=@userId">Screens</a>
    <a href="/Player/TelemetryLog?userId=@userId">Telemetry</a>
    <a href="/Anticheat/GameSessionAnalysis?userId=@userId"><b>AntiCheat analysis</b></a>
}
```

## Data Contracts (ARC-003)

### Initial state (Razor → Vue, embedded in `data-initial-state`)

Minimum bootstrap. Vue mounts and immediately fires 3 parallel AJAX requests.

```json
{
  "userId": "abc-123-def-...",
  "dateRange": {
    "from": "2026-04-19T00:00:00Z",
    "to":   "2026-05-03T23:59:59Z"
  }
}
```

### Screenshots — `GET /Anticheat/GameSessionAnalysis/Screenshots`

Query: `userId`, `from`, `to`, `page` (default 1), `pageSize` (default 20).

```json
{
  "items": [
    { "id": 12345, "timestamp": "2026-04-25T14:23:11Z", "tournamentId": "T-789" },
    { "id": 12346, "timestamp": "2026-04-25T14:24:32Z", "tournamentId": null }
  ],
  "total": 247,
  "page": 1,
  "pageSize": 20
}
```

`total` is the unfiltered count of screenshots in date range. `pageSize` defaults to 20 but client can request larger via query param.

### Events — `GET /Anticheat/GameSessionAnalysis/Events`

Query: `userId`, `from`, `to`. No paging.

```json
{
  "items": [
    { "kind": "take",    "timestamp": "2026-04-25T14:23:11.234Z", "x": 663, "y": 89 },
    { "kind": "release", "timestamp": "2026-04-25T14:23:13.567Z", "x": 473, "y": 89 }
  ],
  "totalAvailable": 24837,
  "returnedCount": 10000,
  "truncated": true
}
```

**Server-side cap: 10,000 events per request.** If `totalAvailable > 10000`, server returns the **last** 10,000 by `timestamp` descending, then re-orders ascending for client consumption. UI displays a banner: «Showing last 10000 of 24837 events. [Increase limit ↗]» (the increase action is a v1 stub; behavior implemented post-v1 if moderators request it).

`kind` values: `"take"` or `"release"`. Coordinates are integer pixel values from `Mouse.current.position.ReadValue()` at the moment the handler fired.

### MonitorInfo — `GET /Anticheat/GameSessionAnalysis/MonitorInfo`

Query: `userId`, `from`, `to`. No paging.

```json
{
  "items": [
    { "timestamp": "2026-04-25T08:00:00Z", "monitor": "1920x1080" },
    { "timestamp": "2026-04-26T19:30:00Z", "monitor": "2560x1440" }
  ],
  "distinctValues": ["1920x1080", "2560x1440"]
}
```

`monitor` is the raw string from `diagSysInfoLog` — server does minimal parsing (extracts the dimensions substring if a known format, otherwise returns raw). `distinctValues` is convenience for the calibration panel «Monitor: [list]» display.

### Error responses

- **2xx** — JSON as above.
- **4xx** (bad input, missing userId, etc.) — JSON `{ "error": "<short message>" }`. Client displays in error-banner.
- **5xx** — server returns a Razor error page (HTML body). Client wraps the response body in `<iframe srcdoc="...">` overlay with a Close button. No special handling of stack trace formatting.

## Component Tree (ARC-004)

### v1 tree

```
App.vue (root — owns all cross-cutting state)
├── ScreenshotStrip
│   props:  screenshots, total, page, activeId, isLoading
│   emits:  update:activeId, update:page
├── HeatmapView
│   props:  activeScreenshot, clicks, frames, displayMode, showTake, showRelease, isLoading
│   emits:  (none in v1 — no cross-component highlight)
└── CalibrationPanel
    props:  resolution, offsetX, offsetY, monitorInfo, displayMode, showTake, showRelease, isLoading
    emits:  update:* for each editable field
```

`RawEventsView` is **not** in v1 — moderator uses existing `/Player/FishingLog?userId=X` for raw event inspection. A future iteration may add an in-tool list with cross-highlight if the timeline phase needs it.

### State ownership in `App.vue`

```ts
// From server (initialState bootstrap + AJAX-loaded)
const userId             = ref<string>(...)
const dateRange          = ref<{ from: Date, to: Date }>(...)
const screenshots        = ref<Screenshot[]>([])
const screenshotsTotal   = ref<number>(0)
const screenshotsPage    = ref<number>(1)
const events             = ref<ClickEvent[]>([])
const eventsTruncated    = ref<{ truncated: boolean, totalAvailable: number } | null>(null)
const monitorInfo        = ref<MonitorInfo | null>(null)

// Per-section loading flags (loading UX option (b) — per-component spinners)
const screenshotsLoading = ref(false)
const eventsLoading      = ref(false)
const monitorLoading     = ref(false)

// Client-side, persisted in localStorage via composable
const { data: calibration } = usePlayerCalibration(userId)
// calibration.resolution, .offsetX, .offsetY, .activeScreenshotId,
// .showTake, .showRelease, .displayMode
```

### Reactivity flow

The composable pattern replaces an explicit store. `usePlayerCalibration(userId)` returns a `ref` that's two-way synced with `localStorage`:

- Slider drag in `CalibrationPanel` emits `update:offsetX` → `App.vue` mutates `calibration.value.offsetX` → `watch(calibration, save, { deep: true })` fires → JSON serialized and written to `localStorage`.
- Pick screenshot in `ScreenshotStrip` emits `update:activeId` → `App.vue` mutates `calibration.value.activeScreenshotId` → same persistence path.
- `HeatmapView` consumes `frames` (computed from `calibration.resolution` + `uiGeometry`) via prop. When resolution changes, `watchEffect` inside `HeatmapView` re-renders the canvas.

No store (Pinia / Vuex) in v1. Composable-as-store is sufficient for the cross-component reactivity needed.

## Calibration Persistence (ARC-005)

### Storage key

```
anticheat:gameSessionAnalysis:monitorCalibrations
```

Three-level prefix mirrors the Area + tool URL hierarchy:

- `anticheat:` — anti-cheat tool group (matches Area `Anticheat`)
- `gameSessionAnalysis:` — specific tool (matches controller `GameSessionAnalysis`)
- `monitorCalibrations` — data type. `monitor` qualifier reserves space for future `timeCalibrations`, `mapCalibrations` etc. without key migration.

### Schema

Single JSON value at the key, indexed by `userId`:

```ts
type StorageRoot = {
  v: 1
  entries: {
    [userId: string]: CalibrationEntry
  }
}

type CalibrationEntry = {
  resolution:
    | { kind: 'preset'; value: string }              // e.g. '1920x1080'
    | { kind: 'manual'; aspectRatio: string; width: number }
  offsetX: number
  offsetY: number
  activeScreenshotId: number | null
  showTake: boolean
  showRelease: boolean
  displayMode: 'points' | 'density'
  ts: number                                          // last-touched epoch millis (for LRU)
}
```

### LRU eviction

When write would result in `Object.keys(entries).length > 100`:

```ts
const oldestUserId = Object.entries(entries)
  .sort(([, a], [, b]) => a.ts - b.ts)[0][0]
delete entries[oldestUserId]
```

`ts` updated on **both** read and write — `ts` reflects last-touched, not last-modified. A moderator returning to a player they investigated weeks ago "touches" the entry on load, protecting it from eviction in subsequent overflows.

### Composable interface

```ts
// composables/usePlayerCalibration.ts
export function usePlayerCalibration(userId: Ref<string>) {
  const data = ref<CalibrationEntry>(loadOrDefaults(userId.value))

  // Persist on any change (deep watch)
  watch(data, () => persist(userId.value, data.value), { deep: true })

  // On userId change (filter form refreshes), reload
  watch(userId, (newId) => { data.value = loadOrDefaults(newId) })

  return { data }
}
```

Encapsulation rationale: components never see `localStorage` directly. The schema, key, and LRU policy live in one file — schema migrations or storage backend changes (e.g., session-server-side persistence in Phase 5) are local edits.

### Schema migration policy

If a future schema bump is needed:

- Read attempt with `v !== 1` → discard, treat as empty. Defaults are returned.
- Moderator loses past calibrations on first load after deploy. Acceptable trade-off for v1; Phase 5 server-side persistence would carry through.
- No active migration code — keeps the composable simple.

## Physical Model — Coordinate Spaces

Three distinct pixel spaces participate in rendering. Their relationships are explicit to avoid the «which size is which» class of bugs (mixing screenshot natural size, client window size, and on-page display size).

### Spaces

| Space                  | Origin                                                                                                                | Typical size                                | Notes                                                                              |
|------------------------|-----------------------------------------------------------------------------------------------------------------------|---------------------------------------------|------------------------------------------------------------------------------------|
| **Client window**      | `Mouse.current.position.ReadValue()` at click time                                                                    | Calibrated (`1920×1080`, `1280×800`, ...)   | Coordinate space of `TakeClick` / `ReleaseClick` events. Y-up.                     |
| **Screenshot natural** | Server-downscaled JPEG in `Stats.Screens.Screen` (verified 2026-05-03 via Id=60007)                                   | Always **800×H**, AR preserved              | Server downscales to fixed 800px width regardless of client window. Y-down.        |
| **On-page display**    | `<canvas>` element CSS size                                                                                           | Browser viewport-bound (`max-width: 100%`)  | UA-side scaling for moderator visibility.                                          |

**Verified**: a real screenshot (`Stats.Screens` Id=60007) is `800×449` JPEG, game-window only (no monitor chrome, no admin chrome). Click coords for the same session are in the original client-window space (e.g. `1920×1080`), not the downscaled space.

### Canvas as the unifying space

The `<canvas>` intrinsic size = **client window resolution** (= `calibration.resolution`). All overlays draw 1:1 in this space:

```
┌──────────────────────────────────────────────────────────┐
│ canvas: width=window.W, height=window.H                  │
│                                                          │
│  Layer 0  background:                                    │
│    if screenshot   → ctx.drawImage(img, 0, 0, W, H)      │
│                       (800×H_jpeg upsampled to W×H)      │
│    else            → strokeRect(0, 0, W, H) — frame      │
│                                                          │
│  Layer 1  KEEP / RELEASE / catchPanel rects              │
│    derived from uiGeometry.ts via Expand-mode scaling    │
│    for current (W, H) — see UI Geometry Constants below  │
│                                                          │
│  Layer 2  click points                                   │
│    drawn at (event.x, event.y) — 1:1, no transform       │
│    Y-flip: draw at (x, H - y) since Y-up → canvas Y-down │
└──────────────────────────────────────────────────────────┘
                    ↓ CSS max-width: 100%
            page rendered ~600-1200px wide
            depending on viewport
```

**Why upsample the JPEG instead of canvas-resizing to 800×H**: clicks are in window space — sticking them on a 800×H canvas would require `(x*800/W, y*H_jpeg/H)` transform, accumulating rounding error and diverging when window AR differs from JPEG AR (server downscales preserving AR, but if calibration AR is wrong, divergence becomes visible — and that visible divergence is what the moderator uses to **detect** AR miscalibration).

When the calibration is correct, screenshot AR == window AR, drawImage is a uniform upscale, everything overlays cleanly. When the calibration is wrong, the screenshot stretches/squashes against bounding rects — visible feedback for the moderator to fix the resolution.

### Bounding-box-only mode (no screenshot selected)

When `activeScreenshotId == null`, Layer 0 = empty stroked rect (`#888`, 1px) on the canvas border. Layers 1-2 unchanged. This gives the moderator a reference frame to interpret click positions even before picking a screenshot.

### Aspect ratio parameterisation (CalibrationPanel manual mode)

```ts
// src/calibration/aspectRatios.ts
export const STANDARD_ASPECT_RATIOS = {
  '16:9':  { w: 16, h: 9  },
  '16:10': { w: 16, h: 10 },
  '4:3':   { w: 4,  h: 3  },
} as const
export type AspectRatioKey = keyof typeof STANDARD_ASPECT_RATIOS
```

Manual mode UI: width slider + radio for `STANDARD_ASPECT_RATIOS` keys → `height = width * ratio.h / ratio.w`. Adding a new standard AR is a single object key — UI iterates over `Object.keys(STANDARD_ASPECT_RATIOS)`. Custom (non-standard) AR support is deferred; schema (`CalibrationData.resolution.manual.aspectRatio: string`) accommodates a free-text future.

## UI Geometry Constants

RES-002 closed 2026-05-03. Canonical values measured at runtime in Unity Editor play mode (not from prefab YAML — runtime layout differs because code overrides `RectTransform` properties on instantiation).

### Source file

`src/calibration/uiGeometry.ts`:

```ts
export type Rect = { x: number; y: number; width: number; height: number }

export type ScalingMode = 'expand' | 'match-width' | 'match-height' | 'shrink'

export type UiGeometry = {
  catchPanel:    Rect
  keepButton:    Rect
  releaseButton: Rect
  baseResolution: { w: number; h: number }
  scalingMode:   ScalingMode
}

// Values from CatchedFishInfo.prefab → CatchedFishInfo(Clone) runtime, 2026-05-03.
export const UI_GEOMETRY: UiGeometry = {
  catchPanel:    { x: 610, y:  18, width: 700, height: 390 },
  keepButton:    { x: 980, y:  92, width: 250, height:  62 },
  releaseButton: { x: 690, y:  92, width: 250, height:  62 },
  baseResolution: { w: 1920, h: 1080 },
  scalingMode:   'expand',
}
```

### Coordinate convention

- Origin at **bottom-left** of canvas (Unity Y-up).
- Same convention as `Mouse.current.position.ReadValue()` (which produces `TakeClick` / `ReleaseClick` log coords). No flipping needed when comparing rects to clicks.
- When rendering on an HTML `<canvas>` (which is Y-down), flip at draw time.

### Element-to-button mapping

Confirmed via reflection on `CatchedFishInfoHandler` runtime instance:

- `_takeButton`    → `PriorityButton` (right side of panel)  → **KEEP**
- `_releaseButton` → `Button`         (left side of panel)   → **RELEASE**

### Host canvas (`HUD_UI`)

- `Canvas.renderMode`:                 ScreenSpaceOverlay
- `Canvas.scaleFactor`:                1
- `CanvasScaler.uiScaleMode`:          ScaleWithScreenSize
- `CanvasScaler.screenMatchMode`:      Expand
- `CanvasScaler.matchWidthOrHeight`:   0 (irrelevant in Expand mode)
- `CanvasScaler.referenceResolution`:  1920 × 1080

### Scaling math (window W × H → canvas reference 1920 × 1080)

```
scale = MIN(W / 1920, H / 1080)
screen_x = canvas_x * scale
screen_y = canvas_y * scale         (Y-up; flip if rendering on Y-down canvas)
```

### Verification against LureKing empirical (real click data)

Beyond a single-point arithmetic check, the canonical geometry was tested against real aggregated click data from the pre-task investigation. Script: [`verify_lureking_runtime_geom.py`](verify_lureking_runtime_geom.py). It:

1. Reads per-player aggregated TakeClick / ReleaseClick coordinates.
2. Computes weighted centroid for each kind.
3. Derives screen window width as `take_centroid_x + release_centroid_x` (assuming canvas-centered panel — same algorithm as `heatmap_gen.detect_window_from_buttons`).
4. Snaps to a known standard resolution if within 10% relative diff; else falls back to derived width with 16:9 aspect.
5. Maps the canonical button rects to the derived screen resolution via Expand scaling.
6. Reports the fraction of clicks that fall inside the expected rect.

Two complementary discriminative metrics emerged from the verification:

1. **Button-targeting metric**: `% of TakeClicks inside KEEP-rect` at the derived (button-symmetry) window. Catches button-targeting bots (LureKing-style).
2. **Window-center metric**: `min distance from cluster centroid to (W/2, H/2)` across popular standard resolutions, with a threshold (e.g. 50 px). Catches cursor-parked-at-center bots (Pattern B). Importantly, this works even with sparse data — centroid stabilizes when clicks are tightly clustered, regardless of click count.

The two metrics do not overlap: LureKing bots are far from any window-center, Pattern B clicks are far from button rects, honest players are far from both.

Results across 8 real-world samples:

| Player                    | Take centroid  | In KEEP rect | Window-center match   | Verdict                                                                                                                                                                                                                                                                                                                                                     |
|---------------------------|----------------|--------------|-----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| LUYA168                   | (663, 89)      | **100.0%**   | NO (272 px off)       | **LureKing**                                                                                                                                                                                                                                                                                                                                                |
| rrsrewr                   | (663, 92)      | **99.1%**    | NO (269 px off)       | **LureKing**                                                                                                                                                                                                                                                                                                                                                |
| W_CHUANQI                 | (808, 575)     | 4.1%         | **1600×1200 (26 px)** | **Pattern B**                                                                                                                                                                                                                                                                                                                                               |
| Niepan.LD                 | (810, 419)     | 8.6%         | **1600×900 (32 px)**  | **Pattern B**                                                                                                                                                                                                                                                                                                                                               |
| DFT_KennPF                | (992, 537)     | n/a (6 take) | **1920×1080 (32 px)** | **Pattern B** (detected on sparse data via centroid)                                                                                                                                                                                                                                                                                                        |
| adidan                    | (983, 470)     | 17.3%        | NO (73 px, marginal)  | **multi-cluster** — visual inspection reveals 3 clouds: window-center (release-heavy, bot-like) + two on actual buttons (looks human). Single-centroid metric averages them and gives misleading verdict — see [Multi-cluster limitation](#multi-cluster-limitation).                                                                                       |
| JangalorFP (4K)           | (2111, 438)    | n/a (no rel) | NO (482 px+)          | honest 4K player — scattered click pattern, no signature match                                                                                                                                                                                                                                                                                              |
| **Jangalor (Steam Deck)** | **(640, 399)** | n/a (no rel) | **1280×800 (1.0 px)** | **Known false-positive — honest controller-only Steam Deck player.** 17/17 TakeClicks at *exactly* (640, 399), variance 0 px, exactly window-center. Visually indistinguishable from a Pattern B bot signature by the window-center metric alone. See [Known false-positive: Steam Deck controller-only](#known-false-positive-steam-deck-controller-only). |

**Verdict logic** (foundation for Phase 4 anomaly scoring):

- Both metrics low (in-rect ≤ 20% AND centroid > 100 px from any window-center) → **honest** or insufficient signal.
- Button-rect metric high (in-rect ≥ 80%) → **button-targeting bot** (LureKing-style).
- Window-center metric matches (centroid within 50 px of standard W/2 H/2) → **suspect Pattern B**, but **cannot conclude bot without additional signal** — see Known false-positive section. Possible refinements: cross-check with `diagSysInfoLog` for controller hardware (Steam Deck), check Releases distribution (controller honest player has few/no Releases at center; bot typically has many Take + Release at center).
- Neither matches AND cluster is concentrated → **distinct signature** (rare, surface to moderator for manual attribution).

Phase 4 anomaly scoring ports both metrics from this verification + `heatmap_gen.py` to server-side. The tool's discriminative power is validated empirically across all 8 samples, but the **window-center metric alone is not sufficient** to call Pattern B verdict — it surfaces *suspects* for moderator review.

#### Known false-positive: Steam Deck controller-only

The same human player on two different setups produces dramatically different click patterns:

- **JangalorFP** (4K monitor 3840×2160, mouse): 25 TakeClicks scattered across X 2131-3534, Y 227-2159 — typical honest pattern, far from any window-center.
- **Jangalor** (Steam Deck 1280×800, controller-only): 17 TakeClicks at *exactly* (640, 399) — variance 0 px — exactly window-center, distance 1.0 px to standard 1280×800 center.

Steam Deck's controller-only mode triggers Unity's auto-cursor-centering on focus / screen events, and there is no mouse to move the cursor away. Every controller-A press for KEEP fires the click handler at the cursor's current pixel, which is the same pixel every time. **Tightness alone does NOT discriminate this from a bot** — a bot with `SetCursorPos(W/2, H/2)` would produce identical output. The earlier hypothesis "tight cluster ≈ controller, loose cluster ≈ bot" is **falsified** — both produce tight clusters.

Discriminator candidates that *do* work:

1. **Hardware signature** — `diagSysInfoLog.Monitor` may identify Steam Deck (e.g. specific resolution + GPU string). If hardware indicates portable / controller-only device, treat window-center cluster as expected-honest until proven otherwise.
2. **Releases distribution** — Jangalor has 0 ReleaseClicks (only Takes). LureKing-style bots have many Releases also at exact button-pixel. Pattern B bots usually have heavy Take dominance with few Releases (similar to Jangalor — ambiguous). If both Take AND Release clusters exist at exact same pixel = bot; only Take cluster + 0 Release = ambiguous (could be controller honest or partial bot).
3. **Click rate** — 17 clicks total over a session is a normal human pace. A bot at the same pixel would accumulate hundreds. Phase 4 anomaly scoring should weight by clicks-per-hour / clicks-per-fish-encounter.
4. **Visual review** — moderator has access to player's account history, ban records, IP timeline. The tool surfaces suspects; moderator confirms or dismisses.

For v1: window-center match is treated as **suspect, surface to moderator**, not auto-verdict bot. Moderator's eye + account context decides. Phase 4 may incorporate (1)-(3) as automated discriminators once enough cases are accumulated.

#### Multi-cluster limitation

Single-centroid analysis is misleading for samples with multiple distinct click clouds. Example: **adidan** visually shows three clusters — one large at window-center (Release ≫ Take, bot signature), two smaller on the actual KEEP / RELEASE buttons (human signature). The weighted centroid lands in between, scoring marginal on both metrics and producing a "neither" verdict that misses the true mixed-actor pattern.

Implications:

- **v1 tool's primary value comes from visual moderator inspection.** Heatmap rendering shows multi-cluster structure directly; the moderator's eye separates clouds without any automation. Numerical verdicts at this stage are just supporting hints.
- **Phase 4 anomaly scoring must do per-cluster decomposition**, not single-centroid analysis. Algorithm:
  1. Density-based clustering (e.g. DBSCAN) on click points to extract distinct clouds.
  2. For each cluster: compute weight (share of total clicks), in-rect %, window-center distance, take/release ratio.
  3. Classify each cluster independently: button-bot / Pattern B / scattered-human / unknown.
  4. Aggregate verdict over clusters: e.g. "one Pattern B cluster (60% of total, Release-heavy) + two human-on-button clusters (40% combined)".
- `heatmap_gen.py` currently extracts only the densest cluster via `cluster_density` / `cluster_centroid`. The Phase 4 port must extend this to enumerate **all** dense clusters above a threshold weight.

#### Window-center cluster: bot-vs-controller discrimination (status 2026-05-03)

A cluster sitting at exact window-center has two competing explanations (per [requirements.md → Hypotheses Still Open](requirements.md#hypotheses-still-open)):

- **(a)** Bot using `SetCursorPos`-style cursor placement before each handler invocation.
- **(b)** Unity auto-centering the cursor on focus / screen-change events, combined with controller-only play (Steam Deck has no mouse, cursor stays where Unity put it).

**Earlier hypothesis (FALSIFIED)**: cluster *tightness* would discriminate (a) from (b) — tight ±1-2 px = controller, loose 5-50 px = bot. This was tested against the Jangalor Steam Deck sample: 17/17 clicks at *exactly* (640, 399), variance 0 px. A confirmed honest controller player produces a tighter cluster than any LureKing bot in our sample. Tightness-as-discriminator is **dead**.

**Working discriminator candidates** (replace tightness):

1. **Hardware signature** (`diagSysInfoLog.Monitor`, GPU string) → identify Steam Deck / portable / known controller-only devices. Treat their window-center clusters as expected-honest until other signal contradicts.
2. **Releases on buttons** — confirmed LureKing bots produce ReleaseClicks at exact RELEASE-button-pixel matching the same scaling as TakeClicks. A controller-honest player has zero or scattered Releases (Jangalor: 0 Releases). If both Take AND Release clusters exist at exact same pixel = strong bot signal; if Release cluster at the actual button position (not center) AND Take cluster at center = weird mixed pattern, surface for review.
3. **Click rate** — 17 takes per session is human pace; bot at same pixel accumulates hundreds in same period. Phase 4 should weight by clicks-per-hour and clicks-per-catch.
4. **Account/IP context** — outside the click metrics: account history, ban records, IP timeline. Visible to moderator alongside the heatmap.

**v1 verdict logic** for window-center match:

- **Suspect** (not auto-verdict bot). Surface to moderator with all 4 discriminator signals visible.
- Moderator looks at: hardware info, Releases distribution, click rate, account context, and the heatmap visual itself.
- Auto-verdict requires Phase 4 work + accumulated case data to confirm which discriminators reliably work.

## Visual Consistency Strategy

The admin layout already loads `kendo.common.min.css` + `kendo.default.min.css` globally. The Vue tool can use Kendo CSS classes selectively to match admin look-and-feel without depending on Kendo widget DOM.

| Element                                   | Approach                                                                                                                                      |
|-------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| Buttons                                   | `<button class="k-button">`                                                                                                                   |
| Text inputs (within Vue)                  | `<input class="k-textbox">`                                                                                                                   |
| Resolution preset dropdown                | `<KendoDropdown>` via jQuery widget bridge (B-bridge); fallback to `<select>` with scoped Kendo-palette CSS if bridge stop-criteria triggered |
| Sliders (resolution width, manual offset) | native `<input type="range">` + scoped CSS                                                                                                    |
| Checkboxes (Take/Release toggles)         | native `<input type="checkbox">` + scoped CSS                                                                                                 |
| Aspect ratio radio                        | native `<input type="radio">` + scoped CSS                                                                                                    |
| Hover tooltips                            | native `title` attribute (v1); custom positioned tooltip if post-v1 needs richer content                                                      |

### What works / what doesn't with `k-*` classes

Confirmed working: `k-button`, `k-textbox`. Most container/layout helpers (`k-content`, `k-window`).

**Not working** without widget-generated DOM: `k-dropdown`, `k-grid`, `k-tabstrip`, `k-treeview`, `k-tooltip`. Those CSS rules style the markup that jQuery widgets produce, not bare HTML.

For one composite widget — the resolution preset dropdown — we accept the bridge overhead because:

1. Visual match for dropdowns is high-value (they're prominent in calibration UX).
2. Bridge code is contained (~50 lines per widget, isolated in `src/kendo/`).
3. SPA migration cost is bounded (bridge files are throwaway, call sites are typed component swaps).

### Bridge component design

`KendoDropdown.vue` follows a rigid pattern (any future bridge component should mirror it):

```vue
<template><input ref="el" /></template>
<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount, watch } from 'vue'

const props = defineProps<{
  modelValue: string | number | null
  options: Array<{ text: string; value: string | number }>
}>()
const emit = defineEmits<{ 'update:modelValue': [string | number | null] }>()
const el = ref<HTMLInputElement>()
let widget: any = null

onMounted(() => {
  widget = $(el.value!).kendoDropDownList({
    dataTextField: 'text',
    dataValueField: 'value',
    dataSource: props.options,
    value: props.modelValue,
    change: () => emit('update:modelValue', widget.value()),
  }).data('kendoDropDownList')
})

watch(() => props.modelValue, v => { if (widget && widget.value() !== v) widget.value(v) })
watch(() => props.options,    v => widget?.setDataSource(v))
onBeforeUnmount(() => widget?.destroy())
</script>
```

Critical points (will be repeated in DOC-001 README):

- The bridge `<input>` element must NOT be re-rendered by Vue (template is stable; props change but element identity persists).
- `widget.destroy()` in `onBeforeUnmount` is **mandatory** — leaks otherwise.
- Widget popups attach to `<body>`, not inside the bridge element. Scoped styles don't reach popups.

### Bridge stop-criteria

If the bridge fails (popup positioning broken, jQuery / Vue DOM ownership conflict, widget integration takes more than ~2 hours of work), fallback is:

- `<select class="kendo-like-select">` with scoped CSS imitating Kendo palette (border `#c5c5c5`, accent `#3e80cf`, font `Segoe UI` — values copied from Kendo via DevTools, not the classes themselves).

The fallback is documented in `architecture.md` post-hoc as «attempted bridge, fell back if applicable» so future authors see the trail.

## Loading UX & Error Handling

### Loading (per-section spinners — option b)

On Vue mount, three AJAX requests fire in parallel:

```ts
const useApi = useApiClient()
onMounted(() => {
  screenshotsLoading.value = true
  useApi.fetchScreenshots(userId.value, from, to, 1, 20)
    .then(r => { screenshots.value = r.items; screenshotsTotal.value = r.total })
    .finally(() => { screenshotsLoading.value = false })

  eventsLoading.value = true
  useApi.fetchEvents(userId.value, from, to)
    .then(r => { events.value = r.items; eventsTruncated.value = { truncated: r.truncated, totalAvailable: r.totalAvailable } })
    .finally(() => { eventsLoading.value = false })

  monitorLoading.value = true
  useApi.fetchMonitorInfo(userId.value, from, to)
    .then(r => { monitorInfo.value = r })
    .finally(() => { monitorLoading.value = false })
})
```

Each component receives an `isLoading` prop and renders a "Loading..." text indicator in its own area:

- `ScreenshotStrip` → "Loading screenshots..." replacing thumbnails area
- `HeatmapView` → spinner overlay on canvas
- `CalibrationPanel` → controls disabled while `monitorLoading.value === true`

If a section finishes earlier, that section becomes interactive immediately. UI never globally blocks.

### Error handling

`useApiClient.ts` wraps `fetch`:

```ts
async function call(url: string): Promise<any> {
  const res = await fetch(url, { credentials: 'same-origin' })
  if (res.ok) return res.json()
  if (res.status >= 500) {
    const html = await res.text()
    showErrorOverlay(html)
    throw new Error('Server error')
  }
  const errBody = await res.json().catch(() => ({ error: 'Request failed' }))
  showErrorBanner(errBody.error)
  throw new Error(errBody.error)
}
```

- `showErrorBanner(msg)` — short text in a dismissible bar above the tool
- `showErrorOverlay(html)` — fullscreen overlay containing `<iframe srcdoc="...">` rendering the Razor error page; close button restores UI

No Sentry or remote logging in v1.

## Performance Budgets

| Resource                 | Cap                                          | Rationale                                                                                                                                                                                            |
|--------------------------|----------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Events per request       | 10,000 (server-side, last by timestamp desc) | Active player at 14-day Mongo retention may have tens of thousands of clicks; rendering all on canvas is feasible but JSON payload + DOM construction grow linearly. 10k chosen as generous default. |
| Screenshots per request  | 20 (paged)                                   | Thumbnail strip with paging is more usable than scroll-to-load for a few hundred screenshots.                                                                                                        |
| Total events client-side | Whatever server returned                     | No additional client-side cap. Client renders what it received.                                                                                                                                      |
| Initial state size       | < 1 KB                                       | Only `userId` + `dateRange` go through Razor data-attribute. Rest via AJAX.                                                                                                                          |

If `Events.totalAvailable > 10000`, UI banner: «Showing last 10000 of 24837 events. [Increase limit ↗]». The increase action is a v1 stub; if moderators ask, post-v1 refinement adds a query param `&limit=N` capped at, say, 50000.

### Data availability constraints

The data sources have different retention windows. Moderators must be aware that a date range can extend beyond the retention horizon for some sources:

| Source                  | Retention                                | Source of truth                                                              | Behavior on out-of-range query                |
|-------------------------|------------------------------------------|------------------------------------------------------------------------------|-----------------------------------------------|
| Mongo `fishingLog`      | 14 days                                  | External (DBA scripts; not in repo)                                          | Older events silently absent                  |
| Mongo `diagSysInfoLog`  | **unverified** (assume 14d as stopgap)   | No TTL index, no AsyncProcessor cleanup job in repo — retention out-of-band  | Older entries silently absent                 |
| SQL `Stats.Screens`     | 14 days                                  | `SqlAnalyticsProvider.ScreenStorageHorizon` + `ScreensClearingJob` (daily)   | Older screenshots silently absent             |

Mongo retention is configured outside versioned code. `Stats.Screens` retention is in-repo. There is no retention manifest covering all logs — see [DOC-003 in backlog](../backlog.md) for KB module promotion.

**UI behavior**: do **not** display a hardcoded retention banner. Empty data over a queried range is self-evident (heatmap empty, no events shown, no thumbnails). Adding a banner with a fixed «14 days» value risks misleading the moderator if the actual horizon drifts. A retention-aware banner is deferred until a verified source-of-truth manifest exists (post-v1).

## Browser & Security

- **Browser targets**: Chrome, Firefox, modern Edge. Safari and IE11 not supported. `vite.config.ts → build.target: 'esnext'`.
- **Auth**: `[CustomAuthorize(Roles = "Abuse")]` at controller level — all 4 actions require Abuse role.
- **CSRF**: all AJAX endpoints are read-only `GET`. No state changes server-side. CSRF tokens not required.
- **Calibration is local**: localStorage only, no server write. No data leaves the moderator's machine.

## Build & Deploy

### Vite output

Configured to emit stable filenames (no content hash) so Razor `<script>` / `<link>` references stay static across builds:

```ts
// vite.config.ts (key parts)
export default defineConfig({
  plugins: [vue()],
  build: {
    outDir: '../../Scripts/vue/anti-cheat',
    emptyOutDir: true,
    rollupOptions: {
      output: {
        entryFileNames: 'main.js',
        assetFileNames: 'style.css',
      },
    },
  },
})
```

### `WebAdmin.csproj` registrations

WebAdmin uses legacy .csproj (not SDK-style). Each new file must be registered explicitly.

`<Compile>`:

```xml
<Compile Include="Areas\Anticheat\AnticheatAreaRegistration.cs" />
<Compile Include="Areas\Anticheat\Controllers\GameSessionAnalysisController.cs" />
<Compile Include="Areas\Anticheat\Models\GameSessionAnalysis\GameSessionAnalysisPageModel.cs" />
<Compile Include="Areas\Anticheat\Models\GameSessionAnalysis\GameSessionAnalysisScreenshotsModel.cs" />
<Compile Include="Areas\Anticheat\Models\GameSessionAnalysis\GameSessionAnalysisEventsModel.cs" />
<Compile Include="Areas\Anticheat\Models\GameSessionAnalysis\GameSessionAnalysisMonitorInfoModel.cs" />
```

`<Content>`:

```xml
<Content Include="Areas\Anticheat\Views\Web.config" />
<Content Include="Areas\Anticheat\Views\_ViewStart.cshtml" />
<Content Include="Areas\Anticheat\Views\GameSessionAnalysis\Index.cshtml" />
<Content Include="Scripts\vue\anti-cheat\main.js" />
<Content Include="Scripts\vue\anti-cheat\style.css" />
```

`_ViewStart.cshtml` is required for `_Layout.cshtml` to apply to Area views — see [Scaffold Spike Verification](#scaffold-spike-verification-res-001).

### Built-artifact commit policy

Same as `TargetedAdsPlanningTool`: built `Scripts/vue/anti-cheat/main.js` and `style.css` are committed to SVN. CI does not run Vite. Pre-commit hook (or developer discipline) ensures `yarn build` was run before commit.

## Constraints from Admin Layout

The Razor host page loads admin-wide layout (`Site.css`, `Layout.css`, `kendo.*.css`, jQuery, jQuery UI, Kendo UI MVC). Specific behaviors of `layout.js → InitLayout(true)`:

- Initializes a fixed list of jQuery UI dialogs by ID (e.g. `#uploadDialog`, `#previewDialog`, `#editorDialog`, ...).
- Binds `keydown` handlers to specific input IDs.
- Listens for `dialogopen` / `dialogclose` on `<body>`.
- Listens for `Escape` on `document` to close parent's bottom div (only fires if hosted in iframe with `window.parent.bottomDivClose`).
- Schedules `setTimeout(InitAllGridsFilterMenu, 1000)` which walks Kendo grids on the page.

### Forbidden in Vue templates

To avoid clashes:

- **IDs** (do not use these in Vue-rendered DOM): `uploadDialog`, `previewDialog`, `editorDialog`, `txtEditorDialog`, `txtViewerDialog`, `viewDialog`, `commentDialog`, `searchDialog`, `duplicateDialog`, `revisionDialog`, `commentOnCommit`, `searchString`, `dupCommentOnCommit`, `revisionFrame`, `revisionFrom`, `revisionComment`.
- **Class** `.k-grid` — `InitAllGridsFilterMenu` looks for it.
- **Attribute** `data-role="..."` — `kendo.aspnetmvc.min.js` auto-binds Kendo widgets by it.

### Escape key handling

If a future Vue component adds a modal/popup that closes on Escape, the handler **must** call `event.stopPropagation()` after handling. Otherwise the document-level listener in `layout.js` triggers `window.parent.bottomDivClose()` if the page is in an iframe.

## Future-Phase Compatibility (ARC-006)

The architecture aims to absorb planned Phase 2-4 work without rewrite. No preemptive abstractions are added; instead, current decisions don't foreclose the future.

### Phase 2 — Timeline

Adds horizontal time axis with game sessions, fishing sessions, screenshots, catch events.

How it plugs in:

- New component `TimelineView.vue` consumes the same `events`, `screenshots`, `monitorInfo` from `App.vue` state. New fetch (game/fishing sessions) needs new AJAX endpoint(s) — added to `useApiClient.ts` and `GameSessionAnalysisController`.
- Current 3-component v1 tree extends to `App.vue → ScreenshotStrip + HeatmapView + CalibrationPanel + TimelineView`.
- Cross-highlight between Timeline and Heatmap (hover on timeline marker → highlight on canvas) is the kind of feature where Pinia might earn its keep — promote to Pinia at this point if state coordination grows hard.

### Phase 3 — Pond fishing map

Adds top-down map with cast positions (data source TBD).

How it plugs in:

- New component `PondMapView.vue`, similar pattern.
- New AJAX endpoint, new model.
- Map calibration (cast coords ↔ map coords) parallels current monitor calibration → matches the `mapCalibrations` storage key the user anticipated.

### Phase 4 — Anomaly detection

Adds server-computed signals (cluster density verdict, signature lookups).

How it plugs in:

- New AJAX endpoint `/Anticheat/GameSessionAnalysis/Anomalies?userId&from&to` returns score + per-signal traces.
- New component `AnomalyTracePanel.vue` displays scores and lets moderator click to highlight contributing events.
- Computational logic lives in helpers under `Areas/Anticheat/Models/GameSessionAnalysis/Anomalies/` if it grows; not in a separate Services layer.
- Auto-suggestion for resolution (deferred from v1) is part of this phase — port the Python algorithm in `artifacts/heatmap_gen.py`.

### Phase 5+ — Automation

Persistent server-side calibration, mass scan, banwave staging.

How it plugs in:

- Calibration storage moves from localStorage to server-side table. The composable `usePlayerCalibration` becomes API-backed; component code unchanged.
- Mass scan / banwave staging are separate epics with their own controllers under the Anticheat Area.

### What we explicitly didn't do

- No "reuse hooks" interface that future phases must implement. Composable-based reactivity is the only contract.
- No event bus / message bus. State coordination via props/emits → composables → Pinia (when it earns its keep).
- No premature service layer. Models per existing convention.

## Strategic Deliverables

### DOC-001 — README in Vue project folder

Path: `WebAdmin/Components/AntiCheatTool/README.md`. Created during initial scaffolding (Phase 4+ subtask), updated as patterns solidify. Sections:

1. What this tool is (1-2 sentences)
2. Architecture overview (Razor host + Vue island)
3. File structure
4. Build commands (`yarn build`, `yarn build:watch`, `yarn lint`, `yarn type-check`)
5. Dev workflow
6. Build output and `WebAdmin.csproj` integration
7. Initial state injection pattern (Razor `Json.Serialize` → `data-initial-state` → Vue `JSON.parse(dataset.initialState)`)
8. Kendo widget bridge (template + gotchas)
9. Explicit contrast with `TargetedAdsPlanningTool`: «If you're building a new admin Vue tool, follow this template, NOT the TargetedAdsPlanningTool's setup. That one uses Vue 2 + Vuetify with `Layout = null` because Vuetify's global CSS reset broke admin layout. We solve that by avoiding UI kits.»

### DOC-002 — KB promotion (after v1 ships)

After v1 is verified working in production:

- Add milestone to `<kb>/fishing-planet/server/modules/web-admin/log.md` with `[branch r<rev>]` stamp: «First embedded Vue 3 + TS island in admin (FP-43579 GameSessionAnalysis); pattern documented in deep-dive»
- Create deep-dive `<kb>/fishing-planet/server/modules/web-admin/embedded-vue-pattern.md` lifting the embed pattern from this tool's README to a generic recipe for future tools
- Tag `TargetedAdsPlanningTool` in the `web-admin` module card as «legacy reference, do not copy for new tools»

## Deferred / Future

The following are explicitly **not in v1** but are anticipated:

- **`RawEventsView` component** — moderator uses existing `/Player/FishingLog?userId=X` for raw event inspection in v1; in-tool view if Phase 2 timeline brings search/cross-highlight needs
- **Cross-component highlight** between RawEvents/Timeline and Heatmap
- **Auto-suggestion of resolution** — port `artifacts/heatmap_gen.py` algorithm; integrates with Phase 4 anomaly detection
- **Vite HMR** instead of `vite build --watch` — only if dev cycle becomes painful with reload
- **Pinia store** — if cross-cutting state coordination grows beyond `App.vue` single-owner model (likely Phase 4)
- **Custom positioned tooltip component** — replacing native `title` attribute when calibration-panel hovers need richer content
- **Server-side density grid** for very high event counts (>50k); reduces payload at cost of visualization fidelity
- **`GetPlayerScreensInRange(userId, from, to)` DAL method** — replaces in-memory date filter if profiling shows bottleneck for high-volume players
- **Persistent server-side calibration** (Phase 5+) — replaces localStorage with server table
- **Server-side screenshot thumbnails** — if client-side scaling of full JPEGs becomes too slow for strip with many screenshots
- **Skeleton loaders** instead of "Loading..." text — UI polish, not v1
- **«Increase limit ↗»** action behind v1 banner placeholder — implemented if moderators request
- **`timeCalibrations`, `mapCalibrations`** — sibling localStorage keys for future calibration types (key namespace already reserved by `monitorCalibrations` discriminator)

### Out of scope (won't be built in this tool)

- Cross-machine sync of calibrations (deliberate v1 constraint per requirements)
- Mobile / console UI variants — separate `CatchedFishInfoMobile.prefab` likely has different geometry, separate epic
- Cross-player aggregations / mass scan / top-N suspect lists — separate epic (Phase 5)
- Automated banwave / report generation — separate epic (Phase 5)
