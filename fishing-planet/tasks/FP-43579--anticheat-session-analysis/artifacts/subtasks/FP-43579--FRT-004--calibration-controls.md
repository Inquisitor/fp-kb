---
id: FRT-004
title: CalibrationPanel — resolution preset, manual, offsets
slice: VS2
status: todo
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
- [ ] Preset switch visibly re-renders heatmap (Expand-mode scaling math from `uiGeometry.ts`)
- [ ] Manual mode: width slider + ratio radio produce expected canvas dimensions
- [ ] OffsetX / OffsetY sliders shift dots in real time
- [ ] Take / Release toggle filters dots
