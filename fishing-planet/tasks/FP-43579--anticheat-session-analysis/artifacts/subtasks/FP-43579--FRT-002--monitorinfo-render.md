---
id: FRT-002
title: MonitorInfo wired to CalibrationPanel
slice: VS1
status: done
depends-on: [BCK-001, FRT-001]
effort: S
---

## Scope
Make `useApiClient.fetchMonitorInfo` actually call BCK-001 endpoint, populate `App.vue` `monitorInfo` ref on mount, render `distinctValues` list inside `CalibrationPanel` placeholder.

## Files
- Modify: `src/composables/useApiClient.ts` — real `fetchMonitorInfo` impl
- Modify: `src/App.vue` — `onMounted` triggers `fetchMonitorInfo`, sets `monitorInfo`
- Modify: `src/components/CalibrationPanel.vue` — render `monitorInfo.distinctValues` as plain `<ul>` (calibration controls land in FRT-004)

## Exit criteria
- [x] Open page with a userId that has `diagSysInfoLog` data → CalibrationPanel shows monitor strings *(verified via TST-002 smoke 2026-05-04)*
- [x] Open with userId missing data → empty list, no console error *(verified via TST-002 smoke 2026-05-04 — empty `distinctValues[]` flows through to "No monitor info recorded" placeholder)*
- [x] Network tab shows one MonitorInfo XHR fired on mount *(verified via TST-002 smoke 2026-05-04)*

## Implementation notes (DONE 2026-05-03)
- `useApiClient.fetchMonitorInfo` was already real in FRT-001 (no stub layer to remove).
- `App.vue` `onMounted` calls `loadMonitorInfo()` which guards on `userId` + `dateRange` (both come from initial state — no-op if either missing). Sets `monitorLoading` true around the fetch; on error logs to console and resets `monitorInfo` to `null` (component shows "No monitor info recorded").
- `CalibrationPanel.vue` rendering of `monitorInfo.distinctValues` was already wired in FRT-001 — empty list renders the placeholder, populated list renders the `<ul>`.
- `loadMonitorInfo` is a named function rather than inline `onMounted` body — BCK-004 will reuse it from the refresh listener.
