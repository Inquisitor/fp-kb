-- FP-43784 lookup — bucket: Nintendo Switch (15 unique nicks, case-insensitive)
-- Read-only. NOLOCK on every Prod table.
-- Match key: Users.Username (SQL_Latin1_General_CP1_CI_AS).
-- Payer rule mirrors SqlMonetizationProvider.GetHasPaidTransactions().

;WITH PollNicks(Nickname) AS (
    SELECT v.Nickname COLLATE SQL_Latin1_General_CP1_CI_AS
    FROM (VALUES
    (N'Clod'),
    (N'Sailnshebe'),
    (N'YellowPerchGuru44'),
    (N'JustTheDude'),
    (N'ShoebillFisher3'),
    (N'Ovix72'),
    (N'gottan'),
    (N'FamousCatfishBuster4'),
    (N'expertfishingYT'),
    (N'Invoker'),
    (N'Dudavis12'),
    (N'Snapper_paladin'),
    (N'NomadMisfit'),
    (N'vIct0r407'),
    (N'Mayyinaise')
    ) AS v(Nickname)
),
MatchedUsers AS (
    SELECT p.Nickname AS PolledNickname, u.UserId, u.Username AS DbUsername
    FROM PollNicks p
    INNER JOIN dbo.Users u WITH (NOLOCK) ON u.Username = p.Nickname
),
PaidUsers AS (
    SELECT DISTINCT t.UserId
    FROM dbo.Transactions t WITH (NOLOCK)
    INNER JOIN MatchedUsers m ON m.UserId = t.UserId
    WHERE t.Status = 'Complete'
      AND t.PaymentSystemId <> 'WebAdmin'
      AND t.Price <> 0
)
SELECT p.Nickname        AS PolledNickname,
       mu.DbUsername     AS MatchedUsername,
       pr.Level          AS Level,
       uc.Country        AS Country,
       CASE WHEN pu.UserId IS NOT NULL THEN 1 ELSE 0 END AS IsPayer
FROM PollNicks p
LEFT JOIN MatchedUsers mu ON mu.PolledNickname = p.Nickname
LEFT JOIN dbo.Profiles pr WITH (NOLOCK) ON pr.UserId = mu.UserId
LEFT JOIN dbo.UserCountries uc WITH (NOLOCK) ON uc.UserId = mu.UserId
LEFT JOIN PaidUsers pu ON pu.UserId = mu.UserId
ORDER BY p.Nickname;
