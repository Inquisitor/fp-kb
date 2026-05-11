### CFG-006. `MaxGroupSize` — in GDD, not in code

- **GDD:** "Desired max number of players per group. Unlike TargetSize which splits into many small subgroups, this
  splits into fewer large groups."
- **Code:** Not in `TournamentGroupingRule`. Not implemented.

**Decision:** Implement per FP-41833. Rework GDD description — current wording unclear. Update documentation to match
implementation. Code parameter named `MaxSize` (not `MaxGroupSize`) for consistency with `MinSize`.

| Action                                                                                            | Status |
|---------------------------------------------------------------------------------------------------|--------|
| **GDD:** Rework description (current wording unclear). Align with final implementation.           | DONE   |
| **TDD:** Add `MaxGroupSize` parameter description with implementation details.                    | DONE — new spec (page 5505613835) |
| **Code:** Implement `MaxGroupSize` in `TournamentGroupingRule` and `MatchmakingLogic` (FP-41833). | DONE   |

**Priority:** Medium (feature implementation)
