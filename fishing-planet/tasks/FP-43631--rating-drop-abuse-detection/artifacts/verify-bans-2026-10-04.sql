-- FP-43631 week-22 -- post-ban verification, 3 blocks, run per platform PROD MAIN
-- ============================================================================
-- Run after layer 1 (bans-2026-10-04.sql) and layer 2 (leaderboard-ban-sync.sql) are COMMITted.
--
-- BLOCK A. The profile ban landed: IsCompetitionsBanned = 1 with the right end date per verdict
-- (NEW 2026-11-05, REPEAT 2026-12-05), for exactly the 13 convicted and nobody else.
--
-- BLOCK B. The leaderboard flag landed **on the closing period**. This is the block that matters
-- tonight. The sweep runs on Sunday and CompetitiveRatingsCurrent rolls to the next weekly period
-- at 00:00Z, so a sync that reaches only the new period leaves the closing week unflagged and the
-- player receives the reward from it. Assert the 20260928 row exists and carries IsBanned = 1. Note
-- the row is deleted by CompetitiveLeaderboardCleanupJob at :20 past the hour -- after that this
-- block returns nothing and CompetitiveRatingWeeklyHistory is the only witness, so run it before
-- 00:20Z or fall back to block C.
--
-- BLOCK C. Blocks A and B look only at accounts that were banned, so neither can see a candidate the
-- review did NOT convict standing in the reward zone. Block C takes the WHOLE cohort and reports
-- where each one landed in the finalized history. Two different outcomes, and they must not be
-- conflated:
--   FAIL  - convicted but received the reward (the ban failed to apply in time)
--   info  - not convicted and received the reward (the process worked as designed)

