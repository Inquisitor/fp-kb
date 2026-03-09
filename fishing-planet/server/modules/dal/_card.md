---
module: dal
---

# Data Access Layer (DAL)
> Repository-pattern abstraction over SQL Server and MongoDB with reflection-based mapping.

## Entry Points
- `DalFactory` — `Dal/DalFactory/DalFactory.cs` (DI container for DAL implementations)
- `DtoExtensions.RestoreObjectFromReader()` — `Dal/Dal.Common/DtoExtensions.cs` (read path: DB→DTO, exact name match, silent skip on mismatch)
- `MsSqlHelper.ExtractParamsFromDto()` / `ExtractParamsFromObject()` — `Dal/Sql.MsSql/Common/MsSqlHelper.cs` (write path: DTO→SQL params) *(UNVERIFIED)*

## Key Types
- `IDalProvider` — top-level DAL interface aggregating all sub-providers
- `DtoExtensions` — reflection mapper: DB columns → C# properties by **exact name match** (no attribute support)
- `MakeCloneOf`/`MakeEqualTo` — reflection-based property copy between objects (also exact name matching)

## Dependencies
→ SQL Server: `Sql.MsSql/` (stored procedures, `System.Data.SqlClient`)
→ MongoDB: `NoSql.Mongo/` (MongoDB.Driver 2.13.0)
← All server components: GameServer, WebAdmin, AsyncProcessor consume via `IDalProvider`

## Deep Dives
Interfaces: `Dal/DalAbstraction/`, `Dal/Sql.Interface/`, `Dal/NoSql.Interface/`
Tests: `Dal/Dal.Common.Tests/`, `Dal/Sql.MsSql.Tests/`, `Dal/NoSql.Mongo.Tests/`

## Related Tasks
- FP-41746: TRM-003 discovered DAL mapper constraints — DTO/model properties must rename synchronously with DB columns

See also: [backlog](backlog.md) | [log](log.md)
