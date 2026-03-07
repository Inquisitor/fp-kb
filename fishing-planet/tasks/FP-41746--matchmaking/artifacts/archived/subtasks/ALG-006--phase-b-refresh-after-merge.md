### ALG-006. Phase B does not call `RefreshGroup()` on target after merge

- **Code:** After moving participants from incomplete bucket to target, `RefreshGroup()` is not called on the target.
  `MinParticipantRating`/`MaxParticipantRating` and sort order become stale. Mitigated by `MakeSubgroups` re-sorting
  later, but fragile.

**Decision:** Add `RefreshGroup()` call after merge.

| Action                                                                                                                                                                            | Status            |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------|
| **GDD:** N/A                                                                                                                                                                      | N/A               |
| **TDD:** N/A                                                                                                                                                                      | N/A               |
| **Code:** After moving participants to `targetGroup` in Phase B, call `RefreshGroup(targetGroup)`. Also `RefreshGroup(currentGroup)` to reset stale ratings on the drained group. | DONE (2026-02-17) |

**Priority:** Medium (correctness)
