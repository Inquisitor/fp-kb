# Embedded Vue 3 Pattern for WebAdmin Tools

How to add a Vue 3 + TypeScript SPA-style tool to the legacy ASP.NET MVC admin without breaking the shared admin chrome.

Reference implementation: `WebAdmin/Components/AntiCheatTool/` (committed in FP-43579, LBM r16063 / MFT r16064). README inside that folder mirrors this document at the tool level. This deep-dive promotes it to KB so the next tool author doesn't need to read 974 lines of the FP-43579 architecture artifact.

## When to use this pattern

Choose Vue island over plain Razor + jQuery + Kendo when the tool meets two or more of:

- Cross-cutting reactive state across multiple coordinated views (e.g. calibration → heatmap, slider → frames, screenshot pick → canvas redraw).
- Iteration on a self-contained UI surface — the kind of velocity that justifies a build pipeline.
- Component reuse anticipated (own components, plus dropping in a heavy widget like `vis-timeline`, a `<canvas>` heatmap, etc.).
- TypeScript value for contract drift between server JSON and client consumption.

If the tool is a simple form + table, Razor + Kendo MVC is still the right choice.

## Why not Vuetify (or any UI kit with global CSS reset)

The historical attempt `WebAdmin/Components/TargetedAdsPlanningTool/` (Vue 2 + Vuetify) breaks admin chrome:

- Vuetify bundles `ress.css` reset inside `chunk-vendors.css` with unscoped global rules: `html { box-sizing: border-box; ... }`, `* { padding: 0; margin: 0 }`, `details, main { display: block }`, etc.
- Loading that CSS into the admin layout breaks Kendo grids, sidebar typography, table spacing throughout the rest of WebAdmin.
- The TargetedAdsPlanningTool ships `Layout = null;` to avoid blowing up the admin — losing admin chrome entirely. Anything beyond a one-off page is unacceptable on those terms.

Quasar / Element Plus / Naive UI / PrimeVue (styled mode) ship similar resets. Headless libraries (Reka UI, Floating Vue) are safe for specific widgets if needed; not preemptively bundled.

**Rule: no UI kit. Scoped styles per component. Reach for Kendo CSS classes (`k-button`, `k-textbox`) for admin-consistent look; reach for jQuery widget bridge (below) for the occasional Kendo widget like Dropdown.**

## High-level architecture

```
URL: /<ToolName>/<Action>?<query>
                ↓
Razor host page (Views/<ToolName>/Index.cshtml or similar)
  - Renders admin chrome via _Layout + _PlayerToolsPartial
  - Renders Razor-side filter form (Kendo date pickers, hidden inputs)
  - Renders <div id="<tool>-app" data-initial-state='{"userId":"...","dateRange":{...}}'></div>
  - Loads <link rel="stylesheet" href="~/Scripts/vue/<tool>/style.css">
  - Loads <script src="~/Scripts/vue/<tool>/main.js"></script>
                ↓
Vue 3 island
  - createApp(App, JSON.parse(div.dataset.initialState)).mount('#<tool>-app')
  - On mount: kicks off parallel AJAX requests against tool-specific controller actions
  - Filter form submit intercepted by JS → CustomEvent → Vue re-fetches state
  - URL updated via history.pushState (shareable / bookmarkable)
```

The filter form lives **outside** Vue because Kendo date pickers expect a jQuery world. Communication from form → Vue is via a `CustomEvent` dispatched on the mount element. Vue exports nothing into `window` — strict separation, idiomatic for future SPA migration.

## Project layout

For a new tool named e.g. `MyTool`:

```
WebAdmin/WebAdmin/
├── Components/MyTool/                              ← Vue project root (yarn workspace-like, but standalone)
│   ├── package.json, tsconfig.json, vite.config.ts
│   ├── README.md                                    ← per-tool details + history
│   ├── src/
│   │   ├── main.ts                                  ← entry: createApp().mount()
│   │   ├── App.vue                                  ← root component, owns cross-cutting state
│   │   ├── components/                              ← presentational components
│   │   ├── composables/                             ← reactive stores (useApiClient, useXyzCalibration, ...)
│   │   ├── kendo/                                   ← jQuery widget bridges if any
│   │   ├── types/                                   ← TS counterparts of server DTOs
│   │   └── shims-vue.d.ts
│   └── (dist/ not committed; vite outputs to ../../Scripts/vue/<tool>/)
├── Controllers/<MyTool>/                            ← namespaced folder for tool controllers
│   └── MyToolController.cs
├── Models/<MyTool>/<Action>/                        ← per-action model files
│   ├── MyToolPageModel.cs                           ← Index view model
│   ├── MyToolXxxAjaxModel.cs                        ← per AJAX endpoint
│   └── ...
├── Views/<MyTool>/                                  ← Razor host views (NOT under Areas/)
│   └── Index.cshtml
├── Scripts/vue/<tool>/                              ← Vite build output (committed to SVN)
│   ├── main.js                                      ← stable filename (no hash)
│   └── style.css                                    ← stable filename
└── WebAdmin.csproj                                  ← <Compile> / <Content> entries for ALL new files
```

