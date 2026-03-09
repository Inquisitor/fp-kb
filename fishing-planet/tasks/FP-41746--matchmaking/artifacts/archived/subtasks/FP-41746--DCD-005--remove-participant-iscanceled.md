### DCD-005. `TournamentGroupParticipant.IsCanceled` — unused

- **Code:** Property exists but is never set or checked in `MatchmakingLogic`.
- Related to CFG-002.

**Decision:** Remove entirely — feature never released. Part of CFG-002 cleanup.

| Action                                                                                                                       | Status |
|------------------------------------------------------------------------------------------------------------------------------|--------|
| **Code:** Remove `IsCanceled` from `TournamentGroupParticipant`. Scan full codebase and DB stored procedures for references. | DONE   |

**Priority:** Medium