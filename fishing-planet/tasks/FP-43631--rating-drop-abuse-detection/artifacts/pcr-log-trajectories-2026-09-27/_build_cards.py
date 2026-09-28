#!/usr/bin/env python3
"""FP-43631 -- build trajectory cards from the per-platform dumps in this folder.

Inputs, all in the folder this script sits in, DATE = the sweep Sunday:
  <plat>-ledger-<DATE>.tsv    SQL spine    (participation-ledger-<DATE>.sql, TSV with header)
  <plat>-dump-<DATE>.tsv      Mongo log    (pcr-trajectory-queries-<DATE>.js, single column `line`)
  <plat>-sessions-<DATE>.tsv  GameSessions (game-sessions-<DATE>.sql, TSV with header)

Output: one <uid>-<slug>.md card per candidate found in the ledger, in the week-20 ledger layout
(Comp start | Registered | Applied | RegPCR | StartPCR | Status | Place | Delta | PCR chain | Online |
Fee | ID | Competition), plus a summary block on stdout.

Status comes from SQL (the log omits participations and cannot tell an empty start from a scored
one). The log supplies Registered (registration timestamp), Applied (reward-line timestamp) and the
PCR chain. Online = minutes of GameSessions overlap with the competition window; for a no-show it
is the measure the week-20 re-hearing used ("in the game while a competition he registered for ran
without him"). Rows the log does not carry are marked `not logged` in the chain column.

Nothing here decides anything. DO NOT REWRITE PER CYCLE -- only DATE and CHARGE_* change.
"""
import csv
import glob
import os
import re
import sys
from collections import defaultdict
from datetime import datetime

DATE = "2026-09-27"
CHARGE_START = datetime(2026, 9, 21)   # charge window by competition EndDate, [start, end)
CHARGE_END = datetime(2026, 9, 28)
HERE = os.path.dirname(os.path.abspath(__file__))

NULLS = {"", "null", "NULL", "<null>", "None"}


def parse_dt(s):
    s = s.strip().rstrip("Z")
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S.%f", "%Y-%m-%d %H:%M:%S.%f"):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            pass
    raise ValueError("bad datetime: %r" % s)


def to_int(v):
    v = (v or "").strip()
    if v in NULLS:
        return None
    return int(float(v))


def slug(name):
    s = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    return re.sub(r"-+", "-", s)


def bracket(pcr):
    if pcr is None:
        return "?"
    if pcr <= 100:
        return "N"
    if pcr <= 1000:
        return "M"
    return "T"


# ---------------------------------------------------------------- ledger (SQL spine)
ledger = defaultdict(list)
who = {}
for f in glob.glob(os.path.join(HERE, "*-ledger-%s.tsv" % DATE)):
    plat = os.path.basename(f).split("-")[0]
    with open(f, encoding="utf-8-sig", newline="") as fh:
        for row in csv.DictReader(fh, delimiter="\t"):
            uid = row["UserId"].strip().lower()
            who[uid] = (row["Username"], plat)
            ledger[uid].append(row)

# ---------------------------------------------------------------- log (Mongo dump)
REWARD = re.compile(r"Tournament reward Competition #(\d+) '(.*)' added CompetitionRating (-?\d+) \((-?\d+) -> (-?\d+)\)")
REG = re.compile(r"Player registered for Competition #(\d+)")
UNREG = re.compile(r"Player unregistered from Competition #(\d+)")
registered = defaultdict(dict)   # uid -> cid -> first registration ts
applied = defaultdict(dict)      # uid -> cid -> reward-line ts
chain = defaultdict(dict)        # uid -> cid -> (before, after, delta)
unregistered = defaultdict(list)
log_lines = 0
for f in glob.glob(os.path.join(HERE, "*-dump-%s.tsv" % DATE)):
    with open(f, encoding="utf-8-sig") as fh:
        for raw in fh:
            raw = raw.rstrip("\r\n")
            if not raw or raw == "line":
                continue
            if raw.startswith('"') and raw.endswith('"'):
                raw = raw[1:-1].replace('""', '"')
            parts = raw.split("\t", 2)
            if len(parts) < 3:
                continue
            log_lines += 1
            uid, ts, msg = parts[0].strip().lower(), parse_dt(parts[1]), parts[2]
            m = REWARD.search(msg)
            if m:
                cid = int(m.group(1))
                applied[uid][cid] = ts
                chain[uid][cid] = (int(m.group(4)), int(m.group(5)), int(m.group(3)))
                continue
            m = REG.search(msg)
            if m:
                registered[uid].setdefault(int(m.group(1)), ts)
                continue
            m = UNREG.search(msg)
            if m:
                unregistered[uid].append((int(m.group(1)), ts))

