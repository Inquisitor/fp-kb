-- FP-43631 week-7 ban — surgical Profile ban of 17 log-verified rating-drop abusers (12 NEW + 5 REPEAT)
-- ============================================================================
-- Hand-picked list (NOT a HAVING-derived cohort): each UserId was confirmed via the Mongo
-- Tournament-log trajectory analysis on 2026-06-21 (see artifacts/bans-2026-06-21.md) AND passed
-- a per-candidate adversarial trial (prosecutor / defense / impartial-judge per case, run as a
-- 78-agent workflow against 26 wide-cohort candidates).
--
-- Trial outcomes summary: 21 BAN + 5 WATCH + 0 EXONERATE. Of the 21 BAN verdicts, 4 are players
-- Support has ALREADY actioned this cycle (Kacumi BanEnd 2026-07-20, poink 2026-07-17,
-- A-J-Rimmer-BSC 2026-07-05, nowa_zajawka 2026-07-21) -- not re-banned here; their Support ban
-- runs past our 2W standard, so the WHERE clause correctly skips them. Recorded in the
-- bans-2026-06-21.md as "Support pre-actioned, trial-confirmed".
--
-- Trial outcomes for the 17 in this script (judge confidence in parens):
--   NEW   2W -> 2026-07-06:
--     Steam (5): TF_B4ngwal (7), Ramboo051 (7), Audrey_HH (9), OZBULLDOG (8), VovaTemniy (8)
--     PS    (6): jorja09 (10), rabolio41100 (8, watchlist escalator week-6),
--                maminapokorny83 (9, watchlist escalator week-5), Neterrall (7),
--                Fat_tuna_mama (7), strullendorfer (8)
--     Xbox  (1): LEBOOGIEEEE (8)
--   REPEAT 4W -> 2026-07-20:
--     Steam (2): FurryCurrentMaster (8, our own week-4 ban expired EXACTLY 2026-06-15;
--                resumption immediate), Dokidepp (9)
--     PS    (2): Flo-GrayFOX (9), bostonbroncos24 (9)
--     Xbox  (1): BuzzingLemur417 (9)
--
-- WATCH (5, all PS, structural reasons): Matiamo_PL (mixed N+M, net +100), ST-9257 (TOP-flavor
-- PCR 943), TR-dennisfb (MASTERS sandbagging 1004->32), Tight_LinesJoe65 (MASTERS sandbagging),
-- TheFastestDevil (climbing-from-zero, weak signal). Listed in bans-2026-06-21.md watchlist.
--
-- The seventeen live on three platform PROD DBs. Run this same script on EACH:
--   [F2P] STEAM PROD  -> matches 7 (TF_B4ngwal + Ramboo051 + Audrey_HH + OZBULLDOG + VovaTemniy
--                                  + FurryCurrentMaster + Dokidepp)
--   [F2P] PS    PROD  -> matches 8 (jorja09 + rabolio41100 + maminapokorny83 + Neterrall
--                                  + Fat_tuna_mama + strullendorfer + Flo-GrayFOX + bostonbroncos24)
--   [F2P] XB    PROD  -> matches 2 (LEBOOGIEEEE + BuzzingLemur417)
-- Non-present UserIds simply don't join Profiles (verify SELECT flags them as not-found per DB).
--
-- REBAN WHERE CLAUSE UPDATED FROM WEEK-6 GOTCHA: now mirrors the canonical game-engine check
-- `ProfileLogic.IsCompetitionsBannedNow()` (AND of `IsCompetitionsBanned=true` AND
-- `BanEndDate > now`). The previous form missed stale-flag-with-NULL-date rows. New form covers
-- all cases where the player is NOT effectively banned at sweep time.
--
-- LEADERBOARD ban is intentionally NOT done here -- run leaderboard-ban-sync.sql afterwards.
-- Standing rule from week-3/4 incidents: after every cycle, verify all three layers (Profiles /
-- CompetitiveRatingsCurrent / banLog) per platform individually -- see verify-bans-2026-06-21.sql.
--
-- Atomic: SET XACT_ABORT ON auto-rolls-back on any error. After inspecting the verify SELECT,
-- run COMMIT TRAN (or ROLLBACK TRAN) at the bottom by hand.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW    date          = '2026-07-06';   -- 2 weeks, Monday-aligned (first-time bans)
    DECLARE @BanUntil_REPEAT date          = '2026-07-20';   -- 4 weeks (recidivism)
    DECLARE @Note            nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-06-22 - rating-drop abuse (week-7, adversarial-reviewed: prosecutor/defense/judge per case)';

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
        -- NEW - 2W -> 2026-07-06
        ('1030BC70-976F-4AE8-8464-5E73A4F5382D', 'TF_B4ngwal',          @BanUntil_NEW,    'NEW'),    -- Steam, trial confidence  7/10
        ('6218FFDE-5EAC-4566-BBA5-711422D44F57', 'Ramboo051',           @BanUntil_NEW,    'NEW'),    -- Steam, trial confidence  7/10
        ('3043CB8F-281B-47DF-BEC7-5CA722FA0394', 'Audrey_HH',           @BanUntil_NEW,    'NEW'),    -- Steam, trial confidence  9/10 (6-day no-show streak)
        ('45BB43B9-8690-43AE-AA4D-190515F4F2EC', 'OZBULLDOG',           @BanUntil_NEW,    'NEW'),    -- Steam, trial confidence  8/10
        ('D2E0BA0E-3AC5-42EC-A645-F8C66137F310', 'VovaTemniy',          @BanUntil_NEW,    'NEW'),    -- Steam, trial confidence  8/10
        ('C5D90E33-5022-4049-9960-C39A28B0D2A4', 'jorja09',             @BanUntil_NEW,    'NEW'),    -- PS,    trial confidence 10/10 (10 NOOBS prizes, 10 MIDDLES drops)
        ('B879AB80-43E5-455F-A045-B5A28480AF04', 'rabolio41100',        @BanUntil_NEW,    'NEW'),    -- PS,    trial confidence  8/10 (watchlist escalator week-6)
        ('E812002D-0618-48EB-ABAE-D88078A4C9F8', 'maminapokorny83',     @BanUntil_NEW,    'NEW'),    -- PS,    trial confidence  9/10 (watchlist escalator week-5)
        ('4277FB92-D6E9-4CA5-9940-EA77CB5DFA6C', 'Neterrall',           @BanUntil_NEW,    'NEW'),    -- PS,    trial confidence  7/10 (77% no-show)
        ('F6816FD8-9A24-424A-AA90-04B1FD4565E8', 'Fat_tuna_mama',       @BanUntil_NEW,    'NEW'),    -- PS,    trial confidence  7/10
        ('CC4044A9-0829-40E6-A6BA-D3222DBCE8D0', 'strullendorfer',      @BanUntil_NEW,    'NEW'),    -- PS,    trial confidence  8/10
        ('1ABB20A3-8696-4737-A0C4-5620A8A374DF', 'LEBOOGIEEEE',         @BanUntil_NEW,    'NEW'),    -- Xbox,  trial confidence  8/10 (48 no-shows, highest)
        -- REPEAT - 4W -> 2026-07-20
        ('09DAA0C8-856A-4328-8001-9CC1B2683FAB', 'FurryCurrentMaster',  @BanUntil_REPEAT, 'REPEAT'), -- Steam, trial confidence  8/10 (our own week-4 ban expired 2026-06-15)
        ('37FE52EC-F9D1-4439-9DDD-2C38982C66C3', 'Dokidepp',            @BanUntil_REPEAT, 'REPEAT'), -- Steam, trial confidence  9/10
        ('76B5F7F3-346A-46B1-9C70-4FE0743572C3', 'Flo-GrayFOX',         @BanUntil_REPEAT, 'REPEAT'), -- PS,    trial confidence  9/10
        ('5DB0A328-1307-4762-A1DB-7FF34E63BFE5', 'bostonbroncos24',     @BanUntil_REPEAT, 'REPEAT'), -- PS,    trial confidence  9/10
        ('013368D1-E8A8-437A-88B0-71059E3287EB', 'BuzzingLemur417',     @BanUntil_REPEAT, 'REPEAT'); -- Xbox,  trial confidence  9/10

    -- Step 2: Profile ban (durable). Allows re-ban when player is NOT effectively banned at
    -- sweep time. WHERE clause mirrors canonical game-engine `IsCompetitionsBannedNow()` check
    -- (AND of `IsCompetitionsBanned=true` AND `BanEndDate > now`). The negation `NOT (...)`
    -- correctly handles all not-banned states including stale-flag-with-NULL-date rows.
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
