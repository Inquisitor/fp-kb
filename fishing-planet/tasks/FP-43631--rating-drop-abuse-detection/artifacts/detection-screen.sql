-- FP-43631 — Community&Support violators report (rating-drop abuse cohort). Run on each platform PROD MAIN.
-- ============================================================================
-- This is a SCREEN, not a verdict: a broad first pass that deliberately over-selects and hands
-- everything it catches to the per-candidate review.
--
-- SCREENING CRITERIA (week-18: the drain counts every unproductive registration, not just absence)
--   Unproductive            = NoShows + ZeroScore   (DQ excluded -- a DQ follows a ban, so those
--                             accounts are already decided and counting them only adds noise)
--   Unproductive            >= 6
--   UnproductiveSharePct    >= 30
--   RatingFromUnproductive  <= -90
--   TotalPrizes             >  3
--
-- Why zero-score counts: rating is shed just as well by entering and catching nothing as by not
-- appearing, at roughly half the cost per event, so the player simply needs about twice as many.
-- Measured over August on all three platforms, the drain-inclusive criteria raised recall on
-- capable bottom-bracket harvesters from 70/109 to 91/109 with nothing lost, at about a third
-- more candidates per cycle. A 35% share threshold was measured and rejected -- it saved one
-- review slot and lost one such account. FP-45377 abolishes NoShowRatingPenalty entirely, after
-- which the zero-score finish is the only remaining route.
--
-- BRACKET SPLITS COME FROM RATING, NOT FROM BracketId (week-17). TournamentParticipants.BracketId
-- is the bucket after matchmaking balancing -- undersized buckets pull from neighbours and then
-- merge -- so it is not the player's rating band. Played_NMT and Prizes_NMT below are computed
-- from CompetitionRatingAtStart (FP-43816), which is exact where present but is NOT always
-- populated, prize rows included (corrected week-20 -- AppL33 lost 2 plays and 1 prize from the
-- split). The BracketCoverage column below reports the shortfall and the parser recovers the
-- missing brackets from the ledger PCR chain.
--
-- Verdict:
--   NEW    — never competition-banned
--   REPEAT — has a competition ban that already EXPIRED (re-offending). There is no date
--            condition here and there cannot be one: Profiles carries only the END date, so a
--            long pre-launch ban is indistinguishable from a recent one. The tariff does not ask
--            what the prior ban was for -- see step 6 of the methodology
--   BANNED — currently competition-banned (by us this cycle, or a prior active ban)
--
-- N/M/T = NOOBS (rating <= 100) / MIDDLES (101-1000) / TOPS (1001+), each a single "N / M / T"
-- string (spaces around the slash on purpose — "8/12/0" gets auto-parsed as a date by Sheets):
--   Played_NMT — competitions actually PLAYED per band, i.e. where they compete
--   Prizes_NMT — prizes (Place<=3) per band, i.e. where they cash
--
-- Already-banned players are NOT excluded — Verdict (trailing) classifies them so Support sees recidivism.
BEGIN
    DECLARE @WindowStart                 datetime     = '2026-09-14';   -- the window's Monday, 00:00
    DECLARE @WindowEnd                   datetime     = '2026-09-21';   -- the following Monday, 00:00 (exclusive)
    DECLARE @MinUnproductive             int          = 6;
    DECLARE @MinUnproductiveSharePct     decimal(6,2) = 30.00;
    DECLARE @MaxRatingFromUnproductive   int          = -90;
    DECLARE @MinTotalPrizes              int          = 4;

    -- A competition belongs to the week in which it ENDS, and that agrees with the board
    -- (established week-20 on competition 331553: it ran Sun 22:00 -> Mon 00:00 and both its
    -- winners carry those wins in the following period). The agreement is not by design --
    -- UpdateCompetitiveLeaderboards() never receives the tournament and derives the period from
    -- UtcNow when the row is written -- it holds because the scheduled end path writes 2 seconds
    -- after EndDate, and the deferred review path is never reached for KindId=3 (IsResultReviewed
    -- is not a column and is assigned nowhere). Screen and board diverge only under a processing
    -- stall, i.e. an incident. Filtering on StartDate selected a different set from the board: it
    -- pulled in the Sunday 22:00 competition that belongs to the next week, and dropped the
    -- previous Sunday's, which belongs to this one. Measured on week-19 Steam: 83 competitions on
    -- each side of the change, differing by 1 candidate at each end -- and the one the old filter
    -- missed was a returning WATCH.
    --
    -- @WindowEnd also gives the window an upper bound, which it never had. Without one the screen's
    -- span depended on when the script was run: re-running the week-19 window on 2026-09-20 returned
    -- 91 registrations for a candidate who had 33. That is the mechanism behind the contaminated
    -- post-ban re-run recorded in week-18.
    WITH Window AS (
        SELECT t.TournamentId FROM Tournaments t WITH (NOLOCK)
        WHERE t.EndDate >= @WindowStart AND t.EndDate < @WindowEnd
          AND t.KindId=3 AND t.IsEnded=1 AND t.IsCanceled=0 AND ISNULL(t.IsDeleted,0)=0
    ),
    Activity AS (
        SELECT p.UserId, p.IsStarted, p.IsDisqualified, p.CompetitionRatingAtStart AS RatingAtStart,
               r.Place, r.Score, r.SecondaryScore, r.Rating,
               CASE WHEN p.IsStarted=1 AND p.IsDisqualified=0
                     AND ISNULL(r.Score,0)=0 AND ISNULL(r.SecondaryScore,0)=0 THEN 1 ELSE 0 END AS IsZeroScore,
               CASE WHEN p.IsStarted=0
                     OR (p.IsStarted=1 AND p.IsDisqualified=0
                         AND ISNULL(r.Score,0)=0 AND ISNULL(r.SecondaryScore,0)=0) THEN 1 ELSE 0 END AS IsUnproductive
        FROM TournamentParticipants p WITH (NOLOCK)
        INNER JOIN Window w ON w.TournamentId=p.TournamentId
        LEFT JOIN TournamentIndividualResults r WITH (NOLOCK) ON r.TournamentId=p.TournamentId AND r.UserId=p.UserId
    ),
    Aggregate AS (
        SELECT a.UserId,
            COUNT(*)                                                                          AS Registrations,
            SUM(CASE WHEN a.IsStarted=1 AND a.IsDisqualified=0 THEN 1 ELSE 0 END)             AS Started,
            SUM(a.IsZeroScore)                                                                AS ZeroScore,
            SUM(CASE WHEN a.IsStarted=0 THEN 1 ELSE 0 END)                                    AS NoShows,
            SUM(a.IsUnproductive)                                                             AS Unproductive,
            CAST(SUM(a.IsUnproductive)*100.0/NULLIF(COUNT(*),0) AS decimal(6,2))              AS UnproductiveSharePct,
            CAST(SUM(CASE WHEN a.IsStarted=0 THEN 1 ELSE 0 END)*100.0/NULLIF(COUNT(*),0) AS decimal(6,2)) AS NoShowSharePct,
            SUM(CASE WHEN a.IsUnproductive=1 THEN ISNULL(a.Rating,0) ELSE 0 END)              AS RatingFromUnproductive,
            SUM(CASE WHEN a.IsStarted=0 OR a.IsDisqualified=1 THEN ISNULL(a.Rating,0) ELSE 0 END) AS RatingFromNoShow_DQ,
            SUM(CASE WHEN a.IsStarted=1 AND a.IsDisqualified=0 AND a.IsZeroScore=0
                     THEN ISNULL(a.Rating,0) ELSE 0 END)                                      AS RatingFromProductivePlay,
            SUM(ISNULL(a.Rating,0))                                                           AS RatingNetDelta,
            SUM(CASE WHEN a.Place=1 THEN 1 ELSE 0 END)                                        AS Gold,
            SUM(CASE WHEN a.Place=2 THEN 1 ELSE 0 END)                                        AS Silver,
            SUM(CASE WHEN a.Place=3 THEN 1 ELSE 0 END)                                        AS Bronze,
            SUM(CASE WHEN a.IsDisqualified=1 THEN 1 ELSE 0 END)                               AS Disqualifications,
            -- Diagnostics for the BracketCoverage self-check below. Expected 0 on both; carried
            -- for one cycle to prove that the prize predicates can be aligned safely.
            SUM(CASE WHEN a.Place=0 THEN 1 ELSE 0 END)                                        AS PlaceZero,
            SUM(CASE WHEN a.IsDisqualified=1 AND a.Place IN (1,2,3) THEN 1 ELSE 0 END)        AS DqWithPlace,
            SUM(CASE WHEN a.IsStarted=1 AND a.IsDisqualified=0 AND a.RatingAtStart<=100 THEN 1 ELSE 0 END)              AS PlayN,
            SUM(CASE WHEN a.IsStarted=1 AND a.IsDisqualified=0 AND a.RatingAtStart BETWEEN 101 AND 1000 THEN 1 ELSE 0 END) AS PlayM,
            SUM(CASE WHEN a.IsStarted=1 AND a.IsDisqualified=0 AND a.RatingAtStart>=1001 THEN 1 ELSE 0 END)             AS PlayT,
            -- Place IN (1,2,3), not Place<=3: the two must use the identical predicate or the
            -- BracketCoverage check below can go negative on a Place=0 row and mask a real
            -- shortfall. Prz* are not in the HAVING clause, so aligning them cannot move the cohort.
            SUM(CASE WHEN a.Place IN (1,2,3) AND a.RatingAtStart<=100 THEN 1 ELSE 0 END)                 AS PrzN,
            SUM(CASE WHEN a.Place IN (1,2,3) AND a.RatingAtStart BETWEEN 101 AND 1000 THEN 1 ELSE 0 END) AS PrzM,
            SUM(CASE WHEN a.Place IN (1,2,3) AND a.RatingAtStart>=1001 THEN 1 ELSE 0 END)                AS PrzT,
            SUM(CASE WHEN a.Place IN (1,2,3) THEN 1 ELSE 0 END)                               AS TotalPrizes,
            MAX(a.RatingAtStart)                                                              AS MaxRatingAtStart
        FROM Activity a GROUP BY a.UserId
        HAVING SUM(a.IsUnproductive) >= @MinUnproductive
           AND CAST(SUM(a.IsUnproductive)*100.0/NULLIF(COUNT(*),0) AS decimal(6,2)) >= @MinUnproductiveSharePct
           AND SUM(CASE WHEN a.IsUnproductive=1 THEN ISNULL(a.Rating,0) ELSE 0 END) <= @MaxRatingFromUnproductive
           AND SUM(CASE WHEN a.Place IN (1,2,3) THEN 1 ELSE 0 END) >= @MinTotalPrizes
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
        ag.Unproductive,
        ag.UnproductiveSharePct,
        ag.RatingFromUnproductive,
        ag.RatingFromNoShow_DQ,
        ag.RatingFromProductivePlay,
        ag.RatingNetDelta,
        ag.Gold,
        ag.Silver,
        ag.Bronze,
        ag.Disqualifications,
        TRY_CAST(JSON_VALUE(pr.StatsJson, '$.GenericStats.CompWon.Count') AS int)     AS LifetimeGold,
        TRY_CAST(JSON_VALUE(pr.StatsJson, '$.GenericStats.Comp2nd.Count') AS int)     AS LifetimeSilver,
        TRY_CAST(JSON_VALUE(pr.StatsJson, '$.GenericStats.Comp3rd.Count') AS int)     AS LifetimeBronze,
        CONCAT(ag.PlayN, ' / ', ag.PlayM, ' / ', ag.PlayT)                           AS Played_NMT,
        CONCAT(ag.PrzN,  ' / ', ag.PrzM,  ' / ', ag.PrzT)                            AS Prizes_NMT,
        ag.TotalPrizes,
        -- Self-check: the bracket split must reconcile with the totals it is split from.
        -- A non-zero value means rows carry no usable RatingAtStart, so their bracket is simply
        -- absent from Played_NMT / Prizes_NMT -- AppL33 (week-19) lost 2 plays and 1 prize this
        -- way, and the lost prize was the NOOBS one, on the account's first event at PCR 0.
        -- This is a RECOVERY trigger, never a leniency. Unclassified rows are overwhelmingly the
        -- account's earliest events, which are bottom-bracket by definition, so the omission runs
        -- in the candidate's favour every time. The parser resolves the bracket from the ledger
        -- PCR chain and fills the split; an unclassified row is not an argument for the defence
        -- and does not feed evidence_completeness.
        -- DQ is reported separately (Disqualifications, DqWithPlace) and deliberately kept OUT of
        -- this predicate: a non-ok value instructs the parser to recover missing brackets, and a
        -- DQ count is not something to recover.
        CASE WHEN ag.Started = ag.PlayN + ag.PlayM + ag.PlayT
              AND ag.TotalPrizes = ag.PrzN + ag.PrzM + ag.PrzT
             THEN 'ok'
             ELSE CONCAT(ag.Started - (ag.PlayN + ag.PlayM + ag.PlayT), ' play, ',
                         ag.TotalPrizes - (ag.PrzN + ag.PrzM + ag.PrzT), ' prize unclassified')
        END                                                                          AS BracketCoverage,
        ag.PlaceZero,
        ag.DqWithPlace,
        pr.IsCompetitionsBanned                                                      AS IsBanned,
        pr.CompetitionsBanEndDate                                                    AS BanEnd,
        CASE WHEN ISNULL(pr.IsCompetitionsBanned,0)=0 THEN 'NEW'
             WHEN pr.CompetitionsBanEndDate IS NOT NULL AND pr.CompetitionsBanEndDate <= GETUTCDATE() THEN 'REPEAT'
             ELSE 'BANNED' END                                                       AS Verdict,
        ag.MaxRatingAtStart
    FROM Aggregate ag
    LEFT JOIN Users    u  WITH (NOLOCK) ON u.UserId  = ag.UserId
    LEFT JOIN Profiles pr WITH (NOLOCK) ON pr.UserId = ag.UserId
    ORDER BY ag.TotalPrizes DESC, ag.Unproductive DESC;
END;
