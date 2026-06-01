-- FP-43631 week-4 ban — surgical Profile ban of 5 log-verified rating-drop abusers
-- ============================================================================
-- Hand-picked list (NOT a HAVING-derived cohort): each UserId was confirmed via the Mongo
-- Tournament-log no-show labelling on 2026-05-31 (see artifacts/bans-2026-05-31.md):
-- strong play (+251..+448 RFRP, multiple +25..+55 wins) deliberately offset by 57-67% no-show
-- batches that pin PCR in the NOOBS / low-MIDDLES bracket where they cash 5-12 prizes per week.
--
-- DrakDerg, Kaneki_Ken2907, Aorney were reviewed and DELIBERATELY EXCLUDED (mixed N+M prizes
-- or MIDDLES-only profile — under observation for week-5 instead).
--
-- The five live on two separate platform PROD DBs. Run this same script on EACH:
--   [F2P] STEAM PROD  -> matches FurryCurrentMaster + SplendidTroutAngler + HeitorJR2
--   [F2P] PS    PROD  -> matches vybuschna_plina + sentinel_krk
-- (no Xbox abusers this week — likely effect of last week's bans + Support's PS sweep)
-- Non-present UserIds simply don't join Profiles (verify SELECT flags them as not-found per DB).
--
-- Replicates WebAdmin "Set Competition Banned" (Profile side only):
--   1. UPDATE Profiles.IsCompetitionsBanned + CompetitionsBanEndDate
--   2. AdminComment audit note appended (not overwritten)
--   3. Influencer reset if IsInfluencer=1
--   4. Mongo Ban/Tournament audit log                                -> separate: ban-log-backfill-2026-05-31.js
--   5. Photon notify                                                 -> NOT replicated
-- LEADERBOARD ban is intentionally NOT done here — run leaderboard-ban-sync.sql afterwards
-- (recurring gotcha: verify per platform individually after, Xbox especially — though Xbox is
-- empty this cycle).
--
-- Atomic: SET XACT_ABORT ON auto-rolls-back on any error. After inspecting the verify SELECT,
-- run COMMIT TRAN (or ROLLBACK TRAN) at the bottom by hand.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil date          = '2026-06-15';   -- 2 weeks, Monday-aligned, uniform (all five NEW)
    DECLARE @Note     nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-05-31 — rating-drop abuse (week-4, Tournament-log no-show 57-67%)';

    BEGIN TRAN;

    -- Step 1: explicit ban list (uniform 2-week ban)
    IF OBJECT_ID('tempdb..#BanCandidates') IS NOT NULL DROP TABLE #BanCandidates;
    CREATE TABLE #BanCandidates (UserId uniqueidentifier PRIMARY KEY, Username varchar(64) NOT NULL);

    INSERT INTO #BanCandidates (UserId, Username) VALUES
        ('09DAA0C8-856A-4328-8001-9CC1B2683FAB', 'FurryCurrentMaster'),   -- Steam
        ('CE0B47DE-48FE-4494-9AE7-10C3DEFA456F', 'SplendidTroutAngler'),  -- Steam
        ('9DD3E9DF-0ED5-4810-9142-79E6D099710E', 'HeitorJR2'),            -- Steam
        ('07BDB641-FCA0-47E1-94BC-61A1D6F92599', 'vybuschna_plina'),      -- PS
        ('84F0D212-9F87-4851-9CEE-86E2A6DFCB8B', 'sentinel_krk');         -- PS

    -- Step 2: Profile ban (durable). Skip rows already banned (don't overwrite an existing ban date).
    UPDATE p
    SET p.IsCompetitionsBanned   = 1,
        p.CompetitionsBanEndDate = @BanUntil,
        p.AdminComment           = CASE
            WHEN p.AdminComment IS NULL OR LTRIM(RTRIM(p.AdminComment)) = ''
                THEN @Note + ' (until ' + CONVERT(varchar(10), @BanUntil, 23) + ')'
            ELSE p.AdminComment + CHAR(13) + CHAR(10) + @Note + ' (until ' + CONVERT(varchar(10), @BanUntil, 23) + ')'
        END
    FROM Profiles p
    INNER JOIN #BanCandidates b ON b.UserId = p.UserId
    WHERE ISNULL(p.IsCompetitionsBanned, 0) = 0;

    PRINT CONCAT('Profiles banned on this DB: ', @@ROWCOUNT);

    -- Step 3: Influencer reset (matches WebAdmin "if (value && IsInfluencer) SetInfluencer(false)")
    UPDATE p
    SET p.IsInfluencer = 0
    FROM Profiles p
    INNER JOIN #BanCandidates b ON b.UserId = p.UserId
    WHERE p.IsInfluencer = 1;

    PRINT CONCAT('Influencer flags cleared: ', @@ROWCOUNT);

    -- Step 4: verify (rows with Username from Users = found on this DB; NULL Users = belongs to another platform)
    SELECT b.Username AS Expected,
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
    ORDER BY FoundUser;

    DROP TABLE #BanCandidates;

    -- After visual inspection pick ONE:
    -- COMMIT TRAN;
    -- ROLLBACK TRAN;
END;
