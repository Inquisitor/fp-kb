-- FP-43631 Week-2 — full report: Query B columns + Verdict + BanUntil (one row per banworthy player)
-- ============================================================================
-- Returns Query B-style aggregates for the new window only (so STOPPED/amnesty players are absent by design).
-- Verdict is derived from old-cohort membership; BanUntil follows the verdict.
--
-- Verdicts:
--   CONTINUED — in both old & new cohorts → BanUntil = 2026-06-15 (4 weeks)
--   STARTED   — only in new cohort        → BanUntil = 2026-06-01 (2 weeks)
--   STOPPED   — only in old cohort        → absent (amnesty, no action)
--
-- IsBanned + BanEnd come from Profiles; if IsBanned = true, Support already handled — skip in Sheets.
--
-- Old thresholds match what produced last week's 107-list (Support 2026-05-11):
--   NoShows ≥ 10, NoShowSharePct ≥ 30, RatingFromNoShow_DQ ≤ −150
-- New thresholds are pro-rated to the 7-day new window (Steam old = 12 days, factor 7/12 ≈ 0.58):
--   NoShows ≥ 6,  NoShowSharePct ≥ 30, RatingFromNoShow_DQ ≤ −90
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

    -- Report: new-window banworthy players with verdict + recommended ban end date
    WITH WindowOld AS (
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
        -- Just UserId membership for verdict; no need for full aggregate columns here
        SELECT p.UserId
        FROM TournamentParticipants p WITH (NOLOCK)
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
    ActivityNew AS (
        SELECT p.UserId, p.IsStarted, p.IsDisqualified, r.Place, r.Score, r.SecondaryScore, r.Rating
        FROM TournamentParticipants p WITH (NOLOCK)
        INNER JOIN WindowNew w ON w.TournamentId = p.TournamentId
        LEFT  JOIN TournamentIndividualResults r WITH (NOLOCK)
            ON r.TournamentId = p.TournamentId AND r.UserId = p.UserId
    ),
    AggregateNew AS (
        SELECT
            a.UserId,
            COUNT(*)                                                                         AS Registrations,
            SUM(CASE WHEN a.IsStarted = 0 THEN 1 ELSE 0 END)                                 AS NoShows,
            SUM(CASE WHEN a.IsDisqualified = 1 THEN 1 ELSE 0 END)                            AS Disqualifications,
            SUM(CASE WHEN a.IsStarted = 1 AND a.IsDisqualified = 0 THEN 1 ELSE 0 END)        AS Started,
            SUM(CASE
                WHEN a.IsStarted = 1 AND a.IsDisqualified = 0
                 AND ISNULL(a.Score, 0)          = 0
                 AND ISNULL(a.SecondaryScore, 0) = 0 THEN 1 ELSE 0 END)                      AS ZeroScore,
            SUM(CASE WHEN a.Place = 1 THEN 1 ELSE 0 END)                                     AS Gold,
            SUM(CASE WHEN a.Place = 2 THEN 1 ELSE 0 END)                                     AS Silver,
            SUM(CASE WHEN a.Place = 3 THEN 1 ELSE 0 END)                                     AS Bronze,
            SUM(CASE WHEN a.IsStarted = 0 OR a.IsDisqualified = 1
                     THEN ISNULL(a.Rating, 0) ELSE 0 END)                                    AS RatingFromNoShow_DQ,
            SUM(CASE WHEN a.IsStarted = 1 AND a.IsDisqualified = 0
                     THEN ISNULL(a.Rating, 0) ELSE 0 END)                                    AS RatingFromRealPlay,
            SUM(ISNULL(a.Rating, 0))                                                         AS RatingNetDelta,
            CAST(SUM(CASE WHEN a.IsStarted = 0 THEN 1 ELSE 0 END) * 100.0
                 / NULLIF(COUNT(*), 0) AS decimal(6,2))                                      AS NoShowSharePct
        FROM ActivityNew a
        GROUP BY a.UserId
        HAVING SUM(CASE WHEN a.IsStarted = 0 THEN 1 ELSE 0 END) >= @NewMinNoShows
           AND CAST(SUM(CASE WHEN a.IsStarted = 0 THEN 1 ELSE 0 END) * 100.0
                    / NULLIF(COUNT(*), 0) AS decimal(6,2)) >= @NewMinNoShowSharePct
           AND SUM(CASE WHEN a.IsStarted = 0 OR a.IsDisqualified = 1
                        THEN ISNULL(a.Rating, 0) ELSE 0 END) <= @NewMaxRatingFromNoShow
    )
    SELECT
        an.UserId,
        u.Username,
        u.Source                                                                     AS Platform,
        pr.Level,
        pr.Rank,
        pr.CompetitionRating                                                         AS CurrentPCR,

        an.Registrations,
        an.Started,
        an.ZeroScore,

        an.NoShows,
        an.NoShowSharePct,
        an.RatingFromNoShow_DQ,
        an.RatingFromRealPlay,
        an.RatingNetDelta,

        an.Gold,
        an.Silver,
        an.Bronze,

        an.Disqualifications,

        TRY_CAST(JSON_VALUE(pr.StatsJson, '$.GenericStats.CompWon.Count') AS int)    AS LifetimeGold,
        TRY_CAST(JSON_VALUE(pr.StatsJson, '$.GenericStats.Comp2nd.Count') AS int)    AS LifetimeSilver,
        TRY_CAST(JSON_VALUE(pr.StatsJson, '$.GenericStats.Comp3rd.Count') AS int)    AS LifetimeBronze,

        pr.IsCompetitionsBanned                                                      AS IsBanned,
        pr.CompetitionsBanEndDate                                                    AS BanEnd,

        CASE WHEN co.UserId IS NOT NULL THEN 'CONTINUED' ELSE 'STARTED' END          AS Verdict,
        CASE WHEN co.UserId IS NOT NULL
             THEN CAST('2026-06-17' AS date)
             ELSE CAST('2026-06-01' AS date) END                                     AS BanUntil
    FROM AggregateNew an
    LEFT JOIN CohortOld co ON co.UserId = an.UserId
    LEFT JOIN Users    u  WITH (NOLOCK) ON u.UserId  = an.UserId
    LEFT JOIN Profiles pr WITH (NOLOCK) ON pr.UserId = an.UserId
    ORDER BY
        CASE WHEN co.UserId IS NOT NULL THEN 1 ELSE 2 END, -- CONTINUED first
        an.NoShows DESC, an.RatingFromNoShow_DQ;
END;
