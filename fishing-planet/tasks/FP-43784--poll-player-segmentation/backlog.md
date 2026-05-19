# FP-43784 — backlog

## Immediate

- [x] Executor: add empty column `Matched nick` in Sheet before `Level`, plus an empty `Duplicate?`
  column after `Is Payer?`. Paste `artifacts/07_final_tsv.tsv` (5 columns).
- [x] Post JIRA comment with results summary (comment id `120470`).
- Marketing-side: decision on DUPLICATE-marked rows (50 rows) is owned by the requesting team —
  not tracked here.

## Dropped

- 370 still-unmatched originals — executor decision: leave as-is. No second fuzz pass.
- `06_manual_review.csv` retained in `artifacts/` as audit trail (18 freshness-dropped + 4 stale
  reviewed).
