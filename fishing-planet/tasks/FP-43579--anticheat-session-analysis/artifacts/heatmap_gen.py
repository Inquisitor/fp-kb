#!/usr/bin/env python3
"""TakeClick / ReleaseClick heatmap generator.

Scans a directory for *.htm log files, extracts pixel coordinates of
TakeClick / ReleaseClick events (telemetry written by the Unity client at
CatchedFishInfoHandler.TakeClick / .ReleaseClick), and renders heatmap.html
with one panel per player.

Usage:
    python heatmap_gen.py [<log_dir>]

Background images (per-player only):
    Drop <player_name>.<png|jpg|jpeg|webp> next to the log file. The image
    is overlaid behind the click points (prefix match also works, e.g.
    "Jangalor.jpg" attaches to "JangalorFP.htm").

Window resolution detection (drives coordinate viewBox):
    1) WINDOW_OVERRIDES (manual hint per player, highest priority)
    2) Auto: weighted centroid of densest cluster x 2 -> snap to nearest
       standard resolution. Triggers only if the cluster holds >= 30% of clicks.
    3) Fallback: virtual 4K (3840x2160).

Verdict heuristic:
    cheat   - >= RED_RATIO of TakeClicks fall inside a (2*r+1)x(2*r+1) px window
    suspect - >= YELLOW_RATIO concentrated in that window
    lowdata - fewer than LOW_DATA_THRESHOLD clicks (cannot judge)
    ok      - dispersed enough to look human
"""
import math, os, re, html, sys, argparse
from pathlib import Path
from collections import defaultdict

# ---- thresholds ---------------------------------------------------------
LOW_DATA_THRESHOLD       = 10    # below this many take-clicks: insufficient sample
CLUSTER_RADIUS_PX        = 1     # 3x3 px window for cheat verdict
RED_RATIO                = 0.50  # >= this share inside cluster -> "cheat"
YELLOW_RATIO             = 0.20  # >= this share inside cluster -> "suspect"
WINDOW_DETECT_RADIUS_PX  = 20    # loose radius for window-center detection
WINDOW_DETECT_MIN_RATIO  = 0.30  # cluster share required to trust the centroid

# ---- per-player manual overrides for window resolution ------------------
# Use when auto-detection cannot work (e.g. cursor parked in a corner)
# or to enforce honest player's known monitor resolution.
WINDOW_OVERRIDES = {
    "JangalorFP": (3840, 2160),  # honest, native 4K
    # LUYA168: removed - now resolved via detect_window_from_buttons()
}

# ---- standard windowed-mode resolutions for snap-matching ---------------
STANDARD_WINDOWS = [
    # 4:3
    (640, 480, "4:3"), (800, 600, "4:3"), (1024, 768, "4:3"),
    (1280, 960, "4:3"), (1600, 1200, "4:3"), (2048, 1536, "4:3"),
    # 16:9
    (1280, 720, "16:9"), (1366, 768, "16:9"), (1600, 900, "16:9"),
    (1920, 1080, "16:9"), (2560, 1440, "16:9"), (3840, 2160, "16:9"),
    # 16:10
    (1280, 800, "16:10"), (1440, 900, "16:10"),
    (1680, 1050, "16:10"), (1920, 1200, "16:10"),
    # 5:4 / 21:9
    (1280, 1024, "5:4"),
    (2560, 1080, "21:9"), (3440, 1440, "21:9"),
]

# ---- catch panel UI geometry --------------------------------------------
# Canvas reference + match-width scaling, derived empirically from:
#   - Jangalor 4K screenshot (KEEP at 4K = (1960..2459, Y_unity=192..300))
#   - W_CHUANQI 1600x1200 screenshot (KEEP at = (822..1022, Y_unity=82..124))
# Both fit canvas (1920x1080) coords below at scale = window_w / 1920 for both axes.
CANVAS_REF_W, CANVAS_REF_H = 1920, 1080
# All in canvas coords, Y from bottom (Unity convention)
UI_KEEP    = {"center": (1105, 123), "size": (250, 56)}
UI_RELEASE = {"center": (815, 123),  "size": (250, 56)}
UI_PANEL   = {"center": (960, 213),  "size": (700, 385)}

