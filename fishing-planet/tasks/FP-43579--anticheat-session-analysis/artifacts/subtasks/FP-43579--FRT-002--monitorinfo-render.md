---
id: FRT-002
title: MonitorInfo wired to CalibrationPanel
slice: VS1
status: todo
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
- [ ] Open page with a userId that has `diagSysInfoLog` data → CalibrationPanel shows monitor strings
- [ ] Open with userId missing data → empty list, no console error
- [ ] Network tab shows one MonitorInfo XHR fired on mount
