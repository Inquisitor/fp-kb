# Analytics read-only access (Stats copy) — `stats_analyst_ro`

Dedicated read-only login used by the analytics / LLM-analyst tooling.

## What

A single impersonal SQL login **`stats_analyst_ro`** on the consolidated **Stats COPY**
instance ("ALL STATS DB"), which hosts a copy of every platform's Stats database:
`SteamStats`, `PsStats`, `XbStats`, `MobStats`, `NxStats`.

- `db_datareader` in all 5 databases — read-only, no write / DDL / execute.
- Column-level `DENY SELECT` on identity / payment-linkage columns
  (`Username`, `ExternalId`, `ForegnTransactionId`) wherever they occur.

## Why

- **Analytics needs a durable read-only endpoint** — a dedicated impersonal principal (not a
  personal account) gives stable, least-privilege access for ad-hoc analytical queries.
- **Queries hit the copy, not live PROD** — heavy analytical scans run on the copy instance and
  never load the live per-platform PROD Stats clusters.
- **Pseudonymous by design** — Stats data is keyed by the GUID `UserId`. The only columns that map
  that GUID back to a real identity are `Username` and `ExternalId` (external platform account id,
  e.g. SteamID64). Denying them keeps all fact/aggregate analytics working while preventing
  de-pseudonymization. `ForegnTransactionId` (external payment reference) is denied — payment-system
  linkage, no analytical value. Revenue columns (`Price`, `EquivalentPrice`, `Currency`) stay readable.
- Stats holds no classic PII columns (no email/name/IP/password-hash — those live in the MAIN DBs).

## Applying

Run the script below as `sysadmin`/`securityadmin` **on the Stats copy instance only**. It is
idempotent. On a fresh instance, set a strong password (placeholder in the script) and store it in
the secrets manager. The DENY matches by column name, so it adapts to per-platform schema differences
automatically (e.g. Mobile/Nintendo `Users` have no `ExternalId`).

Consumer side: set a command timeout (60-120s) and a row cap on the analyst connection — there is no
server-side Resource Governor limit.

## Setup script

