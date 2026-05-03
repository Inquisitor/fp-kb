#!/usr/bin/env python3
"""Verify LureKing-sample clicks against the canonical runtime UI geometry.

Reads the per-player aggregated click files (e.g. _LUYA168_take.txt,
_LUYA168_release.txt — line format: "<count> TakeClick: <x>; <y>") and:

  1. Computes the cluster centers (Take, Release) by weighted centroid.
  2. Derives the window width from take_X + release_X assuming the catch
     panel is canvas-centered (heatmap_gen.detect_window_from_buttons logic).
  3. Snaps the derived width to a known standard resolution.
  4. Maps the runtime canonical button rects (1920x1080 ref, Expand scaling)
     down to the derived screen resolution.
  5. Reports what fraction of TakeClicks land inside the KEEP rect and
     what fraction of ReleaseClicks land inside the RELEASE rect.

A bot using the buttons should yield ~100% in-rect; a bot at hardcoded
coordinates that drift from button centers will show lower percentages.
"""

import re
import sys
from pathlib import Path

# Canonical runtime geometry (from Components/AntiCheatTool/src/calibration/uiGeometry.ts)
CANVAS_W, CANVAS_H = 1920, 1080
KEEP    = {"x":  980, "y":  92, "w": 250, "h": 62}   # PriorityButton (right)
RELEASE = {"x":  690, "y":  92, "w": 250, "h": 62}   # Button (left)

STANDARD_WINDOWS = [
    (1280,  720), (1366,  768), (1600,  900), (1920, 1080),
    (2560, 1440), (3840, 2160), (1280,  800), (1440,  900),
    (1680, 1050), (1920, 1200), (640,   480), (800,   600),
    (1024,  768), (1280,  960), (1600, 1200), (2048, 1536),
    (1280, 1024), (2560, 1080), (3440, 1440),
]

LINE_RE      = re.compile(r"\s*(\d+)\s+(TakeClick|ReleaseClick):\s+([0-9.]+)\s*;\s*([0-9.]+)")
RAW_EVENT_RE = re.compile(r"(TakeClick|ReleaseClick):\s+([0-9.]+)\s*;\s*([0-9.]+)")


def parse(path):
    """Aggregated `.txt` file — '<count> <kind>: <x>; <y>' per line."""
    points = []  # (x, y, count)
    for line in Path(path).read_text(encoding="utf-8", errors="ignore").splitlines():
        m = LINE_RE.match(line)
        if m:
            points.append((float(m.group(3)), float(m.group(4)), int(m.group(1))))
    return points


def parse_raw_htm(path, kind):
    """Raw `.htm` log — extract events by kind, accumulate counts per (x, y)."""
    from collections import Counter
    text = Path(path).read_text(encoding="utf-8", errors="ignore")
    counter = Counter()
    for m in RAW_EVENT_RE.finditer(text):
        if m.group(1) != kind:
            continue
        x, y = float(m.group(2)), float(m.group(3))
        counter[(x, y)] += 1
    return [(x, y, c) for (x, y), c in counter.items()]


def centroid(points):
    if not points:
        return None
    sx = sum(x * c for x, y, c in points)
    sy = sum(y * c for x, y, c in points)
    sc = sum(c     for x, y, c in points)
    return (sx / sc, sy / sc, sc)


def snap_window(w_raw, max_rel_diff=0.10):
    """Snap to nearest standard window if within max_rel_diff. Otherwise
    fall back to derived width with 16:9 aspect (heatmap_gen heuristic)."""
    best = None
    for sw, sh in STANDARD_WINDOWS:
        d = abs(sw - w_raw) / sw
        if best is None or d < best[0]:
            best = (d, sw, sh)
    if best[0] <= max_rel_diff:
        return ("snap", best[0], best[1], best[2])
    # Fallback: assume 16:9 at exactly the derived width
    sw = int(round(w_raw))
    sh = int(round(sw * 9 / 16))
    return ("derived-16:9", best[0], sw, sh)


def expand_scale(W, H):
    return min(W / CANVAS_W, H / CANVAS_H)


def check_window_center(cx, cy, top_n=5):
    """Pattern B detection: rank standard resolutions by distance from
    centroid (cx, cy) to that resolution's window-center (W/2, H/2).
    If best match is close, flag as window-center signature."""
    cands = []
    for sw, sh in STANDARD_WINDOWS:
        wcx, wcy = sw / 2, sh / 2
        d = ((cx - wcx) ** 2 + (cy - wcy) ** 2) ** 0.5
        cands.append((d, sw, sh, wcx, wcy))
    cands.sort()
    print(f"  Window-center candidates (closest first):")
    for d, sw, sh, wcx, wcy in cands[:top_n]:
        rel_w = abs(cx - wcx) / wcx if wcx else 1
        rel_h = abs(cy - wcy) / wcy if wcy else 1
        print(f"    {sw}x{sh}: center=({wcx:.0f},{wcy:.0f}), distance={d:.1f}px, relX={rel_w*100:.1f}%, relY={rel_h*100:.1f}%")
    best_d, best_sw, best_sh, _, _ = cands[0]
    PATTERN_B_THRESHOLD_PX = 50  # within 50 px of window-center counts
    if best_d <= PATTERN_B_THRESHOLD_PX:
        print(f"  >> Pattern B match: cluster centroid is within {PATTERN_B_THRESHOLD_PX}px of {best_sw}x{best_sh} window-center.")
    else:
        print(f"  >> No window-center match (best is {best_d:.0f}px > {PATTERN_B_THRESHOLD_PX}px threshold).")


