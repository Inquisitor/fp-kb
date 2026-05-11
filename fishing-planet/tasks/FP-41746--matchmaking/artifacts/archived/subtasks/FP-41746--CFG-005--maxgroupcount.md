### CFG-005. `MaxGroupCount` — in GDD, not in code

- **GDD:** "Maximum number of groups the algorithm can split the quorum into." Example: `"GroupCount": 5`. Use case: "if
  500 newbies registered, split into 3 newbie groups instead of one."
- **Code:** Not in `TournamentGroupingRule`. Not implemented.

**Decision:** Implement per FP-41833. Update documentation to match implementation.

| Action                                                                                             | Status |
|----------------------------------------------------------------------------------------------------|--------|
| **GDD:** Update description to match final implementation.                                         | DONE   |
| **TDD:** Add `MaxGroupCount` parameter description with implementation details.                    | DONE — new spec (page 5505613835) |
| **Code:** Implement `MaxGroupCount` in `TournamentGroupingRule` and `MatchmakingLogic` (FP-41833). | DONE   |

**Priority:** Medium (feature implementation)
