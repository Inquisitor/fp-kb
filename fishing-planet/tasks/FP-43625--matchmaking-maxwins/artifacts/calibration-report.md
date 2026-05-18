---
date: 2026-05-18
purpose: data-driven calibration of MaxWins / Max2nd / Max3rd thresholds for the FP-43625 promotion gate
data_source: Q1 scatter exports from STEAM/PS/XB PROD MAIN, 2026-05-17 snapshot (996,582 profiles with Competition history)
ground_truth: FP-43631 confirmed abuser cohort (200 UserIds across bans-2026-05-11 + bans-2026-05-18)
---

# FP-43625 MaxWins calibration report

## Why

GD-spec for the FP-43625 promotion gate is `(3 gold OR 4 silver OR 5 bronze)` for Newbies, `(12 gold OR 15 silver OR 20 bronze)` for Middles. These values came from designer intuition. This report measures their performance against actual prod data and proposes adjustments. The gate has not yet shipped; calibration is a one-shot empirical check before deployment plus a template for monthly re-runs after.

## Two methodologies, different brackets

The right calibration metric depends on what signal is reliable in each bracket.

### Method A: precision/recall against the FP-43631 cohort

For each candidate threshold triple, apply the OR-gate to the bracket population and compute:

- **Promoted** = count of players promoted by the gate.
- **TP** = how many of those are in the known abuser cohort (FP-43631).
- **Precision_LB** = `TP / Promoted`. Lower bound because the cohort is partial.
- **Recall** = `TP / (bracket suspects)`.
- **F1** = harmonic mean.

Maximise F1 (single number balancing both) to pick a triple.

### Method B: distribution matching against the target bracket

Apply the OR-gate, get the promoted cohort. For each medal, compute KS distance between the promoted-cohort wins distribution and the target bracket wins distribution. Aggregate via max() across medals. Minimise the aggregate.

Newbies-promoted target: **non-Newbies** wins distribution (Middles + Tops combined). The promoted players are leaving Newbies; their wins should resemble where they end up.

Middles-promoted target: **Tops** wins distribution. Middles-promoted move to Tops; their wins should look like Tops.

### Which method per bracket

| Bracket | Cohort precision_LB at best F1 | Cohort signal? | Method chosen |
|---|---:|---|---|
| **Newbies** | ~70% | Reliable | A (F1 on cohort) |
| **Middles** | ~12-16% | Unreliable | B (distribution match) |

In Newbies, having any wins at all is rare (median 0). The cohort (no-show abusers) heavily overlaps with the "high-wins-in-Newbies" subset; cohort precision is meaningful. Method A applies.

In Middles, having wins is normal (median 1, p90 = 4). The cohort under-samples Middles-style abuse — many in cohort are Newbies-tankers whose PCR drifted up since detection. Method A produces low and unstable precision values. Method B is more principled for the matchmaking-quality objective.

## Results -- Newbies bracket (method A: max F1 on FP-43631 cohort)

Sweep: `N_g in 1..10`, `N_s in 1..12`, `N_b in 1..15`. 1800 triples; 98 Pareto-optimal.

| Triple | Promoted | TP | Precision LB | Recall | F1 |
|---|---:|---:|---:|---:|---:|
| GD-spec **3 / 4 / 5** | 64 | 40 | 62.5% | 50.6% | 0.559 |
| Max F1 **4 / 3 / 6** | 61 | 42 | **68.9%** | **53.2%** | **0.600** |
| Max precision 6 / 3 / 7 | 52 | 37 | 71.2% | 46.8% | 0.565 |
| Max recall 1 / 1 / 1 | 9,904 | 72 | 0.7% | 91.1% | 0.014 |

Max-F1 triple `4 / 3 / 6` strictly dominates GD-spec — precision +6.4pp and recall +2.6pp simultaneously. Pattern: silver is "cheaper" than GD intuited (drop 4 to 3); gold and bronze are slightly more meaningful (raise 3 to 4 and 5 to 6).

## Results -- Middles bracket (method B: distribution match to Tops)

Sweep: `N_g in 3..20`, `N_s in 3..25`, `N_b in 3..30`. 11592 triples.

| Triple | Promoted | KS_gold | KS_silver | KS_bronze | KS_max | KS_mean |
|---|---:|---:|---:|---:|---:|---:|
| GD-spec **12 / 15 / 20** | 244 | 0.241 | 0.171 | 0.114 | 0.241 | 0.175 |
| Best by KS_max **13 / 13 / 14** | 284 | 0.152 | 0.151 | 0.146 | **0.152** | 0.150 |
| Best by KS_mean **12 / 13 / 14** | 302 | 0.159 | 0.131 | 0.112 | 0.159 | **0.134** |

GD-spec rank: #1156 by KS_max (top 10%), #718 by KS_mean (top 6.2%). Strong but not optimal.

The CDFs of Middles-promoted under `12 / 13 / 14` overlay the Tops CDFs almost perfectly across all three medals -- the 302 promoted players are statistically indistinguishable from Tops by wins distribution. GD-spec shifts the gold CDF too far right (its 244 promoted Middles have systematically higher gold counts than typical Tops).

