---
id: DAT-001
title: Extend GetPlayerScreens with date-range + paging; add Count
slice: VS3
status: todo
depends-on: []
effort: S
---

## Scope
Variant B per [architecture → DAL changes](../architecture.md#dal-changes-extend-getplayerscreens-with-optional-date-range-paging). Existing single-arg method preserved (defaults make it a no-op for `WebAdmin/Models/Players/Logs/ScreensModel.cs:15`).

```csharp
// Sql.Interface/Analytics/IAnalyticsProvider.cs
IEnumerable<ScreenDto> GetPlayerScreens(
    Guid userId,
    DateTime? from = null, DateTime? to = null,
    int? skip = null, int? take = null);

int GetPlayerScreensCount(
    Guid userId,
    DateTime? from = null, DateTime? to = null);
```

## Files
- Modify: `Dal/Sql.Interface/Analytics/IAnalyticsProvider.cs` — interface signature change
- Modify: `Dal/Sql.MsSql/Analytics/SqlAnalyticsProvider.cs` — extend SQL with optional `AND Timestamp >= @from AND Timestamp <= @to` plus `OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY` (when both non-null); add `GetPlayerScreensCount` method (single `SELECT COUNT(*) WITH (NOLOCK)`)
- Verify untouched: `WebAdmin/Models/Players/Logs/ScreensModel.cs` — call site continues to work via default args

## Preconditions (verified in [backlog](../backlog.md))
- 1 impl, 0 Moq mocks, 1 caller
- `WebAdmin.Tests` has zero references; risk in `Sql.MsSql.Tests` only
- Retention 14d verified — no UI implication

## Implementation notes
- SQL with WITH (NOLOCK) on every reference (per session feedback rule).
- `OFFSET/FETCH` requires `ORDER BY` — already present (`ORDER BY Timestamp DESC`). Most recent first; `OFFSET 0` returns latest.
- **Skip/take semantics**: paging applies when `take.HasValue`. In that case, `skip ?? 0` is used as offset (skip alone without take is silently ignored — paging requires both, but `take` alone is a valid «top N latest» query). Without `take`, OFFSET/FETCH is omitted entirely → unbounded result preserved (existing caller behavior).
  ```csharp
  // Pseudo-SQL building:
  if (take.HasValue) {
      sql += " OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY";
      cmd.Parameters.Add("@skip", SqlDbType.Int).Value = skip ?? 0;
      cmd.Parameters.Add("@take", SqlDbType.Int).Value = take.Value;
  }
  ```
- Date predicates similarly conditional: append `AND Timestamp >= @from` / `AND Timestamp <= @to` only when each is non-null. Existing caller (`ScreensModel.cs:15`) passes neither → unchanged SQL.

## Exit criteria
- [ ] Interface compiles, all consumers updated
- [ ] `Sql.MsSql.Tests` green (`dotnet test --no-build`)
- [ ] Existing `/Player/Screens?userId=...` still returns full list (verify in browser)
- [ ] Manual SQL trace: query plan uses `IX_Screens_UserId` (or whichever index exists) without scan blow-up at large `skip`
