### CFG-001. `CrossMovesAllowed` — documented but not in code model

- **GDD:** Described. Says "always true, because we always form groups and run competition if possible."
- **TDD:** Described. Says "deprecated, will be removed."
- **Code:** Not in `TournamentGroupingRule`. Algorithm always allows cross-moves.

**Decision:** Remove from documentation entirely. Feature not released — no need to keep history.

| Action                                                       | Status                                                    |
|--------------------------------------------------------------|-----------------------------------------------------------|
| **GDD:** Remove all mentions of `CrossMovesAllowed`.         | DONE (removed in Confluence, local .md synced 2026-02-17) |
| **TDD:** Remove all mentions of `CrossMovesAllowed`.         | DONE                                                      |
| **Code:** No changes needed — parameter was already removed. | N/A                                                       |

**Priority:** Low
