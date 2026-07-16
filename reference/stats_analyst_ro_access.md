# Analytics read-only access (Stats copy) — `analytics_ro` role

Read-only access for the analytics / analyst colleagues on the consolidated **Stats COPY**
instance ("ALL STATS DB": `SteamStats`, `PsStats`, `XbStats`, `MobStats`, `NxStats`).

## Model

A shared database role **`analytics_ro`** in each of the 5 databases carries the access:

- member of `db_datareader` (reads everything) — no write / DDL / execute;
- column-level `DENY SELECT` on identity / payment-linkage columns
  (`Username`, `ExternalId`, `ForegnTransactionId`) wherever they occur, applied **to the role**.

Each colleague gets an **impersonal per-role login** that is only a member of `analytics_ro`.
Separate logins give per-person attribution in SQL audit/traces, individual passwords, and
individual revocation. The role keeps the permission model in one place, so adding another
colleague is just `CREATE LOGIN` + `CREATE USER` + add to the role.

| Login               | Purpose                          |
|---------------------|----------------------------------|
| `stats_analyst_ro`  | original analytics account (CEO) |
| `stats_ro_analyst`  | analyst                          |
| `stats_ro_producer` | producer                         |
| `stats_ro_gd_lead`  | GD lead                          |

## Why

- **Durable, attributable read-only access** for the analytics colleagues, against the copy so
  heavy scans never touch the live per-platform PROD Stats clusters.
- **Pseudonymous by design** — Stats is keyed by the GUID `UserId`; the only columns mapping it to
  a real identity are `Username` and `ExternalId` (external platform account id, e.g. SteamID64).
  Denying them keeps fact/aggregate analytics working while preventing de-pseudonymization.
  `ForegnTransactionId` (external payment ref) is denied — payment linkage, no analytical value.
  Revenue columns (`Price`, `EquivalentPrice`, `Currency`) stay readable. Stats has no classic PII
  columns (no email/name/IP/password-hash — those live in the MAIN DBs).

## Applying

Run the script below as `sysadmin`/`securityadmin` **on the Stats copy instance only**. It is
idempotent. Set the three placeholder passwords (`<<SET_STRONG_PASSWORD_*>>`) to strong secrets
stored in the secrets manager — the placeholders are intentionally not policy-complex, so an
unmodified run fails at `CREATE LOGIN` instead of creating an account with a predictable password.
The DENY matches by column name, so it adapts to per-platform schema differences (e.g.
Mobile/Nintendo `Users` have no `ExternalId`).

**CEO account migration is zero-downtime by construction:** in each DB the role (with read + DENY)
is established first, `stats_analyst_ro` is then added to it, and only afterwards is its direct
`db_datareader` membership and per-user DENY removed — so read access and the column DENY are
continuous. The cutover is wrapped in a transaction so other sessions see only the before/after
state. Re-running the script is a no-op once migrated.

Consumer side: set a command timeout (60-120s) and a row cap on each connection — there is no
server-side Resource Governor limit.

## Setup script

