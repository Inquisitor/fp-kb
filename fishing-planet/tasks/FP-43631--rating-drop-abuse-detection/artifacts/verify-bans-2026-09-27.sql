-- FP-43631 week-21 -- post-ban verification, 3 blocks, run per platform PROD MAIN
-- ============================================================================
-- Run after layer 1 (bans-2026-09-27.sql) and layer 2 (leaderboard-ban-sync.sql) are COMMITted.
--
-- BLOCK A. The profile ban landed: IsCompetitionsBanned = 1 with the right end date per verdict
-- (NEW 2026-10-26, REPEAT 2026-11-23), for exactly the 6 convicted and nobody else.
--
-- BLOCK B. The leaderboard flag landed **on the closing period**. This is the block that matters
-- tonight. The sweep runs on Sunday and CompetitiveRatingsCurrent rolls to the next weekly period
-- at 00:00Z, so a sync that reaches only the new period leaves the closing week unflagged and the
-- player is paid from it. Assert the 20260921 row exists and carries IsBanned = 1. Note the row is
-- deleted by CompetitiveLeaderboardCleanupJob at :20 past the hour -- after that this block returns
-- nothing and CompetitiveRatingWeeklyHistory is the only witness, so run it before 00:20Z or fall
-- back to block C.
--
-- BLOCK C. Blocks A and B look only at accounts that were banned, so neither can see a candidate the
-- review did NOT convict standing in the money. Block C takes the WHOLE deadline subset and reports
-- where each one landed in the finalized history. Two different outcomes, and they must not be
-- conflated:
--   FAIL  - convicted but paid anyway (the ban failed to apply in time)
--   info  - not convicted and paid (the process worked as designed)

-- ============================================================================
-- BLOCK A -- profile ban state, expected end date per verdict
-- ============================================================================
WITH Expected AS (
    SELECT CAST(v AS uniqueidentifier) AS UserId, n AS Username, CAST(d AS datetime) AS BanEnd FROM (VALUES
        ('23A99BA9-E0F0-46E0-B5FC-846E5DAD0814', 'Noob-KAKA1988',  '2026-10-26'),  -- Steam NEW
        ('67E551F8-A305-4BBD-9C1E-8F96EBDD24B1', 'HalfSand_',      '2026-11-23'),  -- PS    REPEAT
        ('E39C9DAB-1697-434F-ADE9-D0122265ED13', 'TMRyuko',        '2026-10-26'),  -- Xbox  NEW
        ('0521E9F5-DCF5-438C-908D-689F0DFD2242', 'Fuzzytacos6571', '2026-11-23'),  -- Xbox  REPEAT
        ('95D6F8AE-0562-455E-99E0-6679CC506389', 'LaterGENJI',     '2026-10-26'),  -- Xbox  NEW
        ('7ACE60E8-8B33-401A-AE9F-B315DD848049', 'ELTITOGRAVY6',   '2026-10-26')   -- Xbox  NEW
    ) t(v, n, d)
)
SELECT e.Username AS Expected, u.Username AS FoundUser, p.IsCompetitionsBanned, p.CompetitionsBanEndDate, e.BanEnd AS ExpectedBanEnd,
       CASE WHEN p.UserId IS NULL THEN 'not on this DB'
            WHEN ISNULL(p.IsCompetitionsBanned,0) = 1 AND p.CompetitionsBanEndDate = e.BanEnd THEN 'ok'
            ELSE 'FAIL' END AS Layer1
FROM Expected e
LEFT JOIN Profiles p WITH (NOLOCK) ON p.UserId = e.UserId
LEFT JOIN Users    u WITH (NOLOCK) ON u.UserId = e.UserId
ORDER BY Layer1, e.Username;
-- expect: every row present on this platform reads 'ok'; the others 'not on this DB'

-- ============================================================================
-- BLOCK B -- leaderboard flag on the CLOSING period, split by period so a roll is visible
-- ============================================================================
SELECT u.Username, c.PeriodTypeId, c.PeriodId, c.CompetitionsWon, c.IsBanned,
       CASE WHEN c.PeriodTypeId = 1 AND c.PeriodId = 20260921 AND c.IsBanned = 1 THEN 'ok'
            WHEN c.PeriodTypeId = 1 AND c.PeriodId = 20260921 THEN 'FAIL - closing week not flagged'
            ELSE 'info - other period' END AS Layer2
FROM CompetitiveRatingsCurrent c WITH (NOLOCK)
LEFT JOIN Users u WITH (NOLOCK) ON u.UserId = c.UserId
WHERE c.UserId IN (
    '23A99BA9-E0F0-46E0-B5FC-846E5DAD0814','67E551F8-A305-4BBD-9C1E-8F96EBDD24B1',
    'E39C9DAB-1697-434F-ADE9-D0122265ED13','0521E9F5-DCF5-438C-908D-689F0DFD2242',
    '95D6F8AE-0562-455E-99E0-6679CC506389','7ACE60E8-8B33-401A-AE9F-B315DD848049')
ORDER BY u.Username, c.PeriodTypeId, c.PeriodId;
-- expect: the PeriodTypeId=1 / PeriodId=20260921 row of each banned account reads 'ok'.
-- Monthly (20260901) and Yearly (20260101) rows appear as 'info' and should also carry IsBanned = 1 after the shared sync.

-- ============================================================================
-- BLOCK C -- the WHOLE deadline subset against the finalized weekly history (run after 00:07Z)
-- ============================================================================
WITH Cohort AS (
    SELECT CAST(v AS uniqueidentifier) AS UserId, n AS Verdict FROM (VALUES
        ('23A99BA9-E0F0-46E0-B5FC-846E5DAD0814','BAN'),           -- Noob-KAKA1988
        ('67E551F8-A305-4BBD-9C1E-8F96EBDD24B1','BAN'),           -- HalfSand_
        ('E39C9DAB-1697-434F-ADE9-D0122265ED13','BAN'),           -- TMRyuko
        ('0521E9F5-DCF5-438C-908D-689F0DFD2242','BAN'),           -- Fuzzytacos6571
        ('95D6F8AE-0562-455E-99E0-6679CC506389','BAN operator'),  -- LaterGENJI
        ('7ACE60E8-8B33-401A-AE9F-B315DD848049','BAN'),           -- ELTITOGRAVY6
        ('BDD6D57E-E41F-475E-B067-C0D990A5A92C','no action')      -- xFenrir77
    ) t(v, n)
)
SELECT u.Username, c.Verdict, h.Place, h.Value AS Wins, h.RewardId,
       CASE WHEN u.UserId IS NULL                            THEN 'not on this DB'
            WHEN h.Place IS NULL                            THEN 'ok - not in history'
            WHEN h.Place > 10                               THEN 'ok - outside the paying places'
            WHEN c.Verdict LIKE 'BAN%'                      THEN 'FAIL - convicted but paid'
            ELSE 'info - not convicted and paid, by design' END AS BlockC
FROM Cohort c
LEFT JOIN Users u WITH (NOLOCK) ON u.UserId = c.UserId
LEFT JOIN CompetitiveRatingWeeklyHistory h WITH (NOLOCK)
       ON h.UserId = c.UserId AND h.PeriodId = 20260921
      AND h.TournamentKindId = 3 AND h.DimensionTypeId = 2
ORDER BY h.Place;
-- expect: no row reads 'FAIL'. xFenrir77 at place 3 on Xbox is the one legitimate 'info' this cycle.
