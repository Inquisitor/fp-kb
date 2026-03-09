### ALG-008. Minimum participants to start — handled outside MatchmakingLogic

- **GDD:** "< 20 registered players — competition doesn't start."
- **Code:** Handled in `TournamentStartAdapter` via `MinParticipants` check before calling `ProcessGrouping`.
  `MatchmakingLogic` itself has no minimum check.

**Decision:** No discrepancy. GDD describes business rule, code implements it in `TournamentStartAdapter`. No changes
needed.

| Action                       | Status |
|------------------------------|--------|
| **GDD:** No changes needed.  | N/A    |
| **TDD:** N/A                 | N/A    |
| **Code:** No changes needed. | N/A    |

**Priority:** N/A (no action required)
