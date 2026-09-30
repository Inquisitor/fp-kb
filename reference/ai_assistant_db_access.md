---
name: Database access for AI assistants
description: Read-only database access for AI assistants - the shared-role-plus-impersonal-logins pattern, how the cut is chosen by who lives in the database, the pitfalls (views, JSON, TLS), and the two instances with their setup scripts - analytics on the Stats copy (`analytics_ro`) and internal playtesting on YellowTest (`internal_playtester_ro`).
type: reference
---

# Database access for AI assistants: read-only roles, logins and cuts

AI assistants reach the databases through the same DB tools people use, under logins of their own.
Every such access follows one pattern; what differs per database is the **cut** — which columns are
denied — and that is decided by who lives in the data. Two instances exist: analytics on the Stats
copy and internal playtesting on YellowTest, each with its own section and scripts below.

## Pattern

A shared database role in each database carries the access:

- member of `db_datareader` (reads everything) — no write / DDL / execute;
- column-level `DENY SELECT` on the columns the cut names, applied **to the role**. The script
  matches by column name over every table and view, so one script adapts to schema differences
  between databases and platforms (e.g. Mobile/Nintendo `Users` have no `ExternalId`).

Each consumer gets an **impersonal login** — named by role (`stats_ro_analyst`) or by agent
(`playtester_ai_1`) — that is only a member of the role. Separate logins give per-login attribution
in SQL audit/traces, individual passwords and individual revocation; the role keeps the permission
model in one place. Adding a consumer is `CREATE LOGIN` + `CREATE USER` + add to the role, and the
permission model is not touched.

