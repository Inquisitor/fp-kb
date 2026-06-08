---
status: completed
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-44245
related: FP-44247, FP-44248, FP-43942
---
# FP-44245: Pedal Kayak Server Support in UGC Competitions

## Status
Completed. The server now allows the pedal kayak in UGC custom competitions: committed MFT r16155, merged to the Code branch NPN r16156. QA-verified and closed, no issues. The design (pedal kayak as a **separate** equipment entry, not folded into the regular kayak) was confirmed by GD in a 4-way call (Andrii Maslov, Vitaliy Belenok, Kyrylo Rovnyi, Stanislav Samoilov).

## Summary

### Goal
Make the pedal kayak usable in UGC (user-generated) custom competitions on par with the regular kayak — equip it, board in 3D, and have catches scored. Server half of the client change FP-44247 (client CodeBranch r55159).

### Root cause
The UGC competition boat whitelist (`TournamentEquipment.BoatTypes`) only ever contained the regular kayak subtype. On boarding, the server rejects any boat type absent from that whitelist (`MultiRodGameProcessor.HandleBoard()` -> "Wrong BoatType" + anti-cheat) and excludes its catches from scoring (`TournamentAdapter`). So the pedal kayak (`ItemSubTypes.PedalKayak = 199`) never boarded in a UGC competition. The rented pedal kayak is the same subtype, so the same fix covers it.

### Implementation (separate-entry model)
Mirrored the client's separate enum member rather than folding the pedal kayak into the regular kayak:
- `UserCompetitionEquipmentAllowed.PedalKayak = 199` added (matches the client enum and `ItemSubTypes.PedalKayak`).
- Mapped into `BoatTypes` on save (`UGCProcess_02_SaveLoadRemove.UGCToItemSubTypes`).
- Advertised in the default competition metadata `DollEquipment`, plus a `BoatTypes -> DollEquipment` reverse-map branch for round-trip on load (`UGCProcess_01_GetMetadata`).
- Round-trip test `UGCHostCreateUserCompetition_Custom_with_Kayak_and_PedalKayak`.

### Design decision (separate vs combined)
Two models were on the table: (A) a separate, independently-selectable pedal-kayak entry; (B) one combined "Kayak and Pedal Kayak" option (folded into the regular kayak). The client (r55159) implemented A; an open GD text ticket (FP-44248) asked for B. Resolved in a 4-way call in favour of **A (separate)**. Had B won, the cleaner server shape would have been expanding `Kayak -> {Kayak, PedalKayak}` (like `MotorBoats_All`) and dropping the separate enum member; that path was not taken.

## Plan
Single bugfix commit + cross-branch merge. See [backlog.md](backlog.md).

## Related
- **FP-44247** — sibling bug: pedal kayak missing from the competition Detail window. Shares this same server support; the client-side Detail-window rendering is finished separately by Kyrylo Rovnyi. -> [journal](../FP-44247--pedal-kayak-ugc-detail-window/journal.md)
- **FP-44248** — GD text task (combine into "Kayak and Pedal Kayak"); rejected in favour of the separate model -> [JIRA](https://fishingplanet.atlassian.net/browse/FP-44248)
- **FP-43942** — parent -> [JIRA](https://fishingplanet.atlassian.net/browse/FP-43942)
- Client change: CodeBranch r55159 (FP-44247).
- No KB module card exists for UGC competition equipment yet (Tournaments group currently has only `matchmaking`).

## Milestones
- 2026-06-07: FP-44245 reopened (server support needed). Traced root cause: the UGC `BoatTypes` whitelist never included `ItemSubTypes.PedalKayak (199)`; `HandleBoard()` rejects non-whitelisted boats and `TournamentAdapter` drops their catches. Reviewed client diff r55159 (FP-44247): separate `UserCompetitionEquipmentAllowed.PedalKayak = 199` enum member + create-flow wiring.
- 2026-06-07: Implemented the server mirror (separate-entry model) — enum + `BoatTypes` mapping + metadata default + reverse map. Build green (LoadBalancing.sln, 0 errors). Added round-trip test. Committed MFT r16155.
- 2026-06-07: Merged MFT r16155 -> NPN (Code) r16156. Clean merge, no conflicts. NPN had a pre-existing unrelated build break (missing `Shared/SharedLib/Profile/InitialSpawnHelper.cs`, referenced but not committed) — not caused by this change; flagged to devops.
- 2026-06-07: Posted combined commit+merge note to FP-44245.
- 2026-06-08: Reviews (/code-review + senior review) — server change correct and complete. Two findings: (1) the FP-44247 Detail-window client code (`TournamentDetailsMessageNew`) still lacks the pedal kayak (`FillRules`/`FillDeniedEquipment` have no `PedalKayak` case) — client-side, owned by Kyrylo Rovnyi; (2) old clients without the enum member would fail to parse the new value, mooted by the forced-update synchronous client+server deploy.
- 2026-06-08: 4-way call (Andrii Maslov, Vitaliy Belenok, Kyrylo Rovnyi, Stanislav Samoilov) — design fixed as **separate** (model A). FP-44248 (combine) to be closed by GD. Server-support note to be added on the sibling tickets.
- 2026-06-08: QA verified FP-44245 and closed it, no issues.
