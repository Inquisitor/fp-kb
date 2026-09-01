-- FP-43631 week-17 ban -- surgical Profile ban of 16 reviewed rating-drop abusers (15 NEW + 1 REPEAT)
-- ============================================================================
-- First cycle after a two-Sunday enforcement pause agreed with the community team. Cohort came
-- back at 19 with an entirely new cast: not one of the week-14 candidates appears in it.
--
-- CHARGE WINDOW. The charge is the sweep week 2026-08-24..2026-08-30. The three-week record
-- 2026-08-10..2026-08-30 was supplied to the review as CONTEXT only -- it may aggravate and it may
-- establish the temporal sequence, but the pause was our decision and must not be turned into a
-- heavier charge after the fact. Two candidates are the exception and are charged cumulatively
-- under rule 8 because they carried a WATCH verdict in an earlier cycle: TrcikLowFiv and
-- martelli04, neither of whom passes the weekly gate at all.
--
-- REVIEW. 21 candidates through an 84-agent run (parse + prosecutor/defence/judge per case),
-- Support-blind. First hearing: 11 BAN / 10 WATCH. Seven cases were then RE-HEARD after two
-- defects were found (see below): 6 of those 7 flipped to BAN, one WATCH upheld (Leelos90).
-- One first-hearing BAN was withdrawn on re-checked data (tigrou_le_boss42, see below).
--
-- TWO DEFECTS FOUND AND CORRECTED DURING THIS CYCLE:
--
-- 1. RULE 1(b) REGRESSION. The week-14 rewrite made the offence bracket-relative -- prizes taken
--    below the highest bracket the player reaches. That silently exempted the most deflated
--    accounts: a player already pushed to the floor has no bracket above him inside the window, so
--    there was nothing for his prizes to be "below", and the same-bracket carve-out then sheltered
--    him. Six of the ten first-hearing WATCH verdicts were this. Rule 1(b) now takes the ceiling as
--    the HIGHER of actual exposure and the COUNTERFACTUAL: the bracket the player's rating would
--    sit in without the penalties he took by not appearing. loseloop, for instance, entered the
--    window at 927 and is at 0; his play alone was worth +163, so his counterfactual ceiling is
--    1090 while every prize was taken at 0.
--
-- 2. LEDGER RETENTION. The Mongo tournamentLog holds fourteen days. Every trajectory card in this
--    cycle begins 2026-08-16 although the window opens 2026-08-10, so findings of the form "no
--    boundary crossing" were true of the ledger and false of the record. SQL is complete and has no
--    retention limit; where they disagree about anything before 2026-08-16, SQL governs.
--
-- BRACKET LABELS ARE NOT PCR BRACKETS. `TournamentParticipants.BracketId` is the bucket the player
-- ended up in after matchmaking balancing, not his rating band: undersized buckets pull players
-- from neighbours and, failing that, merge. Prize splits for every candidate here were therefore
-- re-derived from `CompetitionRatingAtStart` rather than from the label. Ten of the eleven
-- first-hearing bans survive that re-derivation unchanged or strengthened.
--
-- WITHDRAWN: tigrou_le_boss42 (PS). His limb 1(b) rested explicitly "on the SQL's own tier field".
-- Re-derived by rating, only 3 of his 6 prizes were taken while he was at or below 100 and his
-- week maximum is 162, against 46 competitions played in MIDDLES over three weeks. That is a weak
-- pattern, and rule 2 does not ban on a weak pattern. Moved to WATCH; he registers around a
-- hundred times a fortnight and will return to the cohort with the corrected classification.
--
-- The 16 in this script (judge confidence in parens):
--   NEW 4W -> 2026-09-28 (15):
--     Steam (6): ASOAWELS (7), MrAl3xXx (8), RubyMarlinSultan (8),
--                loseloop (9, re-heard -- entered the window at 927, ended at 0, 83 no-shows at 93%),
--                Saintmnk (9, re-heard -- counterfactual ceiling 528 against 12 prizes all taken at the floor),
--                SoRA6r (8, re-heard)
--     PS    (7): DJTigar (9), Akkord_8 (8), blue102180 (8, largest three-week haul at 19 prizes),
--                bigbruney24 (8), lolofifa29 (8),
--                martelli04 (7, CUMULATIVE charge under rule 8 -- week-14 WATCH returning, the
--                            data-sufficiency shelter no longer applies at 17 starts),
--                HIflyfishingGH (8, re-heard -- week-12 WATCH returning)
--     Xbox  (2): ChaChaWuu9588 (8), ScionHades8639 (8, re-heard -- entered the window at 122, now 0)
--   REPEAT 8W -> 2026-10-26 (1):
--     Steam (1): TrcikLowFiv (7, re-heard, CUMULATIVE charge under rule 8; our own ban lapsed
--                2026-06-12; recorded at rating 1006 inside the window against a counterfactual
--                ceiling of 1122 and prizes taken at 869 and 842)
--
-- SUPPORT OVERLAP. Four of the sixteen already carry Support bans that run at least as long as
-- ours: Saintmnk (2026-09-28), loseloop (2026-09-29), DJTigar (2026-09-30), Akkord_8 (2026-09-30).
-- The WHERE clause skips them by design -- shortening another team's ban would be a regression.
-- They still get banLog entries recording our independent finding (LaccFarro precedent, week-10).
-- EXPECTED PROFILE UPDATES: Steam 4, PS 5, Xbox 2 = 11 of the 16 rows. (Steam 6 minus Saintmnk and
-- loseloop, plus TrcikLowFiv; PS 7 minus DJTigar and Akkord_8.)
--
-- Run this same script on EACH platform PROD MAIN. Non-present UserIds simply don't join Profiles.
--
-- REBAN WHERE CLAUSE: mirrors canonical game-engine `ProfileLogic.IsCompetitionsBannedNow()`.
--
-- LEADERBOARD ban is intentionally NOT done here -- run leaderboard-ban-sync.sql afterwards, then
-- verify-bans-2026-08-30.sql, which now checks the closing period explicitly.
--
-- Atomic: SET XACT_ABORT ON auto-rolls-back on any error. After inspecting the verify SELECT,
-- run COMMIT TRAN (or ROLLBACK TRAN) at the bottom by hand.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW    date          = '2026-09-28';   -- 4 weeks from Monday 2026-08-31
    DECLARE @BanUntil_REPEAT date          = '2026-10-26';   -- 8 weeks (recidivism)
    DECLARE @Note            nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-08-31 - rating-drop abuse (week-17)';

    BEGIN TRAN;

    IF OBJECT_ID('tempdb..#BanCandidates') IS NOT NULL DROP TABLE #BanCandidates;
    CREATE TABLE #BanCandidates (
        UserId   uniqueidentifier PRIMARY KEY,
        Username varchar(64)      NOT NULL,
        BanUntil date             NOT NULL,
        Verdict  varchar(10)      NOT NULL
    );

    INSERT INTO #BanCandidates (UserId, Username, BanUntil, Verdict) VALUES
        -- NEW - 4W -> 2026-09-28
        ('890EEF14-DACA-451E-AE0D-EE7454D996FD', 'ASOAWELS',         @BanUntil_NEW,    'NEW'),    -- Steam, conf 7/10 (8 prizes all taken at PCR <= 100 while reaching 137)
        ('11AAA18E-D387-4431-B195-60130CEEB90B', 'MrAl3xXx',         @BanUntil_NEW,    'NEW'),    -- Steam, conf 8/10 (20 no-shows at 67%, 5 of 6 prizes below the ceiling)
        ('4B47AE81-1B95-4BB2-9B21-77186189665A', 'RubyMarlinSultan', @BanUntil_NEW,    'NEW'),    -- Steam, conf 8/10 (5 prizes all at PCR <= 100, week maximum 102)
        ('250A6AB6-AF79-454F-881B-7AF2655A970E', 'loseloop',         @BanUntil_NEW,    'NEW'),    -- Steam, conf 9/10 (re-heard; 927 -> 0, 83 no-shows at 93%) -- SKIPPED, Support ban to 2026-09-29
        ('A6255AD3-8198-49A9-A27F-B3643B0D994A', 'Saintmnk',         @BanUntil_NEW,    'NEW'),    -- Steam, conf 9/10 (re-heard; counterfactual ceiling 528, 12 prizes all at the floor) -- SKIPPED, Support ban to 2026-09-28
        ('F19AB1BB-4482-459D-9D4B-B8BB753FFFFE', 'SoRA6r',           @BanUntil_NEW,    'NEW'),    -- Steam, conf 8/10 (re-heard; counterfactual ceiling 445 against 12 NOOBS prizes)
        ('AFBB0707-23C7-4601-ABFD-E8093490813B', 'DJTigar',          @BanUntil_NEW,    'NEW'),    -- PS,    conf 9/10 (8 prizes all at PCR <= 100) -- SKIPPED, Support ban to 2026-09-30
        ('275768BF-834B-44E4-9297-11B946C070E0', 'Akkord_8',         @BanUntil_NEW,    'NEW'),    -- PS,    conf 8/10 (7 prizes all at PCR <= 100; 21 zero-score finishes of 40 starts) -- SKIPPED, Support ban to 2026-09-30
        ('9C7CEA54-909B-41F9-994B-05DCCB86C144', 'blue102180',       @BanUntil_NEW,    'NEW'),    -- PS,    conf 8/10 (19 prizes across three weeks, the largest haul in the cohort)
        ('2A9E0031-CD4A-41B7-A791-20E395C43ABB', 'bigbruney24',      @BanUntil_NEW,    'NEW'),    -- PS,    conf 8/10 (5 prizes at PCR-before 92, 84, 61, 55 and 0)
        ('783F7778-52A1-4D72-B569-26665CD72714', 'lolofifa29',       @BanUntil_NEW,    'NEW'),    -- PS,    conf 8/10 (4 prizes all at PCR <= 100)
        ('1D95D7D9-D983-4F8A-B8F2-2E2BB3AAA247', 'martelli04',       @BanUntil_NEW,    'NEW'),    -- PS,    conf 7/10 (CUMULATIVE charge, rule 8; week-14 WATCH returning)
        ('EBC824AC-464E-4186-B896-A937A0599D6C', 'HIflyfishingGH',   @BanUntil_NEW,    'NEW'),    -- PS,    conf 8/10 (re-heard; week-12 WATCH returning, counterfactual ceiling 414)
        ('13090FFE-7894-4C66-9AF2-0CD81C1A03EB', 'ChaChaWuu9588',    @BanUntil_NEW,    'NEW'),    -- Xbox,  conf 8/10 (5 of 8 prizes at PCR <= 100 while reaching 134)
        ('2F692613-2090-4D4C-8E52-736A6BEF5C2C', 'ScionHades8639',   @BanUntil_NEW,    'NEW'),    -- Xbox,  conf 8/10 (re-heard; entered the window at 122, now 0, 69 no-shows at 78%)
        -- REPEAT - 8W -> 2026-10-26
        ('9757FD6A-8435-409A-9F83-33214AF80424', 'TrcikLowFiv',      @BanUntil_REPEAT, 'REPEAT'); -- Steam, conf 7/10 (re-heard, CUMULATIVE charge; our ban lapsed 2026-06-12; rating 1006 recorded in-window)

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
