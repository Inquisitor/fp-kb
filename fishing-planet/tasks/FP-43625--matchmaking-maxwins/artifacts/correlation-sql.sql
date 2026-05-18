-- FP-43625 Q0 -- Inventory: active templates and future Competitions with Grouping -- per platform
BEGIN
    SELECT 'TournamentTemplates' AS [Source],
           COUNT(*) AS Total,
           SUM(CASE WHEN tt.KindId = 3 THEN 1 ELSE 0 END) AS CompetitionTotal,
           SUM(CASE WHEN tt.KindId = 3 AND JSON_QUERY(tt.ConfigJson, '$.Grouping') IS NOT NULL THEN 1 ELSE 0 END) AS WithGrouping
    FROM dbo.TournamentTemplates tt WITH (NOLOCK)
    UNION ALL
    SELECT 'Tournaments (future, EndDate > now)',
           COUNT(*),
           SUM(CASE WHEN t.KindId = 3 THEN 1 ELSE 0 END),
           SUM(CASE WHEN t.KindId = 3 AND JSON_QUERY(t.ConfigJson, '$.Grouping') IS NOT NULL THEN 1 ELSE 0 END)
    FROM dbo.Tournaments t WITH (NOLOCK)
    WHERE t.EndDate > SYSUTCDATETIME();
END
GO
-- Run per platform on [F2P] STEAM/PS/XB PROD MAIN to size the migration.
-- Snapshot 2026-05-17: Steam 103 templates + 151 future Comps; PS 103 + 151;
-- Xbox 103 + 152. The 29 inactive templates per platform carry no Grouping and
-- are filtered out automatically.


-- FP-43625 Q1 -- Per-user (PCR, Gold, Silver, Bronze) scatter export -- raw data
BEGIN
    IF OBJECT_ID('tempdb..#CompetitiveUsers') IS NOT NULL DROP TABLE #CompetitiveUsers;

    SELECT UserId
    INTO   #CompetitiveUsers
    FROM (
        SELECT tp.UserId
        FROM   dbo.TournamentParticipants tp WITH (NOLOCK)
        JOIN   dbo.Tournaments            t  WITH (NOLOCK) ON t.TournamentId = tp.TournamentId
        WHERE  t.KindId = 3
        UNION
        SELECT atp.UserId
        FROM   dbo.ArchiveTournamentParticipants atp WITH (NOLOCK)
        JOIN   dbo.ArchiveTournaments            at  WITH (NOLOCK) ON at.TournamentId = atp.TournamentId
        WHERE  at.KindId = 3
    ) cu;
    CREATE UNIQUE CLUSTERED INDEX IX_CompetitiveUsers ON #CompetitiveUsers(UserId);

    SELECT  p.UserId,
            p.CompetitionRating                                                                  AS PCR,
            ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.CompWon.Count') AS int), 0) AS Gold,
            ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.Comp2nd.Count') AS int), 0) AS Silver,
            ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.Comp3rd.Count') AS int), 0) AS Bronze,
            CASE
                WHEN p.CompetitionRating <= 100  THEN 'Newbies'
                WHEN p.CompetitionRating <= 1000 THEN 'Middles'
                ELSE                                  'Tops'
            END                                                                                  AS CurrentBracket
    FROM    dbo.Profiles       p  WITH (NOLOCK)
    JOIN    #CompetitiveUsers  cu                ON cu.UserId = p.UserId
    ORDER BY p.CompetitionRating, p.UserId;

    DROP TABLE #CompetitiveUsers;
END
GO
-- Bracket boundaries: Newbies 0..100, Middles 101..1000, Tops 1001+.
-- Counters live in Profiles.StatsJson.$.GenericStats.{CompWon|Comp2nd|Comp3rd}.Count,
-- incremented only inside the KindId == Competition branch
-- (GameClientPeer_Tournaments). Sport tournaments do not contaminate.
-- #CompetitiveUsers = anyone with at least one registration for a KindId=3
-- tournament across TournamentParticipants + ArchiveTournamentParticipants.


