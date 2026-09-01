-- FP-43631 verify-bans-2026-08-30 -- 3-layer post-ban check (Profiles + leaderboard)
-- ============================================================================
-- Standing rule from the week-3/4 incidents: after every ban cycle verify all three layers
-- (Profiles / CompetitiveRatingsCurrent / Mongo banLog) per platform individually. This script
-- covers the SQL layers; the banLog check is the one-liner at the foot of
-- ban-log-backfill-2026-08-30.js.
--
-- Run on each platform PROD MAIN. Non-belonging UserIds LEFT JOIN to NULL (expected).
--
-- FOUR ROWS ARE EXPECTED TO CARRY SOMEONE ELSE'S DATE. Saintmnk (2026-09-28), loseloop
-- (2026-09-29), DJTigar (2026-09-30) and Akkord_8 (2026-09-30) already carried Support bans at
-- least as long as ours, so the ban script skips them by design. Their expected BanEnd below is
-- Support's date. A row showing OUR 2026-09-28 for loseloop, DJTigar or Akkord_8 would mean we
-- SHORTENED an active ban -- that is the failure to look for, not the reverse.

DECLARE @NEW    date = '2026-09-28';   -- 4 weeks, ours
DECLARE @REPEAT date = '2026-10-26';   -- 8 weeks, ours

