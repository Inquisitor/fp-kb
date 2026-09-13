-- FP-43631 week-18 -- 3-layer post-ban verification
-- ============================================================================
-- Run on EACH platform PROD MAIN. UserIds not present on a given DB report 'not on this DB', which
-- is expected -- the ban list spans three platforms and each database holds only its own.
--
-- Layer 1 (profile)     -- block A
-- Layer 2 (leaderboard) -- blocks A and B; B is the one that matters, see below
-- Layer 3 (Mongo banLog) -- NOT here; checked separately against each platform Mongo.
--
-- WHY BLOCK B EXISTS. The sweep runs on Sunday and CompetitiveRatingsCurrent rolls to the next
-- weekly period around the same time, so a player can carry rows for both the closing week and the
-- new one. A check that only counts banned-vs-not-banned across all rows returns OK when the new
-- week is banned and the CLOSING week -- the one the imminent reward run pays out on -- is not.
-- Block B asserts the closing period explicitly. Weekly PeriodId is the window's Monday as
-- yyyymmdd: closing 20260831, next 20260907.
-- Week-18 note: at verification time the 20260907 rows did not exist yet, so Rows_New = 0 across the
-- board was the correct result this cycle, not a miss.
--
-- WHY BLOCK C EXISTS. Blocks A and B only look at players we banned. Block C sweeps the OTHER
-- direction: it takes the whole reviewed cohort -- including everyone left on WATCH -- and reports
-- any of them standing in a rewarded position of the closing period without a ban. That is the
-- check that would have caught this cycle's real exposure, where the top two extraction positions on
-- Steam and Xbox were held by candidates the first hearing had not convicted.
--
-- Aggregate database-side. The MCP result view truncates at ten rows, so a per-row listing of the
-- ban set across three period types is past the cut and a verdict read off the visible rows is a
-- verdict read off an arbitrary subset. Return counts, not rows.

SET NOCOUNT ON;

