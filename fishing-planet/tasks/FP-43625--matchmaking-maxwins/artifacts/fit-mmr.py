"""
FP-43625 -- fit MMR formula from correlation data.

Input:  D:/FishingPlanet/Docs/Reports/2026-05-17-rating-correlation/<platform>-q1-scatter.csv
Output: <same dir>/mmr-fit-<variant>.png   -- overlay: hist2d + median curve + power-law fit
        <same dir>/mmr-coefficients.csv    -- per (platform, medal) fit params
        stdout: table of coefficients and implied-PCR predictions for GD thresholds

Methodology
-----------
1. For each (platform, medal): bin players by PCR via quantiles (qcut), compute
   the median wins per bin. This produces a "typical profile" curve robust to
   outliers (sandbaggers do NOT shift the median).
2. Fit a power law wins = a * PCR^b via log-log linear regression on the
   medians (not the raw scatter). Report R2 as fit quality.
3. Invert: implied_PCR(wins) = (wins / a) ** (1 / b). For an honest player,
   implied_PCR(actual_wins) ~ actual_PCR. Sandbaggers have
   implied_PCR(actual_wins) >> actual_PCR -- this is the abuse signal.
4. Also compute a combined fit (all three platforms stacked) for production
   use -- a single set of coefficients shipped in the JsonVariable.

A power-law (linear in log-log) is the natural model when both PCR and
podium counts are unbounded above and bounded below at 0. If R2 is low, the
power law is inadequate and we should fall back to quantile mapping
(non-parametric lookup table).
"""

from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm
import numpy as np
import pandas as pd

DATA_DIR = Path(r"D:/FishingPlanet/Docs/Reports/2026-05-17-rating-correlation")

PLATFORMS = [
    ("steam", "Steam/EGS"),
    ("ps",    "PlayStation"),
    ("xb",    "Xbox"),
]
MEDALS = [
    ("Gold",   [3,  12]),
    ("Silver", [4,  15]),
    ("Bronze", [5,  20]),
]
BRACKET_BOUNDARIES = [100, 1001]
N_QUANTILE_BINS = 25


def load_platform(key: str) -> pd.DataFrame:
    df = pd.read_csv(DATA_DIR / f"{key}-q1-scatter.csv",
                     dtype={"UserId": str, "PCR": "Int32",
                            "Gold": "Int32", "Silver": "Int32", "Bronze": "Int32",
                            "CurrentBracket": "category"})
    df["platform"] = key
    return df


def medians_by_pcr(df: pd.DataFrame, medal_col: str, n_bins=N_QUANTILE_BINS):
    """Equal-count PCR quantile binning; medians per bin."""
    sub = df[df["PCR"].fillna(-1) > 0].copy()
    if len(sub) < n_bins * 5:
        return pd.DataFrame(columns=["pcr_median", "win_median", "count"])
    bins = pd.qcut(sub["PCR"], n_bins, duplicates="drop")
    g = sub.groupby(bins, observed=True)
    return pd.DataFrame({
        "pcr_median": g["PCR"].median().astype(float),
        "win_median": g[medal_col].median().astype(float),
        "count":      g.size(),
    }).reset_index(drop=True)


def fit_power_law(pcr, wins):
    """wins = a * PCR^b  =>  log(wins) = log(a) + b*log(PCR).
    Returns (a, b, r_squared) on log-log linear regression. Drops zero-wins
    points (log undefined). None if too few non-zero points."""
    pcr = np.asarray(pcr, dtype=float)
    wins = np.asarray(wins, dtype=float)
    mask = (pcr > 0) & (wins > 0)
    if mask.sum() < 3:
        return None
    lp = np.log(pcr[mask])
    lw = np.log(wins[mask])
    b, log_a = np.polyfit(lp, lw, 1)
    pred = log_a + b * lp
    ss_res = ((lw - pred) ** 2).sum()
    ss_tot = ((lw - lw.mean()) ** 2).sum()
    r2 = 1 - ss_res / ss_tot if ss_tot > 0 else float("nan")
    return float(np.exp(log_a)), float(b), float(r2), int(mask.sum())


def implied_pcr(wins, a, b):
    """Inverse of wins = a * PCR^b."""
    if wins <= 0 or a is None or b is None or b == 0:
        return 0.0
    return (wins / a) ** (1.0 / b)


