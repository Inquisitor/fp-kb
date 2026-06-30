-- FP-43631 -- monthly + yearly LB ban back-fill verify (read-only)
-- ============================================================================
-- Standalone post-COMMIT verification for monthly-lb-ban-june-2026.sql. Run on
-- each platform PROD MAIN after the UPDATE has been committed. No transaction,
-- no UPDATEs -- pure read.
--
-- Reading the result:
--   * Status='OK'             -- Monthly + Yearly both IsBanned=1 (or absent because never played)
--   * Status='not on this DB' -- expected for UserIds belonging to other platforms
--   * Status='FAIL: ...'      -- back-fill did NOT take effect for this row -- investigate

WITH BannedInJune AS (
    SELECT * FROM (VALUES
        -- week-5
        (CAST('8FD87705-6500-4717-B459-387B07D7B471' AS uniqueidentifier), 'JuliaRybalka',         'Steam', 'week-5', 'FP-43631'),
        (CAST('4545581F-C2DB-4FA4-986E-9AEE3F9CCB48' AS uniqueidentifier), 'Kaneki_Ken2907',       'Steam', 'week-5', 'FP-43631'),
        (CAST('0386A8AA-954F-44CF-B371-6C5BAB96943F' AS uniqueidentifier), 'emer_85_he',           'Steam', 'week-5', 'FP-43631'),
        (CAST('5C99BE5A-A7FB-49B1-AAFB-188E26693CA7' AS uniqueidentifier), 'I_MACTEP_I',           'Steam', 'week-5', 'FP-43631'),
        (CAST('4D3EFD74-6B2B-4E65-B434-A63D08BC6F68' AS uniqueidentifier), 'TTC-SWAX',             'Steam', 'week-5', 'FP-43631'),
        (CAST('E81A2739-534A-4299-80E7-7BF54B573BE8' AS uniqueidentifier), 'nggaaah',              'Xbox',  'week-5', 'FP-43631'),
        (CAST('AE6A4BC7-2DBF-4662-B5C3-7A8296A0F387' AS uniqueidentifier), 'Bejk76 cz',            'Xbox',  'week-5', 'FP-43631'),
        (CAST('82DA4897-61AB-4B56-BD82-4C654B54B7DA' AS uniqueidentifier), 'Bizkit3209',           'Xbox',  'week-5', 'FP-43631'),
        -- week-6
        (CAST('47FEE9FA-C9E6-4DBE-8742-63B56558D890' AS uniqueidentifier), 'LaccFarro',            'Steam', 'week-6', 'FP-43631'),
        (CAST('78C4A65F-EF45-482A-A125-88D71973013B' AS uniqueidentifier), 'Mr-crimson-21',        'PS',    'week-6', 'FP-43631'),
        (CAST('E25C082E-8A19-4236-AA8B-C345137E9EA3' AS uniqueidentifier), 'STARI40K_YT',          'PS',    'week-6', 'FP-43631'),
        (CAST('8F36F30F-ADE0-4D9A-BC88-765AE61E5384' AS uniqueidentifier), 'IIGot-_-Smoked',       'PS',    'week-6', 'FP-43631'),
        -- week-7
        (CAST('1030BC70-976F-4AE8-8464-5E73A4F5382D' AS uniqueidentifier), 'TF_B4ngwal',           'Steam', 'week-7', 'FP-43631'),
        (CAST('6218FFDE-5EAC-4566-BBA5-711422D44F57' AS uniqueidentifier), 'Ramboo051',            'Steam', 'week-7', 'FP-43631'),
        (CAST('3043CB8F-281B-47DF-BEC7-5CA722FA0394' AS uniqueidentifier), 'Audrey_HH',            'Steam', 'week-7', 'FP-43631'),
        (CAST('45BB43B9-8690-43AE-AA4D-190515F4F2EC' AS uniqueidentifier), 'OZBULLDOG',            'Steam', 'week-7', 'FP-43631'),
        (CAST('D2E0BA0E-3AC5-42EC-A645-F8C66137F310' AS uniqueidentifier), 'VovaTemniy',           'Steam', 'week-7', 'FP-43631'),
        (CAST('09DAA0C8-856A-4328-8001-9CC1B2683FAB' AS uniqueidentifier), 'FurryCurrentMaster',   'Steam', 'week-7', 'FP-43631'),
        (CAST('37FE52EC-F9D1-4439-9DDD-2C38982C66C3' AS uniqueidentifier), 'Dokidepp',             'Steam', 'week-7', 'FP-43631'),
        (CAST('C5D90E33-5022-4049-9960-C39A28B0D2A4' AS uniqueidentifier), 'jorja09',              'PS',    'week-7', 'FP-43631'),
        (CAST('B879AB80-43E5-455F-A045-B5A28480AF04' AS uniqueidentifier), 'rabolio41100',         'PS',    'week-7', 'FP-43631'),
        (CAST('E812002D-0618-48EB-ABAE-D88078A4C9F8' AS uniqueidentifier), 'maminapokorny83',      'PS',    'week-7', 'FP-43631'),
        (CAST('4277FB92-D6E9-4CA5-9940-EA77CB5DFA6C' AS uniqueidentifier), 'Neterrall',            'PS',    'week-7', 'FP-43631'),
        (CAST('F6816FD8-9A24-424A-AA90-04B1FD4565E8' AS uniqueidentifier), 'Fat_tuna_mama',        'PS',    'week-7', 'FP-43631'),
        (CAST('CC4044A9-0829-40E6-A6BA-D3222DBCE8D0' AS uniqueidentifier), 'strullendorfer',       'PS',    'week-7', 'FP-43631'),
        (CAST('76B5F7F3-346A-46B1-9C70-4FE0743572C3' AS uniqueidentifier), 'Flo-GrayFOX',          'PS',    'week-7', 'FP-43631'),
        (CAST('5DB0A328-1307-4762-A1DB-7FF34E63BFE5' AS uniqueidentifier), 'bostonbroncos24',      'PS',    'week-7', 'FP-43631'),
        (CAST('1ABB20A3-8696-4737-A0C4-5620A8A374DF' AS uniqueidentifier), 'LEBOOGIEEEE',          'Xbox',  'week-7', 'FP-43631'),
        (CAST('013368D1-E8A8-437A-88B0-71059E3287EB' AS uniqueidentifier), 'BuzzingLemur417',      'Xbox',  'week-7', 'FP-43631'),
        -- week-7 Support pre-actioned
        (CAST('41C022CF-88C4-43F0-A8E5-C1F6F4963242' AS uniqueidentifier), 'Kacumi',               'Steam', 'week-7', 'Support'),
        (CAST('004E4969-131B-426F-B936-6B75F2B6BCD0' AS uniqueidentifier), 'poink',                'Steam', 'week-7', 'Support'),
        (CAST('84F0D212-9F87-4851-9CEE-86E2A6DFCB8B' AS uniqueidentifier), 'A-J-Rimmer-BSC',       'PS',    'week-7', 'Support'),
        (CAST('224F5D15-C1B9-4B5E-9435-3F7FC6184ADF' AS uniqueidentifier), 'nowa_zajawka',         'PS',    'week-7', 'Support'),
        -- week-8
        (CAST('C434AFC9-875D-4ECE-8EFA-FE7810C6DAFF' AS uniqueidentifier), 'ArmlessFisherMan',     'Steam', 'week-8', 'FP-43631'),
        (CAST('883362EF-98A6-4406-B2DC-9636E1D022FC' AS uniqueidentifier), 'BB_Anastasia',         'Steam', 'week-8', 'FP-43631'),
        (CAST('222BBE9D-3557-4280-B854-CBEF2AE48707' AS uniqueidentifier), 'MonsterFish_fuark',    'Steam', 'week-8', 'FP-43631'),
        (CAST('4CF530BA-2330-4DC0-BB8B-C03A55176EFC' AS uniqueidentifier), 'angeperdu',            'Steam', 'week-8', 'FP-43631'),
        (CAST('683D0D32-290E-4726-BFE9-AD16A0234324' AS uniqueidentifier), 'krolikusik',           'Steam', 'week-8', 'FP-43631'),
        (CAST('C5A87A36-E9A3-44C6-B69A-CB08ADBEAEDA' AS uniqueidentifier), 'Matiamo_PL',           'PS',    'week-8', 'FP-43631'),
        (CAST('46E9E18F-0E49-4F9E-B91C-B074823CF02B' AS uniqueidentifier), 'tigrou_le_boss42',     'PS',    'week-8', 'FP-43631'),
        (CAST('56ED8774-68B1-49B2-B395-E594DBE4B766' AS uniqueidentifier), 'M4R5H_57_',            'PS',    'week-8', 'FP-43631'),
        (CAST('CBF68606-DF2C-46B3-8086-E76B7019C1D1' AS uniqueidentifier), 'Epic70cosmin',         'PS',    'week-8', 'FP-43631'),
        (CAST('D1320268-0463-4289-A455-24BAB60B2363' AS uniqueidentifier), 'MrChadRico',           'PS',    'week-8', 'FP-43631'),
        (CAST('EE558D4F-7515-4B5F-B0FD-4C1F47319C3A' AS uniqueidentifier), 'MONSTER-VERT1325',     'PS',    'week-8', 'FP-43631'),
        (CAST('330F8B15-1FC5-49DC-9829-8B710B04F80F' AS uniqueidentifier), 'TR-BILECIKLI_CMR',     'PS',    'week-8', 'FP-43631'),
        (CAST('882BB61A-9F03-4706-B58E-AA9A279E303B' AS uniqueidentifier), 'kokoljj',              'PS',    'week-8', 'FP-43631'),
        (CAST('06BB9D34-BC04-4591-80F6-0F8AD8F05087' AS uniqueidentifier), 'IKIGAI__1__',          'PS',    'week-8', 'FP-43631'),
        (CAST('F25A97B7-FDEF-4C1C-B50A-0D0A117745D4' AS uniqueidentifier), 'Smooter85',            'Xbox',  'week-8', 'FP-43631'),
        -- week-8 Support pre-actioned
        (CAST('97D1FDE6-7AD7-41A7-AED8-79E70220D035' AS uniqueidentifier), 'Adlerblut-Slayer',     'PS',    'week-8', 'Support'),
        (CAST('8893B30E-73BB-49E0-B573-D1C44CC78075' AS uniqueidentifier), 'TR-dennisfb',          'PS',    'week-8', 'Support')
    ) AS T(UserId, Username, Platform, Cycle, Source)
)
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
FROM BannedInJune b
LEFT JOIN CompetitiveRatingsCurrent c WITH (NOLOCK)
    ON c.UserId = b.UserId
   AND ((c.PeriodTypeId = 2 AND c.PeriodId = '20260601')
     OR (c.PeriodTypeId = 3 AND c.PeriodId = '20260101'))
GROUP BY b.Platform, b.Cycle, b.Source, b.Username, b.UserId
ORDER BY b.Platform, b.Cycle, b.Source, b.Username;