WITH BannedThisCycle AS (
    SELECT * FROM (VALUES
        -- Steam
        (CAST('890EEF14-DACA-451E-AE0D-EE7454D996FD' AS uniqueidentifier), 'ASOAWELS',         @NEW,                        'NEW',    'Steam'),
        (CAST('11AAA18E-D387-4431-B195-60130CEEB90B' AS uniqueidentifier), 'MrAl3xXx',         @NEW,                        'NEW',    'Steam'),
        (CAST('4B47AE81-1B95-4BB2-9B21-77186189665A' AS uniqueidentifier), 'RubyMarlinSultan', @NEW,                        'NEW',    'Steam'),
        (CAST('250A6AB6-AF79-454F-881B-7AF2655A970E' AS uniqueidentifier), 'loseloop',         CAST('2026-09-29' AS date),  'NEW',    'Steam'),
        (CAST('A6255AD3-8198-49A9-A27F-B3643B0D994A' AS uniqueidentifier), 'Saintmnk',         CAST('2026-09-28' AS date),  'NEW',    'Steam'),
        (CAST('F19AB1BB-4482-459D-9D4B-B8BB753FFFFE' AS uniqueidentifier), 'SoRA6r',           @NEW,                        'NEW',    'Steam'),
        (CAST('9757FD6A-8435-409A-9F83-33214AF80424' AS uniqueidentifier), 'TrcikLowFiv',      @REPEAT,                     'REPEAT', 'Steam'),
        -- PS
        (CAST('AFBB0707-23C7-4601-ABFD-E8093490813B' AS uniqueidentifier), 'DJTigar',          CAST('2026-09-30' AS date),  'NEW',    'PS'   ),
        (CAST('275768BF-834B-44E4-9297-11B946C070E0' AS uniqueidentifier), 'Akkord_8',         CAST('2026-09-30' AS date),  'NEW',    'PS'   ),
        (CAST('9C7CEA54-909B-41F9-994B-05DCCB86C144' AS uniqueidentifier), 'blue102180',       @NEW,                        'NEW',    'PS'   ),
        (CAST('2A9E0031-CD4A-41B7-A791-20E395C43ABB' AS uniqueidentifier), 'bigbruney24',      @NEW,                        'NEW',    'PS'   ),
        (CAST('783F7778-52A1-4D72-B569-26665CD72714' AS uniqueidentifier), 'lolofifa29',       @NEW,                        'NEW',    'PS'   ),
        (CAST('1D95D7D9-D983-4F8A-B8F2-2E2BB3AAA247' AS uniqueidentifier), 'martelli04',       @NEW,                        'NEW',    'PS'   ),
        (CAST('EBC824AC-464E-4186-B896-A937A0599D6C' AS uniqueidentifier), 'HIflyfishingGH',   @NEW,                        'NEW',    'PS'   ),
        -- Xbox
        (CAST('13090FFE-7894-4C66-9AF2-0CD81C1A03EB' AS uniqueidentifier), 'ChaChaWuu9588',    @NEW,                        'NEW',    'Xbox' ),
        (CAST('2F692613-2090-4D4C-8E52-736A6BEF5C2C' AS uniqueidentifier), 'ScionHades8639',   @NEW,                        'NEW',    'Xbox' )
    ) AS T(UserId, Username, ExpectedBanEnd, Verdict, ExpectedPlatform)
),
LbAgg AS (
    SELECT r.UserId,
           SUM(CASE WHEN r.IsBanned = 1 THEN 1 ELSE 0 END) AS LB_Banned,
           SUM(CASE WHEN r.IsBanned = 0 THEN 1 ELSE 0 END) AS LB_NotBanned
    FROM CompetitiveRatingsCurrent r WITH (NOLOCK)
    GROUP BY r.UserId
)
SELECT
    b.Verdict, b.ExpectedPlatform,
    b.Username                       AS Expected,
    u.Username                       AS FoundUser,
    p.IsCompetitionsBanned           AS Prof_Banned,
    p.CompetitionsBanEndDate         AS Prof_BanEnd,
    b.ExpectedBanEnd                 AS Prof_BanEnd_Expected,
    CASE
        WHEN NOT EXISTS (SELECT 1 FROM Users u2 WITH (NOLOCK) WHERE u2.UserId = b.UserId) THEN 'not on this DB'
        WHEN ISNULL(p.IsCompetitionsBanned, 0) = 0            THEN 'FAIL: not banned'
        WHEN p.CompetitionsBanEndDate <> b.ExpectedBanEnd     THEN 'FAIL: wrong BanEnd'
        ELSE 'OK'
    END                              AS Prof_Status,
    p.CompetitionRating              AS CurrentPCR,
    ISNULL(lb.LB_Banned, 0)          AS LB_B,
    ISNULL(lb.LB_NotBanned, 0)       AS LB_N,
    CASE
        WHEN NOT EXISTS (SELECT 1 FROM Users u2 WITH (NOLOCK) WHERE u2.UserId = b.UserId) THEN 'not on this DB'
        WHEN lb.UserId IS NULL                   THEN 'FAIL: no LB rows'
        WHEN ISNULL(lb.LB_NotBanned, 0) > 0      THEN 'FAIL: some LB NotBanned'
        WHEN ISNULL(lb.LB_Banned, 0) = 0         THEN 'FAIL: no LB Banned rows'
        ELSE 'OK'
    END                              AS LB_Status
FROM BannedThisCycle b
LEFT JOIN Profiles p WITH (NOLOCK) ON p.UserId = b.UserId
LEFT JOIN Users    u WITH (NOLOCK) ON u.UserId = b.UserId
LEFT JOIN LbAgg    lb              ON lb.UserId = b.UserId
ORDER BY b.ExpectedPlatform, b.Username;

-- Reading the result:
--   * Steam PROD MAIN -- 7 OK rows; 9 others 'not on this DB'
--   * PS PROD MAIN    -- 7 OK rows; 9 others 'not on this DB'
--   * Xbox PROD MAIN  -- 2 OK rows; 14 others 'not on this DB'
--   * Any 'FAIL: ...' on a row whose expected platform matches the DB you are on -> investigate.


