-- FP-43631 verify-bans-2026-08-09 -- 3-layer post-ban check (Profiles + LB)
-- ============================================================================
-- Standing rule from week-3/4 incidents: after every ban cycle, verify all three layers
-- (Profiles / CompetitiveRatingsCurrent / Mongo banLog) per platform individually.
-- This script covers the SQL layers; Mongo banLog verify is a one-liner at the bottom of
-- ban-log-backfill-2026-08-09.js.
--
-- Run on each platform PROD MAIN. Non-belonging UserIds LEFT JOIN to NULL (expected).
--
-- All ten bans this cycle are NEW (4 weeks). RGC_ReeL_SKiiLLz is the one exception in the
-- expectations below: his Profile is intentionally NOT written by our script because Support
-- already banned him to 2026-09-09, which runs longer than our 2026-09-07. His expected BanEnd
-- is therefore Support's date, and a row reading 2026-09-07 for him would mean we shortened
-- someone else's ban -- that is the failure to look for, not the reverse.

DECLARE @ExpectedBanEnd_NEW     date = '2026-09-07';   -- 4 weeks, ours
DECLARE @ExpectedBanEnd_Support date = '2026-09-09';   -- Support's pre-existing ban on RGC_ReeL_SKiiLLz

WITH BannedThisCycle AS (
    SELECT * FROM (VALUES
        -- Steam (4)
        (CAST('82C921B5-1383-437D-9AFA-9D711A344481' AS uniqueidentifier), 'Dr.Seven',         @ExpectedBanEnd_NEW,     'NEW', 'Steam'),
        (CAST('9584B60D-67D5-4362-8021-F1065562A5BC' AS uniqueidentifier), 'lailailaiyu',      @ExpectedBanEnd_NEW,     'NEW', 'Steam'),
        (CAST('B4B0C273-5B5C-4A0C-BDDF-E204EE7F6B1A' AS uniqueidentifier), 'ShadowOfOxigen',   @ExpectedBanEnd_NEW,     'NEW', 'Steam'),
        (CAST('4422CD0F-153B-477B-A4F5-60353C37B5EA' AS uniqueidentifier), 'Martino_CZ',       @ExpectedBanEnd_NEW,     'NEW', 'Steam'),
        -- PS (5) -- RGC_ReeL_SKiiLLz expected to carry Support's later date, untouched by us
        (CAST('C51F5F26-2816-4FF9-88F3-530AF5E7E875' AS uniqueidentifier), 'RGC_ReeL_SKiiLLz', @ExpectedBanEnd_Support, 'NEW', 'PS'   ),
        (CAST('92264697-3829-4C7A-93F3-861F4533C3BA' AS uniqueidentifier), 'Angel_of_Dunkirk', @ExpectedBanEnd_NEW,     'NEW', 'PS'   ),
        (CAST('BFAF6154-7A56-4025-A4A8-4FFE8D6B74B1' AS uniqueidentifier), 'switch-toad',      @ExpectedBanEnd_NEW,     'NEW', 'PS'   ),
        (CAST('AB70490A-BFFB-4E18-9297-B3479BAC4369' AS uniqueidentifier), 'Seu_Kuka_Beludo',  @ExpectedBanEnd_NEW,     'NEW', 'PS'   ),
        (CAST('67E551F8-A305-4BBD-9C1E-8F96EBDD24B1' AS uniqueidentifier), 'HalfSand_',        @ExpectedBanEnd_NEW,     'NEW', 'PS'   ),
        -- Xbox DB (1) -- Win10 account
        (CAST('646EFD1D-3A4B-4D62-B8CF-D3BC767AC646' AS uniqueidentifier), 'Pilou625057',      @ExpectedBanEnd_NEW,     'NEW', 'Xbox' )
    ) AS T(UserId, Username, ExpectedBanEnd, Verdict, ExpectedPlatform)
),
LbAgg AS (
    SELECT r.UserId,
           SUM(CASE WHEN r.PeriodTypeId = 1 AND r.IsBanned = 1 THEN 1 ELSE 0 END) AS LB_Wk_B,
           SUM(CASE WHEN r.PeriodTypeId = 1 AND r.IsBanned = 0 THEN 1 ELSE 0 END) AS LB_Wk_N,
           SUM(CASE WHEN r.PeriodTypeId = 2 AND r.IsBanned = 1 THEN 1 ELSE 0 END) AS LB_Mo_B,
           SUM(CASE WHEN r.PeriodTypeId = 2 AND r.IsBanned = 0 THEN 1 ELSE 0 END) AS LB_Mo_N,
           SUM(CASE WHEN r.PeriodTypeId = 3 AND r.IsBanned = 1 THEN 1 ELSE 0 END) AS LB_Yr_B,
           SUM(CASE WHEN r.PeriodTypeId = 3 AND r.IsBanned = 0 THEN 1 ELSE 0 END) AS LB_Yr_N
    FROM CompetitiveRatingsCurrent r WITH (NOLOCK)
    GROUP BY r.UserId
)
SELECT
    b.Verdict,
    b.ExpectedPlatform,
    b.Username                       AS Expected,
    u.Username                       AS FoundUser,
    b.UserId,
    p.IsCompetitionsBanned           AS Prof_Banned,
    p.CompetitionsBanEndDate         AS Prof_BanEnd,
    b.ExpectedBanEnd                 AS Prof_BanEnd_Expected,
    CASE
        WHEN NOT EXISTS (SELECT 1 FROM Users u2 WITH (NOLOCK) WHERE u2.UserId = b.UserId) THEN 'not on this DB'
        WHEN ISNULL(p.IsCompetitionsBanned, 0) = 0                        THEN 'FAIL: not banned'
        WHEN p.CompetitionsBanEndDate <> b.ExpectedBanEnd                 THEN 'FAIL: wrong BanEnd'
        ELSE 'OK'
    END                              AS Prof_Status,
    p.IsInfluencer                   AS Prof_Influencer,
    p.CompetitionRating              AS CurrentPCR,
    ISNULL(lb.LB_Wk_B, 0)            AS Wk_B,
    ISNULL(lb.LB_Wk_N, 0)            AS Wk_N,
    ISNULL(lb.LB_Mo_B, 0)            AS Mo_B,
    ISNULL(lb.LB_Mo_N, 0)            AS Mo_N,
    ISNULL(lb.LB_Yr_B, 0)            AS Yr_B,
    ISNULL(lb.LB_Yr_N, 0)            AS Yr_N,
    CASE
        WHEN NOT EXISTS (SELECT 1 FROM Users u2 WITH (NOLOCK) WHERE u2.UserId = b.UserId) THEN 'not on this DB'
        WHEN lb.UserId IS NULL                                            THEN 'FAIL: no LB rows'
        WHEN ISNULL(lb.LB_Wk_N,0)+ISNULL(lb.LB_Mo_N,0)+ISNULL(lb.LB_Yr_N,0)>0 THEN 'FAIL: some LB NotBanned'
        WHEN ISNULL(lb.LB_Wk_B,0)+ISNULL(lb.LB_Mo_B,0)+ISNULL(lb.LB_Yr_B,0)=0 THEN 'FAIL: no LB Banned rows'
        ELSE 'OK'
    END                              AS LB_Status
