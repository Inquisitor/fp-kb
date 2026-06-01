-- FP-43631 — Community&Support violators report (rating-drop abuse cohort). Run on each platform PROD MAIN.
-- ============================================================================
-- Column layout: old report fields (week2-comparison.sql order) first, then NEW per-bracket Played/Prizes
-- (concatenated as single N/M/T strings), then TotalPrizes, then the ban-status trailer at the very end.
-- Deviations from week-2: Verdict is ban-history (NEW/REPEAT/BANNED), not cross-week; BanUntil dropped.
--
-- Verdict:
--   NEW    — never competition-banned
--   REPEAT — has a competition ban that already EXPIRED (re-offending; a ban dated before the
--            2026-04-29 matchmaking launch is an old/unrelated comp ban — judge accordingly)
--   BANNED — currently competition-banned (by us this cycle, or a prior active ban)
--
-- NEW per-bracket columns (BracketId 1=NOOBS, 2=MIDDLES, 3=TOPS), each a single "N / M / T" string
-- (spaces around the slash on purpose — "8/12/0" gets auto-parsed as a date by Google Sheets):
--   Played_NMT — competitions actually PLAYED (started, not DQ) per bracket → where they compete
--   Prizes_NMT — prizes (Place<=3) per bracket → where they cash (NOOBS-concentrated = clearest abuse)
--
-- Gate: no-show (NoShows>=6, NoShowSharePct>=30, RatingFromNoShow_DQ<=-90) AND prize (total prizes > 3).
-- Already-banned players are NOT excluded — Verdict (trailing) classifies them so Support sees recidivism.
BEGIN
    DECLARE @WindowStart        datetime     = '2026-05-25';
    DECLARE @MinNoShows         int          = 6;
    DECLARE @MinNoShowSharePct  decimal(6,2) = 30.00;
    DECLARE @MaxRatingFromNoShow int         = -90;
    DECLARE @MinTotalPrizes     int          = 4;

    WITH Window AS (
        SELECT t.TournamentId FROM Tournaments t WITH (NOLOCK)
        WHERE t.StartDate >= @WindowStart AND t.KindId=3 AND t.IsEnded=1 AND t.IsCanceled=0 AND ISNULL(t.IsDeleted,0)=0
    ),
    Activity AS (
        SELECT p.UserId, p.IsStarted, p.IsDisqualified, p.BracketId, r.Place, r.Score, r.SecondaryScore, r.Rating
        FROM TournamentParticipants p WITH (NOLOCK)
        INNER JOIN Window w ON w.TournamentId=p.TournamentId
        LEFT JOIN TournamentIndividualResults r WITH (NOLOCK) ON r.TournamentId=p.TournamentId AND r.UserId=p.UserId
    ),
    Aggregate AS (
        SELECT a.UserId,
            COUNT(*)                                                                          AS Registrations,
            SUM(CASE WHEN a.IsStarted=1 AND a.IsDisqualified=0 THEN 1 ELSE 0 END)             AS Started,
            SUM(CASE WHEN a.IsStarted=1 AND a.IsDisqualified=0
                      AND ISNULL(a.Score,0)=0 AND ISNULL(a.SecondaryScore,0)=0 THEN 1 ELSE 0 END) AS ZeroScore,
            SUM(CASE WHEN a.IsStarted=0 THEN 1 ELSE 0 END)                                    AS NoShows,
            CAST(SUM(CASE WHEN a.IsStarted=0 THEN 1 ELSE 0 END)*100.0/NULLIF(COUNT(*),0) AS decimal(6,2)) AS NoShowSharePct,
            SUM(CASE WHEN a.IsStarted=0 OR a.IsDisqualified=1 THEN ISNULL(a.Rating,0) ELSE 0 END)  AS RatingFromNoShow_DQ,
            SUM(CASE WHEN a.IsStarted=1 AND a.IsDisqualified=0 THEN ISNULL(a.Rating,0) ELSE 0 END) AS RatingFromRealPlay,
            SUM(ISNULL(a.Rating,0))                                                           AS RatingNetDelta,
            SUM(CASE WHEN a.Place=1 THEN 1 ELSE 0 END)                                        AS Gold,
            SUM(CASE WHEN a.Place=2 THEN 1 ELSE 0 END)                                        AS Silver,
            SUM(CASE WHEN a.Place=3 THEN 1 ELSE 0 END)                                        AS Bronze,
            SUM(CASE WHEN a.IsDisqualified=1 THEN 1 ELSE 0 END)                               AS Disqualifications,
            SUM(CASE WHEN a.IsStarted=1 AND a.IsDisqualified=0 AND a.BracketId=1 THEN 1 ELSE 0 END) AS PlayN,
            SUM(CASE WHEN a.IsStarted=1 AND a.IsDisqualified=0 AND a.BracketId=2 THEN 1 ELSE 0 END) AS PlayM,
            SUM(CASE WHEN a.IsStarted=1 AND a.IsDisqualified=0 AND a.BracketId=3 THEN 1 ELSE 0 END) AS PlayT,
            SUM(CASE WHEN a.Place<=3 AND a.BracketId=1 THEN 1 ELSE 0 END)                     AS PrzN,
            SUM(CASE WHEN a.Place<=3 AND a.BracketId=2 THEN 1 ELSE 0 END)                     AS PrzM,
            SUM(CASE WHEN a.Place<=3 AND a.BracketId=3 THEN 1 ELSE 0 END)                     AS PrzT,
            SUM(CASE WHEN a.Place IN (1,2,3) THEN 1 ELSE 0 END)                               AS TotalPrizes
        FROM Activity a GROUP BY a.UserId
        HAVING SUM(CASE WHEN a.IsStarted=0 THEN 1 ELSE 0 END) >= @MinNoShows
           AND CAST(SUM(CASE WHEN a.IsStarted=0 THEN 1 ELSE 0 END)*100.0/NULLIF(COUNT(*),0) AS decimal(6,2)) >= @MinNoShowSharePct
           AND SUM(CASE WHEN a.IsStarted=0 OR a.IsDisqualified=1 THEN ISNULL(a.Rating,0) ELSE 0 END) <= @MaxRatingFromNoShow
           AND SUM(CASE WHEN a.Place IN (1,2,3) THEN 1 ELSE 0 END) >= @MinTotalPrizes
    )
    SELECT
        -- ---- old report fields (week2-comparison.sql order) ----
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
        TRY_CAST(JSON_VALUE(pr.StatsJson, '$.GenericStats.CompWon.Count') AS int)     AS LifetimeGold,
        TRY_CAST(JSON_VALUE(pr.StatsJson, '$.GenericStats.Comp2nd.Count') AS int)     AS LifetimeSilver,
        TRY_CAST(JSON_VALUE(pr.StatsJson, '$.GenericStats.Comp3rd.Count') AS int)     AS LifetimeBronze,
        -- ---- NEW: per-bracket play + prizes, concatenated N/M/T (1=NOOBS 2=MIDDLES 3=TOPS) ----
        CONCAT(ag.PlayN, ' / ', ag.PlayM, ' / ', ag.PlayT)                               AS Played_NMT,
        CONCAT(ag.PrzN,  ' / ', ag.PrzM,  ' / ', ag.PrzT)                                AS Prizes_NMT,
        ag.TotalPrizes,
        -- ---- ban status / verdict, moved to the very end ----
        pr.IsCompetitionsBanned                                                      AS IsBanned,
        pr.CompetitionsBanEndDate                                                    AS BanEnd,
        CASE WHEN ISNULL(pr.IsCompetitionsBanned,0)=0 THEN 'NEW'
             WHEN pr.CompetitionsBanEndDate IS NOT NULL AND pr.CompetitionsBanEndDate <= GETUTCDATE() THEN 'REPEAT'
             ELSE 'BANNED' END                                                       AS Verdict
    FROM Aggregate ag
    LEFT JOIN Users    u  WITH (NOLOCK) ON u.UserId  = ag.UserId
    LEFT JOIN Profiles pr WITH (NOLOCK) ON pr.UserId = ag.UserId
    ORDER BY ag.TotalPrizes DESC, ag.NoShows DESC;
END;
