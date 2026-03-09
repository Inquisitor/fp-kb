### ALG-001. Bucket fill priority — GDD semantic vs. Code positional

- **GDD:** "Priority: fill Newbies first, then Tops, then Middles last."
- **TDD:** Ping-pong traversal described in detail. First bucket, last, second, second-to-last, etc.
- **Code:** `PingPongTraversalIterator` — positional ping-pong. For 3 groups (Newbies=1, Middles=2, Tops=3) the result
  is 1,3,2 — matches GDD's semantic description.

**Decision:** No conflict for the standard 3-group setup. For N groups, the code is more precise. Update GDD to describe
the positional ping-pong pattern instead of semantic names. Keep 3-group case as example.

| Action                                                                                                                                                                 | Status            |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------|
| **GDD:** Rewrite "Group Creation Logic (for N groups)" to describe ping-pong traversal pattern instead of semantic priority. Keep 3-group example showing equivalence. | DONE (2026-03-09) |
| **TDD:** Already correct. No changes.                                                                                                                                  | N/A               |
| **Code:** No changes needed.                                                                                                                                           | N/A               |

**Priority:** Medium