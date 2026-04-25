---
status: resolved
executor: Dmytro Kurylovych (initial), Stanislav Samoilov (rework)
branch: LBM @ r15656, rework @ r16036, merged to MFT @ r16037
jira: https://fishingplanet.atlassian.net/browse/FP-41591
---

# Review: FP-41591 — [WebAdmin] [ProductsDashboard] missing columns in By level groups report

## Summary

WebAdmin "Products Dashboard" → "By level groups" report lacked the 90-100 and 100-110 columns for the current `LevelCap = 110`. The original fix (LBM r15656) replaced a hard-coded 9-column list with a `LevelCap / 10` loop. Review found two defects, confirmed empirically on QA (a level-50 transaction renders in the "51-60" column). Rework done in this session reverses the off-by-one in SQL grouping and extends column count in both ProductsDashboard and TwitchDrop reports.

## Scope

- **LBM r15656** (Dmytro) — [WebAdmin] [ProductsDashboard] use global variable LevelCap to generate report columns
  - Replaced 9 hard-coded `ProductDashboardColumn { Level = 0..8 }` adds with `for (int i = 0; i < LevelCap / 10; i++)`
  - Verdict: rejected — see F-1, F-2 below
- **LBM r16036** (Stanislav, this session) — [LevelGroups] fix off-by-one in level grouping for monetization reports
  - SQL `tf.Level / 10` → `(tf.Level - 1) / 10` in `SqlAnalyticsProvider.GetProductsDashboard()` reportType "L"
  - `ProductsDashboardModel` case "L" loop bound `LevelCap / 10` → `(LevelCap - 1) / 10 + 1`
  - `TwitchDropStatsModel.LevelRangeColumns` count `(LevelCap - 1) / LevelRange` → `(LevelCap - 1) / LevelRange + 1`
  - Merged to MFT (Code) @ r16037 (post-r15942, explicit merge required)

## Findings

### F-1: SQL grouping mis-aligned with column titles + last group dropped [High]

**Description.** Two compounding defects:

1. **SQL/title misalignment (pre-existing, not introduced by r15656).** The view's column title formula is `string.Format("{0} - {1}lvl", c.Level * 10 + 1, c.Level * 10 + 10)` — column `Level=N` is labeled "(N*10+1) - (N*10+10)lvl". The SQL grouping is `tf.Level / 10` (integer division). For `tf.Level = N` where `N % 10 == 0`, SQL returns `N/10`, so a player at level 10 falls into column `Level=1` ("11-20lvl"), level 20 into "21-30lvl", level 100 into "101-110lvl". Empirically confirmed on QA: a level-50 transaction shows in the "51-60lvl" column.
2. **Last group dropped (introduced by r15656 logic).** With `LevelCap = 110`, `maxLevelGroup = LevelCap / 10 = 11`, loop creates columns `Level = 0..10`. SQL maps `tf.Level = 110` (capped player, reachable per `LevelingManager`) to DTO `Level = 11`. There is no column for `Level = 11` → row silently dropped at render (`equals = (c, p) => c.Level == p.Level`).

The original 9-column hard-coded version exhibited the same SQL/title misalignment plus dropped levels 90+ entirely (the symptom that JIRA describes).

**Investigation.**
- `LevelingManager.cs`: `currentLevel >= GlobalVariablesCache.LevelCap` and `profile.Level = levelGains.Last().Id` (no clamp) confirm players can reach `Level == LevelCap`.
- `AnalyticsAdapter.LogTransactionFact`: `Level = profile.Level` written into `TransactionFact.Level` without clamp.
- DB: `Leveling.LevelCap = 110`, `MAX(Levels.LevelId) = 110`, 110 rows.
- Cross-reference with `TwitchDropStatsModel.LoadTwitchDropStatsGroupByLevelRange` SQL: `(PlayerLevel - 1) / @levelRange` — same module already uses the aligned formula. The reviewer (and r15656 author) did not notice the existing pattern.
- Empirical QA check (this session): a level-50 transaction shows in "51-60lvl" column → confirms (1).

