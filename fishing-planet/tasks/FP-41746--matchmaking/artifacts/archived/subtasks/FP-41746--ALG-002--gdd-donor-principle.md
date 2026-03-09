### ALG-002. Merging direction — GDD says "Middles as filler"

- **GDD:** "Players from bracket B (Middles) serve as filler for other buckets."
- **Code:** Any bucket can serve as a donor. The ping-pong algorithm pulls from adjacent **unvisited** buckets
  regardless of semantic role.

**Decision:** Code behavior is correct and more general. Update GDD.

| Action                                                                                                                                                                                                                                                                 | Status            |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------|
| **GDD:** Replace "Middles serve as filler" with: "Players are pulled from adjacent unvisited buckets. The middle bucket(s) are naturally the last to be visited, so they serve as the primary donor — but any bucket can donate players to an adjacent one if needed." | DONE (2026-03-09) |
| **TDD:** Already correct. No changes.                                                                                                                                                                                                                                  | N/A               |
| **Code:** No changes needed.                                                                                                                                                                                                                                           | N/A               |

**Priority:** Medium