def in_rect(x, y, rect, scale):
    """Check if click (x, y) at screen scale `scale` falls inside `rect`
    given in canvas coords (Y from bottom)."""
    rx0 = rect["x"]      * scale
    rx1 = (rect["x"] + rect["w"]) * scale
    ry0 = rect["y"]      * scale
    ry1 = (rect["y"] + rect["h"]) * scale
    return rx0 <= x <= rx1 and ry0 <= y <= ry1


def analyze(name, take_path, release_path):
    take_pts    = parse(take_path)
    release_pts = parse(release_path)
    _analyze_inner(name, take_pts, release_pts)


def analyze_raw(name, htm_path):
    take_pts    = parse_raw_htm(htm_path, "TakeClick")
    release_pts = parse_raw_htm(htm_path, "ReleaseClick")
    _analyze_inner(name, take_pts, release_pts)


def _analyze_inner(name, take_pts, release_pts):

    take_total    = sum(c for _, _, c in take_pts)
    release_total = sum(c for _, _, c in release_pts)

    take_c    = centroid(take_pts)
    release_c = centroid(release_pts)

    print(f"=== {name} ===")
    if take_c is None:
        print(f"  TakeClick: 0 — no data")
        print()
        return
    if release_c is None:
        # No release data — fall back to Pattern B detection (cursor parked at window center)
        tx, ty, _ = take_c
        print(f"  TakeClick: {take_total} clicks, centroid=({tx:.2f}, {ty:.2f}). No ReleaseClicks.")
        check_window_center(tx, ty)
        print()
        return
    print(f"  TakeClick:    {take_total} clicks, centroid=({take_c[0]:.2f}, {take_c[1]:.2f})")
    print(f"  ReleaseClick: {release_total} clicks, centroid=({release_c[0]:.2f}, {release_c[1]:.2f})")

    # Detect window from button-center symmetry
    w_raw = take_c[0] + release_c[0]
    snap_kind, rel_diff, sw, sh = snap_window(w_raw)
    print(f"  Inferred window (Take_x + Release_x): {w_raw:.1f} -> {sw}x{sh} ({snap_kind}, snap rel diff {rel_diff*100:.1f}%)")

    scale = expand_scale(sw, sh)
    print(f"  Expand scale at {sw}x{sh}: {scale:.4f}")

    # Compute KEEP / RELEASE screen rects
    def rect_screen(r):
        return (r["x"] * scale, r["y"] * scale,
                (r["x"] + r["w"]) * scale, (r["y"] + r["h"]) * scale)

    kx0, ky0, kx1, ky1 = rect_screen(KEEP)
    rx0, ry0, rx1, ry1 = rect_screen(RELEASE)
    print(f"  KEEP screen rect:    [{kx0:.1f}, {ky0:.1f}] - [{kx1:.1f}, {ky1:.1f}]")
    print(f"  RELEASE screen rect: [{rx0:.1f}, {ry0:.1f}] - [{rx1:.1f}, {ry1:.1f}]")

    # Count what falls inside expected rect
    take_in_keep = sum(c for x, y, c in take_pts    if in_rect(x, y, KEEP, scale))
    rel_in_rel   = sum(c for x, y, c in release_pts if in_rect(x, y, RELEASE, scale))
    take_in_rel  = sum(c for x, y, c in take_pts    if in_rect(x, y, RELEASE, scale))
    rel_in_keep  = sum(c for x, y, c in release_pts if in_rect(x, y, KEEP, scale))

    print(f"  TakeClicks in KEEP rect:    {take_in_keep}/{take_total} ({take_in_keep/take_total*100:.1f}%)")
    print(f"  ReleaseClicks in REL rect:  {rel_in_rel}/{release_total} ({rel_in_rel/release_total*100:.1f}%)")
    if take_in_rel:    print(f"  WARN: TakeClicks in RELEASE rect: {take_in_rel}")
    if rel_in_keep:    print(f"  WARN: ReleaseClicks in KEEP rect: {rel_in_keep}")
    # Always also check window-center as a second discriminative signal
    print(f"  --- Pattern B (window-center) cross-check on Take centroid ---")
    check_window_center(take_c[0], take_c[1], top_n=3)
    print()


if __name__ == "__main__":
    base = Path(sys.argv[1] if len(sys.argv) > 1 else r"D:/FishingPlanet/Temp/logs/cheaters/take-click")
    for name in ("LUYA168", "W_CHUANQI", "rrsrewr", "Niepan.LD", "DFT_KennPF", "adidan", "JangalorFP", "Jangalor"):
        t = base / f"_{name}_take.txt"
        r = base / f"_{name}_release.txt"
        h = base / f"{name}.htm"
        if t.exists() and r.exists():
            analyze(name, t, r)
        elif h.exists():
            analyze_raw(name + " (from raw .htm)", h)
