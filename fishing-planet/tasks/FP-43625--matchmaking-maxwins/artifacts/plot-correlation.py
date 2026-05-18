"""
FP-43625 -- build correlation fields (PCR vs lifetime podium counts) from Q1 CSVs.

Input:  D:/FishingPlanet/Docs/Reports/2026-05-17-rating-correlation/<platform>-q1-scatter.csv
Output: <same dir>/correlation-fields-<variant>.png      -- 3x3 grid
        <same dir>/<platform>-correlation-<variant>.png  -- 1x3 per platform

Variants:
  - linear: linear X axis clipped to PCR <= 5000, linear Y clipped to <= 60.
            Tight bins (PCR step 25, Y step 1) so hex/cell shapes are crisp,
            not blurry. Best for reading "how the cloud sits near brackets
            and thresholds".
  - log:    log X axis (PCR>=1 filter), linear Y full range. Spans
            multi-order-of-magnitude PCR (0..10000+) in one frame.

Plot style: hist2d with LogNorm color (cell density log-scaled).
Bracket boundaries marked at PCR=100 and PCR=1001 (vertical dashed red).
GD-spec thresholds marked as horizontal dashed orange lines per medal:
    Gold:   3 (Newbies gate), 12 (Middles gate)
    Silver: 4 (Newbies gate), 15 (Middles gate)
    Bronze: 5 (Newbies gate), 20 (Middles gate)
"""

import sys
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


def load_platform(key: str) -> pd.DataFrame:
    path = DATA_DIR / f"{key}-q1-scatter.csv"
    df = pd.read_csv(path, dtype={"UserId": str, "PCR": "Int32",
                                  "Gold": "Int32", "Silver": "Int32", "Bronze": "Int32",
                                  "CurrentBracket": "category"})
    total = len(df)
    null_pcr = df["PCR"].isna().sum()
    print(f"  {key:<6} -- {total:>8,} rows, {null_pcr:,} NULL PCR ({null_pcr/total:.1%})")
    return df


def plot_linear(ax, df, medal_col, thresholds, title):
    sub = df.dropna(subset=["PCR"])
    x = sub["PCR"].to_numpy()
    y = sub[medal_col].to_numpy()
    if len(x) == 0:
        ax.text(0.5, 0.5, "no data", ha="center", va="center",
                transform=ax.transAxes); return None

    x_bins = np.linspace(0, 5000, 201)   # PCR step 25
    y_bins = np.arange(0, 62)             # integer Y bins 0..60
    _, _, _, im = ax.hist2d(x, y, bins=[x_bins, y_bins], cmap="viridis",
                            norm=LogNorm(vmin=1), cmin=1)

    for b in BRACKET_BOUNDARIES:
        ax.axvline(b, color="red", linestyle="--", linewidth=0.8, alpha=0.8)
    for t in thresholds:
        ax.axhline(t, color="orange", linestyle=":", linewidth=1.0, alpha=0.9)

    ax.set_xlim(0, 5000)
    ax.set_ylim(0, 60)
    ax.set_title(title, fontsize=10)
    ax.set_xlabel("CompetitionRating (PCR)", fontsize=8)
    ax.set_ylabel(medal_col, fontsize=8)
    ax.grid(True, alpha=0.2)
    return im


