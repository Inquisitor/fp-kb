-- FP-43631 week-18 -- OPERATOR OVERRIDE of two WATCH verdicts (2 NEW)
-- ============================================================================
-- BASIS. Week-12 precedent (dreadloc): an operator may override a WATCH where the player stands in
-- the platform weekly Won leaderboard top-10 AND the extraction is bottom-bracket flavoured. The
-- rationale recorded then applies unchanged -- the top of the leaderboard is where prizes are
-- actually taken, so deferring on a player who has converted a suppressed rating into rewards
-- defers past the payout, and the deferral cannot be undone afterwards.
--
-- WHY THESE TWO AND NOT THE OTHER FOUR IN THE TOP FIFTEEN. Closing weekly period 20260831,
-- ranked by wins:
--   seagate22022   Steam  rank 2 of 2969, 7 wins, 10 of 11 prizes taken at rating <= 100
--   o Lord Mac o   Xbox   rank 3 of 2334, 4 wins, 4 of 4 prizes in the bottom bracket
--   LuizFernandoo  Steam  rank 7  -- mixed prize flavour, criterion not met
--   trumcautrom    Steam  rank 9  -- mixed prize flavour, criterion not met
--   Myky0576       Steam  rank 9  -- borderline (3 of 4 in the bottom bracket), left to the review
--   Ilija1982      Steam  rank 15 -- outside the top ten, criterion not met
--
-- WHAT THE REVIEW ACTUALLY HELD ON THESE TWO. Neither was exonerated. In both cases limb 1(b) --
-- prizes taken a bracket below where the player's own results place him -- was expressly found MET,
-- and rule 6 was applied as aggravating at its maximum (o Lord Mac o's entire lifetime prize record
-- was earned inside the charged week; seagate22022's in-window haul is 52.4% of his lifetime and 7
-- of his 8 lifetime golds). Both were held only because limb 1(a)'s temporal-order requirement was
-- not made out on the brief the first hearing was given -- a brief that omitted the standing week-12
-- finding that a same-second ledger group is a flush moment rather than evidence of presence, so the
-- prosecution built its sequence case on precisely the artifact the judges then struck down. That
-- omission was ours, not a fact about these players.
--
-- SCOPE. This does not reopen a conviction and does not pre-empt the re-hearing: the re-hearing runs
-- on a corrected brief and may reach the same two independently. If it returns WATCH for either of
-- them on the corrected brief, that is a signal worth recording in the cycle notes -- the override
-- stands on the leaderboard criterion, not on a prediction of the verdict.
--
-- Tariff: both NEW, 4 weeks from Monday 2026-09-07 -> 2026-10-05.
--
-- Run on Steam PROD MAIN and Xbox PROD MAIN. Neither UserId exists on the other platforms.
-- Afterwards re-run leaderboard-ban-sync.sql on both, and COMMIT it separately.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW date          = '2026-10-05';
    DECLARE @Note         nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-09-07 - rating-drop abuse (week-18)';

    BEGIN TRAN;

    IF OBJECT_ID('tempdb..#BanCandidates') IS NOT NULL DROP TABLE #BanCandidates;
    CREATE TABLE #BanCandidates (
        UserId   uniqueidentifier PRIMARY KEY,
        Username varchar(64)      NOT NULL,
        BanUntil date             NOT NULL,
        Verdict  varchar(10)      NOT NULL
    );

    INSERT INTO #BanCandidates (UserId, Username, BanUntil, Verdict) VALUES
        ('267A4A3D-0A1D-456C-B766-6FC1891F0C26', 'seagate22022', @BanUntil_NEW, 'NEW'),  -- Steam, weekly rank 2 of 2969, 7 wins, 10 of 11 prizes at rating <= 100
        ('1C653428-2C77-4F8E-8194-422AA3D63C8F', 'o Lord Mac o', @BanUntil_NEW, 'NEW');  -- Xbox,  weekly rank 3 of 2334, 4 wins, all 4 prizes in the bottom bracket, ends the window at 0

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
