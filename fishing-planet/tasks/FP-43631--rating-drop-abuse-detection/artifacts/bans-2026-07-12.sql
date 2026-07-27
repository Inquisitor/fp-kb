-- FP-43631 week-10 ban -- surgical Profile ban of 4 log-verified rating-drop abusers (2 NEW + 2 REPEAT)
-- ============================================================================
-- Hand-picked list: each UserId was confirmed via the Mongo Tournament-log trajectory analysis
-- on 2026-07-12 (see artifacts/bans-2026-07-12.md) AND passed a per-candidate adversarial trial
-- (prosecutor / defense / impartial-judge per case, run as a 57-agent workflow against 12
-- wide-cohort candidates).
--
-- Trial outcomes summary: 9 BAN + 10 WATCH + 0 EXONERATE. Of the 9 BAN verdicts, 5 are players
-- Support has ALREADY actioned this cycle (JFF_Gothyka BanEnd 2026-08-12, CreekSamurai
-- 2026-07-26, MLG720YOLO 2026-08-11, Da Sneaky Snake 2026-08-11, CraddiePoosta 2026-08-11) --
-- not re-banned here; their Support ban runs past our 2W standard. Recorded in the
-- bans-2026-07-12.md as "Support pre-actioned, trial-confirmed".
--
-- Trial outcomes for the 4 in this script (judge confidence in parens):
--   NEW   2W -> 2026-07-27:
--     Steam (1): Captain_Djack_Sparrow (8, PCR 218 -> 62, 3 MIDDLES->NOOBS drops)
--     Xbox  (1): alphaBiTsoop16 (8, 79% no-show, PCR 54 -> 0, 3 MIDDLES->NOOBS drops)
--   REPEAT 4W -> 2026-08-10:
--     Steam (1): LaccFarro (10, **our own week-6 BAN expired 2026-06-29, recidivism within days**;
--                Support also 5W-banned him post-sweep at 2026-08-12 but our 4W ban goes durably
--                on our own record)
--     PS    (1): Miron_33 (7, **sink-comp repeat targeting -- Akula #372479/#372516 and Labirint
--                #372504/#372587 each NO-SHOWed twice**, 5 MIDDLES->NOOBS drops, 4 climb-then-flush cycles)
--
-- WATCH (10, structural reasons): JIALIN0720 (Steam TOP-flavor MIDDLES-veteran family from w5/w6),
-- MORPH3US (Steam novice + recovery-climb + inverted farming economics RFNS>RFRP), wesleytorres1
-- (Steam novice + peaked PCR 151 breaking farmer-cap-at-100), TrcikLowFiv (Steam REPEAT-stale
-- TOP-flavor +322 climb), X1aoDouYa (Steam REPEAT-stale TOP-flavor +294 climb), sandaljepitt
-- (Steam Support-pre-actioned but for CHEAT vector not rating-drop -- orthogonal-vector case,
-- trial WATCH on rating-drop grounds under rule 6 novice-deference), evgeniy3311 (PS novice
-- threshold), Bas_di08 (PS TOP-flavor MASTERS), Adrian_Yaj08 (PS small sample + 1 TOPS prize),
-- Sir Mijael (Xbox novice + net +121 climb recovery pattern). Listed in bans-2026-07-12.md
-- watchlist.
--
-- The four live on 3 platform PROD DBs. Run this same script on EACH:
--   [F2P] STEAM PROD  -> matches 2 (Captain_Djack_Sparrow + LaccFarro)
--   [F2P] PS    PROD  -> matches 1 (Miron_33)
--   [F2P] XB    PROD  -> matches 1 (alphaBiTsoop16)
-- Non-present UserIds simply don't join Profiles (verify SELECT flags them as not-found per DB).
--
-- REBAN WHERE CLAUSE: mirrors canonical game-engine `ProfileLogic.IsCompetitionsBannedNow()`.
--
-- LEADERBOARD ban is intentionally NOT done here -- run leaderboard-ban-sync.sql afterwards.
-- Standing rule: verify all three layers (Profiles / CompetitiveRatingsCurrent / banLog) per
-- platform individually -- see verify-bans-2026-07-12.sql.
--
-- Atomic: SET XACT_ABORT ON auto-rolls-back on any error. After inspecting the verify SELECT,
-- run COMMIT TRAN (or ROLLBACK TRAN) at the bottom by hand.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW    date          = '2026-07-27';   -- 2 weeks, Monday-aligned (first-time bans)
    DECLARE @BanUntil_REPEAT date          = '2026-08-10';   -- 4 weeks (recidivism)
    DECLARE @Note            nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-07-13 - rating-drop abuse (week-10)';

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
        -- NEW - 2W -> 2026-07-27
        ('17999A3E-1BAB-479A-B4DE-374EB48FF867', 'Captain_Djack_Sparrow', @BanUntil_NEW,    'NEW'),    -- Steam, trial confidence  8/10 (mixed 5N+1M, 3 MIDDLES->NOOBS drops)
        ('6572E942-F8A7-4F7B-915E-007F21D6E81C', 'alphaBiTsoop16',        @BanUntil_NEW,    'NEW'),    -- Xbox,  trial confidence  8/10 (79% no-show extreme, PCR 54 -> 0 collapse)
        -- REPEAT - 4W -> 2026-08-10
        ('47FEE9FA-C9E6-4DBE-8742-63B56558D890', 'LaccFarro',             @BanUntil_REPEAT, 'REPEAT'), -- Steam, trial confidence 10/10 (our week-6 BAN expired 2026-06-29, immediate recidivism)
        ('1F0B293C-2A06-45CC-BBC5-9B0D0715728F', 'Miron_33',              @BanUntil_REPEAT, 'REPEAT'); -- PS,    trial confidence  7/10 (sink-comp repeat targeting, 5 MIDDLES->NOOBS drops)

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
