### DCD-001. `TournamentGroup.IsNotRated` — always false

- **Code:** `TournamentGroup.IsNotRated` (was `TournamentSubgroup.IsNotRated`). Marked `[Obsolete]`. No logic sets it
  to `true`. Written to DB as `IsRated = !IsNotRated` (always `true`).
- Related to CFG-003.

**Decision:** Remove field entirely — feature never released. Remove from code, DB stored procedures, and all
references. Related to CFG-003 investigation of `IsRated` columns.

| Action                                                                                                                                                                                  | Status |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------|
| **Code:** Remove `IsNotRated` from `TournamentGroup`. Update `AssignGroupsToParticipants` to pass `isRated: true` directly. Scan full codebase and DB stored procedures for references. | DONE   |

**Priority:** Medium
