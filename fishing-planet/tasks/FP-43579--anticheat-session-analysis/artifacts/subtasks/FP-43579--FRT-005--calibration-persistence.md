---
id: FRT-005
title: usePlayerCalibration composable + LRU
slice: VS2
status: done
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
- [x] Setting calibration, refreshing the page → values restored *(verified via TST-002 smoke 2026-05-04)*
- [x] Switching userId via filter form → calibration switches; switching back → previous values restored *(verified via TST-002 smoke 2026-05-04 — `isPersisted` gate covers fresh-vs-saved branching)*
- [ ] Manually filling 101 distinct userIds → oldest entry evicted, others intact *(not exercised by smoke; LRU algorithm covered by code review only)*
- [ ] Schema version bump (manually edit localStorage to `v: 2`) → returns defaults, no crash *(not exercised by smoke; discard-on-mismatch path covered by code review only)*

## Implementation notes (DONE 2026-05-03)
- Composable signature: `usePlayerCalibration(userId: Ref<string | null>): { data: Ref<CalibrationData> }`. App.vue uses returned `data` ref directly.
- Storage key `anticheat:gameSessionAnalysis:monitorCalibrations`. Schema `{ v: 1, entries: { [userId]: CalibrationEntry } }` where `CalibrationEntry = CalibrationData & { ts: number }`.
- Foreign / future schema (v !== 1) → silently discarded, returns defaults. No crash, no migration code (per architecture).
- LRU 100 on write: sort by `ts` asc, evict oldest. `ts` updated on **read AND write** (read-touch protects re-investigated players from eviction).
- Debounced save: trailing 200 ms via `setTimeout`. Slider drag (60 fps) would otherwise be 60 JSON.serialize + localStorage.setItem per second — visible main-thread jank. Debounce trades a worst-case 200 ms data loss on tab close vs smooth UX.
- `userId` switch (filter form): flush pending save under OLD id first (so changes don't carry over), then hydrate from storage for NEW id. Defaults if null userId.
- `JSON.parse(JSON.stringify(...))` snapshot at debounce time — defensive copy so subsequent reactive mutations don't sneak into the in-flight save.
- localStorage write wrapped in try/catch (quota / disabled-storage scenarios) — log + continue, don't break UX.
- Strict TS clean: `yarn type-check` 0 errors. Build: 25 modules, main.js 74.4 KB / style.css 2.6 KB (was 67.8 KB / 1.6 KB at VS1 — composable + CalibrationPanel controls add ~7 KB).
