-- FP-43631 week-13 ban -- surgical Profile ban of 7 log-verified rating-drop abusers (5 NEW + 2 REPEAT)
-- ============================================================================
-- Hand-picked list: each UserId was confirmed via the Mongo Tournament-log trajectory analysis
-- on 2026-08-02 (see artifacts/bans-2026-08-02.md) AND passed a per-candidate review
-- (prosecutor / defense / impartial-judge per case, 54-agent workflow over 18 wide-cohort
-- candidates).
--
-- NEW DURATIONS FROM THIS CYCLE: 4 weeks first offence, 8 weeks recidivism (previously 2W/4W).
-- Raised because the 2W term demonstrably failed to deter -- strullendorfer returned 13 days
-- after expiry, jackylu 16 days, kokoljj ~3 weeks, Aorney ~4.5 weeks. The CS lead had proposed
-- permanent bans for repeat offenders; 4W/8W is the agreed interim step.
--
-- Review outcomes: 14 BAN + 3 WATCH + 1 EXONERATE. Seven of the 14 BAN verdicts are players
-- Support had already actioned before the sweep (LuizFernandoo, BarbosUa, MORPH3US,
-- ELPEZGORDO12, aperno, La_Iena_River_, ZacKasoN) -- not re-banned here. The other 7 are this
-- script.
--
-- This cycle's review was run Support-blind: the pre-trial context carried no indication of who
-- Support had already banned, so the verdicts are an independent check rather than a
-- confirmation. It was also run twice over the same cohort -- once under the previous rules and
-- once under the revised rule 6 -- to measure whether the rule set was too lenient. The old
-- rules missed two players Support had banned; the revision missed none and flipped no
-- confident BAN the other way. See bans-2026-08-02.md.
--
-- The 7 in this script (judge confidence in parens):
--   NEW   4W -> 2026-08-31:
--     Steam (2): FarantirPL       (8, **returned after two absent cycles following a week-9 WATCH**;
--                                  21 NS 70%, PCR 0. Absence from a cohort is not correction)
--                wallims          (9, within-bracket detector; LB Rank 2 while holding PCR 25,
--                                  plays exclusively in NOOBS)
--     PS    (2): BOOMDATRUTH2     (9, **week-12 WATCH returning** -- prizes 4N -> 8N, no-shows
--                                  12 -> 26; rule 8 persistence met on multiple limbs)
--                Old-Black-Fisher (8, 5N pure, 19 NS 70%, plays exclusively in NOOBS)
--     Xbox  (1): Mjolnir8761      (7, largest prize haul in the cohort at 12; weakest of the
--                                  seven because seven of his played comps are in TOPS)
--   REPEAT 8W -> 2026-09-28:
--     Steam (1): Aorney           (8, ban lapsed 2026-07-01 and he returned; **was on the week-4
--                                  watchlist as a MIDDLES-only flavor and the flavor has now
--                                  changed to NOOBS** -- rule 4. Defense argued WATCH, judge overrode)
--     PS    (1): kokoljj          (8, **our own week-8 ban lapsed 2026-07-13, back within three
--                                  weeks**; carries the cohort's only literal sink-comp repeat --
--                                  competition #374038 no-showed twice)
--
-- WATCH (3): eMadkiller5964 (Xbox -- held on rule 3, only 7 competitions played against 19
-- no-shows, a genuine data-sufficiency limit), Pilou625057 (Win10 -- mixed flavor, 9 of 18
-- played comps in TOPS, wrong mechanism under rules 1/2), EsseDouble (Steam -- upper-bracket
-- sandbagging, see the note below).
-- EXONERATE (1): X1aoDouYa -- closed as a non-target under rule 7 direction 2, fourth cycle with
-- an unchanged upper-bracket profile and zero NOOBS prizes.
-- NOTE: EsseDouble carries a near-identical profile to X1aoDouYa but drew WATCH rather than
-- EXONERATE. Judges evaluate candidates independently and cannot see one another, so the
-- uniformity clause added to rule 7 did not bind. Both are proposed for manual closure.
--
-- Platform note: the cohort is no longer purely Steam/PS/Xbox -- ELPEZGORDO12 is an Epic account
-- on the Steam DB and Pilou625057 is a Win10 account on the Xbox DB. Neither is in this script,
-- but the per-DB split below is by database, not by the player's platform label.
--
-- Run this same script on EACH platform PROD MAIN:
--   [F2P] STEAM PROD  -> matches 3 (FarantirPL, wallims, Aorney)
--   [F2P] PS    PROD  -> matches 3 (BOOMDATRUTH2, Old-Black-Fisher, kokoljj)
--   [F2P] XB    PROD  -> matches 1 (Mjolnir8761)
-- Non-present UserIds simply don't join Profiles (verify SELECT flags them as not-found per DB).
--
-- REBAN WHERE CLAUSE: mirrors canonical game-engine `ProfileLogic.IsCompetitionsBannedNow()`.
--
-- LEADERBOARD ban is intentionally NOT done here -- run leaderboard-ban-sync.sql afterwards.
-- Standing rule: verify all three layers (Profiles / CompetitiveRatingsCurrent / banLog) per
-- platform individually -- see verify-bans-2026-08-02.sql.
--
-- Atomic: SET XACT_ABORT ON auto-rolls-back on any error. After inspecting the verify SELECT,
-- run COMMIT TRAN (or ROLLBACK TRAN) at the bottom by hand.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW    date          = '2026-08-31';   -- 4 weeks, Monday-aligned (first offence)
    DECLARE @BanUntil_REPEAT date          = '2026-09-28';   -- 8 weeks (recidivism)
    DECLARE @Note            nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-08-03 - rating-drop abuse (week-13)';

    BEGIN TRAN;

    -- Step 1: explicit ban list with per-row BanUntil + Verdict tag
    IF OBJECT_ID('tempdb..#BanCandidates') IS NOT NULL DROP TABLE #BanCandidates;
    CREATE TABLE #BanCandidates (
        UserId   uniqueidentifier PRIMARY KEY,
        Username varchar(64)      NOT NULL,
        BanUntil date             NOT NULL,
        Verdict  varchar(10)      NOT NULL
    );

    INSERT INTO #BanCandidates (UserId, Username, BanUntil, Verdict) VALUES
        -- NEW - 4W -> 2026-08-31
        ('5ED0507E-3D58-4FA7-B5C5-A3DF361B791F', 'FarantirPL',       @BanUntil_NEW,    'NEW'),    -- Steam, conf 8/10 (returned after two absent cycles following a week-9 WATCH; 21 NS 70%, PCR 0)
        ('DA1E5723-6F95-4600-98CD-F3E680E5163E', 'wallims',          @BanUntil_NEW,    'NEW'),    -- Steam, conf 9/10 (within-bracket detector; LB Rank 2 at PCR 25, plays only in NOOBS)
        ('30F95ADA-24FA-4FA1-8671-48F73D804156', 'BOOMDATRUTH2',     @BanUntil_NEW,    'NEW'),    -- PS,    conf 9/10 (week-12 WATCH returning; prizes 4N -> 8N, no-shows 12 -> 26)
        ('17C96F92-269F-4811-AF1E-813AFC75E144', 'Old-Black-Fisher', @BanUntil_NEW,    'NEW'),    -- PS,    conf 8/10 (5N pure, 19 NS 70%, plays only in NOOBS)
        ('6DE2B7AD-6EA2-4F67-AB64-2C4CD4CBCDCA', 'Mjolnir8761',      @BanUntil_NEW,    'NEW'),    -- Xbox,  conf 7/10 (12 prizes, largest haul; weakest case -- 7 played comps in TOPS)
        -- REPEAT - 8W -> 2026-09-28
        ('132E8BE9-7515-4898-B4D6-ACF7FADE37C7', 'Aorney',           @BanUntil_REPEAT, 'REPEAT'), -- Steam, conf 8/10 (ban lapsed 2026-07-01; week-4 watchlist MIDDLES-only, flavor now NOOBS -- rule 4)
        ('882BB61A-9F03-4706-B58E-AA9A279E303B', 'kokoljj',          @BanUntil_REPEAT, 'REPEAT'); -- PS,    conf 8/10 (our week-8 ban lapsed 2026-07-13, back in 3 weeks; sink-comp repeat on #374038)

    -- Step 2: Profile ban (durable). Allows re-ban when player is NOT effectively banned at
    -- sweep time. WHERE clause mirrors canonical game-engine `IsCompetitionsBannedNow()` check.
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

    -- Step 3: Influencer reset (matches WebAdmin behaviour)
    UPDATE p
    SET p.IsInfluencer = 0
    FROM Profiles p
    INNER JOIN #BanCandidates b ON b.UserId = p.UserId
    WHERE p.IsInfluencer = 1;

    PRINT CONCAT('Influencer flags cleared: ', @@ROWCOUNT);

    -- Step 4: verify (FoundUser non-null = matched on this DB; null = belongs to another platform)
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
