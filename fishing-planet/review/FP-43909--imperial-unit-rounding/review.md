---
status: resolved
executor: Yuriy Burda
branch: MFT @ r16110
jira: https://fishingplanet.atlassian.net/browse/FP-43909
---

# Review: FP-43909 — [FTUE][DailyMissions][Server] Error converting centimeters to inches

## Summary

Daily-mission task text shows a whole-number imperial threshold ("Catch fish less than 20 inch") derived from a metric condition (50 cm). 20 inch = 50.8 cm, not 50 cm, so the imperial copy misrepresents the real condition: a fish at 19.8″ (= 50.3 cm > 50 cm) appears to satisfy "less than 20 inch" while failing the actual 50 cm check. Reporter saw ~0.32″ of false tolerance.

Requested fix (Mary Key): round imperial units to tenths instead of whole numbers when generating task text, and round directionally per the condition — `less` rounds down, `more` rounds up.

## Scope

- **MFT r16110** — Imperial unit rounding in daily mission task text
  - `TaskLocalizer.cs`: replaced `Weight(value)`/`Length(value)` (nearest rounding) with direction-aware `Weight(value, RoundDirection)` / `Length(value, RoundDirection)`; added `RoundDirection` enum and `RoundDirectional` helper (scale → Floor/Ceiling → unscale)
  - Length precision: Imperial now 1 decimal (was whole), Metric 0 decimals (whole cm); Weight stays 3 decimals
  - Direction wiring: lower bounds (`More`, range min, `MaxLoad`) round Up; upper bounds (`Less`, range max) round Down
  - `MeasuringSystemManager.cs`: exposed `CurrentMeasuringSystem` getter (drives the Imperial/Metric decimals choice)
  - Tests: imperial/metric × length/weight × less/more/range/maxload, with hand-checked expected values

## Verdict

**Approve.** The fix is correct, directly resolves the reported complaint ("less than 20 inch" → "less than 19.6 inch"), and is backed by thorough tests with mathematically verified expectations. All findings are Info/Low, resolved Accepted (card-only) — F-1 (cross-branch propagation) resolved via assignee confirmation that 2026.4 ships from the Code/MFT branch.

## Findings

### F-1: Fix landed only on Code (MFT); buggy code also lives on Content (LBM) and Stable (KNW) [Info]

**Description:** `TaskLocalizer.cs` exists on LBM (Content) and KNW (Stable) without the fix, absent on IMV (OldStable). Under the up-merge model a Code-branch commit does not propagate down, so the live/content releases would retain the bug unless intentionally back-ported.

**Investigation:** Checked file presence across branches (`TaskLocalizer.cs` on LBM/KNW; `CurrentMeasuringSystem` absent on LBM). MFT is a copy of LBM:15942, so r16110 (>15942) cannot be inherited by LBM/KNW — propagation would require an explicit down-merge. Raised to assignee.

**Resolution:** Accepted — assignee confirmed 2026.4 ships from the MFT (Code) branch, which is about to become the main release; no prod hotfixes are planned before that release, so no down-merge to KNW/LBM is needed.

**Discovered by:** skill recon (cross-branch presence check)

### F-2: Range display can invert when min and max are within one rounding step [Low]

**Description:** In `TaskLocalizer.Localize`, a range task rounds the lower bound Up and the upper bound Down; when they are closer than the rounding granularity the text reads e.g. `length 19.7 - 19.6 inch` (min > max).

**Investigation:** File inspection; the added test `TaskLocalizer_imperial_length_range_rounds_min_up_and_max_down` asserts exactly `19.7 - 19.6 inch`, confirming the author is aware. Real "between X and Y" mission configs differ by far more than 0.1 inch / 1 cm, so the inversion is not reachable in practice.

**Resolution:** Accepted — known, test-codified, harmless for realistic configs.

**Discovered by:** manual scan

### F-3: Weight kept at 3 decimals despite the literal "round lb to tenths" request [Info]

**Description:** The JIRA requirement said round lb to tenths; the implementation keeps weight at 3 decimals and only adds directional rounding (only length precision was reduced).

**Investigation:** Compared requirement text to diff. The reported bug was length whole-number rounding; weight at 3 decimals never misrepresents, and reducing it to tenths would re-introduce a (smaller) gap. The "round to tenths + directional" intent maps to length; weight correctly receives only the directional change.

**Resolution:** Accepted — defensible interpretation of intent; no action.

**Discovered by:** manual scan (requirement vs diff)

## Investigation Journal

- Intake: JIRA read direct via MCP. Executor field (`customfield_11224`) empty at intake → flagged; commit author taken from JIRA comment (Yuriy Burda). Assignee filled the field post-review.
- Branch: r16110 on MFT (Code role per `_index.md`). MFT created at r15943 from LBM:15942, so r16110 is a genuine post-copy MFT commit (not inherited).
- VCS audit: `svn log -r 15943:HEAD branches/MFT20260325 | grep FP-43909` → single commit r16110 (yuriy.burda); matches JIRA comment. No unposted commits.
- Verified `MeasuringSystemManager`: `LengthCm` returns Inches under Imperial / Centimeters under Metric; `Weight` returns Pounds / kg; `ChangeMeasuringSystem(1)=Imperial, (3)=EnglishMetric`. Confirms decimals choice (Imperial length → 1, Metric → 0) and that tests exercise real conversion (mock only stubs translation, `measuring` is a real instance keyed off `LanguageId`).
- Hand-checked test math: 0.5 m = 19.685″ → Less/Down 19.6, More/Up 19.7 ✓; 2.2 kg = 4.85017 lb → Less 4.85, More 4.851 ✓; 0.523 m metric → 52/53 cm ✓; 2.2341 kg → 2.235 kg ✓.
- Cross-branch: `TaskLocalizer.cs` present on LBM (Content) + KNW (Stable) without fix, absent on IMV (OldStable) → F-1. MFT is parent's child (copy of LBM:15942), so LBM/KNW cannot inherit r16110; any propagation needs explicit (down-)merge.
- Findings F-1/F-2/F-3 all Info/Low, resolved Accepted (card-only, no JIRA blockers). F-1 resolved via assignee: 2026.4 ships from Code/MFT (imminent main release, no prod hotfix before it) → no down-merge to KNW/LBM.
