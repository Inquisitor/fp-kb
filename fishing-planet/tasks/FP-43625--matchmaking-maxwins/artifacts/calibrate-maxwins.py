"""
FP-43625 -- data-driven calibration of discrete MaxWins thresholds.

Input:  D:/FishingPlanet/Docs/Reports/2026-05-17-rating-correlation/<platform>-q1-scatter.csv
Output: <same dir>/maxwins-calibration.csv  -- per (platform, medal, wins_threshold)
        <same dir>/maxwins-calibration.png  -- visualisation of crossings
        stdout: recommended thresholds for Newbies and Middles per medal

Methodology
-----------
For each (platform, medal):

  1. For each candidate threshold N (1, 2, 3, ..., up to high enough):
     a. Take the cohort of players with wins >= N AND non-NULL PCR.
     b. Compute median PCR of that cohort.
  2. Find smallest N such that median_PCR > 100  -> MaxWins candidate for Newbies.
     Find smallest N such that median_PCR > 1000 -> MaxWins candidate for Middles.

Interpretation: "at threshold N, more than half of the players with at least N
podiums of this kind are already in the next bracket by rating alone". The gate
catches the half who tanked despite earning enough wins to naturally graduate.

Cadence: re-run periodically (monthly?), push new thresholds to the JsonVariable.
The metagame shifts (new content, new players, season transitions) -- thresholds
follow.
"""

from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

DATA_DIR = Path(r"D:/FishingPlanet/Docs/Reports/2026-05-17-rating-correlation")

PLATFORMS = [
    ("steam", "Steam/EGS"),
    ("ps",    "PlayStation"),
    ("xb",    "Xbox"),
]
MEDALS = ["Gold", "Silver", "Bronze"]
MEDAL_COLORS = {"Gold": "#d4a017", "Silver": "#9aa0a6", "Bronze": "#cd7f32"}
GD_SPEC = {"Gold": (3, 12), "Silver": (4, 15), "Bronze": (5, 20)}
BOUNDARY_NEWBIES = 100
BOUNDARY_MIDDLES = 1000
MIN_COHORT_SIZE = 20
PERCENTILE = 25


def load_platform(key: str) -> pd.DataFrame:
    return pd.read_csv(DATA_DIR / f"{key}-q1-scatter.csv",
                       dtype={"UserId": str, "PCR": "Int32",
                              "Gold": "Int32", "Silver": "Int32", "Bronze": "Int32",
                              "CurrentBracket": "category"})


def calibrate(df: pd.DataFrame, medal: str, max_threshold: int = 40, percentile: int = PERCENTILE):
    """For each wins threshold 1..max, compute pX PCR of cohort (wins >= N, PCR not null).
    Return DataFrame: (threshold, n_cohort, primary_pcr, p25, p50, p75, p90)."""
    sub = df.dropna(subset=["PCR"]).copy()
    sub["PCR"] = sub["PCR"].astype(int)
    rows = []
    for n in range(1, max_threshold + 1):
        cohort = sub[sub[medal] >= n]
        if len(cohort) < MIN_COHORT_SIZE:
            continue
        rows.append({
            "threshold": n,
            "n_cohort":  len(cohort),
            "primary_pcr": int(cohort["PCR"].quantile(percentile / 100)),
            "p25_pcr":    int(cohort["PCR"].quantile(0.25)),
            "p50_pcr":    int(cohort["PCR"].quantile(0.50)),
            "p75_pcr":    int(cohort["PCR"].quantile(0.75)),
            "p90_pcr":    int(cohort["PCR"].quantile(0.90)),
        })
    return pd.DataFrame(rows)


def find_crossing(calib: pd.DataFrame, boundary: int):
    """Smallest threshold where primary_pcr > boundary (primary_pcr = the chosen percentile)."""
    above = calib[calib["primary_pcr"] > boundary]
    return int(above["threshold"].iloc[0]) if not above.empty else None


