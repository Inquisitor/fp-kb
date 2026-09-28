-- FP-43631 week-21 -- competition bans, SECOND PACK: 5 of the 9 candidates outside the money
-- ============================================================================
-- ONE block. Run it unchanged on each platform PROD MAIN (Steam / PS / Xbox). The join matches
-- only the candidates that exist on that database, so the other platforms' rows come back with
-- FoundUser = NULL -- which is also the cross-check that the platform split is what we think.
--
-- Same cycle, same tariff and note as bans-2026-09-27.sql (the deadline pack). Decided after the
-- payout, one candidate at a time with the operator, from the rebuilt cards in
-- pcr-log-trajectories-2026-09-27/; decisions and grounds in _verdicts.md there.
--
--   ShrekUndies      PS    NEW     23 registrations, 9 played, 13 no-shows, net -39 from 132; SIX boundary
--                                  crossings down in the week, a podium after five of them; 4 of 5 prizes in
--                                  NOOBS against a ceiling of 293; half the sheds made while in the game;
--                                  registers the next slots right after a podium
--   UlfsonUlfstroem  Xbox  REPEAT  17 registrations, 5 played, 11 no-shows; 4 prizes in 5 games, all NOOBS;
--                                  4 crossings down, each after a podium; on 09-21 four skips in a row while
--                                  in the game right after a 2nd place; prior competition ban lapsed
--   BoraxHook        Xbox  NEW     19 registrations, 7 played, 12 no-shows; 6 prizes in 7 games, all NOOBS;
--                                  never above 89 in the week -- the within-bracket shape, all four gates;
--                                  registers 18:00-04:00 slots right after each prize and never attends them
--   DCUK420          Steam NEW     (was BurnsTroutFishery at screen time) 22 registrations, 5 played, 17
--                                  no-shows at 77%, net -71; 3 crossings down; 4 prizes in 5 games, three in
--                                  NOOBS and one at 101; batch-registers night slots after each prize
--   christdu7340     PS    NEW     24 registrations, 12 played, 12 no-shows, net +77 rising but 2-3 crossings
--                                  down; 5 prizes in 12 games, all NOOBS, against a ceiling of 263; three
--                                  skips of 120 min in the game bracketing the podiums of 09-26 and 09-27
--
--   WATCH, not applied: mregan52 (PS, thin and at every screen threshold, no batches),
--   NotTheTheFace (Steam, high-PCR shape under 1001, rule 7 clock), silvery_harvest8 (PS, plays and
--   cashes in MIDDLES with a MIDDLES ceiling). BuzzingLemur417 (Xbox) is under a Support ban to
--   2026-11-25 and is left alone, no banLog entry by the operator's decision.
--
-- Tariff 4W NEW / 8W REPEAT from the Monday following the sweep (2026-09-28), unchanged for this
-- cycle; calendar months (one / two) apply from week-22 so a ban cannot lapse before the end of the
-- month of the offence.
--
-- The closing weekly period 20260921 is already finalised and cleaned up; the shared
-- `leaderboard-ban-sync.sql` reaches the still-open monthly 20260901 and yearly 20260101 rows, and
-- the new week 20260928 where a row exists. Monthly exclusion is the reason this pack does not wait
-- for the next cycle: September finalises at 2026-10-01 00:07Z.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW    date          = '2026-10-26';   -- 4 weeks from Monday 2026-09-28
    DECLARE @BanUntil_REPEAT date          = '2026-11-23';   -- 8 weeks from Monday 2026-09-28
    DECLARE @Note            nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-09-28 - rating-drop abuse (week-21)';

    BEGIN TRAN;

    IF OBJECT_ID('tempdb..#BanCandidates') IS NOT NULL DROP TABLE #BanCandidates;
    CREATE TABLE #BanCandidates (
        UserId   uniqueidentifier PRIMARY KEY,
        Username varchar(64)      NOT NULL,
        BanUntil date             NOT NULL,
        Verdict  varchar(10)      NOT NULL
    );

    INSERT INTO #BanCandidates (UserId, Username, BanUntil, Verdict) VALUES
        ('3EDA1A94-2DA6-45B4-A837-465773F5291A', 'DCUK420',         @BanUntil_NEW,    'NEW'),     -- Steam
        ('23AD555B-A45C-47AC-AB4A-A469D7DDBE5E', 'ShrekUndies',     @BanUntil_NEW,    'NEW'),     -- PS
        ('EBB52E2F-E4ED-42A9-9711-E55FACB1668C', 'christdu7340',    @BanUntil_NEW,    'NEW'),     -- PS
        ('C6440075-C23C-4B02-80AD-FE1F5FF9B25E', 'UlfsonUlfstroem', @BanUntil_REPEAT, 'REPEAT'),  -- Xbox
        ('7E4889A6-8E26-4EB8-97B5-3C67AD6C423D', 'BoraxHook',       @BanUntil_NEW,    'NEW');     -- Xbox

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
-- On Steam expect 1 banned row  (DCUK420) and 4 with FoundUser NULL.
-- On PS    expect 2 banned rows (ShrekUndies, christdu7340) and 3 with FoundUser NULL.
-- On Xbox  expect 2 banned rows (BoraxHook until 2026-10-26; UlfsonUlfstroem until 2026-11-23) and 3 with FoundUser NULL.
-- Expected must equal FoundUser on every non-NULL row.
-- COMMIT;
-- or ROLLBACK;
