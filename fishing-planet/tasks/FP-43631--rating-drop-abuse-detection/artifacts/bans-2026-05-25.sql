-- FP-43631 week-3 ban — surgical Profile ban of 4 log-verified rating-drop abusers
-- (the @Note applied to AdminComment keeps its original "tank-and-farm" wording — already written to prod)
-- ============================================================================
-- Hand-picked list (NOT a HAVING-derived cohort): each UserId was confirmed via the Mongo
-- Tournament-log no-show labelling on 2026-05-25 (see artifacts/pcr-log-trajectories-2026-05-25.md):
-- strong play (+178..+583) deliberately offset by 49-67% no-shows that pin PCR in the low bracket.
-- Djarumsuper16 (39% no-show, net climbing) was reviewed and DELIBERATELY EXCLUDED as likely honest.
--
-- The four live on three separate platform PROD DBs. Run this same script on EACH:
--   [F2P] STEAM PROD  -> matches Holekko only
--   [F2P] PS    PROD  -> matches IIGot-_-Smoked only
--   [F2P] XB    PROD  -> matches VITAO4460 + profpaulo18
-- Non-present UserIds simply don't join Profiles (verify SELECT flags them as not-found per DB).
--
-- Replicates WebAdmin "Set Competition Banned" (Profile side only):
--   1. UPDATE Profiles.IsCompetitionsBanned + CompetitionsBanEndDate  — REPLICATED
--   2. AdminComment audit note appended (not overwritten)             — REPLICATED
--   3. Influencer reset if IsInfluencer=1                             — REPLICATED
--   4. Mongo Ban/Tournament audit log                                — separate: ban-log-backfill-2026-05-25.js
--   5. Photon notify                                                 — NOT replicated (player learns at next registration)
-- LEADERBOARD ban is intentionally NOT done here — run leaderboard-ban-sync.sql afterwards
-- (it sets CompetitiveRatingsCurrent.IsBanned=1 for every active Profile ban this period).
--
-- Atomic: SET XACT_ABORT ON auto-rolls-back on any error. After inspecting the verify SELECT,
-- run COMMIT TRAN (or ROLLBACK TRAN) at the bottom by hand.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil date          = '2026-06-08';   -- 2 weeks, Monday-aligned
    DECLARE @Note     nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-05-25 — tank-and-farm (week-3, Tournament-log no-show 49-67%)';

    BEGIN TRAN;

    -- Step 1: explicit ban list (uniform 2-week ban)
    IF OBJECT_ID('tempdb..#BanCandidates') IS NOT NULL DROP TABLE #BanCandidates;
    CREATE TABLE #BanCandidates (UserId uniqueidentifier PRIMARY KEY, Username varchar(64) NOT NULL);

    INSERT INTO #BanCandidates (UserId, Username) VALUES
        ('5E3F0096-55ED-4715-BA43-4A7F377507A4', 'Holekko'),          -- Steam
        ('8F36F30F-ADE0-4D9A-BC88-765AE61E5384', 'IIGot-_-Smoked'),   -- PS
        ('5CEC46B5-E4CA-43BD-9BD1-3BB493460A4E', 'VITAO4460'),        -- Xbox
        ('4BF7E769-1526-47A4-9795-5A7B3FDF1D3C', 'profpaulo18');      -- Xbox

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
