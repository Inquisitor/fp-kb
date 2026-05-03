---
id: BCK-001
title: MonitorInfo endpoint (cheapest end-to-end)
slice: VS1
status: todo
depends-on: []
effort: M
---

## Scope
Add `Action MonitorInfo(string userId, DateTime from, DateTime to)` to `GameSessionAnalysisController` returning the JSON shape from [architecture → MonitorInfo](../architecture.md#monitorinfo-get-anticheatgamesessionanalysismonitorinfo). No DAL change — uses existing `MongoDiagProvider.SysInfo.Find(userId, start, end)`.

## Files
- Modify: `Dal/NoSql.Mongo/Diag/MongoDiagProvider.cs` — add `Find(string userId, DateTime start, DateTime end)` to `MongoSysInfoProvider`, mirroring `MongoErrorProvider.Find(userId, start, end)` already in the same file (`MongoDiagProvider.cs:146`)
- Modify: `WebAdmin/WebAdmin/Areas/Anticheat/Controllers/GameSessionAnalysisController.cs` — add `MonitorInfo` action
- Create: `WebAdmin/WebAdmin/Areas/Anticheat/Models/GameSessionAnalysis/GameSessionAnalysisMonitorInfoModel.cs` — `Fill(userId, from, to)` + `Data` projection
- Modify: `WebAdmin/WebAdmin/WebAdmin.csproj` — `<Compile Include="...">` for new model

## Implementation notes
- Model follows existing `MongoLogModel` pattern (Fill + Data anonymous projection).
- New `MongoSysInfoProvider.Find(userId, start, end)` — review `MongoErrorProvider.Find(userId, start, end)` (`MongoDiagProvider.cs:146`) for the **semantics** that need to carry over: UTC normalisation of bounds (`new DateTime(x.Ticks, DateTimeKind.Utc)`), filter shape `Query.And(EQ UserId, GTE Timestamp, LTE Timestamp)`. Decide on `NoSqlStats.ExecuteWithStats(...)` wrapping based on what `MongoSysInfoProvider`'s **own** existing methods do (`SaveSysInfo`, `Find(userId)`) — match that class's convention, not Error's.
- Server-side parse of `Monitor` field: keep raw string in `monitor`, populate `distinctValues` via LINQ `.Select(x => x.Monitor).Distinct().ToList()`.
- Date validation: if `from > to` or both default → return `JsonResponse(new { error = "Invalid date range" })` with HTTP 400. Same pattern in BCK-002, BCK-003. Default `DateTime` for unbound MVC params is `DateTime.MinValue` — guard at action entry.

## Exit criteria
- [ ] `/Anticheat/GameSessionAnalysis/MonitorInfo?userId=...&from=...&to=...` returns valid JSON shape under `[CustomAuthorize(Roles="Abuse")]`
- [ ] Manual call via browser with a known userId returns expected `distinctValues`
- [ ] No regression in existing `Player/SysLog` (which also uses `MongoSysInfoProvider.Find`)
