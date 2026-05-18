"""
FP-43625 -- joint calibration of (MaxWins, Max2nd, Max3rd) triples.

Sweep over all plausible (N_g, N_s, N_b) triples for each bracket. For each
triple, apply the OR-gate to the bracket population, compute:
  - promoted: number of players promoted
  - TP:        number of those that are in FP-43631 suspect cohort
  - precision_LB:  TP / promoted  (lower bound; cohort is partial)
  - recall:    TP / (bracket suspects)  (cohort-relative recall)
  - F1:        harmonic mean of precision_LB and recall

Then find the Pareto-optimal front (no other triple dominates on both
precision and recall) and recommend representative picks:
  - max precision_LB
  - max recall
  - max F1
  - closest to GD-spec
"""

import re
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

DATA_DIR = Path(r"D:/FishingPlanet/Docs/Reports/2026-05-17-rating-correlation")
BANS_DIR = Path(r"D:/kb/fishing-planet/tasks/FP-43631--rating-drop-abuse-detection/artifacts")
PLATFORMS = [("steam", "Steam/EGS"), ("ps", "PlayStation"), ("xb", "Xbox")]

GD_SPEC = {
    "Newbies": (3, 4, 5),
    "Middles": (12, 15, 20),
}
SWEEP_RANGES = {
    "Newbies": (range(1, 11), range(1, 13), range(1, 16)),   # N_g, N_s, N_b
    "Middles": (range(3, 21), range(3, 26), range(3, 31)),
}
BRACKET_RANGE = {
    "Newbies": (0, 100),
    "Middles": (101, 1000),
}


def load_combined():
    dfs = []
    for k, _ in PLATFORMS:
        df = pd.read_csv(DATA_DIR / f"{k}-q1-scatter.csv",
                         dtype={"UserId": str, "PCR": "Int32",
                                "Gold": "Int32", "Silver": "Int32", "Bronze": "Int32"})
        df["platform"] = k
        dfs.append(df)
    return pd.concat(dfs, ignore_index=True)


def load_suspects():
    pat = re.compile(r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}")
    ids = set()
    for f in ["bans-2026-05-11.md", "bans-2026-05-18.md"]:
        for m in pat.findall((BANS_DIR / f).read_text(encoding="utf-8")):
            ids.add(m.upper())
    return ids


def bracket_subset(combined, bracket):
    lo, hi = BRACKET_RANGE[bracket]
    return combined[(combined["PCR"] >= lo) & (combined["PCR"] <= hi)].copy()


def sweep(bracket_df, ranges):
    """For each (N_g, N_s, N_b) in ranges, evaluate OR-gate."""
    gold = bracket_df["Gold"].fillna(0).to_numpy()
    silv = bracket_df["Silver"].fillna(0).to_numpy()
    bron = bracket_df["Bronze"].fillna(0).to_numpy()
    susp = bracket_df["is_suspect"].to_numpy()
    n_suspects = int(susp.sum())

    rows = []
    for ng in ranges[0]:
        gold_ok = gold >= ng
        for ns in ranges[1]:
            silv_ok = silv >= ns
            gs_or = gold_ok | silv_ok
            for nb in ranges[2]:
                promoted = gs_or | (bron >= nb)
                n_promoted = int(promoted.sum())
                if n_promoted == 0:
                    continue
                n_tp = int((promoted & susp).sum())
                p_lb = n_tp / n_promoted
                rc = n_tp / n_suspects if n_suspects else 0
                f1 = 2 * p_lb * rc / (p_lb + rc) if (p_lb + rc) else 0
                rows.append({
                    "n_g": ng, "n_s": ns, "n_b": nb,
                    "promoted": n_promoted, "TP": n_tp,
                    "precision_LB": p_lb, "recall": rc, "F1": f1,
                })
    return pd.DataFrame(rows)


def pareto_front(df):
    """Pareto-optimal rows: no other row strictly dominates on both precision and recall."""
    pts = df[["precision_LB", "recall"]].to_numpy()
    n = len(pts)
    is_pareto = np.ones(n, dtype=bool)
    for i in range(n):
        if not is_pareto[i]:
            continue
        for j in range(n):
            if i == j:
                continue
            if pts[j, 0] >= pts[i, 0] and pts[j, 1] >= pts[i, 1] \
               and (pts[j, 0] > pts[i, 0] or pts[j, 1] > pts[i, 1]):
                is_pareto[i] = False
                break
    return df[is_pareto].reset_index(drop=True)


def print_pick(label, row):
    print(f"  {label:<22} ({int(row.n_g)}/{int(row.n_s)}/{int(row.n_b)})  "
          f"promoted={int(row.promoted):>5,}  TP={int(row.TP):>3}  "
          f"precision={row.precision_LB:6.1%}  recall={row.recall:6.1%}  "
          f"F1={row.F1:.3f}")


