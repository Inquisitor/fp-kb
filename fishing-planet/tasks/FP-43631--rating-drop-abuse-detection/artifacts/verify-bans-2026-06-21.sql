-- FP-43631 verify-bans-2026-06-21 — 3-layer post-ban check (Profiles + LB)
-- ============================================================================
-- Standing rule from week-3/4 incidents: after every ban cycle, verify all three layers
-- (Profiles / CompetitiveRatingsCurrent / Mongo banLog) per platform individually.
-- This script covers the SQL layers (Profiles + LB); Mongo banLog verify is a one-liner
-- at the bottom of ban-log-backfill-2026-06-21.js.
--
-- Run on each platform PROD MAIN (Steam, PS, Xbox). Non-belonging UserIds simply LEFT JOIN to
-- NULL (those rows are expected on the other platform).

DECLARE @ExpectedBanEnd_NEW    date = '2026-07-06';
DECLARE @ExpectedBanEnd_REPEAT date = '2026-07-20';

WITH BannedThisCycle AS (
    SELECT * FROM (VALUES
        -- NEW (12)
        (CAST('1030BC70-976F-4AE8-8464-5E73A4F5382D' AS uniqueidentifier), 'TF_B4ngwal',          @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('6218FFDE-5EAC-4566-BBA5-711422D44F57' AS uniqueidentifier), 'Ramboo051',           @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('3043CB8F-281B-47DF-BEC7-5CA722FA0394' AS uniqueidentifier), 'Audrey_HH',           @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('45BB43B9-8690-43AE-AA4D-190515F4F2EC' AS uniqueidentifier), 'OZBULLDOG',           @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('D2E0BA0E-3AC5-42EC-A645-F8C66137F310' AS uniqueidentifier), 'VovaTemniy',          @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('C5D90E33-5022-4049-9960-C39A28B0D2A4' AS uniqueidentifier), 'jorja09',             @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('B879AB80-43E5-455F-A045-B5A28480AF04' AS uniqueidentifier), 'rabolio41100',        @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('E812002D-0618-48EB-ABAE-D88078A4C9F8' AS uniqueidentifier), 'maminapokorny83',     @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('4277FB92-D6E9-4CA5-9940-EA77CB5DFA6C' AS uniqueidentifier), 'Neterrall',           @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('F6816FD8-9A24-424A-AA90-04B1FD4565E8' AS uniqueidentifier), 'Fat_tuna_mama',       @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('CC4044A9-0829-40E6-A6BA-D3222DBCE8D0' AS uniqueidentifier), 'strullendorfer',      @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('1ABB20A3-8696-4737-A0C4-5620A8A374DF' AS uniqueidentifier), 'LEBOOGIEEEE',         @ExpectedBanEnd_NEW,    'NEW',    'Xbox' ),
        -- REPEAT (5)
        (CAST('09DAA0C8-856A-4328-8001-9CC1B2683FAB' AS uniqueidentifier), 'FurryCurrentMaster',  @ExpectedBanEnd_REPEAT, 'REPEAT', 'Steam'),
        (CAST('37FE52EC-F9D1-4439-9DDD-2C38982C66C3' AS uniqueidentifier), 'Dokidepp',            @ExpectedBanEnd_REPEAT, 'REPEAT', 'Steam'),
        (CAST('76B5F7F3-346A-46B1-9C70-4FE0743572C3' AS uniqueidentifier), 'Flo-GrayFOX',         @ExpectedBanEnd_REPEAT, 'REPEAT', 'PS'   ),
        (CAST('5DB0A328-1307-4762-A1DB-7FF34E63BFE5' AS uniqueidentifier), 'bostonbroncos24',     @ExpectedBanEnd_REPEAT, 'REPEAT', 'PS'   ),
        (CAST('013368D1-E8A8-437A-88B0-71059E3287EB' AS uniqueidentifier), 'BuzzingLemur417',     @ExpectedBanEnd_REPEAT, 'REPEAT', 'Xbox' )
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
        WHEN p.UserId IS NULL                                             THEN 'not on this DB'
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
        WHEN p.UserId IS NULL                                             THEN 'not on this DB'
        WHEN lb.UserId IS NULL                                            THEN 'FAIL: no LB rows'
        WHEN ISNULL(lb.LB_Wk_N,0)+ISNULL(lb.LB_Mo_N,0)+ISNULL(lb.LB_Yr_N,0)>0 THEN 'FAIL: some LB NotBanned'
        WHEN ISNULL(lb.LB_Wk_B,0)+ISNULL(lb.LB_Mo_B,0)+ISNULL(lb.LB_Yr_B,0)=0 THEN 'FAIL: no LB Banned rows'
        ELSE 'OK'
    END                              AS LB_Status
FROM BannedThisCycle b
LEFT JOIN Profiles p WITH (NOLOCK) ON p.UserId = b.UserId
LEFT JOIN Users    u WITH (NOLOCK) ON u.UserId = b.UserId
LEFT JOIN LbAgg    lb              ON lb.UserId = b.UserId
ORDER BY b.Verdict, b.ExpectedPlatform, b.Username;

-- Reading the result:
--   * Steam PROD MAIN should show 7 OK rows; 8 PS + 2 Xbox come back as 'not on this DB' -- expected
--   * PS PROD MAIN -- 8 OK rows, 5 Steam + 2 Xbox 'not on this DB'
--   * Xbox PROD MAIN -- 2 OK rows, 5 Steam + 8 PS 'not on this DB'
--   * Any 'FAIL: ...' on a row whose Expected platform matches the DB you're on -> investigate.
