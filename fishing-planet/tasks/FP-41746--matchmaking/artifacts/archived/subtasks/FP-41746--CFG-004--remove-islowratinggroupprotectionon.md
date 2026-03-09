### CFG-004. `IsLowRatingGroupProtectionOn` — in TDD, removed from code

- **TDD:** `bool, default true` — "players from upper buckets are protected from joining lower buckets."
- **Code:** Flag removed from codebase. Only referenced in a stale test name
  `CreateGroups_LowRatingProtectionIsOn_AddsMinimalPossiblePlayers` (was `CreateSubgroups_...`).

**Decision:** Feature not released. Remove from TDD. Stale test — see TST-003.

| Action                                                          | Status |
|-----------------------------------------------------------------|--------|
| **GDD:** No mention — no changes.                               | N/A    |
| **TDD:** Remove all mentions of `IsLowRatingGroupProtectionOn`. | DONE   |
| **Code:** See TST-003.                                          | DONE   |

**Priority:** Medium
