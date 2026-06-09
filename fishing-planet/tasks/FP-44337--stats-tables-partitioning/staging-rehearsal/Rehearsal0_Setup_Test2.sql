/* ============================================================================
   FP-44337  Rehearsal 0  |  SERVER: TEST2 (Enterprise 15.0.2000.5) — NON-PROD
   Build a throwaway DB that mimics the PRE-cutover PROD state, so Phase 2->3
   (and optionally 6) can be rehearsed without touching the live Test2 [Stats]
   or the SQLSTAGING backstop.

   What this creates:
     - DB [StatsFP44337] (throwaway; drop when done).
     - dbo.StatsFact / dbo.MissionsFact in the EXACT prod column layout (copied
       from Phase2_PROD_Swap.sql), NON-partitioned, clustered PK on EntityId only,
       no secondary index — i.e. the prod "old" shape. Constraint names match what
       Phase 2 renames (PK_StatsFact, DF_StatsFact_Rank, PK_MissionsFact).
     - Synthetic data with Timestamps spread 2026-04-01 .. 2026-06-09 (the REAL June
       cutover state — there is no July/August data yet):
         * All rows < 2026-07-01 -> partition P1. P2 (July) and P3 (August) stay EMPTY,
           exactly as at the live June cutover (the empty trailing buffers).
         * History (Apr/May, < 2026-06-01) stays in *_old; the June tail (Jun 1..Jun 9)
           is what Phase 3 loads into the new table -> P1.
         * EntityId is monotonic with Timestamp (IDENTITY assigned in ORDER BY order)
           -> Phase 3's EntityId<->Timestamp binary search for the June-1 boundary is real.
         * @tailFrom 2026-06-01 sits inside the range -> the tail load does real work.
       (RANGE RIGHT routing into P2/P3 is a POST-cutover concern — validate it separately
        by inserting a July/August row after START, not by pre-loading fake history.)

   REHEARSAL DELTAS vs prod (intentional): different DB name (USE [StatsFP44337]),
   Test2 data path, and tiny partition files (set in the adapted Phase 2). The
   column layout is identical, so the Phase 2 column-compare verifies cleanly.
   ============================================================================ */

------------------------------------------------------------------------------
-- 0) Fresh throwaway DB.
------------------------------------------------------------------------------
USE master;
GO
IF DB_ID('StatsFP44337') IS NOT NULL
BEGIN
    ALTER DATABASE StatsFP44337 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE StatsFP44337;
END
GO
CREATE DATABASE StatsFP44337;
GO
ALTER DATABASE StatsFP44337 SET RECOVERY SIMPLE;   -- match prod (SIMPLE)
GO

USE StatsFP44337;
GO

------------------------------------------------------------------------------
-- 1) OLD-shape tables (exact prod columns; clustered PK on EntityId only).
------------------------------------------------------------------------------
-- EntityId is the 58th column in the live schema (after Rank), not the first - match it.
CREATE TABLE dbo.StatsFact (
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
    EntityId BIGINT IDENTITY(1,1) NOT NULL,
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
    CONSTRAINT PK_StatsFact PRIMARY KEY CLUSTERED (EntityId)
);
GO

CREATE TABLE dbo.MissionsFact (
    EntityId BIGINT IDENTITY(1,1) NOT NULL,
    UserId UNIQUEIDENTIFIER NOT NULL,
    [Timestamp] DATETIME NOT NULL,
    Source VARCHAR(12) NULL,
    [Level] INT NOT NULL,
    [Rank] INT NOT NULL,
    Pond INT NULL,
    TournamentId INT NULL,
    GameDayNumber INT NOT NULL,
    MissionId INT NOT NULL,
    MissionCode VARCHAR(100) NULL,
    TaskId INT NULL,
    TaskCode VARCHAR(100) NULL,
    EventType VARCHAR(32) NOT NULL,
    [Message] NVARCHAR(MAX) NULL,
    Argument INT NULL,
    TaskDfn VARCHAR(255) NULL,
    MissionDifficulty TINYINT NULL,
    TaskDifficulty TINYINT NULL,
    CONSTRAINT PK_MissionsFact PRIMARY KEY CLUSTERED (EntityId)
);
GO

