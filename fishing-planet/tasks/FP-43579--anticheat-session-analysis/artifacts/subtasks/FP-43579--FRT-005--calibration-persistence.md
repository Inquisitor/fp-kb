---
id: FRT-005
title: usePlayerCalibration composable + LRU
slice: VS2
status: todo
depends-on: [FRT-004]
effort: S
---

## Scope
Replace placeholder `calibration` ref in `App.vue` with `usePlayerCalibration(userId)` composable per [architecture → Calibration Persistence](../architecture.md#calibration-persistence-arc-005).

## Files
- Create: `src/composables/usePlayerCalibration.ts`
- Modify: `src/App.vue` — swap placeholder for composable

## Implementation notes
- Storage key: `anticheat:gameSessionAnalysis:monitorCalibrations`.
- Schema versioned (`v: 1`); on `v !== 1` discard, return defaults.
- LRU at >100 entries on write; `ts` updated on read AND write.
- `watch(data, save, { deep: true })` for persistence — but **debounce save by 200ms trailing** (e.g. via lodash-style local impl). Slider drag on offsetX/Y at 60fps would otherwise produce 60 JSON.serialize + localStorage writes per second, blocking the main thread visibly. Final state is what matters; intermediate frames not.
- `watch(userId, reload)` — when filter form swaps userId, hydrate from storage. Flush any pending debounced save before reload to avoid carry-over.

## Exit criteria
- [ ] Setting calibration, refreshing the page → values restored
- [ ] Switching userId via filter form → calibration switches; switching back → previous values restored
- [ ] Manually filling 101 distinct userIds (via DevTools script) → oldest entry evicted, others intact
- [ ] Schema version bump (manually edit localStorage to `v: 2`) → returns defaults, no crash