-- ============================================================================
-- BLOCK A -- profile ban state, expected end date per verdict
-- ============================================================================
-- A: profile bans
WITH Expected AS (
    SELECT CAST(v AS uniqueidentifier) AS UserId, n AS Username, CAST(d AS datetime) AS BanEnd FROM (VALUES
        ('60D42746-1430-4D54-A479-29583B87B0A5', 'Mariusz1029',    '2026-12-05'),  -- Steam REPEAT
        ('76DC3E6B-4BEA-47ED-83A4-D0649D605FF9', 'JoeCoviDodo',    '2026-11-05'),  -- Steam NEW
        ('17D9446A-6115-42B0-A48D-14914922F593', 'Tho1324',        '2026-11-05'),  -- Steam NEW
        ('8E2F69A6-B63B-46E6-A0B8-CDFB5741DD50', 'mr.GreeM',       '2026-11-05'),  -- Steam NEW
        ('DAA00F0B-2BA8-49A5-8BE2-9880D6C856E3', 'MP_Alan',        '2026-11-05'),  -- Steam NEW
        ('2C393625-F229-4284-8DB2-962BEBDE0774', 'marzak66',       '2026-11-05'),  -- PS    NEW
        ('BB7842CC-E2F4-491A-A6A1-0083D202BCF7', 'keeno1',         '2026-11-05'),  -- PS    NEW
        ('E3A99CF5-48D9-423F-998B-D714CC1668F6', 'thebig35994',    '2026-11-05'),  -- PS    NEW
        ('496E32D7-CD9F-4F8F-96DF-F9171FCE1E93', 'zezinho_curuja', '2026-11-05'),  -- PS    NEW
        ('D442B23B-4502-4427-8E08-CA35871DDC4D', 'popeye-43',      '2026-11-05'),  -- PS    NEW
        ('C896536D-28FA-4785-A85E-48C27B947590', 'Panonski_Alas',  '2026-12-05'),  -- PS    REPEAT
        ('13090FFE-7894-4C66-9AF2-0CD81C1A03EB', 'ChaChaWuu9588',  '2026-12-05'),  -- Xbox  REPEAT
        ('623A4D04-BC0D-486B-AFF5-FEA169CBD915', 'ArticSquid71',   '2026-11-05')   -- Xbox  NEW
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
-- expect: every row present on this platform reads 'ok' (Steam 5, PS 6, Xbox 2); the others 'not on this DB'

-- ============================================================================
-- BLOCK B -- leaderboard flag on the CLOSING period, split by period so a roll is visible
-- ============================================================================
-- B: board flag, closing week
SELECT u.Username, c.PeriodTypeId, c.PeriodId, c.CompetitionsWon, c.IsBanned,
       CASE WHEN c.PeriodTypeId = 1 AND c.PeriodId = 20260928 AND c.IsBanned = 1 THEN 'ok'
            WHEN c.PeriodTypeId = 1 AND c.PeriodId = 20260928 THEN 'FAIL - closing week not flagged'
            ELSE 'info - other period' END AS Layer2
FROM CompetitiveRatingsCurrent c WITH (NOLOCK)
LEFT JOIN Users u WITH (NOLOCK) ON u.UserId = c.UserId
WHERE c.UserId IN (
    '60D42746-1430-4D54-A479-29583B87B0A5','76DC3E6B-4BEA-47ED-83A4-D0649D605FF9',
    '17D9446A-6115-42B0-A48D-14914922F593','8E2F69A6-B63B-46E6-A0B8-CDFB5741DD50',
    'DAA00F0B-2BA8-49A5-8BE2-9880D6C856E3','2C393625-F229-4284-8DB2-962BEBDE0774',
    'BB7842CC-E2F4-491A-A6A1-0083D202BCF7','E3A99CF5-48D9-423F-998B-D714CC1668F6',
    '496E32D7-CD9F-4F8F-96DF-F9171FCE1E93','D442B23B-4502-4427-8E08-CA35871DDC4D',
    'C896536D-28FA-4785-A85E-48C27B947590','13090FFE-7894-4C66-9AF2-0CD81C1A03EB',
    '623A4D04-BC0D-486B-AFF5-FEA169CBD915')
ORDER BY u.Username, c.PeriodTypeId, c.PeriodId;
-- expect: the PeriodTypeId=1 / PeriodId=20260928 row of each banned account reads 'ok'.
-- Monthly (20261001) and Yearly (20260101) rows appear as 'info' and should also carry IsBanned = 1 after the shared sync.

-- ============================================================================
-- BLOCK C -- the WHOLE cohort against the finalized weekly history (run after 00:07Z)
-- ============================================================================
-- C: cohort vs reward history
WITH Cohort AS (
    SELECT CAST(v AS uniqueidentifier) AS UserId, n AS Verdict FROM (VALUES
        ('60D42746-1430-4D54-A479-29583B87B0A5','BAN'),           -- Mariusz1029      Steam
        ('76DC3E6B-4BEA-47ED-83A4-D0649D605FF9','BAN'),           -- JoeCoviDodo      Steam
        ('17D9446A-6115-42B0-A48D-14914922F593','BAN'),           -- Tho1324          Steam
        ('8E2F69A6-B63B-46E6-A0B8-CDFB5741DD50','BAN'),           -- mr.GreeM         Steam
        ('DAA00F0B-2BA8-49A5-8BE2-9880D6C856E3','BAN'),           -- MP_Alan          Steam
        ('99D3FC51-C708-4C3E-9BAF-DAAB73A22602','WATCH'),         -- 1st_Demigod      Steam
        ('2C393625-F229-4284-8DB2-962BEBDE0774','BAN'),           -- marzak66         PS
        ('BB7842CC-E2F4-491A-A6A1-0083D202BCF7','BAN'),           -- keeno1           PS
        ('E3A99CF5-48D9-423F-998B-D714CC1668F6','BAN'),           -- thebig35994      PS
        ('496E32D7-CD9F-4F8F-96DF-F9171FCE1E93','BAN'),           -- zezinho_curuja   PS
        ('D442B23B-4502-4427-8E08-CA35871DDC4D','BAN'),           -- popeye-43        PS
        ('C896536D-28FA-4785-A85E-48C27B947590','BAN'),           -- Panonski_Alas    PS
        ('1CDB373F-5A08-4D3A-AB4A-83DAB1F00685','WATCH'),         -- anatoly2026      PS
        ('E25C082E-8A19-4236-AA8B-C345137E9EA3','WATCH'),         -- STARI40K_YT      PS
        ('8CFF48CD-F1AE-418F-82B4-20FD72B6F1DC','elsewhere'),     -- intro20          PS, banned elsewhere
        ('13090FFE-7894-4C66-9AF2-0CD81C1A03EB','BAN operator'),  -- ChaChaWuu9588    Xbox
        ('623A4D04-BC0D-486B-AFF5-FEA169CBD915','BAN'),           -- ArticSquid71     Xbox
        ('2F692613-2090-4D4C-8E52-736A6BEF5C2C','WATCH'),         -- ScionHades8639   Xbox
        ('BDD6D57E-E41F-475E-B067-C0D990A5A92C','no action')      -- xFenrir77        Xbox
    ) t(v, n)
)
SELECT u.Username, c.Verdict, h.Place, h.Value AS Wins, h.RewardId,
       CASE WHEN u.UserId IS NULL                            THEN 'not on this DB'
            WHEN h.Place IS NULL                            THEN 'ok - not in history'
            WHEN h.Place > 10                               THEN 'ok - outside the reward zone'
            WHEN c.Verdict LIKE 'BAN%'                      THEN 'FAIL - convicted but received the reward'
            ELSE 'info - not convicted, received the reward, by design' END AS BlockC
FROM Cohort c
LEFT JOIN Users u WITH (NOLOCK) ON u.UserId = c.UserId
LEFT JOIN CompetitiveRatingWeeklyHistory h WITH (NOLOCK)
       ON h.UserId = c.UserId AND h.PeriodId = 20260928
      AND h.TournamentKindId = 3 AND h.DimensionTypeId = 2
ORDER BY h.Place;
-- expect: no row reads 'FAIL'. Legitimate 'info' rows this cycle: ScionHades8639 on Xbox, anatoly2026 on PS,
-- 1st_Demigod on Steam (place 10 once Mariusz1029's ban frees it).