def compute_mmr(pcr: float, gold: int, silver: int, bronze: int, fits: dict) -> float:
    """Combine raw PCR with wins-implied PCR into a single effective rating.

    Formula: max(PCR, median(implied_PCR_gold, implied_PCR_silver, implied_PCR_bronze))

    Median of the three implied-PCRs requires at least 2 of 3 medal signals
    to agree before the player is promoted -- single-medal anomalies (e.g.
    a player who specialises in 1st-place pushes but never lands silver
    or bronze) do not trigger promotion. PCR-floor preserved: a Tops
    player with low medal counts keeps Tops via max(pcr, ...).
    """
    counts = {"Gold": gold, "Silver": silver, "Bronze": bronze}
    implied = [implied_pcr(counts[m], a, b)
               for m, (a, b, _r2, _n) in fits.items() if (a, b) != (None, None)]
    if not implied:
        return float(pcr)
    return max(float(pcr), float(np.median(implied)))


def load_suspect_userids(paths) -> set[str]:
    """Extract UserIds (case-insensitive) from FP-43631 ban-list markdown files."""
    import re
    pat = re.compile(r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}")
    ids = set()
    for path in paths:
        text = Path(path).read_text(encoding="utf-8")
        for m in pat.findall(text):
            ids.add(m.upper())
    return ids


def recall_check(combined: pd.DataFrame, fits_combined: dict, suspects: set[str]) -> None:
    """Apply MMR formula to suspect UserIds; report promotion stats."""
    combined = combined.copy()
    combined["UserId_upper"] = combined["UserId"].str.upper()
    suspect_rows = combined[combined["UserId_upper"].isin(suspects)].drop_duplicates("UserId_upper")
    n_suspects_in_data = len(suspect_rows)
    print(f"\nRecall check against FP-43631 cohort ({len(suspects)} UserIds across ban files):")
    print(f"  matched in Q1 data: {n_suspects_in_data}")
    if n_suspects_in_data == 0:
        return

    def classify(pcr, mmr):
        b_pcr = ("Newbies" if pcr <= 100 else "Middles" if pcr <= 1000 else "Tops") if pd.notna(pcr) else "(null PCR)"
        b_mmr = "Newbies" if mmr <= 100 else "Middles" if mmr <= 1000 else "Tops"
        return b_pcr, b_mmr

    # Discrete MaxWins gate (current FP-43625 plan)
    GATES = {
        "Newbies": (3, 4, 5),    # gold, silver, bronze
        "Middles": (12, 15, 20),
    }
    def discrete_gate_promotes(pcr, g, s, b):
        if pd.isna(pcr): return False
        if pcr <= 100:
            return g >= 3 or s >= 4 or b >= 5
        if pcr <= 1000:
            return g >= 12 or s >= 15 or b >= 20
        return False  # Tops has no gate

    mmr_breakdown = {"Newbies->Middles": 0, "Newbies->Tops": 0, "Middles->Tops": 0,
                     "already Tops": 0, "still Newbies": 0, "still Middles": 0,
                     "(null PCR)": 0}
    discrete_breakdown = {"promoted Newbies": 0, "promoted Middles": 0,
                          "Tops (no gate)": 0, "missed Newbies": 0, "missed Middles": 0,
                          "(null PCR)": 0}

    for _, row in suspect_rows.iterrows():
        pcr = row["PCR"]
        g = int(row["Gold"] or 0)
        s = int(row["Silver"] or 0)
        bz = int(row["Bronze"] or 0)
        pcr_val = float(pcr) if pd.notna(pcr) else 0.0

        # MMR formula path
        mmr = compute_mmr(pcr_val, g, s, bz, fits_combined)
        b_pcr_str = "(null PCR)" if pd.isna(pcr) else ("Newbies" if pcr <= 100 else "Middles" if pcr <= 1000 else "Tops")
        b_mmr_str = "Newbies" if mmr <= 100 else "Middles" if mmr <= 1000 else "Tops"
        if b_pcr_str == "(null PCR)":
            mmr_breakdown["(null PCR)"] += 1
        elif b_pcr_str == b_mmr_str:
            if b_pcr_str == "Tops":
                mmr_breakdown["already Tops"] += 1
            else:
                mmr_breakdown[f"still {b_pcr_str}"] += 1
        else:
            mmr_breakdown[f"{b_pcr_str}->{b_mmr_str}"] += 1

        # Discrete gate path
        if pd.isna(pcr):
            discrete_breakdown["(null PCR)"] += 1
        elif pcr > 1000:
            discrete_breakdown["Tops (no gate)"] += 1
        elif discrete_gate_promotes(pcr, g, s, bz):
            discrete_breakdown[f"promoted {b_pcr_str}"] += 1
        else:
            discrete_breakdown[f"missed {b_pcr_str}"] += 1

    print(f"\n  MMR formula recall (median(implied_PCR), max with raw PCR):")
    for k, v in mmr_breakdown.items():
        if v > 0:
            print(f"    {k:<22} {v:>4}  ({v / n_suspects_in_data:.1%})")
    promoted_mmr = sum(v for k, v in mmr_breakdown.items()
                       if "->" in k)
    print(f"  -> total bracket-shifted: {promoted_mmr} / {n_suspects_in_data} "
          f"= {promoted_mmr / n_suspects_in_data:.1%}")

    print(f"\n  Discrete MaxWins gate (FP-43625 plan, 3/4/5 + 12/15/20):")
    for k, v in discrete_breakdown.items():
        if v > 0:
            print(f"    {k:<22} {v:>4}  ({v / n_suspects_in_data:.1%})")
    promoted_disc = sum(v for k, v in discrete_breakdown.items()
                        if k.startswith("promoted "))
    print(f"  -> total promoted (Newbies+Middles): {promoted_disc} / {n_suspects_in_data} "
          f"= {promoted_disc / n_suspects_in_data:.1%}")


