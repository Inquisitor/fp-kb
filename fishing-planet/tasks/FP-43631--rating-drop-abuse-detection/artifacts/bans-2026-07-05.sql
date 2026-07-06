-- FP-43631 week-9 ban -- surgical Profile ban of 6 log-verified rating-drop abusers (6 NEW + 0 REPEAT)
-- ============================================================================
-- Hand-picked list (NOT a HAVING-derived cohort): each UserId was confirmed via the Mongo
-- Tournament-log trajectory analysis on 2026-07-05 (see artifacts/bans-2026-07-05.md) AND passed
-- a per-candidate adversarial trial (prosecutor / defense / impartial-judge per case, run as a
-- 36-agent workflow against 12 wide-cohort candidates).
--
-- Trial outcomes summary: 8 BAN + 4 WATCH + 0 EXONERATE. Of the 8 BAN verdicts, 2 are players
-- Support has ALREADY actioned this cycle (ArTeM209 BanEnd 2026-08-04, Gustyn112 2026-08-05) --
-- not re-banned here; their Support ban runs past our 2W standard, so the WHERE clause correctly
-- skips them. Recorded in the bans-2026-07-05.md as "Support pre-actioned, trial-confirmed".
--
-- Trial outcomes for the 6 in this script (judge confidence in parens):
--   NEW   2W -> 2026-07-20:
--     Steam (3): Ti_To (10, PCR 668->38 = -630 largest collapse), H.a.r.y44 (9, veteran flavor
--                change with 10 MIDDLES->NOOBS drops highest in cohort), IaMiya (7, small sample)
--     PS    (3): EL-_-Diablo-_-51 (9, 7 MIDDLES->NOOBS drops with net-positive Kacumi refinement
--                fires), San-miculsan (8), kevynrdm13 (7, borderline mixed)
--
-- WATCH (4, structural reasons): VM_Vigor (Steam 3rd-cycle returning TOP-flavor persists week-6
-- WATCH + week-8 WATCH + week-9 WATCH -- 0 NOOBS prizes and 0 MIDDLES->NOOBS drops in 3 weeks),
-- Panonski_Alas (PS stale-flag REPEAT MASTERS-flavor PCR 1025 climbing, 0 drops), CreekSamurai
-- (Steam novice-deference rule 6: lifetime 10 borderline + recovery climb + one-cycle clock for
-- week-10), FarantirPL (Steam novice-deference rule 6: same profile, recovery climb argument
-- accepted). Listed in bans-2026-07-05.md watchlist.
--
-- The six live on 2 platform PROD DBs. Run this same script on EACH:
--   [F2P] STEAM PROD  -> matches 3 (Ti_To + H.a.r.y44 + IaMiya)
--   [F2P] PS    PROD  -> matches 3 (EL-_-Diablo-_-51 + San-miculsan + kevynrdm13)
-- Xbox cohort empty this week -- Xbox PROD MAIN skipped.
-- Non-present UserIds simply don't join Profiles (verify SELECT flags them as not-found per DB).
--
-- REBAN WHERE CLAUSE: mirrors canonical game-engine `ProfileLogic.IsCompetitionsBannedNow()`
-- (AND of `IsCompetitionsBanned=true` AND `BanEndDate > now`).
--
-- LEADERBOARD ban is intentionally NOT done here -- run leaderboard-ban-sync.sql afterwards.
-- Standing rule: verify all three layers (Profiles / CompetitiveRatingsCurrent / banLog) per
-- platform individually -- see verify-bans-2026-07-05.sql.
--
-- Atomic: SET XACT_ABORT ON auto-rolls-back on any error. After inspecting the verify SELECT,
-- run COMMIT TRAN (or ROLLBACK TRAN) at the bottom by hand.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW    date          = '2026-07-20';   -- 2 weeks, Monday-aligned (first-time bans)
    DECLARE @Note            nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-07-06 - rating-drop abuse (week-9, adversarial-reviewed: prosecutor/defense/judge per case)';

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
        -- NEW - 2W -> 2026-07-20
        ('E0A2F28A-F5BE-4A5C-9898-43F2C093DBB1', 'Ti_To',              @BanUntil_NEW, 'NEW'),    -- Steam, trial confidence 10/10 (PCR 668->38 = -630, 76 NO-SHOWs, 18 batched flushes)
        ('E98D05D2-4E6F-45BC-8421-9ED08CDCE54E', 'H.a.r.y44',          @BanUntil_NEW, 'NEW'),    -- Steam, trial confidence  9/10 (veteran 178 lifetime with flavor change, 10 MIDDLES->NOOBS drops highest)
        ('53E1B654-48BD-413C-AE77-6E58C39CFC14', 'IaMiya',             @BanUntil_NEW, 'NEW'),    -- Steam, trial confidence  7/10
        ('5C5B4305-BC67-403E-A013-640E396F1A9F', 'EL-_-Diablo-_-51',   @BanUntil_NEW, 'NEW'),    -- PS,    trial confidence  9/10 (Kacumi refinement fires -- net-positive with climb-then-flush)
        ('EEA41D0D-3987-403F-A479-F2F8EFE326D7', 'San-miculsan',       @BanUntil_NEW, 'NEW'),    -- PS,    trial confidence  8/10
        ('E28DD543-32FF-449F-8A0F-02AF1C615D38', 'kevynrdm13',         @BanUntil_NEW, 'NEW');    -- PS,    trial confidence  7/10

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
