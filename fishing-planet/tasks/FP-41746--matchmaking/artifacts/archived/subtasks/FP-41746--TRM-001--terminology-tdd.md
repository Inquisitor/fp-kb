### TRM-001. Terminology mismatch across all documents

| Concept                | GDD     | TDD            | Code                      |
|------------------------|---------|----------------|---------------------------|
| Rating range config    | Bracket | (rating range) | `TournamentGroupSettings` |
| Rating-based container | Bucket  | Group          | `TournamentGroup`         |
| Final competition unit | Group   | Subgroup       | `TournamentSubgroup`      |

**Decision:** Adopt unified terminology **Bracket / Bucket / Group** (from GDD).

| Action                                                                                                                                                                      | Status                                   |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------|
| **GDD:** Already uses Bracket/Bucket/Group. No changes needed.                                                                                                              | N/A                                      |
| **TDD:** Replace "Group" with "Bucket" and "Subgroup" with "Group" throughout the matchmaking section.                                                                      | DONE — new spec (page 5505613835)        |
| **Code:** Code identifiers (`TournamentGroup`, `TournamentSubgroup`) stay as-is to avoid massive refactoring. Add XML doc comments explaining the mapping to unified terms. | Superseded by TRM-002 (full code rename) |

**Priority:** High (blocks clear communication on everything else)
