---
id: BCK-003
title: Screenshots endpoint (paged)
slice: VS3
status: done
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
- [x] Endpoint shape matches architecture (`{ items, total, page, pageSize }`)
- [x] `/Anticheat/GameSessionAnalysis/Screenshots?userId=...&page=1&pageSize=20` returns first 20 + correct `total` *(verified via TST-002 smoke 2026-05-04)*
- [x] `page=2` returns next 20 *(verified via TST-002 smoke 2026-05-04 — Prev/Next pagination exercised)*
- [ ] Out-of-range page returns empty `items` with same `total` *(not explicitly exercised; defensive `Math.min/max` clamps in model are code-reviewed only)*

## Implementation notes (DONE 2026-05-03)
- Page/pageSize clamped server-side: `pageSize ∈ [1, 100]`, `page ∈ [1, 10000]` — protects against `OFFSET` blow-up and abuse.
- `total` from separate `GetPlayerScreensCount` call before paged read. Race acceptable per architecture.
- Image bytes NOT bundled — UI continues using `/Player/GetScreen?id=N`.
- Reuses `ValidateInputs` from BCK-001/002 (same userId / from / to guards).
- Frontend: `useApiClient.fetchScreenshots` switched from stub to real `getJson` call.