-- FP-43625 Q2 -- Bracket histogram by GD-spec thresholds -- impact preview
BEGIN
    IF OBJECT_ID('tempdb..#CompetitiveUsers') IS NOT NULL DROP TABLE #CompetitiveUsers;

    SELECT UserId
    INTO   #CompetitiveUsers
    FROM (
        SELECT tp.UserId
        FROM   dbo.TournamentParticipants tp WITH (NOLOCK)
        JOIN   dbo.Tournaments            t  WITH (NOLOCK) ON t.TournamentId = tp.TournamentId
        WHERE  t.KindId = 3
        UNION
        SELECT atp.UserId
        FROM   dbo.ArchiveTournamentParticipants atp WITH (NOLOCK)
        JOIN   dbo.ArchiveTournaments            at  WITH (NOLOCK) ON at.TournamentId = atp.TournamentId
        WHERE  at.KindId = 3
    ) cu;
    CREATE UNIQUE CLUSTERED INDEX IX_CompetitiveUsers ON #CompetitiveUsers(UserId);

    ;WITH scoped AS (
        SELECT  CASE
                    WHEN p.CompetitionRating <= 100  THEN 'Newbies'
                    WHEN p.CompetitionRating <= 1000 THEN 'Middles'
                    ELSE                                  'Tops'
                END                                                                                  AS CurrentBracket,
                ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.CompWon.Count') AS int), 0) AS Gold,
                ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.Comp2nd.Count') AS int), 0) AS Silver,
                ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.Comp3rd.Count') AS int), 0) AS Bronze
        FROM    dbo.Profiles       p  WITH (NOLOCK)
        JOIN    #CompetitiveUsers  cu                ON cu.UserId = p.UserId
    )
    SELECT  CurrentBracket,
            COUNT(*)                                                                       AS Total,
            SUM(CASE WHEN Gold   >= 3  THEN 1 ELSE 0 END)                                  AS GoldGE_3,
            SUM(CASE WHEN Gold   >= 12 THEN 1 ELSE 0 END)                                  AS GoldGE_12,
            SUM(CASE WHEN Silver >= 4  THEN 1 ELSE 0 END)                                  AS SilverGE_4,
            SUM(CASE WHEN Silver >= 15 THEN 1 ELSE 0 END)                                  AS SilverGE_15,
            SUM(CASE WHEN Bronze >= 5  THEN 1 ELSE 0 END)                                  AS BronzeGE_5,
            SUM(CASE WHEN Bronze >= 20 THEN 1 ELSE 0 END)                                  AS BronzeGE_20,
            SUM(CASE WHEN (Gold >= 3  OR Silver >= 4  OR Bronze >= 5)  THEN 1 ELSE 0 END)  AS WouldPromoteFromNewbies,
            SUM(CASE WHEN (Gold >= 12 OR Silver >= 15 OR Bronze >= 20) THEN 1 ELSE 0 END)  AS WouldPromoteFromMiddles
    FROM    scoped
    GROUP BY CurrentBracket
    ORDER BY
            CASE CurrentBracket WHEN 'Newbies' THEN 1 WHEN 'Middles' THEN 2 WHEN 'Tops' THEN 3 END;

    DROP TABLE #CompetitiveUsers;
END
GO
-- In the Newbies row, WouldPromoteFromNewbies = how many Newbies-PCR players
-- would be promoted out by the current GD-spec thresholds (3/4/5). In the
-- Middles row, WouldPromoteFromMiddles = how many Middles-PCR players would be
-- promoted to Tops by 12/15/20. Tops row is unaffected (no MaxWins on Tops).


