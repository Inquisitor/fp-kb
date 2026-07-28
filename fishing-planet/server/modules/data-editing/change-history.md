# Reading the admin change history (`DataChanges`)

`DataChanges` is the append-only audit of edits made through the admin panel. It is the only way to
reconstruct who changed a content row and when — no content table carries its own history.

## Where it lives and when it is written

The row is inserted by `DataCapture.CaptureInsert / CaptureUpdate / CaptureDelete` into `DataChanges`
in the **same `Main` database as the edited row**, on a separate connection — the capture is not part
of the edit's transaction, so a failed capture does not roll the edit back.

Capture is gated once at startup by `DataCapture.Init(Settings.IsDev && Settings.IsDataEditable)`
(WebAdmin `Global.asax`), where `IsDataEditable` is `!IsProd && !IsQa && !IsEnvironmentDataFreeze`.
`EnvironmentController` re-runs the same `Init` when the data-freeze flag is toggled.

The consequence decides where to look: the history exists on the **authoring (Dev) environment**. The
same content on TEST / QA / PROD arrives there by DataPump, which copies content rows and not the
audit — those environments hold no `DataChanges` rows for that edit.

Writers beyond the generic grid: `Translations` and `Images` (Shared/DataEditing) and the
translation-management models capture their own inserts/updates/deletes with hand-built payloads.

## Payload shape

`ChangeType` is `C` / `U` / `D`; `CreatedBy` is the admin identity, `Comment` the edit comment the
panel requires.

- **`C`** — `OldValues` null, `NewValues` = full entity snapshot.
- **`U`** — `CrudHelper` builds before/after snapshots and calls `CaptureDataSet.CompressUpdate`,
  which drops every column whose value is equal on both sides while keeping the primary key. An
  update that changes nothing is not written at all. So `U` rows carry **PK + genuinely changed
  columns only** — the absence of a column means "untouched", not "null".
- **`D`** — `OldValues` = full snapshot, `NewValues` null.

`CaptureDataSet.FromReader` skips `DBNull`, so in a full snapshot a missing key means the column was
null. Do not read a `C`/`D` snapshot as an exhaustive column list.

## Lookup recipe

The primary key is present on every change type, which makes it the reliable selector:

```sql
SELECT CONVERT(varchar(19), [Timestamp], 120) + ' [' + ChangeType + '] by ' + CreatedBy
       + ' OLD=' + ISNULL(OldValues, '-') + ' NEW=' + ISNULL(NewValues, '-')
FROM dbo.DataChanges WITH (NOLOCK)
WHERE TableName = '<Table>'
  AND (OldValues LIKE '%"<PkColumn>":<id>,%' OR NewValues LIKE '%"<PkColumn>":<id>,%')
ORDER BY [Timestamp];
```

Aggregate the result into a single row (`STRING_AGG`) when completeness matters — the DB-access tool
truncates long row sets without a marker, and a partial history reads as a complete one.

Keep the trailing comma in the `LIKE` token: `"TaskId":15682,` does not match `"TaskId":156820`.

## What never reaches this table

Changes applied outside the admin panel leave no trace here:

- SQL patches under `<project>/SQL/Patches` (applied by `SQLCheck` at release)
- release-only scripts under `<project>/SQL/Releases`
- one-off manual queries against the DB

These are the exception, not the rule — typically a fix the admin panel cannot express, or a bulk
correction. By convention such a change carries a script, either in VCS or attached to its JIRA task,
so the audit trail is there rather than in `DataChanges`.

## Tooling — read the table directly

Two projects in the tree touch this data. Neither is a working tool today; do not route a question
about the change history through them.

- `DataChangesImport` (`<project>/Photon/tools`) — replays a `DataChanges` table onto a target DB.
  Written for a single import and never generalized; the read-only join-leak gotcha in
  [`_card.md`](_card.md) came out of that one run. Content promotion between environments is
  DataPump's job, not this.
- `DataSyncDashboard` (`<project>/WebAdmin`) — a browse/sync UI over the change stream, abandoned.
  Its whole visible history in the branch lineage is branch-creation copies plus two repo-wide
  sweeps (a log4net UTC config change and a Newtonsoft.Json bump) — no functional commit. Reviving it
  would cost more than rewriting it.

Query the table directly with the recipe above.
