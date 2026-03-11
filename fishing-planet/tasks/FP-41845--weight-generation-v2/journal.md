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
Phase 1.3 complete: WebAdmin weight simulator built and operational. Service layer invokes real `GenerateRandomWeight()`, all results bucketed by actual (post-crossover) form matching FishFact production behavior. Kendo area chart, form toggles, crossover display, top-200 leaderboard preview, TSV export. 11 unit tests green. Next: Phase 1.4 — validate simulator against production FishFact histograms.

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
