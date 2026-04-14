---
status: completed
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-42033
---
# FP-42033: Torch and sinker retained after line cut

## Status
Completed. Fixed in r15783 (LBM), merged r15784 (KNW). Verified on QA by Mykhailo Horishnyi. JIRA closed 2026-02-16.

## Summary
Player presses B (Cut) with torch rod setup — torch and sinker are not removed. Expected: entire terminal tackle destroyed on line cut.

## Root Cause
`HandleBreakLine` calls `BreakLeaderLoseTackle` when leader exists, which excludes Sinker/Chum/Torch from removal. Leader state is also not cleaned up when `BreakLineLoseTackle` is called instead.

## Decisions
1. Extract `CleanupLeader()` method from `BreakLeaderLoseTackle` — handles only state cleanup (null leader, chum lifecycle, rod unequip check). No durability wear, stats, or logging.
2. Call `CleanupLeader()` from `BreakLineLoseTackle` after `DoInventoryTransactionEvent` — ensures leader state is cleaned up whenever the line breaks.
3. Simplify `HandleBreakLine` — primary path always calls `BreakLineLoseTackle` (semantically correct for line cut). Defensive fallback to `BreakLeaderLoseTackle` if `line` is null but `leader` exists, with error logging via `DiagAdapter.SaveServerErrorAsync`.

All 3 decisions implemented as designed.

## Artifacts
- [root-cause-analysis.md](artifacts/root-cause-analysis.md) — call flow, solution outline, safety guarantees, affected call sites, testing plan

## Milestones
- 2026-02-11 — Root cause analysis and solution design (KB session)
- 2026-02-11 — Fix committed: r15783 (LBM), r15784 (KNW merge)
- 2026-02-12 — Verified on QA (Steam, client r52149, server r15784)
- 2026-02-16 — JIRA closed
