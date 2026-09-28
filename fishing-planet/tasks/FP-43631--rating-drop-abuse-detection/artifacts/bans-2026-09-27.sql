-- FP-43631 week-21 -- competition bans, 6 of the 7 deadline candidates
-- ============================================================================
-- ONE block. Run it unchanged on each platform PROD MAIN (Steam / PS / Xbox). The join matches
-- only the candidates that exist on that database, so the other platforms' rows come back with
-- FoundUser = NULL -- which is also the cross-check that the platform split is what we think.
--
-- No tribunal this cycle, by the operator's decision. Each case was read from the rebuilt ledger
-- (SQL spine + log registration times + GameSessions presence) and decided with the operator, one
-- candidate at a time. Cards in pcr-log-trajectories-2026-09-27/, decisions in _verdicts.md.
--
--   HalfSand_       PS    REPEAT  81 registrations, 25 played, 53 no-shows, net -321 from 443; 5 boundary
--                                 crossings down; 4 of 8 prizes in NOOBS at 69..94 against a ceiling of 885;
--                                 23 no-shows spent 30+ min in the game; nightly 6-slot batches; our
--                                 week-14 ban lapsed 2026-09-07
--   TMRyuko         Xbox  NEW     32 registrations, 6 played, 25 no-shows at 81%; range 0..85 the whole
--                                 fortnight; 5 prizes in 6 games at 0..55; 10 consecutive absences 85 -> 0
--                                 then a prize at 0 -- the within-bracket shape, all four gates
--   Fuzzytacos6571  Xbox  REPEAT  20 registrations, 5 played, 15 no-shows; 5 prizes in 5 games at 0..55;
--                                 after every prize a run of absences to the next one, 8 of them 30+ min
--                                 in the game; registers a minute before the start and does not enter;
--                                 competition ban lapsed 2026-06-01
--   LaterGENJI      Xbox  NEW     OPERATOR DECISION against the standing rules (net +53, one boundary
--                                 crossing, rule 5 threshold not met): 4 of 5 prizes in NOOBS against a
--                                 ceiling of 237; zero-score 30 min after a win; skip at 151 while 120 min
--                                 in the game right after climbing to 168; batch registration. Blind
--                                 re-hearing queued per the week-20 rule
--   ELTITOGRAVY6    Xbox  NEW     42 registrations, 18 played, 24 unproductive; net +3 flat from +325 played
--                                 and -322 shed; 6 of 7 prizes in NOOBS (6 in 7 games) against 1 in 11
--                                 MIDDLES games; a day of honest MIDDLES play, then 9 unproductive 158 -> 62
--                                 and a prize at 62
--   Noob-KAKA1988   Steam NEW     58 registrations, 19 played, 39 unproductive; net -177 from 236 (635 a
--                                 week earlier); 17 consecutive unproductive 218 -> 10 then 1st at 10;
--                                 5 NOOBS games, 5 prizes; ceiling 589; board place 10, on the paying line
--
--   xFenrir77       Xbox  no action -- TOPS only, 0 prizes below his level, net +330; third cycle cleared.
--
-- Tariff unchanged (4W NEW / 8W REPEAT from the Monday following the sweep, 2026-09-28). A change to
-- month-aligned terms was considered and deferred to the CS lead.
--
-- PAYOUT: all 6 sit inside the paying top 10 on the closing weekly Won board (period 20260921) --
-- HalfSand_ 2 on PS; TMRyuko 2, LaterGENJI 5, Fuzzytacos6571 7, ELTITOGRAVY6 8 on Xbox;
-- Noob-KAKA1988 10 on Steam. Layer 2 is the SHARED `leaderboard-ban-sync.sql` (joins on UserId with
-- no period filter, so it reaches the closing weekly row plus monthly and yearly). It must land
-- before 00:07Z, when CompetitiveLeaderboardFinalizationJob writes history with `WHERE IsBanned = 0`.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW    date          = '2026-10-26';   -- 4 weeks from Monday 2026-09-28
    DECLARE @BanUntil_REPEAT date          = '2026-11-23';   -- 8 weeks from Monday 2026-09-28
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
        ('23A99BA9-E0F0-46E0-B5FC-846E5DAD0814', 'Noob-KAKA1988',  @BanUntil_NEW,    'NEW'),     -- Steam, board 10
        ('67E551F8-A305-4BBD-9C1E-8F96EBDD24B1', 'HalfSand_',      @BanUntil_REPEAT, 'REPEAT'),  -- PS,    board 2
        ('E39C9DAB-1697-434F-ADE9-D0122265ED13', 'TMRyuko',        @BanUntil_NEW,    'NEW'),     -- Xbox,  board 2
        ('0521E9F5-DCF5-438C-908D-689F0DFD2242', 'Fuzzytacos6571', @BanUntil_REPEAT, 'REPEAT'),  -- Xbox,  board 7
        ('95D6F8AE-0562-455E-99E0-6679CC506389', 'LaterGENJI',     @BanUntil_NEW,    'NEW'),     -- Xbox,  board 5
        ('7ACE60E8-8B33-401A-AE9F-B315DD848049', 'ELTITOGRAVY6',   @BanUntil_NEW,    'NEW');     -- Xbox,  board 8

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
-- On Steam expect 1 banned row  (Noob-KAKA1988) and 5 with FoundUser NULL.
-- On PS    expect 1 banned row  (HalfSand_, until 2026-11-23) and 5 with FoundUser NULL.
-- On Xbox  expect 4 banned rows (TMRyuko, LaterGENJI, ELTITOGRAVY6 until 2026-10-26; Fuzzytacos6571 until 2026-11-23) and 2 with FoundUser NULL.
-- Expected must equal FoundUser on every non-NULL row.
-- COMMIT;
-- or ROLLBACK;