# ---- rendering ----------------------------------------------------------
PANEL_TARGET_W = 800
IMG_EXTS = (".png", ".jpg", ".jpeg", ".webp")
EVENT_RE = re.compile(r"(TakeClick|ReleaseClick): ([0-9.]+); ([0-9.]+)")


def parse_log(path):
    take, release = defaultdict(int), defaultdict(int)
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            for m in EVENT_RE.finditer(line):
                kind, x, y = m.group(1), float(m.group(2)), float(m.group(3))
                target = take if kind == "TakeClick" else release
                target[(x, y)] += 1
    return take, release


def cluster_density(points, radius=CLUSTER_RADIUS_PX):
    if not points:
        return 0
    items = list(points.items())
    best = 0
    for (x1, y1), _ in items:
        s = sum(c for (x2, y2), c in items
                if abs(x2 - x1) <= radius and abs(y2 - y1) <= radius)
        if s > best:
            best = s
    return best


def cluster_centroid(points, radius):
    """Weighted centroid of the densest neighborhood plus its share of total."""
    if not points:
        return None
    items = list(points.items())
    best_pt, best_sum = None, 0
    for (x1, y1), _ in items:
        s = sum(c for (x2, y2), c in items
                if abs(x2 - x1) <= radius and abs(y2 - y1) <= radius)
        if s > best_sum:
            best_sum = s; best_pt = (x1, y1)
    if best_pt is None:
        return None
    cx_num = cy_num = 0; cw = 0
    for (x2, y2), c in items:
        if abs(x2 - best_pt[0]) <= radius and abs(y2 - best_pt[1]) <= radius:
            cx_num += x2 * c; cy_num += y2 * c; cw += c
    total = sum(points.values())
    return (cx_num / cw, cy_num / cw, cw, total)


def verdict(take):
    total = sum(take.values())
    if total < LOW_DATA_THRESHOLD:
        return "lowdata", f"insufficient sample ({total} clicks)"
    density = cluster_density(take, CLUSTER_RADIUS_PX)
    ratio = density / total
    box = (CLUSTER_RADIUS_PX * 2) + 1
    if ratio >= RED_RATIO:
        return "cheat", f"cheat: {density}/{total} clicks in {box}x{box} px ({ratio*100:.0f}%)"
    if ratio >= YELLOW_RATIO:
        return "suspect", f"suspect: {density}/{total} clicks in {box}x{box} px ({ratio*100:.0f}%)"
    return "ok", f"dispersed: top {box}x{box} cluster = {ratio*100:.0f}%"


def snap_window(w, h):
    best, best_d = None, float('inf')
    for sw, sh, ratio in STANDARD_WINDOWS:
        d = abs(sw - w) + abs(sh - h)
        if d < best_d:
            best_d = d; best = (sw, sh, ratio, d)
    return best


def detect_window_from_buttons(take, release):
    """Bot that aims at button centers: TakeClick and ReleaseClick share Y.
    If catch panel is screen-centered, window width = take_X + release_X.
    Returns (centroid_take, centroid_release, derived_w) or None.
    """
    if not take or not release:
        return None
    take_c  = cluster_centroid(take,    WINDOW_DETECT_RADIUS_PX)
    release_c = cluster_centroid(release, WINDOW_DETECT_RADIUS_PX)
    if take_c is None or release_c is None:
        return None
    tx, ty, ts, tt = take_c
    rx, ry, rs, rt = release_c
    if ts / tt < WINDOW_DETECT_MIN_RATIO or rs / rt < WINDOW_DETECT_MIN_RATIO:
        return None
    if abs(ty - ry) > 5:                 # not on same row -> not button centers
        return None
    if abs(tx - rx) < 30:                # too close -> same parked cursor, not buttons
        return None
    if tx <= rx:                         # KEEP must be right of RELEASE
        return None
    return (tx, ty), (rx, ry), tx + rx


