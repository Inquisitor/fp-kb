-- FP-43631 week-22 -- competition bans, one pack for the whole cohort
-- ============================================================================
-- ONE block. Run it unchanged on each platform PROD MAIN (Steam / PS / Xbox). The join matches
-- only the candidates that exist on that database, so the other platforms' rows come back with
-- FoundUser = NULL -- which is also the cross-check that the platform split is what we think.
--
-- The cohort of 19 was read from the trajectory cards (SQL participation rows + log registration
-- times + GameSessions presence) and decided with the operator, one candidate at a time, reward
-- zone first. Cards in pcr-log-trajectories-2026-10-04/, grounds in _verdicts.md.
--
--   Banned: 13 -- Steam 5, PS 6, Xbox 2; 10 first offence, 3 repeat.
--   Not banned: ScionHades8639 (Xbox), anatoly2026 (PS), 1st_Demigod (Steam), STARI40K_YT (PS) -- WATCH;
--               xFenrir77 (Xbox) -- no action, upper bracket only;
--               intro20 (PS) -- banned elsewhere until 2026-12-02, nothing to apply.
--
-- Ban term: first offence 1 calendar month, repeat 2 calendar months, from the Monday after the
-- sweep (2026-10-05).
--
-- REWARD ZONE: 3 of the 13 stand in the rewarded top 10 of the closing weekly Won board (period
-- 20260928) -- ChaChaWuu9588 3 and ArticSquid71 7 on Xbox, Mariusz1029 5 on Steam. Layer 2 is the
-- SHARED `leaderboard-ban-sync.sql` (joins on UserId with no period filter, so it reaches the
-- closing weekly row plus monthly and yearly). It must land before 00:07Z, when
-- CompetitiveLeaderboardFinalizationJob writes history with `WHERE IsBanned = 0`.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW    date          = '2026-11-05';   -- 1 month from Monday 2026-10-05
    DECLARE @BanUntil_REPEAT date          = '2026-12-05';   -- 2 months from Monday 2026-10-05
    DECLARE @Note            nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-10-05 - rating-drop abuse (week-22)';

    BEGIN TRAN;

    IF OBJECT_ID('tempdb..#BanCandidates') IS NOT NULL DROP TABLE #BanCandidates;
    CREATE TABLE #BanCandidates (
        UserId   uniqueidentifier PRIMARY KEY,
        Username varchar(64)      NOT NULL,
        BanUntil date             NOT NULL,
        Verdict  varchar(10)      NOT NULL
    );

    INSERT INTO #BanCandidates (UserId, Username, BanUntil, Verdict) VALUES
        -- ---- Steam (5) ----
        ('60D42746-1430-4D54-A479-29583B87B0A5', 'Mariusz1029',    @BanUntil_REPEAT, 'REPEAT'),  -- Steam, board 5
        ('76DC3E6B-4BEA-47ED-83A4-D0649D605FF9', 'JoeCoviDodo',    @BanUntil_NEW,    'NEW'),     -- Steam
        ('17D9446A-6115-42B0-A48D-14914922F593', 'Tho1324',        @BanUntil_NEW,    'NEW'),     -- Steam
        ('8E2F69A6-B63B-46E6-A0B8-CDFB5741DD50', 'mr.GreeM',       @BanUntil_NEW,    'NEW'),     -- Steam
        ('DAA00F0B-2BA8-49A5-8BE2-9880D6C856E3', 'MP_Alan',        @BanUntil_NEW,    'NEW'),     -- Steam
        -- ---- PS (6) ----
        ('2C393625-F229-4284-8DB2-962BEBDE0774', 'marzak66',       @BanUntil_NEW,    'NEW'),     -- PS
        ('BB7842CC-E2F4-491A-A6A1-0083D202BCF7', 'keeno1',         @BanUntil_NEW,    'NEW'),     -- PS
        ('E3A99CF5-48D9-423F-998B-D714CC1668F6', 'thebig35994',    @BanUntil_NEW,    'NEW'),     -- PS
        ('496E32D7-CD9F-4F8F-96DF-F9171FCE1E93', 'zezinho_curuja', @BanUntil_NEW,    'NEW'),     -- PS
        ('D442B23B-4502-4427-8E08-CA35871DDC4D', 'popeye-43',      @BanUntil_NEW,    'NEW'),     -- PS
        ('C896536D-28FA-4785-A85E-48C27B947590', 'Panonski_Alas',  @BanUntil_REPEAT, 'REPEAT'),  -- PS
        -- ---- Xbox (2) ----
        ('13090FFE-7894-4C66-9AF2-0CD81C1A03EB', 'ChaChaWuu9588',  @BanUntil_REPEAT, 'REPEAT'),  -- Xbox, board 3
        ('623A4D04-BC0D-486B-AFF5-FEA169CBD915', 'ArticSquid71',   @BanUntil_NEW,    'NEW');     -- Xbox, board 7

    UPDATE p
    SET p.IsCompetitionsBanned   = 1,
        p.CompetitionsBanEndDate = b.BanUntil,
        p.AdminComment           = CASE
            WHEN p.AdminComment IS NULL OR LTRIM(RTRIM(p.AdminComment)) = ''
                THEN @Note + ' (' + b.Verdict + ' until ' + CONVERT(varchar(10), b.BanUntil, 23) + ')'
            ELSE p.AdminComment + CHAR(13) + CHAR(10) + @Note + ' (' + b.Verdict + ' until ' + CONVERT(varchar(10), b.BanUntil, 23) + ')'
        END
    FROM Profiles p
    INNER JOIN #BanCandidates b ON b.UserId = p.UserId
    WHERE NOT (ISNULL(p.IsCompetitionsBanned, 0) = 1
               AND p.CompetitionsBanEndDate IS NOT NULL
               AND p.CompetitionsBanEndDate > GETUTCDATE());
    PRINT CONCAT('Profiles banned on this DB: ', @@ROWCOUNT);

    UPDATE p
    SET p.IsInfluencer = 0
    FROM Profiles p
    INNER JOIN #BanCandidates b ON b.UserId = p.UserId
    WHERE p.IsInfluencer = 1;
    PRINT CONCAT('Influencer flags cleared: ', @@ROWCOUNT);

    SELECT b.Verdict,
           b.Username AS Expected,
           u.Username AS FoundUser,
           b.UserId,
           u.Source   AS Platform,
           p.IsCompetitionsBanned,
           p.CompetitionsBanEndDate,
           p.CompetitionRating AS CurrentPCR,
           p.IsInfluencer,
           p.AdminComment
    FROM #BanCandidates b
    LEFT JOIN Profiles p WITH (NOLOCK) ON p.UserId = b.UserId
    LEFT JOIN Users    u WITH (NOLOCK) ON u.UserId = b.UserId
    ORDER BY b.Verdict, FoundUser;

    DROP TABLE #BanCandidates;
END;
-- On Steam expect 5 banned rows (Mariusz1029 until 2026-12-05; JoeCoviDodo, Tho1324, mr.GreeM, MP_Alan until 2026-11-05) and 8 with FoundUser NULL.
-- On PS    expect 6 banned rows (Panonski_Alas until 2026-12-05; marzak66, keeno1, thebig35994, zezinho_curuja, popeye-43 until 2026-11-05) and 7 with FoundUser NULL.
-- On Xbox  expect 2 banned rows (ChaChaWuu9588 until 2026-12-05; ArticSquid71 until 2026-11-05) and 11 with FoundUser NULL.
-- Expected must equal FoundUser on every non-NULL row.
-- COMMIT;
-- or ROLLBACK;
