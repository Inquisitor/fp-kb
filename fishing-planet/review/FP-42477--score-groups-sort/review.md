---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15925
jira: https://fishingplanet.atlassian.net/browse/FP-42477
---

# Review: FP-42477 — [Competitions] Score window hard scrolling through groups

## Summary

In the in-game Score window, paginated tournament results came back with the wrong group ordering — client expected groups in `A → B → C` order, but server returned data sorted by `BracketId DESC, GroupName ASC`. With more than one bracket in a tournament, group `A` could appear only after groups from higher-BracketId brackets, so the first 40 rows (pageIndex 0 + 1) skipped group `A` entirely. The commit strips `BracketId` out of the `ORDER BY` in four tournament-result SPs so that the output is sorted purely by `GroupName`.

## Scope

- **LBM r15925** — Make competition score groups sorting order to match with a client sort order
  - Removed `BracketId DESC` from outer `ORDER BY` in four SPs under `SQL/Patches/Main/Procedures/`
  - Affected: `GetCurrentTournamentResult`, `GetCurrentTournamentResultTopN`, `GetTournamentResult`, `GetTournamentResultTopN`
  - Inner window functions `RANK()` / `ROW_NUMBER()` still `PARTITION BY BracketId, GroupName`; no data identity changes

## Findings

### F-1: Outer ORDER BY drops bracket key while inner partition retains it [Info]

**Description.** The commit removes `BracketId DESC` from the outer ORDER BY while inner `RANK()` / `ROW_NUMBER()` continue to `PARTITION BY BracketId, GroupName`. Initial concern was that rows from different brackets sharing a `GroupName` could interleave under the new order.

**Investigation.**
- Read diff across the 4 SPs — consistent pattern, only outer presentation order changed.
- Initially rated Medium on the hypothesis that `GroupName` could repeat across brackets.
- Verified via `Shared/SharedLib/Tournaments/MatchmakingLogic.BuildGroups` (lines 243-248): group names are assigned with a single tournament-wide running index, so every `GroupName` is globally unique within a tournament and already encodes its bracket.
- With that invariant, `BracketId` in the outer ORDER BY is redundant; removing it cannot interleave anything.
- The old clause's real effect was to sort primarily by bracket ID — pushing higher-ID brackets (whose group names come later in the alphabetical sequence) ahead of lower-ID ones (starting with `A`), which is precisely why pagination pages 0+1 could miss group `A`.
- Severity downgraded Medium → Info after verification.

**Resolution.** Accepted. Fix is correct.

**Discovered by.** Skill recon.

### F-2: History procedures still ORDER BY [Rank] without GroupName [Info]

**Description.** `GetTournamentResultHistory` and `GetTournamentResultHistoryTopN` keep sorting by `[Rank]` only. They are player-facing (called via `TournamentHistoryCache` from `GameClientPeer_Tournaments`), but serve the past-tournaments UI rather than the live Score window this task fixes.

**Investigation.**
- Grepped callers: `SqlTournamentProvider.GetTournamentResultHistory` → `TournamentHistoryCache` → `GameClientPeer_Tournaments` sub-op handler. Confirmed player-facing, not admin-only.
- Separate pre-existing design concern surfaced: both procs `UNION ALL` the active and archive tables inside a live request path.
- User confirmed: out of scope for this task.

**Resolution.** Pre-existing. Not addressed in this review.

**Discovered by.** Skill recon.

## Notes

- `GetCurrentTournamentResultHud` in the same folder was not modified; verified against deployed procedure body — it filters by specific `@BracketId / @GroupName` and sorts by `RowNum` only, so the bug pattern does not apply. No change required.
- Deployment model sanity check done explicitly: procedure files under `SQL/Patches/Main/Procedures/*.sql` are deployed by the release pipeline (not via `AppliedPatches`). Confirmed on local DB — procedure bodies already reflect the new ORDER BY, no matching patch row. This is the project convention by design (rollback and diff-visibility benefits vs. the older per-change patch approach).
