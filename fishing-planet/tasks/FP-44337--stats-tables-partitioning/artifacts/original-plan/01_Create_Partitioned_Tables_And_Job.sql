--Step 1 
-- На ПРОДІ Перейменування існуючого StatsFact
USE [Stats];
GO

EXEC sp_rename 'dbo.StatsFact',     'StatsFact_old';
EXEC sp_rename 'PK_StatsFact',      'PK_StatsFact_old',      'OBJECT';
EXEC sp_rename 'DF_StatsFact_Rank', 'DF_StatsFact_Rank_old', 'OBJECT';
GO

-- Перевірка
SELECT name FROM sys.objects
WHERE name IN ('StatsFact_old', 'PK_StatsFact_old', 'DF_StatsFact_Rank_old');


-- Step 2

IF EXISTS (SELECT 1 FROM sys.partition_schemes WHERE name = 'ps_StatsFact_Timestamp')
    DROP PARTITION SCHEME ps_StatsFact_Timestamp;
IF EXISTS (SELECT 1 FROM sys.partition_functions WHERE name = 'pf_StatsFact_Timestamp')
    DROP PARTITION FUNCTION pf_StatsFact_Timestamp;
GO

--Step 3 

DECLARE @DataPath NVARCHAR(260) = N'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER2019\MSSQL\DATA'; 
DECLARE @dbName   SYSNAME       = DB_NAME();
DECLARE @sql      NVARCHAR(MAX);

-- Червень
IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name = 'FG_StatsFact_2026_06')
BEGIN
    SET @sql = N'ALTER DATABASE [' + @dbName + N'] ADD FILEGROUP [FG_StatsFact_2026_06];';
    EXEC sp_executesql @sql;

    SET @sql = N'ALTER DATABASE [' + @dbName + N'] ADD FILE (
        NAME = N''StatsFact_2026_06'',
        FILENAME = N''' + @DataPath + N'StatsFact_2026_06.ndf'',
        SIZE = 51200MB, FILEGROWTH = 10240MB) TO FILEGROUP [FG_StatsFact_2026_06];';
    EXEC sp_executesql @sql;
END

-- Липень (буфер)
IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name = 'FG_StatsFact_2026_07')
BEGIN
    SET @sql = N'ALTER DATABASE [' + @dbName + N'] ADD FILEGROUP [FG_StatsFact_2026_07];';
    EXEC sp_executesql @sql;

    SET @sql = N'ALTER DATABASE [' + @dbName + N'] ADD FILE (
        NAME = N''StatsFact_2026_07'',
        FILENAME = N''' + @DataPath + N'StatsFact_2026_07.ndf'',
        SIZE = 51200MB, FILEGROWTH = 10240MB) TO FILEGROUP [FG_StatsFact_2026_07];';
    EXEC sp_executesql @sql;
END
GO

-- Перевірка
SELECT fg.name, df.physical_name, df.size * 8 / 1024 AS size_mb
FROM sys.filegroups fg
LEFT JOIN sys.database_files df ON df.data_space_id = fg.data_space_id
WHERE fg.name LIKE 'FG_StatsFact_2026_%';
-- Має бути 2 рядки по 51200 MB

--
--   Partition Function

-- Step 4
CREATE PARTITION FUNCTION pf_StatsFact_Timestamp (DATETIME)
AS RANGE RIGHT FOR VALUES ('2026-07-01T00:00:00');
GO

--Тепер:

--Партиція 1 (< 2026-07-01, червень) → FG_StatsFact_2026_06
--Партиція 2 (>= 2026-07-01, липень+) → FG_StatsFact_2026_07

-- 28-го числа додасть FG_2026_08 і зробить split, далі кожен місяць у своєму FG.


--   Partition Scheme — КОЖНА партиція в СВОЮ filegroup
CREATE PARTITION SCHEME ps_StatsFact_Timestamp
AS PARTITION pf_StatsFact_Timestamp
TO ([FG_StatsFact_2026_06], [FG_StatsFact_2026_07]);   -- ⬅ кожен FG свій
GO



---  Розрахунок IDENTITY-старту

