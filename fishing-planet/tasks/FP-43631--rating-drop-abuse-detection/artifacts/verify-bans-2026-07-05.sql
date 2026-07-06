-- FP-43631 verify-bans-2026-07-05 -- 3-layer post-ban check (Profiles + LB)
-- ============================================================================
-- Standing rule from week-3/4 incidents: after every ban cycle, verify all three layers
-- (Profiles / CompetitiveRatingsCurrent / Mongo banLog) per platform individually.
-- This script covers the SQL layers (Profiles + LB); Mongo banLog verify is a one-liner
-- at the bottom of ban-log-backfill-2026-07-05.js.
--
-- Run on each platform PROD MAIN (Steam, PS). Xbox cohort empty this week.
-- Non-belonging UserIds simply LEFT JOIN to NULL (those rows are expected on the other platform).

DECLARE @ExpectedBanEnd_NEW date = '2026-07-20';

WITH BannedThisCycle AS (
    SELECT * FROM (VALUES
        -- NEW (6)
        (CAST('E0A2F28A-F5BE-4A5C-9898-43F2C093DBB1' AS uniqueidentifier), 'Ti_To',            @ExpectedBanEnd_NEW, 'NEW', 'Steam'),
        (CAST('E98D05D2-4E6F-45BC-8421-9ED08CDCE54E' AS uniqueidentifier), 'H.a.r.y44',        @ExpectedBanEnd_NEW, 'NEW', 'Steam'),
        (CAST('53E1B654-48BD-413C-AE77-6E58C39CFC14' AS uniqueidentifier), 'IaMiya',           @ExpectedBanEnd_NEW, 'NEW', 'Steam'),
        (CAST('5C5B4305-BC67-403E-A013-640E396F1A9F' AS uniqueidentifier), 'EL-_-Diablo-_-51', @ExpectedBanEnd_NEW, 'NEW', 'PS'   ),
        (CAST('EEA41D0D-3987-403F-A479-F2F8EFE326D7' AS uniqueidentifier), 'San-miculsan',     @ExpectedBanEnd_NEW, 'NEW', 'PS'   ),
        (CAST('E28DD543-32FF-449F-8A0F-02AF1C615D38' AS uniqueidentifier), 'kevynrdm13',       @ExpectedBanEnd_NEW, 'NEW', 'PS'   )
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
--   * Steam PROD MAIN should show 3 OK rows; 3 PS come back as 'not on this DB' -- expected
--   * PS PROD MAIN -- 3 OK rows, 3 Steam 'not on this DB'
--   * Any 'FAIL: ...' on a row whose Expected platform matches the DB you're on -> investigate.
