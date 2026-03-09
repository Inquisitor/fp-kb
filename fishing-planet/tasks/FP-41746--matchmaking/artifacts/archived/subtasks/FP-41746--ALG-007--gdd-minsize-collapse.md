### ALG-007. "MinSize*2 single group" threshold — GDD describes, code doesn't enforce

- **GDD:** "If total players < MinSize*2 — run competition as single group, no splitting."
- **Code:** No explicit check for `MinSize*2` in `MatchmakingLogic`. The algorithm naturally produces one group if there
  aren't enough players for two, but there's no explicit guard.

**Decision:** Trivial — algorithm handles this naturally, no explicit check needed. Remove from GDD to avoid clutter.

| Action                                                                      | Status            |
|-----------------------------------------------------------------------------|-------------------|
| **GDD:** Remove the "MinSize*2 single group" statement — it's self-evident. | DONE (2026-03-09) |
| **TDD:** N/A                                                                | N/A               |
| **Code:** No changes needed.                                                | N/A               |

**Priority:** Low