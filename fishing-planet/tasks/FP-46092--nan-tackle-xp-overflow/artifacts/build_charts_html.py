"""Builds fight-charts.html: a self-contained interactive page (no external libraries) with the
player's fish fights before/after the first Denuvo detection.

Inputs (same folder): fishfact-hooked.csv, fishingsessionscatch.csv, fishinglog-fights.tsv.
Run: python build_charts_html.py   ->  fight-charts.html
"""
import csv
import io
import json
import os
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
SPLIT_ISO = "2026-09-03T00:00:00Z"


def read(name, delimiter=","):
    with io.open(os.path.join(HERE, name), encoding="utf-8") as f:
        return list(csv.DictReader(f, delimiter=delimiter))


def fnum(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def pdt(v):
    v = (v or "").strip()
    for fmt in ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S.%fZ", "%Y-%m-%dT%H:%M:%SZ"):
        try:
            return datetime.strptime(v, fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    return None


def iso(d):
    return d.strftime("%Y-%m-%dT%H:%M:%SZ")


# species names from the fishingLog window (FishFact only has ids)
species = {}
fl_rows = []
for r in read("fishinglog-fights.tsv", delimiter="\t"):
    if r.get("fishId") and r.get("species"):
        species[r["fishId"]] = r["species"]
    if r["end"] != "caught":
        continue
    t = pdt(r["t0"])
    if t is None:
        continue
    fl_rows.append({
        "t": iso(t), "species": r["species"], "kg": fnum(r["kg"]), "sec": fnum(r["sec"]),
        "stamina": fnum(r["stamina"]), "dist": fnum(r["dist"]) if r["dist"] != "NaN" else None,
        "exp": fnum(r["exp"]), "rodLen": fnum(r["rodLen"]), "tire": fnum(r["tireWarn"]),
    })

# fish force / tackle load from FishingSessionsCatch, keyed by fish id + fight seconds
fsc = {}
for r in read("fishingsessionscatch.csv"):
    sec = fnum(r["FightSec"])
    if sec is None:
        continue
    fsc["%s|%.3f" % (r["FishId"], sec)] = (fnum(r["FishForce"]), fnum(r["MinMaxLoad"]), r["IsBoarded"] == "1")

fish = []
for r in read("fishfact-hooked.csv"):
    if not r["CaughtAt"]:
        continue
    w, sec, dist = fnum(r["Weight"]), fnum(r["FightSec"]), fnum(r["HookedDistance"])
    t = pdt(r["HookedAt"])
    if t is None and r["CaughtAt"] and sec:
        # the hooked update never landed (NaN hooked distance); place the fight by its end
        t = datetime.fromtimestamp(pdt(r["CaughtAt"]).timestamp() - sec, tz=timezone.utc)
    if t is None or w is None or sec is None or sec <= 0:
        continue
    force, load, boarded = fsc.get("%s|%.3f" % (r["FishId"], sec), (None, None, None))
    fish.append({
        "t": iso(t), "kg": w, "sec": sec, "dist": dist, "fishId": r["FishId"],
        "species": species.get(r["FishId"], "fish #" + r["FishId"]),
        "reel": (dist / sec) if dist else None, "spk": sec / w if w > 0 else None,
        "force": force, "load": load, "ratio": (force / load) if (force and load) else None,
        "exp": fnum(r["Exp"]), "rodId": r["RodId"], "reelId": r["ReelId"], "pond": r["PondId"],
        "boat": r["BoatType"] not in ("", "0"), "slot": r["Slot"],
    })

fish.sort(key=lambda x: x["t"])
data = {"split": SPLIT_ISO, "fish": fish, "fl": fl_rows}

PAGE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>snxth fish fights</title>
<style>
:root{color-scheme:light;
 --page:#f9f9f7;--surface:#fcfcfb;--ink:#0b0b0b;--ink2:#52514e;--muted:#898781;--grid:#e1e0d9;--axis:#c3c2b7;--border:rgba(11,11,11,.10);
 --s1:#2a78d6;--s2:#eb6834;--split:#898781}
@media (prefers-color-scheme: dark){:root:where(:not([data-theme="light"])){color-scheme:dark;
 --page:#0d0d0d;--surface:#1a1a19;--ink:#ffffff;--ink2:#c3c2b7;--muted:#898781;--grid:#2c2c2a;--axis:#383835;--border:rgba(255,255,255,.10);
 --s1:#3987e5;--s2:#d95926;--split:#898781}}
:root[data-theme="dark"]{color-scheme:dark;
 --page:#0d0d0d;--surface:#1a1a19;--ink:#ffffff;--ink2:#c3c2b7;--muted:#898781;--grid:#2c2c2a;--axis:#383835;--border:rgba(255,255,255,.10);
 --s1:#3987e5;--s2:#d95926;--split:#898781}
*{box-sizing:border-box}
body{margin:0;background:var(--page);color:var(--ink);font:14px/1.45 system-ui,-apple-system,"Segoe UI",sans-serif}
header{padding:20px 24px 8px}
h1{font-size:20px;font-weight:600;margin:0 0 4px}
.sub{color:var(--ink2);margin:0}
.filters{display:flex;flex-wrap:wrap;gap:16px;align-items:center;padding:12px 24px;border-top:1px solid var(--border);border-bottom:1px solid var(--border);background:var(--surface)}
.filters label{display:flex;align-items:center;gap:6px;color:var(--ink2)}
.filters input[type=date],.filters select{font:inherit;color:var(--ink);background:var(--surface);border:1px solid var(--axis);border-radius:6px;padding:4px 8px}
.chip{display:inline-flex;align-items:center;gap:8px;padding:4px 10px;border:1px solid var(--axis);border-radius:999px;cursor:pointer;user-select:none;color:var(--ink)}
.chip.off{opacity:.45}
.key{width:14px;height:14px;border-radius:50%;display:inline-block}
.key.s1{background:var(--s1)}.key.s2{background:var(--s2)}
.spacer{flex:1}
button{font:inherit;color:var(--ink);background:var(--surface);border:1px solid var(--axis);border-radius:6px;padding:5px 10px;cursor:pointer}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px;padding:16px 24px 0}
.tile{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:12px 14px}
.tile .l{color:var(--ink2);font-size:12px}
.tile .v{font-size:26px;font-weight:600;margin-top:2px}
.tile .d{color:var(--ink2);font-size:12px;margin-top:2px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(520px,1fr));gap:16px;padding:16px 24px 24px}
.card{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:14px 14px 8px;min-width:0}
.card h2{font-size:15px;font-weight:600;margin:0 0 2px}
.card p{margin:0 0 6px;color:var(--ink2);font-size:12px}
.legend{display:flex;gap:16px;margin:4px 0 2px;font-size:12px;color:var(--ink2)}
.legend span{display:inline-flex;align-items:center;gap:6px}
svg{width:100%;height:auto;display:block;overflow:visible}
.gl{stroke:var(--grid);stroke-width:1}
.ax{stroke:var(--axis);stroke-width:1}
.tick{fill:var(--muted);font-size:11px;font-variant-numeric:tabular-nums}
.alabel{fill:var(--ink2);font-size:12px}
.pt{stroke:var(--surface);stroke-width:2;cursor:pointer}
.pt.s1{fill:var(--s1)}.pt.s2{fill:var(--s2)}
.pt.hi{stroke:var(--ink);stroke-width:2}
.split{stroke:var(--split);stroke-width:1}
.splitl{fill:var(--ink2);font-size:11px}
.ref{stroke:var(--muted);stroke-width:1}
.dlabel{fill:var(--ink2);font-size:11px}
.bar{fill:var(--s1)}
#tip{position:fixed;pointer-events:none;background:var(--surface);color:var(--ink);border:1px solid var(--border);border-radius:8px;padding:8px 10px;font-size:12px;box-shadow:0 4px 16px rgba(0,0,0,.18);display:none;max-width:280px;z-index:9}
#tip .v{font-weight:600;font-size:14px}
#tip .k{display:inline-block;width:12px;height:3px;vertical-align:middle;margin-right:6px;border-radius:2px}
#tip .k.s1{background:var(--s1)}#tip .k.s2{background:var(--s2)}
#tip div{margin:1px 0}
table{border-collapse:collapse;width:100%;font-size:12px}
th,td{text-align:left;padding:4px 8px;border-bottom:1px solid var(--grid);white-space:nowrap}
td.n,th.n{text-align:right;font-variant-numeric:tabular-nums}
.tablewrap{padding:0 24px 24px;overflow-x:auto;display:none}
.tablewrap.on{display:block}
</style>
</head>
<body>
<header>
 <h1>Fish fights of player snxth</h1>
 <p class="sub">Caught fish from Stats <code>FishFact</code> (7 Aug – 6 Sep 2026, UTC) joined with <code>FishingSessionsCatch</code>; stamina from the 14-day Mongo <code>fishingLog</code>. Split at 2026-09-03, the first Denuvo <code>NoFishFight.dll</code> detection.</p>
</header>
<div class="filters">
 <label>From <input type="date" id="from"></label>
 <label>To <input type="date" id="to"></label>
 <label>Min weight <select id="minw"><option value="0">any</option><option value="10">10 kg</option><option value="50">50 kg</option><option value="100">100 kg</option></select></label>
 <span class="chip" id="chip1"><i class="key s1"></i>before 2026-09-03</span>
 <span class="chip" id="chip2"><i class="key s2"></i>from 2026-09-03</span>
 <span class="spacer"></span>
 <button id="tbl">Table view</button>
 <button id="theme">Theme</button>
</div>
<div class="stats" id="stats"></div>
<div class="grid" id="charts"></div>
<div class="tablewrap" id="tablewrap"></div>
<div id="tip"></div>
<script id="data" type="application/json">__DATA__</script>
<script>
(function(){
const D = JSON.parse(document.getElementById('data').textContent);
const SPLIT = Date.parse(D.split);
D.fish.forEach(f => { f.ts = Date.parse(f.t); f.after = f.ts >= SPLIT; });
D.fl.forEach(f => { f.ts = Date.parse(f.t); f.after = f.ts >= SPLIT; });
const state = { s1: true, s2: true, minw: 0, from: null, to: null };
const $ = id => document.getElementById(id);
const tip = $('tip');

// ---------- filters ----------
const allTs = D.fish.map(f => f.ts);
const dmin = new Date(Math.min(...allTs)), dmax = new Date(Math.max(...allTs));
const dstr = d => d.toISOString().slice(0, 10);
$('from').value = dstr(dmin); $('to').value = dstr(dmax);
$('from').onchange = e => { state.from = e.target.value ? Date.parse(e.target.value + 'T00:00:00Z') : null; render(); };
$('to').onchange = e => { state.to = e.target.value ? Date.parse(e.target.value + 'T23:59:59Z') : null; render(); };
$('minw').onchange = e => { state.minw = +e.target.value; render(); };
$('chip1').onclick = () => { state.s1 = !state.s1; $('chip1').classList.toggle('off', !state.s1); render(); };
$('chip2').onclick = () => { state.s2 = !state.s2; $('chip2').classList.toggle('off', !state.s2); render(); };
$('theme').onclick = () => { const r = document.documentElement; const dark = r.dataset.theme === 'dark' || (!r.dataset.theme && matchMedia('(prefers-color-scheme: dark)').matches); r.dataset.theme = dark ? 'light' : 'dark'; };
$('tbl').onclick = () => { $('tablewrap').classList.toggle('on'); };
function keep(f) {
  if (f.after ? !state.s2 : !state.s1) return false;
  if (f.kg != null && f.kg < state.minw) return false;
  if (state.from && f.ts < state.from) return false;
  if (state.to && f.ts > state.to) return false;
  return true;
}

// ---------- helpers ----------
const fmt = (v, d) => v == null ? '–' : (+v).toLocaleString('en-US', { maximumFractionDigits: d == null ? 1 : d, minimumFractionDigits: 0 });
const ts2 = ts => new Date(ts).toISOString().replace('T', ' ').slice(0, 19) + ' UTC';
function q(vals, p) { const a = vals.filter(v => v != null).sort((x, y) => x - y); if (!a.length) return null; const k = (a.length - 1) * p, lo = Math.floor(k), hi = Math.min(lo + 1, a.length - 1); return a[lo] + (a[hi] - a[lo]) * (k - lo); }
const NS = 'http://www.w3.org/2000/svg';
function el(tag, attrs, parent) { const e = document.createElementNS(NS, tag); for (const k in attrs) e.setAttribute(k, attrs[k]); if (parent) parent.appendChild(e); return e; }
function txt(e, s) { e.textContent = s; return e; }
function logTicks(lo, hi) { const t = []; for (let e = Math.floor(Math.log10(lo)); e <= Math.ceil(Math.log10(hi)); e++) { const b = Math.pow(10, e); [1, 2, 5].forEach(m => { const v = b * m; if (v >= lo && v <= hi) t.push(v); }); } return t; }
function linTicks(lo, hi, n) { const span = hi - lo, raw = span / n, mag = Math.pow(10, Math.floor(Math.log10(raw))), step = [1, 2, 5, 10].map(m => m * mag).find(s => span / s <= n) || mag; const t = []; for (let v = Math.ceil(lo / step) * step; v <= hi + 1e-9; v += step) t.push(+v.toFixed(6)); return t; }
function dayTicks(lo, hi) { const t = []; const d = new Date(lo); d.setUTCHours(0, 0, 0, 0); for (; d.getTime() <= hi; d.setUTCDate(d.getUTCDate() + 1)) t.push(d.getTime()); return t; }
function ceilNice(v) { const e = Math.floor(Math.log10(v)); for (const m of [1, 2, 5, 10]) { const c = m * Math.pow(10, e); if (c >= v) return c; } return Math.pow(10, e + 1); }
function floorNice(v) { const e = Math.floor(Math.log10(v)); for (const m of [5, 2, 1]) { const c = m * Math.pow(10, e); if (c <= v) return c; } return Math.pow(10, e); }
const qp = new URLSearchParams(location.search).get('theme'); if (qp) document.documentElement.dataset.theme = qp;

// generic scatter with nearest-point hover
function scatter(host, opt) {
  const W = 640, H = opt.height || 330, m = { l: 56, r: 16, t: 26, b: 40 };
  const pts = opt.points.filter(p => p.x != null && p.y != null && (!opt.xlog || p.x > 0) && (!opt.ylog || p.y > 0));
  const card = document.createElement('div'); card.className = 'card'; host.appendChild(card);
  const h2 = document.createElement('h2'); h2.textContent = opt.title; card.appendChild(h2);
  const p = document.createElement('p'); p.textContent = opt.subtitle || ''; card.appendChild(p);
  const lg = document.createElement('div'); lg.className = 'legend';
  [['s1', 'before 2026-09-03'], ['s2', 'from 2026-09-03']].forEach(([c, l]) => { const s = document.createElement('span'); const k = document.createElement('i'); k.className = 'key ' + c; s.appendChild(k); s.appendChild(document.createTextNode(l)); lg.appendChild(s); });
  card.appendChild(lg);
  const svg = el('svg', { viewBox: `0 0 ${W} ${H}`, role: 'img', 'aria-label': opt.title }, card);
  if (!pts.length) { txt(el('text', { x: W / 2, y: H / 2, class: 'alabel', 'text-anchor': 'middle' }, svg), 'no points in the current filter'); return; }
  const xs = pts.map(p => p.x), ys = pts.map(p => p.y);
  let x0 = opt.xmin != null ? opt.xmin : Math.min(...xs), x1 = opt.xmax != null ? opt.xmax : Math.max(...xs);
  let y0 = opt.ymin != null ? opt.ymin : Math.min(...ys), y1 = opt.ymax != null ? opt.ymax : Math.max(...ys);
  if (opt.ylog) { y0 = floorNice(y0); y1 = ceilNice(y1 * 1.05); }
  if (opt.xlog) { x0 = floorNice(x0); x1 = ceilNice(x1 * 1.05); }
  if (opt.xtime) { x0 -= 12 * 3600e3; x1 += 12 * 3600e3; }
  const sx = v => m.l + (opt.xlog ? (Math.log10(v) - Math.log10(x0)) / (Math.log10(x1) - Math.log10(x0)) : (v - x0) / (x1 - x0)) * (W - m.l - m.r);
  const sy = v => H - m.b - (opt.ylog ? (Math.log10(v) - Math.log10(y0)) / (Math.log10(y1) - Math.log10(y0)) : (v - y0) / (y1 - y0)) * (H - m.t - m.b);
  const yt = opt.ylog ? logTicks(y0, y1) : linTicks(y0, y1, opt.yticks || 5);
  yt.forEach(v => { el('line', { x1: m.l, x2: W - m.r, y1: sy(v), y2: sy(v), class: 'gl' }, svg); txt(el('text', { x: m.l - 8, y: sy(v) + 4, class: 'tick', 'text-anchor': 'end' }, svg), fmt(v, 2)); });
  const xt = opt.xtime ? dayTicks(x0, x1) : (opt.xlog ? logTicks(x0, x1) : linTicks(x0, x1, 6));
  xt.forEach((v, i) => { el('line', { x1: sx(v), x2: sx(v), y1: m.t, y2: H - m.b, class: 'gl' }, svg); if (!opt.xtime || i % Math.ceil(xt.length / 10) === 0) txt(el('text', { x: sx(v), y: H - m.b + 16, class: 'tick', 'text-anchor': 'middle' }, svg), opt.xtime ? new Date(v).toISOString().slice(5, 10) : fmt(v, 2)); });
  el('line', { x1: m.l, x2: W - m.r, y1: H - m.b, y2: H - m.b, class: 'ax' }, svg);
  el('line', { x1: m.l, x2: m.l, y1: m.t, y2: H - m.b, class: 'ax' }, svg);
  txt(el('text', { x: W - m.r, y: H - 4, class: 'alabel', 'text-anchor': 'end' }, svg), opt.xlabel);
  txt(el('text', { x: m.l - 46, y: 12, class: 'alabel' }, svg), opt.ylabel);
  if (opt.xtime && SPLIT > x0 && SPLIT < x1) { el('line', { x1: sx(SPLIT), x2: sx(SPLIT), y1: m.t, y2: H - m.b, class: 'split' }, svg); txt(el('text', { x: sx(SPLIT) - 5, y: m.t - 6, class: 'splitl', 'text-anchor': 'end' }, svg), 'first Denuvo detection'); }
  (opt.refs || []).forEach(r => { if (r.y > y0 && r.y < y1) { el('line', { x1: m.l, x2: W - m.r, y1: sy(r.y), y2: sy(r.y), class: 'ref' }, svg); txt(el('text', { x: m.l + 6, y: sy(r.y) - 5, class: 'dlabel' }, svg), r.label); } });
  const g = el('g', {}, svg);
  const nodes = pts.map(p => { const c = el('circle', { cx: sx(p.x), cy: sy(p.y), r: 4, class: 'pt ' + (p.after ? 's2' : 's1'), tabindex: 0 }, g); c.__p = p; return c; });
  (opt.labels || []).forEach(l => { const p = pts.find(l.match); if (p) { const right = sx(p.x) > (W - m.r) * 0.72; txt(el('text', { x: sx(p.x) + (right ? -9 : 9), y: sy(p.y) - 9, class: 'dlabel', 'text-anchor': right ? 'end' : 'start' }, svg), l.text); el('line', { x1: sx(p.x), x2: sx(p.x), y1: sy(p.y) - 6, y2: sy(p.y) - 12, class: 'ref' }, svg); } });
  let hi = null;
  function show(c, ev) { if (hi) hi.classList.remove('hi'); hi = c; c.classList.add('hi'); tip.replaceChildren(...opt.tooltip(c.__p)); tip.style.display = 'block'; const r = c.getBoundingClientRect(); const x = (ev && ev.clientX) || r.left + 6, y = (ev && ev.clientY) || r.top; tip.style.left = Math.min(x + 14, innerWidth - 300) + 'px'; tip.style.top = Math.max(8, y - 12) + 'px'; }
  function hide() { if (hi) hi.classList.remove('hi'); hi = null; tip.style.display = 'none'; }
  svg.addEventListener('pointermove', ev => { const r = svg.getBoundingClientRect(); const k = W / r.width; const px = (ev.clientX - r.left) * k, py = (ev.clientY - r.top) * k; let best = null, bd = 24 * k; nodes.forEach(c => { const dx = +c.getAttribute('cx') - px, dy = +c.getAttribute('cy') - py; const d = Math.hypot(dx, dy); if (d < bd) { bd = d; best = c; } }); if (best) show(best, ev); else hide(); });
  svg.addEventListener('pointerleave', hide);
  nodes.forEach(c => { c.addEventListener('focus', () => show(c)); c.addEventListener('blur', hide); });
}
function bars(host, opt) {
  const W = 640, H = 250, m = { l: 56, r: 16, t: 26, b: 40 };
  const card = document.createElement('div'); card.className = 'card'; host.appendChild(card);
  const h2 = document.createElement('h2'); h2.textContent = opt.title; card.appendChild(h2);
  const p = document.createElement('p'); p.textContent = opt.subtitle || ''; card.appendChild(p);
  const svg = el('svg', { viewBox: `0 0 ${W} ${H}`, role: 'img', 'aria-label': opt.title }, card);
  const rows = opt.rows; if (!rows.length) { txt(el('text', { x: W / 2, y: H / 2, class: 'alabel', 'text-anchor': 'middle' }, svg), 'no days in the current filter'); return; }
  const y1 = Math.max(...rows.map(r => r.v)) || 1; const yt = linTicks(0, y1, 4); const yTop = yt[yt.length - 1] < y1 ? y1 : yt[yt.length - 1];
  const sy = v => H - m.b - v / yTop * (H - m.t - m.b);
  yt.forEach(v => { el('line', { x1: m.l, x2: W - m.r, y1: sy(v), y2: sy(v), class: 'gl' }, svg); txt(el('text', { x: m.l - 8, y: sy(v) + 4, class: 'tick', 'text-anchor': 'end' }, svg), fmt(v, 2)); });
  el('line', { x1: m.l, x2: W - m.r, y1: H - m.b, y2: H - m.b, class: 'ax' }, svg);
  const band = (W - m.l - m.r) / rows.length, bw = Math.min(24, band - 2);
  rows.forEach((r, i) => {
    const x = m.l + band * i + (band - bw) / 2, y = sy(r.v), h = H - m.b - y;
    const rect = el('path', { d: `M${x},${H - m.b} v${-(h - Math.min(4, h))} q0,-${Math.min(4, h)} ${Math.min(4, bw / 2)},-${Math.min(4, h)} h${bw - 2 * Math.min(4, bw / 2)} q${Math.min(4, bw / 2)},0 ${Math.min(4, bw / 2)},${Math.min(4, h)} v${h - Math.min(4, h)} z`, class: 'bar', tabindex: 0 }, svg);
    if (rows.length <= 16 || i % 2 === 0) txt(el('text', { x: x + bw / 2, y: H - m.b + 16, class: 'tick', 'text-anchor': 'middle' }, svg), r.day.slice(5));
    const showb = ev => { tip.replaceChildren(...opt.tooltip(r)); tip.style.display = 'block'; const rc = rect.getBoundingClientRect(); const cx = (ev && ev.clientX) || rc.left, cy = (ev && ev.clientY) || rc.top; tip.style.left = Math.min(cx + 14, innerWidth - 300) + 'px'; tip.style.top = Math.max(8, cy - 12) + 'px'; };
    rect.addEventListener('pointermove', showb); rect.addEventListener('pointerleave', () => tip.style.display = 'none'); rect.addEventListener('focus', showb); rect.addEventListener('blur', () => tip.style.display = 'none');
  });
  const sd = rows.findIndex(r => Date.parse(r.day + 'T00:00:00Z') >= SPLIT);
  if (sd > 0) { const x = m.l + band * sd; el('line', { x1: x, x2: x, y1: m.t, y2: H - m.b, class: 'split' }, svg); txt(el('text', { x: x - 5, y: m.t - 6, class: 'splitl', 'text-anchor': 'end' }, svg), 'first Denuvo detection'); }
  txt(el('text', { x: m.l - 46, y: 12, class: 'alabel' }, svg), opt.ylabel);
}
function row(label, value, cls) { const d = document.createElement('div'); if (cls) { const k = document.createElement('span'); k.className = 'k ' + cls; d.appendChild(k); } const v = document.createElement('span'); v.className = 'v'; v.textContent = value; d.appendChild(v); d.appendChild(document.createTextNode(' ' + label)); return d; }
function fishTip(f) {
  const head = document.createElement('div'); head.className = 'v'; head.textContent = f.species + ', ' + fmt(f.kg, 2) + ' kg';
  const out = [head, row('fight', fmt(f.sec, 1) + ' s', f.after ? 's2' : 's1'), row('s per kg', fmt(f.spk, 2)), row('hooked distance', fmt(f.dist, 1) + ' m'), row('implied reel speed', fmt(f.reel, 2) + ' m/s')];
  if (f.ratio != null) out.push(row('fish force / tackle load', fmt(f.ratio, 2)));
  if (f.stamina != null) out.push(row('stamina at catch', fmt(f.stamina, 3)));
  if (f.exp != null) out.push(row('XP', fmt(f.exp, 0)));
  const t = document.createElement('div'); t.textContent = ts2(f.ts) + (f.boat ? ', boat' : '') + (f.rodId ? ', rod #' + f.rodId : ''); out.push(t);
  return out;
}

// ---------- render ----------
function render() {
  const F = D.fish.filter(keep), L = D.fl.filter(keep);
  const st = $('stats'); st.replaceChildren();
  const tile = (l, v, d) => { const t = document.createElement('div'); t.className = 'tile'; const a = document.createElement('div'); a.className = 'l'; a.textContent = l; const b = document.createElement('div'); b.className = 'v'; b.textContent = v; const c = document.createElement('div'); c.className = 'd'; c.textContent = d || ''; t.append(a, b, c); st.appendChild(t); };
  const B = F.filter(f => !f.after), A = F.filter(f => f.after);
  tile('caught fish', fmt(F.length, 0), fmt(B.length, 0) + ' before, ' + fmt(A.length, 0) + ' after');
  tile('median fight, s', fmt(q(B.map(f => f.sec), .5)) + ' → ' + fmt(q(A.map(f => f.sec), .5)), 'before → after');
  tile('max implied reel speed, m/s', fmt(Math.max(0, ...B.map(f => f.reel || 0)), 1) + ' → ' + fmt(Math.max(0, ...A.map(f => f.reel || 0)), 1), 'hooked distance / fight duration');
  tile('fights < 10 s with fish > 50 kg', fmt(B.filter(f => f.sec < 10 && f.kg > 50).length, 0) + ' → ' + fmt(A.filter(f => f.sec < 10 && f.kg > 50).length, 0), 'before → after');
  const ch = $('charts'); ch.replaceChildren();
  const overflow = { match: p => p.exp != null && p.exp > 1e9, text: 'XP overflow catch' };
  scatter(ch, { title: 'Fight duration over time', subtitle: 'each dot is one caught fish; vertical hairline = first Denuvo detection', xtime: true, ylog: true, xlabel: 'date (UTC)', ylabel: 'seconds, log', points: F.map(f => ({ x: f.ts, y: f.sec, after: f.after, ...f })), tooltip: fishTip, labels: [overflow] });
  scatter(ch, { title: 'Implied reel speed over time', subtitle: 'hooked distance divided by fight duration; the reel cannot exceed a few m/s', xtime: true, ylog: true, xlabel: 'date (UTC)', ylabel: 'm/s, log', points: F.map(f => ({ x: f.ts, y: f.reel, after: f.after, ...f })), tooltip: fishTip, refs: [{ y: 5, label: '5 m/s, max reel speed used by the server checks' }] });
  scatter(ch, { title: 'Fish weight vs fight duration', subtitle: 'an honest fight grows with the weight; a flat band means the fish was landed instantly', xlog: true, ylog: true, xlabel: 'kg, log', ylabel: 'seconds, log', points: F.map(f => ({ x: f.kg, y: f.sec, after: f.after, ...f })), tooltip: fishTip });
  scatter(ch, { title: 'Hooked distance vs fight duration', subtitle: 'a 300 m hookup landed in 5 s is a 60 m/s reel', xlog: true, ylog: true, xlabel: 'm, log', ylabel: 'seconds, log', points: F.map(f => ({ x: f.dist, y: f.sec, after: f.after, ...f })), tooltip: fishTip });
  scatter(ch, { title: 'Fish force / tackle max load vs fight duration', subtitle: 'FishingSessionsCatch; above 1 the fish is stronger than the tackle', xlog: true, ylog: true, xlabel: 'force / load, log', ylabel: 'seconds, log', points: F.map(f => ({ x: f.ratio, y: f.sec, after: f.after, ...f })), tooltip: fishTip, refs: [] });
  scatter(ch, { title: 'Stamina at catch vs fish weight (fishingLog, 14 days)', subtitle: 'server FishTireModel value when the fish was landed; 1.0 = not tired at all', xlog: true, xlabel: 'kg, log', ylabel: 'stamina', ymin: 0, ymax: 1, yticks: 5, points: L.map(f => ({ x: f.kg, y: f.stamina, after: f.after, ...f, reel: f.dist && f.sec ? f.dist / f.sec : null, spk: f.kg ? f.sec / f.kg : null })), tooltip: fishTip });
  const days = {}; F.forEach(f => { const d = f.t.slice(0, 10); (days[d] = days[d] || []).push(f); });
  const rows = Object.keys(days).sort().map(d => { const big = days[d].filter(f => f.kg >= 20); return { day: d, v: q(big.map(f => f.sec), .5) || 0, nbig: big.length, n: days[d].length, med: q(days[d].map(f => f.sec), .5), wmax: Math.max(...days[d].map(f => f.kg)) }; }).filter(r => r.nbig > 0);
  bars(ch, { title: 'Median fight of fish over 20 kg, by day', subtitle: 'only fish of 20 kg and more, so the day mix of small fish does not dilute it', ylabel: 'seconds', rows, tooltip: r => [Object.assign(document.createElement('div'), { className: 'v', textContent: r.day }), row('median fight of fish over 20 kg', fmt(r.v, 1) + ' s'), row('fish over 20 kg', fmt(r.nbig, 0)), row('caught fish, all', fmt(r.n, 0)), row('median fight, all', fmt(r.med, 1) + ' s'), row('heaviest fish', fmt(r.wmax, 1) + ' kg')] });
  // table view
  const tw = $('tablewrap'); tw.replaceChildren();
  const tb = document.createElement('table'); const thead = document.createElement('thead'); const tr = document.createElement('tr');
  [['hooked (UTC)', ''], ['period', ''], ['fish', ''], ['kg', 'n'], ['fight s', 'n'], ['s/kg', 'n'], ['distance m', 'n'], ['reel m/s', 'n'], ['force/load', 'n'], ['XP', 'n'], ['rod', 'n']].forEach(([h, c]) => { const th = document.createElement('th'); th.textContent = h; if (c) th.className = c; tr.appendChild(th); });
  thead.appendChild(tr); tb.appendChild(thead); const tbody = document.createElement('tbody');
  F.forEach(f => { const r = document.createElement('tr'); [[ts2(f.ts).slice(0, 19), ''], [f.after ? 'after' : 'before', ''], [f.species, ''], [fmt(f.kg, 2), 'n'], [fmt(f.sec, 1), 'n'], [fmt(f.spk, 2), 'n'], [fmt(f.dist, 1), 'n'], [fmt(f.reel, 2), 'n'], [fmt(f.ratio, 2), 'n'], [fmt(f.exp, 0), 'n'], [f.rodId, 'n']].forEach(([v, c]) => { const td = document.createElement('td'); td.textContent = v; if (c) td.className = c; r.appendChild(td); }); tbody.appendChild(r); });
  tb.appendChild(tbody); tw.appendChild(tb);
}
render();
})();
</script>
</body>
</html>
"""

html = PAGE.replace("__DATA__", json.dumps(data, separators=(",", ":")).replace("</", "<\\/"))
with io.open(os.path.join(HERE, "fight-charts.html"), "w", encoding="utf-8", newline="\n") as f:
    f.write(html)
print("fight-charts.html written: %d caught fish, %d fishingLog fights, %d bytes" % (len(fish), len(fl_rows), len(html)))
