#!/usr/bin/env python3
"""Parse Mongo Tournament-log dumps into per-player trajectory cards."""
import os
import re
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", newline="\n")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", newline="\n")
from datetime import datetime
from collections import defaultdict, OrderedDict

DIR = r"D:\kb\fishing-planet\tasks\FP-43631--rating-drop-abuse-detection\artifacts\pcr-log-trajectories-2026-06-21"

# Player -> platform map (canonical case-preserving names)
STEAM = ["FurryCurrentMaster", "TF_B4ngwal", "Kacumi", "Dokidepp", "Ramboo051",
         "Audrey_HH", "poink", "OZBULLDOG", "VovaTemniy"]
PS = ["A-J-Rimmer-BSC", "jorja09", "rabolio41100", "Matiamo_PL", "Flo-GrayFOX",
      "bostonbroncos24", "maminapokorny83", "nowa_zajawka", "Neterrall", "ST-9257",
      "Fat_tuna_mama", "TR-dennisfb", "Tight_LinesJoe65", "TheFastestDevil",
      "strullendorfer"]
XBOX = ["LEBOOGIEEEE", "BuzzingLemur417"]

PLATFORM = {}
for n in STEAM: PLATFORM[n.lower().replace("_", "-")] = ("Steam", n)
for n in PS:    PLATFORM[n.lower().replace("_", "-")] = ("PS", n)
for n in XBOX:  PLATFORM[n.lower().replace("_", "-")] = ("Xbox", n)


# Regexes
RE_PCR = re.compile(
    r"Tournament reward Competition #(\d+) '(.*)' added CompetitionRating (-?\d+) \((-?\d+) -> (-?\d+)\)"
)
RE_STARTED = re.compile(r"Player started scoring time for Competition #(\d+)")
RE_REG = re.compile(r"Player registered for Competition #(\d+)")
RE_REG_FAIL = re.compile(r"Registration for tournament Competition #(\d+) .* failed", re.IGNORECASE)
RE_CHEAT = re.compile(r"^CHEAT:\s*(.+)$")


def parse_line(raw):
    """Parse one raw line. Returns (ts, msg) or None."""
    s = raw.rstrip("\r\n")
    if not s or s == "line":
        return None
    # Must start and end with double quote
    if len(s) < 2 or s[0] != '"' or s[-1] != '"':
        return None
    inner = s[1:-1]
    # Unescape "" -> "
    inner = inner.replace('""', '"')
    # Split on FIRST literal tab
    tab = inner.find("\t")
    if tab < 0:
        return None
    ts = inner[:tab]
    msg = inner[tab+1:]
    return ts, msg


def parse_ts(ts):
    return datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ")


def process_file(path):
    """Returns dict of derived data for one player file."""
    pcr_entries = []   # list of dicts: ts, ts_dt, comp_id, comp_name, delta, before, after
    started_set = set()    # comp_ids
    regs = 0
    fails = 0
    cheats = []   # list of (ts, body)

    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for raw in f:
            parsed = parse_line(raw)
            if not parsed:
                continue
            ts, msg = parsed

            m = RE_PCR.search(msg)
            if m:
                comp_id, name, delta, before, after = m.groups()
                pcr_entries.append({
                    "ts": ts,
                    "ts_dt": parse_ts(ts),
                    "comp_id": comp_id,
                    "name": name,
                    "delta": int(delta),
                    "before": int(before),
                    "after": int(after),
                })
                continue

            m = RE_STARTED.search(msg)
            if m:
                started_set.add(m.group(1))
                continue

            if RE_REG.search(msg):
                regs += 1
                continue
            if RE_REG_FAIL.search(msg):
                fails += 1
                continue

            m = RE_CHEAT.match(msg)
            if m:
                cheats.append((ts, m.group(1)))
                continue

    # Sort PCR entries by timestamp ascending; for equal timestamps preserve insertion order
    pcr_entries.sort(key=lambda e: e["ts_dt"])

    # Mark status: PLAYED if comp_id ever appears in started_set; else NO-SHOW
    for e in pcr_entries:
        e["status"] = "PLAYED" if e["comp_id"] in started_set else "NO-SHOW"

    return {
        "pcr": pcr_entries,
        "started": started_set,
        "regs": regs,
        "fails": fails,
        "cheats": cheats,
    }


