-- FP-43631 week-11 ban -- surgical Profile ban of 5 log-verified rating-drop abusers (4 NEW + 1 REPEAT)
-- ============================================================================
-- Hand-picked list: each UserId was confirmed via the Mongo Tournament-log trajectory analysis
-- on 2026-07-19 (see artifacts/bans-2026-07-19.md) AND passed a per-candidate adversarial trial
-- (prosecutor / defense / impartial-judge per case, run as a 60-agent workflow against 20
-- wide-cohort candidates).
--
-- Trial outcomes summary: 9 BAN + 11 WATCH + 0 EXONERATE. Of the 9 BAN verdicts, 4 are players
-- Support has ALREADY actioned this cycle (yevhen331 BanEnd 2026-08-18, sen1a 2026-08-17,
-- evgeniy3311 2026-08-02, Ricky27sampei 2026-08-02) -- not re-banned here; their Support ban
-- runs past our 2W standard. Recorded in the bans-2026-07-19.md as "Support pre-actioned,
-- trial-confirmed". Plus one Support-pre-actioned Trial-Support dissent (LZ23J7KS, Support 2W
-- BanEnd 2026-08-01 but trial WATCH under Rule 7 direction 2 -- TOP-flavor MASTERS sandbagger
-- family, not FP-43631 target -- **2nd Trial-Support dissent on rating-drop, alignment 32/34**).
--
-- Trial outcomes for the 5 in this script (judge confidence in parens):
--   NEW   2W -> 2026-08-03:
--     Steam (1): FoxMilard          (9,  4 climb-and-cash cycles, 4 MIDDLES->NOOBS drops, LB Rank 27 heavy grinder with NOOBS flavor-change)
--     PS    (2): CFC-T-W-T-32568    (10, textbook farmer profile, LB Rank 8, PCR 4, 6N pure NOOBS)
--                Chuydakid214       (8,  4 climb-then-flush cycles, 2 MIDDLES->NOOBS crossings, NOOBS-heavy end at PCR 88)
--     Xbox  (1): Belion019          (7,  4 Kacumi climb-and-cash cycles, 6 batched flushes, 1 M->N drop, 67% no-show. Note: 88 CHEAT triggers orthogonal to rating-drop, AntiCheat will catch separately)
--   REPEAT 4W -> 2026-08-17:
--     PS    (1): strullendorfer     (10, **our week-7 NEW 2W BanEnd 2026-07-06 expired, immediate recidivism 13d later**, Rule 1+4+5+8 stack, defense CONCEDE)
--
-- WATCH (11, structural reasons): Zemaro (Steam mixed 6N pure but small climb-and-flush weak signature), TTC-Squilliam
-- (Steam MIDDLES-heavy 16M played, mixed 3N+1M flavor), CHERTEN0K (Steam borderline novice Lifetime 6 + hybrid NS+ZeroScore),
-- n4rkos060905 (Steam novice threshold Lifetime 7, at 35% NoShow gate); DraVexTab (PS borderline Lifetime 15 mixed flavor),
-- La_Iena_River_ (PS 42 NS 84% extreme but TotalPrizes 6 < 10 novice-deference + single drain-then-climb not multi-cycle),
-- vlad_spain (PS novice Lifetime 6), Narco_KiNg (PS novice Lifetime 7), DiffenDaff (PS TOP-flavor MASTERS PCR 913, same family
-- as LZ23J7KS -- Rule 7 one-cycle clock), LZ23J7KS (PS **Support pre-actioned but trial WATCH under Rule 7 direction 2 --
-- 3rd cycle TOP-flavor unchanged, 2ND Trial-Support dissent on rating-drop**); TurboBandz6351 (Xbox novice Lifetime 5 +
-- ZeroScore pivot signature but terminal recovery-climb defeats climb-and-cash). Listed in bans-2026-07-19.md watchlist.
--
-- The five live on 3 platform PROD DBs. Run this same script on EACH:
--   [F2P] STEAM PROD  -> matches 1 (FoxMilard)
--   [F2P] PS    PROD  -> matches 3 (CFC-T-W-T-32568 + Chuydakid214 + strullendorfer)
--   [F2P] XB    PROD  -> matches 1 (Belion019)
-- Non-present UserIds simply don't join Profiles (verify SELECT flags them as not-found per DB).
--
-- REBAN WHERE CLAUSE: mirrors canonical game-engine `ProfileLogic.IsCompetitionsBannedNow()`.
--
-- LEADERBOARD ban is intentionally NOT done here -- run leaderboard-ban-sync.sql afterwards.
-- Standing rule: verify all three layers (Profiles / CompetitiveRatingsCurrent / banLog) per
-- platform individually -- see verify-bans-2026-07-19.sql.
--
-- Atomic: SET XACT_ABORT ON auto-rolls-back on any error. After inspecting the verify SELECT,
-- run COMMIT TRAN (or ROLLBACK TRAN) at the bottom by hand.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW    date          = '2026-08-03';   -- 2 weeks, Monday-aligned (first-time bans)
    DECLARE @BanUntil_REPEAT date          = '2026-08-17';   -- 4 weeks (recidivism)
    DECLARE @Note            nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-07-20 - rating-drop abuse (week-11)';

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
        -- NEW - 2W -> 2026-08-03
        ('313EEE9D-DA0C-42F0-9B1E-E4D0C2598766', 'FoxMilard',       @BanUntil_NEW,    'NEW'),    -- Steam, trial confidence  9/10 (heavy grinder LB Rank 27 with NOOBS flavor-change, 4 climb-and-cash cycles, 4 M->N drops)
        ('469DF796-D270-40FF-BAD9-8A5B9D83B6DC', 'CFC-T-W-T-32568', @BanUntil_NEW,    'NEW'),    -- PS,    trial confidence 10/10 (textbook farmer, LB Rank 8, PCR 4, 6N pure)
        ('CE09DA31-C3FC-4B21-915A-87EBA15367D9', 'Chuydakid214',    @BanUntil_NEW,    'NEW'),    -- PS,    trial confidence  8/10 (4 climb-then-flush cycles, 2 M->N crossings, mixed 4N+1M NOOBS-heavy end)
        ('FB67D3BC-E77D-4579-856A-F2DF8DC3CAA5', 'Belion019',       @BanUntil_NEW,    'NEW'),    -- Xbox,  trial confidence  7/10 (4 Kacumi cycles, 6 batched flushes, 67% no-show; 88 CHEAT triggers orthogonal)
        -- REPEAT - 4W -> 2026-08-17
        ('CC4044A9-0829-40E6-A6BA-D3222DBCE8D0', 'strullendorfer',  @BanUntil_REPEAT, 'REPEAT'); -- PS,    trial confidence 10/10 (our week-7 BAN expired 2026-07-06, immediate recidivism 13d later, defense CONCEDE)

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