def detect_window(name, take, release):
    if name in WINDOW_OVERRIDES:
        w, h = WINDOW_OVERRIDES[name]
        snap = snap_window(w, h)
        return (w, h), f"manual override -> {w}x{h} ({snap[2]})"
    # Method 1: button-center symmetry (bot clicks on the actual buttons)
    btn = detect_window_from_buttons(take, release)
    if btn is not None:
        (tx, ty), (rx, ry), w_raw = btn
        # height: assume button row Y is canvas_Y * (H / ref_H) with ref_H=1080
        # we can't fully solve without another anchor; pick H to match common standards
        # heuristic: search aspect ratios that fit the X estimate to a standard window
        candidates = []
        for sw, sh, ratio in STANDARD_WINDOWS:
            d_w = abs(sw - w_raw) / sw
            if d_w < 0.10:               # within 10% of derived width
                candidates.append((d_w, sw, sh, ratio))
        if candidates:
            candidates.sort()
            _, sw, sh, ratio = candidates[0]
            note = (f"buttons: take=({tx:.0f},{ty:.0f}) release=({rx:.0f},{ry:.0f}) "
                    f"-> width~{w_raw:.0f} -> {sw}x{sh} ({ratio})")
            return (sw, sh), note
        # No standard match -> use derived width with assumed 16:9
        sh = int(round(w_raw * 9 / 16))
        note = (f"buttons: take=({tx:.0f},{ty:.0f}) release=({rx:.0f},{ry:.0f}) "
                f"-> width~{w_raw:.0f} (no standard match, assuming 16:9 -> {int(w_raw)}x{sh})")
        return (int(w_raw), sh), note
    # Method 2: hot-spot = window center (cursor parked at center)
    if not take:
        return None, "no clicks"
    centroid = cluster_centroid(take, WINDOW_DETECT_RADIUS_PX)
    if centroid is None:
        return None, "no cluster"
    cx, cy, cluster_sum, total = centroid
    if cluster_sum / total < WINDOW_DETECT_MIN_RATIO:
        return None, f"weak cluster ({cluster_sum}/{total})"
    w_raw, h_raw = 2 * cx, 2 * cy
    sw, sh, ratio, d = snap_window(w_raw, h_raw)
    note = (f"center: hot=({cx:.1f},{cy:.1f}) -> window~{w_raw:.0f}x{h_raw:.0f} "
            f"-> {sw}x{sh} ({ratio}, off={d}px)")
    return (sw, sh), note


def color_for(count, ln_max):
    t = math.log(count) / ln_max if count > 0 and ln_max > 0 else 0
    return f"hsl({240 - 240*t:.0f},85%,55%)"


def radius_for(count):
    return 2.5 + math.sqrt(count) * 1.3