def plot_overlay(ax, df, medal_col, thresholds, fit_combined, fit_platform, x_max, y_max, title):
    sub = df.dropna(subset=["PCR"]).copy()
    pcr = sub["PCR"].to_numpy(dtype=float)
    pcr[pcr <= 0] = 1.0
    y = sub[medal_col].to_numpy(dtype=float)
    y[y <= 0] = 1.0

    x_bins = np.logspace(0, np.log10(x_max), 80)
    y_bins = np.logspace(0, np.log10(max(y_max, 2)), 40)
    _, _, _, im = ax.hist2d(pcr, y, bins=[x_bins, y_bins], cmap="viridis",
                            norm=LogNorm(vmin=1), cmin=1)

    # bracket and threshold reference lines
    for b in BRACKET_BOUNDARIES:
        ax.axvline(b, color="red", linestyle="--", linewidth=0.8, alpha=0.7)
    for t in thresholds:
        ax.axhline(t, color="orange", linestyle=":", linewidth=0.9, alpha=0.8)

    # median curve (white dots)
    med = medians_by_pcr(df, medal_col)
    if not med.empty:
        ax.plot(med["pcr_median"].clip(lower=1),
                med["win_median"].clip(lower=1),
                "o", color="white", markersize=4, alpha=0.9,
                markeredgecolor="black", markeredgewidth=0.5,
                label="median wins per PCR bin")

    # platform-specific fit (cyan dashed)
    if fit_platform is not None:
        a, b, r2, n = fit_platform
        xs = np.logspace(0, np.log10(x_max), 100)
        ys = a * xs**b
        ax.plot(xs, np.clip(ys, 1, y_max), "--", color="cyan", linewidth=1.5,
                label=f"platform fit: wins = {a:.3g} * PCR^{b:.3f}  (R2={r2:.2f})")

    # combined fit (magenta solid) for reference -- the production candidate
    if fit_combined is not None:
        a, b, r2, n = fit_combined
        xs = np.logspace(0, np.log10(x_max), 100)
        ys = a * xs**b
        ax.plot(xs, np.clip(ys, 1, y_max), "-", color="magenta", linewidth=1.2,
                alpha=0.8,
                label=f"combined fit: wins = {a:.3g} * PCR^{b:.3f}  (R2={r2:.2f})")

    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlim(1, x_max)
    ax.set_ylim(1, max(y_max, 2))
    ax.set_title(title, fontsize=10)
    ax.set_xlabel("CompetitionRating (PCR), log; 0->1", fontsize=8)
    ax.set_ylabel(f"{medal_col}, log; 0->1", fontsize=8)
    ax.grid(True, alpha=0.2, which="both")
    ax.legend(loc="upper left", fontsize=7, framealpha=0.85)
    return im


