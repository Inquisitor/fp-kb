### CFG-002. `CanceledIfIncomplete` — in TDD, not in code

- **TDD:** `bool, default true` — "if the group still has less members than MinSize, competitive activity is canceled
  for players in the group."
- **Code:** `TournamentGroup.IsCanceled` (was `TournamentSubgroup.IsCanceled`) exists (marked `[Obsolete]`), but no
  logic ever sets it to `true`. `TournamentGroupParticipant.IsCanceled` also exists, unused.

**Decision:** Feature not released. Remove from TDD and remove obsolete fields from code.

| Action                                                  | Status |
|---------------------------------------------------------|--------|
| **GDD:** No mention — no changes.                       | N/A    |
| **TDD:** Remove all mentions of `CanceledIfIncomplete`. | DONE   |
| **Code:** See DCD-002, DCD-005.                         | DONE   |

**Priority:** Low (documentation cleanup)