def main():
    print("Loading CSVs:")
    data = {key: load_platform(key) for key, _ in PLATFORMS}
    for k, df in data.items():
        print(f"  {k:<6} -- {len(df):>8,} rows")
    combined = pd.concat(data.values(), ignore_index=True)
    print(f"  combined -- {len(combined):>8,} rows\n")

    scopes = [("combined", combined)] + [(k, data[k]) for k, _ in PLATFORMS]
    all_rows = []
    recommendations = {}

    print(f"Recommended MaxWins thresholds (data-driven, p{PERCENTILE} of cohort with wins>=N):\n")
    print(f"  {'scope':<10} {'medal':<7} {'-> Newbies-gate':<18} {'-> Middles-gate':<18}  {'GD spec':<10}")
    print("  " + "-" * 80)

    for scope_name, scope_df in scopes:
        recommendations[scope_name] = {}
        for medal in MEDALS:
            calib = calibrate(scope_df, medal)
            cross_n = find_crossing(calib, BOUNDARY_NEWBIES)
            cross_m = find_crossing(calib, BOUNDARY_MIDDLES)
            recommendations[scope_name][medal] = {"newbies": cross_n, "middles": cross_m}
            calib_with = calib.copy()
            calib_with["scope"] = scope_name
            calib_with["medal"] = medal
            all_rows.append(calib_with)
            spec_n, spec_m = GD_SPEC[medal]
            cross_n_str = f"{cross_n}" if cross_n is not None else "(not reached)"
            cross_m_str = f"{cross_m}" if cross_m is not None else "(not reached)"
            print(f"  {scope_name:<10} {medal:<7} {cross_n_str:<18} {cross_m_str:<18}  {spec_n}/{spec_m}")
        print()

    # CSV
    pd.concat(all_rows).to_csv(DATA_DIR / "maxwins-calibration.csv", index=False)
    print(f"Wrote {DATA_DIR / 'maxwins-calibration.csv'}")

    # Visualization 1: per-medal panels, all platforms overlaid (per-platform comparison)
    fig, axes = plt.subplots(1, 3, figsize=(16, 5), constrained_layout=True, sharey=True)
    fig.suptitle(
        f"FP-43625 MaxWins calibration: p{PERCENTILE} PCR of players with at least N podiums of given kind.\n"
        "Crossing PCR=100 (red) -> candidate Newbies gate.  "
        "Crossing PCR=1000 (red) -> candidate Middles gate.  "
        "Dashed orange: GD-spec thresholds (3/4/5 + 12/15/20).",
        fontsize=11,
    )
    colors = {"steam": "tab:blue", "ps": "tab:orange", "xb": "tab:green", "combined": "black"}
    for ax, medal in zip(axes, MEDALS):
        for scope_name, scope_df in scopes:
            calib = calibrate(scope_df, medal)
            if calib.empty:
                continue
            ls = "-" if scope_name == "combined" else "--"
            lw = 2.0 if scope_name == "combined" else 1.0
            ax.plot(calib["threshold"], calib["primary_pcr"],
                    color=colors[scope_name], linestyle=ls, linewidth=lw,
                    marker="o" if scope_name == "combined" else None,
                    markersize=4, label=scope_name)
        ax.axhline(BOUNDARY_NEWBIES, color="red", linestyle="--", linewidth=0.8, alpha=0.7,
                   label="PCR=100 (Newbies->Middles)")
        ax.axhline(BOUNDARY_MIDDLES, color="red", linestyle="--", linewidth=0.8, alpha=0.7,
                   label="PCR=1000 (Middles->Tops)")
        spec_n, spec_m = GD_SPEC[medal]
        ax.axvline(spec_n, color="orange", linestyle=":", linewidth=0.8, alpha=0.7)
        ax.axvline(spec_m, color="orange", linestyle=":", linewidth=0.8, alpha=0.7)
        ax.set_yscale("log")
        ax.set_xlabel("wins threshold N")
        ax.set_title(medal)
        ax.grid(True, alpha=0.3, which="both")
        if medal == "Gold":
            ax.set_ylabel(f"p{PERCENTILE} PCR of cohort with wins >= N (log)")
            ax.legend(fontsize=7, loc="lower right")
    out = DATA_DIR / "maxwins-calibration.png"
    fig.savefig(out, dpi=120)
    plt.close(fig)
    print(f"Wrote {out}")

    # Visualization 2: three medals overlaid on one chart per scope (medal comparison)
    fig, axes = plt.subplots(1, 4, figsize=(20, 5), constrained_layout=True, sharey=True)
    fig.suptitle(
        f"FP-43625 MaxWins calibration -- medal comparison (p{PERCENTILE} PCR vs wins threshold).\n"
        "How much harder is gold vs silver vs bronze at any given wins count?",
        fontsize=11,
    )
    for ax, (scope_name, scope_df) in zip(axes, scopes):
        for medal in MEDALS:
            calib = calibrate(scope_df, medal)
            if calib.empty:
                continue
            ax.plot(calib["threshold"], calib["primary_pcr"],
                    color=MEDAL_COLORS[medal], linewidth=2.0, marker="o", markersize=4,
                    label=medal)
        ax.axhline(BOUNDARY_NEWBIES, color="red", linestyle="--", linewidth=0.8, alpha=0.7)
        ax.axhline(BOUNDARY_MIDDLES, color="red", linestyle="--", linewidth=0.8, alpha=0.7)
        ax.set_yscale("log")
        ax.set_xlabel("wins threshold N")
        ax.set_title(scope_name)
        ax.grid(True, alpha=0.3, which="both")
        if scope_name == "combined":
            ax.set_ylabel(f"p{PERCENTILE} PCR of cohort with wins >= N (log)")
            ax.legend(fontsize=8, loc="lower right")
    out2 = DATA_DIR / "maxwins-calibration-by-medal.png"
    fig.savefig(out2, dpi=120)
    plt.close(fig)
    print(f"Wrote {out2}")

    # Cohort-size sanity: detail dump for combined
    print("\nCombined-platform cohort details (for the decisive thresholds):")
    for medal in MEDALS:
        calib = calibrate(combined, medal)
        rec_n = recommendations["combined"][medal]["newbies"]
        rec_m = recommendations["combined"][medal]["middles"]
        for label, threshold in [(f"Newbies-gate -> {rec_n}", rec_n),
                                 (f"Middles-gate -> {rec_m}", rec_m)]:
            if threshold is None:
                continue
            row = calib[calib["threshold"] == threshold].iloc[0]
            print(f"  {medal:<7} {label:<22} p{PERCENTILE}_PCR={row['primary_pcr']:>5}  "
                  f"(p25={row['p25_pcr']}, p50={row['p50_pcr']}, p75={row['p75_pcr']}, p90={row['p90_pcr']})  "
                  f"cohort={row['n_cohort']:>5,}")


if __name__ == "__main__":
    main()
