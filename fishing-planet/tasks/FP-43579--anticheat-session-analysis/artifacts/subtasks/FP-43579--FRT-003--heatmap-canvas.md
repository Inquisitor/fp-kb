---
id: FRT-003
title: HeatmapView canvas — points mode, fixed resolution
slice: VS2
status: todo
depends-on: [BCK-002]
effort: M
---

## Scope
Render `events` list as dots on `<canvas>` inside `HeatmapView`. Canvas size = calibrated client window resolution (per [architecture → Physical Model](../architecture.md#physical-model-coordinate-spaces)). Bounding-box-only mode (no screenshot — that's FRT-007). No calibration UI yet — fixed default `1920×1080` for now (FRT-004 adds controls).

## Files
- Modify: `src/components/HeatmapView.vue` — canvas drawing, `watchEffect` redraws on `events` / calibration / `displayMode` change
- Use: `src/calibration/uiGeometry.ts` — already exists from RES-002, used here for KEEP/RELEASE rect overlay

## Implementation notes
- Canvas intrinsic size: `<canvas :width="window.W" :height="window.H">`. CSS `max-width: 100%` for display scaling.
- Coordinate convention: events come in pixel space (Y-up per `Mouse.current.position`). Canvas is Y-down → flip `y` at draw time: `drawY = canvas.h - event.y`.
- Layer 0 (background): `strokeRect(0, 0, canvas.w, canvas.h)` with `#888` 1px — bounding-box-only mode for now. FRT-007 swaps in `ctx.drawImage(...)` when screenshot active.
- Layer 1: KEEP / RELEASE / catchPanel rects derived from `uiGeometry.ts` via Expand-mode scaling for current `(W, H)` (formula: `scale = MIN(W/1920, H/1080); rect_screen = rect_canvas * scale`). Stroked outlines, label text.
- Layer 2: click points 1:1 in canvas-space (with Y-flip).
- Two `displayMode` values planned (`'points' | 'density'`); v1 lands `points` only — `density` deferred.
- Show `take` / `release` toggle (props `showTake / showRelease`); state owned by `App.vue`, mutated via FRT-004.

## Exit criteria
- [ ] LureKing sample renders a dense dot in KEEP-rect area; honest sample shows scattered dots
- [ ] Canvas redraws on `events` ref change (e.g., when filter form refreshes via BCK-004)
- [ ] No off-by-one when click at (0, 0) or (W, H)
- [ ] Resolution change (e.g. via DevTools manual swap of calibration ref) re-renders rects and dots in correct positions