def compute_patterns(pcr):
    """Compute derived analytics."""
    if not pcr:
        return {
            "pcr_range": "",
            "pcr_at_start": None,
            "pcr_at_end": None,
            "net_delta": 0,
            "batched_flush_groups": 0,
            "longest_no_show_streak_hours": 0.0,
            "middles_to_noobs_drops": 0,
            "batched_groups_detail": [],
            "longest_streak_detail": None,
            "middles_drops_detail": [],
            "climb_then_flush_detail": [],
        }

    befores = [e["before"] for e in pcr]
    afters = [e["after"] for e in pcr]
    pcr_min = min(min(befores), min(afters))
    pcr_max = max(max(befores), max(afters))

    pcr_at_start = pcr[0]["before"]
    pcr_at_end = pcr[-1]["after"]
    net_delta = pcr_at_end - pcr_at_start

    # Batched flush groups: entries sharing exact same second; >=2 with at least one NO-SHOW
    groups = defaultdict(list)
    for e in pcr:
        groups[e["ts"]].append(e)
    batched_groups = []
    for ts, items in groups.items():
        if len(items) >= 2 and any(x["status"] == "NO-SHOW" for x in items):
            batched_groups.append((ts, items))
    batched_groups.sort(key=lambda g: g[0])

    # Longest no-show streak: >=5 consecutive NO-SHOW
    longest_hours = 0.0
    longest_detail = None
    i = 0
    while i < len(pcr):
        if pcr[i]["status"] == "NO-SHOW":
            j = i
            while j+1 < len(pcr) and pcr[j+1]["status"] == "NO-SHOW":
                j += 1
            # streak [i..j] (NO-SHOW)
            run_len = j - i + 1
            if run_len >= 5:
                span = (pcr[j]["ts_dt"] - pcr[i]["ts_dt"]).total_seconds() / 3600.0
                if span > longest_hours:
                    longest_hours = span
                    longest_detail = (pcr[i]["ts"], pcr[j]["ts"], run_len, span,
                                      pcr[i]["before"], pcr[j]["after"])
            i = j + 1
        else:
            i += 1

    # MIDDLES drops: NO-SHOW with before >= 100 and after < 100
    middles_drops = []
    for e in pcr:
        if e["status"] == "NO-SHOW" and e["before"] >= 100 and e["after"] < 100:
            middles_drops.append(e)

    # Climb-then-flush: PLAYED pushing PCR into >=100, followed within <4h by NO-SHOW dropping below 100
    climb_then_flush = []
    for idx, e in enumerate(pcr):
        if e["status"] == "PLAYED" and e["after"] >= 100 and e["before"] < 100:
            # find next NO-SHOW within 4 hours that drops below 100
            for k in range(idx+1, len(pcr)):
                gap_h = (pcr[k]["ts_dt"] - e["ts_dt"]).total_seconds() / 3600.0
                if gap_h >= 4:
                    break
                if pcr[k]["status"] == "NO-SHOW" and pcr[k]["after"] < 100:
                    climb_then_flush.append((e, pcr[k], gap_h))
                    break

    return {
        "pcr_range": f"{pcr_min} .. {pcr_max}",
        "pcr_at_start": pcr_at_start,
        "pcr_at_end": pcr_at_end,
        "net_delta": net_delta,
        "batched_flush_groups": len(batched_groups),
        "longest_no_show_streak_hours": round(longest_hours, 2),
        "middles_to_noobs_drops": len(middles_drops),
        "batched_groups_detail": batched_groups,
        "longest_streak_detail": longest_detail,
        "middles_drops_detail": middles_drops,
        "climb_then_flush_detail": climb_then_flush,
    }


