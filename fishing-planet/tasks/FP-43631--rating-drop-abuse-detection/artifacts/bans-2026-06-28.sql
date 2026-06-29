-- FP-43631 week-8 ban — surgical Profile ban of 15 log-verified rating-drop abusers (14 NEW + 1 REPEAT)
-- ============================================================================
-- Hand-picked list (NOT a HAVING-derived cohort): each UserId was confirmed via the Mongo
-- Tournament-log trajectory analysis on 2026-06-28 (see artifacts/bans-2026-06-28.md) AND passed
-- a per-candidate adversarial trial (prosecutor / defense / impartial-judge per case, run as a
-- 72-agent workflow against 24 wide-cohort candidates).
--
-- Trial outcomes summary: 15 BAN + 2 BAN-already-pre-actioned-by-Support + 7 WATCH + 0 EXONERATE.
-- The 2 Support-pre-actioned players (Adlerblut-Slayer BanEnd 2026-07-28, TR-dennisfb 2026-07-23)
-- were trial-confirmed BAN at conf 10/10 but are NOT included here -- their Support bans run past
-- our 2W standard, so the WHERE clause correctly skips them. Recorded in the bans-2026-06-28.md
-- as "Support pre-actioned, trial-confirmed".
--
-- Trial outcomes for the 15 in this script (judge confidence in parens):
--   NEW   2W -> 2026-07-13:
--     Steam (5): ArmlessFisherMan (7), BB_Anastasia (8), MonsterFish_fuark (8, watchlist escalator week-6),
--                angeperdu (7), krolikusik (8)
--     PS    (8): Matiamo_PL (9, watchlist escalator week-7), tigrou_le_boss42 (7), M4R5H_57_ (8),
--                Epic70cosmin (9), MrChadRico (8), MONSTER-VERT1325 (9), TR-BILECIKLI_CMR (8), kokoljj (9)
--     Xbox  (1): Smooter85 (9, 135.8h no-show streak longest of cohort)
--   REPEAT 4W -> 2026-07-27:
--     PS    (1): IKIGAI__1__ (10, prior ban expired 2026-06-17, returned 11 days later)
--
-- WATCH (7, structural reasons): VM_Vigor (Steam TOP-flavor, week-6 returning), KingYakO2 (Steam
-- novice profile, sample-size deference), ST-9257 (PS TOP-flavor, week-7 returning),
-- Ttv_s4muka019 (PS TOP-flavor, week-6 returning), LZ23J7KS (PS MASTERS-sandbagging within bracket,
-- no NOOBS crossings), serber-denis85 (PS MIDDLES-only veteran), BarNoneD (Xbox ascending-peak
-- climber, not closed-cycle). Listed in bans-2026-06-28.md watchlist.
--
-- The fifteen live on three platform PROD DBs. Run this same script on EACH:
--   [F2P] STEAM PROD  -> matches 5 (ArmlessFisherMan + BB_Anastasia + MonsterFish_fuark
--                                  + angeperdu + krolikusik)
--   [F2P] PS    PROD  -> matches 9 (Matiamo_PL + tigrou_le_boss42 + M4R5H_57_ + Epic70cosmin
--                                  + MrChadRico + MONSTER-VERT1325 + TR-BILECIKLI_CMR + kokoljj
--                                  + IKIGAI__1__ REPEAT)
--   [F2P] XB    PROD  -> matches 1 (Smooter85)
-- Non-present UserIds simply don't join Profiles (verify SELECT flags them as not-found per DB).
--
-- REBAN WHERE CLAUSE: mirrors canonical game-engine `ProfileLogic.IsCompetitionsBannedNow()`
-- (AND of `IsCompetitionsBanned=true` AND `BanEndDate > now`). Covers all cases where the player
-- is NOT effectively banned at sweep time, including stale-flag-with-NULL-date rows.
--
-- LEADERBOARD ban is intentionally NOT done here -- run leaderboard-ban-sync.sql afterwards.
-- Standing rule from week-3/4 incidents: after every cycle, verify all three layers (Profiles /
-- CompetitiveRatingsCurrent / banLog) per platform individually -- see verify-bans-2026-06-28.sql.
--
-- Atomic: SET XACT_ABORT ON auto-rolls-back on any error. After inspecting the verify SELECT,
-- run COMMIT TRAN (or ROLLBACK TRAN) at the bottom by hand.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW    date          = '2026-07-13';   -- 2 weeks, Monday-aligned (first-time bans)
    DECLARE @BanUntil_REPEAT date          = '2026-07-27';   -- 4 weeks (recidivism)
    DECLARE @Note            nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-06-29 - rating-drop abuse (week-8, adversarial-reviewed: prosecutor/defense/judge per case)';

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
        -- NEW - 2W -> 2026-07-13
        ('C434AFC9-875D-4ECE-8EFA-FE7810C6DAFF', 'ArmlessFisherMan',   @BanUntil_NEW,    'NEW'),    -- Steam, trial confidence  7/10
        ('883362EF-98A6-4406-B2DC-9636E1D022FC', 'BB_Anastasia',       @BanUntil_NEW,    'NEW'),    -- Steam, trial confidence  8/10 (74 regs highest volume)
        ('222BBE9D-3557-4280-B854-CBEF2AE48707', 'MonsterFish_fuark',  @BanUntil_NEW,    'NEW'),    -- Steam, trial confidence  8/10 (watchlist escalator week-6)
        ('4CF530BA-2330-4DC0-BB8B-C03A55176EFC', 'angeperdu',          @BanUntil_NEW,    'NEW'),    -- Steam, trial confidence  7/10 (was week-5 borderline WATCH)
        ('683D0D32-290E-4726-BFE9-AD16A0234324', 'krolikusik',         @BanUntil_NEW,    'NEW'),    -- Steam, trial confidence  8/10
        ('C5A87A36-E9A3-44C6-B69A-CB08ADBEAEDA', 'Matiamo_PL',         @BanUntil_NEW,    'NEW'),    -- PS,    trial confidence  9/10 (watchlist escalator week-7, 13 MIDDLES drops)
        ('46E9E18F-0E49-4F9E-B91C-B074823CF02B', 'tigrou_le_boss42',   @BanUntil_NEW,    'NEW'),    -- PS,    trial confidence  7/10
        ('56ED8774-68B1-49B2-B395-E594DBE4B766', 'M4R5H_57_',          @BanUntil_NEW,    'NEW'),    -- PS,    trial confidence  8/10 (79% no-show extreme)
        ('CBF68606-DF2C-46B3-8086-E76B7019C1D1', 'Epic70cosmin',       @BanUntil_NEW,    'NEW'),    -- PS,    trial confidence  9/10 (72% no-show)
        ('D1320268-0463-4289-A455-24BAB60B2363', 'MrChadRico',         @BanUntil_NEW,    'NEW'),    -- PS,    trial confidence  8/10
        ('EE558D4F-7515-4B5F-B0FD-4C1F47319C3A', 'MONSTER-VERT1325',   @BanUntil_NEW,    'NEW'),    -- PS,    trial confidence  9/10
        ('330F8B15-1FC5-49DC-9829-8B710B04F80F', 'TR-BILECIKLI_CMR',   @BanUntil_NEW,    'NEW'),    -- PS,    trial confidence  8/10
        ('882BB61A-9F03-4706-B58E-AA9A279E303B', 'kokoljj',            @BanUntil_NEW,    'NEW'),    -- PS,    trial confidence  9/10
        ('F25A97B7-FDEF-4C1C-B50A-0D0A117745D4', 'Smooter85',          @BanUntil_NEW,    'NEW'),    -- Xbox,  trial confidence  9/10 (135.8h streak longest)
        -- REPEAT - 4W -> 2026-07-27
        ('06BB9D34-BC04-4591-80F6-0F8AD8F05087', 'IKIGAI__1__',        @BanUntil_REPEAT, 'REPEAT'); -- PS,    trial confidence 10/10 (prior ban expired 2026-06-17)

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
