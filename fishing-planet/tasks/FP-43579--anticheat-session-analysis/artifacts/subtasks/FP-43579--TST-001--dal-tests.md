---
id: TST-001
title: DAL tests for date-range + paging
slice: VS5
status: deferred-post-v1
depends-on: [DAT-001]
effort: M
---

## Deferred 2026-05-04

`Sql.MsSql.Tests` has no `IAnalyticsProvider` fixture — scaffolding from
scratch (DB connection, Stats.Screens seeding, ~7 cases) is ~2-4 h for one
edge case. The single existing caller (`ScreensModel.cs:15`) uses defaults
unchanged; the new optional parameters are only exercised by our endpoint,
which is covered by manual smoke (TST-002). Architecture already deferred
controller/model unit tests on the same blast-radius / scaffolding-cost
argument; DAL is the symmetric case.

Tracked in [backlog → DOC-001-tests](../backlog.md). Reconsider if Phase 4
anomaly scoring lands testable business logic.

## Scope
Add `Sql.MsSql.Tests` cases covering the new optional parameters of `GetPlayerScreens` and the new `GetPlayerScreensCount`.

## Files
- Modify or create: `Dal/Sql.MsSql.Tests/Analytics/SqlAnalyticsProvider*Tests.cs`

## Test cases (minimum)
1. `GetPlayerScreens(userId)` — preserves prior behavior (no filter, no paging)
2. `GetPlayerScreens(userId, from, to)` — returns only rows in range
3. `GetPlayerScreens(userId, null, null, skip: 5, take: 10)` — OFFSET/FETCH applied
4. `GetPlayerScreens(userId, from, to, skip, take)` — combined
5. `GetPlayerScreensCount(userId, from, to)` — agrees with full unpaged query length
6. Empty range → empty + count 0
7. `take = 0` — defines edge behavior (return empty? reject? document and assert)

## Implementation notes
- Use existing test infra (database fixture / seeded data).
- If `Sql.MsSql.Tests` lacks an `IAnalyticsProvider` test fixture, scaffold one minimally (insert N rows with controlled timestamps, run query, assert).
- Tests may require `[TestCategory("RequiresSql")]` if local SQL is needed — check existing convention.

## Exit criteria
- [ ] `dotnet test Dal/Sql.MsSql.Tests/Sql.MsSql.Tests.csproj --no-build` — all green
- [ ] Coverage measurable via existing coverlet config (no separate setup needed)
