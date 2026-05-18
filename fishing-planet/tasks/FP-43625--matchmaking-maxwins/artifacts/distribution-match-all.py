"""
FP-43625 -- distribution-matching calibration for BOTH brackets.

Newbies gate: target = "non-Newbies" wins distribution (Middles + Tops combined).
  Rationale: a Newbies-promoted player leaves Newbies; their wins should resemble
  the population they're joining. The cascade then routes further (Middles-gate
  catches Tops-equivalent ones).

Middles gate: target = Tops wins distribution.
  Rationale: a Middles-promoted player goes to Tops; their wins should resemble
  Tops.

Metric: KS distance per medal between source-bracket-promoted and target
distribution. Aggregate via max() (worst-medal-wins) and mean().

Generates:
  - distribution-match-newbies.csv, distribution-match-middles.csv
  - cdf-newbies.png, cdf-middles.png  (CDF comparison plots per medal)
"""

from pathlib import Path
import numpy as np
import pandas as pd
from scipy.stats import ks_2samp
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

DATA_DIR = Path(r"D:/FishingPlanet/Docs/Reports/2026-05-17-rating-correlation")
PLATFORMS = [("steam", "Steam/EGS"), ("ps", "PlayStation"), ("xb", "Xbox")]
MEDALS = ["Gold", "Silver", "Bronze"]
MIN_PROMOTED = 30

CONFIG = {
    "Newbies": {
        "source_filter": lambda df: df[df["bracket"] == "Newbies"],
        "target_filter": lambda df: df[df["bracket"] != "Newbies"],   # Middles + Tops
        "target_label":  "non-Newbies (Middles + Tops)",
        "sweep":  (range(1, 11), range(1, 13), range(1, 16)),
        "gd_spec": (3, 4, 5),
    },
    "Middles": {
        "source_filter": lambda df: df[df["bracket"] == "Middles"],
        "target_filter": lambda df: df[df["bracket"] == "Tops"],
        "target_label":  "Tops",
        "sweep":  (range(3, 21), range(3, 26), range(3, 31)),
        "gd_spec": (12, 15, 20),
    },
}


def load_combined():
    dfs = []
    for k, _ in PLATFORMS:
        df = pd.read_csv(DATA_DIR / f"{k}-q1-scatter.csv",
                         dtype={"UserId": str, "PCR": "Int32",
                                "Gold": "Int32", "Silver": "Int32", "Bronze": "Int32"})
        dfs.append(df)
    df = pd.concat(dfs, ignore_index=True).dropna(subset=["PCR"])
    df["bracket"] = df["PCR"].apply(
        lambda p: "Newbies" if p <= 100 else "Middles" if p <= 1000 else "Tops")
    return df


def ks_distance(a, b):
    if len(a) < 5 or len(b) < 5:
        return float("inf")
    return float(ks_2samp(a, b).statistic)


def sweep_bracket(df, cfg):
    source = cfg["source_filter"](df)
    target = cfg["target_filter"](df)
    target_arrays = {m: target[m].to_numpy() for m in MEDALS}
    gold_s = source["Gold"].to_numpy()
    silv_s = source["Silver"].to_numpy()
    bron_s = source["Bronze"].to_numpy()
    rows = []
    for ng in cfg["sweep"][0]:
        gok = gold_s >= ng
        for ns in cfg["sweep"][1]:
            gsok = gok | (silv_s >= ns)
            for nb in cfg["sweep"][2]:
                mask = gsok | (bron_s >= nb)
                n_prom = int(mask.sum())
                if n_prom < MIN_PROMOTED:
                    continue
                ks_g = ks_distance(gold_s[mask], target_arrays["Gold"])
                ks_s = ks_distance(silv_s[mask], target_arrays["Silver"])
                ks_b = ks_distance(bron_s[mask], target_arrays["Bronze"])
                rows.append({
                    "n_g": ng, "n_s": ns, "n_b": nb,
                    "promoted": n_prom,
                    "KS_gold": ks_g, "KS_silver": ks_s, "KS_bronze": ks_b,
                    "KS_max":  max(ks_g, ks_s, ks_b),
                    "KS_mean": (ks_g + ks_s + ks_b) / 3,
                })
    return pd.DataFrame(rows), source, target


def find_row(df, triple):
    g, s, b = triple
    r = df[(df.n_g == g) & (df.n_s == s) & (df.n_b == b)]
    return r.iloc[0] if not r.empty else None


