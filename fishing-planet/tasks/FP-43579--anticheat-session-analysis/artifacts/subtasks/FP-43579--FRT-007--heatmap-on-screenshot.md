---
id: FRT-007
title: Heatmap overlay on selected screenshot
slice: VS3
status: todo
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
- [ ] Pick a thumbnail → screenshot renders as background, upscaled to canvas size; click dots remain in calibrated positions
- [ ] AR-mismatch demonstration: deliberately set wrong calibration AR → screenshot visibly stretches/squashes, KEEP/RELEASE rects misalign with the in-image buttons (proves the visual feedback loop)
- [ ] Pick another thumbnail → image swaps; existing dots stable
- [ ] Deselect (back to bounding-box-only) → behaves identically to FRT-003 baseline
