"""
FP-43625 -- compare wins distributions across Newbies/Middles/Tops brackets.

Answers: do high-wins Middles look statistically like Tops, or like long-played
honest Middles, or both?
"""

from pathlib import Path
import numpy as np
import pandas as pd

DATA_DIR = Path(r"D:/FishingPlanet/Docs/Reports/2026-05-17-rating-correlation")
PLATFORMS = [("steam", "Steam/EGS"), ("ps", "PlayStation"), ("xb", "Xbox")]


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


def main():
    df = load_combined()
    for medal in ("Gold", "Silver", "Bronze"):
        print(f"\n=== {medal} count distribution by bracket ===")
        print(f"  {'bracket':<8} {'n':>8} {'mean':>6} {'p50':>4} {'p75':>4} {'p90':>4} {'p95':>4} {'p99':>4} {'max':>4}")
        for bracket in ("Newbies", "Middles", "Tops"):
            sub = df[df["bracket"] == bracket][medal]
            print(f"  {bracket:<8} {len(sub):>8,} "
                  f"{sub.mean():>6.2f} {int(sub.quantile(.50)):>4} "
                  f"{int(sub.quantile(.75)):>4} {int(sub.quantile(.90)):>4} "
                  f"{int(sub.quantile(.95)):>4} {int(sub.quantile(.99)):>4} "
                  f"{int(sub.max()):>4}")

    print("\n=== Cross-distribution: Middles-promoted-by-GD vs Tops baseline ===")
    middles = df[df["bracket"] == "Middles"]
    tops    = df[df["bracket"] == "Tops"]
    print(f"  Population: Middles={len(middles):,}, Tops={len(tops):,}")
    print(f"\n  Tops baseline (all Tops):")
    for medal in ("Gold", "Silver", "Bronze"):
        s = tops[medal]
        print(f"    {medal:<7} mean={s.mean():>6.2f}  p50={int(s.quantile(.50))}  "
              f"p90={int(s.quantile(.90))}  p99={int(s.quantile(.99))}")

    print(f"\n  Middles who trip GD-spec gate (12 gold OR 15 silver OR 20 bronze):")
    promoted = middles[(middles["Gold"] >= 12) | (middles["Silver"] >= 15) | (middles["Bronze"] >= 20)]
    print(f"    n = {len(promoted):,}")
    for medal in ("Gold", "Silver", "Bronze"):
        s = promoted[medal]
        if len(s) > 0:
            print(f"    {medal:<7} mean={s.mean():>6.2f}  p50={int(s.quantile(.50))}  "
                  f"p90={int(s.quantile(.90))}  p99={int(s.quantile(.99))}")

    print(f"\n  Side-by-side medians:")
    for medal in ("Gold", "Silver", "Bronze"):
        m_med = promoted[medal].median() if len(promoted) > 0 else 0
        t_med = tops[medal].median()
        print(f"    {medal:<7}  Middles-promoted={int(m_med):>3}  Tops={int(t_med):>3}  "
              f"ratio={m_med / max(t_med, 1):.2f}x")


if __name__ == "__main__":
    main()
