-- FP-43631 verify-bans-2026-06-14 — 3-layer post-ban check (Profiles + LB)
-- ============================================================================
-- Standing rule from week-3/4 incidents: after every ban cycle, verify all three layers
-- (Profiles / CompetitiveRatingsCurrent / Mongo banLog) per platform individually.
-- This script covers the SQL layers (Profiles + LB); Mongo banLog verify is a one-liner
-- at the bottom of ban-log-backfill-2026-06-14.js.
--
-- Run on each platform PROD MAIN (Steam, PS). Non-belonging UserIds simply LEFT JOIN to NULL
-- (those rows are expected on the other platform). XB PROD MAIN is NOT relevant this cycle
-- (no Xbox ban this week — MikeikeMOON downgraded to WATCH by adversarial review).

DECLARE @ExpectedBanEnd_NEW    date = '2026-06-29';
DECLARE @ExpectedBanEnd_REPEAT date = '2026-07-13';

WITH BannedThisCycle AS (
    SELECT * FROM (VALUES
        (CAST('47FEE9FA-C9E6-4DBE-8742-63B56558D890' AS uniqueidentifier), 'LaccFarro',     @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('78C4A65F-EF45-482A-A125-88D71973013B' AS uniqueidentifier), 'Mr-crimson-21', @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('E25C082E-8A19-4236-AA8B-C345137E9EA3' AS uniqueidentifier), 'STARI40K_YT',   @ExpectedBanEnd_REPEAT, 'REPEAT', 'PS'   ),
        (CAST('8F36F30F-ADE0-4D9A-BC88-765AE61E5384' AS uniqueidentifier), 'IIGot-_-Smoked',@ExpectedBanEnd_REPEAT, 'REPEAT', 'PS'   )
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
    -- Profiles layer
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
    -- LB layer
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
--   * Steam PROD MAIN should show OK row for LaccFarro; 3 PS users come back as
--     'not on this DB' on both Prof_Status and LB_Status — that's expected.
--   * PS PROD MAIN — mirror: 3 OK PS rows, 1 'not on this DB' for LaccFarro.
--   * Any 'FAIL: ...' on a row whose Expected platform matches the DB you're on -> investigate.