def main():
    print("Loading...")
    combined = load_combined()
    suspects = load_suspects()
    combined["UserId_upper"] = combined["UserId"].str.upper()
    combined["is_suspect"] = combined["UserId_upper"].isin(suspects)
    print(f"  combined rows: {len(combined):,}")
    print(f"  suspects: {len(suspects)} UserIds\n")

    for bracket in ("Newbies", "Middles"):
        bdf = bracket_subset(combined, bracket)
        n_total = len(bdf)
        n_susp = int(bdf["is_suspect"].sum())
        print(f"=== {bracket} bracket (PCR {BRACKET_RANGE[bracket]}) ===")
        print(f"  population: {n_total:,}; suspects: {n_susp}")
        print(f"  sweep ranges: N_g={list(SWEEP_RANGES[bracket][0])[0]}..{list(SWEEP_RANGES[bracket][0])[-1]}, "
              f"N_s={list(SWEEP_RANGES[bracket][1])[0]}..{list(SWEEP_RANGES[bracket][1])[-1]}, "
              f"N_b={list(SWEEP_RANGES[bracket][2])[0]}..{list(SWEEP_RANGES[bracket][2])[-1]}")

        results = sweep(bdf, SWEEP_RANGES[bracket])
        print(f"  triples evaluated: {len(results):,}")

        # Pareto front
        front = pareto_front(results).sort_values("recall", ascending=False)
        print(f"  Pareto-optimal triples: {len(front)}")

        # Special picks
        gd_n_g, gd_n_s, gd_n_b = GD_SPEC[bracket]
        gd_row = results[(results.n_g == gd_n_g) & (results.n_s == gd_n_s) & (results.n_b == gd_n_b)]
        max_prec = results.sort_values(["precision_LB", "recall"], ascending=[False, False]).iloc[0]
        max_rec  = results.sort_values(["recall", "precision_LB"], ascending=[False, False]).iloc[0]
        max_f1   = results.sort_values("F1", ascending=False).iloc[0]
        balanced = results[(results.precision_LB >= 0.30) & (results.recall >= 0.30)].sort_values("F1", ascending=False)

        print(f"\n  Notable triples:")
        if not gd_row.empty:
            print_pick("GD-spec", gd_row.iloc[0])
        print_pick("max precision_LB", max_prec)
        print_pick("max recall", max_rec)
        print_pick("max F1", max_f1)
        if not balanced.empty:
            print_pick("balanced (P>=30%, R>=30%, max F1)", balanced.iloc[0])

        # Top 15 Pareto-front rows by recall
        print(f"\n  Top Pareto-front (sorted by recall desc):")
        print(f"  {'n_g':>4} {'n_s':>4} {'n_b':>4}  {'promoted':>8} {'TP':>4}  "
              f"{'precision':>10} {'recall':>8} {'F1':>6}")
        for _, r in front.head(20).iterrows():
            print(f"  {int(r.n_g):>4} {int(r.n_s):>4} {int(r.n_b):>4}  "
                  f"{int(r.promoted):>8,} {int(r.TP):>4}  "
                  f"{r.precision_LB:>10.1%} {r.recall:>8.1%} {r.F1:>6.3f}")

        # CSV
        results.to_csv(DATA_DIR / f"joint-calibration-{bracket.lower()}.csv", index=False)
        print(f"\n  Wrote joint-calibration-{bracket.lower()}.csv ({len(results):,} rows)\n")

        # Pareto plot
        fig, ax = plt.subplots(figsize=(10, 7), constrained_layout=True)
        ax.scatter(results["recall"], results["precision_LB"], s=4, alpha=0.15, color="gray",
                   label=f"all triples ({len(results):,})")
        ax.scatter(front["recall"], front["precision_LB"], s=20, color="tab:blue",
                   label=f"Pareto front ({len(front)})")
        if not gd_row.empty:
            r = gd_row.iloc[0]
            ax.scatter(r.recall, r.precision_LB, s=160, color="orange", marker="*",
                       edgecolor="black", linewidth=1,
                       label=f"GD-spec {gd_n_g}/{gd_n_s}/{gd_n_b}")
        for label, r, c, mk in [
            ("max precision", max_prec, "red", "^"),
            ("max recall", max_rec, "green", "v"),
            ("max F1", max_f1, "purple", "D"),
        ]:
            ax.scatter(r.recall, r.precision_LB, s=80, color=c, marker=mk,
                       edgecolor="black", linewidth=0.8,
                       label=f"{label}: {int(r.n_g)}/{int(r.n_s)}/{int(r.n_b)}")
        ax.set_xlabel("Recall (cohort-relative; fraction of FP-43631 suspects caught)")
        ax.set_ylabel("Precision_LB (TP / promoted; cohort overlap; actual precision >=)")
        ax.set_title(f"FP-43625 joint calibration -- {bracket} bracket\n"
                     f"OR-gate (gold>=N_g OR silver>=N_s OR bronze>=N_b)")
        ax.grid(True, alpha=0.3)
        ax.legend(loc="upper right", fontsize=8)
        ax.set_xlim(-0.02, 1.02)
        ax.set_ylim(-0.02, 1.02)
        fig.savefig(DATA_DIR / f"joint-calibration-{bracket.lower()}.png", dpi=120)
        plt.close(fig)
        print(f"  Wrote joint-calibration-{bracket.lower()}.png\n")


if __name__ == "__main__":
    main()
