### VAL-001. TDD describes extensive validation, code has minimal

- **TDD:** Lists these validation checks:
    - `MinSize < TargetSize < MaxSize`
    - `CanceledIfIncomplete` and `NotRatedIfIncomplete` can't both be true
    - `TargetSize` and `MaxSize` both null or both not null
    - Rating overlap checks (continuous brackets)
- **Code:** Only `TargetSize` range validation exists (`CreateGroups` (was `CreateSubgroups`) throws
  `ArgumentException` if `TargetSize < MinSize` or `TargetSize > MaxSize`). No rating overlap validation.

**Decision:** Remove validations for deleted parameters from TDD. Remaining validations (TargetSize, rating ranges,
code-side checks) to be revisited after CFG-007 refactoring.

| Action                                                                                                                                       | Status |
|----------------------------------------------------------------------------------------------------------------------------------------------|--------|
| **GDD:** N/A                                                                                                                                 | N/A    |
| **TDD:** Remove validation rules for `CanceledIfIncomplete`/`NotRatedIfIncomplete`. Revisit remaining validations after CFG-007.             | Folded into [FP-43717](https://fishingplanet.atlassian.net/browse/FP-43717) |
| **Code:** Revisit code-side validations after CFG-007 (existing checks have issues). Consider adding `MinSize > 0`, `Groups.Count > 0`, etc. | Folded into [FP-43717](https://fishingplanet.atlassian.net/browse/FP-43717) |

**Priority:** Medium (depends on CFG-007)

---

**Status update:** Folded into [FP-43717](https://fishingplanet.atlassian.net/browse/FP-43717) acceptance criteria. If `MaxRating` is eliminated (CFG-007 → FP-43717 Option A) the old overlap/gap checks become structurally impossible (boundaries are derived from sorted `MinRating`); the only validations that survive are `brackets[0].MinRating == 0` and strict-ascending `MinRating` order. Captured directly in FP-43717.