FROM BannedThisCycle b
LEFT JOIN Profiles p WITH (NOLOCK) ON p.UserId = b.UserId
LEFT JOIN Users    u WITH (NOLOCK) ON u.UserId = b.UserId
LEFT JOIN LbAgg    lb              ON lb.UserId = b.UserId
ORDER BY b.ExpectedPlatform, b.Username;

-- Reading the result:
--   * Steam PROD MAIN -- 4 OK rows (Dr.Seven, lailailaiyu, ShadowOfOxigen, Martino_CZ); 6 others 'not on this DB'
--   * PS PROD MAIN    -- 5 OK rows; 5 others 'not on this DB'
--   * Xbox PROD MAIN  -- 1 OK row (Pilou625057); 9 others 'not on this DB'
--   * Any 'FAIL: ...' on a row whose Expected platform matches the DB you're on -> investigate.
--   * RGC_ReeL_SKiiLLz specifically: 'OK' means his BanEnd is still Support's 2026-09-09.
--     'FAIL: wrong BanEnd' showing 2026-09-07 would mean the WHERE clause did not skip him and we
--     shortened an active ban -- restore 2026-09-09 by hand and check the AdminComment trail.


-- ============================================================================
-- Block 2: leaderboard check split by PeriodId (added week-14)
-- ============================================================================
-- The query above aggregates every period into one banned-vs-not-banned pair, which passes as
-- long as SOME row is banned. The Sunday sweep coincides with the weekly rollover, so a player
-- can hold rows for both the closing week and the new one; an aggregate check therefore returns
-- OK while the closing week -- the period the imminent reward run pays out on -- stays open.
-- Assert the closing period explicitly.
--
-- The weekly PeriodId is the window's Monday as yyyymmdd. Sweep 2026-08-09 -> closing 20260803,
-- new 20260810. Update both for the cycle being verified.
--
-- Aggregated database-side on purpose: ten players across three period types is well past the
-- ten-row result cap, and a verdict read off the visible rows is a verdict read off a subset.

