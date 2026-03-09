### TRM-002. Rename code identifiers to unified terminology

- **Code:** Rename core matchmaking types to match Bracket/Bucket/Group terminology:
    - `TournamentGroupSettings` → `TournamentBracket`
    - `TournamentGroup` → `TournamentBucket`
    - `TournamentSubgroup` → `TournamentGroup`
    - `TournamentGroupParticipant` — stays (correct in new terminology)
    - `TournamentGroupingRule` — stays (neutral name)
- **Risk:** Name collision — must rename in two steps (Group→Bucket first, then Subgroup→Group).
- **Boundary:** Keep old names at DB/serialization layer with XML doc comments mapping to new terms.
- **Scope:** Affects Shared/ObjectModel, GameServer, DAL, WebAdmin, tests. Assess blast radius before starting.

**Decision:** Rename in code, preserve old names only at DB/input boundaries. Execute as final phase after all other
changes. May be split into sub-items later.

| Action                                                                                                                          | Status                                                                                                     |
|---------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------|
| **GDD:** No changes needed.                                                                                                     | N/A                                                                                                        |
| **TDD:** No changes needed (will already use unified terms after TRM-001).                                                      | N/A                                                                                                        |
| **Code:** Rename types in two steps. Add serialization aliases / XML doc at DB boundary. Update all references across solution. | DONE (2026-02-18, P6-P14 deferred → TRM-003. See [Terminology-Rename-Plan.md](Terminology-Rename-Plan.md)) |

**Priority:** Medium (execute last — after all other phases)
