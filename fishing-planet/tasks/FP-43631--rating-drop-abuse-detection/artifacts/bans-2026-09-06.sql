-- FP-43631 week-18 ban -- surgical Profile ban of 4 reviewed rating-drop abusers (3 NEW + 1 REPEAT)
-- ============================================================================
-- CHARGE WINDOW. The sweep week 2026-08-31..2026-09-06. The trajectory cards span fourteen days
-- (2026-08-24..2026-09-06) because that is the entire retention of the Mongo tournamentLog; the
-- extra week is context for order and timing only and is not charged.
--
-- FIRST CYCLE ON THE DRAIN-INCLUSIVE SCREEN. Week-18 changed what the detection SQL counts: the
-- screen now selects on UNPRODUCTIVE participation -- no-shows plus zero-score finishes -- rather
-- than absence alone, because rating is shed just as well by entering and catching nothing, at
-- roughly half the cost per event. Disqualifications stay excluded (a DQ follows a ban). Cohort 17
-- against 13 under the old criteria; the four extra are drain-route candidates the old screen could
-- not see. Myky0576 is the extreme case: 27 zero-score finishes against a single no-show, i.e.
-- invisible to a no-show-only screen at 2.38% absence share.
--
-- REVIEW. 17 candidates through a 51-agent run (prosecutor and defence in parallel, judge
-- sequential), Support-blind. Result: 4 BAN / 12 WATCH / 1 EXONERATE.
--
-- THE LOW BAN COUNT IS NOT A SOFT REVIEW -- IT IS RULE 1 BITING. Week-18 amended limb 1(a) to read
-- rating from PRODUCTIVE play, and recorded at the time that the amendment leaves the sums
-- unchanged, so a candidate whose net rating is RISING still fails that limb. This cohort is full of
-- that shape. Several candidates had limb 1(b) expressly MET and rule 6 aggravating at maximum, and
-- were still held on WATCH because limb (a) failed and rule 5 -- the provision meant to reach a
-- rising net -- did not carry on the record. See the ban-execution md for the two cases that most
-- sharply expose this and are referred for a policy decision rather than banned here.
--
-- WHAT THE JUDGES ACTUALLY FOUND ON SEQUENCE. Repeatedly, the prosecution's climb-then-flush
-- exhibits did not survive verification against the raw log: a registration "booked" at the exact
-- second a prior competition resolved, while the player had been scoring inside that prior
-- competition for hours, is write order, not choice. This affects how the climb-then-flush signature
-- should be read in every future cycle and is recorded in the methodology.
--
-- The 4 in this script (judge confidence in parens):
--   NEW 4W -> 2026-10-05 (3):
--     PS   (2): Leelos90 (8) -- our week-17 WATCH returning; 26 unproductive of 35 at 74%, -366 from
--                              them against +268 productive, net -98, ends the window at 0, 6 of 7
--                              prizes taken at or below 100. Rules 4 and 8 fire on the return.
--               ST-9257  (8) -- upper-bracket case. Plays 22 MIDDLES and 19 TOPS, cashes 4 MIDDLES
--                              and 1 TOPS; sits at 990 against a counterfactual ceiling of 1164, so
--                              the prizes are taken a bracket below where his own play places him.
--                              11 of his 19 unproductive events are zero-score finishes.
--     Xbox (1): I JEEPERS I (7) -- plays 4 NOOBS and 8 MIDDLES, cashes 4 NOOBS and 1 MIDDLES;
--                              16 unproductive of 28 at 57%, -238 from them, net -85. Pure absence,
--                              no zero-score events.
--   REPEAT 8W -> 2026-11-02 (1):
--     PS   (1): CFC-T-W-T-32568 (9) -- our week-11 ban lapsed 2026-08-03 and he was carried on the
--                              week-17 watchlist, so this is a second return. Every prize in the
--                              bottom bracket while a bracket above is where he plays; 16
--                              unproductive of 24 at 67%.
--
-- SUPPORT OVERLAP. Leelos90 carries a Support ban to 2026-10-03, imposed 2026-09-03 -- mid-window,
-- which is why most of his charged activity predates it. The WHERE clause skips him. Note ours would
-- run two days longer; the convention is still not to touch another team's ban, and he gets a banLog
-- entry recording our independent finding.
-- EXPECTED PROFILE UPDATES: PS 2, Xbox 1 = 3 of the 4 rows.
--
-- Run this same script on EACH platform PROD MAIN. Non-present UserIds simply don't join Profiles.
--
-- REBAN WHERE CLAUSE: mirrors canonical game-engine `ProfileLogic.IsCompetitionsBannedNow()`.
--
-- LEADERBOARD ban is intentionally NOT done here -- run leaderboard-ban-sync.sql afterwards, then
-- verify-bans-2026-09-06.sql, which checks the closing period 20260831 separately from the new one.
--
-- Atomic: SET XACT_ABORT ON auto-rolls-back on any error. After inspecting the verify SELECT,
-- run COMMIT TRAN (or ROLLBACK TRAN) at the bottom by hand.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW    date          = '2026-10-05';   -- 4 weeks from Monday 2026-09-07
    DECLARE @BanUntil_REPEAT date          = '2026-11-02';   -- 8 weeks (recidivism)
    DECLARE @Note            nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-09-07 - rating-drop abuse (week-18)';

    BEGIN TRAN;

    IF OBJECT_ID('tempdb..#BanCandidates') IS NOT NULL DROP TABLE #BanCandidates;
    CREATE TABLE #BanCandidates (
        UserId   uniqueidentifier PRIMARY KEY,
        Username varchar(64)      NOT NULL,
        BanUntil date             NOT NULL,
        Verdict  varchar(10)      NOT NULL
    );

    INSERT INTO #BanCandidates (UserId, Username, BanUntil, Verdict) VALUES
        -- NEW - 4W -> 2026-10-05
        ('51873B16-7A58-4FC6-B234-7F3617C0CE91', 'Leelos90',        @BanUntil_NEW,    'NEW'),    -- PS,   conf 8/10 (week-17 WATCH returning; 74% unproductive, ends at 0) -- SKIPPED, Support ban to 2026-10-03
        ('09BDC8BF-B133-493E-9EBE-E5C145CB0FDE', 'ST-9257',         @BanUntil_NEW,    'NEW'),    -- PS,   conf 8/10 (990 actual against 1164 counterfactual; cashes a bracket below his play)
        ('92517835-3C2F-449D-AE3E-1ECEBE9E656A', 'I JEEPERS I',     @BanUntil_NEW,    'NEW'),    -- Xbox, conf 7/10 (plays MIDDLES, cashes NOOBS; 57% unproductive, net -85)
        -- REPEAT - 8W -> 2026-11-02
        ('469DF796-D270-40FF-BAD9-8A5B9D83B6DC', 'CFC-T-W-T-32568', @BanUntil_REPEAT, 'REPEAT'); -- PS,   conf 9/10 (second return; week-11 ban lapsed 2026-08-03, week-17 watchlist)

    -- Profile ban (durable). WHERE clause mirrors `IsCompetitionsBannedNow()`, so anyone already
    -- effectively banned -- by Support or by us -- is left untouched.
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

    -- After visual inspection pick ONE:
    -- COMMIT TRAN;
    -- ROLLBACK TRAN;
END;
