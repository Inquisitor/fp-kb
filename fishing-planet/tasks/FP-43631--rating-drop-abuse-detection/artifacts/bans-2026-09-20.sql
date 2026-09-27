-- FP-43631 week-20 -- competition bans, 5 of the 6 deadline candidates
-- ============================================================================
-- ONE block. Run it unchanged on each platform PROD MAIN (Steam / PS / Xbox). The join matches
-- only the candidates that exist on that database, so the other platforms' rows come back with
-- FoundUser = NULL -- which is also the cross-check that the platform split is what we think.
--
-- Trial (18 agents, 0 errors): BAN 3, WATCH 3.
--   BAN   LEK_TARNO (conf 8), Rapidstrapon (conf 8), Gentleman83190 (conf 9)
--   WATCH CrazyGepard (9), HavocHHH (9), HalfSand_ (9)
--
-- OPERATOR OVERRIDE of 2 WATCH verdicts: CrazyGepard and HavocHHH, both BANNED.
-- Same ground twice -- **the boundary-capper shape**. Rule 5's operative test counts downward
-- crossings, and neither ever crosses: each rides up to just under a bracket boundary and flushes
-- there, so the counter reads 0 and no rule reaches them.
--   CrazyGepard  tops out at exactly 100 -- the highest rating that is still NOOBS -- on 09-17
--                06:24 and takes 5 no-shows at 2-hour intervals back to 27, then a 3-entry
--                same-second flush to 0. Repeats it on 09-19. All 8 prizes in NOOBS;
--                counterfactual ceiling 73 + 302 = 375, MIDDLES.
--   HavocHHH     peaks at 988, 13 points short of the TOPS floor at 1001. On 09-19T03:35:56 a
--                PLAYED +47 reaching 988 is followed IN THE SAME SECOND by 4 no-shows back to 948;
--                again on 09-20T04:29:19, 6 entries in one second for -82. All 7 prizes in
--                MIDDLES; counterfactual ceiling 840 + 424 = 1264, TOPS.
-- Both overrides require a blind re-hearing on the full brief (week-20 rule), queued.
--
-- HalfSand_ stays WATCH and is deliberately absent: he sheds too, but his band is 384..505, the
-- middle of MIDDLES with no boundary within reach either way, and his counterfactual ceiling
-- (391 + 197 = 588) is the same bracket he plays and cashes in. His shedding buys nothing.
--
-- All 5 are NEW by our own ban history -> 4 weeks. BanUntil 2026-10-19 = the Monday following the
-- sweep (2026-09-21) + 28 days.
--
-- PAYOUT: 4 of the 5 sit inside the paying top 10 on the closing weekly Won board and lose the
-- prize -- LEK_TARNO place 1 and HavocHHH place 7 on Steam, CrazyGepard place 3 on PS,
-- Rapidstrapon place 5 on Xbox. Gentleman83190 is place 12, outside it; his ban is on the merits.
-- Places verified with the production ranking: DENSE_RANK over CompetitionsWon DESC,
-- CompetitionsWonTs ASC, CompetitionsWonExp DESC, banned rows excluded before ranking; 10 paying
-- rows per platform, cutoff 3 wins, no tie inflation.
--
-- Layer 2 is the SHARED `leaderboard-ban-sync.sql` (joins on UserId with no period filter, so it
-- reaches the closing weekly row plus monthly and yearly). It must land before 00:07Z, when
-- CompetitiveLeaderboardFinalizationJob writes history with `WHERE IsBanned = 0`.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW date          = '2026-10-19';   -- 4 weeks from Monday 2026-09-21
    DECLARE @Note         nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-09-21 - rating-drop abuse (week-20)';

    BEGIN TRAN;

    IF OBJECT_ID('tempdb..#BanCandidates') IS NOT NULL DROP TABLE #BanCandidates;
    CREATE TABLE #BanCandidates (
        UserId   uniqueidentifier PRIMARY KEY,
        Username varchar(64)      NOT NULL,
        BanUntil date             NOT NULL,
        Verdict  varchar(10)      NOT NULL
    );

    INSERT INTO #BanCandidates (UserId, Username, BanUntil, Verdict) VALUES
        ('DCB21F48-6B54-4F74-8A3F-9CAAE8BFF6A0', 'LEK_TARNO',      @BanUntil_NEW, 'NEW'),  -- Steam, conf 8/10 (board place 1 with 7 wins; 6 in-window boundary drops; 9 of 12 prizes in NOOBS against a MIDDLES ceiling of 712)
        ('F3150296-CC7F-43B0-90A5-CC941B45E960', 'HavocHHH',       @BanUntil_NEW, 'NEW'),  -- Steam, OPERATOR OVERRIDE of a WATCH (see header): caps at 988 under the TOPS floor and flushes in the same second; all 7 prizes in MIDDLES, counterfactual 1264
        ('80B05C6C-7719-40B5-89CA-3A358F0BD166', 'Gentleman83190', @BanUntil_NEW, 'NEW'),  -- PS,    conf 9/10 (26 unproductive of 35 at 74%, net -149, 3 in-window boundary drops, 5 of 6 prizes in NOOBS)
        ('A92ED0C7-BB5E-43AC-971C-7AF91FD47D31', 'CrazyGepard',    @BanUntil_NEW, 'NEW'),  -- PS,    OPERATOR OVERRIDE of a WATCH (see header): parks at exactly 100 and sheds 5 no-shows at 2-hour intervals, twice; all 8 prizes in NOOBS, counterfactual 375
        ('16DDA5F1-E9C3-46F5-A43F-BFB806DE1F8F', 'Rapidstrapon',   @BanUntil_NEW, 'NEW');  -- Xbox,  conf 8/10 (42 unproductive of 53 at 79%, net -175, 2 in-window boundary drops both on 09-17, 7 of 8 prizes in NOOBS)

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
-- On Steam expect 2 banned rows (LEK_TARNO, HavocHHH) and 3 with FoundUser NULL.
-- On PS    expect 2 banned rows (Gentleman83190, CrazyGepard) and 3 with FoundUser NULL.
-- On Xbox  expect 1 banned row  (Rapidstrapon) and 4 with FoundUser NULL.
-- Expected must equal FoundUser on every non-NULL row.
-- COMMIT;
-- or ROLLBACK;
