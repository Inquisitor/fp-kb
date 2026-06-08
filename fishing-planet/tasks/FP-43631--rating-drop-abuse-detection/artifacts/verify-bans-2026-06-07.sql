-- FP-43631 verify-bans-2026-06-07 — 3-layer post-ban check (Profiles + LB)
-- ============================================================================
-- Standing rule from week-3/4 incidents: after every ban cycle, verify all three layers
-- (Profiles / CompetitiveRatingsCurrent / Mongo banLog) per platform individually.
-- This script covers the SQL layers (Profiles + LB); Mongo banLog verify is a one-liner
-- at the bottom of ban-log-backfill-2026-06-07.js.
--
-- Run on each platform PROD MAIN (Steam, Xbox). Non-belonging UserIds simply LEFT JOIN to NULL
-- (those rows are expected on the other platform). PS PROD MAIN is NOT relevant this cycle
-- (Lay_D14S downgraded to WATCH; no PS ban).

DECLARE @ExpectedBanEnd_NEW    date = '2026-06-22';
DECLARE @ExpectedBanEnd_REPEAT date = '2026-07-06';

WITH BannedThisCycle AS (
    SELECT * FROM (VALUES
        (CAST('8FD87705-6500-4717-B459-387B07D7B471' AS uniqueidentifier), 'JuliaRybalka',   @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('4545581F-C2DB-4FA4-986E-9AEE3F9CCB48' AS uniqueidentifier), 'Kaneki_Ken2907', @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('0386A8AA-954F-44CF-B371-6C5BAB96943F' AS uniqueidentifier), 'emer_85_he',     @ExpectedBanEnd_NEW,    'NEW',    'Steam'),
        (CAST('E81A2739-534A-4299-80E7-7BF54B573BE8' AS uniqueidentifier), 'nggaaah',        @ExpectedBanEnd_NEW,    'NEW',    'Xbox' ),
        (CAST('AE6A4BC7-2DBF-4662-B5C3-7A8296A0F387' AS uniqueidentifier), 'Bejk76 cz',      @ExpectedBanEnd_NEW,    'NEW',    'Xbox' ),
        (CAST('82DA4897-61AB-4B56-BD82-4C654B54B7DA' AS uniqueidentifier), 'Bizkit3209',     @ExpectedBanEnd_NEW,    'NEW',    'Xbox' ),
        (CAST('5C99BE5A-A7FB-49B1-AAFB-188E26693CA7' AS uniqueidentifier), 'I_MACTEP_I',     @ExpectedBanEnd_REPEAT, 'REPEAT', 'Steam'),
        (CAST('4D3EFD74-6B2B-4E65-B434-A63D08BC6F68' AS uniqueidentifier), 'TTC-SWAX',       @ExpectedBanEnd_REPEAT, 'REPEAT', 'Steam')
    ) AS T(UserId, Username, ExpectedBanEnd, Verdict, ExpectedPlatform)
),
LbAgg AS (
    SELECT r.UserId,
           SUM(CASE WHEN r.PeriodTypeId = 1 AND r.IsBanned = 1 THEN 1 ELSE 0 END) AS LB_Weekly_Banned,
           SUM(CASE WHEN r.PeriodTypeId = 1 AND r.IsBanned = 0 THEN 1 ELSE 0 END) AS LB_Weekly_NotBanned,
           SUM(CASE WHEN r.PeriodTypeId = 2 AND r.IsBanned = 1 THEN 1 ELSE 0 END) AS LB_Monthly_Banned,
           SUM(CASE WHEN r.PeriodTypeId = 2 AND r.IsBanned = 0 THEN 1 ELSE 0 END) AS LB_Monthly_NotBanned,
           SUM(CASE WHEN r.PeriodTypeId = 3 AND r.IsBanned = 1 THEN 1 ELSE 0 END) AS LB_Yearly_Banned,
           SUM(CASE WHEN r.PeriodTypeId = 3 AND r.IsBanned = 0 THEN 1 ELSE 0 END) AS LB_Yearly_NotBanned
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
    ISNULL(lb.LB_Weekly_Banned,   0) AS LB_Wk_Banned,
    ISNULL(lb.LB_Weekly_NotBanned,0) AS LB_Wk_NotBanned,
    ISNULL(lb.LB_Monthly_Banned,  0) AS LB_Mo_Banned,
    ISNULL(lb.LB_Monthly_NotBanned,0) AS LB_Mo_NotBanned,
    ISNULL(lb.LB_Yearly_Banned,   0) AS LB_Yr_Banned,
    ISNULL(lb.LB_Yearly_NotBanned,0) AS LB_Yr_NotBanned,
    CASE
        WHEN p.UserId IS NULL                                             THEN 'not on this DB'
        WHEN lb.UserId IS NULL                                            THEN 'FAIL: no LB rows'
        WHEN ISNULL(lb.LB_Weekly_NotBanned,0)
           + ISNULL(lb.LB_Monthly_NotBanned,0)
           + ISNULL(lb.LB_Yearly_NotBanned,0) > 0                         THEN 'FAIL: some LB rows still NotBanned'
        WHEN ISNULL(lb.LB_Weekly_Banned,0)
           + ISNULL(lb.LB_Monthly_Banned,0)
           + ISNULL(lb.LB_Yearly_Banned,0) = 0                            THEN 'FAIL: no LB Banned rows'
        ELSE 'OK'
    END                              AS LB_Status
FROM BannedThisCycle b
LEFT JOIN Profiles p WITH (NOLOCK) ON p.UserId = b.UserId
LEFT JOIN Users    u WITH (NOLOCK) ON u.UserId = b.UserId
LEFT JOIN LbAgg    lb              ON lb.UserId = b.UserId
ORDER BY b.Verdict, b.ExpectedPlatform, b.Username;

-- Reading the result:
--   * Steam PROD MAIN should show OK rows for the 5 Steam users; 3 Xbox users come back as
--     'not on this DB' for both Prof_Status and LB_Status — that's expected, those rows just
--     don't join Profiles/LB on this DB.
--   * Xbox PROD MAIN — mirror: 3 OK Xbox rows, 5 'not on this DB' for Steam.
--   * Any 'FAIL: ...' on a row whose Expected platform matches the DB you're on → investigate.
--   * The week-4 incident was Prof_Banned NULL with LB already flipped — that's the canonical
--     'forgot to COMMIT the bans-2026-06-07.sql BEGIN TRAN' signature.