# ---------------------------------------------------------------- sessions (Stats)
sessions = defaultdict(list)
for f in glob.glob(os.path.join(HERE, "*-sessions-%s.tsv" % DATE)):
    with open(f, encoding="utf-8-sig", newline="") as fh:
        for row in csv.DictReader(fh, delimiter="\t"):
            uid = row["UserId"].strip().lower()
            st = parse_dt(row["StartedAt"])
            en_raw = row.get("EndedAt") or ""
            if en_raw.strip() in NULLS:
                en_raw = row.get("UpdatedAt") or row["StartedAt"]
            sessions[uid].append((st, parse_dt(en_raw)))


def online_minutes(uid, start, end):
    total = 0.0
    for st, en in sessions[uid]:
        lo, hi = max(st, start), min(en, end)
        if hi > lo:
            total += (hi - lo).total_seconds() / 60.0
    return total


# ---------------------------------------------------------------- cards
def fmt_dt(d):
    return d.strftime("%Y-%m-%d %H:%M") if d else "."


def fmt_short(d):
    return d.strftime("%m-%d %H:%M:%S") if d else "."


summary_lines = []
for uid, rows in sorted(ledger.items(), key=lambda kv: who[kv[0]][1] + who[kv[0]][0].lower()):
    name, plat = who[uid]
    rows.sort(key=lambda r: r["StartDate"])

    # registration batches: consecutive registrations no more than 120 s apart
    regs = sorted(registered[uid].items(), key=lambda kv: kv[1])
    batches, cur = [], []
    for cid, ts in regs:
        if cur and (ts - cur[-1][1]).total_seconds() <= 120:
            cur.append((cid, ts))
        else:
            if len(cur) >= 2:
                batches.append(cur)
            cur = [(cid, ts)]
    if len(cur) >= 2:
        batches.append(cur)

    def blank():
        return dict(reg=0, played=0, ns=0, zs=0, dq=0, prog=0, shed=0, earned=0, net=0,
                    prizes=0, pN=0, pM=0, pT=0, playN=0, playM=0, playT=0,
                    ns_online30=0, unlogged=0, drops=0)

    span, cw = blank(), blank()
    table = ["| Comp start | Registered | Applied | RegPCR | StartPCR | Status | Place | Delta | PCR chain | Online | Fee | ID | Competition |",
             "|---|---|---|---:|---:|---|---:|---:|:---:|---:|---:|---|---|"]
    streak, best_streak, best_streak_end = 0, 0, None
    entering_cw, pcr_min, pcr_max = None, None, None
    first_cw_row_seen = False
    for r in rows:
        cid = int(r["TournamentId"])
        st, en = parse_dt(r["StartDate"]), parse_dt(r["EndDate"])
        status = r["Status"].strip()
        delta = to_int(r.get("Delta"))
        place = to_int(r.get("Place"))
        regpcr, startpcr = to_int(r.get("RegPCR")), to_int(r.get("StartPCR"))
        fee = to_int(r.get("EntranceFee"))
        ch = chain[uid].get(cid)
        rg, ap = registered[uid].get(cid), applied[uid].get(cid)
        in_cw = CHARGE_START <= en < CHARGE_END
        online = online_minutes(uid, st, en)
        carried = startpcr if startpcr is not None else (ch[0] if ch else None)

        if ch:
            for v in (ch[0], ch[1]):
                pcr_min = v if pcr_min is None else min(pcr_min, v)
                pcr_max = v if pcr_max is None else max(pcr_max, v)
            if in_cw and not first_cw_row_seen:
                entering_cw, first_cw_row_seen = ch[0], True

        for agg, on in ((span, True), (cw, in_cw)):
            if not on:
                continue
            agg["reg"] += 1
            if status == "IN-PROGRESS":
                agg["prog"] += 1
                continue
            if delta is not None:
                agg["net"] += delta
            if status == "PLAYED":
                agg["played"] += 1
                if delta is not None:
                    agg["earned"] += delta
                agg["play" + bracket(carried)] = agg.get("play" + bracket(carried), 0) + 1
            elif status == "ZERO-SCORE":
                agg["zs"] += 1
                if delta is not None:
                    agg["shed"] += delta
            elif status == "NO-SHOW":
                agg["ns"] += 1
                if delta is not None:
                    agg["shed"] += delta
                if online >= 30:
                    agg["ns_online30"] += 1
            elif status == "DQ":
                agg["dq"] += 1
            if place is not None and 1 <= place <= 3:
                agg["prizes"] += 1
                agg["p" + bracket(carried)] = agg.get("p" + bracket(carried), 0) + 1
            if ch is None and status != "IN-PROGRESS":
                agg["unlogged"] += 1
            if ch and status in ("NO-SHOW", "ZERO-SCORE") and ch[0] >= 101 and ch[1] <= 100:
                agg["drops"] += 1

        if status in ("NO-SHOW", "ZERO-SCORE"):
            streak += 1
            if streak > best_streak:
                best_streak, best_streak_end = streak, st
        elif status != "IN-PROGRESS":
            streak = 0

        chain_txt = ("%d -> %d" % (ch[0], ch[1])) if ch else ("." if status == "IN-PROGRESS" else "not logged")
        table.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %d | %s |" % (
            fmt_dt(st), fmt_short(rg), fmt_short(ap),
            "." if regpcr is None else regpcr, "." if startpcr is None else startpcr,
            status, "." if place is None else place, "." if delta is None else delta,
            chain_txt, "%.0f" % online, "." if fee is None else fee, cid,
            (r.get("Competition") or "").strip() or "."))

    ceiling = (entering_cw + cw["earned"]) if entering_cw is not None else None
    batch_txt = "; ".join("%s x%d" % (fmt_short(b[0][1]), len(b)) for b in batches) or "none"

    head = [
        "---",
        "uid: %s" % uid,
        "username: %s" % name,
        "platform: %s" % plat,
        "card_span: competitions starting 2026-09-14 .. 2026-09-27 (SQL spine)",
        "charge_window: 2026-09-21 .. 2026-09-27 by EndDate",
        "registrations: %d span; %d charge window" % (span["reg"], cw["reg"]),
        "played: %d span; %d charge window" % (span["played"], cw["played"]),
        "zero_score: %d span; %d charge window" % (span["zs"], cw["zs"]),
        "no_shows: %d span; %d charge window" % (span["ns"], cw["ns"]),
        "no_shows_online_30min_plus: %d span; %d charge window" % (span["ns_online30"], cw["ns_online30"]),
        "rating_shed_unproductive: %d span; %d charge window" % (span["shed"], cw["shed"]),
        "rating_from_productive_play: %d span; %d charge window" % (span["earned"], cw["earned"]),
        "net_delta: %d span; %d charge window" % (span["net"], cw["net"]),
        "pcr_range_logged: %s..%s" % (pcr_min, pcr_max),
        "entering_rating_charge_window: %s" % ("." if entering_cw is None else entering_cw),
        "counterfactual_ceiling_charge_window: %s" % ("." if ceiling is None else "%d (%s)" % (ceiling, bracket(ceiling))),
        "played_NMT_charge_window: %d / %d / %d" % (cw["playN"], cw["playM"], cw["playT"]),
        "prizes_NMT_charge_window: %d / %d / %d (total %d)" % (cw["pN"], cw["pM"], cw["pT"], cw["prizes"]),
        "middles_to_noobs_drops: %d span; %d charge window" % (span["drops"], cw["drops"]),
        "longest_unproductive_run: %d (ending at the competition starting %s)" % (best_streak, fmt_dt(best_streak_end)),
        "registration_batches_120s: %d -- %s" % (len(batches), batch_txt),
        "unregistrations: %d" % len(unregistered[uid]),
        "rows_not_in_log: %d span" % span["unlogged"],
        "in_progress_rows: %d" % span["prog"],
        "---",
        "",
        "# %s - PCR trajectory card (week-21)" % name,
        "",
        "%s, %s. Spine from SQL (participation rows for competitions starting 2026-09-14 .. 2026-09-27); "
        "Registered / Applied / PCR chain from the tournament log; Online = minutes of GameSessions overlap "
        "with the competition window. Charge window 2026-09-21 .. 2026-09-27 by EndDate; earlier rows are pre-context." % (name, plat),
        "",
        "## Ledger",
        "",
    ]
    out_path = os.path.join(HERE, "%s-%s.md" % (uid, slug(name)))
    with open(out_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(head + table) + "\n")

    summary_lines.append(
        "%-18s %-5s cw: reg %3d played %3d ns %3d zs %2d | shed %5d earned %+5d net %+5d | "
        "prizes N/M/T %d/%d/%d | played N/M/T %d/%d/%d | entering %s ceiling %s | drops %d | ns online>=30m %d | batches %d | unlogged %d | run %d"
        % (name, plat, cw["reg"], cw["played"], cw["ns"], cw["zs"], cw["shed"], cw["earned"], cw["net"],
           cw["pN"], cw["pM"], cw["pT"], cw["playN"], cw["playM"], cw["playT"],
           "." if entering_cw is None else entering_cw,
           "." if ceiling is None else "%d%s" % (ceiling, bracket(ceiling)),
           cw["drops"], cw["ns_online30"], len(batches), span["unlogged"], best_streak))

print("log lines parsed: %d; candidates in ledger: %d; sessions rows: %d"
      % (log_lines, len(ledger), sum(len(v) for v in sessions.values())))
print("\n".join(summary_lines))