BEGIN
    DECLARE @ClosingPeriod int = 20260831;
    DECLARE @NextPeriod    int = 20260907;

    DECLARE @Ban TABLE (UserId uniqueidentifier PRIMARY KEY, Username varchar(64), Platform varchar(16), BanUntil date, Basis varchar(24));
    INSERT INTO @Ban VALUES
        -- trial verdicts, first hearing
        ('51873B16-7A58-4FC6-B234-7F3617C0CE91','Leelos90',        'PS',   '2026-10-05','trial conf 8'),
        ('09BDC8BF-B133-493E-9EBE-E5C145CB0FDE','ST-9257',         'PS',   '2026-10-05','trial conf 8'),
        ('92517835-3C2F-449D-AE3E-1ECEBE9E656A','I JEEPERS I',     'Xbox', '2026-10-05','trial conf 7'),
        ('469DF796-D270-40FF-BAD9-8A5B9D83B6DC','CFC-T-W-T-32568', 'PS',   '2026-11-02','trial conf 9 REPEAT'),
        -- operator override, week-12 leaderboard criterion; both later confirmed by the re-hearing
        ('267A4A3D-0A1D-456C-B766-6FC1891F0C26','seagate22022',    'Steam','2026-10-05','override + rehear 8'),
        ('1C653428-2C77-4F8E-8194-422AA3D63C8F','o Lord Mac o',    'Xbox', '2026-10-05','override + rehear 9'),
        -- re-hearing on the corrected brief
        ('E7B743E8-FBF0-4C6C-8A27-CC333C199BAF','Ilija1982',       'Steam','2026-10-05','rehearing conf 8'),
        ('A7D0B667-2796-462E-9763-2B2ACAF4E2B9','codeco',          'Steam','2026-10-05','rehearing conf 8'),
        ('B8CA6B12-3057-4BBE-9980-53F655FCF065','Myky0576',        'Steam','2026-11-02','rehearing conf 8 REPEAT');

    -- Leelos90 carries a Support ban to 2026-10-03 imposed 2026-09-03. bans-2026-09-06.sql skips him
    -- by design, so his ProfBanEnd is Support's date and not ours. That is a PASS, not a FAIL.

    ---------------------------------------------------------------------------
    -- BLOCK A -- profile layer, per row
    ---------------------------------------------------------------------------
    SELECT b.Platform,
           b.Username,
           b.Basis,
           b.BanUntil                                AS ExpectedBanUntil,
           p.CompetitionsBanEndDate                  AS ActualBanEnd,
           CASE WHEN p.UserId IS NULL THEN 'not on this DB'
                WHEN ISNULL(p.IsCompetitionsBanned,0) = 1
                 AND p.CompetitionsBanEndDate IS NOT NULL
                 AND p.CompetitionsBanEndDate > GETUTCDATE() THEN 'OK'
                ELSE 'FAIL: not effectively banned' END AS Prof_Status,
           p.IsInfluencer,
           p.CompetitionRating                       AS CurrentPCR
    FROM @Ban b
    LEFT JOIN Profiles p WITH (NOLOCK) ON p.UserId = b.UserId
    ORDER BY b.Platform, b.Username;

    ---------------------------------------------------------------------------
    -- BLOCK B -- leaderboard layer, split by period. The closing period is the one that pays.
    ---------------------------------------------------------------------------
    SELECT b.Username,
           SUM(CASE WHEN c.PeriodId = @ClosingPeriod THEN 1 ELSE 0 END)                    AS Rows_Closing,
           SUM(CASE WHEN c.PeriodId = @ClosingPeriod AND c.IsBanned = 1 THEN 1 ELSE 0 END) AS Banned_Closing,
           SUM(CASE WHEN c.PeriodId = @NextPeriod THEN 1 ELSE 0 END)                       AS Rows_Next,
           SUM(CASE WHEN c.PeriodId = @NextPeriod AND c.IsBanned = 1 THEN 1 ELSE 0 END)    AS Banned_Next,
           SUM(CASE WHEN c.PeriodId NOT IN (@ClosingPeriod, @NextPeriod) THEN 1 ELSE 0 END)                    AS Rows_MonthYear,
           SUM(CASE WHEN c.PeriodId NOT IN (@ClosingPeriod, @NextPeriod) AND c.IsBanned = 1 THEN 1 ELSE 0 END) AS Banned_MonthYear,
           CASE WHEN SUM(CASE WHEN c.PeriodId = @ClosingPeriod THEN 1 ELSE 0 END) = 0 THEN 'not on this DB'
                WHEN SUM(CASE WHEN c.PeriodId = @ClosingPeriod THEN 1 ELSE 0 END)
                   = SUM(CASE WHEN c.PeriodId = @ClosingPeriod AND c.IsBanned = 1 THEN 1 ELSE 0 END)
                 AND SUM(CASE WHEN c.PeriodId NOT IN (@ClosingPeriod, @NextPeriod) THEN 1 ELSE 0 END)
                   = SUM(CASE WHEN c.PeriodId NOT IN (@ClosingPeriod, @NextPeriod) AND c.IsBanned = 1 THEN 1 ELSE 0 END)
                THEN 'OK'
                ELSE 'FAIL: closing or month/year row not banned' END AS LB_Status
    FROM @Ban b
    LEFT JOIN CompetitiveRatingsCurrent c WITH (NOLOCK) ON c.UserId = b.UserId
    GROUP BY b.Username
    ORDER BY b.Username;

    ---------------------------------------------------------------------------
    -- BLOCK C -- standing pre-payout sweep over the WHOLE reviewed cohort, banned or not.
    -- Anything returned here is a reviewed candidate standing in a rewarded position of the closing
    -- period with no ban on the row. Empty is the pass condition.
    ---------------------------------------------------------------------------
    DECLARE @Cohort TABLE (UserId uniqueidentifier PRIMARY KEY);
    INSERT INTO @Cohort VALUES
        ('267A4A3D-0A1D-456C-B766-6FC1891F0C26'),('F3150296-CC7F-43B0-90A5-CC941B45E960'),
        ('D3E8334C-49B0-4E75-A759-BDCC95738444'),('E7B743E8-FBF0-4C6C-8A27-CC333C199BAF'),
        ('13EC8B47-BA33-4510-9CF7-9C365E0BD267'),('B8CA6B12-3057-4BBE-9980-53F655FCF065'),
        ('A7D0B667-2796-462E-9763-2B2ACAF4E2B9'),('DAE6C504-81A4-4F34-BCAF-9C94008BF4CA'),
        ('5D6F2740-5780-4936-BD4D-CC542E244CF2'),('51873B16-7A58-4FC6-B234-7F3617C0CE91'),
        ('09BDC8BF-B133-493E-9EBE-E5C145CB0FDE'),('3C8D3BBD-DCA4-4412-98AB-98F7C8FAB1F5'),
        ('469DF796-D270-40FF-BAD9-8A5B9D83B6DC'),('1CDB373F-5A08-4D3A-AB4A-83DAB1F00685'),
        ('92517835-3C2F-449D-AE3E-1ECEBE9E656A'),('4E051EAE-C2A0-4473-AD49-67E48AAF0775'),
        ('1C653428-2C77-4F8E-8194-422AA3D63C8F');

    WITH Ranked AS (
        SELECT c.UserId, c.CompetitionsWon, c.CompetitionRating, c.IsBanned,
               RANK() OVER (ORDER BY c.CompetitionsWon DESC) AS WinsRank
        FROM CompetitiveRatingsCurrent c WITH (NOLOCK)
        WHERE c.PeriodId = @ClosingPeriod
    )
    SELECT r.WinsRank, r.CompetitionsWon, r.CompetitionRating, r.IsBanned, u.Username,
           'EXPOSED: reviewed candidate in a rewarded position, not banned' AS Finding
    FROM Ranked r
    INNER JOIN @Cohort ch ON ch.UserId = r.UserId
    LEFT  JOIN Users   u WITH (NOLOCK) ON u.UserId = r.UserId
    WHERE r.WinsRank <= 15
      AND ISNULL(r.IsBanned, 0) = 0
    ORDER BY r.WinsRank;
END;