## Key counter-intuitive finding

The Method A peak on Middles cohort (13 / 25 / 20) recommends **raising** silver to 25 -- effectively making the silver-gate strict to keep precision_LB up. Method B says the opposite: **lower** silver to 13 and bronze to 14, because real Tops have lower silver/bronze counts than GD-spec assumed.

The split arises because the cohort over-represents "high-silver/high-bronze long-playing Middles" (most no-show abusers accumulate medals over time). Method A treats them as honest false positives; Method B recognises they look like Tops and should be promoted.

For matchmaking quality (the stated FP-43625 goal), Method B is correct. For "catch known abusers at high confidence" goal, Method A would apply -- but on a cohort more representative of Middles abuse than FP-43631 currently provides.

## Recommended thresholds

```json
"Brackets": [
  { "BracketId": 1, "BracketName": "Newbies", "MinRating": 0,
    "MaxWins": 4, "Max2nd": 3, "Max3rd": 6 },
  { "BracketId": 2, "BracketName": "Middles", "MinRating": 101,
    "MaxWins": 12, "Max2nd": 13, "Max3rd": 14 },
  { "BracketId": 3, "BracketName": "Tops", "MinRating": 1001 }
]
```

Net change vs GD-spec:

| Bracket | Medal | GD-spec | Recommended | Delta |
|---|---|---:|---:|---:|
| Newbies | MaxWins (Gold) | 3 | **4** | +1 |
| Newbies | Max2nd (Silver) | 4 | **3** | -1 |
| Newbies | Max3rd (Bronze) | 5 | **6** | +1 |
| Middles | MaxWins (Gold) | 12 | **12** | 0 |
| Middles | Max2nd (Silver) | 15 | **13** | -2 |
| Middles | Max3rd (Bronze) | 20 | **14** | -6 |

Expected promotion rates (per platform-combined population):

- Newbies (191,381 players): 61 promoted under recommended (was 64 under GD-spec). Effectively same volume, better precision/recall.
- Middles (10,971 players): 302 promoted under recommended (was 244 under GD-spec). +24% more promotions; the extra are Tops-equivalent players that GD-spec was missing.

## Caveats

1. **Cohort is partial.** FP-43631 detection was calibrated at `NoShowSharePct >= 30%`. Less aggressive abusers and win-farmers without no-show signal are not in the cohort. Method A's precision_LB underestimates true precision in Newbies.
2. **Middles cohort sparse.** Only 85 of 200 suspects sit in Middles PCR range, mostly Newbies-style abusers whose PCR drifted up. Method A's metric is unstable in Middles; Method B addresses this.
3. **NULL PCR rows skipped.** 71-85% of profiles with Competition history have NULL CompetitionRating; excluded from analysis. Possible downstream data-pipeline issue; separate investigation needed.
4. **Newbies distribution-match target is dominated by Middles.** Method B applied to Newbies with target = non-Newbies recommends `(2 / 2 / 3)` -- too aggressive operationally because Middles itself has median 1 wins. Method A is used for Newbies instead, where cohort signal is reliable.
5. **Per-platform variation small.** Per-platform calibration within 1 of the combined recommendation. Single thresholds for all platforms remain appropriate.

## Re-calibration cadence

Monthly. Re-run the calibration scripts on a fresh Q1 dump. Push updated thresholds to `dbo.JsonVariables` (`Tournaments.GroupingDefault`). No code change, no deploy. Metagame shifts (new content, season transitions, player progression) drift the optimum over time.

## Calibration artifacts

Under `<kb>/fishing-planet/tasks/FP-43625--matchmaking-maxwins/artifacts/`:

- `calibrate-maxwins.py` -- per-medal-independent calibration (educational, NOT the basis for final recommendation; analyses each medal in isolation without OR-aggregation).
- `or-gate-precision.py` -- OR-gate sanity check; computes promoted-count and precision_LB for any given threshold triple.
- `joint-calibration.py` -- Method A: joint sweep with precision_LB / recall / F1 on FP-43631 cohort. Source of the Newbies recommendation.
- `distribution-match-all.py` -- Method B: KS-distance sweep against target bracket distribution. Source of the Middles recommendation.
- `bracket-distributions.py` -- exploratory; per-bracket wins statistics, including the comparison of Middles-promoted vs Tops distributions.
- `plot-correlation.py`, `fit-mmr.py` -- exploratory visualisations; not used for the final recommendation.

Plot outputs (under the prod-reports directory):

- `joint-calibration-newbies.png`, `joint-calibration-middles.png` -- Pareto fronts for Method A.
- `cdf-newbies.png`, `cdf-middles.png` -- CDF comparisons for Method B (target vs GD-spec vs recommended).

Input data: `<reports>/2026-05-17-rating-correlation/<platform>-q1-scatter.csv`. Re-run requires a fresh Q1 dump from each platform's prod read-replica (`correlation-sql.sql` Q1).
