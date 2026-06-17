# data-editing — decision log

2026-06-17 FP-44465: needed to reproduce the admin DataChanges audit from a SQL script (bulk
`LocalShop.Price` change) so the change carries author + comment and is replay/restore-able.
- Verified the capture format from a real admin edit (DataChangeId f8c5f767...): a LocalShop price
  edit produced `OldValues {"ShopId":218,"Currency":null,"Price":6.0,"OriginalPrice":0.0}` →
  `NewValues {"ShopId":218,"Currency":"SC","Price":600.0,"OriginalPrice":550.0}`.
- Found the read-only join leak (Currency/OriginalPrice) and confirmed via `DataChangesImport.SyncChanges`
  that such records would break the replay (`UPDATE LocalShop SET Currency=..., OriginalPrice=...` — no
  such columns). Decision: scripted captures emit only PK + real changed columns (`{ShopId, Price}`),
  which both preserves the audit and replays cleanly.
- Decision: leave `Timestamp` to the column default (`getutcdate()`), matching `DataCapture`.

2026-06-17 `DataChangesApply` is NOT part of the live flow — it is a leftover one-off staging table.
- Live path: edits → `DataChanges` (commit-log) → consumed by `DataSyncDashboard` (`DataChanges` + `DataSyncLog`).
- `DataChangesImport` reads whatever table is passed as `args[0]`; its dev `launchSettings.json` still
  passes `DataChangesApply`. On DEV that table holds 143 rows, Apr–May 2023, `TournamentTemplates` only
  (authors marina/Fullgrimus) — a single past import, untouched since. Absent on the local DB.
- FP-43424 (pass-1) classifies `DataChangesImport` itself as a one-off tool "used to repair DB corruption
  once" — not the live pipeline (that is `DataPump`). So both the tool and the 2023 `DataChangesApply` rows
  are one-off-repair leftovers, not standard sync.
- Lesson: do not mistake `DataChangesApply` / `DataChangesImport` for the sync mechanism. Drop candidate (deferred — see backlog).
