-- FP-43631 — URGENT: ban abusers from current weekly Competitive leaderboard before reward distribution
-- ============================================================================
-- Mechanism: CompetitiveRatingsCurrent.IsBanned = 1 → SaveCompetitiveLeaderboardHistory excludes
-- the user from History (filter `WHERE [r].[IsBanned] = 0` in the MERGE), so no reward row gets created.
-- PeriodTypeId values: 1 = Weekly, 2 = Monthly, 3 = Yearly.
-- PeriodId encoding: YYYYMMDD of the Monday that starts the week (e.g. Mon 2026-05-04 → 20260504).
-- Today is 2026-05-11 (Monday). Two weekly periods are in play:
--   - 20260504 (Mon 2026-05-04 - Sun 2026-05-10): just ended; finalizes tonight at the next hourly tick after midnight UTC
--   - 20260511 (Mon 2026-05-11 - Sun 2026-05-17): just started; covers the new week
-- The hourly finalization job runs at MM:07 UTC. Race: ban must complete BEFORE the :07 tick after
-- the week ends rolls through.
--
-- DO NOT USE the `UpdateLeaderboardsBanned` SP — it reads `Users.IsBanned`, and if that is 0
-- (i.e. account not banned), the SP RESETS CompetitiveRatingsCurrent.IsBanned to 0. We need direct UPDATE.


-- FP-43631 Query D — top-N weekly wins leaderboard with no-show abuse markers (decision view)
-- ============================================================================
BEGIN
    DECLARE @PeriodTypeId int      = 1;             -- Weekly
    DECLARE @PeriodId     int      = 20260504;      -- week that just ended (Mon May 4 - Sun May 10)
    --DECLARE @PeriodId     int      = 20260511;    -- current week (Mon May 11 - Sun May 17)
    DECLARE @TopN         int      = 30;            -- show wider net than top 10
    DECLARE @WindowStart  datetime = '2026-04-29';  -- abuse window (matchmaking launch on Steam/EGS)

    -- Decision: who is in the top-N wins-leaderboard right now, and how dirty their no-show pattern is
    SELECT TOP (@TopN)
        DENSE_RANK() OVER (ORDER BY r.CompetitionsWon DESC, r.CompetitionsWonTs, r.CompetitionsWonExp DESC) AS WinsRank,
        r.UserId,
        u.Username,
        u.Source                                                                  AS Platform,
        r.CompetitionsPlayed,
        r.CompetitionsWon,
        r.CompetitionRating                                                       AS PCR_PeriodSum,
        pr.CompetitionRating                                                      AS PCR_Lifetime,
        r.IsBanned,
        pr.IsCompetitionsBanned,
        pr.CompetitionsBanEndDate,

        TRY_CAST(JSON_VALUE(pr.StatsJson, '$.GenericStats.CompWon.Count') AS int) AS LifetimeGold,
        TRY_CAST(JSON_VALUE(pr.StatsJson, '$.GenericStats.Comp2nd.Count') AS int) AS LifetimeSilver,
        TRY_CAST(JSON_VALUE(pr.StatsJson, '$.GenericStats.Comp3rd.Count') AS int) AS LifetimeBronze,

        suspect.Registrations,
        suspect.NoShows,
        suspect.Disqualifications,
        suspect.RatingFromNoShow_DQ,
        suspect.RatingFromRealPlay,
        suspect.NoShowSharePct
    FROM CompetitiveRatingsCurrent r WITH (NOLOCK)
    LEFT JOIN Users    u  WITH (NOLOCK) ON u.UserId  = r.UserId
    LEFT JOIN Profiles pr WITH (NOLOCK) ON pr.UserId = r.UserId
    OUTER APPLY (
        SELECT
            COUNT(*)                                                              AS Registrations,
            SUM(CASE WHEN p.IsStarted = 0 THEN 1 ELSE 0 END)                      AS NoShows,
            SUM(CASE WHEN p.IsDisqualified = 1 THEN 1 ELSE 0 END)                 AS Disqualifications,
            SUM(CASE WHEN p.IsStarted = 0 OR p.IsDisqualified = 1
                     THEN ISNULL(tr.Rating, 0) ELSE 0 END)                        AS RatingFromNoShow_DQ,
            SUM(CASE WHEN p.IsStarted = 1 AND p.IsDisqualified = 0
                     THEN ISNULL(tr.Rating, 0) ELSE 0 END)                        AS RatingFromRealPlay,
            CAST(SUM(CASE WHEN p.IsStarted = 0 THEN 1 ELSE 0 END) * 100.0
                 / NULLIF(COUNT(*), 0) AS decimal(6,2))                           AS NoShowSharePct
        FROM TournamentParticipants p WITH (NOLOCK)
        INNER JOIN Tournaments t WITH (NOLOCK) ON t.TournamentId = p.TournamentId
        LEFT  JOIN TournamentIndividualResults tr WITH (NOLOCK)
            ON tr.TournamentId = p.TournamentId AND tr.UserId = p.UserId
        WHERE p.UserId    = r.UserId
          AND t.StartDate >= @WindowStart
          AND t.KindId    = 3
          AND t.IsEnded   = 1
          AND t.IsCanceled = 0
          AND ISNULL(t.IsDeleted, 0) = 0
    ) suspect
    WHERE r.PeriodTypeId    = @PeriodTypeId
      AND r.PeriodId        = @PeriodId
      AND r.IsBanned        = 0
      AND r.CompetitionsWon > 0
    ORDER BY r.CompetitionsWon DESC, r.CompetitionsWonTs, r.CompetitionsWonExp DESC;
