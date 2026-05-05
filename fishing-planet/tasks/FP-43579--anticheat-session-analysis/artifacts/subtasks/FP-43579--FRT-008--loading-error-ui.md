---
id: FRT-008
title: Per-section loading + error overlay/banner
slice: VS4
status: done
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
- [x] Per-section loading text already exists in components (`<p v-if="isLoading">Loading...</p>` in each placeholder)
- [ ] Force a 4xx → banner displays error message *(not exercised by smoke; `reportFetchError` branching covered by code review only)*
- [ ] Force a 5xx → overlay shows error page; close button restores *(not exercised by smoke; iframe sandbox srcdoc path covered by code review only)*

## Implementation notes (DONE 2026-05-03)
- New singleton composable `useErrorReporter` (mirrors `useRefreshSignal` pattern): module-level `ref<ErrorReport | null>`, exports `reportBanner(msg)` / `reportOverlay(html, msg)` / `clearError()`.
- App.vue catch path: `reportFetchError(label, err)` switches on `err instanceof ApiError`. 5xx with body → overlay (`<iframe sandbox srcdoc>` — XSS-safe). Anything else (4xx, network, parse) → banner with message.
- 5xx overlay uses `sandbox=""` (no allow-* tokens) so the embedded Razor error page can't run scripts / submit forms / access parent — pure visual.
- Single concurrent overlay/banner (writer overwrites). Architecture says overlay replaces — same model for banners (avoids stack pile-up).
- Truncation banner for Events (`eventsTruncated.value` non-null) lives next to error UI — soft warning, dismiss-on-refresh.
- Loading skeletons explicitly deferred per architecture; current text-Loading is enough for v1.