```sql
/* Analytics read-only access on the Stats COPY instance ("ALL STATS DB").
   - shared role [analytics_ro] per DB: member of db_datareader + column DENY on identity columns
   - per-colleague logins, members of the role
   - migrates the original [stats_analyst_ro] account into the role (zero-downtime)
   Idempotent. RUN AS sysadmin/securityadmin ON THE COPY INSTANCE ONLY.
   Set the three <<SET_STRONG_PASSWORD_*>> placeholders to strong secrets before running -- they
   intentionally fail password policy, so an unmodified run errors at CREATE LOGIN rather than
   creating an account with a predictable password. */

-- Part 0 - per-colleague logins (master). The original [stats_analyst_ro] already exists.
USE [master];
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE [name] = N'stats_ro_analyst')
    CREATE LOGIN [stats_ro_analyst]  WITH PASSWORD = N'<<SET_STRONG_PASSWORD_ANALYST>>',  CHECK_POLICY = ON, CHECK_EXPIRATION = OFF, DEFAULT_DATABASE = [SteamStats];
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE [name] = N'stats_ro_producer')
    CREATE LOGIN [stats_ro_producer] WITH PASSWORD = N'<<SET_STRONG_PASSWORD_PRODUCER>>', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF, DEFAULT_DATABASE = [SteamStats];
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE [name] = N'stats_ro_gd_lead')
    CREATE LOGIN [stats_ro_gd_lead]  WITH PASSWORD = N'<<SET_STRONG_PASSWORD_GD_LEAD>>',  CHECK_POLICY = ON, CHECK_EXPIRATION = OFF, DEFAULT_DATABASE = [SteamStats];
GO

/* Per-database block below is IDENTICAL for every database except the USE statement.
   Order matters for the zero-downtime CEO migration: role + role-DENY first, then add the
   original account to the role, only then drop its direct db_datareader membership / per-user DENY. */

-- ============================ SteamStats ============================
USE [SteamStats];
GO
IF DATABASE_PRINCIPAL_ID(N'analytics_ro') IS NULL
    CREATE ROLE [analytics_ro];
ALTER ROLE [db_datareader] ADD MEMBER [analytics_ro];
GO
DECLARE @deny nvarchar(max) = N'';
SELECT @deny = @deny + N'DENY SELECT ON OBJECT::' + QUOTENAME(s.[name]) + N'.' + QUOTENAME(o.[name])
     + N' (' + QUOTENAME(c.[name]) + N') TO [analytics_ro];' + NCHAR(10)
FROM sys.columns c
JOIN sys.objects o ON o.[object_id] = c.[object_id]
JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] IN ('U', 'V')
  AND c.[name] IN (N'Username', N'ExternalId', N'ForegnTransactionId');
IF @deny <> N'' EXEC sys.sp_executesql @deny;
GO
IF SUSER_ID(N'stats_ro_analyst') IS NOT NULL
BEGIN
    IF DATABASE_PRINCIPAL_ID(N'stats_ro_analyst') IS NULL CREATE USER [stats_ro_analyst] FOR LOGIN [stats_ro_analyst];
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_ro_analyst];
END
IF SUSER_ID(N'stats_ro_producer') IS NOT NULL
BEGIN
    IF DATABASE_PRINCIPAL_ID(N'stats_ro_producer') IS NULL CREATE USER [stats_ro_producer] FOR LOGIN [stats_ro_producer];
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_ro_producer];
END
IF SUSER_ID(N'stats_ro_gd_lead') IS NOT NULL
BEGIN
    IF DATABASE_PRINCIPAL_ID(N'stats_ro_gd_lead') IS NULL CREATE USER [stats_ro_gd_lead] FOR LOGIN [stats_ro_gd_lead];
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_ro_gd_lead];
END
GO
BEGIN TRANSACTION;
IF DATABASE_PRINCIPAL_ID(N'stats_analyst_ro') IS NOT NULL
BEGIN
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_analyst_ro];
    IF EXISTS (SELECT 1 FROM sys.database_role_members m
               JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
               WHERE r.[name] = N'db_datareader' AND m.member_principal_id = DATABASE_PRINCIPAL_ID(N'stats_analyst_ro'))
        ALTER ROLE [db_datareader] DROP MEMBER [stats_analyst_ro];
    DECLARE @rev nvarchar(max) = N'';
    SELECT @rev = @rev + N'REVOKE SELECT ON OBJECT::' + QUOTENAME(OBJECT_SCHEMA_NAME(p.major_id)) + N'.'
         + QUOTENAME(OBJECT_NAME(p.major_id)) + N' (' + QUOTENAME(col.[name]) + N') TO [stats_analyst_ro];' + NCHAR(10)
    FROM sys.database_permissions p
    JOIN sys.columns col ON col.[object_id] = p.major_id AND col.column_id = p.minor_id
    WHERE p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'stats_analyst_ro')
      AND p.state_desc = 'DENY' AND p.permission_name = 'SELECT' AND p.minor_id > 0;
    IF @rev <> N'' EXEC sys.sp_executesql @rev;
END
COMMIT TRANSACTION;
GO

-- ============================ PsStats ============================
USE [PsStats];
GO
IF DATABASE_PRINCIPAL_ID(N'analytics_ro') IS NULL
    CREATE ROLE [analytics_ro];
ALTER ROLE [db_datareader] ADD MEMBER [analytics_ro];
GO
DECLARE @deny nvarchar(max) = N'';
SELECT @deny = @deny + N'DENY SELECT ON OBJECT::' + QUOTENAME(s.[name]) + N'.' + QUOTENAME(o.[name])
     + N' (' + QUOTENAME(c.[name]) + N') TO [analytics_ro];' + NCHAR(10)
FROM sys.columns c
JOIN sys.objects o ON o.[object_id] = c.[object_id]
JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] IN ('U', 'V')
  AND c.[name] IN (N'Username', N'ExternalId', N'ForegnTransactionId');
IF @deny <> N'' EXEC sys.sp_executesql @deny;
GO
IF SUSER_ID(N'stats_ro_analyst') IS NOT NULL
BEGIN
    IF DATABASE_PRINCIPAL_ID(N'stats_ro_analyst') IS NULL CREATE USER [stats_ro_analyst] FOR LOGIN [stats_ro_analyst];
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_ro_analyst];
END
IF SUSER_ID(N'stats_ro_producer') IS NOT NULL
BEGIN
    IF DATABASE_PRINCIPAL_ID(N'stats_ro_producer') IS NULL CREATE USER [stats_ro_producer] FOR LOGIN [stats_ro_producer];
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_ro_producer];
END
IF SUSER_ID(N'stats_ro_gd_lead') IS NOT NULL
BEGIN
    IF DATABASE_PRINCIPAL_ID(N'stats_ro_gd_lead') IS NULL CREATE USER [stats_ro_gd_lead] FOR LOGIN [stats_ro_gd_lead];
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_ro_gd_lead];
END
GO
BEGIN TRANSACTION;
IF DATABASE_PRINCIPAL_ID(N'stats_analyst_ro') IS NOT NULL
BEGIN
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_analyst_ro];
    IF EXISTS (SELECT 1 FROM sys.database_role_members m
               JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
               WHERE r.[name] = N'db_datareader' AND m.member_principal_id = DATABASE_PRINCIPAL_ID(N'stats_analyst_ro'))
        ALTER ROLE [db_datareader] DROP MEMBER [stats_analyst_ro];
    DECLARE @rev nvarchar(max) = N'';
    SELECT @rev = @rev + N'REVOKE SELECT ON OBJECT::' + QUOTENAME(OBJECT_SCHEMA_NAME(p.major_id)) + N'.'
         + QUOTENAME(OBJECT_NAME(p.major_id)) + N' (' + QUOTENAME(col.[name]) + N') TO [stats_analyst_ro];' + NCHAR(10)
    FROM sys.database_permissions p
    JOIN sys.columns col ON col.[object_id] = p.major_id AND col.column_id = p.minor_id
    WHERE p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'stats_analyst_ro')
      AND p.state_desc = 'DENY' AND p.permission_name = 'SELECT' AND p.minor_id > 0;
    IF @rev <> N'' EXEC sys.sp_executesql @rev;
END
COMMIT TRANSACTION;
GO

-- ============================ XbStats ============================
USE [XbStats];
GO
IF DATABASE_PRINCIPAL_ID(N'analytics_ro') IS NULL
    CREATE ROLE [analytics_ro];
ALTER ROLE [db_datareader] ADD MEMBER [analytics_ro];
GO
DECLARE @deny nvarchar(max) = N'';
SELECT @deny = @deny + N'DENY SELECT ON OBJECT::' + QUOTENAME(s.[name]) + N'.' + QUOTENAME(o.[name])
     + N' (' + QUOTENAME(c.[name]) + N') TO [analytics_ro];' + NCHAR(10)
FROM sys.columns c
JOIN sys.objects o ON o.[object_id] = c.[object_id]
JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] IN ('U', 'V')
  AND c.[name] IN (N'Username', N'ExternalId', N'ForegnTransactionId');
IF @deny <> N'' EXEC sys.sp_executesql @deny;
GO
IF SUSER_ID(N'stats_ro_analyst') IS NOT NULL
BEGIN
    IF DATABASE_PRINCIPAL_ID(N'stats_ro_analyst') IS NULL CREATE USER [stats_ro_analyst] FOR LOGIN [stats_ro_analyst];
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_ro_analyst];
END
IF SUSER_ID(N'stats_ro_producer') IS NOT NULL
BEGIN
    IF DATABASE_PRINCIPAL_ID(N'stats_ro_producer') IS NULL CREATE USER [stats_ro_producer] FOR LOGIN [stats_ro_producer];
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_ro_producer];
END
IF SUSER_ID(N'stats_ro_gd_lead') IS NOT NULL
BEGIN
    IF DATABASE_PRINCIPAL_ID(N'stats_ro_gd_lead') IS NULL CREATE USER [stats_ro_gd_lead] FOR LOGIN [stats_ro_gd_lead];
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_ro_gd_lead];
END
GO
BEGIN TRANSACTION;
IF DATABASE_PRINCIPAL_ID(N'stats_analyst_ro') IS NOT NULL
BEGIN
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_analyst_ro];
    IF EXISTS (SELECT 1 FROM sys.database_role_members m
               JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
               WHERE r.[name] = N'db_datareader' AND m.member_principal_id = DATABASE_PRINCIPAL_ID(N'stats_analyst_ro'))
        ALTER ROLE [db_datareader] DROP MEMBER [stats_analyst_ro];
    DECLARE @rev nvarchar(max) = N'';
    SELECT @rev = @rev + N'REVOKE SELECT ON OBJECT::' + QUOTENAME(OBJECT_SCHEMA_NAME(p.major_id)) + N'.'
         + QUOTENAME(OBJECT_NAME(p.major_id)) + N' (' + QUOTENAME(col.[name]) + N') TO [stats_analyst_ro];' + NCHAR(10)
    FROM sys.database_permissions p
    JOIN sys.columns col ON col.[object_id] = p.major_id AND col.column_id = p.minor_id
    WHERE p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'stats_analyst_ro')
      AND p.state_desc = 'DENY' AND p.permission_name = 'SELECT' AND p.minor_id > 0;
    IF @rev <> N'' EXEC sys.sp_executesql @rev;
END
COMMIT TRANSACTION;
GO

-- ============================ MobStats ============================
USE [MobStats];
GO
IF DATABASE_PRINCIPAL_ID(N'analytics_ro') IS NULL
    CREATE ROLE [analytics_ro];
ALTER ROLE [db_datareader] ADD MEMBER [analytics_ro];
GO
DECLARE @deny nvarchar(max) = N'';
SELECT @deny = @deny + N'DENY SELECT ON OBJECT::' + QUOTENAME(s.[name]) + N'.' + QUOTENAME(o.[name])
     + N' (' + QUOTENAME(c.[name]) + N') TO [analytics_ro];' + NCHAR(10)
FROM sys.columns c
JOIN sys.objects o ON o.[object_id] = c.[object_id]
JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] IN ('U', 'V')
  AND c.[name] IN (N'Username', N'ExternalId', N'ForegnTransactionId');
IF @deny <> N'' EXEC sys.sp_executesql @deny;
GO
IF SUSER_ID(N'stats_ro_analyst') IS NOT NULL
BEGIN
    IF DATABASE_PRINCIPAL_ID(N'stats_ro_analyst') IS NULL CREATE USER [stats_ro_analyst] FOR LOGIN [stats_ro_analyst];
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_ro_analyst];
END
IF SUSER_ID(N'stats_ro_producer') IS NOT NULL
BEGIN
    IF DATABASE_PRINCIPAL_ID(N'stats_ro_producer') IS NULL CREATE USER [stats_ro_producer] FOR LOGIN [stats_ro_producer];
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_ro_producer];
END
IF SUSER_ID(N'stats_ro_gd_lead') IS NOT NULL
BEGIN
    IF DATABASE_PRINCIPAL_ID(N'stats_ro_gd_lead') IS NULL CREATE USER [stats_ro_gd_lead] FOR LOGIN [stats_ro_gd_lead];
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_ro_gd_lead];
END
GO
BEGIN TRANSACTION;
IF DATABASE_PRINCIPAL_ID(N'stats_analyst_ro') IS NOT NULL
BEGIN
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_analyst_ro];
    IF EXISTS (SELECT 1 FROM sys.database_role_members m
               JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
               WHERE r.[name] = N'db_datareader' AND m.member_principal_id = DATABASE_PRINCIPAL_ID(N'stats_analyst_ro'))
        ALTER ROLE [db_datareader] DROP MEMBER [stats_analyst_ro];
    DECLARE @rev nvarchar(max) = N'';
    SELECT @rev = @rev + N'REVOKE SELECT ON OBJECT::' + QUOTENAME(OBJECT_SCHEMA_NAME(p.major_id)) + N'.'
         + QUOTENAME(OBJECT_NAME(p.major_id)) + N' (' + QUOTENAME(col.[name]) + N') TO [stats_analyst_ro];' + NCHAR(10)
    FROM sys.database_permissions p
    JOIN sys.columns col ON col.[object_id] = p.major_id AND col.column_id = p.minor_id
    WHERE p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'stats_analyst_ro')
      AND p.state_desc = 'DENY' AND p.permission_name = 'SELECT' AND p.minor_id > 0;
    IF @rev <> N'' EXEC sys.sp_executesql @rev;
END
COMMIT TRANSACTION;
GO

-- ============================ NxStats ============================
USE [NxStats];
GO
IF DATABASE_PRINCIPAL_ID(N'analytics_ro') IS NULL
    CREATE ROLE [analytics_ro];
ALTER ROLE [db_datareader] ADD MEMBER [analytics_ro];
GO
DECLARE @deny nvarchar(max) = N'';
SELECT @deny = @deny + N'DENY SELECT ON OBJECT::' + QUOTENAME(s.[name]) + N'.' + QUOTENAME(o.[name])
     + N' (' + QUOTENAME(c.[name]) + N') TO [analytics_ro];' + NCHAR(10)
FROM sys.columns c
JOIN sys.objects o ON o.[object_id] = c.[object_id]
JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] IN ('U', 'V')
  AND c.[name] IN (N'Username', N'ExternalId', N'ForegnTransactionId');
IF @deny <> N'' EXEC sys.sp_executesql @deny;
GO
IF SUSER_ID(N'stats_ro_analyst') IS NOT NULL
BEGIN
    IF DATABASE_PRINCIPAL_ID(N'stats_ro_analyst') IS NULL CREATE USER [stats_ro_analyst] FOR LOGIN [stats_ro_analyst];
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_ro_analyst];
END
IF SUSER_ID(N'stats_ro_producer') IS NOT NULL
BEGIN
    IF DATABASE_PRINCIPAL_ID(N'stats_ro_producer') IS NULL CREATE USER [stats_ro_producer] FOR LOGIN [stats_ro_producer];
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_ro_producer];
END
IF SUSER_ID(N'stats_ro_gd_lead') IS NOT NULL
BEGIN
    IF DATABASE_PRINCIPAL_ID(N'stats_ro_gd_lead') IS NULL CREATE USER [stats_ro_gd_lead] FOR LOGIN [stats_ro_gd_lead];
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_ro_gd_lead];
END
GO
BEGIN TRANSACTION;
IF DATABASE_PRINCIPAL_ID(N'stats_analyst_ro') IS NOT NULL
BEGIN
    ALTER ROLE [analytics_ro] ADD MEMBER [stats_analyst_ro];
    IF EXISTS (SELECT 1 FROM sys.database_role_members m
               JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
               WHERE r.[name] = N'db_datareader' AND m.member_principal_id = DATABASE_PRINCIPAL_ID(N'stats_analyst_ro'))
        ALTER ROLE [db_datareader] DROP MEMBER [stats_analyst_ro];
    DECLARE @rev nvarchar(max) = N'';
    SELECT @rev = @rev + N'REVOKE SELECT ON OBJECT::' + QUOTENAME(OBJECT_SCHEMA_NAME(p.major_id)) + N'.'
         + QUOTENAME(OBJECT_NAME(p.major_id)) + N' (' + QUOTENAME(col.[name]) + N') TO [stats_analyst_ro];' + NCHAR(10)
    FROM sys.database_permissions p
    JOIN sys.columns col ON col.[object_id] = p.major_id AND col.column_id = p.minor_id
    WHERE p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'stats_analyst_ro')
      AND p.state_desc = 'DENY' AND p.permission_name = 'SELECT' AND p.minor_id > 0;
    IF @rev <> N'' EXEC sys.sp_executesql @rev;
END
COMMIT TRANSACTION;
GO
```

