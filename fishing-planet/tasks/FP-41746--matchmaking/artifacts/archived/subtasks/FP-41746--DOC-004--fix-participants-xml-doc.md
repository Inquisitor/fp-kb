### DOC-004. `TournamentGroup.Participants` — incorrect XML doc

- **Code:** XML doc said `"List of User IDs of group's participants"` but the property type is
  `IList<TournamentGroupParticipant>` — a list of participant objects, not user IDs.

**Decision:** Fix XML doc.

| Action                                                     | Status |
|------------------------------------------------------------|--------|
| **Code:** Fix XML doc to `"List of group's participants."` | DONE   |

**Priority:** Low (found during TRM-002 review, 2026-02-18)
