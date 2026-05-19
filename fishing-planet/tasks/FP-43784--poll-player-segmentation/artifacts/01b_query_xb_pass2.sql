-- FP-43784 2nd-pass variant + email lookup — bucket: xb
-- 26 (original, variant) pairs
;WITH PollPairs(OriginalNick, Variant, Source) AS (
    SELECT N'BEYOND xxHELP', N'BEYONDxxHELP', 'username'
    UNION ALL
    SELECT N'BEYOND xxHELP', N'BEYOND_xxHELP', 'username'
    UNION ALL
    SELECT N'Bionoc Bark', N'BionocBark', 'username'
    UNION ALL
    SELECT N'Bionoc Bark', N'Bionoc_Bark', 'username'
    UNION ALL
    SELECT N'Brazenleader#641', N'Brazenleader', 'username'
    UNION ALL
    SELECT N'Brazenleader#641', N'Brazenleader641', 'username'
    UNION ALL
    SELECT N'Courtney benning', N'Courtneybenning', 'username'
    UNION ALL
    SELECT N'Courtney benning', N'Courtney_benning', 'username'
    UNION ALL
    SELECT N'Flourylmp', N'FlouryImp', 'username'
    UNION ALL
    SELECT N'KGE SNEAKY ME', N'KGESNEAKYME', 'username'
    UNION ALL
    SELECT N'KGE SNEAKY ME', N'KGE_SNEAKY_ME', 'username'
    UNION ALL
    SELECT N'kikotheWplayer', N'kikotheplayer', 'username'
    UNION ALL
    SELECT N'kiwiis#9694', N'kiwiis', 'username'
    UNION ALL
    SELECT N'Lilstumpy328 aka Ayden', N'Lilstumpy328', 'username'
    UNION ALL
    SELECT N'Lilstumpy328 aka Ayden', N'Ayden', 'username'
    UNION ALL
    SELECT N'M00N1IGHT420', N'MOONlIGHT420', 'username'
    UNION ALL
    SELECT N'Mikus#1994', N'Mikus', 'username'
    UNION ALL
    SELECT N'Mustang25#701', N'Mustang25', 'username'
    UNION ALL
    SELECT N'Mustang25#701', N'Mustang25701', 'username'
    UNION ALL
    SELECT N'NoahDestroyer18. (xbox gamertag)', N'NoahDestroyer18', 'username'
    UNION ALL
    SELECT N'Prstonrobinson', N'Prestonrobinson', 'username'
    UNION ALL
    SELECT N'Silverwolf#1887', N'Silverwolf', 'username'
    UNION ALL
    SELECT N'Silverwolf#1887', N'Silverwolf1887', 'username'
    UNION ALL
    SELECT N'Taz( tasmanian devil )', N'Taz', 'username'
    UNION ALL
    SELECT N'TheShadows#4966', N'TheShadows', 'username'
    UNION ALL
    SELECT N'TheShadows#4966', N'TheShadows4966', 'username'
),
MatchedByUsername AS (
    SELECT p.OriginalNick, p.Variant, u.UserId, u.Username AS DbUsername
    FROM PollPairs p
    INNER JOIN dbo.Users u WITH (NOLOCK)
        ON u.Username = p.Variant COLLATE SQL_Latin1_General_CP1_CI_AS
    WHERE p.Source = 'username'
),
MatchedByEmail AS (
    SELECT p.OriginalNick, p.Variant, u.UserId, u.Username AS DbUsername
    FROM PollPairs p
    INNER JOIN dbo.Users u WITH (NOLOCK)
        ON u.Email = p.Variant COLLATE SQL_Latin1_General_CP1_CI_AS
    WHERE p.Source = 'email'
),
AllMatched AS (
    SELECT * FROM MatchedByUsername
    UNION ALL
    SELECT * FROM MatchedByEmail
),
PaidUsers AS (
    SELECT DISTINCT t.UserId
    FROM dbo.Transactions t WITH (NOLOCK)
    INNER JOIN AllMatched m ON m.UserId = t.UserId
    WHERE t.Status = 'Complete' AND t.PaymentSystemId <> 'WebAdmin' AND t.Price <> 0
)
SELECT p.OriginalNick AS OriginalNick,
       p.Variant      AS Variant,
       p.Source       AS Source,
       m.DbUsername   AS MatchedUsername,
       pr.Level       AS Level,
       uc.Country     AS Country,
       CASE WHEN pu.UserId IS NOT NULL THEN 1 ELSE 0 END AS IsPayer
FROM PollPairs p
LEFT JOIN AllMatched m ON m.OriginalNick = p.OriginalNick AND m.Variant = p.Variant
LEFT JOIN dbo.Profiles pr WITH (NOLOCK) ON pr.UserId = m.UserId
LEFT JOIN dbo.UserCountries uc WITH (NOLOCK) ON uc.UserId = m.UserId
LEFT JOIN PaidUsers pu ON pu.UserId = m.UserId
ORDER BY p.OriginalNick, p.Variant;
