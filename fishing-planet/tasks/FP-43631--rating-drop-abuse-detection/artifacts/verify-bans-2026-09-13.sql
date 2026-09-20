-- FP-43631 week-19 -- 3-layer post-ban verification
-- ============================================================================
-- Run on EACH platform PROD MAIN. UserIds not present on a given DB report 'not on this DB', which
-- is expected -- the ban list spans three platforms and each database holds only its own.
--
-- Layer 1 (profile)     -- block A
-- Layer 2 (leaderboard) -- blocks A and B; B is the one that matters
-- Layer 3 (Mongo banLog) -- NOT here; checked separately against each platform Mongo.
--
-- BLOCK B. The sweep runs on Sunday and CompetitiveRatingsCurrent rolls to the next weekly period
-- around the same time, so a player can carry rows for both weeks. A check that only counts
-- banned-vs-not-banned across all rows returns OK when the new week is banned and the CLOSING week
-- -- the one the imminent reward run pays on -- is not. Weekly PeriodId is the window's Monday as
-- yyyymmdd: closing 20260907, next 20260914.
--
-- BLOCK C. Blocks A and B look only at accounts that were banned, so neither can see a candidate the
-- review did not convict standing in the money. Block C takes the WHOLE reviewed cohort and reports
-- anyone inside the closing period's risk zone. It is a net, not the primary control -- the risk
-- zone computed before the trial is what protects the payout, and block C catches the case where
-- that zone was computed wrong or the board moved afterwards.
--
-- Read block C by the Finding column, not by the row count:
--   FAIL  -- a convicted candidate with no ban. Fix before the payout.
--   info  -- an acquitted candidate standing in the money. Not an alarm. Week-18 acquitted a
--            candidate at 6th place who duly collected, and that was the correct outcome of a
--            reasoned acquittal. Flagging both alike would make this check cry wolf.
--
-- Week-19 expectation: the paying cutoff was 3 wins on every platform; the only candidate who could
-- reach it was ZellyRolled at 3rd on Xbox, and he is banned. No FAIL rows should appear.
--
-- Aggregate database-side. The MCP result view truncates at ten rows.

SET NOCOUNT ON;

BEGIN
    DECLARE @ClosingPeriod int = 20260907;
    DECLARE @NextPeriod    int = 20260914;

    DECLARE @Ban TABLE (UserId uniqueidentifier PRIMARY KEY, Username varchar(64), Platform varchar(16), BanUntil date, Basis varchar(28));
    INSERT INTO @Ban VALUES
        ('952EED36-E6A1-40DD-ACD6-7BC8831500CB','Pilou62',        'Steam','2026-10-12','trial conf 9'),
        ('0EF1A14C-25BC-4F84-B6BE-85EE73C8739F','Mr.Twin',        'Steam','2026-10-12','trial conf 9'),
        ('D9D89E71-18D8-44E4-83B5-DAF07045FE14','Suna4Y',         'Steam','2026-10-12','trial conf 9'),
        ('2018B861-7EBF-4D9E-AEF8-3656C6A21C22','AdmiralAckbar98','PS',   '2026-10-12','trial conf 8'),
        ('CF9967A8-175F-42AC-A364-C9C658532B58','sidelong-beak10','PS',   '2026-10-12','trial conf 9'),
        ('4E051EAE-C2A0-4473-AD49-67E48AAF0775','KovlekPlayz',    'Xbox', '2026-10-12','trial conf 9, rules 4/8'),
        ('87223C5F-5082-496F-88D4-507D31B540F5','ZellyRolled',    'Xbox', '2026-10-12','operator override');

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
    -- BLOCK C -- the net: whole reviewed cohort inside the closing period's risk zone
    ---------------------------------------------------------------------------
    DECLARE @Cohort TABLE (UserId uniqueidentifier PRIMARY KEY, Verdict varchar(10));
    INSERT INTO @Cohort VALUES
        ('952EED36-E6A1-40DD-ACD6-7BC8831500CB','BAN'),   -- Pilou62
        ('0EF1A14C-25BC-4F84-B6BE-85EE73C8739F','BAN'),   -- Mr.Twin
        ('D9D89E71-18D8-44E4-83B5-DAF07045FE14','BAN'),   -- Suna4Y
        ('2018B861-7EBF-4D9E-AEF8-3656C6A21C22','BAN'),   -- AdmiralAckbar98
        ('CF9967A8-175F-42AC-A364-C9C658532B58','BAN'),   -- sidelong-beak10
        ('4E051EAE-C2A0-4473-AD49-67E48AAF0775','BAN'),   -- KovlekPlayz
        ('87223C5F-5082-496F-88D4-507D31B540F5','BAN'),   -- ZellyRolled (operator override)
        ('10A0FFF3-E631-413B-B5FA-30208635F2A6','WATCH'), -- FOGGIA1920
        ('1E51550F-DB71-4EBC-82D5-06B89693D93A','WATCH'), -- Lesky2123
        ('297D97A2-2446-4C13-BF9B-3CF6745086EE','WATCH'), -- YOUTUBE-Eduzera-YT
        ('A9266367-F0BD-45D7-BDD5-14A21F152862','WATCH'), -- AppL33
        ('18514E38-B869-48BA-B39B-B77B3A741B43','WATCH'); -- Bog_Zim

    WITH Ranked AS (
        SELECT c.UserId, c.CompetitionsWon, c.IsBanned,
               RANK() OVER (ORDER BY c.CompetitionsWon DESC) AS WinsRank
        FROM CompetitiveRatingsCurrent c WITH (NOLOCK)
        WHERE c.PeriodId = @ClosingPeriod
    )
    SELECT r.WinsRank, r.CompetitionsWon, r.IsBanned, u.Username, ch.Verdict,
           CASE WHEN ch.Verdict = 'BAN' AND ISNULL(r.IsBanned,0) = 0
                     THEN 'FAIL - convicted but not applied'
                WHEN ch.Verdict = 'BAN' THEN 'covered'
                ELSE 'info - acquitted, unbanned by decision' END AS Finding
    FROM Ranked r
    INNER JOIN @Cohort ch ON ch.UserId = r.UserId
    LEFT  JOIN Users   u  WITH (NOLOCK) ON u.UserId = r.UserId
    WHERE r.WinsRank <= 15
    ORDER BY r.WinsRank;
END;
