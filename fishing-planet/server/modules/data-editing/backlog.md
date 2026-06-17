# Backlog — data-editing

- [ ] Drop the stale `DataChangesApply` table on DEV — leftover one-off staging from a 2023 `TournamentTemplates` import (143 rows, Apr–May 2023, marina/Fullgrimus); not part of the live `DataChanges`/`DataSyncLog` flow. Deferred (not now); confirm no consumer first, and drop the `DataChangesImport` dev `launchSettings.json` arg that still points at it.