-- ============================================================================
-- Block 2: leaderboard check split by PeriodId
-- ============================================================================
-- The aggregate above passes as long as SOME row is banned. The Sunday sweep coincides with the
-- weekly rollover, so a player can hold rows for both the closing week and the new one, and an
-- aggregate check returns OK while the closing week -- the period the imminent reward run pays out
-- on -- stays open. Assert the closing period explicitly.
--
-- The weekly PeriodId is the window's Monday as yyyymmdd. Sweep 2026-08-30 -> closing 20260824,
-- new 20260831. THIS CYCLE THE ROLLOVER HAS ALREADY HAPPENED: the ban is being applied at
-- 2026-08-30T23:00Z, an hour before the new period opens, so both are expected to exist.
--
-- Aggregated database-side on purpose: sixteen players across three period types is well past the
-- ten-row result cap, and a verdict read off the visible rows is a verdict read off a subset.

DECLARE @ClosingPeriodId int = 20260824;
DECLARE @NewPeriodId     int = 20260831;

SELECT
    COUNT(DISTINCT r.UserId) AS PlayersWithRows,
    COUNT(*)                 AS TotalRows,
    SUM(CASE WHEN r.IsBanned = 0 THEN 1 ELSE 0 END)                                       AS AnyRow_NotBanned,
    SUM(CASE WHEN r.PeriodTypeId = 1 AND r.PeriodId = @ClosingPeriodId THEN 1 ELSE 0 END) AS ClosingWeek_Rows,
    SUM(CASE WHEN r.PeriodTypeId = 1 AND r.PeriodId = @ClosingPeriodId AND r.IsBanned = 0
             THEN 1 ELSE 0 END)                                                           AS ClosingWeek_NotBanned,
    SUM(CASE WHEN r.PeriodTypeId = 1 AND r.PeriodId = @NewPeriodId THEN 1 ELSE 0 END)     AS NewWeek_Rows,
    SUM(CASE WHEN r.PeriodTypeId = 1 AND r.PeriodId = @NewPeriodId AND r.IsBanned = 0
             THEN 1 ELSE 0 END)                                                           AS NewWeek_NotBanned
FROM CompetitiveRatingsCurrent r WITH (NOLOCK)
WHERE r.UserId IN (
    '890EEF14-DACA-451E-AE0D-EE7454D996FD', '11AAA18E-D387-4431-B195-60130CEEB90B',
    '4B47AE81-1B95-4BB2-9B21-77186189665A', '250A6AB6-AF79-454F-881B-7AF2655A970E',
    'A6255AD3-8198-49A9-A27F-B3643B0D994A', 'F19AB1BB-4482-459D-9D4B-B8BB753FFFFE',
    '9757FD6A-8435-409A-9F83-33214AF80424', 'AFBB0707-23C7-4601-ABFD-E8093490813B',
    '275768BF-834B-44E4-9297-11B946C070E0', '9C7CEA54-909B-41F9-994B-05DCCB86C144',
    '2A9E0031-CD4A-41B7-A791-20E395C43ABB', '783F7778-52A1-4D72-B569-26665CD72714',
    '1D95D7D9-D983-4F8A-B8F2-2E2BB3AAA247', 'EBC824AC-464E-4186-B896-A937A0599D6C',
    '13090FFE-7894-4C66-9AF2-0CD81C1A03EB', '2F692613-2090-4D4C-8E52-736A6BEF5C2C');

-- Pass condition: AnyRow_NotBanned = 0, ClosingWeek_Rows equals the number of this cycle's bans
-- present on this DB, and ClosingWeek_NotBanned = 0. A non-zero ClosingWeek_NotBanned means the
-- reward run will pay a banned account -- fix before it fires, not after.


-- ============================================================================
-- Block 3: standing pre-payout sweep -- not cycle-specific
-- ============================================================================
-- A leaderboard row is created when a player takes part in a competition, and a row created after
-- the ban sync has run is born unbanned. So a banned player who competes later in the week reopens
-- a row that nothing closes until the sync runs again. Week-14 saw exactly this on three accounts.
--
-- Whether the row-creation path reads Profiles.IsCompetitionsBanned is still unresolved. Until it
-- is, run this before every reward payout, not only at ban time. It takes no parameters and covers
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