END;

-- STEAM
-- FP-43631 Query E — surgical ban: set IsBanned=1 for the chosen UserIds in current Weekly period
-- ============================================================================
BEGIN
    DECLARE @PeriodTypeId int = 1;          -- Weekly
    DECLARE @PeriodId     int = 20260504;   -- bump to 20260511 for the new week pass

    -- Operation: Ban chosen UserIds from this period's leaderboard
    -- Wrap in TRAN; verify; then COMMIT or ROLLBACK manually
    BEGIN TRAN;

    WITH BanList AS (
        SELECT UserId FROM (VALUES
            -- Replace these placeholders with the actual top-N abusers chosen from Query D
            (CAST('9757FD6A-8435-409A-9F83-33214AF80424' AS uniqueidentifier)), -- StillWaterMind
            (CAST('987DF29C-04D6-4E9E-AAD6-713FF59AD5D5' AS uniqueidentifier)), -- T0BENG
            (CAST('B786FB32-546C-47DB-89CB-85276FFB51F4' AS uniqueidentifier)), -- MVK22
            (CAST('1DFDDFD1-117E-4804-B1D7-C7701B8F4DE6' AS uniqueidentifier)), -- YuJiAn1992
            (CAST('3FBF5EA2-33A6-42BE-88C4-EC7562697EFB' AS uniqueidentifier)), -- Mieza
            (CAST('22737C51-79A1-4632-97E7-7F2B3AF23277' AS uniqueidentifier)), -- xiaoqianying
            (CAST('5CF4B299-F2EB-4FA8-8590-F367FBADB269' AS uniqueidentifier)), -- Mabuk_Laut
            (CAST('F25B7F02-596B-4E53-BFF8-2E684C9552EF' AS uniqueidentifier)), -- BUTOW
            (CAST('38E1578B-354C-43E0-886B-FA6405BE900C' AS uniqueidentifier)), -- LovelyBayLady
            (CAST('C77A50FB-1C16-4CA8-8011-487C3EBC498A' AS uniqueidentifier)), -- IFC_BaysEmperor
            (CAST('CD4A6026-713B-4A9C-995A-8970F18FBD33' AS uniqueidentifier)), -- IkanBobo
            (CAST('A3DBD3A7-5A0A-4610-863A-0AC9260E2A08' AS uniqueidentifier)), -- benimaru67
            (CAST('BDB63435-DA41-4670-901C-CC453BAA704A' AS uniqueidentifier))  -- GamingForza
            -- add more rows: ,(CAST('<guid>' AS uniqueidentifier))
        ) v(UserId)
    )
    UPDATE r
    SET IsBanned = 1
    FROM CompetitiveRatingsCurrent r
    INNER JOIN BanList b ON b.UserId = r.UserId
    WHERE r.PeriodTypeId = @PeriodTypeId
      AND r.PeriodId     = @PeriodId;

    -- Verify rows that were just touched
    SELECT r.PeriodTypeId, r.PeriodId, r.UserId, u.Username, r.IsBanned,
           r.CompetitionsPlayed, r.CompetitionsWon, r.CompetitionRating
    FROM CompetitiveRatingsCurrent r WITH (NOLOCK)
    LEFT JOIN Users u WITH (NOLOCK) ON u.UserId = r.UserId
    WHERE r.PeriodTypeId = @PeriodTypeId
      AND r.PeriodId     = @PeriodId
      AND r.UserId IN (
                       (CAST('9757FD6A-8435-409A-9F83-33214AF80424' AS uniqueidentifier)), -- StillWaterMind
                       (CAST('987DF29C-04D6-4E9E-AAD6-713FF59AD5D5' AS uniqueidentifier)), -- T0BENG
                       (CAST('B786FB32-546C-47DB-89CB-85276FFB51F4' AS uniqueidentifier)), -- MVK22
                       (CAST('1DFDDFD1-117E-4804-B1D7-C7701B8F4DE6' AS uniqueidentifier)), -- YuJiAn1992
                       (CAST('3FBF5EA2-33A6-42BE-88C4-EC7562697EFB' AS uniqueidentifier)), -- Mieza
                       (CAST('22737C51-79A1-4632-97E7-7F2B3AF23277' AS uniqueidentifier)), -- xiaoqianying
                       (CAST('5CF4B299-F2EB-4FA8-8590-F367FBADB269' AS uniqueidentifier)), -- Mabuk_Laut
                       (CAST('F25B7F02-596B-4E53-BFF8-2E684C9552EF' AS uniqueidentifier)), -- BUTOW
                       (CAST('38E1578B-354C-43E0-886B-FA6405BE900C' AS uniqueidentifier)), -- LovelyBayLady
                       (CAST('C77A50FB-1C16-4CA8-8011-487C3EBC498A' AS uniqueidentifier)), -- IFC_BaysEmperor
                       (CAST('CD4A6026-713B-4A9C-995A-8970F18FBD33' AS uniqueidentifier)), -- IkanBobo
                       (CAST('A3DBD3A7-5A0A-4610-863A-0AC9260E2A08' AS uniqueidentifier)), -- benimaru67
                       (CAST('BDB63435-DA41-4670-901C-CC453BAA704A' AS uniqueidentifier))  -- GamingForza
          -- mirror the BanList rows above
      );

    -- If verify shows IsBanned=1 for all expected UserIds → COMMIT;
    -- If anything looks off                            → ROLLBACK;
    -- COMMIT TRAN;
    -- ROLLBACK TRAN;