def build_notable(patterns, cheats):
    """Build small notable list (0-8 items)."""
    items = []
    # Batched flush groups: top few by collapse size
    bg = patterns["batched_groups_detail"]
    bg_sorted = sorted(bg, key=lambda g: -len(g[1]))
    for ts, grp in bg_sorted[:3]:
        first_before = grp[0]["before"]
        last_after = grp[-1]["after"]
        no_show_count = sum(1 for e in grp if e["status"] == "NO-SHOW")
        items.append(f"{ts} batched flush: {len(grp)} entries same second ({no_show_count} NO-SHOW), PCR {first_before}->{last_after}")

    # Longest streak >=6h
    ls = patterns["longest_streak_detail"]
    if ls and ls[3] >= 6.0:
        items.append(f"{ls[0]}..{ls[1]} NO-SHOW streak: {ls[2]} entries over {ls[3]:.1f}h, PCR {ls[4]}->{ls[5]}")

    # MIDDLES drops: top 3 by delta magnitude
    md = patterns["middles_drops_detail"]
    md_sorted = sorted(md, key=lambda e: e["delta"])  # most negative first
    for e in md_sorted[:3]:
        items.append(f"{e['ts']} NO-SHOW MIDDLES->NOOBS: PCR {e['before']}->{e['after']} (#{e['comp_id']} '{e['name']}')")

    # Climb-then-flush
    cf = patterns["climb_then_flush_detail"]
    for played, noshow, gap_h in cf[:3]:
        items.append(f"{played['ts']} PLAYED->{played['after']}, then {noshow['ts']} NO-SHOW->{noshow['after']} ({gap_h:.1f}h later)")

    # Cheats: count + a representative
    if cheats:
        # group by code
        codes = defaultdict(int)
        for ts, body in cheats:
            m = re.match(r"\((\d+)\)\s*(.+?)(?:\s+Actual:|$)", body)
            if m:
                codes[(m.group(1), m.group(2).strip())] += 1
            else:
                codes[("?", body[:50])] += 1
        top = sorted(codes.items(), key=lambda x: -x[1])[:2]
        kinds = "; ".join(f"({c[0]}) {c[1]} x{n}" for c, n in top)
        items.append(f"{len(cheats)} CHEAT triggers across window — top: {kinds}")

    return items[:8]


def render_card(canonical, platform, uuid, totals, patterns, notable, pcr):
    """Render markdown."""
    lines = []
    lines.append("---")
    lines.append(f"username: {canonical}")
    lines.append(f"platform: {platform}")
    lines.append(f"userId: {uuid}")
    lines.append("window: 2026-06-01 -> 2026-06-21")
    lines.append("totals:")
    lines.append(f"  competitions_with_pcr_entry: {totals['competitions_with_pcr_entry']}")
    lines.append(f"  played: {totals['played']}")
    lines.append(f"  no_show: {totals['no_show']}")
    lines.append(f"  registrations_logged: {totals['regs']}")
    lines.append(f"  failed_registrations: {totals['fails']}")
    lines.append("patterns:")
    lines.append(f"  pcr_range: \"{patterns['pcr_range']}\"")
    lines.append(f"  pcr_at_start: {patterns['pcr_at_start'] if patterns['pcr_at_start'] is not None else ''}")
    lines.append(f"  pcr_at_end: {patterns['pcr_at_end'] if patterns['pcr_at_end'] is not None else ''}")
    lines.append(f"  net_delta: {patterns['net_delta']}")
    lines.append(f"  batched_flush_groups: {patterns['batched_flush_groups']}")
    lines.append(f"  longest_no_show_streak_hours: {patterns['longest_no_show_streak_hours']}")
    lines.append(f"  middles_to_noobs_drops: {patterns['middles_to_noobs_drops']}")
    lines.append(f"  cheat_triggers: {totals['cheats']}")
    lines.append("notable:")
    if not notable:
        # keep YAML valid: empty list
        lines[-1] = "notable: []"
    else:
        for s in notable:
            # escape double quotes
            s_esc = s.replace('"', '\\"')
            lines.append(f"  - \"{s_esc}\"")
    lines.append("---")
    lines.append("")
    lines.append(f"# {canonical} -- PCR-log trajectory (3 weeks)")
    lines.append("")
    lines.append("## PCR ledger (chronological, all entries)")
    lines.append("")
    lines.append("| Timestamp           | Comp ID  | Comp name                  | Status   | Δ    | PCR    |")
    lines.append("|---------------------|----------|----------------------------|----------|------|--------|")
    for e in pcr:
        delta_s = f"+{e['delta']}" if e['delta'] >= 0 else f"{e['delta']}"
        pcr_col = f"{e['before']}→{e['after']}"
        # truncate names to reasonable width
        name = e['name'] if len(e['name']) <= 28 else e['name'][:25] + "..."
        lines.append(f"| {e['ts']} | #{e['comp_id']} | {name} | {e['status']} | {delta_s} | {pcr_col} |")
    lines.append("")
    return "\n".join(lines)


