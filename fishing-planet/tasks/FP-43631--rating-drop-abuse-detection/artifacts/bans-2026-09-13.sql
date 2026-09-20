-- FP-43631 week-19 ban -- surgical Profile ban of 7 reviewed rating-drop abusers (7 NEW)
-- ============================================================================
-- CHARGE WINDOW. The sweep week 2026-09-07..2026-09-13. Trajectory cards span fourteen days
-- (2026-08-31..2026-09-13), the whole retention of the Mongo tournamentLog; the extra week is
-- context for order and timing only and is not charged.
--
-- REVIEW. 12 candidates through a 36-agent run (prosecutor and defence in parallel, judge
-- sequential), Support-blind, on the corrected brief adopted after week-18 -- the standing defect
-- list is now carried into every hearing. Result: 6 BAN / 6 WATCH. The defence conceded outright in
-- 5 of the 6 convictions.
--
-- ORDER OF THE COHORT. Cases were dispatched in leaderboard order, not in screen order. The weekly
-- reward pays the top 10 by wins and a ban vacates the place, so the risk zone is top (10 + N) per
-- platform. Computed before the trial: the paying cutoff was 3 wins on all three platforms, and
-- only ZellyRolled (3rd of 2347 on Xbox, 6 wins) could reach a reward. Everyone else sat at 2 wins
-- or fewer with at most 1 competition still running, so none of the bans below is on a deadline.
--
-- The 6 in this script (judge confidence in parens):
--   NEW 4W -> 2026-10-12:
--     Steam (3): Pilou62 (9) -- the upper-bracket case. Plays 28 MIDDLES and cashes 5 there, so
--                              play and payoff share a bracket, but the ledger records a maximum of
--                              1211 inside the fourteen days: he has been in TOPS and is at 848.
--                              32 unproductive of 59 registrations cost -511 against +414 earned.
--                Mr.Twin (9) -- plays 10 NOOBS and 9 MIDDLES, cashes 4 NOOBS and nothing above.
--                              Note 2 of his downward boundary crossings were by PLAYING, not by
--                              absence, and the verdict accounts for that.
--                Suna4Y  (9) -- the steepest fall in the cohort: 29 unproductive of 48 at 60%,
--                              -407 against +259 earned, ends the window at rating 0. All 5 prizes
--                              taken in the bottom bracket; lifetime record is almost entirely this
--                              window.
--     PS    (2): AdmiralAckbar98 (8) -- 23 unproductive of 37 at 62%, net -71; plays 7 NOOBS and
--                              7 MIDDLES, cashes 3 NOOBS and 1 MIDDLES.
--                sidelong-beak10 (9) -- the heaviest zero-score case: 17 zero-score finishes across
--                              the ledger, 7 inside the charge week, against 16 no-shows. Entirely
--                              inside NOOBS, never above 79. Rule 9.
--     Xbox  (1): KovlekPlayz (9) -- **our week-18 WATCH returning**, and the first clean validation
--                              of the rules 4/8 ladder since rule 6 was rewritten. Prizes 5 -> 9,
--                              unproductive 8 -> 21, registrations 13 -> 32. Defence conceded.
--
-- OPERATOR OVERRIDE -- ZellyRolled (Xbox), the 7th row below.
--
-- The review returned WATCH at confidence 7. It did NOT find the pattern absent: the judge recorded
-- limb 1(b) as MET, found the rule 5 climb-and-cash signature present and verified it line by line
-- on the rating chain, and wrote that on the standing rules alone this is a ban configuration. He
-- released on rule 3 -- 9 competitions played against a threshold of 10 -- with the registration-
-- batch mechanism as secondary support.
--
-- The override is taken because rule 3 was applied to something it does not cover. The rule is
-- defined in this methodology as a claim about how much evidence exists, not about who the player
-- is, and the evidence here is abundant rather than thin: 28 registrations, 19 absences, and 5
-- upward crossings of the 100 line of which every single one is followed within 1 or 2 competitions
-- by shedding that puts him back underneath before his next contested event. He never plays while
-- above 100 -- 8 of his 9 starts were entered below the line, the 9th being the last of the week.
-- What is thin is only the count of competitions played, and the charge does not rest on how he
-- plays; it rests on where he cashes and how he arrives there, and 8 prizes from 9 starts settles
-- that. A leniency for "we cannot make out what is happening" has nothing to operate on in a case
-- the court itself described in full.
--
-- The week-12 leaderboard criterion is independently satisfied: 3rd of 2347 on the closing weekly
-- board with 6 wins, 7 of 8 prizes taken in the bottom bracket, reward run imminent.
--
-- Recorded plainly because this differs from week-18: there the override filled a gap left by a
-- defective brief and the re-hearing later confirmed it independently. Here the brief was sound and
-- the operator is disagreeing with a reasoned verdict. Rules 4 and 8 would have reached him next
-- cycle in any event -- he registered for 4 further competitions at 18:34 on the sweep day -- and 52
-- anti-cheat triggers in the same window are referred separately and form no part of this.
--
-- Run this same script on EACH platform PROD MAIN. Non-present UserIds simply don't join Profiles.
-- EXPECTED PROFILE UPDATES: Steam 3, PS 2, Xbox 2.
--
-- REBAN WHERE CLAUSE: mirrors canonical game-engine `ProfileLogic.IsCompetitionsBannedNow()`.
--
-- LEADERBOARD ban is intentionally NOT done here -- run leaderboard-ban-sync.sql afterwards, then
-- verify-bans-2026-09-13.sql, which checks the closing period 20260907 separately from the new one.
--
-- Atomic: SET XACT_ABORT ON auto-rolls-back on any error. After inspecting the verify SELECT,
-- run COMMIT TRAN (or ROLLBACK TRAN) at the bottom by hand.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW date          = '2026-10-12';   -- 4 weeks from Monday 2026-09-14
    DECLARE @Note         nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-09-14 - rating-drop abuse (week-19)';

    BEGIN TRAN;

    IF OBJECT_ID('tempdb..#BanCandidates') IS NOT NULL DROP TABLE #BanCandidates;
    CREATE TABLE #BanCandidates (
        UserId   uniqueidentifier PRIMARY KEY,
        Username varchar(64)      NOT NULL,
        BanUntil date             NOT NULL,
        Verdict  varchar(10)      NOT NULL
    );

    INSERT INTO #BanCandidates (UserId, Username, BanUntil, Verdict) VALUES
        ('952EED36-E6A1-40DD-ACD6-7BC8831500CB', 'Pilou62',         @BanUntil_NEW, 'NEW'),  -- Steam, conf 9/10 (reached 1211 in the ledger, sits at 848; -511 shed against +414 earned)
        ('0EF1A14C-25BC-4F84-B6BE-85EE73C8739F', 'Mr.Twin',         @BanUntil_NEW, 'NEW'),  -- Steam, conf 9/10 (plays across 2 brackets, cashes 4 of 4 in the lower one)
        ('D9D89E71-18D8-44E4-83B5-DAF07045FE14', 'Suna4Y',          @BanUntil_NEW, 'NEW'),  -- Steam, conf 9/10 (60% unproductive, -407, ends the window at 0)
        ('2018B861-7EBF-4D9E-AEF8-3656C6A21C22', 'AdmiralAckbar98', @BanUntil_NEW, 'NEW'),  -- PS,    conf 8/10 (62% unproductive, net -71, cashes below where he plays)
        ('CF9967A8-175F-42AC-A364-C9C658532B58', 'sidelong-beak10', @BanUntil_NEW, 'NEW'),  -- PS,    conf 9/10 (17 zero-score finishes; entirely inside NOOBS, rule 9)
        ('4E051EAE-C2A0-4473-AD49-67E48AAF0775', 'KovlekPlayz',     @BanUntil_NEW, 'NEW'),  -- Xbox,  conf 9/10 (week-18 WATCH returning; prizes 5 -> 9, unproductive 8 -> 21)
        ('87223C5F-5082-496F-88D4-507D31B540F5', 'ZellyRolled',     @BanUntil_NEW, 'NEW');  -- Xbox,  OPERATOR OVERRIDE of a WATCH (see header): 3rd on the weekly board, 5 of his 6 upward crossings of 100 shed back before the next contested event

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
