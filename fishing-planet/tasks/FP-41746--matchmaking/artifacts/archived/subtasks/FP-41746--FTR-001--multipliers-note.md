### FTR-001. Separate rewards per group

- **GDD:** "In next iterations, rewards of different value per group."
- **Code:** `RatingMultiplier` and `RewardMultiplier` exist in `TournamentGroupSettings` but are not applied in
  matchmaking (applied during reward distribution separately).

**Decision:** No action needed now. Document status.

| Action                                                                                                                                          | Status |
|-------------------------------------------------------------------------------------------------------------------------------------------------|--------|
| **GDD:** Already marked as future iteration. No changes.                                                                                        | N/A    |
| **TDD:** Add note: "RatingMultiplier and RewardMultiplier are stored in config and applied during reward distribution, not during matchmaking." | DONE — new spec (page 5505613835), Section 3.4 |
| **Code:** No changes needed.                                                                                                                    | N/A    |

**Priority:** Low (documentation only)
