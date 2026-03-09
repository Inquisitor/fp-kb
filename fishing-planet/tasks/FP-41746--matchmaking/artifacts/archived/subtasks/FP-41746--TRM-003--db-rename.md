### TRM-003. Rename deferred DTO properties (P6-P14)

- **Code:** Nine classes still use `GroupId` instead of `BracketId`:
    - **DTO (P9-P12):** `ParticipantItemDto`, `TournamentIndividualResultsDto`,
      `TournamentParticipantDto`, `TournamentSecondaryResultDto`.
    - **Model (P6-P8):** `PlayerFinalResult`, `TournamentIndividualResults`,
      `TournamentSecondaryResult`.
    - **Runtime (P13-P14):** `ProfileTournament`, `ParticipantItem` (WebAdmin).
- **Blocker (DTOs P9-P12):** The custom DAL mapper `RestoreObjectFromReader` in `DtoExtensions.cs` maps
  DB column names to C# property names by **exact name match** via reflection. It does not support any
  mapping attributes. Renaming properties without enhancing the mapper would break all DAL reads.
- **Blocker (models P6-P8, P13-P14):** Populated from DTOs via `MakeCloneOf` / `MakeEqualTo`, which also
  use reflection with exact name matching. Renaming model properties without renaming DTOs would silently
  break the copy.
- **`GroupName` note:** All P6-P14 classes also have `GroupName`. Despite the name, it stores the **group
  name** (not the bracket name). `GroupName` does NOT need to be renamed to `BracketName` — it is already
  correct in the unified terminology.
- **Boundary analysis:** All 13 boundary points where `BracketId` (renamed) meets `GroupId` (deferred) have
  been validated as safe. See [Terminology-Rename-Plan.md](../Terminology-Rename-Plan.md) §Implications.
- **Depends on:** TRM-002 (DONE).

**Decision (revised 2026-03-08):** Rename DB columns directly instead of enhancing the DAL mapper.
Feature is deployed but disabled — columns contain no data. Atomic deployment with downtime.
Also removes `IsRated` (DCD-004) and participant `IsCanceled` chain (DCD-005) from DB.

| Action                                                                                          | Status |
|-------------------------------------------------------------------------------------------------|--------|
| **DB:** `sp_rename` `[GroupId]` → `[BracketId]` in 6 tables + update 18+ stored procedures.     | DONE   |
| **DB:** `REPLACE()` ConfigJson in `Tournaments`, `TournamentTemplates`, `ArchiveTournaments`.   | DONE   |
| **Code:** Rename `GroupId` → `BracketId` in P6-P14 classes. Remove `[JsonProperty]` attributes. | DONE   |

Full design: [TRM-003-DB-Rename-Design.md](../TRM-003-DB-Rename-Design.md)

**Priority:** Medium (unblocked by DB rename approach)