--step 5 
DECLARE @maxFromData BIGINT, @identCurr BIGINT, @startFrom BIGINT;
SELECT @maxFromData = ISNULL(MAX(EntityId), 0) FROM dbo.StatsFact_old WITH (NOLOCK);
SELECT @identCurr   = CAST(IDENT_CURRENT('dbo.StatsFact_old') AS BIGINT);
SET @startFrom = CASE WHEN @maxFromData > @identCurr THEN @maxFromData ELSE @identCurr END + 1000;

PRINT 'IDENTITY start = ' + CAST(@startFrom AS VARCHAR(20));

IF OBJECT_ID('tempdb..#StartFrom') IS NOT NULL DROP TABLE #StartFrom;
SELECT @startFrom AS StartFrom INTO #StartFrom;


--482018

-- Step 6 NEW TABLE
DECLARE @startFrom BIGINT;
SELECT @startFrom = StartFrom FROM #StartFrom;

DECLARE @sql NVARCHAR(MAX) =
N'CREATE TABLE dbo.StatsFact (
    EntityId BIGINT IDENTITY(' + CAST(@startFrom AS NVARCHAR(20)) + N', 1) NOT NULL,
    UserId UNIQUEIDENTIFIER NOT NULL,
    [Timestamp] DATETIME NOT NULL,
    Source VARCHAR(12) NULL,
    [Level] INT NOT NULL,
    Pond VARCHAR(128) NULL,
    [Location] VARCHAR(128) NULL,
    FishBox VARCHAR(128) NULL,
    Bait VARCHAR(128) NULL,
    RodTemplate VARCHAR(32) NULL,
    FishName VARCHAR(128) NULL,
    AchievementName VARCHAR(128) NULL,
    StateName VARCHAR(128) NULL,
    Product VARCHAR(128) NULL,
    Money INT NULL,
    Achievement INT NULL,
    TimeOfDay INT NULL,
    Weather VARCHAR(16) NULL,
    SilverSpentInShop INT NULL,
    GoldSpentInShop INT NULL,
    SilverSpentOnRepair INT NULL,
    GoldSpentOnRepair INT NULL,
    SilverSpentOnLicense INT NULL,
    GoldSpentOnLicense INT NULL,
    ItemType VARCHAR(32) NULL,
    LicenseDays INT NULL,
    SilverEarnedForDay INT NULL,
    GoldEarnedForDay INT NULL,
    FishCount INT NULL,
    FishCageFishCount INT NULL,
    TravelCount INT NULL,
    DaysSpent INT NULL,
    SilverEarnedForFish INT NULL,
    GoldEarnedForFish INT NULL,
    SilverSpentForTravel INT NULL,
    GoldSpentForTravel INT NULL,
    RealTimeSpent INT NULL,
    Silver INT NULL,
    Gold INT NULL,
    FishWeight FLOAT NULL,
    FishLength FLOAT NULL,
    RodType VARCHAR(32) NULL,
    ReelType VARCHAR(32) NULL,
    LineType VARCHAR(32) NULL,
    TackleType VARCHAR(32) NULL,
    HookSize FLOAT NULL,
    Crash VARCHAR(10) NULL,
    TournamentId INT NULL,
    PondTime VARCHAR(10) NULL,
    GameDayNumber INT NULL,
    Throw BIT NULL,
    HitchBoxName VARCHAR(50) NULL,
    HitchMaxLoad FLOAT NULL,
    IsReleased BIT NULL,
    TimeForward INT NULL,
    BaseExp INT NULL,
    Exp INT NULL,
    [Rank] INT NOT NULL CONSTRAINT DF_StatsFact_Rank DEFAULT (0),
    IsBoatCatch BIT NULL,
    ItemId INT NULL,
    ItemCount INT NULL,
    EventType INT NULL,
    TimeEnd DATETIME NULL,
    Duration FLOAT NULL,
    HasPremium BIT NULL,
    BalanceSilver INT NULL,
    BalanceGold INT NULL,
    BalanceClubTokens INT NULL,
    ClubTokensSpentInShop INT NULL,
    ClubTokensEarnedForDay INT NULL,
    ClubTokens INT NULL,
    BoatSpeed FLOAT NULL,
    BoatId INT NULL,
    DragStyle VARCHAR(10) NULL,
    IsHookedWithTrolling BIT NULL,
    FtSessionId INT NULL,
    GameSessionId UNIQUEIDENTIFIER NULL,
    TotalExp BIGINT NULL,
    SlotNumber TINYINT NULL,
    RodId INT NULL,
    Flag1 BIT NULL,
    ReelId INT NULL,
    LineId INT NULL,
    LeaderId INT NULL,
    RodMaxLoad FLOAT NULL,
    ReelMaxLoad FLOAT NULL,
    LineMaxLoad FLOAT NULL,
    LeaderMaxLoad FLOAT NULL,
    LeaderType VARCHAR(32) NULL,

    CONSTRAINT PK_StatsFact PRIMARY KEY CLUSTERED (EntityId, [Timestamp])
        WITH (DATA_COMPRESSION = PAGE)
        ON ps_StatsFact_Timestamp([Timestamp])
) ON ps_StatsFact_Timestamp([Timestamp]);';

