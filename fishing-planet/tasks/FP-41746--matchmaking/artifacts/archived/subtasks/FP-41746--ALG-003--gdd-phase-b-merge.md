### ALG-003. Incomplete bucket merge (Phase B) — not described in GDD

- **GDD:** Does not describe what happens if a bucket remains incomplete after balancing.
- **TDD:** "Prioritizes merging into a stronger group. Fallback: nearest weaker group."
- **Code:** Merges upward (stronger), fallback to weaker. **BUG: finds farthest, not nearest** (see ALG-004).

**Decision:** Add Phase B description to GDD. Fix bug in code (ALG-004).

| Action                                                                                                                                                                                                                                                                                | Status            |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------|
| **GDD:** Add a brief note describing Phase B: after ping-pong traversal, if a bucket is still below MinSize, it merges into the nearest stronger bucket; fallback — nearest weaker bucket. Include the 5 scenario categories from TST-001 as typical examples for the 3-bracket case. | DONE (2026-03-09) |
| **TDD:** Already describes correct ("nearest") behavior. No changes needed.                                                                                                                                                                                                           | N/A               |
| **Code:** See ALG-004 for bug fix.                                                                                                                                                                                                                                                    | N/A               |

**Priority:** Medium