def main():
    summary = []
    for fn in sorted(os.listdir(DIR)):
        if not fn.endswith(".tsv"):
            continue
        path = os.path.join(DIR, fn)
        base = fn[:-4]
        # Filename: <uuid>-<slug>.tsv  (uuid is 36 chars)
        uuid = base[:36]
        slug = base[37:]
        if slug not in PLATFORM:
            print(f"UNKNOWN SLUG: {slug}", file=sys.stderr)
            sys.exit(2)
        platform, canonical = PLATFORM[slug]

        data = process_file(path)
        pcr = data["pcr"]
        comp_ids = {e["comp_id"] for e in pcr}
        played = sum(1 for cid in comp_ids if cid in data["started"])
        no_show = len(comp_ids) - played

        # But: count per entry, not per comp (a player may have multiple entries for same comp?)
        # Use entry-level counts to be safe (each ledger entry counted)
        played_entries = sum(1 for e in pcr if e["status"] == "PLAYED")
        no_show_entries = sum(1 for e in pcr if e["status"] == "NO-SHOW")

        totals = {
            "competitions_with_pcr_entry": len(comp_ids),
            "played": played_entries,
            "no_show": no_show_entries,
            "regs": data["regs"],
            "fails": data["fails"],
            "cheats": len(data["cheats"]),
        }
        patterns = compute_patterns(pcr)
        notable = build_notable(patterns, data["cheats"])

        card = render_card(canonical, platform, uuid, totals, patterns, notable, pcr)
        out_path = os.path.join(DIR, base + ".md")
        with open(out_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(card)
            if not card.endswith("\n"):
                f.write("\n")

        # Hottest signal heuristic for summary table
        signals = []
        bf = patterns["batched_flush_groups"]
        md = patterns["middles_to_noobs_drops"]
        ls_h = patterns["longest_no_show_streak_hours"]
        cf = len(patterns["climb_then_flush_detail"])
        cheats_n = totals["cheats"]
        if bf >= 1:
            signals.append((f"{bf} batched-flush groups (same-second PCR collapses)", 100 + bf))
        if md >= 1:
            signals.append((f"{md} MIDDLES->NOOBS no-show drops", 50 + md))
        if cf >= 1:
            signals.append((f"{cf} climb-then-flush events (<4h)", 40 + cf))
        if ls_h >= 24:
            signals.append((f"NO-SHOW streak {ls_h:.0f}h", 30))
        if cheats_n >= 1:
            signals.append((f"{cheats_n} CHEAT triggers", 20 + min(cheats_n, 10)))
        ns_share = (no_show_entries / max(1, played_entries + no_show_entries))
        if ns_share >= 0.6:
            signals.append((f"{int(ns_share*100)}% no-show rate", 10))
        signals.sort(key=lambda x: -x[1])
        hottest = signals[0][0] if signals else "low-signal trajectory"

        summary.append({
            "username": canonical,
            "platform": platform,
            "played": played_entries,
            "no_show": no_show_entries,
            "batched": bf,
            "streak_h": ls_h,
            "middles": md,
            "pcr_start": patterns["pcr_at_start"],
            "pcr_end": patterns["pcr_at_end"],
            "net": patterns["net_delta"],
            "hottest": hottest,
            "_ns_share": ns_share,
        })

    # Sort summary by: batched desc, middles desc, no_show_share desc
    summary.sort(key=lambda r: (-r["batched"], -r["middles"], -r["_ns_share"]))

    # Print summary table
    print("| Username | Platform | Played | No-show | Batched flushes | Longest streak (h) | MIDDLES drops | PCR start->end | Net Δ | Hottest signal |")
    print("|----------|----------|--------|---------|-----------------|--------------------|---------------|----------------|-------|----------------|")
    for r in summary:
        pcr_se = f"{r['pcr_start']}->{r['pcr_end']}" if r['pcr_start'] is not None else "n/a"
        net = f"{r['net']:+d}" if r['pcr_start'] is not None else "0"
        print(f"| {r['username']} | {r['platform']} | {r['played']} | {r['no_show']} | {r['batched']} | {r['streak_h']:.1f} | {r['middles']} | {pcr_se} | {net} | {r['hottest']} |")


if __name__ == "__main__":
    main()
