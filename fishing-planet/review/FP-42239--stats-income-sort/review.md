---
status: resolved
executor: Yevhenii Shust
branch: MFT @ r16122
jira: https://fishingplanet.atlassian.net/browse/FP-42239
---

# Review: FP-42239 — [Stats] Unsorted table data in the "Income" report

## Summary

Table data in the "Income" (`/Stats/Money`) report appeared unsorted by date.
Fix adds an `ORDER BY` in `GetStatsTransactions` to guarantee chronological
order for the Income stats (chart + grid) instead of relying on storage/index
order.

## Scope

- **MFT r16122** — Added ORDER BY in `GetStatsTransactions` to guarantee chronological Income stats (chart/grid) without relying on index order.

## Notes

- **N-1 (Info):** Sibling method `GetTransactions` (same file, queries the legacy `Transactions` table) has the identical `GROUP BY {dateGroupStatement}` without `ORDER BY`. Grep of all `*.cs` shows its only callers are unit tests (`SqlMonetizationProviderTest.cs`) — no production consumer. The unsorted-order bug shape exists there too but affects nothing live. Out of scope for this fix; not worth filing.
- Fix is consumed by `MoneyModel.Fill()` → array order drives both the chart and the Kendo grid's default order. SQL-side `ORDER BY` is the right place to fix (small aggregated result, one row per day/month).
- No test added/changed in r16122. Existing `GetStatsTransactions_builds_correct_query` is a smoke test (executes query, asserts not-null) and neither breaks nor would catch an ordering regression. Acceptable for a one-line fix.

## Verdict

**Approve.** Minimal, correct, targeted fix. `ORDER BY {dateGroupStatement}` repeats the exact `SELECT`/`GROUP BY` expression — valid T-SQL, guarantees chronological order for both Daily (`CAST(Timestamp AS DATE)`) and Monthly (`DATEFROMPARTS(...)`) aggregates. No new injection surface (`dateGroupStatement` is a hard-coded two-value ternary, no user input). Performance impact negligible. Already inherited in Code (NPN) via branch copy — no merge needed.

## Investigation Journal

- Intake: executor = Yevhenii Shust (matches `customfield_11224`). Single commit r16122 on MFT per JIRA comment.
- VCS audit: `svn log -r 16000:HEAD | grep FP-42239` → exactly one commit r16122, matches JIRA. No undisclosed commits.
- Branch inheritance: NPN (Code) copied from MFT @ r16130; r16122 ≤ r16130. Verified via `svn log <NPN-URL>/.../SqlMonetizationProvider.cs -r 16122` — revision present in NPN file history → fix inherited via branch copy, no explicit merge needed.
- Per-site audit: grepped callers of `GetStatsTransactions` (prod: `MoneyModel.cs`) and sibling `GetTransactions` (tests only) → N-1.
- code-reviewer agent (independent): confirmed T-SQL validity, chronological correctness for both aggregates, zero new injection surface, negligible perf. No blocking findings.
