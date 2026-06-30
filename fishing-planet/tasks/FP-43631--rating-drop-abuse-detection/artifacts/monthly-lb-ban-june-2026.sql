-- FP-43631 -- monthly + yearly leaderboard back-fill for June 2026 bans
-- ============================================================================
-- Backfills CompetitiveRatingsCurrent.IsBanned = 1 for everyone banned in June
-- 2026: four FP-43631 weekly cycles (week-5 through week-8) plus six Support
-- pre-actioned candidates identified during weeks 7-8 sweeps. Targets Monthly
-- (PeriodTypeId=2, PeriodId='20260601') and Yearly (PeriodTypeId=3,
-- PeriodId='20260101') periods.
--
-- Reason: Steam has an auto-sync patch propagating Profile.IsCompetitionsBanned
-- to CompetitiveRatingsCurrent.IsBanned on BOTH ban AND unban. For Weekly LBs
-- the rotation is fast enough that an unban mid-period doesn't matter -- but
-- Monthly and Yearly LBs aggregate the entire period, so a player whose
-- Profile ban expires before the monthly rollover gets their LB IsBanned
-- reverted to 0 and the finalizer pays them out anyway. This script sticks
-- the Monthly (June 2026) and Yearly (2026) IsBanned flags for everyone
-- (FP-43631 or Support) who held a Profile ban at any point during June.
--
-- Run on each platform PROD MAIN -- UserIds are globally unique FP GUIDs, so
-- each platform's UPDATE only touches its own rows. Non-belonging UserIds
-- simply have no LB rows on this DB and are reported as 'not on this DB' in
-- the verify SELECT.
--
-- Cohort: 50 UserIds (Steam 20, PS 24, Xbox 6).
--
-- Atomic: SET XACT_ABORT ON auto-rolls-back on any error. After inspecting
-- the verify SELECT, run COMMIT TRAN (or ROLLBACK TRAN) at the bottom by hand.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    BEGIN TRAN;

    IF OBJECT_ID('tempdb..#BannedInJune') IS NOT NULL DROP TABLE #BannedInJune;
    CREATE TABLE #BannedInJune (
        UserId   uniqueidentifier PRIMARY KEY,
        Username varchar(64)      NOT NULL,
        Platform varchar(16)      NOT NULL,
        Cycle    varchar(20)      NOT NULL,
        Source   varchar(12)      NOT NULL  -- 'FP-43631' or 'Support'
    );

    INSERT INTO #BannedInJune (UserId, Username, Platform, Cycle, Source) VALUES
        -- week-5 (sweep 2026-06-07; BanEnd 2026-06-22 NEW / 2026-07-06 REPEAT)
        ('8FD87705-6500-4717-B459-387B07D7B471', 'JuliaRybalka',         'Steam', 'week-5', 'FP-43631'),
        ('4545581F-C2DB-4FA4-986E-9AEE3F9CCB48', 'Kaneki_Ken2907',       'Steam', 'week-5', 'FP-43631'),
        ('0386A8AA-954F-44CF-B371-6C5BAB96943F', 'emer_85_he',           'Steam', 'week-5', 'FP-43631'),
        ('5C99BE5A-A7FB-49B1-AAFB-188E26693CA7', 'I_MACTEP_I',           'Steam', 'week-5', 'FP-43631'),
        ('4D3EFD74-6B2B-4E65-B434-A63D08BC6F68', 'TTC-SWAX',             'Steam', 'week-5', 'FP-43631'),
        ('E81A2739-534A-4299-80E7-7BF54B573BE8', 'nggaaah',              'Xbox',  'week-5', 'FP-43631'),
        ('AE6A4BC7-2DBF-4662-B5C3-7A8296A0F387', 'Bejk76 cz',            'Xbox',  'week-5', 'FP-43631'),
        ('82DA4897-61AB-4B56-BD82-4C654B54B7DA', 'Bizkit3209',           'Xbox',  'week-5', 'FP-43631'),
        -- week-6 (sweep 2026-06-14; BanEnd 2026-06-29 NEW / 2026-07-13 REPEAT)
        ('47FEE9FA-C9E6-4DBE-8742-63B56558D890', 'LaccFarro',            'Steam', 'week-6', 'FP-43631'),
        ('78C4A65F-EF45-482A-A125-88D71973013B', 'Mr-crimson-21',        'PS',    'week-6', 'FP-43631'),
        ('E25C082E-8A19-4236-AA8B-C345137E9EA3', 'STARI40K_YT',          'PS',    'week-6', 'FP-43631'),
        ('8F36F30F-ADE0-4D9A-BC88-765AE61E5384', 'IIGot-_-Smoked',       'PS',    'week-6', 'FP-43631'),
        -- week-7 (sweep 2026-06-21; BanEnd 2026-07-06 NEW / 2026-07-20 REPEAT)
        ('1030BC70-976F-4AE8-8464-5E73A4F5382D', 'TF_B4ngwal',           'Steam', 'week-7', 'FP-43631'),
        ('6218FFDE-5EAC-4566-BBA5-711422D44F57', 'Ramboo051',            'Steam', 'week-7', 'FP-43631'),
        ('3043CB8F-281B-47DF-BEC7-5CA722FA0394', 'Audrey_HH',            'Steam', 'week-7', 'FP-43631'),
        ('45BB43B9-8690-43AE-AA4D-190515F4F2EC', 'OZBULLDOG',            'Steam', 'week-7', 'FP-43631'),
        ('D2E0BA0E-3AC5-42EC-A645-F8C66137F310', 'VovaTemniy',           'Steam', 'week-7', 'FP-43631'),
        ('09DAA0C8-856A-4328-8001-9CC1B2683FAB', 'FurryCurrentMaster',   'Steam', 'week-7', 'FP-43631'),
        ('37FE52EC-F9D1-4439-9DDD-2C38982C66C3', 'Dokidepp',             'Steam', 'week-7', 'FP-43631'),
        ('C5D90E33-5022-4049-9960-C39A28B0D2A4', 'jorja09',              'PS',    'week-7', 'FP-43631'),
        ('B879AB80-43E5-455F-A045-B5A28480AF04', 'rabolio41100',         'PS',    'week-7', 'FP-43631'),
        ('E812002D-0618-48EB-ABAE-D88078A4C9F8', 'maminapokorny83',      'PS',    'week-7', 'FP-43631'),
        ('4277FB92-D6E9-4CA5-9940-EA77CB5DFA6C', 'Neterrall',            'PS',    'week-7', 'FP-43631'),
        ('F6816FD8-9A24-424A-AA90-04B1FD4565E8', 'Fat_tuna_mama',        'PS',    'week-7', 'FP-43631'),
        ('CC4044A9-0829-40E6-A6BA-D3222DBCE8D0', 'strullendorfer',       'PS',    'week-7', 'FP-43631'),
        ('76B5F7F3-346A-46B1-9C70-4FE0743572C3', 'Flo-GrayFOX',          'PS',    'week-7', 'FP-43631'),
        ('5DB0A328-1307-4762-A1DB-7FF34E63BFE5', 'bostonbroncos24',      'PS',    'week-7', 'FP-43631'),
        ('1ABB20A3-8696-4737-A0C4-5620A8A374DF', 'LEBOOGIEEEE',          'Xbox',  'week-7', 'FP-43631'),
        ('013368D1-E8A8-437A-88B0-71059E3287EB', 'BuzzingLemur417',      'Xbox',  'week-7', 'FP-43631'),
        -- week-7 Support pre-actioned (trial-confirmed, Support BanEnd 2026-07-05..2026-07-21)
        ('41C022CF-88C4-43F0-A8E5-C1F6F4963242', 'Kacumi',               'Steam', 'week-7', 'Support'),
        ('004E4969-131B-426F-B936-6B75F2B6BCD0', 'poink',                'Steam', 'week-7', 'Support'),
        ('84F0D212-9F87-4851-9CEE-86E2A6DFCB8B', 'A-J-Rimmer-BSC',       'PS',    'week-7', 'Support'),
        ('224F5D15-C1B9-4B5E-9435-3F7FC6184ADF', 'nowa_zajawka',         'PS',    'week-7', 'Support'),
        -- week-8 (sweep 2026-06-28; BanEnd 2026-07-13 NEW / 2026-07-27 REPEAT)
        ('C434AFC9-875D-4ECE-8EFA-FE7810C6DAFF', 'ArmlessFisherMan',     'Steam', 'week-8', 'FP-43631'),
        ('883362EF-98A6-4406-B2DC-9636E1D022FC', 'BB_Anastasia',         'Steam', 'week-8', 'FP-43631'),
        ('222BBE9D-3557-4280-B854-CBEF2AE48707', 'MonsterFish_fuark',    'Steam', 'week-8', 'FP-43631'),
        ('4CF530BA-2330-4DC0-BB8B-C03A55176EFC', 'angeperdu',            'Steam', 'week-8', 'FP-43631'),
        ('683D0D32-290E-4726-BFE9-AD16A0234324', 'krolikusik',           'Steam', 'week-8', 'FP-43631'),
        ('C5A87A36-E9A3-44C6-B69A-CB08ADBEAEDA', 'Matiamo_PL',           'PS',    'week-8', 'FP-43631'),
        ('46E9E18F-0E49-4F9E-B91C-B074823CF02B', 'tigrou_le_boss42',     'PS',    'week-8', 'FP-43631'),
        ('56ED8774-68B1-49B2-B395-E594DBE4B766', 'M4R5H_57_',            'PS',    'week-8', 'FP-43631'),
        ('CBF68606-DF2C-46B3-8086-E76B7019C1D1', 'Epic70cosmin',         'PS',    'week-8', 'FP-43631'),
        ('D1320268-0463-4289-A455-24BAB60B2363', 'MrChadRico',           'PS',    'week-8', 'FP-43631'),
        ('EE558D4F-7515-4B5F-B0FD-4C1F47319C3A', 'MONSTER-VERT1325',     'PS',    'week-8', 'FP-43631'),
        ('330F8B15-1FC5-49DC-9829-8B710B04F80F', 'TR-BILECIKLI_CMR',     'PS',    'week-8', 'FP-43631'),
        ('882BB61A-9F03-4706-B58E-AA9A279E303B', 'kokoljj',              'PS',    'week-8', 'FP-43631'),
        ('06BB9D34-BC04-4591-80F6-0F8AD8F05087', 'IKIGAI__1__',          'PS',    'week-8', 'FP-43631'),
        ('F25A97B7-FDEF-4C1C-B50A-0D0A117745D4', 'Smooter85',            'Xbox',  'week-8', 'FP-43631'),
        -- week-8 Support pre-actioned (trial-confirmed, Support BanEnd 2026-07-23/2026-07-28)
        ('97D1FDE6-7AD7-41A7-AED8-79E70220D035', 'Adlerblut-Slayer',     'PS',    'week-8', 'Support'),
        ('8893B30E-73BB-49E0-B573-D1C44CC78075', 'TR-dennisfb',          'PS',    'week-8', 'Support');

    -- Step 1: Monthly LB (PeriodTypeId=2, PeriodId='20260601')
    UPDATE c
    SET c.IsBanned = 1
    FROM CompetitiveRatingsCurrent c
    INNER JOIN #BannedInJune b ON b.UserId = c.UserId
    WHERE c.PeriodTypeId = 2 AND c.PeriodId = '20260601' AND ISNULL(c.IsBanned, 0) = 0;

    PRINT CONCAT('Monthly LB rows flipped to IsBanned=1: ', @@ROWCOUNT);

    -- Step 2: Yearly LB (PeriodTypeId=3, PeriodId='20260101')
    UPDATE c
    SET c.IsBanned = 1
    FROM CompetitiveRatingsCurrent c
    INNER JOIN #BannedInJune b ON b.UserId = c.UserId
    WHERE c.PeriodTypeId = 3 AND c.PeriodId = '20260101' AND ISNULL(c.IsBanned, 0) = 0;

    PRINT CONCAT('Yearly LB rows flipped to IsBanned=1: ', @@ROWCOUNT);

    -- Step 3: verify -- per-UserId Monthly/Yearly status. Possible Status values:
    --   'not on this DB'  -- UserId belongs to another platform (expected for ~30 of 50 rows)
    --   'OK'              -- on this DB, Monthly+Yearly both banned (or absent because never played)
    --   'FAIL: ...'       -- on this DB but a banned-status check failed -- investigate
    SELECT
        b.Platform,
        b.Cycle,
        b.Source,
        b.Username,
        b.UserId,
        SUM(CASE WHEN c.PeriodTypeId = 2 AND c.IsBanned = 1 THEN 1 ELSE 0 END) AS Mo_B,
        SUM(CASE WHEN c.PeriodTypeId = 2 AND c.IsBanned = 0 THEN 1 ELSE 0 END) AS Mo_N,
        SUM(CASE WHEN c.PeriodTypeId = 3 AND c.IsBanned = 1 THEN 1 ELSE 0 END) AS Yr_B,
        SUM(CASE WHEN c.PeriodTypeId = 3 AND c.IsBanned = 0 THEN 1 ELSE 0 END) AS Yr_N,
        CASE
            WHEN NOT EXISTS (SELECT 1 FROM Users u WITH (NOLOCK) WHERE u.UserId = b.UserId) THEN 'not on this DB'
            WHEN SUM(CASE WHEN c.PeriodTypeId = 2 AND c.IsBanned = 0 THEN 1 ELSE 0 END) > 0 THEN 'FAIL: Monthly still NotBanned'
            WHEN SUM(CASE WHEN c.PeriodTypeId = 3 AND c.IsBanned = 0 THEN 1 ELSE 0 END) > 0 THEN 'FAIL: Yearly still NotBanned'
            ELSE 'OK'
        END AS Status
    FROM #BannedInJune b
    LEFT JOIN CompetitiveRatingsCurrent c WITH (NOLOCK)
        ON c.UserId = b.UserId
       AND ((c.PeriodTypeId = 2 AND c.PeriodId = '20260601')
         OR (c.PeriodTypeId = 3 AND c.PeriodId = '20260101'))
    GROUP BY b.Platform, b.Cycle, b.Source, b.Username, b.UserId
    ORDER BY b.Platform, b.Cycle, b.Source, b.Username;

    DROP TABLE #BannedInJune;

    -- After visual inspection pick ONE:
    -- COMMIT TRAN;
    -- ROLLBACK TRAN;
END;