**Discovered by.** skill recon (defect 2) + reviewer manual QA check (defect 1).

**Resolution.** **Self-fixed in rework commit r16036** (this session): switched SQL to `(tf.Level - 1) / 10` and loop bound to `(LevelCap - 1) / 10 + 1`. With `LevelCap = 110`: 11 columns Level=0..10, level 1..10 → group 0 → "1-10lvl" ✓, level 110 → group 10 → "101-110lvl" ✓.

### F-2: Same defect pattern in `TwitchDropStatsModel.LevelRangeColumns` [High]

**Description.** `LevelRangeColumns` computed `int maxGroup = (LevelCap - 1) / LevelRange;` then `Enumerable.Range(0, maxGroup)`. `Range`'s second argument is element count, not end-inclusive — for `LevelCap=110, LevelRange=10` this produces ranges `0..9` (10 elements), so the last group (group 10, levels 101..110) is missing. SQL in this model already uses `(PlayerLevel - 1) / 10` (correctly aligned), so only the column count was wrong.

**Discovered by.** manual scan during F-1 investigation.

**Resolution.** **Self-fixed in rework commit r16036** (this session): `+ 1` added to `maxGroup`. Originally classified as Low/Pre-existing/Filed; promoted to High by reviewer because the symptom in TwitchDrop is identical to the one this ticket was opened for, and the user requested addressing both at once.

## Investigation Journal

- 2026-04-25: Phase 1 intake complete — card created from JIRA comment metadata; commit list taken as-is (single commit).
- 2026-04-25: VCS audit — `svn log --search "FP-41591" -r 15500:16013` confirms exactly 1 commit (r15656); no extras. `svn log` on `WebAdmin/.../ProductsDashboardModel.cs` in MFT URL shows r15656 → MFT inherits via branch-copy (created from LBM r15942 ≥ 15656). No merge needed for r15656.
- 2026-04-25: Hypotheses H3 (no `{}` on `for`) and H4 (`int maxLevelGroup` declared inside `case` without block) → both correspond to pre-existing convention in this file (case `D`/`W`/`M` do the same); not authorial findings.
- 2026-04-25: Hypothesis H6 (View hardcoded under 9 columns) → disproven. `ProductsDashboard.cshtml` iterates `Model.Columns.Count` everywhere.
- 2026-04-25: Verified `LevelCap` semantics via `LevelingManager.cs` and DB query (`Leveling.LevelCap = 110`, `MAX(Levels.LevelId) = 110`); LevelCap is inclusive max ID.
- 2026-04-25: Independent verification via code-reviewer agent confirmed loss of capped-level transactions (off-by-one at upper bound).
- 2026-04-25: User initially skeptical ("колонка же есть на QA"), reframed inquiry to ask **what column** the data lands in. Reviewer ran QA check: level-50 transaction renders in "51-60lvl" → revealed pre-existing SQL/title misalignment (every round-decade level shifts one column right). Promoted F-1 from Medium to High.
- 2026-04-25: Cross-checked TwitchDrop SQL — `(PlayerLevel - 1) / 10` already aligned with title `range*10+1, (range+1)*10`. F-2 promoted from Low/Pre-existing to High; user requested rework in same ticket since author unavailable.
- 2026-04-25: Decided fix approach A (adjust SQL `(tf.Level - 1) / 10` + loop bound `(LevelCap - 1) / 10 + 1`) over approach B (rewrite title formula); approach A keeps user-facing labels unchanged.
- 2026-04-25: Verified `GetProductsDashboard("L", …)` has only one caller (`ProductsDashboardModel.LoadData`) — SQL change has no other consumers.
- 2026-04-25: Rework committed as LBM r16036; merged to MFT @ r16037; bug-description and fix-notification posted to JIRA as separate comments per user preference.
