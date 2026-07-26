-- FP-43631 verify-bans-2026-07-26 -- 3-layer post-ban check (Profiles + LB)
-- ============================================================================
-- Standing rule from week-3/4 incidents: after every ban cycle, verify all three layers
-- (Profiles / CompetitiveRatingsCurrent / Mongo banLog) per platform individually.
-- This script covers the SQL layers (Profiles + LB); Mongo banLog verify is a one-liner
-- at the bottom of ban-log-backfill-2026-07-26.js.
--
-- Run on each platform PROD MAIN (Steam, PS, Xbox). Non-belonging UserIds simply LEFT JOIN
-- to NULL (those rows are expected on the other platform).

DECLARE @ExpectedBanEnd_NEW    date = '2026-08-10';
DECLARE @ExpectedBanEnd_REPEAT date = '2026-08-24';

WITH BannedThisCycle AS (
    SELECT * FROM (VALUES
        -- NEW (5)
        (CAST('99247BDE-F4CB-4698-8A5C-679550D9F369' AS uniqueidentifier), 'dreadloc',       @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('CB167D53-BD55-4228-8B44-F41A284E7C3E' AS uniqueidentifier), 'Albbert',        @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('B3440760-BBD6-4AF0-B0EE-DEF6B131DE62' AS uniqueidentifier), 'Zemaro',         @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('35ED0E4A-4ACB-4072-B23A-10D5B5578FEA' AS uniqueidentifier), 'vlad_spain',     @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('FF382A4E-F0C7-4DC4-A882-80F32276E095' AS uniqueidentifier), 'TurboBandz6351', @ExpectedBanEnd_NEW,    'NEW',    'Xbox' ),
        -- REPEAT (1)
        (CAST('EB4273EE-EB6A-488F-8AC7-6C40809E1229' AS uniqueidentifier), 'jackylu',        @ExpectedBanEnd_REPEAT, 'REPEAT', 'Steam')
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
--   * Steam PROD MAIN should show 4 OK rows (dreadloc, Albbert, Zemaro, jackylu); 1 PS + 1 Xbox 'not on this DB'
--   * PS PROD MAIN -- 1 OK row (vlad_spain); 4 Steam + 1 Xbox 'not on this DB'
--   * Xbox PROD MAIN -- 1 OK row (TurboBandz6351); 4 Steam + 1 PS 'not on this DB'
--   * Any 'FAIL: ...' on a row whose Expected platform matches the DB you're on -> investigate.
