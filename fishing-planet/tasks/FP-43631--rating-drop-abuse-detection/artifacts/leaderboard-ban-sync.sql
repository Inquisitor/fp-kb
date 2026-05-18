-- FP-43631 — Sync CompetitiveRatingsCurrent.IsBanned ← Profiles.IsCompetitionsBanned (per platform)
-- ============================================================================
-- Closes the gap between two independent flags:
--   - Profiles.IsCompetitionsBanned  — blocks future registrations (admin-set durable ban)
--   - CompetitiveRatingsCurrent.IsBanned — excludes from current-period reward distribution
-- They are NOT auto-linked. Profile-banned users keep IsBanned=0 in Current → would still
-- receive prizes when Weekly/Monthly/Yearly periods finalize, even though their account is banned.
--
-- This script propagates an ACTIVE Profile ban to all the user's existing Current rows
-- (Weekly + Monthly + Yearly). Idempotent — safe to re-run.
--
-- Filter: only ACTIVE Profile bans (`IsCompetitionsBanned=1` AND ban not expired).
--   Expired-flag users (IsCompetitionsBanned=1 but BanEndDate in past) are left alone —
--   their ban is logically over, no reason to exclude them from rewards earned legitimately.
--
-- Run order: execute on each platform PROD MAIN (Steam / PS / Xbox / Mobile / NX) once.
-- Atomic: XACT_ABORT ON triggers ROLLBACK on any error; otherwise COMMIT at end.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    BEGIN TRAN;

    -- Pre-snapshot for verify (count of rows about to be flipped)
    DECLARE @PreCount int = (
        SELECT COUNT(*)
        FROM CompetitiveRatingsCurrent r WITH (NOLOCK)
        INNER JOIN Profiles p WITH (NOLOCK) ON p.UserId = r.UserId
        WHERE p.IsCompetitionsBanned = 1
          AND (p.CompetitionsBanEndDate IS NULL OR p.CompetitionsBanEndDate > GETUTCDATE())
          AND r.IsBanned = 0
    );

    -- The actual sync
    UPDATE r
    SET r.IsBanned = 1
    FROM CompetitiveRatingsCurrent r
    INNER JOIN Profiles p WITH (NOLOCK) ON p.UserId = r.UserId
    WHERE p.IsCompetitionsBanned = 1
      AND (p.CompetitionsBanEndDate IS NULL OR p.CompetitionsBanEndDate > GETUTCDATE())
      AND r.IsBanned = 0;
    DECLARE @Updated int = @@ROWCOUNT;

    -- Verify: top-line counts
    SELECT @PreCount AS RowsExpectedToFlip, @Updated AS RowsActuallyFlipped;

    -- Verify: breakdown by PeriodTypeId / PeriodId
    SELECT 'After sync — banned rows from profile-banned users:' AS Info,
           r.PeriodTypeId, r.PeriodId, COUNT(*) AS BannedRows
    FROM CompetitiveRatingsCurrent r WITH (NOLOCK)
    INNER JOIN Profiles p WITH (NOLOCK) ON p.UserId = r.UserId
    WHERE p.IsCompetitionsBanned = 1
      AND (p.CompetitionsBanEndDate IS NULL OR p.CompetitionsBanEndDate > GETUTCDATE())
      AND r.IsBanned = 1
    GROUP BY r.PeriodTypeId, r.PeriodId
    ORDER BY r.PeriodTypeId, r.PeriodId;

    -- Verify: any leftover profile-banned-but-not-LB-banned (should be 0; non-zero = expired bans we skipped)
    SELECT 'Skipped (expired Profile ban, LB not touched):' AS Info, COUNT(*) AS SkippedRows
    FROM CompetitiveRatingsCurrent r WITH (NOLOCK)
    INNER JOIN Profiles p WITH (NOLOCK) ON p.UserId = r.UserId
    WHERE p.IsCompetitionsBanned = 1
      AND p.CompetitionsBanEndDate IS NOT NULL
      AND p.CompetitionsBanEndDate <= GETUTCDATE()
      AND r.IsBanned = 0;

    -- COMMIT TRAN;
END;
