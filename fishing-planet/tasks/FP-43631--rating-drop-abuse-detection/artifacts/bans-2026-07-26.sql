-- FP-43631 week-12 ban -- surgical Profile ban of 6 log-verified rating-drop abusers (5 NEW + 1 REPEAT)
-- ============================================================================
-- Hand-picked list: each UserId was confirmed via the Mongo Tournament-log trajectory analysis
-- on 2026-07-26 (see artifacts/bans-2026-07-26.md) AND passed a per-candidate review
-- (prosecutor / defense / impartial-judge per case, run as a 57-agent workflow against 19
-- wide-cohort candidates).
--
-- Review outcomes summary: 8 BAN + 10 WATCH + 1 EXONERATE. Of the 8 BAN verdicts, 3 are players
-- Support has ALREADY actioned this cycle (KondaFlk BanEnd 2026-08-08, VGB_N4rkos060905
-- 2026-08-07, rascof molotov 2026-08-25) -- not re-banned here. Recorded in bans-2026-07-26.md
-- as "Support pre-actioned, review-confirmed".
--
-- The 6 in this script (judge confidence in parens; dreadloc is an operator override):
--   NEW   2W -> 2026-08-10:
--     Steam (3): dreadloc          (**operator override of a WATCH verdict** -- Steam weekly Won
--                                   leaderboard Place 6 with LifePCR 46 and period rating -13;
--                                   the only player in that top-10 accumulating wins while net
--                                   negative on rating. 7N pure, 7 of 11 lifetime prizes taken
--                                   inside this 20-day window)
--                Albbert           (8, 7N pure, 20 NS 43%, net-positive PCR defeated by rule 5)
--                Zemaro            (8, **W11 WATCH conf 7 returning** -- rule 8 persistence:
--                                   Lifetime 8 -> 13, NoShowSharePct 52% -> 65%)
--     PS    (1): vlad_spain        (10, **W11 WATCH conf 6 returning, largest escalation in the
--                                   cohort** -- NOOBS prizes 5 -> 11, NS 19 -> 39, Lifetime 6 -> 18.
--                                   Defense CONCEDE)
--     Xbox  (1): TurboBandz6351    (9, **W11 WATCH conf 6 returning** -- rule 9 now outranks rule 6
--                                   on a returning candidate; ZeroScore 5 -> 9, PCR 81 -> 22,
--                                   net -140. Defense CONCEDE)
--   REPEAT 4W -> 2026-08-24:
--     Steam (1): jackylu           (9, **prior ban lapsed 2026-07-10, back in the farm-gated cohort
--                                   16 days later**; 4N pure, 15 NS 68%. Defense CONCEDE)
--
-- WATCH (10, structural reasons): dreadloc was the sole WATCH overridden -- the rest stand.
-- EsseDouble + X1aoDouYa (Steam TOP-flavor, PCR 815/805, zero NOOBS play), autoteo78 (PS
-- TOP-flavor MASTERS PCR 937), HIflyfishingGH / ThorUs422 (PS -- floor arrivals acknowledged as
-- aggravating but the no-show mass is not boundary-targeted), BOOMDATRUTH2 / Alien_Back (PS,
-- exactly at the 30% gate, balanced NOOBS/MIDDLES play), La_Iena_River_ (PS -- **W11 WATCH
-- validated by moderation**: 42 NS 84% -> 9 NS 41%, net now positive), COUNTRY3PER (Xbox veteran,
-- mixed 3N+1M, 9 played).
-- EXONERATE (1): Panonski_Alas (PS) -- **closed as a NON-TARGET under rule 7 direction 2 and
-- EXITS FP-43631 tracking**; PCR band 917..1039, zero NOOBS prizes, zero boundary crossings,
-- every flush immediately reclaimed upward. Not carried on a further WATCH clock.
--
-- The six live on 3 platform PROD DBs. Run this same script on EACH:
--   [F2P] STEAM PROD  -> matches 4 (dreadloc, Albbert, Zemaro, jackylu)
--   [F2P] PS    PROD  -> matches 1 (vlad_spain)
--   [F2P] XB    PROD  -> matches 1 (TurboBandz6351)
-- Non-present UserIds simply don't join Profiles (verify SELECT flags them as not-found per DB).
--
-- REBAN WHERE CLAUSE: mirrors canonical game-engine `ProfileLogic.IsCompetitionsBannedNow()`.
--
-- LEADERBOARD ban is intentionally NOT done here -- run leaderboard-ban-sync.sql afterwards.
-- Standing rule: verify all three layers (Profiles / CompetitiveRatingsCurrent / banLog) per
-- platform individually -- see verify-bans-2026-07-26.sql.
--
-- Atomic: SET XACT_ABORT ON auto-rolls-back on any error. After inspecting the verify SELECT,
-- run COMMIT TRAN (or ROLLBACK TRAN) at the bottom by hand.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW    date          = '2026-08-10';   -- 2 weeks, Monday-aligned (first-time bans)
    DECLARE @BanUntil_REPEAT date          = '2026-08-24';   -- 4 weeks (recidivism)
    DECLARE @Note            nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-07-27 - rating-drop abuse (week-12)';

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
        -- NEW - 2W -> 2026-08-10
        ('99247BDE-F4CB-4698-8A5C-679550D9F369', 'dreadloc',       @BanUntil_NEW,    'NEW'),    -- Steam, operator override (LB Won Place 6, LifePCR 46, period rating -13, 7N pure)
        ('CB167D53-BD55-4228-8B44-F41A284E7C3E', 'Albbert',        @BanUntil_NEW,    'NEW'),    -- Steam, judge confidence  8/10 (7N pure, rule 5 defeats net-positive PCR)
        ('B3440760-BBD6-4AF0-B0EE-DEF6B131DE62', 'Zemaro',         @BanUntil_NEW,    'NEW'),    -- Steam, judge confidence  8/10 (W11 WATCH returning, rule 8 persistence)
        ('35ED0E4A-4ACB-4072-B23A-10D5B5578FEA', 'vlad_spain',     @BanUntil_NEW,    'NEW'),    -- PS,    judge confidence 10/10 (W11 WATCH returning, prizes 5N -> 11N, defense CONCEDE)
        ('FF382A4E-F0C7-4DC4-A882-80F32276E095', 'TurboBandz6351', @BanUntil_NEW,    'NEW'),    -- Xbox,  judge confidence  9/10 (W11 WATCH returning, rule 9 > rule 6, defense CONCEDE)
        -- REPEAT - 4W -> 2026-08-24
        ('EB4273EE-EB6A-488F-8AC7-6C40809E1229', 'jackylu',        @BanUntil_REPEAT, 'REPEAT'); -- Steam, judge confidence  9/10 (prior ban lapsed 2026-07-10, back within 16 days, defense CONCEDE)

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
