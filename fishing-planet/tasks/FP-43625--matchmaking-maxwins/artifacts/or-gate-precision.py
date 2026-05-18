"""
FP-43625 -- OR-gate precision analysis.

Apply discrete MaxWins gate with OR-aggregation across medals to full population.
Report per-platform breakdown:
  - Total in bracket
  - Promoted by OR-gate (count + percentage)
  - Overlap with FP-43631 cohort (TP lower bound)
  - Implied precision LB

Compares two candidate thresholds:
  - p25 data-driven: Newbies 1/2/2, Middles 7/7/7
  - GD-spec:         Newbies 3/4/5, Middles 12/15/20
"""

import re
from pathlib import Path
import pandas as pd

DATA_DIR = Path(r"D:/FishingPlanet/Docs/Reports/2026-05-17-rating-correlation")
BANS_DIR = Path(r"D:/kb/fishing-planet/tasks/FP-43631--rating-drop-abuse-detection/artifacts")

PLATFORMS = [("steam", "Steam/EGS"), ("ps", "PlayStation"), ("xb", "Xbox")]

GATES = {
    "p25-data": {"Newbies": (1, 2, 2),  "Middles": (7, 7, 7)},
    "GD-spec":  {"Newbies": (3, 4, 5),  "Middles": (12, 15, 20)},
}


def load_platform(key):
    return pd.read_csv(DATA_DIR / f"{key}-q1-scatter.csv",
                       dtype={"UserId": str, "PCR": "Int32",
                              "Gold": "Int32", "Silver": "Int32", "Bronze": "Int32"})


def load_suspects():
    pat = re.compile(r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}")
    ids = set()
    for f in ["bans-2026-05-11.md", "bans-2026-05-18.md"]:
        for m in pat.findall((BANS_DIR / f).read_text(encoding="utf-8")):
            ids.add(m.upper())
    return ids


def trip(row, gate):
    g, s, b = row["Gold"], row["Silver"], row["Bronze"]
    return g >= gate[0] or s >= gate[1] or b >= gate[2]


def analyze(df, gates_set, suspects):
    df = df.dropna(subset=["PCR"]).copy()
    df["UserId_upper"] = df["UserId"].str.upper()
    df["is_suspect"] = df["UserId_upper"].isin(suspects)
    df["bracket"] = df["PCR"].apply(lambda r: "Newbies" if r <= 100 else "Middles" if r <= 1000 else "Tops")

    rows = []
    for bracket in ("Newbies", "Middles"):
        bdf = df[df["bracket"] == bracket]
        gate = gates_set[bracket]
        promoted_mask = bdf.apply(lambda r: trip(r, gate), axis=1)
        promoted = bdf[promoted_mask]
        n_total = len(bdf)
        n_promoted = len(promoted)
        n_tp = int(promoted["is_suspect"].sum())
        rows.append({
            "bracket": bracket,
            "gate": f"{gate[0]}/{gate[1]}/{gate[2]}",
            "total":      n_total,
            "promoted":   n_promoted,
            "promoted_pct": n_promoted / n_total if n_total else 0,
            "TP":         n_tp,
            "precision_LB": n_tp / n_promoted if n_promoted else 0,
        })
    return pd.DataFrame(rows)


def main():
    print("Loading...")
    data = {k: load_platform(k) for k, _ in PLATFORMS}
    suspects = load_suspects()
    print(f"Suspects from FP-43631: {len(suspects)} UserIds\n")

    for name, gates_set in GATES.items():
        print(f"=== Gate set: {name} ===")
        print(f"  Newbies: gold>={gates_set['Newbies'][0]} or silver>={gates_set['Newbies'][1]} or bronze>={gates_set['Newbies'][2]}")
        print(f"  Middles: gold>={gates_set['Middles'][0]} or silver>={gates_set['Middles'][1]} or bronze>={gates_set['Middles'][2]}\n")

        for key, label in PLATFORMS:
            df_analyze = analyze(data[key], gates_set, suspects)
            print(f"  {label}")
            for _, r in df_analyze.iterrows():
                print(f"    {r['bracket']:<8} gate={r['gate']:<10} "
                      f"total={r['total']:>7,}  promoted={r['promoted']:>5,}  "
                      f"({r['promoted_pct']:6.2%} of bracket)  "
                      f"TP={r['TP']:>3}  precision_LB={r['precision_LB']:6.1%}")
            print()
        print()


if __name__ == "__main__":
    main()