def print_picks(results, cfg, label):
    gd = cfg["gd_spec"]
    print(f"\n=== {label} ===")
    print(f"  source: {label} bracket; target: {cfg['target_label']}")
    print(f"  feasible triples: {len(results):,}")

    best_max  = results.sort_values("KS_max").iloc[0]
    best_mean = results.sort_values("KS_mean").iloc[0]
    gd_row    = find_row(results, gd)

    print(f"\n  Best by KS_max (worst-medal optimization):")
    _print_row(best_max)
    print(f"  Best by KS_mean (average optimization):")
    _print_row(best_mean)
    if gd_row is not None:
        print(f"  GD-spec {gd[0]}/{gd[1]}/{gd[2]}:")
        _print_row(gd_row)
        rk_max = int((results["KS_max"] <= gd_row.KS_max).sum())
        rk_mean = int((results["KS_mean"] <= gd_row.KS_mean).sum())
        print(f"    rank: KS_max #{rk_max}/{len(results):,} ({rk_max/len(results):.1%})  "
              f"KS_mean #{rk_mean}/{len(results):,} ({rk_mean/len(results):.1%})")


def _print_row(r):
    print(f"    ({int(r.n_g)}/{int(r.n_s)}/{int(r.n_b)})  promoted={int(r.promoted):>5}  "
          f"KS_gold={r.KS_gold:.3f}  KS_silver={r.KS_silver:.3f}  KS_bronze={r.KS_bronze:.3f}  "
          f"KS_max={r.KS_max:.3f}  KS_mean={r.KS_mean:.3f}")


def plot_cdfs(source, target, target_label, gd_spec, picks, out_path, title):
    """3-panel figure: CDF per medal, with target/GD-spec-promoted/recommended-promoted overlaid."""
    fig, axes = plt.subplots(1, 3, figsize=(16, 5), constrained_layout=True)
    fig.suptitle(title, fontsize=11)

    gd_mask = ((source["Gold"]   >= gd_spec[0]) |
               (source["Silver"] >= gd_spec[1]) |
               (source["Bronze"] >= gd_spec[2]))
    gd_promoted = source[gd_mask]

    for ax, medal in zip(axes, MEDALS):
        for label, data, style in [
            (f"{target_label}  (n={len(target):,})", target[medal], ("tab:orange", "-", 2.0)),
            (f"GD-spec promoted  (n={len(gd_promoted):,})", gd_promoted[medal], ("tab:red", "--", 1.5)),
        ]:
            xs = np.sort(data.to_numpy())
            ys = np.arange(1, len(xs) + 1) / len(xs)
            ax.plot(xs, ys, color=style[0], linestyle=style[1], linewidth=style[2], label=label)
        # plot each pick
        for name, triple, color in picks:
            mask = ((source["Gold"]   >= triple[0]) |
                    (source["Silver"] >= triple[1]) |
                    (source["Bronze"] >= triple[2]))
            promoted = source[mask]
            xs = np.sort(promoted[medal].to_numpy())
            if len(xs) > 0:
                ys = np.arange(1, len(xs) + 1) / len(xs)
                ax.plot(xs, ys, color=color, linestyle="-", linewidth=1.5,
                        label=f"{name}  {triple[0]}/{triple[1]}/{triple[2]}  (n={len(xs):,})")
        ax.set_xlim(0, 60)
        ax.set_ylim(0, 1.02)
        ax.set_title(medal)
        ax.set_xlabel(f"{medal} count")
        ax.grid(True, alpha=0.3)
        if medal == "Gold":
            ax.set_ylabel("CDF: P(count <= x)")
        ax.legend(fontsize=7, loc="lower right")

    fig.savefig(out_path, dpi=120)
    plt.close(fig)


def main():
    print("Loading...")
    df = load_combined()
    print(f"  Newbies: {len(df[df.bracket == 'Newbies']):,}, "
          f"Middles: {len(df[df.bracket == 'Middles']):,}, "
          f"Tops: {len(df[df.bracket == 'Tops']):,}")

    for bracket_name, cfg in CONFIG.items():
        results, source, target = sweep_bracket(df, cfg)
        results.to_csv(DATA_DIR / f"distribution-match-{bracket_name.lower()}.csv", index=False)
        print_picks(results, cfg, bracket_name)

        # CDF visualization with picks
        best_max  = results.sort_values("KS_max").iloc[0]
        best_mean = results.sort_values("KS_mean").iloc[0]
        gd = cfg["gd_spec"]
        picks = [
            (f"best KS_max",  (int(best_max.n_g), int(best_max.n_s), int(best_max.n_b)),
             "tab:blue"),
        ]
        if (int(best_mean.n_g), int(best_mean.n_s), int(best_mean.n_b)) != \
           (int(best_max.n_g), int(best_max.n_s), int(best_max.n_b)):
            picks.append((f"best KS_mean",
                          (int(best_mean.n_g), int(best_mean.n_s), int(best_mean.n_b)),
                          "tab:green"))

        plot_cdfs(source, target, cfg["target_label"], gd, picks,
                  DATA_DIR / f"cdf-{bracket_name.lower()}.png",
                  f"FP-43625 distribution match -- {bracket_name} bracket\n"
                  f"target: {cfg['target_label']}.  "
                  f"Closer the line is to orange, better the promoted-cohort matches the target.")
        print(f"\n  Wrote cdf-{bracket_name.lower()}.png")


if __name__ == "__main__":
    main()