END;

-- PS
-- FP-43631 Query E — surgical ban: set IsBanned=1 for the chosen UserIds in current Weekly period
-- ============================================================================
BEGIN
    DECLARE @PeriodTypeId int = 1;          -- Weekly
    DECLARE @PeriodId     int = 20260504;   -- bump to 20260511 for the new week pass

    -- Operation: Ban chosen UserIds from this period's leaderboard
    -- Wrap in TRAN; verify; then COMMIT or ROLLBACK manually
    BEGIN TRAN;

    WITH BanList AS (
                        SELECT UserId FROM (VALUES
                                                -- Replace these placeholders with the actual top-N abusers chosen from Query D
                                                (CAST('1637AACD-F05D-4CAB-9248-146D9025CF70' AS uniqueidentifier)), -- QG_LucasBorghi
                                                (CAST('118B21ED-1D89-4A8D-8296-922452775439' AS uniqueidentifier)), -- Sajler_1_
                                                (CAST('EC23E09A-2A18-49CC-9281-E2CEF90753BA' AS uniqueidentifier)), -- ericeazye1967
                                                (CAST('20CCB19B-F17E-433C-8F02-86817CF63830' AS uniqueidentifier)), -- GOTYS-AUF-DIE-1
                                                (CAST('06BB9D34-BC04-4591-80F6-0F8AD8F05087' AS uniqueidentifier)), -- IKIGAI__1__
                                                (CAST('13D1C7C7-1B4D-4A3E-9890-8B4391519EBF' AS uniqueidentifier))  -- Whip-_-FP-_-
                                               -- add more rows: ,(CAST('<guid>' AS uniqueidentifier))
                        ) v(UserId)
    )
    UPDATE r
    SET IsBanned = 1
    FROM CompetitiveRatingsCurrent r
        INNER JOIN BanList b ON b.UserId = r.UserId
    WHERE r.PeriodTypeId = @PeriodTypeId
      AND r.PeriodId     = @PeriodId;

    -- Verify rows that were just touched
    SELECT r.PeriodTypeId, r.PeriodId, r.UserId, u.Username, r.IsBanned,
           r.CompetitionsPlayed, r.CompetitionsWon, r.CompetitionRating
    FROM CompetitiveRatingsCurrent r WITH (NOLOCK)
        LEFT JOIN Users u WITH (NOLOCK) ON u.UserId = r.UserId
    WHERE r.PeriodTypeId = @PeriodTypeId
      AND r.PeriodId     = @PeriodId
      AND r.UserId IN (
                       (CAST('1637AACD-F05D-4CAB-9248-146D9025CF70' AS uniqueidentifier)), -- QG_LucasBorghi
                       (CAST('118B21ED-1D89-4A8D-8296-922452775439' AS uniqueidentifier)), -- Sajler_1_
                       (CAST('EC23E09A-2A18-49CC-9281-E2CEF90753BA' AS uniqueidentifier)), -- ericeazye1967
                       (CAST('20CCB19B-F17E-433C-8F02-86817CF63830' AS uniqueidentifier)), -- GOTYS-AUF-DIE-1
                       (CAST('06BB9D34-BC04-4591-80F6-0F8AD8F05087' AS uniqueidentifier)), -- IKIGAI__1__
                       (CAST('13D1C7C7-1B4D-4A3E-9890-8B4391519EBF' AS uniqueidentifier))  -- Whip-_-FP-_-
        -- mirror the BanList rows above
        );

    -- If verify shows IsBanned=1 for all expected UserIds → COMMIT;
    -- If anything looks off                            → ROLLBACK;
    -- COMMIT TRAN;
    -- ROLLBACK TRAN;