def plot_log(ax, df, medal_col, thresholds, x_max, y_max, title):
    sub = df.dropna(subset=["PCR"])
    # log X requires positive values -- shift PCR=0 to PCR=1 so the
    # zero-rating cohort stays visible at the left edge of the log axis.
    pcr = sub["PCR"].to_numpy().astype(float)
    pcr[pcr <= 0] = 1.0
    # same shift on Y: counter=0 -> 1 so the (massive) zero-podium cohort
    # stays visible at the bottom of the log Y axis.
    y = sub[medal_col].to_numpy().astype(float)
    y[y <= 0] = 1.0
    if len(pcr) == 0:
        ax.text(0.5, 0.5, "no data", ha="center", va="center",
                transform=ax.transAxes); return None

    x_bins = np.logspace(0, np.log10(x_max), 80)
    y_bins = np.logspace(0, np.log10(max(y_max, 2)), 40)
    _, _, _, im = ax.hist2d(pcr, y, bins=[x_bins, y_bins], cmap="viridis",
                            norm=LogNorm(vmin=1), cmin=1)

    for b in BRACKET_BOUNDARIES:
        ax.axvline(b, color="red", linestyle="--", linewidth=0.8, alpha=0.8)
    for t in thresholds:
        ax.axhline(t, color="orange", linestyle=":", linewidth=1.0, alpha=0.9)

    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlim(1, x_max)
    ax.set_ylim(1, max(y_max, 2))
    ax.set_title(title, fontsize=10)
    ax.set_xlabel("CompetitionRating (PCR), log; PCR=0 mapped to 1", fontsize=8)
    ax.set_ylabel(f"{medal_col}, log; 0 mapped to 1", fontsize=8)
    ax.grid(True, alpha=0.2, which="both")
    return im


def render_variant(data, variant_name):
    if variant_name == "linear":
        plot_fn = plot_linear
        fn_kwargs = lambda medal_col, thr: dict()
        suptitle_suffix = ("linear axes, PCR clipped to 5000, Y clipped to 60.  "
                           "Bins: PCR=25 wide, Y=1 wide.")
    else:
        # global Y cap = max counter across all platforms; ensures one common range
        y_max = int(max(df[m[0]].max() for df in data.values() for m in MEDALS))
        x_max = float(max(df["PCR"].dropna().max() for df in data.values())) * 1.05
        plot_fn = plot_log
        fn_kwargs = lambda medal_col, thr: dict(x_max=x_max, y_max=y_max)
        suptitle_suffix = (f"X log scale (PCR=0 -> 1), Y linear full range "
                           f"(up to {y_max}).")

    # combined 3x3
    fig, axes = plt.subplots(3, 3, figsize=(16, 12), constrained_layout=True)
    fig.suptitle(
        f"FP-43625 correlation fields ({variant_name}): PCR vs lifetime podium counts\n"
        f"{suptitle_suffix}  Vertical red = brackets (100, 1001).  "
        f"Horizontal orange = GD-spec thresholds.  Color = log density.",
        fontsize=11,
    )
    last_im = None
    for col, (key, label) in enumerate(PLATFORMS):
        df = data[key]
        for row, (medal, thr) in enumerate(MEDALS):
            ax = axes[row, col]
            im = plot_fn(ax, df, medal, thr, title=f"{label} -- {medal}",
                         **fn_kwargs(medal, thr))
            if im is not None:
                last_im = im
    if last_im is not None:
        fig.colorbar(last_im, ax=axes.ravel().tolist(),
                     label="users per cell (log)", shrink=0.6)
    out = DATA_DIR / f"correlation-fields-{variant_name}.png"
    fig.savefig(out, dpi=120)
    plt.close(fig)
    print(f"  wrote {out.name}")

    # per-platform 1x3
    for key, label in PLATFORMS:
        df = data[key]
        fig, axes = plt.subplots(1, 3, figsize=(15, 4.5), constrained_layout=True)
        fig.suptitle(f"FP-43625 correlation field ({variant_name}) -- {label}", fontsize=11)
        last_im = None
        for col, (medal, thr) in enumerate(MEDALS):
            im = plot_fn(axes[col], df, medal, thr, title=medal,
                         **fn_kwargs(medal, thr))
            if im is not None:
                last_im = im
        if last_im is not None:
            fig.colorbar(last_im, ax=axes.ravel().tolist(),
                         label="users per cell (log)", shrink=0.7)
        out = DATA_DIR / f"{key}-correlation-{variant_name}.png"
        fig.savefig(out, dpi=120)
        plt.close(fig)
        print(f"  wrote {out.name}")


def main():
    print("Loading CSVs:")
    data = {key: load_platform(key) for key, _ in PLATFORMS}
    for variant in ("linear", "log"):
        print(f"\nRendering {variant} variant:")
        render_variant(data, variant)


if __name__ == "__main__":
    main()
