---
id: FRT-007
title: Heatmap overlay on selected screenshot
slice: VS3
status: done
depends-on: [FRT-006, FRT-003]
effort: S
---

## Scope
When `activeScreenshotId` non-null, replace Layer 0 of `HeatmapView` (currently `strokeRect` from FRT-003) with the screenshot drawn via `ctx.drawImage(img, 0, 0, canvas.w, canvas.h)` — JPEG (server-downscaled to 800×H) **upscaled** to the calibrated window size. Canvas size does NOT change. Click overlays unchanged. See [architecture → Physical Model](../architecture.md#physical-model-coordinate-spaces).

## Files
- Modify: `src/components/HeatmapView.vue` — load `<img>` for active screenshot, swap Layer 0 background

## Implementation notes
- `<img>` load is async. Use `new Image()` + `await new Promise(res => { img.onload = res; img.src = url })` inside `watchEffect`.
- Cross-origin: `/Player/GetScreen` on same admin host → no CORS complications.
- **Canvas size stays = calibrated window resolution** (do NOT resize canvas to screenshot's 800×H natural size — that breaks click 1:1 rendering and uiGeometry rect math).
- `drawImage(img, 0, 0, canvas.w, canvas.h)` performs uniform AR-preserving upscale **only when** calibrated AR matches screenshot AR. AR mismatch produces visible stretch/squash — this is a deliberate calibration-feedback signal (moderator sees AR-misfit and corrects in CalibrationPanel).
- Re-render order each frame: drawImage background → KEEP/RELEASE rects → click points. `requestAnimationFrame` not needed — events drive it.

## Exit criteria
- [x] Pick a thumbnail → screenshot renders as background, upscaled to canvas size; click dots remain in calibrated positions *(verified via TST-002 smoke 2026-05-04)*
- [x] AR-mismatch demonstration *(verified via TST-002 smoke 2026-05-04 — manual calibration adjustment showed visible stretch; calibration feedback signal works as architecture predicted)*
- [x] Pick another thumbnail → image swaps; existing dots stable *(verified via TST-002 smoke 2026-05-04 — `onCleanup` cancels in-flight loads so stable)*
- [x] Deselect → returns to hatched placeholder *(verified via TST-002 smoke 2026-05-04 — second click on same thumbnail unselects)*

## Implementation notes (DONE 2026-05-03)
- `activeImage: ref<HTMLImageElement | null>` — `watch(() => props.activeScreenshot, …)` async-loads via `new Image()` + `img.onload` callback; `onCleanup` cancels in-flight load if user picks another thumbnail before previous resolved (avoids stale-overwrite race).
- `{ immediate: true }` so initial mount with pre-set `activeScreenshot` (from persisted calibration) hydrates without extra round-trip.
- drawHeatmap branches on `activeImage.value`: image set → `ctx.drawImage(0, 0, w, h)` + `ctx.fillRect(0, 0, w, h)` with `rgba(0,0,0,0.45)` overlay (uniform upscale; AR-stretch is intentional calibration-feedback signal per architecture; semi-transparent overlay mirrors heatmap_gen.py SVG `filter:brightness(0.55)` — keeps click overlays readable over bright lake/sky photos). Initial impl used `ctx.filter = 'brightness(0.55)'`, but the user couldn't see the dimming — overlay rect is more portable (no `ctx.filter` browser-quirks, no leaked-state risk).
- `img.onerror` logs a warning and resets activeImage — fall back to hatched placeholder rather than broken-state silence.
- Strict TS clean: yarn type-check 0 errors. Build: 25 modules, main.js 77.28 KB.
