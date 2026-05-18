-- FP-43631 — Discovery SQL for PCR-drop abuse detection
-- Window:   Tournaments.StartDate >= '2026-04-29' (matchmaking launch on Steam/EGS)
-- Scope:    KindId = 3 (Competition) only — brackets/matchmaking apply only here
-- Status:   Only ended, non-cancelled, non-deleted tournaments
--
-- Ground-truth UserIds (3 confirmed abusers per Community&Support team):
-- STEAM:
--   bafa56a3-af75-443c-b3d3-dee191015189 = W_CHUANQI (already banned)
--   f139316b-bd01-42ba-bf31-aba105bc9bd0 = wuhongzei
--   dab0b476-4ba7-483c-adcc-dd380df05a9d = TrigramMirror
--   9757fd6a-8435-409a-9f83-33214af80424 = StillWaterMind (top 2 wins leaderboard of the week)
-- PS:
--   871b984b-cf03-414f-ac6c-aa82d237fbcd = babasss27 (reported by players, clean)
--
-- Run on PROD: detection cohort lives there. Local dev DB has < 10 participants.
--
-- Rating-sign note: `tournament.Places` is a piecewise step-config. Bottom-tier places
-- have NEGATIVE configured Rating (smaller magnitude than NoShowRatingPenalty, but still <0).
-- So `r.Rating < 0` does NOT prove no-show. The reliable discriminator is `IsStarted = 0`.
-- RatingFromRealPlay sums Rating over rows where the player actually played — for an honest
-- bad player it will be NEGATIVE (slow drag from sub-prize finishes); for an abuser it
-- will be POSITIVE (Nub-bracket prizes outweigh in-game losses).


-- FP-43631 Query A — single-player verification: competition timeline (tournament id, template, name, bracket, group, place, rating, scores, reward)
-- ============================================================================
BEGIN
    DECLARE @WindowStart datetime         = '2026-04-29'; -- STEAM
    --DECLARE @WindowStart datetime         = '2026-05-06'; -- PS
    --DECLARE @WindowStart datetime         = '2026-05-07'; -- Xbox
    DECLARE @UserId      uniqueidentifier = CAST('09daa0c8-856a-4328-8001-9cc1b2683fab' AS uniqueidentifier);
    DECLARE @LanguageId  int              = 3;


    -- Verify: Single-player competition timeline (use after Query B to inspect a found suspect)
    SELECT
        t.TournamentId,
        t.TemplateId,
        tr.String                AS Name,
        t.EndDate,
        CASE p.BracketId WHEN 1 THEN 'NOOBS' WHEN 2 THEN 'MIDDLES' WHEN 3 THEN 'TOPS' END AS BracketName,
        p.GroupName,
        r.Place,
        CASE
            WHEN p.IsStarted = 0                                                 THEN 'NO-SHOW'
            WHEN p.IsDisqualified = 1                                            THEN 'DQ'
            WHEN ISNULL(r.Score, 0) = 0 AND ISNULL(r.SecondaryScore, 0) = 0      THEN 'ZERO-SCORE'
            WHEN r.Place IS NOT NULL AND r.Place <= 3                            THEN 'PRIZE'
            ELSE 'PLAYED'
        END                      AS Outcome,
        r.Rating,
        r.Score,
        r.SecondaryScore,
        r.IsRewardReceived,
        r.RewardJson
    FROM TournamentParticipants p WITH (NOLOCK)
    INNER JOIN Tournaments t WITH (NOLOCK)
        ON t.TournamentId = p.TournamentId
    LEFT  JOIN TournamentIndividualResults r WITH (NOLOCK)
        ON r.TournamentId = p.TournamentId AND r.UserId = p.UserId
    LEFT  JOIN Translations tr WITH (NOLOCK)
        ON tr.TranslationId = t.NameSID AND tr.LanguageId = @LanguageId
    WHERE p.UserId    = @UserId
      AND t.StartDate >= @WindowStart
      AND t.KindId    = 3
      AND t.IsEnded   = 1
      AND t.IsCanceled = 0
      AND ISNULL(t.IsDeleted, 0) = 0
    ORDER BY t.EndDate;
END;


