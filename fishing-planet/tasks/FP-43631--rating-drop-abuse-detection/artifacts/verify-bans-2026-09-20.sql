-- FP-43631 week-20 -- post-ban verification, 3 blocks, run per platform PROD MAIN
-- ============================================================================
-- Run after layer 1 (bans-2026-09-20.sql) and layer 2 (leaderboard-ban-sync.sql) are COMMITted.
--
-- BLOCK A. The profile ban landed: IsCompetitionsBanned = 1 with the right end date, for exactly
-- the 5 convicted and nobody else.
--
-- BLOCK B. The leaderboard flag landed **on the closing period**. This is the block that matters
-- tonight. The sweep runs on Sunday and CompetitiveRatingsCurrent rolls to the next weekly period
-- at 00:00Z, so a sync that reaches only the new period leaves the closing week unflagged and the
-- player is paid from it. Assert the 20260914 row exists and carries IsBanned = 1. Note the row is
-- deleted by CompetitiveLeaderboardCleanupJob at :20 past the hour -- after that this block returns
-- nothing and CompetitiveRatingWeeklyHistory is the only witness, so run it before :20 or fall back
-- to block C.
--
-- BLOCK C. Blocks A and B look only at accounts that were banned, so neither can see a candidate the
-- review did NOT convict standing in the money. Block C takes the WHOLE reviewed cohort and reports
-- where each one landed in the finalized history. Two different outcomes, and they must not be
-- conflated:
--   FAIL  - convicted but paid anyway (the ban failed to apply in time)
--   info  - acquitted and paid (the process worked as designed; the verdict was WATCH)

-- ============================================================================
-- BLOCK A -- profile ban state
-- ============================================================================
SELECT u.Username, p.IsCompetitionsBanned, p.CompetitionsBanEndDate,
       CASE WHEN ISNULL(p.IsCompetitionsBanned,0) = 1
             AND p.CompetitionsBanEndDate = '2026-10-19 00:00:00' THEN 'ok'
            ELSE 'FAIL' END AS Layer1
FROM Profiles p WITH (NOLOCK)
LEFT JOIN Users u WITH (NOLOCK) ON u.UserId = p.UserId
WHERE p.UserId IN (
    -- Steam
    'DCB21F48-6B54-4F74-8A3F-9CAAE8BFF6A0',  -- LEK_TARNO
    'F3150296-CC7F-43B0-90A5-CC941B45E960',  -- HavocHHH
    -- PS
    '80B05C6C-7719-40B5-89CA-3A358F0BD166',  -- Gentleman83190
    'A92ED0C7-BB5E-43AC-971C-7AF91FD47D31',  -- CrazyGepard
    -- Xbox
    '16DDA5F1-E9C3-46F5-A43F-BFB806DE1F8F'   -- Rapidstrapon
);
-- expect: every row on this platform reads 'ok'

-- ============================================================================
-- BLOCK B -- leaderboard flag on the CLOSING period, split by period so a roll is visible
-- ============================================================================
SELECT u.Username, c.PeriodTypeId, c.PeriodId, c.CompetitionsWon, c.IsBanned,
       CASE WHEN c.PeriodTypeId = 1 AND c.PeriodId = 20260914 AND c.IsBanned = 1 THEN 'ok'
            WHEN c.PeriodTypeId = 1 AND c.PeriodId = 20260914 THEN 'FAIL - closing week not flagged'
            ELSE 'info - other period' END AS Layer2
FROM CompetitiveRatingsCurrent c WITH (NOLOCK)
LEFT JOIN Users u WITH (NOLOCK) ON u.UserId = c.UserId
WHERE c.UserId IN (
    'DCB21F48-6B54-4F74-8A3F-9CAAE8BFF6A0','F3150296-CC7F-43B0-90A5-CC941B45E960',
    '80B05C6C-7719-40B5-89CA-3A358F0BD166','A92ED0C7-BB5E-43AC-971C-7AF91FD47D31',
    '16DDA5F1-E9C3-46F5-A43F-BFB806DE1F8F')
ORDER BY u.Username, c.PeriodTypeId, c.PeriodId;
-- expect: the PeriodTypeId=1 / PeriodId=20260914 row of each banned account reads 'ok'.
-- Monthly and Yearly rows appear as 'info' and should also carry IsBanned = 1 after the shared sync.

-- ============================================================================
-- BLOCK C -- the WHOLE reviewed cohort against the finalized weekly history
-- ============================================================================
WITH Cohort AS (
    SELECT CAST(v AS uniqueidentifier) AS UserId, n AS Verdict FROM (VALUES
        ('DCB21F48-6B54-4F74-8A3F-9CAAE8BFF6A0','BAN'),          -- LEK_TARNO
        ('F3150296-CC7F-43B0-90A5-CC941B45E960','BAN override'), -- HavocHHH
        ('80B05C6C-7719-40B5-89CA-3A358F0BD166','BAN'),          -- Gentleman83190
        ('A92ED0C7-BB5E-43AC-971C-7AF91FD47D31','BAN override'), -- CrazyGepard
        ('16DDA5F1-E9C3-46F5-A43F-BFB806DE1F8F','BAN'),          -- Rapidstrapon
        ('67E551F8-A305-4BBD-9C1E-8F96EBDD24B1','WATCH')         -- HalfSand_
    ) t(v, n)
)
SELECT u.Username, c.Verdict, h.Place, h.Value AS Wins, h.RewardId,
       CASE WHEN h.Place IS NULL                            THEN 'ok - not in history'
            WHEN h.Place > 10                               THEN 'ok - outside the paying places'
            WHEN c.Verdict LIKE 'BAN%'                      THEN 'FAIL - convicted but paid'
            ELSE 'info - acquitted and paid, by design' END AS BlockC
FROM Cohort c
LEFT JOIN Users u WITH (NOLOCK) ON u.UserId = c.UserId
LEFT JOIN CompetitiveRatingWeeklyHistory h WITH (NOLOCK)
       ON h.UserId = c.UserId AND h.PeriodId = 20260914
      AND h.TournamentKindId = 3 AND h.DimensionTypeId = 2
ORDER BY h.Place;
-- expect: no row reads 'FAIL'. HalfSand_ at place 9 is the one legitimate 'info' this cycle --
-- acquitted at confidence 9 and paid, which is the process working, not failing.
