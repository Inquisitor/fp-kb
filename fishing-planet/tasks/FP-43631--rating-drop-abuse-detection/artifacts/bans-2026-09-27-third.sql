-- FP-43631 week-21 -- competition bans, THIRD PACK: the 2 Steam candidates the early screen missed
-- ============================================================================
-- ONE block. Run it on [F2P] STEAM PROD MAIN only (both candidates are Steam accounts); on the other
-- platforms every row would come back with FoundUser = NULL.
--
-- Same cycle, same tariff and note as bans-2026-09-27.sql and bans-2026-09-27-second.sql. Both
-- surfaced only when the screen was re-run after 22:00Z: their fourth prize, which the screen
-- requires, came in the week's last competition (20:00-22:00), after the 21:35Z screen. Neither was
-- in the paying places (33rd and unplaced). Decided with the operator from the rebuilt cards;
-- grounds in pcr-log-trajectories-2026-09-27/_verdicts.md.
--
--   AmazingQuestHero45  Steam  NEW  fresh account (first competition 09-17), 24 registrations, 6 played,
--                                   17 no-shows at 75%, net -91 from 119; a 6-slot batch registered at
--                                   08:00 and skipped entirely, three of the skips while 111-119 min in
--                                   the game; 4 prizes in 6 games, all NOOBS, incl. 1st at 0 after two
--                                   in-game skips of 120 and 117 min; 2 boundary crossings down
--   kojldyn             Steam  NEW  week-20 WATCH returning; 32 registrations, 14 played, 17 no-shows;
--                                   twice in a fortnight batch-registers 7-10 consecutive slots at a
--                                   local peak (112 on 09-20, 115 on 09-26), skips them all down to 0
--                                   and takes a prize at the floor; 4 prizes in 14 games, all NOOBS
--
-- Tariff 4W NEW from the Monday following the sweep (2026-09-28); calendar months from week-22.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW    date          = '2026-10-26';   -- 4 weeks from Monday 2026-09-28
    DECLARE @Note            nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-09-28 - rating-drop abuse (week-21)';

    BEGIN TRAN;

    IF OBJECT_ID('tempdb..#BanCandidates') IS NOT NULL DROP TABLE #BanCandidates;
    CREATE TABLE #BanCandidates (
        UserId   uniqueidentifier PRIMARY KEY,
        Username varchar(64)      NOT NULL,
        BanUntil date             NOT NULL,
        Verdict  varchar(10)      NOT NULL
    );

    INSERT INTO #BanCandidates (UserId, Username, BanUntil, Verdict) VALUES
        ('1DFD5192-3B71-437F-BB5E-B0A3CFD2C281', 'AmazingQuestHero45', @BanUntil_NEW, 'NEW'),  -- Steam
        ('67831814-56C8-47AC-BBE2-882DC339072A', 'kojldyn',            @BanUntil_NEW, 'NEW');  -- Steam

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
-- On Steam expect 2 banned rows (AmazingQuestHero45, kojldyn), both until 2026-10-26.
-- Expected must equal FoundUser on every non-NULL row.
-- COMMIT;
-- or ROLLBACK;
