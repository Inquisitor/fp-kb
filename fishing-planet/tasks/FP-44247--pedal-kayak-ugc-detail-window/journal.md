---
status: completed
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-44247
related: FP-44245
---
# FP-44247: Pedal Kayak in UGC Competition Detail Window

## Status
Server side done — the pedal-kayak server support is shared with FP-44245 (same enum + `BoatTypes` work, MFT r16155 / NPN r16156). The client-side Detail-window rendering (`TournamentDetailsMessageNew`) is finished separately by Kyrylo Rovnyi. Separate-entry model confirmed by GD (see FP-44245).

## Summary
Sibling of FP-44245. FP-44245 = pedal kayak unusable in 3D; FP-44247 = pedal kayak not listed in the competition Detail window's allowed-boats. Both were stamped with the same client commit (CodeBranch r55159) and both required the same server support, which is implemented and documented under FP-44245. The full history (root cause, implementation, design decision) lives in the FP-44245 card.

Note: as of the server work, the client Detail-window code (`TournamentDetailsMessageNew.FillRules` / `FillDeniedEquipment`) did not yet render the pedal kayak under the separate-entry model — flagged to Kyrylo Rovnyi as the remaining client-side piece.

## Plan
No separate server plan — the server support is delivered and documented under [FP-44245](../FP-44245--pedal-kayak-ugc-server-support/journal.md). Remaining client-side Detail-window work is owned by Kyrylo Rovnyi.

## Related
- **FP-44245** — main card: full history, server implementation, and the separate-vs-combined design decision -> [journal](../FP-44245--pedal-kayak-ugc-server-support/journal.md)

## Milestones
- 2026-06-08: Server support delivered under FP-44245 (MFT r16155 / NPN r16156); the same enum + `BoatTypes` work covers this ticket's server need. Review noted the client Detail-window rendering still needs the pedal kayak (separate-entry model) — client-side, owned by Kyrylo Rovnyi. Design confirmed "separate" in the 4-way GD call.
