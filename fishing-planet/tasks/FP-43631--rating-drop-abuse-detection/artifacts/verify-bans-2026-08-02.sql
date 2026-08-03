-- FP-43631 verify-bans-2026-08-02 -- 3-layer post-ban check (Profiles + LB)
-- ============================================================================
-- Standing rule from week-3/4 incidents: after every ban cycle, verify all three layers
-- (Profiles / CompetitiveRatingsCurrent / Mongo banLog) per platform individually.
-- This script covers the SQL layers; Mongo banLog verify is a one-liner at the bottom of
-- ban-log-backfill-2026-08-02.js.
--
-- Run on each platform PROD MAIN. Non-belonging UserIds LEFT JOIN to NULL (expected).

DECLARE @ExpectedBanEnd_NEW    date = '2026-08-31';   -- 4 weeks
DECLARE @ExpectedBanEnd_REPEAT date = '2026-09-28';   -- 8 weeks

WITH BannedThisCycle AS (
    SELECT * FROM (VALUES
        -- NEW (5)
        (CAST('5ED0507E-3D58-4FA7-B5C5-A3DF361B791F' AS uniqueidentifier), 'FarantirPL',       @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('DA1E5723-6F95-4600-98CD-F3E680E5163E' AS uniqueidentifier), 'wallims',          @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('30F95ADA-24FA-4FA1-8671-48F73D804156' AS uniqueidentifier), 'BOOMDATRUTH2',     @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('17C96F92-269F-4811-AF1E-813AFC75E144' AS uniqueidentifier), 'Old-Black-Fisher', @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('6DE2B7AD-6EA2-4F67-AB64-2C4CD4CBCDCA' AS uniqueidentifier), 'Mjolnir8761',      @ExpectedBanEnd_NEW,    'NEW',    'Xbox' ),
        -- REPEAT (2)
        (CAST('132E8BE9-7515-4898-B4D6-ACF7FADE37C7' AS uniqueidentifier), 'Aorney',           @ExpectedBanEnd_REPEAT, 'REPEAT', 'Steam'),
        (CAST('882BB61A-9F03-4706-B58E-AA9A279E303B' AS uniqueidentifier), 'kokoljj',          @ExpectedBanEnd_REPEAT, 'REPEAT', 'PS'   )
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
ORDER BY b.Verdict, b.ExpectedPlatform, b.Username;

-- Reading the result:
--   * Steam PROD MAIN -- 3 OK rows (FarantirPL, wallims, Aorney); 4 others 'not on this DB'
--   * PS PROD MAIN    -- 3 OK rows (BOOMDATRUTH2, Old-Black-Fisher, kokoljj); 4 others 'not on this DB'
--   * Xbox PROD MAIN  -- 1 OK row (Mjolnir8761); 6 others 'not on this DB'
--   * Any 'FAIL: ...' on a row whose Expected platform matches the DB you're on -> investigate.
