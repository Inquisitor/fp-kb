---
id: FRT-003
title: HeatmapView canvas — points mode, fixed resolution
slice: VS2
status: done
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
- [x] LureKing sample renders a dense dot in KEEP-rect area; honest sample shows scattered dots *(verified via TST-002 smoke 2026-05-04 — LureKing red hot-cluster on KEEP rect confirmed)*
- [x] Canvas redraws on `events` ref change — `watchEffect` reads all reactive props (events, calibration, displayMode, showTake/Release)
- [x] No off-by-one at corners — clicks drawn with simple `arc(x, h - y, ...)` math; rects use `+ 0.5` for crisp 1px strokes
- [x] Resolution change re-renders — `watchEffect` re-fires on `calibration.resolution` mutation; canvas intrinsic size updated; UI rects rescaled via Expand math

## Implementation notes (DONE 2026-05-03)
- `resolutionToSize` inline helper in HeatmapView (preset = parse `'WxH'`, manual = width + 16:9 fallback). Will be replaced by `aspectRatios.ts` lookup in FRT-004.
- Render order Layer 0 → Layer 1 → Layer 2 per architecture. Layer 0 is bbox stroke for now; FRT-007 swaps in `ctx.drawImage(activeScreenshot)`.
- Visual style **adopted from `heatmap_gen.py`** (per smoke feedback): dark canvas (#0d0d0d), fine pixel grid with axis labels (`#444 stroke 0.5` lines + `#666 9px Consolas` labels), orange center-cross (`#ff8c00`), dashed UI rects with opacity 0.55 (KEEP=`#ff8c00`, RELEASE=`#7fb3d5`, panel=`#999`), dashed frame border. **Take = filled cyan-blue circle (`hsl(200,80%,55%)`) with thin white stroke**, **Release = no fill + dashed red ring (`#ff5252`, `setLineDash([2,2])`)** — visually distinct kinds without colour-blindness ambiguity. Density mode acknowledged in template but not implemented (Phase 4).
- **Hatched placeholder background** when `activeScreenshot == null` (added per smoke feedback, not in original architecture): subtle 45° diagonal lines (`#1c1c1c` on `#0d0d0d`) cover the entire canvas at 18px-pixelScale step. Reads as «no screenshot here, by design» — empty bbox alone left moderators wondering if rendering broke. FRT-007 will skip this draw when activeScreenshot is set (`ctx.drawImage` takes its place).
- Grid step picker mirrors heatmap_gen.py: `floor(span / 10 / base) * base` with min cap (X: base 80, min 100/160 below/above 800; Y: base 45, min 60/90 below/above 450). Round numbers on labels regardless of resolution.
- Canvas intrinsic size = window resolution (1920×1080 default). CSS `max-width: 100%` shrinks for moderator visibility per architecture's three-coordinate-spaces model.
- App.vue: passes new `calibration` prop to HeatmapView (was missing from FRT-001 wiring).
- Strict TS clean: `yarn type-check` 0 errors.