## Verification / rollback

```sql
-- Verify (per DB). Expect: role analytics_ro is a db_datareader member with the three DENYs;
-- every analyst user is a member of analytics_ro and NOT a direct db_datareader member;
-- no analyst user has per-user DENYs left.
USE [SteamStats];

SELECT m.member_principal_id, u.[name] AS Member
FROM sys.database_role_members m
JOIN sys.database_principals u ON u.principal_id = m.member_principal_id
WHERE m.role_principal_id = DATABASE_PRINCIPAL_ID(N'analytics_ro');

SELECT OBJECT_SCHEMA_NAME(p.major_id) AS [Schema], OBJECT_NAME(p.major_id) AS [Object],
       c.[name] AS [Column], p.[state_desc]
FROM sys.database_permissions p
JOIN sys.columns c ON c.[object_id] = p.major_id AND c.column_id = p.minor_id
WHERE p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'analytics_ro') AND p.state_desc = 'DENY';

-- Rollback (teardown): in each DB DROP the users, then DROP ROLE [analytics_ro]; in master DROP the
-- three per-colleague logins. (The original stats_analyst_ro can be re-granted db_datareader directly
-- if the role model is abandoned.)
```

Cross-platform schema differences an analyst should know:
[stats_platform_schema_divergence.md](stats_platform_schema_divergence.md).
