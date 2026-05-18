-- FP-43631 Week-2 — bulk ban execution: Profile ban (durable) + Leaderboard ban (current periods)
-- ============================================================================
-- Replicates WebAdmin "Set Competition Banned" action for bulk cohort. Run per platform.
--
-- What WebAdmin admin action does, and what this script does:
--   1. UPDATE Profiles.IsCompetitionsBanned + CompetitionsBanEndDate — REPLICATED
--   2. Mongo audit Logger.Ban.LogBan                                  — NOT replicated (SQL→Mongo not done from script)
--   3. Mongo audit Logger.Tournament.Log                              — NOT replicated
--   4. Photon notify via RunOnMaster(c => c.SendMessage)              — NOT replicated (player learns at next registration attempt)
--   5. Influencer reset (if IsInfluencer=true)                        — REPLICATED (separate UPDATE)
-- Plus: per-period CompetitiveRatingsCurrent.IsBanned=1 to block reward distribution this period.
--
-- Audit-trail mitigation: each affected Profiles row gets a `AdminComment` appended with the operation note.
--
-- Run order:
--   1. Set @OldStart per platform (Steam/PS/Xbox)
--   2. Execute the script — atomic: SET XACT_ABORT ON ensures any error auto-rolls-back, otherwise auto-COMMIT at end
--   3. Inspect Verify SELECTs returned to confirm what was committed

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    --DECLARE @OldStart                  datetime     = '2026-04-29'; -- STEAM
    --DECLARE @OldStart                  datetime     = '2026-05-06'; -- PS
    DECLARE @OldStart                  datetime     = '2026-05-07'; -- Xbox
    DECLARE @Cutoff                    datetime     = '2026-05-11';

    DECLARE @OldMinNoShows             int          = 10;
    DECLARE @OldMinNoShowSharePct      decimal(6,2) = 30.00;
    DECLARE @OldMaxRatingFromNoShow    int          = -150;

    DECLARE @NewMinNoShows             int          = 6;
    DECLARE @NewMinNoShowSharePct      decimal(6,2) = 30.00;
    DECLARE @NewMaxRatingFromNoShow    int          = -90;

    DECLARE @BanUntil_4W               date         = '2026-06-17'; -- CONTINUED
    DECLARE @BanUntil_2W               date         = '2026-06-01'; -- STARTED
    DECLARE @Note                      nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-05-17 — no-show abuse (week-2 comparison)';

    BEGIN TRAN;

    -- Step 1: Derive ban list with verdict-based BanUntil into a temp table (re-used by 3 UPDATEs)
    IF OBJECT_ID('tempdb..#BanCandidates') IS NOT NULL DROP TABLE #BanCandidates;
    CREATE TABLE #BanCandidates (UserId uniqueidentifier PRIMARY KEY, BanUntil date NOT NULL, Verdict varchar(10) NOT NULL);

    ;WITH WindowOld AS (
        SELECT t.TournamentId FROM Tournaments t WITH (NOLOCK)
        WHERE t.StartDate >= @OldStart AND t.StartDate < @Cutoff
          AND t.KindId = 3 AND t.IsEnded = 1 AND t.IsCanceled = 0 AND ISNULL(t.IsDeleted, 0) = 0
    ),
    WindowNew AS (
        SELECT t.TournamentId FROM Tournaments t WITH (NOLOCK)
        WHERE t.StartDate >= @Cutoff
          AND t.KindId = 3 AND t.IsEnded = 1 AND t.IsCanceled = 0 AND ISNULL(t.IsDeleted, 0) = 0
    ),
    CohortOld AS (
        SELECT p.UserId FROM TournamentParticipants p WITH (NOLOCK)
        INNER JOIN WindowOld w ON w.TournamentId = p.TournamentId
        LEFT  JOIN TournamentIndividualResults r WITH (NOLOCK)
            ON r.TournamentId = p.TournamentId AND r.UserId = p.UserId
        GROUP BY p.UserId
        HAVING SUM(CASE WHEN p.IsStarted = 0 THEN 1 ELSE 0 END) >= @OldMinNoShows
           AND CAST(SUM(CASE WHEN p.IsStarted = 0 THEN 1 ELSE 0 END) * 100.0
                    / NULLIF(COUNT(*), 0) AS decimal(6,2)) >= @OldMinNoShowSharePct
           AND SUM(CASE WHEN p.IsStarted = 0 OR p.IsDisqualified = 1
                        THEN ISNULL(r.Rating, 0) ELSE 0 END) <= @OldMaxRatingFromNoShow
    ),
    CohortNew AS (
        SELECT p.UserId FROM TournamentParticipants p WITH (NOLOCK)
        INNER JOIN WindowNew w ON w.TournamentId = p.TournamentId
        LEFT  JOIN TournamentIndividualResults r WITH (NOLOCK)
            ON r.TournamentId = p.TournamentId AND r.UserId = p.UserId
        GROUP BY p.UserId
        HAVING SUM(CASE WHEN p.IsStarted = 0 THEN 1 ELSE 0 END) >= @NewMinNoShows
           AND CAST(SUM(CASE WHEN p.IsStarted = 0 THEN 1 ELSE 0 END) * 100.0
                    / NULLIF(COUNT(*), 0) AS decimal(6,2)) >= @NewMinNoShowSharePct
           AND SUM(CASE WHEN p.IsStarted = 0 OR p.IsDisqualified = 1
                        THEN ISNULL(r.Rating, 0) ELSE 0 END) <= @NewMaxRatingFromNoShow
    )
    INSERT INTO #BanCandidates (UserId, BanUntil, Verdict)
    SELECT
        cn.UserId,
        CASE WHEN co.UserId IS NOT NULL THEN @BanUntil_4W ELSE @BanUntil_2W END,
        CASE WHEN co.UserId IS NOT NULL THEN 'CONTINUED'  ELSE 'STARTED'      END
    FROM CohortNew cn
    LEFT JOIN CohortOld co ON co.UserId = cn.UserId
    WHERE NOT EXISTS (
        -- Skip if already Profile-banned (don't overwrite existing ban dates / unrelated bans)
        SELECT 1 FROM Profiles p WITH (NOLOCK)
        WHERE p.UserId = cn.UserId AND ISNULL(p.IsCompetitionsBanned, 0) = 1
    );

    DECLARE @Count int = (SELECT COUNT(*) FROM #BanCandidates);
    PRINT CONCAT('Ban candidates: ', @Count);

    -- Step 2: Profile ban (the main durable action)
    UPDATE p
    SET p.IsCompetitionsBanned   = 1,
        p.CompetitionsBanEndDate = b.BanUntil,
        p.AdminComment           = CASE
            WHEN p.AdminComment IS NULL OR LTRIM(RTRIM(p.AdminComment)) = ''
                THEN @Note + ' (' + b.Verdict + ' until ' + CONVERT(varchar(10), b.BanUntil, 23) + ')'
            ELSE p.AdminComment + CHAR(13) + CHAR(10) + @Note + ' (' + b.Verdict + ' until ' + CONVERT(varchar(10), b.BanUntil, 23) + ')'
        END
    FROM Profiles p
    INNER JOIN #BanCandidates b ON b.UserId = p.UserId;

    PRINT CONCAT('Profiles updated: ', @@ROWCOUNT);

    -- Step 3: Surgical leaderboard ban — all current periods (Weekly/Monthly/Yearly) the user is in
    UPDATE r
    SET r.IsBanned = 1
    FROM CompetitiveRatingsCurrent r
    INNER JOIN #BanCandidates b ON b.UserId = r.UserId
    WHERE r.IsBanned = 0;

    PRINT CONCAT('CompetitiveRatingsCurrent rows banned: ', @@ROWCOUNT);

    -- Step 4: Influencer reset (rare; matches WebAdmin "if (value && IsInfluencer) SetInfluencer(false)")
    UPDATE p
    SET p.IsInfluencer = 0
    FROM Profiles p
    INNER JOIN #BanCandidates b ON b.UserId = p.UserId
    WHERE p.IsInfluencer = 1;

    PRINT CONCAT('Influencer flags cleared: ', @@ROWCOUNT);

    -- Step 5: Verify what was just done
    SELECT b.Verdict, b.BanUntil, b.UserId, u.Username, p.IsCompetitionsBanned, p.CompetitionsBanEndDate,
           p.IsInfluencer, p.AdminComment
    FROM #BanCandidates b
    LEFT JOIN Profiles p WITH (NOLOCK) ON p.UserId = b.UserId
    LEFT JOIN Users    u WITH (NOLOCK) ON u.UserId = b.UserId
    ORDER BY b.Verdict, u.Username;

    SELECT 'CompetitiveRatingsCurrent affected:' AS Info,
           r.PeriodTypeId, r.PeriodId, COUNT(*) AS BannedRows
    FROM CompetitiveRatingsCurrent r WITH (NOLOCK)
    INNER JOIN #BanCandidates b ON b.UserId = r.UserId
    WHERE r.IsBanned = 1
    GROUP BY r.PeriodTypeId, r.PeriodId
    ORDER BY r.PeriodTypeId, r.PeriodId;

    DROP TABLE #BanCandidates;

    -- After visual inspection: pick one of
    -- COMMIT TRAN;
    -- ROLLBACK TRAN;
END;
