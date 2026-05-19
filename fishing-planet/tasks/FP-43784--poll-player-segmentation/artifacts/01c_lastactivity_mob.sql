-- FP-43784 LastActivityDate lookup for pass-2 matched users — bucket: mob (10 users)
SELECT u.Username AS MatchedUsername, u.LastActivityDate
FROM (VALUES (N'DaenerysTargaryen'),(N'DaenerysTargaryen-VII'),(N'FurryNetThief'),(N'GiganticBarnacleKozak'),(N'JF_Fishing'),(N'JfFishing'),(N'Quack-Attack83'),(N'Santino'),(N'jacob'),(N'omarxd')) AS v(Name)
INNER JOIN dbo.Users u WITH (NOLOCK)
    ON u.Username = v.Name COLLATE SQL_Latin1_General_CP1_CI_AS
ORDER BY u.Username;
