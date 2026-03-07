### ALG-004. **BUG:** Phase B finds farthest bucket instead of nearest

- **TDD:** "nearest non-empty group"
- **Code:** Loop iterates from `currentGroupIndex+1` to end without `break`, overwriting `targetGroup` each time.
  Result: selects the **farthest (strongest)** non-empty bucket. Similarly for fallback — selects farthest weakest.

**Decision:** Fix the bug. Add `break` after finding first match.

| Action                                                                                                                  | Status            |
|-------------------------------------------------------------------------------------------------------------------------|-------------------|
| **GDD:** N/A (will describe correct behavior per ALG-003).                                                              | N/A               |
| **TDD:** Already describes correct ("nearest") behavior. No changes.                                                    | N/A               |
| **Code:** Fix `BalanceGroups` Phase B: add `break` after `targetGroup = groups[j]` in both loops (upward and fallback). | DONE (2026-02-17) |

**Priority:** **High** (behavioral bug)