def main():
    print("Loading CSVs:")
    data = {key: load_platform(key) for key, _ in PLATFORMS}
    for k, df in data.items():
        print(f"  {k:<6} -- {len(df):>8,} rows")
    combined = pd.concat(data.values(), ignore_index=True)
    print(f"  combined -- {len(combined):>8,} rows\n")

    # axis ranges
    x_max = float(combined["PCR"].dropna().max()) * 1.05
    y_max = int(combined[[m[0] for m in MEDALS]].max().max())

    # fit per (platform, medal) and combined
    fits = {key: {} for key, _ in PLATFORMS}
    fits["combined"] = {}
    print("Power-law fits  (wins = a * PCR^b on raw rows where wins > 0 AND PCR > 0):\n")
    print(f"  {'scope':<10} {'medal':<7} {'a':>10} {'b':>8} {'R2':>6} {'pts':>5}   implied_PCR for...")
    print(f"  {'':10} {'':7} {'':10} {'':8} {'':6} {'':5}   newbies-thr | middles-thr")
    print("  " + "-" * 90)

    for medal, thr in MEDALS:
        # combined fit on raw (PCR, wins) over wins > 0
        fit_c = fit_power_law(combined["PCR"].fillna(-1), combined[medal])
        fits["combined"][medal] = fit_c
        if fit_c:
            a, b, r2, n = fit_c
            ip_n = implied_pcr(thr[0], a, b)
            ip_m = implied_pcr(thr[1], a, b)
            print(f"  {'combined':<10} {medal:<7} {a:>10.4g} {b:>8.4f} {r2:>6.3f} {n:>5}   "
                  f"{thr[0]}g -> PCR {ip_n:>7.0f} | {thr[1]}g -> PCR {ip_m:>7.0f}")

        # per platform
        for key, label in PLATFORMS:
            df = data[key]
            fit_p = fit_power_law(df["PCR"].fillna(-1), df[medal])
            fits[key][medal] = fit_p
            if fit_p:
                a, b, r2, n = fit_p
                ip_n = implied_pcr(thr[0], a, b)
                ip_m = implied_pcr(thr[1], a, b)
                print(f"  {key:<10} {medal:<7} {a:>10.4g} {b:>8.4f} {r2:>6.3f} {n:>5}   "
                      f"{thr[0]}g -> PCR {ip_n:>7.0f} | {thr[1]}g -> PCR {ip_m:>7.0f}")
        print()

    # save coefficients
    rows = []
    for scope_key in ["combined"] + [k for k, _ in PLATFORMS]:
        for medal, thr in MEDALS:
            f = fits[scope_key][medal] if medal in fits[scope_key] else None
            if f:
                a, b, r2, n = f
                rows.append({"scope": scope_key, "medal": medal,
                             "a": a, "b": b, "r_squared": r2, "fit_points": n,
                             "implied_PCR_newbies_thr":
                                 implied_pcr(thr[0], a, b),
                             "implied_PCR_middles_thr":
                                 implied_pcr(thr[1], a, b)})
    pd.DataFrame(rows).to_csv(DATA_DIR / "mmr-coefficients.csv", index=False)
    print(f"\nWrote {DATA_DIR / 'mmr-coefficients.csv'}")

    # overlay plot: 3x3 (medals x platforms)
    fig, axes = plt.subplots(3, 3, figsize=(16, 12), constrained_layout=True)
    fig.suptitle(
        "FP-43625 MMR fits: PCR vs lifetime podium counts (log-log)\n"
        "White dots = median wins per PCR bin.  "
        "Cyan dashed = platform power-law fit.  "
        "Magenta = combined fit (all platforms).  "
        "Red = bracket boundaries.  Orange = GD thresholds.",
        fontsize=11,
    )
    last_im = None
    for col, (key, label) in enumerate(PLATFORMS):
        df = data[key]
        for row, (medal, thr) in enumerate(MEDALS):
            ax = axes[row, col]
            im = plot_overlay(ax, df, medal, thr,
                              fits["combined"][medal], fits[key][medal],
                              x_max, y_max, f"{label} -- {medal}")
            if im is not None:
                last_im = im
    if last_im is not None:
        fig.colorbar(last_im, ax=axes.ravel().tolist(),
                     label="users per cell (log)", shrink=0.6)
    out = DATA_DIR / "mmr-fit-overlay.png"
    fig.savefig(out, dpi=120)
    plt.close(fig)
    print(f"Wrote {out}")

    # recall check against FP-43631 cohort
    bans_dir = Path(r"D:/kb/fishing-planet/tasks/FP-43631--rating-drop-abuse-detection/artifacts")
    suspects = load_suspect_userids([
        bans_dir / "bans-2026-05-11.md",
        bans_dir / "bans-2026-05-18.md",
    ])
    recall_check(combined, fits["combined"], suspects)
    precision_check(data, combined, fits["combined"], suspects)