-- FP-43631 Query B — full-cohort PCR-drop abuse detection (HAVING-filtered, parametrized window + thresholds)
-- ============================================================================
BEGIN
    DECLARE @WindowStart          datetime       = '2026-04-29'; -- STEAM
    --DECLARE @WindowStart          datetime       = '2026-05-06'; -- PS
    --DECLARE @WindowStart          datetime       = '2026-05-07'; -- Xbox
    DECLARE @MinNoShows           int            = 10;
    DECLARE @MinNoShowSharePct    decimal(6,2)   = 30.00;
    DECLARE @MaxRatingFromNoShow  int            = -150; -- threshold is ≤ this (i.e. -150 or more negative)

    -- Find: Full-cohort PCR-drop abuse scan (no-show ≥ N, share ≥ X, rating-loss-from-no-show ≤ Y)
    WITH Window AS (
        SELECT t.TournamentId
        FROM Tournaments t WITH (NOLOCK)
        WHERE t.StartDate >= @WindowStart
          AND t.KindId    = 3
          AND t.IsEnded   = 1
          AND t.IsCanceled = 0
          AND ISNULL(t.IsDeleted, 0) = 0
    ),
    Activity AS (
        SELECT
            p.UserId,
            p.IsStarted,
            p.IsDisqualified,
            r.Place,
            r.Score,
            r.SecondaryScore,
            r.Rating
        FROM TournamentParticipants p WITH (NOLOCK)
        INNER JOIN Window w ON w.TournamentId = p.TournamentId
        LEFT  JOIN TournamentIndividualResults r WITH (NOLOCK)
            ON r.TournamentId = p.TournamentId AND r.UserId = p.UserId
    ),
    Aggregate AS (
        SELECT
            a.UserId,
            COUNT(*)                                                                 AS Registrations,
            SUM(CASE WHEN a.IsStarted = 0 THEN 1 ELSE 0 END)                         AS NoShows,
            SUM(CASE WHEN a.IsDisqualified = 1 THEN 1 ELSE 0 END)                    AS Disqualifications,
            SUM(CASE WHEN a.IsStarted = 1 AND a.IsDisqualified = 0 THEN 1 ELSE 0 END) AS Started,
            SUM(CASE
                WHEN a.IsStarted = 1 AND a.IsDisqualified = 0
                 AND ISNULL(a.Score, 0)          = 0
                 AND ISNULL(a.SecondaryScore, 0) = 0 THEN 1 ELSE 0 END)              AS ZeroScore,
            SUM(CASE WHEN a.Place = 1 THEN 1 ELSE 0 END)                             AS Gold,
            SUM(CASE WHEN a.Place = 2 THEN 1 ELSE 0 END)                             AS Silver,
            SUM(CASE WHEN a.Place = 3 THEN 1 ELSE 0 END)                             AS Bronze,
            SUM(CASE WHEN a.IsStarted = 0 OR a.IsDisqualified = 1
                     THEN ISNULL(a.Rating, 0) ELSE 0 END)                            AS RatingFromNoShow_DQ,
            SUM(CASE WHEN a.IsStarted = 1 AND a.IsDisqualified = 0
                     THEN ISNULL(a.Rating, 0) ELSE 0 END)                            AS RatingFromRealPlay,
            SUM(ISNULL(a.Rating, 0))                                                 AS RatingNetDelta,
            CAST(SUM(CASE WHEN a.IsStarted = 0 THEN 1 ELSE 0 END) * 100.0
                 / NULLIF(COUNT(*), 0) AS decimal(6,2))                              AS NoShowSharePct
        FROM Activity a
        GROUP BY a.UserId
        HAVING SUM(CASE WHEN a.IsStarted = 0 THEN 1 ELSE 0 END) >= @MinNoShows
           AND CAST(SUM(CASE WHEN a.IsStarted = 0 THEN 1 ELSE 0 END) * 100.0
                    / NULLIF(COUNT(*), 0) AS decimal(6,2)) >= @MinNoShowSharePct
           AND SUM(CASE WHEN a.IsStarted = 0 OR a.IsDisqualified = 1
                        THEN ISNULL(a.Rating, 0) ELSE 0 END) <= @MaxRatingFromNoShow
    )
    SELECT
        ag.UserId,
        u.Username,
        u.Source                                                                     AS Platform,
        pr.Level,
        pr.Rank,
        pr.CompetitionRating                                                         AS CurrentPCR,

        ag.Registrations,
        ag.Started,
        ag.ZeroScore,

        ag.NoShows,
        ag.NoShowSharePct,
        ag.RatingFromNoShow_DQ,
        ag.RatingFromRealPlay,
        ag.RatingNetDelta,

        ag.Gold,
        ag.Silver,
        ag.Bronze,

        ag.Disqualifications,

        TRY_CAST(JSON_VALUE(pr.StatsJson, '$.GenericStats.CompWon.Count') AS int)    AS LifetimeGold,
        TRY_CAST(JSON_VALUE(pr.StatsJson, '$.GenericStats.Comp2nd.Count') AS int)    AS LifetimeSilver,
        TRY_CAST(JSON_VALUE(pr.StatsJson, '$.GenericStats.Comp3rd.Count') AS int)    AS LifetimeBronze,

        pr.IsCompetitionsBanned                                                      AS IsBanned,
        pr.CompetitionsBanEndDate                                                    AS BanEnd
    FROM Aggregate ag
    LEFT JOIN Profiles pr WITH (NOLOCK) ON pr.UserId = ag.UserId
    LEFT JOIN Users    u  WITH (NOLOCK) ON u.UserId  = ag.UserId
    ORDER BY ag.NoShows DESC, ag.RatingFromNoShow_DQ;
END;
