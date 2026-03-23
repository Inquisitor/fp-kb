---
status: in-progress
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-41845
related: FP-33182, FP-41844, FP-42080
blocked-tasks: FP-41844
epic: FP-26788 (Leaderboards and ratings)
---
# FP-41845: Implement New System of Weight Generation

## Status
Phase 2a complete (r15918–r15937, commits 1–7). Next: Phase 3 — Confluence documentation (FP-41844). Phase 2b (crossover visualization) deferred.

## Summary

### Goal
Replace the current hybrid uniform/normal weight generation system (FP-33182) with a correct, predictable, and tunable algorithm. Before making any changes, build instrumentation to understand, simulate, and validate the system.

### Approach
1. **Instrument first** — build a simulator that reproduces production weight generation for specific fish/pond configurations
2. **Validate** — compare simulated distribution graphs against real production statistics (FishFact table)
3. **Iterate** — use the simulator to design and validate the new algorithm with game designers
4. **Implement** — replace the algorithm with confidence

### Context
- Current system (FP-33182) is on production (LBM20251201) with known issues — see [FP-33182 journal](../FP-33182--weight-generation/journal.md)
- Existing "tests" are visualization-only with zero assertions and non-representative parameters
- Game designers need a tool to predict the effect of parameter changes

## Plan
See [backlog.md](backlog.md) for action items.

## Related
- **FP-33182** — current system on production, known issues documented → [journal](../FP-33182--weight-generation/journal.md)
- **FP-41844** — documentation task, **blocked by this task** → [JIRA](https://fishingplanet.atlassian.net/browse/FP-41844)
- **FP-42080** — game design support task (Andrii Maslov) → [JIRA](https://fishingplanet.atlassian.net/browse/FP-42080)
- Module: [fish-generator](../../server/modules/fish-generator/_card.md)

## Milestones
- 2026-03-10: Phase 1.1 complete — FishFact deep dive, SQL query for weight histograms, production data validated (Northern Pike + Nile Perch). Form polynomial effects confirmed on real data.
- 2026-03-10: Phase 1.2 complete — all generation paths mapped, simulator scope confirmed (BiteSystem path only, Source='B'). weightK origin identified (chum system). Architecture decision: invoke real BiteSystem code, no code copying.
- 2026-03-11: Phase 1.3 complete — WebAdmin Fish Weight Simulator built. Service (`FishWeightSimulationService`), controller (partial `StatsController`), Razor view with Kendo area chart. All accumulators (histogram, top weights, totals) keyed by actual form after crossover. Top-200 leaderboard preview per form. Culture-safe float handling (InvariantCulture). Code reviewed, 11 tests green.
- 2026-03-11: Phase 1.3 deployed — simulator live on WebAdmin, confirmed working by game designers and analysts.
- 2026-03-11: Phase 1.4 complete — simulator validated against production FishFact (Nile Perch @ Congo River, 2 months data). All four forms match within 0.13pp max deviation. Detailed analysis in [module log](../../server/modules/fish-generator/log.md). Phase 1 fully complete.
- 2026-03-12: Phase 2a planning — GD requirements gathered from Confluence docs and stakeholder input. Decay algorithm design: analyzed three approaches (normal-first, power-law, exponential). Normal-first rejected due to fundamental seam discontinuity at threshold. Interactive comparison tool built ([decay-comparison.html](artifacts/decay-comparison.html)).
- 2026-03-12: Phase 2a.1 complete — FP-33182 threshold/Marsaglia re-roll reverted in `GenerateRandomWeight()`. Restored pre-r12950 uniform generation. Also eliminated double weightK application bug introduced in r12950.
- 2026-03-12: Phase 2a.2 complete — simulator bucket range extended to `globalMax * weightK` when weightK > 1. Oversize fish now visible on chart instead of clamping into last bucket.
- 2026-03-14: Phase 2a design complete — edge distribution system spec and 5-commit implementation plan finalized. Key design decisions: "Edge Distribution" terminology (not decay/tail), zone fraction (not threshold), `[Flags]` EdgeDistributionScope (form×edge bit matrix), callback config pattern (`UpdateFromGlobalVariables` in BiteSystem), `internal set` on Config.Current. Deep review: 18 findings, all resolved.
- 2026-03-14: Commits 1–2 code complete (local) — legacy cleanup (polynomial removal, `FishWeightGenerator` extraction) + edge distribution system (4 algorithms, config, scope, GlobalVariables, WebAdmin UI, 43 tests passing). Not committed to SVN — pending normalization fix.
- 2026-03-15: Normalization trap discovered — naive edge remap gives edge zone a fixed probability budget, creating a density spike at the boundary ((α+1)× for PowerLaw). Same root cause as the r12950 seam problem. Fix: normalized piecewise inverse CDF with `EdgeAreaFraction` property. Design doc updated, deep dive article written ([edge-distribution.md](../../server/modules/fish-generator/edge-distribution.md)).
- 2026-03-16: Phase 2a committed to SVN. r15918: `MathUtility` (Lerp, Clamp) in SharedLib. r15919: edge distribution system — legacy cleanup, 4 strategies, normalized `Generate()`, config, scope, GlobalVariables, WebAdmin, 44 tests green.
- 2026-03-16: Commit 3 (r15920) — simulator moved from `StatsController` to `SettingsController` (namespace `WorldSettings`, avoids conflict with existing `Settings` static class). View → `Views/Settings/FishWeightGenerator.cshtml`. Navigation: Content > Fishing. Both files svn-moved for history. Wildcard csproj pattern for future partials.
- 2026-03-16: Commit 4 (r15921) — Settings UI: Save to GlobalVariables with DataChanges audit trail, confirmation dialog (responsibility checkbox + comment), Reset per fieldset, Refresh Caches. Two-fieldset layout (CSS Grid). Kendo DropDownList for Algorithm/Scope. `AllUpper` and `ExtremesAndAllUpper` scope presets. SQL patch 035-v2: added missing `FishWeightUpperEdgeZoneFraction` insert.
- 2026-03-17: Commits 5–6 (r15923, r15926) — Preview Curves modal: Canvas 2D curve explorer with dark mode, crosshair legend, sidebar with non-linear sliders, upper/lower toggle. UI restructured: CSS Grid fieldsets, Kendo widgets, zone fields in percentages. Chart fix: near-edge buckets with count>0 now visible. Save dialog: AJAX error handling, Kendo ComboBox commit message.
- 2026-03-19: Commit 7 (r15937) — Simulator & UI polishing. Shared `FishWeightRounding` constants (production + simulator sync). Histogram bucketing rewritten in decimal arithmetic — fixed float precision bug (zeros/doubles pattern at gram resolution). Bucket grid: `(int)(range/step)+1` gives maxWeight its own bucket. Sentinel bucket for chart area closing. Tooltips: gram-precision ranges, single value at step≤0.001, right-inclusive last bin. TSV export F3. `ToFileNameSlug` scope-aware. NiceStep snap on MaxBucketCount overflow. Percentages to 3dp. Layout padding-right fix. 22 tests green.
