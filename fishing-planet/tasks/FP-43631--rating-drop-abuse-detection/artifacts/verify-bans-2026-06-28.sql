-- FP-43631 verify-bans-2026-06-28 — 3-layer post-ban check (Profiles + LB)
-- ============================================================================
-- Standing rule from week-3/4 incidents: after every ban cycle, verify all three layers
-- (Profiles / CompetitiveRatingsCurrent / Mongo banLog) per platform individually.
-- This script covers the SQL layers (Profiles + LB); Mongo banLog verify is a one-liner
-- at the bottom of ban-log-backfill-2026-06-28.js.
--
-- Run on each platform PROD MAIN (Steam, PS, Xbox). Non-belonging UserIds simply LEFT JOIN to
-- NULL (those rows are expected on the other platform).

DECLARE @ExpectedBanEnd_NEW    date = '2026-07-13';
DECLARE @ExpectedBanEnd_REPEAT date = '2026-07-27';

WITH BannedThisCycle AS (
    SELECT * FROM (VALUES
        -- NEW (14)
        (CAST('C434AFC9-875D-4ECE-8EFA-FE7810C6DAFF' AS uniqueidentifier), 'ArmlessFisherMan',  @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('883362EF-98A6-4406-B2DC-9636E1D022FC' AS uniqueidentifier), 'BB_Anastasia',      @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('222BBE9D-3557-4280-B854-CBEF2AE48707' AS uniqueidentifier), 'MonsterFish_fuark', @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('4CF530BA-2330-4DC0-BB8B-C03A55176EFC' AS uniqueidentifier), 'angeperdu',         @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('683D0D32-290E-4726-BFE9-AD16A0234324' AS uniqueidentifier), 'krolikusik',        @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('C5A87A36-E9A3-44C6-B69A-CB08ADBEAEDA' AS uniqueidentifier), 'Matiamo_PL',        @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('46E9E18F-0E49-4F9E-B91C-B074823CF02B' AS uniqueidentifier), 'tigrou_le_boss42',  @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('56ED8774-68B1-49B2-B395-E594DBE4B766' AS uniqueidentifier), 'M4R5H_57_',         @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('CBF68606-DF2C-46B3-8086-E76B7019C1D1' AS uniqueidentifier), 'Epic70cosmin',      @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('D1320268-0463-4289-A455-24BAB60B2363' AS uniqueidentifier), 'MrChadRico',        @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('EE558D4F-7515-4B5F-B0FD-4C1F47319C3A' AS uniqueidentifier), 'MONSTER-VERT1325',  @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('330F8B15-1FC5-49DC-9829-8B710B04F80F' AS uniqueidentifier), 'TR-BILECIKLI_CMR',  @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('882BB61A-9F03-4706-B58E-AA9A279E303B' AS uniqueidentifier), 'kokoljj',           @ExpectedBanEnd_NEW,    'NEW',    'PS'   ),
        (CAST('F25A97B7-FDEF-4C1C-B50A-0D0A117745D4' AS uniqueidentifier), 'Smooter85',         @ExpectedBanEnd_NEW,    'NEW',    'Xbox' ),
        -- REPEAT (1)
        (CAST('06BB9D34-BC04-4591-80F6-0F8AD8F05087' AS uniqueidentifier), 'IKIGAI__1__',       @ExpectedBanEnd_REPEAT, 'REPEAT', 'PS'   )
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
--   * Steam PROD MAIN should show 5 OK rows; 9 PS + 1 Xbox come back as 'not on this DB' -- expected
--   * PS PROD MAIN -- 9 OK rows, 5 Steam + 1 Xbox 'not on this DB'
--   * Xbox PROD MAIN -- 1 OK row, 5 Steam + 9 PS 'not on this DB'
--   * Any 'FAIL: ...' on a row whose Expected platform matches the DB you're on -> investigate.
