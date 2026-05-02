# Catch panel UI geometry — calibration

## Status

**This is a stopgap, not a proper method.** The constants below were derived once empirically from screenshots; they will rot when the client UI is repositioned. The proper path is reading the catch-panel prefab in Unity Editor (see [Recommended approach](#recommended-approach)).

## Current constants (as of 2026-05, Content branch LBM20251201)

In Unity canvas reference (1920×1080), Y measured from the bottom of the screen (Unity convention):

| Element        | Center (canvas)   | Size (canvas) |
|----------------|-------------------|---------------|
| KEEP button    | `(1105, 123)`     | `250 × 56`    |
| RELEASE button | `( 815, 123)`     | `250 × 56`    |
| Catch panel    | `( 960, 213)`     | `700 × 385`   |

Scaling rule (verified): **match-width**. At any window resolution `(W, H)`, scale all positions and sizes by `W / 1920` for both X and Y.

## Why this works (and why it's fragile)

Unity's `CanvasScaler` on the HUD canvas is configured in match-width mode (or equivalent), so the catch panel renders at the same *canvas* position regardless of player window size. One calibration point gives the layout for every resolution.

Verified on two screenshots at different aspect ratios:
- Jangalor — 4K (3840×2160, 16:9) — KEEP center detected at `(2210, 246)` in client coords → canvas `(1105, 123)` ✓
- W_CHUANQI — 1600×1200 (4:3 windowed) — KEEP center at `(922, 103)` → canvas `(1106, 124)` ✓

Both fit the same canvas constants under match-width. Confirms the rule.

The fragility: if the catch panel is ever moved, resized, or the canvas reference resolution is changed in Unity, **all constants invalidate silently**. The tool will draw boxes in slightly wrong places without any error.

## Empirical recalibration (the stopgap)

If the prefab path below is unavailable, the constants can be redone from a fresh honest-player screenshot at any resolution:

1. Get a 4K-or-higher screenshot from a known honest player with the catch panel open
2. Run [`heatmap_gen.py`](heatmap_gen.py)-style detection: find the largest connected component of the orange KEEP color (`R~238, G~119, B~0`)
3. Get pixel bbox in screen coords; convert Y to Unity convention (`Y_unity = screen_h - Y_top`)
4. Scale to canvas: `canvas_X = client_X × 1920 / window_w`, same for Y
5. Repeat for RELEASE (button-color is bluish dark grey, `R~50, G~69, B~75`) and the panel BG
6. Cross-verify on a screenshot at a different aspect ratio (4:3 if the first was 16:9) — both must produce the same canvas numbers

Run cost: ~30 minutes for someone who has the screenshots.

## Recommended approach

Read the layout directly from the Unity client source. The catch panel lives at `client/Assets/Resources_moved/HUD/HudDecomposition/CatchedFishInfo.prefab` (~9.9k lines of YAML with nested `PrefabInstance` overrides). The fields we need:

- The catch-panel root `RectTransform` — `m_AnchorMin`, `m_AnchorMax`, `m_AnchoredPosition`, `m_SizeDelta`, `m_Pivot`
- KEEP button (GameObject `8008045117424131238` referenced as `_takeButton`) — same fields, plus its parent chain back to the canvas
- RELEASE button (the GameObject behind `_releaseButton`) — same
- The HUD canvas — `CanvasScaler` settings (`m_UiScaleMode`, `m_ReferenceResolution`, `m_ScreenMatchMode`, `m_MatchWidthOrHeight`) — confirms our match-width assumption authoritatively

Reading the nested YAML by hand is painful (`PrefabInstance` indirection makes positions resolve through override chains). Two practical options:

- **Open in Unity Editor**, click on the prefab, read values directly from the inspector — minutes
- **Write a small parser** that walks `PrefabInstance` overrides and resolves the effective transform — afternoon of work, but reusable for other UI investigations

Either path replaces the empirical constants with values derived from the source of truth, and provides a checked recalibration step for client releases.

## When to redo calibration

- After any client release that touches HUD layout (catch panel moves, resizes, or the canvas reference resolution changes)
- If a new platform variant is introduced (mobile / console use `CatchedFishInfoMobile.prefab` — separate calibration, not covered here)
- If empirical observation shows the WebAdmin tool's overlay drifting from the actual buttons on a known honest player's screenshot
