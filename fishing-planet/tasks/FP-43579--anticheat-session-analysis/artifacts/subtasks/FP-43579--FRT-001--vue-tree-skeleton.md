---
id: FRT-001
title: Vue component tree skeleton + types + API client
slice: VS1
status: done
depends-on: []
effort: M
---

## Scope
Replace scaffold's stub `App.vue` with the v1 component tree (`ScreenshotStrip` + `HeatmapView` + `CalibrationPanel`), state in `App.vue`, AJAX client wired but not yet hitting endpoints. Components render «Loading...» placeholders.

## Files
- Create: `WebAdmin/WebAdmin/Components/AntiCheatTool/src/components/{ScreenshotStrip,HeatmapView,CalibrationPanel}.vue`
- Create: `src/composables/useApiClient.ts` — wraps `fetch`, `credentials: 'same-origin'`, error helpers (overlay/banner stubs in FRT-008)
- Create: `src/types/{ClickEvent,Screenshot,MonitorInfo,CalibrationData}.ts`
- Modify: `src/App.vue` — owner of all cross-cutting state per [architecture → State ownership](../architecture.md#state-ownership-in-appvue)
- Modify: `src/main.ts` — register `anticheat:refresh` CustomEvent listener (FRT-001 stub; BCK-004 wires emission)

## Implementation notes
- Strict TS (`tsconfig.json` already `"strict": true`).
- No store / Pinia; composables-as-store.
- Loading flags (`screenshotsLoading`, `eventsLoading`, `monitorLoading`) declared but stuck `false` until VS-specific endpoints land.
- `usePlayerCalibration` composable created in FRT-005; here use a local `ref` placeholder.

## Exit criteria
- [x] `yarn build` succeeds with new tree, output to `Scripts/vue/anti-cheat/main.js` *(run repeatedly throughout iterations; final 28 modules clean)*
- [x] Page loads without console errors; three component placeholders visible inside the admin chrome *(verified via TST-002 smoke 2026-05-04 — placeholders later replaced by real impls in VS2/VS3, smoke covers final state)*
- [x] `useApiClient` exports `fetchMonitorInfo / fetchEvents / fetchScreenshots` typed signatures — `fetchMonitorInfo` real, others return resolved Promise of empty data until BCK-002/003 land

## Implementation notes (DONE 2026-05-03)
- `useApiClient` hook returns the three named fetchers; `ApiError` exported separately. `fetchMonitorInfo` calls real BCK-001 endpoint via `fetch`; `fetchEvents` and `fetchScreenshots` return empty payloads matching their interface so the VS1 demo doesn't 404 when they're called from BCK-004 refresh.
- `App.vue` owns all cross-cutting state per architecture (no Pinia). FRT-005 will swap local `calibration` ref for `usePlayerCalibration(userId)` composable.
- `main.ts` registers `anticheat:refresh` listener as a no-op stub; BCK-004 fills in the body.
- Three components render placeholders with their FRT-### where the real impl lands.
- `node_modules` and `.git` already covered by `svn:global-ignores` on the `Components/AntiCheatTool/` folder (matches `TargetedAdsPlanningTool` setup); `.env` covered by `svn:ignore`.
