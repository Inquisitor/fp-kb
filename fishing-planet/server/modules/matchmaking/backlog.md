# Backlog — Matchmaking

- [x] Update Confluence matchmaking page — published as new spec on page 5505613835 (FP-41746)
- [ ] Document `Rational` struct in KB
- [x] Phase 2 + Phase 7 documentation pass (alignment plan) — FP-41746
- [x] Phase 5 cosmetic refactoring (CFG-007) — moved to [FP-43717](https://fishingplanet.atlassian.net/browse/FP-43717)
- [ ] Add missing runtime validation — folded into [FP-43717](https://fishingplanet.atlassian.net/browse/FP-43717) ACs
- [ ] Categorize 4-bracket test cases — bubbled from FP-41746 RES-001 → [details](../../../tasks/FP-41746--matchmaking/artifacts/archived/subtasks/FP-41746--RES-001--categorize-4-bracket-tests.md). Revisit after upcoming bucket-evaluation change
- [ ] Investigate 5+ bracket / degenerate edge-case categories — bubbled from FP-41746 RES-002 → [details](../../../tasks/FP-41746--matchmaking/artifacts/archived/subtasks/FP-41746--RES-002--investigate-edge-categories.md). Depends on the categorization task above
- [x] DCD-004/005/CFG-003 DB decommissioning — done in Phase 8 (r15898)
- [ ] Log rating application unconditionally — the ledger write in `GameClientPeer_Tournaments` is conditional on the rating having changed, so a penalty clamped at the PCR 0 floor leaves no record at all. Emitting the line regardless (including zero movement) keeps the ledger a faithful audit trail and removes the need for an SQL cross-check. Surfaced by FP-43631 week-12, where an account showed 21 assessed penalties and zero ledger lines across three days — see [rating application](rating-application.md)