def render_svg(take, release, ln_max, window, bg_path):
    ww, wh = window
    panel_w = PANEL_TARGET_W
    panel_h = int(round(panel_w * wh / ww))
    sx = panel_w / ww
    sy = panel_h / wh

    parts = [f'<svg width="{panel_w}" height="{panel_h}" xmlns="http://www.w3.org/2000/svg">']
    if bg_path:
        parts.append(
            f'<image href="{html.escape(bg_path)}" x="0" y="0" '
            f'width="{panel_w}" height="{panel_h}" preserveAspectRatio="none" '
            f'style="filter:brightness(0.55)"/>'
        )
    parts.append(f'<rect class="frame" x="0" y="0" width="{panel_w}" height="{panel_h}"/>')
    # Catch panel UI overlay (canvas coords scaled by ww/1920, match-width mode)
    ui_scale = ww / CANVAS_REF_W
    for ui, css_cls in [(UI_PANEL, "ui-panel"), (UI_RELEASE, "ui-release"), (UI_KEEP, "ui-keep")]:
        cx_w = ui["center"][0] * ui_scale
        cy_w = ui["center"][1] * ui_scale  # Unity Y (from bottom)
        rw   = ui["size"][0]   * ui_scale
        rh   = ui["size"][1]   * ui_scale
        rect_left   = (cx_w - rw/2) * sx
        rect_top    = panel_h - (cy_w + rh/2) * sy   # SVG y from top
        rect_w_svg  = rw * sx
        rect_h_svg  = rh * sy
        parts.append(f'<rect class="{css_cls}" x="{rect_left:.2f}" y="{rect_top:.2f}" '
                     f'width="{rect_w_svg:.2f}" height="{rect_h_svg:.2f}"/>')
    # Axes (in window pixel space)
    step_x = max(160, ww // 10 // 80 * 80) if ww > 800 else 100
    step_y = max(90, wh // 10 // 45 * 45) if wh > 450 else 60
    x = 0
    while x <= ww:
        parts.append(f'<line class="axis" x1="{x*sx:.2f}" y1="0" x2="{x*sx:.2f}" y2="{panel_h}"/>')
        parts.append(f'<text class="axis-text" x="{x*sx+2:.2f}" y="{panel_h-2}">{x}</text>')
        x += step_x
    y = 0
    while y <= wh:
        yy = panel_h - y * sy
        parts.append(f'<line class="axis" x1="0" y1="{yy:.2f}" x2="{panel_w}" y2="{yy:.2f}"/>')
        parts.append(f'<text class="axis-text" x="2" y="{yy-2:.2f}">{y}</text>')
        y += step_y
    # Center marker
    cx0 = (ww / 2) * sx
    cy0 = panel_h - (wh / 2) * sy
    parts.append(f'<line class="center" x1="{cx0-8:.2f}" y1="{cy0:.2f}" x2="{cx0+8:.2f}" y2="{cy0:.2f}"/>')
    parts.append(f'<line class="center" x1="{cx0:.2f}" y1="{cy0-8:.2f}" x2="{cx0:.2f}" y2="{cy0+8:.2f}"/>')
    # Clicks (small first)
    for (px, py), c in sorted(take.items(), key=lambda kv: kv[1]):
        cx = px * sx; cy = panel_h - py * sy
        parts.append(
            f'<circle class="take" cx="{cx:.2f}" cy="{cy:.2f}" r="{radius_for(c):.2f}" '
            f'fill="{color_for(c, ln_max)}" fill-opacity="0.75">'
            f'<title>TakeClick ({px:.0f}, {py:.0f}) - {c}x</title></circle>'
        )
    for (px, py), c in release.items():
        cx = px * sx; cy = panel_h - py * sy
        parts.append(
            f'<circle class="release" cx="{cx:.2f}" cy="{cy:.2f}" r="{radius_for(c)+1:.2f}">'
            f'<title>ReleaseClick ({px:.0f}, {py:.0f}) - {c}x</title></circle>'
        )
    parts.append('</svg>')
    return "".join(parts), panel_w, panel_h


HTML_HEAD = """<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><title>TakeClick / ReleaseClick heatmap</title>
<style>
  body { background:#1a1a1a; color:#ddd; font-family: Consolas, monospace; margin:0; padding:24px; }
  h1 { font-size:18px; margin:0 0 16px 0; }
  .legend { display:flex; gap:24px; align-items:center; margin-bottom:16px; font-size:12px; flex-wrap:wrap; }
  .legend-bar { width:240px; height:14px;
    background: linear-gradient(90deg, hsl(240,85%,55%), hsl(180,85%,55%), hsl(120,85%,55%), hsl(60,85%,55%), hsl(0,85%,55%));
    border-radius:2px; }
  .legend-item { display:flex; align-items:center; gap:6px; }
  .panels { display:flex; gap:16px; flex-wrap:wrap; align-items:flex-start; }
  .panel { background:#252525; padding:12px; border-radius:6px; border:1px solid #333; }
  .panel-title { font-size:14px; margin-bottom:6px; font-weight:bold; }
  .cls-honest, .cls-ok    { color:#7fdb7f; }
  .cls-cheat              { color:#ff5252; }
  .cls-suspect            { color:#ffb347; }
  .cls-lowdata            { color:#888; }
  .panel-stats { font-size:11px; color:#888; margin-bottom:8px; line-height:1.5; }
  .panel-stats .win { color:#aaa; }
  svg { display:block; background:#0d0d0d; border:1px solid #333; }
  circle.take { stroke:#fff; stroke-width:0.4; }
  circle.release { fill:none; stroke:#ff5252; stroke-width:1.5; stroke-dasharray:2,2; }
  .axis { stroke:#444; stroke-width:0.5; }
  .axis-text { fill:#666; font-size:9px; font-family: Consolas, monospace; }
  .frame { fill:none; stroke:#3a3a3a; stroke-width:1; stroke-dasharray:3,3; }
  .center { stroke:#ff8c00; stroke-width:1; }
  .ui-panel   { fill:none; stroke:#999;    stroke-width:1; stroke-dasharray:5,3; opacity:0.55; }
  .ui-keep    { fill:none; stroke:#ff8c00; stroke-width:1; stroke-dasharray:5,3; opacity:0.55; }
  .ui-release { fill:none; stroke:#7fb3d5; stroke-width:1; stroke-dasharray:5,3; opacity:0.55; }
</style></head><body>
<h1>TakeClick / ReleaseClick - pixel coordinates from <code>Mouse.current.position.ReadValue()</code></h1>
"""


def find_personal_bg(log_dir, name):
    # Exact filename match only. Convention: <player_name>.<png|jpg|jpeg|webp>
    # next to the log file. No prefix fuzz — that produced false positives
    # when one player's name is a prefix of another's (e.g. Jangalor / JangalorFP).
    for ext in IMG_EXTS:
        p = log_dir / f"{name}{ext}"
        if p.is_file():
            return p
    return None


def main():
    ap = argparse.ArgumentParser(description="TakeClick heatmap generator")
    ap.add_argument("log_dir", nargs="?", default=None)
    args = ap.parse_args()

    log_dir = Path(args.log_dir) if args.log_dir else Path(__file__).resolve().parent
    if not log_dir.is_dir():
        print(f"not a directory: {log_dir}", file=sys.stderr); sys.exit(1)

    files = sorted(log_dir.glob("*.htm"))
    if not files:
        print(f"no *.htm files in {log_dir}"); return

    sessions = []
    for f in files:
        take, release = parse_log(f)
        if not take and not release:
            continue
        cls, v_text = verdict(take)
        window, wnote = detect_window(f.stem, take, release)
        if window is None:
            window = (3840, 2160)
            wnote = (wnote or "no detection") + " -> fallback 4K"
        bg = find_personal_bg(log_dir, f.stem)
        bg_rel = None
        if bg:
            try:
                bg_rel = os.path.relpath(bg, log_dir).replace("\\", "/")
            except ValueError:
                bg_rel = bg.as_uri()
        sessions.append({
            "name": f.stem, "take": take, "release": release,
            "cls": cls, "verdict": v_text, "window": window,
            "wnote": wnote, "bg": bg_rel
        })

    if not sessions:
        print("no events parsed in any file"); return

    all_counts = [c for s in sessions for c in s["take"].values()] + \
                 [c for s in sessions for c in s["release"].values()]
    max_count = max(all_counts) if all_counts else 1
    ln_max = math.log(max_count) if max_count > 1 else 1

    order = {"ok": 0, "lowdata": 1, "suspect": 2, "cheat": 3}
    sessions.sort(key=lambda s: (order.get(s["cls"], 99), s["name"]))

    panels = []
    for s in sessions:
        total_t = sum(s["take"].values())
        total_r = sum(s["release"].values())
        uniq_t  = len(s["take"])
        uniq_r  = len(s["release"])
        pct_t   = f"{uniq_t/total_t*100:.2f}%" if total_t else "-"
        all_pts = list(s["take"].keys()) + list(s["release"].keys())
        if all_pts:
            xs = [p[0] for p in all_pts]; ys = [p[1] for p in all_pts]
            bbox = f"X&isin;[{min(xs):.0f}..{max(xs):.0f}] Y&isin;[{min(ys):.0f}..{max(ys):.0f}]"
        else:
            bbox = "-"
        ww, wh = s["window"]
        stats = (f"take={total_t}, unique={uniq_t} ({pct_t}) &middot; "
                 f"release={total_r}, unique={uniq_r}<br>"
                 f"bbox {bbox}<br>"
                 f'<span class="win">window: {ww}x{wh} - {html.escape(s["wnote"])}</span>')
        svg, pw, ph = render_svg(s["take"], s["release"], ln_max, s["window"], s["bg"])
        panels.append(
            f'<div class="panel">'
            f'<div class="panel-title cls-{s["cls"]}">{html.escape(s["name"])} &mdash; '
            f'{html.escape(s["verdict"])}</div>'
            f'<div class="panel-stats">{stats}</div>'
            f'{svg}'
            f'</div>'
        )

    legend = (
        f'<div class="legend">'
        f'  <div class="legend-item"><span>count (log-scale):</span> 1<div class="legend-bar"></div>{max_count}</div>'
        f'  <div class="legend-item"><svg width="14" height="14"><circle cx="7" cy="7" r="5" fill="hsl(200,80%,55%)" stroke="#fff" stroke-width="0.4"/></svg> TakeClick</div>'
        f'  <div class="legend-item"><svg width="14" height="14"><circle cx="7" cy="7" r="5" fill="none" stroke="#ff5252" stroke-width="1.5" stroke-dasharray="2,2"/></svg> ReleaseClick</div>'
        f'  <div class="legend-item"><svg width="14" height="14"><line x1="3" y1="7" x2="11" y2="7" stroke="#ff8c00"/><line x1="7" y1="3" x2="7" y2="11" stroke="#ff8c00"/></svg> window center</div>'
        f'  <div class="legend-item"><svg width="20" height="14"><rect x="2" y="3" width="16" height="8" fill="none" stroke="#ff8c00" stroke-width="1" stroke-dasharray="5,3"/></svg> KEEP button</div>'
        f'  <div class="legend-item"><svg width="20" height="14"><rect x="2" y="3" width="16" height="8" fill="none" stroke="#7fb3d5" stroke-width="1" stroke-dasharray="5,3"/></svg> RELEASE button</div>'
        f'  <div class="legend-item"><svg width="20" height="14"><rect x="2" y="3" width="16" height="8" fill="none" stroke="#999" stroke-width="1" stroke-dasharray="5,3"/></svg> catch panel</div>'
        f'  <div class="legend-item">UI rects: canvas (1920x1080 ref) &times; window_w/1920 (match-width). Y flipped.</div>'
        f'</div>'
    )

    doc = HTML_HEAD + legend + '<div class="panels">' + "".join(panels) + '</div></body></html>'
    out_path = log_dir / "heatmap.html"
    out_path.write_text(doc, encoding="utf-8")

    print(f"wrote {out_path}\n")
    print(f"{'name':14s}  {'verdict':8s}  {'take':>5s}  {'uniq':>5s}  {'window':>11s}  note")
    print("-" * 100)
    for s in sessions:
        total = sum(s["take"].values())
        uniq  = len(s["take"])
        ww, wh = s["window"]
        print(f"{s['name']:14s}  {s['cls']:8s}  {total:5d}  {uniq:5d}  {ww:5d}x{wh:<5d}  {s['wnote']}")


if __name__ == "__main__":
    main()
