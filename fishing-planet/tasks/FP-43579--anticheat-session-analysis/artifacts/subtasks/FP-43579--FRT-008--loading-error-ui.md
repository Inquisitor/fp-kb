---
id: FRT-008
title: Per-section loading + error overlay/banner
slice: VS4
status: todo
depends-on: [FRT-002, FRT-003, FRT-006]
effort: S
---

## Scope
Replace «Loading...» placeholders with proper indicators and surface 4xx/5xx errors per [architecture → Loading UX & Error Handling](../architecture.md#loading-ux-error-handling).

## Files
- Modify: `src/components/{ScreenshotStrip, HeatmapView, CalibrationPanel}.vue` — inline loader placement (text or simple CSS spinner)
- Modify: `src/composables/useApiClient.ts` — `showErrorBanner(msg)` and `showErrorOverlay(html)` helpers
- Modify: `src/App.vue` — banner / overlay render slots at root

## Implementation notes
- Loading text fine for v1 (skeleton loaders are deferred per architecture).
- Error banner: dismissible bar at the top of `App.vue`, persists last error message.
- Error overlay for 5xx: `<iframe srcdoc="...">` showing the Razor error page; close button restores UI.
- One concurrent overlay max — second 5xx replaces.

## Exit criteria
- [ ] Throttle network in DevTools → all 3 sections show their own indicator until done
- [ ] Force a 4xx (manually request `?userId=invalid`) → banner displays error message
- [ ] Force a 5xx (kill DAL connection / use a debug hack) → overlay shows error page; close button restores