EXEC sp_executesql @sql;
DROP TABLE #StartFrom;
GO

--  Aligned NC індекс на UserId

-- Step 7 
CREATE NONCLUSTERED INDEX IX_StatsFact_UserId_Aligned
ON dbo.StatsFact (UserId, [Timestamp])
WITH (DATA_COMPRESSION = PAGE)
ON ps_StatsFact_Timestamp([Timestamp]);
GO

--  Верифікація

SELECT COUNT(*) AS missing_columns
FROM sys.dm_exec_describe_first_result_set('SELECT * FROM dbo.StatsFact_old', NULL, 1) c
WHERE NOT EXISTS (
    SELECT 1 FROM sys.dm_exec_describe_first_result_set('SELECT * FROM dbo.StatsFact', NULL, 1) n
    WHERE n.name = c.name AND n.system_type_name = c.system_type_name AND n.is_nullable = c.is_nullable
);
-- Має бути 0

-- IDENTITY
SELECT IDENT_SEED('dbo.StatsFact') AS seed, IDENT_CURRENT('dbo.StatsFact') AS curr;

-- Партиції
SELECT
    p.partition_number, p.rows, fg.name AS filegroup, prv.value AS upper_boundary
FROM sys.partitions p
JOIN sys.indexes i ON i.object_id = p.object_id AND i.index_id = p.index_id
JOIN sys.partition_schemes ps ON ps.data_space_id = i.data_space_id
JOIN sys.destination_data_spaces dds
    ON dds.partition_scheme_id = ps.data_space_id AND dds.destination_id = p.partition_number
JOIN sys.filegroups fg ON fg.data_space_id = dds.data_space_id
LEFT JOIN sys.partition_range_values prv
    ON prv.function_id = ps.function_id AND prv.boundary_id = p.partition_number
WHERE p.object_id = OBJECT_ID('dbo.StatsFact') AND i.index_id IN (0,1)
ORDER BY p.partition_number;

--STEP 8