END;

-- XB
-- FP-43631 Query E — surgical ban: set IsBanned=1 for the chosen UserIds in current Weekly period
-- ============================================================================
BEGIN
    DECLARE @PeriodTypeId int = 1;          -- Weekly
    DECLARE @PeriodId     int = 20260504;   -- bump to 20260511 for the new week pass

    -- Operation: Ban chosen UserIds from this period's leaderboard
    -- Wrap in TRAN; verify; then COMMIT or ROLLBACK manually
    BEGIN TRAN;

    WITH BanList AS (
                        SELECT UserId FROM (VALUES
                                                -- Replace these placeholders with the actual top-N abusers chosen from Query D
                                                (CAST('5B1825F5-C5D0-4F3E-9962-E4D4E5E8D019' AS uniqueidentifier)), -- JackPot6077
                                                (CAST('93146A41-D7D2-4434-A35E-5A1BFEF40CB8' AS uniqueidentifier)), -- SCATTER FS
                                                (CAST('9439D534-3527-4D9C-A2D0-0B3DF836B572' AS uniqueidentifier)), -- RaidedBYoff
                                                (CAST('18494A55-D471-40DB-955C-4BC1F0CB633E' AS uniqueidentifier)), -- Buckslayer86433
                                                (CAST('E81A2739-534A-4299-80E7-7BF54B573BE8' AS uniqueidentifier)), -- nggaaah
                                                (CAST('69DF2685-BBE6-4584-95AE-17EC7606C12C' AS uniqueidentifier)), -- Vexmy69
                                                (CAST('25042CF9-B59B-4AE5-AA61-1C7FBA97828F' AS uniqueidentifier)), -- AS SZATANOS
                                                (CAST('87D7E8F8-C89C-4E0D-B0FB-F41C1BC42AF6' AS uniqueidentifier)), -- SmirkyWord9283
                                                (CAST('86368609-B05B-45F5-9979-7E65838C9113' AS uniqueidentifier)), -- HappyHoodz
                                                (CAST('013368D1-E8A8-437A-88B0-71059E3287EB' AS uniqueidentifier))  -- BuzzingLemur417
                                               -- add more rows: ,(CAST('<guid>' AS uniqueidentifier))
                        ) v(UserId)
    )
    UPDATE r
    SET IsBanned = 1
    FROM CompetitiveRatingsCurrent r
        INNER JOIN BanList b ON b.UserId = r.UserId
    WHERE r.PeriodTypeId = @PeriodTypeId
      AND r.PeriodId     = @PeriodId;

    -- Verify rows that were just touched
    SELECT r.PeriodTypeId, r.PeriodId, r.UserId, u.Username, r.IsBanned,
           r.CompetitionsPlayed, r.CompetitionsWon, r.CompetitionRating
    FROM CompetitiveRatingsCurrent r WITH (NOLOCK)
        LEFT JOIN Users u WITH (NOLOCK) ON u.UserId = r.UserId
    WHERE r.PeriodTypeId = @PeriodTypeId
      AND r.PeriodId     = @PeriodId
      AND r.UserId IN (
                       (CAST('5B1825F5-C5D0-4F3E-9962-E4D4E5E8D019' AS uniqueidentifier)), -- JackPot6077
                       (CAST('93146A41-D7D2-4434-A35E-5A1BFEF40CB8' AS uniqueidentifier)), -- SCATTER FS
                       (CAST('9439D534-3527-4D9C-A2D0-0B3DF836B572' AS uniqueidentifier)), -- RaidedBYoff
                       (CAST('18494A55-D471-40DB-955C-4BC1F0CB633E' AS uniqueidentifier)), -- Buckslayer86433
                       (CAST('E81A2739-534A-4299-80E7-7BF54B573BE8' AS uniqueidentifier)), -- nggaaah
                       (CAST('69DF2685-BBE6-4584-95AE-17EC7606C12C' AS uniqueidentifier)), -- Vexmy69
                       (CAST('25042CF9-B59B-4AE5-AA61-1C7FBA97828F' AS uniqueidentifier)), -- AS SZATANOS
                       (CAST('87D7E8F8-C89C-4E0D-B0FB-F41C1BC42AF6' AS uniqueidentifier)), -- SmirkyWord9283
                       (CAST('86368609-B05B-45F5-9979-7E65838C9113' AS uniqueidentifier)), -- HappyHoodz
                       (CAST('013368D1-E8A8-437A-88B0-71059E3287EB' AS uniqueidentifier))  -- BuzzingLemur417
        -- mirror the BanList rows above
        );

    -- If verify shows IsBanned=1 for all expected UserIds → COMMIT;
    -- If anything looks off                            → ROLLBACK;
    -- COMMIT TRAN;
    -- ROLLBACK TRAN;
