-- FP-43631 week-20 -- competition bans, SECOND PACK: the 2 convicted out of the remainder
-- ============================================================================
-- ONE block. Run it unchanged on each platform PROD MAIN (Steam / PS). The join matches only the
-- candidates that exist on that database, so the other platform's row comes back with
-- FoundUser = NULL -- which is also the cross-check that the platform split is what we think.
--
-- These two were not in the payout-deadline subset and were reviewed after it, by reading the
-- trajectory directly rather than by tribunal. Each was tested against three competing
-- explanations before the conclusion -- schedule (no-show rate by hour of competition start),
-- rating management (no-show rate by rating at registration), and tilt (place in the last played
-- competition before each event) -- and in both cases only the rating explanation survives.
--
--   Bas_di08 (PS). Band 951..1050 for the whole fortnight, straddling the MIDDLES/TOPS line at
--     1001. Six excursions above the line and six returns, every one of them gated by a no-show:
--     1027->1007, 1021->1006, 1011->1001, 1050->1030->1017->997, 1034->1014->994,
--     1040->1020->997. Never stays above for more than two or three entries. Net -11 over
--     fourteen days -- flat, which is what holding a position looks like. 23 no-shows of 48
--     events, almost all at the maximum -20. All 4 prizes taken in MIDDLES while the
--     counterfactual ceiling sits well inside TOPS.
--
--   Iron.Claw (Steam). No schedule at all -- misses spread across every hour of the day, 46%
--     overall. The rating gradient therefore has nothing to hide behind and it survives: 33% of
--     registrations made below 50 lapse, 50% between 51 and 100, 60% above 100. He entered a
--     competition above 100 exactly FOUR times in fourteen days, took no prize and averaged 20th;
--     below 100 he played 20 and took 5 prizes at an average of 9.8. On 09-20 the reward for a
--     won slot landed at 06:19 and at 06:22 -- three minutes later, demonstrably at the console --
--     he registered for three more at rating 105 and attended none. Zero unregistrations in 48
--     participations, though cancelling is free and refunds the fee.
--
-- Both NEW by our own ban history -> 4 weeks. BanUntil 2026-10-19, the same date as the first
-- pack: the tariff is anchored to the sweep week, not to the hour the operator got to the case.
--
-- PAYOUT: the weekly period closed before these were decided, so neither loses a weekly prize --
-- Bas_di08 was outside the paying ten on the Won board in any case. Layer 2 still matters and must
-- follow: the MONTHLY (20260901) and YEARLY (20260101) periods are still open, and the shared
-- `leaderboard-ban-sync.sql` flags those rows too.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW date          = '2026-10-19';   -- 4 weeks from Monday 2026-09-21
    DECLARE @Note         nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-09-21 - rating-drop abuse (week-20)';

    BEGIN TRAN;

    IF OBJECT_ID('tempdb..#BanCandidates') IS NOT NULL DROP TABLE #BanCandidates;
    CREATE TABLE #BanCandidates (
        UserId   uniqueidentifier PRIMARY KEY,
        Username varchar(64)      NOT NULL,
        BanUntil date             NOT NULL,
        Verdict  varchar(10)      NOT NULL
    );

    INSERT INTO #BanCandidates (UserId, Username, BanUntil, Verdict) VALUES
        ('54EA8084-5546-4EA8-8068-4C1FDBE77D4A', 'Bas_di08',  @BanUntil_NEW, 'NEW'),  -- PS,    holds station on the 1001 line for a fortnight; 6 excursions above, 6 no-show returns; net -11; all 4 prizes in MIDDLES
        ('6B94E751-0D2F-40B0-81EA-FB7C9DA0FD14', 'Iron.Claw', @BanUntil_NEW, 'NEW');  -- Steam, no schedule to explain it; 4 entries above 100 in 14 days and 0 prizes there; registered 3 slots at rating 105 three minutes after seeing himself cross, attended none

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
END;
-- On Steam expect 1 banned row (Iron.Claw) and 1 with FoundUser NULL.
-- On PS    expect 1 banned row (Bas_di08)  and 1 with FoundUser NULL.
-- Expected must equal FoundUser on every non-NULL row.
-- COMMIT;
-- or ROLLBACK;