The scripts are idempotent and run as `sysadmin` — `securityadmin` can create logins but not the
roles, memberships and `DENY`s inside a database. Run them with a client that stops at the first
error (SQLCMD mode with `:ON ERROR EXIT`, or the console's stop-on-error setting): a failed `USE`
does not switch databases, and the batches after it would run in the previous one. Every block is
idempotent, so that is harmless, but the verification output would then describe the wrong
database — which is why every verify query prints `DB_NAME()`.

A login script takes the password through a variable and refuses to create the login while the
`<<SET_STRONG_PASSWORD...>>` placeholder is still in it. The placeholders are also not
policy-complex, so even without that guard `CREATE LOGIN` fails where password complexity is
enforced — but complexity is a server setting, not a safeguard to rely on. Replace the placeholder
in the query console, never in a file that can reach version control, and keep the secret in the
secrets manager. Re-running a script does not rotate a password or reconcile an existing login: a
same-name login or user that already exists is adopted as it is, with whatever other memberships and
grants it carries.

Password generator (PowerShell 7; the value goes to the clipboard and is never printed):

```powershell
$abc = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789'
do { $p = -join (1..32 | ForEach-Object { $abc[[Security.Cryptography.RandomNumberGenerator]::GetInt32($abc.Length)] }) }
until ($p -cmatch '[A-Z]' -and $p -cmatch '[a-z]' -and $p -match '\d')
$p | Set-Clipboard
```

Letters and digits only, so the value needs no escaping in T-SQL or in a connection string; the
loop retries the rare draw that lacks a character class and would fail the standard Windows
complexity requirement that `CHECK_POLICY = ON` applies. The same policy locks a login after
repeated wrong passwords, and an agent whose tool retries a bad password can lock its own — check
`LOGINPROPERTY(N'<login>', 'IsLocked')` before looking elsewhere.

Re-running a role script is additive: it adds a `DENY` for every column that matches now and leaves
earlier ones in place, so removing a name from the list does not lift the `DENY` it once created —
revoke that by hand.

Consumer side: set a command timeout (60-120s) and a row cap on each connection — there is no
server-side Resource Governor limit.

## Choosing the cut

| Who lives in the database                              | What is denied                                                                                                                                                                                                                                                                                                                                                | Instance                 |
|--------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------|
| Real players — the Stats copy                          | Identity and payment linkage: `Username`, `ExternalId`, `ForegnTransactionId`. The data stays pseudonymous — Stats is keyed by the GUID `UserId`, and these are the only columns mapping it to a real identity or a payment.                                                                                                                                | `analytics_ro`           |
| Test and QA accounts only — YellowTest `Main`, `Stats` | Credentials, tokens and e-mail: `Password`, `PasswordSalt`, `SecurityToken`, `TwitchToken`, `TwitchRefreshToken`, `DeviceToken`, `ReceiptJson`, `Email`, `TwitchEmail`. Player identity stays readable — the playtester has to find an account by name and read its whole state.                                                                             | `internal_playtester_ro` |
| Real players in `Main`                                 | Not covered. A deny list over `db_datareader` is the wrong shape there: every new table and column is readable by default, and identity inside JSON columns (`Profiles.ProfileJson` embeds friends' usernames and platform ids) cannot be cut by column permissions. It would take an allow-list of `GRANT`s on a curated set of tables and columns.           | —                        |

## Pitfalls

- **Views bypass the table's DENY.** A view and its base table share an owner, so ownership
  chaining skips the permission check on the table — a `DENY` on `Users.Email` is not evaluated
  when `Email` is read through `VW_PlayerDetails`. The `DENY` has to sit on the view's columns as
  well; matching by name over views covers this as long as the view keeps the column name.
- **Name matching does not follow a value.** A view that renames the column (`Email AS
  ContactAddress`), a computed column copying it, or an expression built from it escapes a
  name-based list; `db_datareader` also covers table-valued functions, not only tables and views.
  The generators therefore scan functions too, and each role script ends with a definition scan
  that lists every view and function whose text mentions a denied column name — read those
  definitions by hand after a deploy that adds or changes views.
- **Recreated views lose the DENY.** A column `DENY` is attached to the object it names. The view
  source scripts under `<project>/SQL/Patches/Main/Views/` recreate a view with `DROP` + `CREATE`,
  which drops the `DENY` with it. Re-run the role script after a deploy.
- **Type aliases hide columns.** `Users.Email` and `Users.Password` are declared `sysname`; an
  inventory that filters on the declared type name `nvarchar` misses them although that is their
  base type. Match by name.
- **JSON columns are all or nothing.** Column permissions cannot cut a key out of a JSON blob; a
  blob that carries identity is either denied whole or exposed through a sanitizing view.
- **Self-generated TLS certificate.** A SQL Server with no certificate selected falls back to a
  self-generated one, regenerated at every service start. A client whose driver encrypts and
  validates by default (ODBC Driver 18, Microsoft.Data.SqlClient 4+, JDBC 10.2+) refuses it before
  authentication is even attempted — with the Windows provider the message reads "certificate chain
  was issued by an authority that is not trusted"; other drivers word it differently. Connect with
  encryption but without validation: `Encrypt=True;TrustServerCertificate=True` (SqlClient),
  `Encrypt=yes;TrustServerCertificate=yes` (ODBC), `encrypt=true;trustServerCertificate=true`
  (JDBC). The channel is encrypted, but the client no longer authenticates the server, so an
  intermediary on the path could impersonate it — acceptable only where the path itself is trusted.
  Exporting or pinning the fallback certificate is no durable configuration: it changes at the next
  restart. The durable fix is binding a CA-issued certificate for the server's DNS name, at the cost
  of a re-bind and a service restart at every renewal (SQL Server does not start if the bound
  certificate has been removed from the store).

## Analytics on the Stats copy — `analytics_ro`

Read-only access for the analytics colleagues on the consolidated **Stats COPY** instance ("ALL
STATS DB": `SteamStats`, `PsStats`, `XbStats`, `MobStats`, `NxStats`). Against the copy, so heavy
scans never touch the live per-platform PROD Stats clusters.

The shared role **`analytics_ro`** in each of the five databases denies `Username`, `ExternalId`
(external platform account id, e.g. SteamID64) and `ForegnTransactionId` (external payment ref)
wherever they occur. Fact/aggregate analytics keep working; de-pseudonymization does not. Revenue
columns (`Price`, `EquivalentPrice`, `Currency`) stay readable. Stats has no classic PII columns —
no e-mail, name, IP or password hash; those live in the MAIN DBs. Column inventory as of 2026-07-16.
The copy is refreshed by copying rows into it, not by restoring backups, so the role and its users
survive a refresh.

| Login               | Purpose                          |
|---------------------|----------------------------------|
| `stats_analyst_ro`  | original analytics account (CEO) |
| `stats_ro_analyst`  | analyst                          |
| `stats_ro_producer` | producer                         |
| `stats_ro_gd_lead`  | GD lead                          |

### Applying

Run the script below **on the Stats copy instance only**, with the three placeholder passwords
(`<<SET_STRONG_PASSWORD_*>>`) replaced.

**CEO account migration is zero-downtime by construction:** in each DB the role (with read + DENY)
is established first, `stats_analyst_ro` is then added to it, and only afterwards is its direct
`db_datareader` membership and per-user DENY removed — so read access and the column DENY are
continuous. The cutover is wrapped in a transaction so other sessions see only the before/after
state. The migration revokes every direct column `DENY` the original account carries, not only the
three listed, and drops its direct `db_datareader` membership: afterwards the role is the only
place where its restrictions live. Re-running the script is a no-op once migrated.

### Setup script

```sql
/* Analytics read-only access on the Stats COPY instance ("ALL STATS DB").
   - shared role [analytics_ro] per DB: member of db_datareader + column DENY on identity columns
   - per-colleague logins, members of the role
   - migrates the original [stats_analyst_ro] account into the role (zero-downtime)
   Idempotent. RUN AS sysadmin ON THE COPY INSTANCE ONLY.
   Set the three <<SET_STRONG_PASSWORD_*>> placeholders to strong secrets before running -- a login
   is not created while its placeholder is still in place. Requires SQL Server 2017+ (STRING_AGG). */

-- Part 0 - per-colleague logins (master). The original [stats_analyst_ro] already exists.
USE [master];
GO
DECLARE @pwd_analyst  nvarchar(128) = N'<<SET_STRONG_PASSWORD_ANALYST>>',
        @pwd_producer nvarchar(128) = N'<<SET_STRONG_PASSWORD_PRODUCER>>',
        @pwd_gd_lead  nvarchar(128) = N'<<SET_STRONG_PASSWORD_GD_LEAD>>';
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE [name] = N'stats_ro_analyst')
BEGIN
    IF @pwd_analyst LIKE N'<<%>>' THROW 50000, N'Password placeholder not replaced - set <<SET_STRONG_PASSWORD_ANALYST>> first.', 1;
    EXEC (N'CREATE LOGIN [stats_ro_analyst] WITH PASSWORD = ' + QUOTENAME(@pwd_analyst, '''') + N', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF, DEFAULT_DATABASE = [SteamStats];');
END
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE [name] = N'stats_ro_producer')
BEGIN
    IF @pwd_producer LIKE N'<<%>>' THROW 50000, N'Password placeholder not replaced - set <<SET_STRONG_PASSWORD_PRODUCER>> first.', 1;
    EXEC (N'CREATE LOGIN [stats_ro_producer] WITH PASSWORD = ' + QUOTENAME(@pwd_producer, '''') + N', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF, DEFAULT_DATABASE = [SteamStats];');
END
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE [name] = N'stats_ro_gd_lead')
BEGIN
    IF @pwd_gd_lead LIKE N'<<%>>' THROW 50000, N'Password placeholder not replaced - set <<SET_STRONG_PASSWORD_GD_LEAD>> first.', 1;
    EXEC (N'CREATE LOGIN [stats_ro_gd_lead] WITH PASSWORD = ' + QUOTENAME(@pwd_gd_lead, '''') + N', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF, DEFAULT_DATABASE = [SteamStats];');
END
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
DECLARE @deny nvarchar(max);
SELECT @deny = STRING_AGG(CAST(N'DENY SELECT ON OBJECT::' + QUOTENAME(s.[name]) + N'.' + QUOTENAME(o.[name])
     + N' (' + QUOTENAME(c.[name]) + N') TO [analytics_ro];' AS nvarchar(max)), NCHAR(10))
FROM sys.columns c
JOIN sys.objects o ON o.[object_id] = c.[object_id]
JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] IN ('U', 'V', 'IF', 'TF', 'FT')
  AND c.[name] IN (N'Username', N'ExternalId', N'ForegnTransactionId');
IF @deny IS NOT NULL EXEC sys.sp_executesql @deny;
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
    DECLARE @rev nvarchar(max);
    SELECT @rev = STRING_AGG(CAST(N'REVOKE SELECT ON OBJECT::' + QUOTENAME(OBJECT_SCHEMA_NAME(p.major_id)) + N'.'
         + QUOTENAME(OBJECT_NAME(p.major_id)) + N' (' + QUOTENAME(col.[name]) + N') TO [stats_analyst_ro];' AS nvarchar(max)), NCHAR(10))
    FROM sys.database_permissions p
    JOIN sys.columns col ON col.[object_id] = p.major_id AND col.column_id = p.minor_id
    WHERE p.class = 1 AND p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'stats_analyst_ro')
      AND p.state_desc = 'DENY' AND p.permission_name = 'SELECT' AND p.minor_id > 0;
    IF @rev IS NOT NULL EXEC sys.sp_executesql @rev;
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
DECLARE @deny nvarchar(max);
SELECT @deny = STRING_AGG(CAST(N'DENY SELECT ON OBJECT::' + QUOTENAME(s.[name]) + N'.' + QUOTENAME(o.[name])
     + N' (' + QUOTENAME(c.[name]) + N') TO [analytics_ro];' AS nvarchar(max)), NCHAR(10))
FROM sys.columns c
JOIN sys.objects o ON o.[object_id] = c.[object_id]
JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] IN ('U', 'V', 'IF', 'TF', 'FT')
  AND c.[name] IN (N'Username', N'ExternalId', N'ForegnTransactionId');
IF @deny IS NOT NULL EXEC sys.sp_executesql @deny;
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
    DECLARE @rev nvarchar(max);
    SELECT @rev = STRING_AGG(CAST(N'REVOKE SELECT ON OBJECT::' + QUOTENAME(OBJECT_SCHEMA_NAME(p.major_id)) + N'.'
         + QUOTENAME(OBJECT_NAME(p.major_id)) + N' (' + QUOTENAME(col.[name]) + N') TO [stats_analyst_ro];' AS nvarchar(max)), NCHAR(10))
    FROM sys.database_permissions p
    JOIN sys.columns col ON col.[object_id] = p.major_id AND col.column_id = p.minor_id
    WHERE p.class = 1 AND p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'stats_analyst_ro')
      AND p.state_desc = 'DENY' AND p.permission_name = 'SELECT' AND p.minor_id > 0;
    IF @rev IS NOT NULL EXEC sys.sp_executesql @rev;
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
DECLARE @deny nvarchar(max);
SELECT @deny = STRING_AGG(CAST(N'DENY SELECT ON OBJECT::' + QUOTENAME(s.[name]) + N'.' + QUOTENAME(o.[name])
     + N' (' + QUOTENAME(c.[name]) + N') TO [analytics_ro];' AS nvarchar(max)), NCHAR(10))
FROM sys.columns c
JOIN sys.objects o ON o.[object_id] = c.[object_id]
JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] IN ('U', 'V', 'IF', 'TF', 'FT')
  AND c.[name] IN (N'Username', N'ExternalId', N'ForegnTransactionId');
IF @deny IS NOT NULL EXEC sys.sp_executesql @deny;
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
    DECLARE @rev nvarchar(max);
    SELECT @rev = STRING_AGG(CAST(N'REVOKE SELECT ON OBJECT::' + QUOTENAME(OBJECT_SCHEMA_NAME(p.major_id)) + N'.'
         + QUOTENAME(OBJECT_NAME(p.major_id)) + N' (' + QUOTENAME(col.[name]) + N') TO [stats_analyst_ro];' AS nvarchar(max)), NCHAR(10))
    FROM sys.database_permissions p
    JOIN sys.columns col ON col.[object_id] = p.major_id AND col.column_id = p.minor_id
    WHERE p.class = 1 AND p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'stats_analyst_ro')
      AND p.state_desc = 'DENY' AND p.permission_name = 'SELECT' AND p.minor_id > 0;
    IF @rev IS NOT NULL EXEC sys.sp_executesql @rev;
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
DECLARE @deny nvarchar(max);
SELECT @deny = STRING_AGG(CAST(N'DENY SELECT ON OBJECT::' + QUOTENAME(s.[name]) + N'.' + QUOTENAME(o.[name])
     + N' (' + QUOTENAME(c.[name]) + N') TO [analytics_ro];' AS nvarchar(max)), NCHAR(10))
FROM sys.columns c
JOIN sys.objects o ON o.[object_id] = c.[object_id]
JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] IN ('U', 'V', 'IF', 'TF', 'FT')
  AND c.[name] IN (N'Username', N'ExternalId', N'ForegnTransactionId');
IF @deny IS NOT NULL EXEC sys.sp_executesql @deny;
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
    DECLARE @rev nvarchar(max);
    SELECT @rev = STRING_AGG(CAST(N'REVOKE SELECT ON OBJECT::' + QUOTENAME(OBJECT_SCHEMA_NAME(p.major_id)) + N'.'
         + QUOTENAME(OBJECT_NAME(p.major_id)) + N' (' + QUOTENAME(col.[name]) + N') TO [stats_analyst_ro];' AS nvarchar(max)), NCHAR(10))
    FROM sys.database_permissions p
    JOIN sys.columns col ON col.[object_id] = p.major_id AND col.column_id = p.minor_id
    WHERE p.class = 1 AND p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'stats_analyst_ro')
      AND p.state_desc = 'DENY' AND p.permission_name = 'SELECT' AND p.minor_id > 0;
    IF @rev IS NOT NULL EXEC sys.sp_executesql @rev;
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
DECLARE @deny nvarchar(max);
SELECT @deny = STRING_AGG(CAST(N'DENY SELECT ON OBJECT::' + QUOTENAME(s.[name]) + N'.' + QUOTENAME(o.[name])
     + N' (' + QUOTENAME(c.[name]) + N') TO [analytics_ro];' AS nvarchar(max)), NCHAR(10))
FROM sys.columns c
JOIN sys.objects o ON o.[object_id] = c.[object_id]
JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] IN ('U', 'V', 'IF', 'TF', 'FT')
  AND c.[name] IN (N'Username', N'ExternalId', N'ForegnTransactionId');
IF @deny IS NOT NULL EXEC sys.sp_executesql @deny;
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
    DECLARE @rev nvarchar(max);
    SELECT @rev = STRING_AGG(CAST(N'REVOKE SELECT ON OBJECT::' + QUOTENAME(OBJECT_SCHEMA_NAME(p.major_id)) + N'.'
         + QUOTENAME(OBJECT_NAME(p.major_id)) + N' (' + QUOTENAME(col.[name]) + N') TO [stats_analyst_ro];' AS nvarchar(max)), NCHAR(10))
    FROM sys.database_permissions p
    JOIN sys.columns col ON col.[object_id] = p.major_id AND col.column_id = p.minor_id
    WHERE p.class = 1 AND p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'stats_analyst_ro')
      AND p.state_desc = 'DENY' AND p.permission_name = 'SELECT' AND p.minor_id > 0;
    IF @rev IS NOT NULL EXEC sys.sp_executesql @rev;
END
COMMIT TRANSACTION;
GO
```

### Verification / rollback

```sql
-- Verify (per DB). Expect: Expected = Actual (one DENY per matching column); the role is a member
-- of db_datareader; every analyst user is a member of analytics_ro and NOT a direct db_datareader
-- member; no analyst user has per-user DENYs left (third query returns no rows).
USE [SteamStats];

SELECT DB_NAME() AS [Db],
       (SELECT COUNT(*) FROM sys.columns c JOIN sys.objects o ON o.[object_id] = c.[object_id]
        WHERE o.[type] IN ('U', 'V', 'IF', 'TF', 'FT') AND c.[name] IN (N'Username', N'ExternalId', N'ForegnTransactionId')) AS Expected,
       (SELECT COUNT(*) FROM sys.database_permissions p
        WHERE p.class = 1 AND p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'analytics_ro')
          AND p.state_desc = 'DENY' AND p.permission_name = 'SELECT' AND p.minor_id > 0) AS Actual;

SELECT r.[name] AS [Role], u.[name] AS [Member]
FROM sys.database_role_members m
JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
JOIN sys.database_principals u ON u.principal_id = m.member_principal_id
WHERE r.[name] IN (N'analytics_ro', N'db_datareader') AND (u.[name] = N'analytics_ro' OR u.[name] LIKE N'stats%');

SELECT u.[name] AS [User], OBJECT_SCHEMA_NAME(p.major_id) AS [Schema], OBJECT_NAME(p.major_id) AS [Object],
       c.[name] AS [Column], p.permission_name, p.[state_desc]
FROM sys.database_permissions p
JOIN sys.database_principals u ON u.principal_id = p.grantee_principal_id
LEFT JOIN sys.columns c ON c.[object_id] = p.major_id AND c.column_id = p.minor_id
WHERE p.class = 1 AND p.state_desc = 'DENY' AND u.[name] LIKE N'stats%';

-- Definition scan: views and functions whose text mentions a denied column name, whatever they
-- expose it as. Read each definition by hand.
SELECT DB_NAME() AS [Db], o.[type_desc], OBJECT_SCHEMA_NAME(o.[object_id]) + N'.' + o.[name] AS [Object]
FROM sys.sql_modules m
JOIN sys.objects o ON o.[object_id] = m.[object_id]
WHERE o.[type] IN ('V', 'IF', 'TF')
  AND EXISTS (SELECT 1 FROM (VALUES (N'Username'), (N'ExternalId'), (N'ForegnTransactionId')) n([col])
              WHERE m.[definition] LIKE N'%' + n.[col] + N'%');

-- Teardown (not a rollback): in each DB DROP the per-colleague users, then DROP ROLE [analytics_ro];
-- in master DROP the three per-colleague logins. Rolling the original stats_analyst_ro back to its
-- pre-migration state means re-granting db_datareader and re-creating its per-user DENYs by hand -
-- the script does not record them.
```

Cross-platform schema differences an analyst should know:
[stats_platform_schema_divergence.md](stats_platform_schema_divergence.md).

## Internal playtesting on YellowTest — `internal_playtester_ro`

Read-only access for internal AI playtesters on the **YellowTest** environment: the `Main` and
`Stats` databases of the test server. YellowTest holds test and QA accounts only, no real players,
so the cut is credentials, tokens and e-mail — material with no debugging value that must not leave
the server: password hashes and salts, access / refresh / device / security tokens, purchase
receipts (`ReceiptJson` embeds a user auth token), and e-mail addresses, which on a test server
belong to staff. Player identity stays readable. Column inventory as of 2026-09-30 on the
Code-branch schema.

`TestProfiles` stays readable: on YellowTest it holds profile snapshots taken from the same
database. The same table can hold profiles imported from other environments, production included,
wherever the admin-panel import was used — check before copying this role to such an environment.

The role and the logins are provisioned by two separate scripts: the role script is the one that
gets edited and re-run, the login script is run once per agent (`playtester_ai_N`, starting with
`playtester_ai_1`).

### Applying

Run the role script first, then the login script.

- **Role script** — no secrets in it. Re-run after a deploy (recreated views, see Pitfalls) and
  whenever the deny list grows. Of the views recreated on deploy only `VW_PlayerDetails` carries a
  denied column (`Email`); the gap between a deploy and the re-run is accepted for that. A new view
  over credentials or tokens would widen it — read the definition scan at the end of the script
  after a deploy that adds or changes views.
- **Login script** — replace the `<<SET_STRONG_PASSWORD>>` placeholder before running. If the role
  is missing, the script raises an error instead of creating a user without permissions; a
  same-name user left behind by a database restore is re-mapped to the login.
- **Another agent** — replace `playtester_ai_1` with the next login name throughout the login script.

### Connecting

The server is reachable over VPN only, by the name `yellowtest.fishingplanet.com`.

As observed on 2026-09-30, the SQL Server instance runs on the fallback self-generated certificate —
the error log carries "A self-generated certificate was successfully loaded for encryption"; whether
a certificate is installed but not selected was not checked. The setting in use is encryption
without validation (see Pitfalls for the per-driver form); the impersonation risk that leaves is
accepted because the server is reachable over VPN only. Binding the environment's wildcard HTTPS
certificate (`*.fishingplanet.com`, public CA) to SQL Server was considered and deferred as not
worth the renewal upkeep; its suitability for SQL Server (key storage, private-key access for the
service account) was not verified.

The game servers are unaffected either way: they reach the database through `localhost` without
requesting encryption.

### Role script — `InternalPlaytesterRole.sql`

```sql
/* Read-only role for internal AI playtesters on a TEST environment (yellowtest).
   - shared role [internal_playtester_ro] in Main and Stats: member of db_datareader + column
     DENY on credentials, tokens and e-mail columns, matched by column name on tables and views
   Logins are provisioned separately: InternalPlaytesterLogin.sql.
   Idempotent. RUN AS sysadmin. Requires SQL Server 2017+ (STRING_AGG).
   NOT for production: only credentials are cut, player identity columns stay readable.
   Re-run after a deploy: a view recreated by DROP/CREATE loses its column DENY. */

/* Per-database block below is IDENTICAL for every database except the USE statement.
   The column DENY matches by name, so it adapts to whatever each database carries. */

-- ============================ Main ============================
USE [Main];
GO
IF DATABASE_PRINCIPAL_ID(N'internal_playtester_ro') IS NULL
    CREATE ROLE [internal_playtester_ro];
ALTER ROLE [db_datareader] ADD MEMBER [internal_playtester_ro];
GO
-- Column DENY: every table/view column named as a credential, token or e-mail
DECLARE @deny nvarchar(max);
SELECT @deny = STRING_AGG(CAST(N'DENY SELECT ON OBJECT::' + QUOTENAME(s.[name]) + N'.' + QUOTENAME(o.[name])
     + N' (' + QUOTENAME(c.[name]) + N') TO [internal_playtester_ro];' AS nvarchar(max)), NCHAR(10))
FROM sys.columns c
JOIN sys.objects o ON o.[object_id] = c.[object_id]
JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] IN ('U', 'V', 'IF', 'TF', 'FT')
  AND c.[name] IN (N'Password', N'PasswordSalt',
                   N'SecurityToken', N'TwitchToken', N'TwitchRefreshToken', N'DeviceToken', N'ReceiptJson',
                   N'Email', N'TwitchEmail');
IF @deny IS NOT NULL EXEC sys.sp_executesql @deny;
GO

-- Verify. Expect: Expected = Actual (one DENY per matching column), listed below it; the role
-- itself is a member of db_datareader.
SELECT DB_NAME() AS [Db],
       (SELECT COUNT(*) FROM sys.columns c JOIN sys.objects o ON o.[object_id] = c.[object_id]
        WHERE o.[type] IN ('U', 'V', 'IF', 'TF', 'FT')
          AND c.[name] IN (N'Password', N'PasswordSalt', N'SecurityToken', N'TwitchToken', N'TwitchRefreshToken', N'DeviceToken', N'ReceiptJson', N'Email', N'TwitchEmail')) AS Expected,
       (SELECT COUNT(*) FROM sys.database_permissions p
        WHERE p.class = 1 AND p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'internal_playtester_ro')
          AND p.state_desc = 'DENY' AND p.permission_name = 'SELECT' AND p.minor_id > 0) AS Actual;

SELECT OBJECT_SCHEMA_NAME(p.major_id) AS [Schema], OBJECT_NAME(p.major_id) AS [Object],
       c.[name] AS [Column], p.permission_name, p.[state_desc]
FROM sys.database_permissions p
LEFT JOIN sys.columns c ON c.[object_id] = p.major_id AND c.column_id = p.minor_id
WHERE p.class = 1 AND p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'internal_playtester_ro') AND p.state_desc = 'DENY'
ORDER BY [Object], [Column];

SELECT r.[name] AS [Role], u.[name] AS [Member]
FROM sys.database_role_members m
JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
JOIN sys.database_principals u ON u.principal_id = m.member_principal_id
WHERE r.[name] = N'internal_playtester_ro' OR u.[name] = N'internal_playtester_ro';

-- Definition scan: views and functions whose text mentions a denied column name, whatever they
-- expose it as. Read each definition by hand.
SELECT DB_NAME() AS [Db], o.[type_desc], OBJECT_SCHEMA_NAME(o.[object_id]) + N'.' + o.[name] AS [Object]
FROM sys.sql_modules m
JOIN sys.objects o ON o.[object_id] = m.[object_id]
WHERE o.[type] IN ('V', 'IF', 'TF')
  AND EXISTS (SELECT 1 FROM (VALUES (N'Password'), (N'PasswordSalt'), (N'SecurityToken'), (N'TwitchToken'), (N'TwitchRefreshToken'), (N'DeviceToken'), (N'ReceiptJson'), (N'Email'), (N'TwitchEmail')) n([col])
              WHERE m.[definition] LIKE N'%' + n.[col] + N'%');
GO

-- ============================ Stats ============================
USE [Stats];
GO
IF DATABASE_PRINCIPAL_ID(N'internal_playtester_ro') IS NULL
    CREATE ROLE [internal_playtester_ro];
ALTER ROLE [db_datareader] ADD MEMBER [internal_playtester_ro];
GO
-- Column DENY: every table/view column named as a credential, token or e-mail
DECLARE @deny nvarchar(max);
SELECT @deny = STRING_AGG(CAST(N'DENY SELECT ON OBJECT::' + QUOTENAME(s.[name]) + N'.' + QUOTENAME(o.[name])
     + N' (' + QUOTENAME(c.[name]) + N') TO [internal_playtester_ro];' AS nvarchar(max)), NCHAR(10))
FROM sys.columns c
JOIN sys.objects o ON o.[object_id] = c.[object_id]
JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] IN ('U', 'V', 'IF', 'TF', 'FT')
  AND c.[name] IN (N'Password', N'PasswordSalt',
                   N'SecurityToken', N'TwitchToken', N'TwitchRefreshToken', N'DeviceToken', N'ReceiptJson',
                   N'Email', N'TwitchEmail');
IF @deny IS NOT NULL EXEC sys.sp_executesql @deny;
GO

-- Verify. Expect: Expected = Actual (one DENY per matching column), listed below it; the role
-- itself is a member of db_datareader.
SELECT DB_NAME() AS [Db],
       (SELECT COUNT(*) FROM sys.columns c JOIN sys.objects o ON o.[object_id] = c.[object_id]
        WHERE o.[type] IN ('U', 'V', 'IF', 'TF', 'FT')
          AND c.[name] IN (N'Password', N'PasswordSalt', N'SecurityToken', N'TwitchToken', N'TwitchRefreshToken', N'DeviceToken', N'ReceiptJson', N'Email', N'TwitchEmail')) AS Expected,
       (SELECT COUNT(*) FROM sys.database_permissions p
        WHERE p.class = 1 AND p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'internal_playtester_ro')
          AND p.state_desc = 'DENY' AND p.permission_name = 'SELECT' AND p.minor_id > 0) AS Actual;

SELECT OBJECT_SCHEMA_NAME(p.major_id) AS [Schema], OBJECT_NAME(p.major_id) AS [Object],
       c.[name] AS [Column], p.permission_name, p.[state_desc]
FROM sys.database_permissions p
LEFT JOIN sys.columns c ON c.[object_id] = p.major_id AND c.column_id = p.minor_id
WHERE p.class = 1 AND p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'internal_playtester_ro') AND p.state_desc = 'DENY'
ORDER BY [Object], [Column];

SELECT r.[name] AS [Role], u.[name] AS [Member]
FROM sys.database_role_members m
JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
JOIN sys.database_principals u ON u.principal_id = m.member_principal_id
WHERE r.[name] = N'internal_playtester_ro' OR u.[name] = N'internal_playtester_ro';

-- Definition scan: views and functions whose text mentions a denied column name, whatever they
-- expose it as. Read each definition by hand.
SELECT DB_NAME() AS [Db], o.[type_desc], OBJECT_SCHEMA_NAME(o.[object_id]) + N'.' + o.[name] AS [Object]
FROM sys.sql_modules m
JOIN sys.objects o ON o.[object_id] = m.[object_id]
WHERE o.[type] IN ('V', 'IF', 'TF')
  AND EXISTS (SELECT 1 FROM (VALUES (N'Password'), (N'PasswordSalt'), (N'SecurityToken'), (N'TwitchToken'), (N'TwitchRefreshToken'), (N'DeviceToken'), (N'ReceiptJson'), (N'Email'), (N'TwitchEmail')) n([col])
              WHERE m.[definition] LIKE N'%' + n.[col] + N'%');
GO

-- Rollback (teardown): remove the logins first (InternalPlaytesterLogin.sql, removal block),
-- then in each DB DROP ROLE [internal_playtester_ro].
```

### Login script — `InternalPlaytesterLogin.sql`

```sql
/* Login for an internal AI playtester on a TEST environment (yellowtest).
   An impersonal per-agent login that is only a member of [internal_playtester_ro] in Main and
   Stats; all permissions come from the role. Run InternalPlaytesterRole.sql first.
   Idempotent. RUN AS sysadmin.
   Set the <<SET_STRONG_PASSWORD>> placeholder before running -- the login is not created while the
   placeholder is still in place.
   Another agent: replace [playtester_ai_1] with the next login name throughout the file. */

USE [master];
GO
DECLARE @pwd nvarchar(128) = N'<<SET_STRONG_PASSWORD>>';
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE [name] = N'playtester_ai_1')
BEGIN
    IF @pwd LIKE N'<<%>>' THROW 50000, N'Password placeholder not replaced - set <<SET_STRONG_PASSWORD>> first.', 1;
    EXEC (N'CREATE LOGIN [playtester_ai_1] WITH PASSWORD = ' + QUOTENAME(@pwd, '''') + N', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF, DEFAULT_DATABASE = [Main];');
END
GO

/* Per-database block below is IDENTICAL for every database except the USE statement. */

-- ============================ Main ============================
USE [Main];
GO
-- Database user for the login, a member of the role only
IF DATABASE_PRINCIPAL_ID(N'internal_playtester_ro') IS NULL
    RAISERROR(N'Role [internal_playtester_ro] is missing - run InternalPlaytesterRole.sql first.', 16, 1);
ELSE IF SUSER_ID(N'playtester_ai_1') IS NOT NULL
BEGIN
    IF DATABASE_PRINCIPAL_ID(N'playtester_ai_1') IS NULL CREATE USER [playtester_ai_1] FOR LOGIN [playtester_ai_1];
    ELSE ALTER USER [playtester_ai_1] WITH LOGIN = [playtester_ai_1]; -- re-maps a same-name user left by a restore
    ALTER ROLE [internal_playtester_ro] ADD MEMBER [playtester_ai_1];
END
GO

-- Verify. Expect: exactly one row, [playtester_ai_1] in [internal_playtester_ro].
SELECT DB_NAME() AS [Db], r.[name] AS [Role], u.[name] AS [Member]
FROM sys.database_role_members m
JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
JOIN sys.database_principals u ON u.principal_id = m.member_principal_id
WHERE u.[name] = N'playtester_ai_1';
GO

-- ============================ Stats ============================
USE [Stats];
GO
-- Database user for the login, a member of the role only
IF DATABASE_PRINCIPAL_ID(N'internal_playtester_ro') IS NULL
    RAISERROR(N'Role [internal_playtester_ro] is missing - run InternalPlaytesterRole.sql first.', 16, 1);
ELSE IF SUSER_ID(N'playtester_ai_1') IS NOT NULL
BEGIN
    IF DATABASE_PRINCIPAL_ID(N'playtester_ai_1') IS NULL CREATE USER [playtester_ai_1] FOR LOGIN [playtester_ai_1];
    ELSE ALTER USER [playtester_ai_1] WITH LOGIN = [playtester_ai_1]; -- re-maps a same-name user left by a restore
    ALTER ROLE [internal_playtester_ro] ADD MEMBER [playtester_ai_1];
END
GO

-- Verify. Expect: exactly one row, [playtester_ai_1] in [internal_playtester_ro].
SELECT DB_NAME() AS [Db], r.[name] AS [Role], u.[name] AS [Member]
FROM sys.database_role_members m
JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
JOIN sys.database_principals u ON u.principal_id = m.member_principal_id
WHERE u.[name] = N'playtester_ai_1';
GO

-- Removal. Uncomment and run as a whole. The login is disabled first, so a DROP LOGIN that fails on
-- an open session leaves a disabled login, not a live one: kill the session and re-run the last batch.
-- USE [master];
-- GO
-- IF EXISTS (SELECT 1 FROM sys.server_principals WHERE [name] = N'playtester_ai_1')
--     ALTER LOGIN [playtester_ai_1] DISABLE;
-- GO
-- USE [Main];
-- GO
-- DROP USER IF EXISTS [playtester_ai_1];
-- GO
-- USE [Stats];
-- GO
-- DROP USER IF EXISTS [playtester_ai_1];
-- GO
-- USE [master];
-- GO
-- IF EXISTS (SELECT 1 FROM sys.server_principals WHERE [name] = N'playtester_ai_1')
--     DROP LOGIN [playtester_ai_1];
-- GO
```

### Permission check

Run as `sysadmin`. `EXECUTE AS USER` tests database permissions only — it says nothing about the
login itself (password, enabled or locked state, default database), so finish with one real
connection through the agent's driver. The first query must return a row; the other two must fail
with a column-permission error. If the console stops at the first error, run the rest and `REVERT`
by hand: the impersonation stays in effect until `REVERT` or the end of the session, and the last
query confirms it is gone.

```sql
-- internal playtester: permission check
USE [Main];
EXECUTE AS USER = N'playtester_ai_1';
SELECT TOP 1 UserId, Username FROM dbo.Users WITH (NOLOCK);
SELECT TOP 1 Email FROM dbo.Users WITH (NOLOCK);
SELECT TOP 1 Email FROM dbo.VW_PlayerDetails WITH (NOLOCK);
REVERT;
SELECT USER_NAME() AS [RunningAs];
```