def vectorized_mmr(df: pd.DataFrame, fits: dict) -> np.ndarray:
    """Vectorised MMR = max(PCR, median(implied_PCR_gold, _silver, _bronze))."""
    pcr = df["PCR"].astype(float).fillna(0.0).to_numpy()
    g = df["Gold"].astype(float).fillna(0).to_numpy()
    s = df["Silver"].astype(float).fillna(0).to_numpy()
    b = df["Bronze"].astype(float).fillna(0).to_numpy()

    def implied_vec(wins, fit):
        if fit is None: return np.zeros_like(wins)
        a, bp, _, _ = fit
        return np.where(wins > 0, (wins / a) ** (1.0 / bp), 0.0)

    ipg = implied_vec(g, fits["Gold"])
    ips = implied_vec(s, fits["Silver"])
    ipb = implied_vec(b, fits["Bronze"])
    med = np.median(np.stack([ipg, ips, ipb], axis=1), axis=1)
    return np.maximum(pcr, med)


def precision_check(data: dict, combined: pd.DataFrame, fits: dict, suspects: set[str]) -> None:
    """Apply MMR to the full population per platform; report confusion matrix and
    lower-bound precision against the known FP-43631 cohort."""
    print(f"\nPrecision check on full population (per platform):")
    print(f"  Lower-bound precision = (overlap with FP-43631 cohort) / (total promoted).")
    print(f"  Actual precision is higher -- the cohort is partial; the rest of 'promoted not in")
    print(f"  cohort' splits between undiscovered abusers and true false positives, unknown ratio.\n")

    def bracket(pcr_or_mmr):
        if pcr_or_mmr <= 100:  return "Newbies"
        if pcr_or_mmr <= 1000: return "Middles"
        return "Tops"

    overall_tp = 0
    overall_promoted = 0
    for key, label in PLATFORMS:
        df = data[key].dropna(subset=["PCR"]).copy()
        df["UserId_upper"] = df["UserId"].str.upper()
        df["MMR"] = vectorized_mmr(df, fits)
        df["bracket_pcr"] = df["PCR"].apply(bracket)
        df["bracket_mmr"] = df["MMR"].apply(bracket)
        df["is_suspect"] = df["UserId_upper"].isin(suspects)
        df["promoted"] = df["bracket_pcr"] != df["bracket_mmr"]

        print(f"  {label}  ({len(df):,} rows with non-NULL PCR)")
        for src in ("Newbies", "Middles"):
            src_rows = df[df["bracket_pcr"] == src]
            if len(src_rows) == 0:
                continue
            promoted = src_rows[src_rows["promoted"]]
            tp = int(promoted["is_suspect"].sum())
            total_promoted = len(promoted)
            base_total = len(src_rows)
            promoted_pct = total_promoted / base_total if base_total else 0
            precision_lb = tp / total_promoted if total_promoted else 0
            print(f"    {src:<8} total={base_total:>7,}  promoted={total_promoted:>5}  "
                  f"({promoted_pct:.2%} of bracket)  TP={tp:>3}  precision_LB={precision_lb:.1%}")
            overall_promoted += total_promoted
            overall_tp += tp
        print()

    if overall_promoted:
        print(f"  COMBINED: {overall_tp} TP / {overall_promoted} promoted "
              f"= {overall_tp / overall_promoted:.1%} precision lower bound")


if __name__ == "__main__":
    main()
