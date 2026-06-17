---
module: data-editing
---

# data-editing

Generic admin table-editing layer (WebAdmin `TableEditModel` grids) backed by a `DataChanges`
commit-log. Every admin edit asks for a comment and records the old/new delta + author; the log can
later be extracted, replayed, or rolled back for recovery / propagation.

## Entry Points
- `CrudHelper.UpdateData / InsertData / DeleteData` (Shared/DataEditing) — CRUD + change capture
- `DataCapture.CaptureUpdate` — INSERTs one row into `DataChanges`
- `DataChangesImport` (Photon/tools) — replays a DataChanges table onto a target DB (one-off DB-corruption-repair tool per FP-43424, not the live pipeline — that is DataPump)

## Key Types
- `DataChanges` table — DataChangeId (GUID PK), TableName, ChangeType (C/U/D), OldValues/NewValues
  (JSON delta), CreatedBy, Timestamp (default `getutcdate()`), Comment
- `CaptureDataSet : Dictionary<string,object>` — `CompressUpdate(prior, pkColumns)` keeps only PK +
  columns whose value differs between before and after; payload = those keys as JSON

## Gotchas
- **Read-only join leak.** `CaptureDataSet.FromObject` serializes *all* public entity properties,
  including `[Readonly]` joined columns (e.g. `LocalShop` exposes Currency / OriginalPrice from
  `InventoryItems`). The before-entity often has them unpopulated (null/0) while the after-entity is
  populated, so `CompressUpdate` treats them as "changed" and keeps them. `DataChangesImport.SyncChanges`
  then builds `UPDATE <table> SET <every non-PK key> WHERE <PK>` — and those columns do not exist on the
  base table, so the row **fails to import**. When reproducing the audit from a SQL script, emit only
  real table columns (PK + actually-changed columns).
- Replay keys rows by PK; identity PKs can differ across environments.

## Related Tasks
- FP-44465 (2026-06): scripted `LocalShop` price changes reproduced the audit as clean `{ShopId, Price}`
  rows (Currency/OriginalPrice deliberately excluded). See [local-shop](../local-shop/_card.md).
