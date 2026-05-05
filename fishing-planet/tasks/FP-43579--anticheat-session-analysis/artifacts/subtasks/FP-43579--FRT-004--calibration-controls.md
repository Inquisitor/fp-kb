---
id: FRT-004
title: CalibrationPanel — resolution preset, manual, offsets
slice: VS2
status: done
depends-on: [FRT-003]
effort: M
---

## Scope
Working calibration UI: preset resolution dropdown (native `<select>` for now — Kendo bridge in FRT-009), manual width slider with aspect-ratio radio, offsetX/offsetY sliders. All values flow through `App.vue` state to `HeatmapView` via props.

## Files
- Create: `src/calibration/aspectRatios.ts` — parametric `STANDARD_ASPECT_RATIOS` per [architecture → Aspect ratio parameterisation](../architecture.md#aspect-ratio-parameterisation-calibrationpanel-manual-mode)
- Modify: `src/components/CalibrationPanel.vue` — controls
- Modify: `src/App.vue` — wire `calibration` ref (placeholder from FRT-001), pass to children
- Modify: `src/types/CalibrationData.ts` — match schema in [architecture → Calibration storage](../architecture.md#schema)

## Implementation notes
- Use `k-button`, `k-textbox` classes per [Visual Consistency](../architecture.md#visual-consistency-strategy). Native `<select>`, `<input type="range">`, `<input type="radio">`.
- Resolution presets: collect `monitorInfo.distinctValues` + a curated list (`1280x720`, `1920x1080`, `2560x1440`, `3840x2160`). Dedupe.
- Manual mode: aspect ratio radio iterates over `Object.keys(STANDARD_ASPECT_RATIOS)` (currently `'16:9'`, `'16:10'`, `'4:3'`) + width slider → `height = width * ratio.h / ratio.w`. Adding new standard AR = one entry in `aspectRatios.ts`, no UI edits. Custom (non-standard) AR support deferred — schema `CalibrationData.resolution.manual.aspectRatio: string` accommodates a future free-text input.
- Slider drag emits `update:offsetX/Y/resolution` → `App.vue` mutates → `HeatmapView` re-renders via watch.
- Debounce localStorage persistence (FRT-005) so slider drag doesn't write on every event.

## Exit criteria
- [x] Preset switch visibly re-renders heatmap (Expand-mode scaling math from `uiGeometry.ts`) *(verified via TST-002 smoke 2026-05-04 — incl. 21:9 ultrawide centring offset bug fix)*
- [x] Manual mode: width slider + ratio radio produce expected canvas dimensions *(verified via TST-002 smoke 2026-05-04 — symmetric preset⇄manual init added)*
- [x] OffsetX / OffsetY sliders shift dots in real time *(verified via TST-002 smoke 2026-05-04 — fine-tune sliders collapsed under toggle)*
- [x] Take / Release toggle filters dots *(verified via TST-002 smoke 2026-05-04)*

## Implementation notes (DONE 2026-05-03)
- Created `src/calibration/aspectRatios.ts` with `STANDARD_ASPECT_RATIOS` (16:9, 16:10, 4:3) + `aspectRatioHeight(width, key)` helper. HeatmapView's manual-mode helper now delegates to this (was 16:9-only fallback in FRT-003).
- Single emit `update:calibration` with whole CalibrationData (immutable spread per change). Considered separate `update:offsetX/Y/resolution` events per architecture but rejected — App.vue would just splat them back into one calibration object anyway. One emit = one mutation, less boilerplate, identical behaviour.
- Preset list = monitor-extracted resolutions (regex `/(\d+)x(\d+)/` over `monitorInfo.distinctValues`) ∪ curated `[1280x720, 1920x1080, 2560x1440, 3840x2160]`, deduped + sorted.
- Mode switch (preset ↔ manual) carries a sensible default for the new shape (preset → first option / `1920x1080`; manual → 16:9 @ 1920).
- Slider ranges: width 800-3840 step 10; offsetX/Y -300..+300 step 1. `<output>` shows live value next to each slider.
- Used `k-textbox` class on `<select>`. Native `<input type="range">`/`<input type="radio">`/`<input type="checkbox">` per architecture's "no Kendo widgets where CSS-only suffices".
- Debouncing of slider drag is FRT-005's concern (localStorage write rate).
- Strict TS clean: `yarn type-check` 0 errors.
