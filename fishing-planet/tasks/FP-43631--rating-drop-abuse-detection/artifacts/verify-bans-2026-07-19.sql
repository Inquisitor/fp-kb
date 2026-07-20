-- FP-43631 verify-bans-2026-07-19 -- 3-layer post-ban check (Profiles + LB)
-- ============================================================================
-- Standing rule from week-3/4 incidents: after every ban cycle, verify all three layers
-- (Profiles / CompetitiveRatingsCurrent / Mongo banLog) per platform individually.
-- This script covers the SQL layers (Profiles + LB); Mongo banLog verify is a one-liner
-- at the bottom of ban-log-backfill-2026-07-19.js.
--
-- Run on each platform PROD MAIN (Steam, PS, Xbox). Non-belonging UserIds simply LEFT JOIN
-- to NULL (those rows are expected on the other platform).

DECLARE @ExpectedBanEnd_NEW    date = '2026-08-03';
DECLARE @ExpectedBanEnd_REPEAT date = '2026-08-17';

WITH BannedThisCycle AS (
    SELECT * FROM (VALUES
        -- NEW (4)
        (CAST('313EEE9D-DA0C-42F0-9B1E-E4D0C2598766' AS uniqueidentifier), 'FoxMilard',       @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('469DF796-D270-40FF-BAD9-8A5B9D83B6DC' AS uniqueidentifier), 'CFC-T-W-T-32568', @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('CE09DA31-C3FC-4B21-915A-87EBA15367D9' AS uniqueidentifier), 'Chuydakid214',    @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('FB67D3BC-E77D-4579-856A-F2DF8DC3CAA5' AS uniqueidentifier), 'Belion019',       @ExpectedBanEnd_NEW,    'NEW',    'Xbox' ),
        -- REPEAT (1)
        (CAST('CC4044A9-0829-40E6-A6BA-D3222DBCE8D0' AS uniqueidentifier), 'strullendorfer',  @ExpectedBanEnd_REPEAT, 'REPEAT', 'PS'   )
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
--   * Steam PROD MAIN should show 1 OK row (FoxMilard); 3 PS + 1 Xbox come back as 'not on this DB' -- expected
--   * PS PROD MAIN -- 3 OK rows (CFC-T-W-T-32568, Chuydakid214, strullendorfer); 1 Steam + 1 Xbox 'not on this DB'
--   * Xbox PROD MAIN -- 1 OK row (Belion019); 1 Steam + 3 PS 'not on this DB'
--   * Any 'FAIL: ...' on a row whose Expected platform matches the DB you're on -> investigate.
