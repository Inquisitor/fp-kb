### DCD-002. `TournamentGroup.IsCanceled` — always false

- **Code:** `TournamentGroup.IsCanceled` (was `TournamentSubgroup.IsCanceled`). Marked `[Obsolete]`. No logic sets it
  to `true`. `ProcessGrouping` returns `null` only if all groups are canceled (impossible since IsCanceled is always
  false).
- Related to CFG-002.

**Decision:** Remove field entirely — feature never released. Remove from code, DB stored procedures, and all
references.

| Action                                                                                                                                                                                                                              | Status |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------|
| **Code:** Remove `IsCanceled` from `TournamentGroup`. Remove the `allCanceled` check in `MakeGroups` (was `MakeSubgroups`) or replace with `groups.Count == 0`. Update `AssignGroupsToParticipants`. Scan full codebase and DB SPs. | DONE   |

**Priority:** Medium
