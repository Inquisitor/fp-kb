---
id: BCK-003
title: Screenshots endpoint (paged)
slice: VS3
status: todo
depends-on: [DAT-001]
effort: S
---

## Scope
Add `Action Screenshots(string userId, DateTime from, DateTime to, int page = 1, int pageSize = 20)` returning shape from [architecture → Screenshots](../architecture.md#screenshots-get-anticheatgamesessionanalysisscreenshots). Uses extended DAL signature.

## Files
- Modify: `Areas/Anticheat/Controllers/GameSessionAnalysisController.cs` — add `Screenshots`
- Create: `Areas/Anticheat/Models/GameSessionAnalysis/GameSessionAnalysisScreenshotsModel.cs`
- Modify: `WebAdmin.csproj` — `<Compile>` for new model

## Implementation notes
- `skip = (page - 1) * pageSize`, `take = pageSize`. Cap `pageSize` at 100 to prevent abuse; cap `page` at e.g. 10000 (avoid `OFFSET` blowups).
- `total` from `GetPlayerScreensCount(userId, from, to)`. Race window with concurrent inserts is acceptable — moderator pagination is not transactional.
- Image bytes are NOT bundled — UI continues to use `/Player/GetScreen?id=N` as documented.
- Date validation: same as BCK-001 — guard `from > to` or `DateTime.MinValue`, return 400 JSON.

## Exit criteria
- [ ] `/Anticheat/GameSessionAnalysis/Screenshots?userId=...&page=1&pageSize=20` returns first 20 + correct `total`
- [ ] `page=2` returns next 20 (and so on)
- [ ] Out-of-range page returns empty `items` with same `total`
