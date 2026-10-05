"""Build the hearing bundle: one manual and one case file per candidate.

Usage:
    python build_bundle.py --date 2026-10-11 --cases cases.json --out <scratchpad>/tribunal

`cases.json` is a list of objects with uid, name, platform (steam / ps / xb), board (place and wins on
the weekly board when the week closed, in words) and history (ban history and earlier reviews, in
words). The cards folder is `pcr-log-trajectories-<date>/` next to this script's parent folder.

The manual is `manual-setting.md` followed by `reading-guide.md` as it stands (frontmatter dropped),
the same for every candidate: the judges see every hint the operator sees. The case file is the
trajectory card plus the case sheet, the game sessions and the raw columns of played rows with no
place. No verdict of the cycle is written into the bundle.

The script prints one line per case and writes `args.json` next to the bundle: the `cases` list for
the workflow (slug and name) and the `base` path.
"""
import argparse
import csv
import glob
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
TASK = os.path.dirname(os.path.dirname(HERE))
PLAT = {"steam": "Steam", "ps": "PlayStation", "xb": "Xbox"}


def build_manual():
    with open(os.path.join(HERE, "manual-setting.md"), encoding="utf-8") as fh:
        setting = fh.read().rstrip()
    with open(os.path.join(TASK, "reading-guide.md"), encoding="utf-8") as fh:
        guide = fh.read()
    guide = re.sub(r"\A---\n.*?\n---\n", "", guide, flags=re.S).strip()
    return setting + "\n\n" + guide + "\n"


def read_tsv(path):
    with open(path, encoding="utf-8-sig", newline="") as fh:
        return list(csv.DictReader(fh, delimiter="\t"))


def sessions_block(cards, plat, date, uid):
    rows = [r for r in read_tsv(os.path.join(cards, "%s-sessions-%s.tsv" % (plat, date))) if r["UserId"].lower() == uid]
    out = []
    for r in rows:
        end = r["EndedAt"] or r["UpdatedAt"] or r["StartedAt"]
        out.append("- %s -> %s (%s min)" % (r["StartedAt"][5:16].replace("T", " "), end[5:16].replace("T", " "), r["Minutes"]))
    return out


def odd_rows_block(cards, plat, date, uid):
    rows = [r for r in read_tsv(os.path.join(cards, "%s-ledger-%s.tsv" % (plat, date)))
            if r["UserId"].lower() == uid and r["Status"] == "PLAYED" and not r["Place"].strip()]
    return ["| %s | %s | %s | %s | %s | %s | %s |" % (
        r["StartDate"][:16].replace("T", " "), r["TournamentId"], r["Competition"],
        r["Score"] or "empty", r["SecondaryScore"] or "empty", r["FishCount"] or "empty", r["Delta"] or "empty") for r in rows]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--date", required=True)
    ap.add_argument("--cases", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    cards = os.path.join(os.path.dirname(HERE), "pcr-log-trajectories-" + a.date)
    with open(a.cases, encoding="utf-8") as fh:
        cases = json.load(fh)
    manual = build_manual()
    os.makedirs(a.out, exist_ok=True)

    args = {"base": a.out.replace("\\", "/").rstrip("/") + "/", "cases": []}
    for c in cases:
        uid = c["uid"].lower()
        card_paths = glob.glob(os.path.join(cards, uid + "-*.md"))
        assert len(card_paths) == 1, (c["name"], card_paths)
        slug = os.path.basename(card_paths[0])[len(uid) + 1:-3]
        with open(card_paths[0], encoding="utf-8") as fh:
            card = fh.read().rstrip()

        parts = ["# Case file: %s (%s)" % (c["name"], PLAT[c["platform"]]), "",
                 "## Case sheet", "",
                 "- Platform: %s." % PLAT[c["platform"]],
                 "- Weekly board of first places when the week closed: %s." % c["board"],
                 "- History: %s" % c["history"],
                 "- Why he is in review: the weekly detection query lists every player with at least 6 absences or "
                 "zero-score entries, making at least 30% of his registrations, at least 90 rating points lost "
                 "through them, and at least 4 prizes in the week. It is a net, not a finding.",
                 "- The card covers 2 weeks. The second week (the charge window) is the one under review; the first "
                 "is context.", "",
                 "## Trajectory card", "", card, ""]
        sess = sessions_block(cards, c["platform"], a.date, uid)
        parts += ["## Game sessions (UTC)", "",
                  "Every stay on a game server in the 2 weeks: start -> end (minutes). A session is presence in the "
                  "game, not participation in a competition.", ""]
        parts += sess if sess else ["- none recorded"]
        parts += [""]
        odd = odd_rows_block(cards, c["platform"], a.date, uid)
        if odd:
            parts += ["## Played rows with no place (raw result columns)", "",
                      "| Comp start | ID | Competition | Score | SecondaryScore | FishCount | Delta |",
                      "|---|---|---|---|---|---|---|"] + odd + [""]

        with open(os.path.join(a.out, "case-%s.md" % slug), "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(parts))
        with open(os.path.join(a.out, "manual-%s.md" % slug), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(manual)
        args["cases"].append({"slug": slug, "name": c["name"]})
        print("%-16s sessions %3d, odd rows %d" % (c["name"], len(sess), len(odd)))

    with open(os.path.join(a.out, "args.json"), "w", encoding="utf-8") as fh:
        json.dump(args, fh, indent=1)
    print(len(cases), "cases ->", a.out, "; workflow args in args.json")


if __name__ == "__main__":
    main()