END;


-- FP-43631 Query F — post-ban sanity check (run after COMMIT to confirm exclusion from leaderboard)
-- ============================================================================
BEGIN
    DECLARE @PeriodTypeId int      = 1;
    DECLARE @PeriodId     int      = 20260504;
    DECLARE @TopN         int      = 15;
    -- DECLARE @WindowStart  datetime = '2026-04-29';
    -- DECLARE @WindowStart  datetime = '2026-05-06';
    DECLARE @WindowStart  datetime = '2026-05-07';

    -- Verify: top-N wins-leaderboard AFTER ban — banned users must not appear; abuse stats + lifetime context inline
    SELECT TOP (@TopN)
        DENSE_RANK() OVER (ORDER BY r.CompetitionsWon DESC, r.CompetitionsWonTs, r.CompetitionsWonExp DESC) AS WinsRank,
        r.UserId,
        u.Username,
        r.CompetitionsPlayed,
        r.CompetitionsWon,
        r.CompetitionRating                                                                                  AS PCR_PeriodSum,
        pr.CompetitionRating                                                                                 AS PCR_Lifetime,
        r.IsBanned,
        pr.IsCompetitionsBanned,
        TRY_CAST(JSON_VALUE(pr.StatsJson, '$.GenericStats.CompWon.Count') AS int)                            AS LifetimeGold,
        TRY_CAST(JSON_VALUE(pr.StatsJson, '$.GenericStats.Comp2nd.Count') AS int)                            AS LifetimeSilver,
        TRY_CAST(JSON_VALUE(pr.StatsJson, '$.GenericStats.Comp3rd.Count') AS int) AS LifetimeBronze,
        suspect.Registrations,
        suspect.NoShows,
        suspect.NoShowSharePct,
        suspect.RatingFromNoShow_DQ,
        suspect.RatingFromRealPlay,
        suspect.RatingNetDelta
    FROM CompetitiveRatingsCurrent r WITH (NOLOCK)
    LEFT JOIN Users    u  WITH (NOLOCK) ON u.UserId  = r.UserId
    LEFT JOIN Profiles pr WITH (NOLOCK) ON pr.UserId = r.UserId
    OUTER APPLY (
        SELECT
            COUNT(*)                                                              AS Registrations,
            SUM(CASE WHEN p.IsStarted = 0 THEN 1 ELSE 0 END)                      AS NoShows,
            SUM(CASE WHEN p.IsStarted = 0 OR p.IsDisqualified = 1
                     THEN ISNULL(tr.Rating, 0) ELSE 0 END)                        AS RatingFromNoShow_DQ,
            SUM(CASE WHEN p.IsStarted = 1 AND p.IsDisqualified = 0
                     THEN ISNULL(tr.Rating, 0) ELSE 0 END)                        AS RatingFromRealPlay,
            SUM(ISNULL(tr.Rating, 0))                                             AS RatingNetDelta,
            CAST(SUM(CASE WHEN p.IsStarted = 0 THEN 1 ELSE 0 END) * 100.0
                 / NULLIF(COUNT(*), 0) AS decimal(6,2))                           AS NoShowSharePct
        FROM TournamentParticipants p WITH (NOLOCK)
        INNER JOIN Tournaments t WITH (NOLOCK) ON t.TournamentId = p.TournamentId
        LEFT  JOIN TournamentIndividualResults tr WITH (NOLOCK)
            ON tr.TournamentId = p.TournamentId AND tr.UserId = p.UserId
        WHERE p.UserId    = r.UserId
          AND t.StartDate >= @WindowStart
          AND t.KindId    = 3
          AND t.IsEnded   = 1
          AND t.IsCanceled = 0
          AND ISNULL(t.IsDeleted, 0) = 0
    ) suspect
    WHERE r.PeriodTypeId    = @PeriodTypeId
      AND r.PeriodId        = @PeriodId
      AND r.IsBanned        = 0
      AND r.CompetitionsWon > 0
    ORDER BY r.CompetitionsWon DESC, r.CompetitionsWonTs, r.CompetitionsWonExp DESC;
END;


-- FP-43631 Query G — post-finalize verification: top-N who actually received reward in the period
-- ============================================================================
-- Reads CompetitiveRating*History (post-cleanup-safe). Banned users were never inserted →
-- their absence here confirms the ban worked.
BEGIN
    DECLARE @PeriodId          int = 20260504;
    DECLARE @TournamentKindId  int = 3;   -- Competition
    DECLARE @DimensionTypeId   int = 2;   -- 1=Played, 2=Won, 3=Rating (verify per platform if unsure)
    DECLARE @TopN              int = 15;

    -- Verify: who got the reward for this Weekly period
    SELECT TOP (@TopN)
        h.Place,
        h.UserId,
        u.Username,
        h.Value          AS Wins,
        h.RewardId,
        h.RewardJson,
        h.ClubPoints
    FROM CompetitiveRatingWeeklyHistory h WITH (NOLOCK)
    LEFT JOIN Users u WITH (NOLOCK) ON u.UserId = h.UserId
    WHERE h.PeriodId         = @PeriodId
      AND h.TournamentKindId = @TournamentKindId
      AND h.DimensionTypeId  = @DimensionTypeId
    ORDER BY h.Place;
END;