```sql
/* Analytics read-only login for the consolidated Stats COPY instance ("ALL STATS DB").
   Principal : SQL login [stats_analyst_ro]
   Grants    : db_datareader in SteamStats / PsStats / XbStats / MobStats / NxStats
   Restricts : column-level DENY SELECT on Username / ExternalId / ForegnTransactionId
   Idempotent: safe to re-run. RUN AS sysadmin/securityadmin ON THE COPY INSTANCE ONLY.
   Fresh instance: replace <<REPLACE_WITH_STRONG_PASSWORD>> and store the secret securely. */

-- Part 0 - server login (master)
USE [master];
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE [name] = N'stats_analyst_ro')
BEGIN
    CREATE LOGIN [stats_analyst_ro]
        WITH PASSWORD        = N'<<REPLACE_WITH_STRONG_PASSWORD>>',
             CHECK_POLICY     = ON,
             CHECK_EXPIRATION = OFF,
             DEFAULT_DATABASE = [SteamStats];
END
GO

-- Per-database access. Identical block per DB except the USE statement:
--   1) create the DB user mapped to the login (if missing)
--   2) add it to db_datareader (read-only; no writer/ddl/execute)
--   3) DENY SELECT on any column named Username / ExternalId / ForegnTransactionId (tables + views),
--      by column NAME so archive/temp tables and future look-alikes are covered on re-run.

-- SteamStats
USE [SteamStats];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE [name] = N'stats_analyst_ro')
    CREATE USER [stats_analyst_ro] FOR LOGIN [stats_analyst_ro];
ALTER ROLE [db_datareader] ADD MEMBER [stats_analyst_ro];
GO
DECLARE @deny nvarchar(max) = N'';
SELECT @deny = @deny + N'DENY SELECT ON OBJECT::' + QUOTENAME(s.[name]) + N'.' + QUOTENAME(o.[name])
     + N' (' + QUOTENAME(c.[name]) + N') TO [stats_analyst_ro];' + NCHAR(10)
FROM sys.columns c
JOIN sys.objects o ON o.[object_id] = c.[object_id]
JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] IN ('U', 'V')
  AND c.[name] IN (N'Username', N'ExternalId', N'ForegnTransactionId');
IF @deny <> N'' EXEC sys.sp_executesql @deny;
GO

-- PsStats
USE [PsStats];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE [name] = N'stats_analyst_ro')
    CREATE USER [stats_analyst_ro] FOR LOGIN [stats_analyst_ro];
ALTER ROLE [db_datareader] ADD MEMBER [stats_analyst_ro];
GO
DECLARE @deny nvarchar(max) = N'';
SELECT @deny = @deny + N'DENY SELECT ON OBJECT::' + QUOTENAME(s.[name]) + N'.' + QUOTENAME(o.[name])
     + N' (' + QUOTENAME(c.[name]) + N') TO [stats_analyst_ro];' + NCHAR(10)
FROM sys.columns c
JOIN sys.objects o ON o.[object_id] = c.[object_id]
JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] IN ('U', 'V')
  AND c.[name] IN (N'Username', N'ExternalId', N'ForegnTransactionId');
IF @deny <> N'' EXEC sys.sp_executesql @deny;
GO

-- XbStats
USE [XbStats];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE [name] = N'stats_analyst_ro')
    CREATE USER [stats_analyst_ro] FOR LOGIN [stats_analyst_ro];
ALTER ROLE [db_datareader] ADD MEMBER [stats_analyst_ro];
GO
DECLARE @deny nvarchar(max) = N'';
SELECT @deny = @deny + N'DENY SELECT ON OBJECT::' + QUOTENAME(s.[name]) + N'.' + QUOTENAME(o.[name])
     + N' (' + QUOTENAME(c.[name]) + N') TO [stats_analyst_ro];' + NCHAR(10)
FROM sys.columns c
JOIN sys.objects o ON o.[object_id] = c.[object_id]
JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] IN ('U', 'V')
  AND c.[name] IN (N'Username', N'ExternalId', N'ForegnTransactionId');
IF @deny <> N'' EXEC sys.sp_executesql @deny;
GO

-- MobStats
USE [MobStats];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE [name] = N'stats_analyst_ro')
    CREATE USER [stats_analyst_ro] FOR LOGIN [stats_analyst_ro];
ALTER ROLE [db_datareader] ADD MEMBER [stats_analyst_ro];
GO
DECLARE @deny nvarchar(max) = N'';
SELECT @deny = @deny + N'DENY SELECT ON OBJECT::' + QUOTENAME(s.[name]) + N'.' + QUOTENAME(o.[name])
     + N' (' + QUOTENAME(c.[name]) + N') TO [stats_analyst_ro];' + NCHAR(10)
FROM sys.columns c
JOIN sys.objects o ON o.[object_id] = c.[object_id]
JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] IN ('U', 'V')
  AND c.[name] IN (N'Username', N'ExternalId', N'ForegnTransactionId');
IF @deny <> N'' EXEC sys.sp_executesql @deny;
GO

-- NxStats
USE [NxStats];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE [name] = N'stats_analyst_ro')
    CREATE USER [stats_analyst_ro] FOR LOGIN [stats_analyst_ro];
ALTER ROLE [db_datareader] ADD MEMBER [stats_analyst_ro];
GO
DECLARE @deny nvarchar(max) = N'';
SELECT @deny = @deny + N'DENY SELECT ON OBJECT::' + QUOTENAME(s.[name]) + N'.' + QUOTENAME(o.[name])
     + N' (' + QUOTENAME(c.[name]) + N') TO [stats_analyst_ro];' + NCHAR(10)
FROM sys.columns c
JOIN sys.objects o ON o.[object_id] = c.[object_id]
JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] IN ('U', 'V')
  AND c.[name] IN (N'Username', N'ExternalId', N'ForegnTransactionId');
IF @deny <> N'' EXEC sys.sp_executesql @deny;
GO
```

## Verification / rollback

```sql
-- Verify (per DB): role membership should be exactly db_datareader; denied columns should list
--                  Username / ExternalId / ForegnTransactionId occurrences.
USE [SteamStats];
SELECT r.[name] AS RoleName
FROM sys.database_role_members m
JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
JOIN sys.database_principals u ON u.principal_id = m.member_principal_id
WHERE u.[name] = N'stats_analyst_ro';

SELECT OBJECT_SCHEMA_NAME(p.major_id) AS [Schema], OBJECT_NAME(p.major_id) AS [Object],
       c.[name] AS [Column], p.[permission_name], p.[state_desc]
FROM sys.database_permissions p
JOIN sys.database_principals u ON u.principal_id = p.grantee_principal_id
LEFT JOIN sys.columns c ON c.[object_id] = p.major_id AND c.column_id = p.minor_id
WHERE u.[name] = N'stats_analyst_ro' AND p.[state_desc] = 'DENY';

-- Rollback: DROP USER IF EXISTS [stats_analyst_ro] in each DB, then DROP LOGIN [stats_analyst_ro].
```

Cross-platform schema differences an analyst should know: see
[stats_platform_schema_divergence.md](stats_platform_schema_divergence.md).
