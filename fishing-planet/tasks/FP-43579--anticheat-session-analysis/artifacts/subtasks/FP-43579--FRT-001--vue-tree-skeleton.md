---
id: FRT-001
title: Vue component tree skeleton + types + API client
slice: VS1
status: todo
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
- [ ] `yarn build` succeeds with new tree, output to `Scripts/vue/anti-cheat/main.js`
- [ ] Page loads without console errors; three component placeholders visible inside the admin chrome
- [ ] `useApiClient` exports `fetchMonitorInfo / fetchEvents / fetchScreenshots` typed signatures (impl can be stubs returning resolved Promise of empty data)