-- FP-43625 Q3 -- Counter percentiles per bracket -- guides threshold choice
BEGIN
    IF OBJECT_ID('tempdb..#CompetitiveUsers') IS NOT NULL DROP TABLE #CompetitiveUsers;

    SELECT UserId
    INTO   #CompetitiveUsers
    FROM (
        SELECT tp.UserId
        FROM   dbo.TournamentParticipants tp WITH (NOLOCK)
        JOIN   dbo.Tournaments            t  WITH (NOLOCK) ON t.TournamentId = tp.TournamentId
        WHERE  t.KindId = 3
        UNION
        SELECT atp.UserId
        FROM   dbo.ArchiveTournamentParticipants atp WITH (NOLOCK)
        JOIN   dbo.ArchiveTournaments            at  WITH (NOLOCK) ON at.TournamentId = atp.TournamentId
        WHERE  at.KindId = 3
    ) cu;
    CREATE UNIQUE CLUSTERED INDEX IX_CompetitiveUsers ON #CompetitiveUsers(UserId);

    ;WITH scoped AS (
        SELECT  CASE
                    WHEN p.CompetitionRating <= 100  THEN 'Newbies'
                    WHEN p.CompetitionRating <= 1000 THEN 'Middles'
                    ELSE                                  'Tops'
                END                                                                                  AS CurrentBracket,
                ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.CompWon.Count') AS int), 0) AS Gold,
                ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.Comp2nd.Count') AS int), 0) AS Silver,
                ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.Comp3rd.Count') AS int), 0) AS Bronze
        FROM    dbo.Profiles       p  WITH (NOLOCK)
        JOIN    #CompetitiveUsers  cu                ON cu.UserId = p.UserId
    )
    SELECT DISTINCT
            CurrentBracket,
            PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY Gold)   OVER (PARTITION BY CurrentBracket) AS Gold_p50,
            PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Gold)   OVER (PARTITION BY CurrentBracket) AS Gold_p75,
            PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY Gold)   OVER (PARTITION BY CurrentBracket) AS Gold_p90,
            PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY Gold)   OVER (PARTITION BY CurrentBracket) AS Gold_p95,
            PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY Gold)   OVER (PARTITION BY CurrentBracket) AS Gold_p99,
            PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY Silver) OVER (PARTITION BY CurrentBracket) AS Silver_p50,
            PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY Silver) OVER (PARTITION BY CurrentBracket) AS Silver_p95,
            PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY Silver) OVER (PARTITION BY CurrentBracket) AS Silver_p99,
            PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY Bronze) OVER (PARTITION BY CurrentBracket) AS Bronze_p50,
            PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY Bronze) OVER (PARTITION BY CurrentBracket) AS Bronze_p95,
            PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY Bronze) OVER (PARTITION BY CurrentBracket) AS Bronze_p99
    FROM    scoped
    ORDER BY
            CASE CurrentBracket WHEN 'Newbies' THEN 1 WHEN 'Middles' THEN 2 WHEN 'Tops' THEN 3 END;

    DROP TABLE #CompetitiveUsers;
END
GO
-- If Gold_p95 in Newbies is 2, then GD-spec MaxWins=3 promotes only the top
-- ~5% of Newbies (likely abuser cohort). If Gold_p95 is 5, the threshold is
-- too lax and lets 95% of true abusers through. Use to triangulate whether
-- 3/4/5 and 12/15/20 are right, too tight, or too loose for the actual
-- prod distribution.


-- FP-43625 Q4 -- Top abusers preview -- highest podium-to-PCR ratio in Newbies
BEGIN
    IF OBJECT_ID('tempdb..#CompetitiveUsers') IS NOT NULL DROP TABLE #CompetitiveUsers;

    SELECT UserId
    INTO   #CompetitiveUsers
    FROM (
        SELECT tp.UserId
        FROM   dbo.TournamentParticipants tp WITH (NOLOCK)
        JOIN   dbo.Tournaments            t  WITH (NOLOCK) ON t.TournamentId = tp.TournamentId
        WHERE  t.KindId = 3
        UNION
        SELECT atp.UserId
        FROM   dbo.ArchiveTournamentParticipants atp WITH (NOLOCK)
        JOIN   dbo.ArchiveTournaments            at  WITH (NOLOCK) ON at.TournamentId = atp.TournamentId
        WHERE  at.KindId = 3
    ) cu;
    CREATE UNIQUE CLUSTERED INDEX IX_CompetitiveUsers ON #CompetitiveUsers(UserId);

    SELECT TOP 50
            p.UserId,
            p.CompetitionRating                                                                       AS PCR,
            ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.CompWon.Count')        AS int), 0) AS Gold,
            ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.Comp2nd.Count')        AS int), 0) AS Silver,
            ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.Comp3rd.Count')        AS int), 0) AS Bronze,
            ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.CompPartCount.Count')  AS int), 0) AS TotalParticipations
    FROM    dbo.Profiles       p  WITH (NOLOCK)
    JOIN    #CompetitiveUsers  cu                ON cu.UserId = p.UserId
    WHERE   p.CompetitionRating <= 100
      AND   ( ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.CompWon.Count') AS int), 0) >= 3
           OR ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.Comp2nd.Count') AS int), 0) >= 4
           OR ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.Comp3rd.Count') AS int), 0) >= 5 )
    ORDER BY (ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.CompWon.Count') AS int), 0) * 5
            + ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.Comp2nd.Count') AS int), 0) * 3
            + ISNULL(TRY_CAST(JSON_VALUE(p.StatsJson, '$.GenericStats.Comp3rd.Count') AS int), 0) * 1) DESC;

    DROP TABLE #CompetitiveUsers;
END
GO
-- Every UserId here would be promoted out of Newbies under the GD-spec
-- thresholds. Cross-reference against the FP-43631 banned cohort
-- (bans-2026-05-11.md) - high overlap = thresholds catch the right people.
