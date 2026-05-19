-- FP-43784 2nd-pass variant + email lookup — bucket: mob
-- 26 (original, variant) pairs
;WITH PollPairs(OriginalNick, Variant, Source) AS (
    SELECT N'@Quack-Attack83', N'Quack-Attack83', 'username'
    UNION ALL
    SELECT N'@Quack-Attack83', N'QuackAttack83', 'username'
    UNION ALL
    SELECT N'@Quack-Attack83', N'Quack_Attack83', 'username'
    UNION ALL
    SELECT N'16_denver', N'16denver', 'username'
    UNION ALL
    SELECT N'AFC-SpingX7', N'AFC-SpringX7', 'username'
    UNION ALL
    SELECT N'AFC-SpingX7', N'AFCSpingX7', 'username'
    UNION ALL
    SELECT N'Caneli_sfishingplanet', N'Caneli_s', 'username'
    UNION ALL
    SELECT N'Caneli_sfishingplanet', N'Caneli', 'username'
    UNION ALL
    SELECT N'DaenerysTargaryen-VIl', N'DaenerysTargaryen-VII', 'username'
    UNION ALL
    SELECT N'DaenerysTargaryen-VIl', N'DaenerysTargaryen', 'username'
    UNION ALL
    SELECT N'FurryNetTheif1', N'FurryNetThief1', 'username'
    UNION ALL
    SELECT N'FurryNetTheif1', N'FurryNetThief', 'username'
    UNION ALL
    SELECT N'GiganticBarnclekozak', N'GiganticBarnaclekozak', 'username'
    UNION ALL
    SELECT N'GiganticBarnclekozak', N'GiganticBarnacle_kozak', 'username'
    UNION ALL
    SELECT N'IDN-Jacob', N'IDN_Jacob', 'username'
    UNION ALL
    SELECT N'IDN-Jacob', N'Jacob', 'username'
    UNION ALL
    SELECT N'Jf-fishing', N'Jf_fishing', 'username'
    UNION ALL
    SELECT N'Jf-fishing', N'JfFishing', 'username'
    UNION ALL
    SELECT N'Minhaz Shakil', N'MinhazShakil', 'username'
    UNION ALL
    SELECT N'Minhaz Shakil', N'Minhaz_Shakil', 'username'
    UNION ALL
    SELECT N'Name: omarxd       level:86', N'omarxd', 'username'
    UNION ALL
    SELECT N'Rajil Afwa', N'RajilAfwa', 'username'
    UNION ALL
    SELECT N'Rajil Afwa', N'Rajil_Afwa', 'username'
    UNION ALL
    SELECT N'Santinooooo', N'Santino', 'username'
    UNION ALL
    SELECT N'X-Daiwa', N'X_Daiwa', 'username'
    UNION ALL
    SELECT N'X-Daiwa', N'XDaiwa', 'username'
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