------------------------------------------------------------------------------
-- 2) Synthetic data. Timestamps linear over [2026-04-01, 2026-07-20); EntityId
--    monotonic with time (ORDER BY rn drives IDENTITY assignment).
--    Tune @rows for a heavier/lighter run.
------------------------------------------------------------------------------
DECLARE @rows INT = 1000000;
DECLARE @startTs DATETIME = '2026-04-01T00:00:00';
DECLARE @endTs   DATETIME = '2026-06-09T15:00:00';   -- ~now; the June cutover state (no July/Aug yet)
DECLARE @spanSec FLOAT = DATEDIFF(SECOND, @startTs, @endTs);

;WITH n AS (
    SELECT TOP (@rows) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_columns a CROSS JOIN sys.all_columns b
)
INSERT INTO dbo.StatsFact (UserId, [Timestamp], [Level], [Rank])
SELECT NEWID(),
       DATEADD(SECOND, CAST(rn * @spanSec / @rows AS INT), @startTs),
       0, 0
FROM n
ORDER BY rn;     -- IDENTITY assigned in this order -> EntityId ASC == Timestamp ASC
GO

DECLARE @rows INT = 1000000;
DECLARE @startTs DATETIME = '2026-04-01T00:00:00';
DECLARE @endTs   DATETIME = '2026-06-09T15:00:00';   -- ~now; the June cutover state (no July/Aug yet)
DECLARE @spanSec FLOAT = DATEDIFF(SECOND, @startTs, @endTs);

;WITH n AS (
    SELECT TOP (@rows) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_columns a CROSS JOIN sys.all_columns b
)
INSERT INTO dbo.MissionsFact (UserId, [Timestamp], [Level], [Rank], GameDayNumber, MissionId, EventType, [Message])
SELECT NEWID(),
       DATEADD(SECOND, CAST(rn * @spanSec / @rows AS INT), @startTs),
       0, 0, 0, (rn % 50),
       'rehearsal',
       CASE WHEN rn % 1000 = 0 THEN REPLICATE(N'x', 300) ELSE NULL END  -- a few >255-char Messages to exercise the SHA2_256 msg_chk path
FROM n
ORDER BY rn;
GO

------------------------------------------------------------------------------
-- 3) Sanity: row counts + the date buckets the partition function will route to.
------------------------------------------------------------------------------
SELECT 'StatsFact' AS tbl, COUNT_BIG(*) AS rows_cnt, MIN([Timestamp]) AS min_ts, MAX([Timestamp]) AS max_ts,
       MIN(EntityId) AS min_id, MAX(EntityId) AS max_id FROM dbo.StatsFact
UNION ALL
SELECT 'MissionsFact', COUNT_BIG(*), MIN([Timestamp]), MAX([Timestamp]), MIN(EntityId), MAX(EntityId) FROM dbo.MissionsFact;

-- All rows < 2026-07-01 -> P1. P2 (July) and P3 (Aug) MUST be 0 (the cutover state).
-- The June tail (>= @tailFrom) is what Phase 3 will load; the rest stays in *_old.
SELECT bucket = CASE WHEN [Timestamp] <  '2026-06-01' THEN 'history (<Jun, stays in *_old)'
                     WHEN [Timestamp] <  '2026-07-01' THEN 'June tail (P1, Phase 3 loads)'
                     WHEN [Timestamp] <  '2026-08-01' THEN 'P2 July -- expect 0'
                     ELSE                                    'P3 Aug -- expect 0' END,
       cnt = COUNT_BIG(*)
FROM dbo.StatsFact GROUP BY CASE WHEN [Timestamp] < '2026-06-01' THEN 'history (<Jun, stays in *_old)'
                                 WHEN [Timestamp] < '2026-07-01' THEN 'June tail (P1, Phase 3 loads)'
                                 WHEN [Timestamp] < '2026-08-01' THEN 'P2 July -- expect 0'
                                 ELSE                                'P3 Aug -- expect 0' END
ORDER BY bucket;
GO
