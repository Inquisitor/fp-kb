### CFG-003. `NotRatedIfIncomplete` — in TDD, not in code

- **TDD:** `bool, default false` — "if the group still has less members than MinSize, rating is not calculated for this
  group."
- **Code:** `TournamentGroup.IsNotRated` (was `TournamentSubgroup.IsNotRated`) exists (marked `[Obsolete]`), but no
  logic ever sets it to `true`. `TournamentGroupParticipant.IsNotRated` also exists, unused.

**Decision:** Feature not released. Remove from TDD and remove obsolete fields from code. Investigate `IsRated` columns
in DB tables `TournamentParticipant*` — may keep as groundwork for future.

| Action                                                                                                                                       | Status |
|----------------------------------------------------------------------------------------------------------------------------------------------|--------|
| **GDD:** No mention — no changes.                                                                                                            | N/A    |
| **TDD:** Remove all mentions of `NotRatedIfIncomplete`.                                                                                      | DONE   |
| **Code:** Investigate `IsRated` columns in `TournamentParticipant*` DB tables — decide: keep or remove. Field removal: see DCD-001, DCD-004. | DONE   |

**Priority:** Medium (DB investigation + documentation cleanup)
