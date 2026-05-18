# FP-43625 calibration artifacts

Frozen snapshot of all calibration outputs (2026-05-17 / 2026-05-18 pass). The final recommendation is in `calibration-report.md`.

## What's here

### Reports (read these first)

- `calibration-report.md` -- final recommendation and methodology. Start here.
- `jsonvariables-research.md` -- background research on the JsonVariables overlay pattern (deploy mechanism for the gate config).

### Scripts (calibration pipeline)

Run order top-to-bottom. All scripts hard-code `DATA_DIR = D:/FishingPlanet/Docs/Reports/2026-05-17-rating-correlation` for both read (raw Q1 CSVs) and write (derived outputs).

1. `correlation-sql.sql` -- four prod queries (Q1 scatter, Q2 impact histogram, Q3 percentiles, Q4 top abusers). Run in DataGrip against each platform, save CSVs as `<platform>-q<n>-*.csv`.
2. `plot-correlation.py` -- render Q1 scatter as `hist2d` density (linear + log variants). Output: `correlation-fields-{linear,log}.png` and per-platform variants.
3. `fit-mmr.py` -- power-law fit `wins = a * PCR^b` per medal; recall check against FP-43631 cohort. **Exploratory, not used for the final recommendation.** Output: `mmr-fit-overlay.png`, `mmr-coefficients.csv`.
4. `calibrate-maxwins.py` -- per-medal-independent threshold calibration via `pX(PCR | wins >= N)`. **Exploratory**; doesn't account for OR-aggregation. Output: `maxwins-calibration.png`, `maxwins-calibration-by-medal.png`, `maxwins-calibration.csv`.
5. `or-gate-precision.py` -- OR-gate sanity check; print precision_LB for any given triple.
6. `bracket-distributions.py` -- per-bracket wins distribution stats; key sanity check that surfaced "Middles-promoted look identical to Tops by wins".
7. `joint-calibration.py` -- **Method A** (max F1 on FP-43631 cohort). Sweep of `(N_g, N_s, N_b)` triples with precision_LB / recall / F1. Source of the Newbies recommendation `4/3/6`. Output: `joint-calibration-{newbies,middles}.{png,csv}`.
8. `distribution-match-all.py` -- **Method B** (KS-distance to target bracket distribution). Source of the Middles recommendation `12/13/14`. Output: `cdf-{newbies,middles}.png`, `distribution-match-{newbies,middles}.csv`.

### Outputs (visualisations and computed CSVs)

PNGs:
- `correlation-fields-linear.png`, `correlation-fields-log.png` -- PCR vs wins density 3x3 grid (medals x platforms).
- `<platform>-correlation-{linear,log}.png` -- per-platform versions.
- `mmr-fit-overlay.png` -- power-law fit overlaid on hist2d (exploratory).
- `maxwins-calibration.png`, `maxwins-calibration-by-medal.png` -- per-medal-independent calibration (exploratory).
- `joint-calibration-newbies.png`, `joint-calibration-middles.png` -- Pareto fronts for Method A.
- `cdf-newbies.png`, `cdf-middles.png` -- CDF comparisons for Method B (target vs GD-spec vs recommended).

CSVs:
- `mmr-coefficients.csv` -- `(scope, medal, a, b, r_squared, fit_points, implied_PCR at thresholds)`.
- `maxwins-calibration.csv` -- per-medal-independent thresholds at various percentiles.
- `joint-calibration-{newbies,middles}.csv` -- full Method A sweep: every triple with precision_LB / recall / F1.
- `distribution-match-{newbies,middles}.csv` -- full Method B sweep: every triple with per-medal KS distances and aggregates.
- `{steam,ps,xb}-q2-impact.csv` -- Q2 prod query result per platform (small).

### Inputs (not stored in KB; too large)

Raw Q1 scatter CSVs (~50 MB total) live in `D:/FishingPlanet/Docs/Reports/2026-05-17-rating-correlation/`:
- `steam-q1-scatter.csv` (17 MB)
- `ps-q1-scatter.csv` (23 MB)
- `xb-q1-scatter.csv` (10 MB)

Format: `UserId, PCR, Gold, Silver, Bronze, CurrentBracket` -- one row per profile with any Competition history.

## Re-run procedure (monthly cadence)

1. Re-export Q1 via `correlation-sql.sql` against each platform's PROD MAIN. Save under `D:/FishingPlanet/Docs/Reports/<YYYY-MM-DD>-rating-correlation/` (date in folder name preserves history).
2. Update `DATA_DIR` at the top of each Python script to the new dated folder.
3. Run scripts in the order above. Outputs land in the new folder.
4. Copy PNG and computed CSV outputs back to this `artifacts/` directory, overwriting the snapshot (or commit a new dated subfolder, decide on KB-convention basis).
5. Re-read `calibration-report.md` -- if Method A peaks or Method B optima shifted, propose threshold updates to GD; push to `dbo.JsonVariables.Tournaments.GroupingDefault`.
