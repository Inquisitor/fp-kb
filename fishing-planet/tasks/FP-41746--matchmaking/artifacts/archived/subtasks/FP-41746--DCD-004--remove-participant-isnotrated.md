### DCD-004. `TournamentGroupParticipant.IsNotRated` — unused

- **Code:** Property exists but is never set or checked in `MatchmakingLogic`.
- Related to CFG-003.

**Decision:** Remove entirely — feature never released. Part of CFG-003 cleanup.

| Action                                                                                                                       | Status |
|------------------------------------------------------------------------------------------------------------------------------|--------|
| **Code:** Remove `IsNotRated` from `TournamentGroupParticipant`. Scan full codebase and DB stored procedures for references. | DONE   |

**Priority:** Medium