DECLARE @ClosingPeriodId int = 20260803;
DECLARE @NewPeriodId     int = 20260810;

SELECT
    COUNT(DISTINCT r.UserId) AS PlayersWithRows,
    COUNT(*)                 AS TotalRows,
    SUM(CASE WHEN r.IsBanned = 0 THEN 1 ELSE 0 END)                                                  AS AnyRow_NotBanned,
    SUM(CASE WHEN r.PeriodTypeId = 1 AND r.PeriodId = @ClosingPeriodId THEN 1 ELSE 0 END)            AS ClosingWeek_Rows,
    SUM(CASE WHEN r.PeriodTypeId = 1 AND r.PeriodId = @ClosingPeriodId AND r.IsBanned = 0
             THEN 1 ELSE 0 END)                                                                      AS ClosingWeek_NotBanned,
    SUM(CASE WHEN r.PeriodTypeId = 1 AND r.PeriodId = @NewPeriodId THEN 1 ELSE 0 END)                AS NewWeek_Rows,
    SUM(CASE WHEN r.PeriodTypeId = 1 AND r.PeriodId = @NewPeriodId AND r.IsBanned = 0
             THEN 1 ELSE 0 END)                                                                      AS NewWeek_NotBanned
FROM CompetitiveRatingsCurrent r WITH (NOLOCK)
WHERE r.UserId IN (
    '82C921B5-1383-437D-9AFA-9D711A344481', '9584B60D-67D5-4362-8021-F1065562A5BC',
    'B4B0C273-5B5C-4A0C-BDDF-E204EE7F6B1A', '4422CD0F-153B-477B-A4F5-60353C37B5EA',
    'C51F5F26-2816-4FF9-88F3-530AF5E7E875', '92264697-3829-4C7A-93F3-861F4533C3BA',
    'BFAF6154-7A56-4025-A4A8-4FFE8D6B74B1', 'AB70490A-BFFB-4E18-9297-B3479BAC4369',
    '67E551F8-A305-4BBD-9C1E-8F96EBDD24B1', '646EFD1D-3A4B-4D62-B8CF-D3BC767AC646');

-- Pass condition: AnyRow_NotBanned = 0, ClosingWeek_Rows = the number of this cycle's bans present
-- on this DB, and ClosingWeek_NotBanned = 0. A non-zero ClosingWeek_NotBanned means the reward run
-- will pay a banned account -- fix before it fires, not after.


-- ============================================================================
-- Block 3: standing pre-payout sweep -- not cycle-specific
-- ============================================================================
-- A leaderboard row is created when a player takes part in a competition, and a row created after
-- the ban sync has run is born unbanned. So a banned player who competes later in the week reopens
-- a row that nothing closes until the sync runs again. Week-14 saw exactly this: one Steam and two
-- PS accounts entered competitions finishing just after 00:00 UTC and reappeared as open rows.
--
-- Whether the row-creation path reads Profiles.IsCompetitionsBanned is unresolved. Until it is,
-- run this before every reward payout, not only at ban time. It takes no parameters and covers
-- every effectively-banned player on the database, not just the current cohort.

SELECT
    COUNT(DISTINCT r.UserId) AS BannedPlayersWithOpenRow,
    COUNT(*)                 AS OpenRows,
    SUM(CASE WHEN r.PeriodTypeId = 1 THEN 1 ELSE 0 END) AS Weekly,
    SUM(CASE WHEN r.PeriodTypeId = 2 THEN 1 ELSE 0 END) AS Monthly,
    SUM(CASE WHEN r.PeriodTypeId = 3 THEN 1 ELSE 0 END) AS Yearly,
    MAX(r.PeriodId)          AS MaxPeriodId
FROM Profiles p WITH (NOLOCK)
INNER JOIN CompetitiveRatingsCurrent r WITH (NOLOCK) ON r.UserId = p.UserId
WHERE ISNULL(p.IsCompetitionsBanned, 0) = 1
  AND p.CompetitionsBanEndDate IS NOT NULL
  AND p.CompetitionsBanEndDate > GETUTCDATE()   -- mirrors ProfileLogic.IsCompetitionsBannedNow()
  AND r.IsBanned = 0;

-- Pass condition: BannedPlayersWithOpenRow = 0. Anything above zero means re-run
-- leaderboard-ban-sync.sql and re-check before the payout.
