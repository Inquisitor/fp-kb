### SUB-001. TDD says "[TBD]"; code fully implements group creation

- **TDD:** "Creating subgroups — [TBD]"
- **Code:** `CreateGroups` (was `CreateSubgroups`) fully implemented with TargetSize-based splitting, group count
  selection (projected/increased/decreased), even distribution.
- **GDD:** "Logic for creating subgroups" section describes the concept and says "in first iteration TargetSize won't be
  used."

**Decision:** Implement new group parameters per FP-41833. Update documentation everywhere to describe final algorithm.

| Action                                                                                                                      | Status |
|-----------------------------------------------------------------------------------------------------------------------------|--------|
| **GDD:** Update group creation section to describe final algorithm with new parameters (FP-41833).                          | DONE   |
| **TDD:** Replace "[TBD]" with full group creation algorithm description matching final implementation.                      | DONE — new spec (page 5505613835) |
| **Code:** Implement new group parameters per FP-41833. Update `CreateGroups` (was `CreateSubgroups`) in `MatchmakingLogic`. | DONE   |

**Priority:** Medium (feature implementation, FP-41833)