-- Stored Procedure usp_StatsFact_AddNextMonth
CREATE OR ALTER PROCEDURE dbo.usp_StatsFact_AddNextMonth
    @DataPath   NVARCHAR(260) = N'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER2019\MSSQL\DATA',
    @InitSizeMB INT           = 51200,
    @GrowthMB   INT           = 10240,
    @Debug      BIT           = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @maxBoundary DATETIME, @nextMonth DATETIME;
    DECLARE @suffix NVARCHAR(7), @fgName SYSNAME, @fileName SYSNAME;
    DECLARE @sql NVARCHAR(MAX), @dbName SYSNAME = DB_NAME();

    SELECT @maxBoundary = MAX(CAST(value AS DATETIME))
    FROM sys.partition_range_values prv
    JOIN sys.partition_functions pf ON pf.function_id = prv.function_id
    WHERE pf.name = 'pf_StatsFact_Timestamp';

    SET @nextMonth = DATEADD(MONTH, 1, @maxBoundary);
    SET @suffix    = FORMAT(@nextMonth, 'yyyy_MM');
    SET @fgName    = N'FG_StatsFact_' + @suffix;
    SET @fileName  = N'StatsFact_'    + @suffix;

    IF EXISTS (SELECT 1 FROM sys.filegroups WHERE name = @fgName)
    BEGIN PRINT 'FG ' + @fgName + ' already exists, skipping.'; RETURN; END

    SET @sql = N'ALTER DATABASE [' + @dbName + N'] ADD FILEGROUP [' + @fgName + N'];';
    PRINT @sql; IF @Debug = 0 EXEC sp_executesql @sql;

    SET @sql = N'ALTER DATABASE [' + @dbName + N'] ADD FILE (' +
        N'NAME=N''' + @fileName + N''',FILENAME=N''' + @DataPath + @fileName + N'.ndf'',' +
        N'SIZE=' + CAST(@InitSizeMB AS NVARCHAR(10)) + N'MB,' +
        N'FILEGROWTH=' + CAST(@GrowthMB AS NVARCHAR(10)) + N'MB) TO FILEGROUP [' + @fgName + N'];';
    PRINT @sql; IF @Debug = 0 EXEC sp_executesql @sql;

    SET @sql = N'ALTER PARTITION SCHEME ps_StatsFact_Timestamp NEXT USED [' + @fgName + N'];';
    PRINT @sql; IF @Debug = 0 EXEC sp_executesql @sql;

    SET @sql = N'ALTER PARTITION FUNCTION pf_StatsFact_Timestamp() SPLIT RANGE (''' +
               CONVERT(NVARCHAR(23), @nextMonth, 121) + N''');';
    PRINT @sql; IF @Debug = 0 EXEC sp_executesql @sql;

    PRINT '+++ Added ' + @suffix;
END
GO

-- Dry-run перевірка
EXEC dbo.usp_StatsFact_AddNextMonth @Debug = 1;



--SQL Agent Job — 28-го о 23:00

--Запустити Агента в сервісах 

--Step 9 JOB 

USE msdb;
GO

IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = 'StatsFact_AddNextMonth')
    EXEC dbo.sp_delete_job @job_name = N'StatsFact_AddNextMonth';
GO

DECLARE @jobId UNIQUEIDENTIFIER;

EXEC dbo.sp_add_job
    @job_name        = N'StatsFact_AddNextMonth',
    @enabled         = 1,
    @description     = N'Creating FG + partition for new month in dbo.StatsFact',
    @owner_login_name = N'sa',
    @job_id          = @jobId OUTPUT;

EXEC dbo.sp_add_jobstep
    @job_id            = @jobId,
    @step_name         = N'Run usp_StatsFact_AddNextMonth',
    @subsystem         = N'TSQL',
    @command           = N'EXEC dbo.usp_StatsFact_AddNextMonth;',
    @database_name     = N'Stats', 
    @on_success_action = 1,
    @retry_attempts    = 2,
    @retry_interval    = 5;

EXEC dbo.sp_add_schedule
    @schedule_name          = N'Monthly_28th_at_23',
    @freq_type              = 16,        -- monthly
    @freq_interval          = 28,        -- 28-th
    @freq_recurrence_factor = 1,         -- everymonth
    @active_start_time      = 230000;    -- 23:00:00

EXEC dbo.sp_attach_schedule
    @job_name      = N'StatsFact_AddNextMonth',
    @schedule_name = N'Monthly_28th_at_23';

EXEC dbo.sp_add_jobserver
    @job_name    = N'StatsFact_AddNextMonth',
    @server_name = N'(LOCAL)';
GO



-- Перевірка нових записів
USE [Stats];

SELECT TOP 10 EntityId, [Timestamp], EventType, FishName, Source
FROM dbo.StatsFact
ORDER BY EntityId DESC;



-- Перевірка партицій

SELECT
    p.partition_number, p.rows, fg.name AS filegroup, prv.value AS upper_boundary
FROM sys.partitions p
JOIN sys.indexes i ON i.object_id = p.object_id AND i.index_id = p.index_id
JOIN sys.partition_schemes ps ON ps.data_space_id = i.data_space_id
JOIN sys.destination_data_spaces dds
    ON dds.partition_scheme_id = ps.data_space_id AND dds.destination_id = p.partition_number
JOIN sys.filegroups fg ON fg.data_space_id = dds.data_space_id
LEFT JOIN sys.partition_range_values prv
    ON prv.function_id = ps.function_id AND prv.boundary_id = p.partition_number
WHERE p.object_id = OBJECT_ID('dbo.StatsFact') AND i.index_id IN (0,1)
ORDER BY p.partition_number;