The Vue project under `Components/<MyTool>/` is its own yarn project (own `package.json` and `node_modules`). It is not a workspace member of a top-level `package.json` — each tool stands alone.

## Tech stack and rationale

| Choice                 | Rationale                                                                                                                             |
|------------------------|---------------------------------------------------------------------------------------------------------------------------------------|
| Vue 3                  | `<script setup>` is the current idiomatic API. Vue 2 is on maintenance.                                                               |
| TypeScript             | Catches drift between server JSON shape and client consumption. `tsconfig.json` enables `"strict": true` + all sub-flags.             |
| Vite                   | `vue-cli-service` is on maintenance (webpack 4). Vite uses esbuild for dev (~200 ms full rebuild). Production via Rollup → small JS.  |
| No UI kit              | Global CSS resets break admin chrome. Use Kendo CSS classes for visual consistency; bridge to Kendo widgets when needed.              |
| Composables-as-store   | `usePlayerCalibration(userId)` etc. — Vue's reactivity + scoping is enough for ~5-component trees. Pinia introduced only when needed. |
| jQuery widget bridge   | Limited to Kendo widgets that require widget-generated DOM (Dropdown, Grid, etc.). See [Kendo widget bridge](#kendo-widget-bridge).   |

### TypeScript strictness

`tsconfig.json` enables `"strict": true` (implies `noImplicitAny`, `strictNullChecks`, `strictFunctionTypes`, `strictBindCallApply`, `alwaysStrict`, `strictPropertyInitialization`). Plus `forceConsistentCasingInFileNames` and `isolatedModules`. Loosening any flag requires a comment explaining why and a TODO — do not silently disable.

### Browser targets

Chrome, Firefox, modern Edge. Safari and IE11 explicitly out of scope. `vite.config.ts → build.target: 'esnext'` — no polyfills, no legacy transpilation.

## Initial-state injection (Razor → Vue)

The Razor host serialises bootstrap state into a `data-initial-state` attribute. Vue reads it on mount.

Razor:

```cshtml
<div id="mytool-app"
     data-initial-state="@Json.Serialize(Model.Data)"></div>
```

`Model.Data` is the JSON-friendly anonymous projection following the WebAdmin Model convention.

Vue (`main.ts`):

```ts
import { createApp } from 'vue'
import App from './App.vue'

const el = document.getElementById('mytool-app')!
const initialState = JSON.parse(el.dataset.initialState!)
createApp(App, { initialState }).mount(el)
```

Keep initial state small (`< 1 KB`). For larger payloads, ship a stub initial state with userId + date range, then fire AJAX requests on mount to populate the rest. The bigger the embedded JSON, the harder the Razor side becomes to read.

## Filter form refresh (Razor → Vue via CustomEvent)

Filter form is outside Vue (Razor + Kendo date pickers). Apply submit is intercepted by JS, which dispatches a `CustomEvent` on the mount element. Vue listens during mount and re-fetches.

Razor:

```cshtml
<form id="anticheat-filter">
    <input id="userId" name="userId" value="@Model.UserId" />
    <input id="from"   name="from" />
    <input id="to"     name="to" />
    <input type="submit" class="k-button" value="Apply" />
</form>

<script>
    document.getElementById('anticheat-filter').addEventListener('submit', function(e) {
        e.preventDefault();
        var qs = new URLSearchParams(new FormData(e.target)).toString();
        history.pushState({}, '', '?' + qs);
        document.getElementById('mytool-app').dispatchEvent(
            new CustomEvent('mytool:refresh', { detail: { userId: ..., from: ..., to: ... } })
        );
    });
    $(document).ready(function() {
        CreateKendoUtcDateTimePickerFor('#fromPicker', '#from');
        CreateKendoUtcDateTimePickerFor('#toPicker',   '#to');
    });
</script>
```

Vue (`main.ts`):

```ts
const el = document.getElementById('mytool-app')!
el.addEventListener('mytool:refresh', (e) => {
  // re-fetch AJAX data with new params
  refreshSignal.value++
})
```

**Why CustomEvent, not `window.MyTool.refresh()`:** no global namespace pollution; mount-order race is explicit (event fires before Vue mounts → DevTools shows "no listeners", not a TypeError); idiomatic for future SPA where refresh is triggered by router state.

Also handle browser Back / Forward:

```ts
window.addEventListener('popstate', () => {
  // parse URLSearchParams from window.location.search
  // sync form input values (and Kendo widget values via widget.value(new Date(...)))
  // dispatch the same CustomEvent
})
```

Without `popstate` handler, the URL changes silently on Back navigation but Vue stays on stale data — confusing.

**Date parsing pitfall:** when reading UTC datetime strings from URL params, `new Date("2026-05-09 14:23:11")` parses as **local time** per ECMA-262 (no `Z` designator). Use a helper like `parseUtc(s)` that converts `"yyyy-MM-dd HH:mm:ss"` → `"yyyy-MM-ddTHH:mm:ssZ"` before `new Date(...)`. Kendo widget then receives correctly-zoned dates.

## Routing

**Do NOT use MVC Areas** for tools that share `_Layout.cshtml`. See [`feedback/aspnet_mvc_area_ambient_strand`](../../../../feedback/aspnet_mvc_area_ambient_strand.md) for full reasoning.

Custom route registered ahead of Default in `App_Start/RouteConfig.cs`:

```csharp
routes.MapRoute(
    name: "MyTool",
    url: "MyTool/{controller}/{action}/{id}",
    defaults: new { controller = "MyToolController", action = "Index", id = UrlParameter.Optional },
    constraints: new { controller = "MyToolController|OtherToolController" },
    namespaces: new[] { "WebAdmin.Controllers.MyTool" });

routes.MapRoute(/* Default */ ...);  // unchanged, after MyTool
```

Controllers live under `Controllers/MyTool/` with namespace `WebAdmin.Controllers.MyTool`. This isolates URL generation: shared layout `Html.ActionLink("Home", "Index", "Home")` correctly produces `/Home/Index` (no `area` ambient strand to redirect through the tool route).

To add another tool under the same prefix later, broaden the `controller` regex. To group multiple tools under different prefixes, register multiple custom routes ahead of Default — each with its own namespace constraint.

## Build pipeline

`vite.config.ts` emits to `../../Scripts/vue/<tool>/` with stable filenames (no content hash) so Razor `<script>` / `<link>` tags can reference statically:

```ts
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  build: {
    outDir: '../../Scripts/vue/mytool',
    emptyOutDir: true,
    target: 'esnext',
    rollupOptions: {
      output: {
        entryFileNames: 'main.js',
        assetFileNames: 'style.css',
      },
    },
  },
})
```

### Build commands

| Command            | Purpose                                                                    |
|--------------------|----------------------------------------------------------------------------|
| `yarn build`       | Production build, one-shot. Used for pre-commit assets.                    |
| `yarn build:watch` | Dev cycle: rebuilds on file save (~1-3s), no HMR. F5 in browser to reload. |
| `yarn type-check`  | `vue-tsc --noEmit` for TS contract validation (not implicit in build).     |
| `yarn lint`        | ESLint across `src/`.                                                      |

### Committed-artifact policy

Built `Scripts/vue/<tool>/main.js` and `style.css` are committed to SVN. CI does not run Vite. Pre-commit hook (or developer discipline) ensures `yarn build` ran before commit. Same policy as the legacy `TargetedAdsPlanningTool`. Acceptable v1 tradeoff — if rotted artifacts become an issue, add a CI step.

## WebAdmin.csproj registrations

WebAdmin uses legacy non-SDK csproj. Every new file must be registered explicitly. Forgetting an entry compiles locally (file picked up by glob from disk) but fails to deploy.

```xml
<!-- Backend -->
<Compile Include="Controllers\MyTool\MyToolController.cs" />
<Compile Include="Models\MyTool\MyToolPageModel.cs" />
<Compile Include="Models\MyTool\MyToolXxxAjaxModel.cs" />

<!-- Razor view -->
<Content Include="Views\MyTool\Index.cshtml" />

<!-- Vite output -->
<Content Include="Scripts\vue\mytool\main.js" />
<Content Include="Scripts\vue\mytool\style.css" />
```

The Vue source files under `Components/MyTool/src/` are NOT registered as `<Content>` — they are pure source, never deployed. Only the Vite output gets shipped.

## Backend layering inside the tool

Convention follows existing WebAdmin pattern: thin Controller → Models with `Fill(...) + Data` projection → DalFactory providers. No Services layer.

```csharp
[CustomAuthorize(Roles = "Abuse")]
public class MyToolController : BaseController
{
    public ActionResult Index(string userId, DateTime? from = null, DateTime? to = null)
    {
        var model = new MyToolPageModel { UserId = userId, From = from ?? DefaultFrom, To = to ?? DefaultTo };
        return View(model);
    }

    public JsonResult SomeAjaxAction(string userId, DateTime from, DateTime to)
    {
        if (!ValidateInputs(userId, from, to, out var error)) return JsonResponse(error);
        var model = new MyToolXxxAjaxModel();
        model.Fill(userId, from, to);
        return JsonResponse(model.Data);
    }
}
```

Class-level `[CustomAuthorize(Roles = "...")]` covers all actions.

**Input validation pattern**: extract a `ValidateInputs(userId, from, to, out errorJson)` helper if the controller has multiple AJAX actions sharing the same checks. Always `Guid.TryParse(userId, ...)` — never `new Guid(userId)` raw (throws `FormatException` → unhandled 500).

**Default date range**: `[UtcNow.Date.AddDays(-1), UtcNow]` is a sane "yesterday onwards" default. Do NOT hardcode dates.

## State management in Vue

App.vue owns cross-cutting reactive state. Composables encapsulate reusable concerns (API client, calibration persistence, etc.). No store (Pinia) preemptively.

```ts
// App.vue
const userId             = ref<string>(props.initialState.userId)
const dateRange          = ref<DateRange>(props.initialState.dateRange)

const screenshots        = ref<Screenshot[]>([])
const events             = ref<ClickEvent[]>([])

const { data: calibration } = usePlayerCalibration(userId)

// Per-section loading flags
const screenshotsLoading = ref(false)
const eventsLoading      = ref(false)
```

Slider drag inside `CalibrationPanel` emits `update:offsetX` → `App.vue` mutates `calibration.value.offsetX` → composable's `watch` fires → persists to localStorage (debounced).

**LocalStorage namespacing** — use the URL hierarchy:

```
<tool-prefix>:<tool-name>:<dataType>
```

e.g. `anticheat:gameSessionAnalysis:monitorCalibrations`. The `dataType` discriminator reserves namespace for future sibling data (e.g. `timeCalibrations`) without migration.

**Debounce localStorage writes**. Slider drag at 60fps without debounce = 60 JSON.stringify + setItem per second = visible main-thread block. 200ms trailing debounce is enough. Flush pending writes before reloading on key change (e.g. userId switch).

**LRU eviction.** Cap at e.g. 100 entries; on write that would overflow, drop oldest. Update `ts` field on **both** read and write — `ts` reflects last-touched, not last-modified. A moderator returning to a player they investigated weeks ago "touches" the entry on load, protecting it from eviction in subsequent overflows.

**Schema versioning.** Tag the JSON with `v: 1`. Read attempt with mismatched version → discard, return defaults. Moderator loses past calibrations on first load after deploy. Acceptable for client-side state; revisit if server-side persistence lands.

## Visual consistency (Kendo CSS classes + widget bridge)

The admin layout loads `kendo.common.min.css` + `kendo.default.min.css` globally. Use Kendo CSS classes selectively for admin-consistent look without depending on widget-generated DOM:

| Element                              | Approach                                                                                            |
|--------------------------------------|-----------------------------------------------------------------------------------------------------|
| Buttons                              | `<button class="k-button">`                                                                         |
| Text inputs (within Vue)             | `<input class="k-textbox">`                                                                         |
| Date pickers                         | Native `<input type="datetime-local">` if v1 OK with browser-native; else Kendo via Razor (outside Vue) |
| Dropdowns                            | Native `<select>` with scoped Kendo-palette CSS, OR jQuery widget bridge (below)                    |
| Sliders / radios / checkboxes        | Native HTML + scoped CSS                                                                            |
| Tooltips                             | Native `title` attribute (v1); custom positioned component if richer content needed                 |

### What works as `.k-*` class

Confirmed: `k-button`, `k-textbox`. Most container helpers (`k-content`, `k-window`).

**Does NOT work** without widget-generated DOM: `k-dropdown`, `k-grid`, `k-tabstrip`, `k-treeview`, `k-tooltip`. Those CSS rules style markup that jQuery widgets produce, not bare HTML.

### Kendo widget bridge

When a Kendo widget is genuinely needed (Dropdown most commonly), wrap the jQuery widget in a Vue bridge component. Template:

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

**Critical points:**

- The bridge `<input>` element MUST NOT be re-rendered by Vue (template is stable; props change but element identity persists).
- `widget.destroy()` in `onBeforeUnmount` is mandatory — leaks otherwise.
- Widget popups attach to `<body>`, not inside the bridge element. Scoped styles don't reach popups; use the globally-loaded Kendo theme.
- Empty-string ↔ null boundary: Kendo dropdowns use empty-string for "nothing selected"; Vue often models that as `null`. Bridge writes through with conversion guards.

### Stop-criteria for the bridge

If the bridge fails (popup positioning broken, jQuery / Vue DOM ownership conflict, more than ~2 hours of work), fall back to:

- `<select class="kendo-like-select">` with scoped CSS imitating Kendo palette (border `#c5c5c5`, accent `#3e80cf`, font `Segoe UI` — copied from Kendo via DevTools, not the class names themselves).

Document the attempt + cause in the tool's README so the next author has the trail.

## Constraints from admin layout

The Razor host loads admin-wide layout. Specific behaviors of `layout.js → InitLayout(true)`:

- Initializes a fixed list of jQuery UI dialogs by ID (e.g. `#uploadDialog`, `#previewDialog`, `#editorDialog`).
- Binds `keydown` handlers to specific input IDs.
- Listens for `dialogopen` / `dialogclose` on `<body>`.
- Listens for `Escape` on `document` to close parent's bottom div (only fires if hosted in iframe).
- Schedules `setTimeout(InitAllGridsFilterMenu, 1000)` which walks Kendo grids on the page.

### Forbidden inside Vue templates

- **IDs**: `uploadDialog`, `previewDialog`, `editorDialog`, `txtEditorDialog`, `txtViewerDialog`, `viewDialog`, `commentDialog`, `searchDialog`, `duplicateDialog`, `revisionDialog`, `commentOnCommit`, `searchString`, `dupCommentOnCommit`, `revisionFrame`, `revisionFrom`, `revisionComment` — admin scripts bind handlers to these.
- **Class `.k-grid`** — `InitAllGridsFilterMenu` walks it.
- **Attribute `data-role="..."`** — `kendo.aspnetmvc.min.js` auto-binds Kendo widgets by it.
- **Bare semantic tags** (`<header>/<footer>/<aside>/<main>/<nav>`) — admin's global CSS targets them. See [`feedback/vue_island_bare_semantic_tags`](../../../../feedback/vue_island_bare_semantic_tags.md). Use `<div class="<component>-header">` etc.

### Escape key

If a Vue component adds a modal that closes on Escape, the handler MUST call `event.stopPropagation()` after handling. Otherwise the document-level listener in `layout.js` triggers `window.parent.bottomDivClose()` if the page is in an iframe.

## Loading and error UX

Three (or N) AJAX requests fire in parallel on mount. Each component gets its own `isLoading` prop and renders a per-section indicator. UI never globally blocks.

```ts
onMounted(() => {
  Promise.allSettled([
    fetchA().finally(() => aLoading.value = false),
    fetchB().finally(() => bLoading.value = false),
    fetchC().finally(() => cLoading.value = false),
  ])
})
```

### Error handling

`useApiClient.ts` wraps `fetch`:

```ts
async function call(url: string): Promise<any> {
  const res = await fetch(url, { credentials: 'same-origin' })
  if (res.ok) return res.json()
  if (res.status >= 500) {
    const html = await res.text()
    showErrorOverlay(html)   // <iframe sandbox srcdoc="..."> rendering Razor error page
    throw new Error('Server error')
  }
  // body read ONCE; attempt JSON parse, fall back to text
  const text = await res.text()
  let errMsg = 'Request failed'
  try { errMsg = JSON.parse(text).error ?? errMsg } catch { /* fall through */ }
  showErrorBanner(errMsg)
  throw new Error(errMsg)
}
```

- `showErrorBanner(msg)` — short text in dismissible bar above the tool.
- `showErrorOverlay(html)` — fullscreen overlay containing `<iframe sandbox srcdoc="...">` with the Razor error page. Sandbox prevents parent access. One concurrent overlay; second 5xx replaces.

Read response body ONCE — `await res.json()` followed by `await res.text()` throws because the body is already consumed.

## Performance budgets

| Resource              | Cap                                  | Rationale                                                        |
|-----------------------|--------------------------------------|------------------------------------------------------------------|
| Events per request    | 10,000 server-side (last by ts desc) | DOM construction and JSON payload grow linearly with count       |
| Initial state size    | < 1 KB                               | Just bootstrap (userId, dateRange); rest via AJAX                |
| Vite main.js          | Aim < 100 KB minified                | Reference: AntiCheatTool's 79 KB. Vuetify-based tool: 600 KB+    |
| Slider-driven writes  | 200ms debounced                      | Avoid main-thread block from 60fps writes                        |

For collection queries (e.g. message-filtered `fishingLog`), use the Mongo content-filter pushdown — see [`reference/mongo_logbase_pushdown`](../../../../reference/mongo_logbase_pushdown.md). Without pushdown an active-player query enumerates hundreds of thousands of BSON docs (~30 min observed in FP-43579).

## Checklist for adding a new tool

```
□ Decide URL prefix: /MyTool/...
□ App_Start/RouteConfig.cs:
  □ Custom MapRoute ahead of Default with controller regex + namespace constraint
□ Controllers/MyTool/MyToolController.cs (namespace WebAdmin.Controllers.MyTool)
  □ [CustomAuthorize(Roles = "...")] at class level
  □ Index action returning View(model)
  □ Per-AJAX action returning JsonResponse(model.Data)
  □ Guid.TryParse for userId (never raw new Guid())
□ Models/MyTool/<Action>Model.cs per action
  □ Fill(...) + Data projection convention
□ Views/MyTool/Index.cshtml
  □ @{ Layout = "~/Views/Shared/_Layout.cshtml"; }
  □ <div id="mytool-app" data-initial-state="@Json.Serialize(Model.Data)"></div>
  □ <link>/<script> for Vite output
  □ Filter form + JS submit handler + popstate handler
□ Components/MyTool/ project
  □ package.json, tsconfig.json (strict), vite.config.ts (outDir to ../../Scripts/vue/mytool)
  □ src/main.ts (createApp().mount() + CustomEvent listener)
  □ src/App.vue (root state)
  □ src/components/ (presentational), composables/, types/
  □ README.md (mirrors this deep-dive at the tool level)
□ Scripts/vue/mytool/ (committed Vite output)
□ WebAdmin.csproj registrations
  □ <Compile Include> for all .cs files
  □ <Content Include> for .cshtml + Scripts/vue/mytool/{main.js,style.css}
□ Link in Views/Shared/_PlayerToolsPartial.cshtml (per-player) and/or Views/Player/CheatContent.cshtml (global) — match access pattern
□ Sanity: yarn build (succeeds), yarn type-check (0 errors), browser smoke (auth gate, AJAX endpoints, refresh form, popstate)
```

## TargetedAdsPlanningTool contrast

| Aspect              | TargetedAdsPlanningTool (legacy)        | This pattern (use this)                     |
|---------------------|-----------------------------------------|---------------------------------------------|
| Vue version         | Vue 2                                   | Vue 3 + `<script setup>`                    |
| Language            | JavaScript                              | TypeScript strict                           |
| Build               | vue-cli-service (webpack 4)             | Vite (esbuild)                              |
| UI kit              | Vuetify                                 | None (Kendo CSS classes + bridge if needed) |
| Admin chrome        | Broken (`Layout = null` to escape Vuetify reset) | Intact (no UI kit reset)                |
| Bundle size         | 600+ KB (chunk-vendors-heavy Vuetify)   | ~80 KB                                      |
| Routing             | Standalone page                         | Custom route + namespaced controllers       |
| State coordination  | Vuex                                    | Composables; Pinia introduced if needed     |

**For any new admin Vue tool, follow this pattern, NOT TargetedAdsPlanningTool's setup.**
