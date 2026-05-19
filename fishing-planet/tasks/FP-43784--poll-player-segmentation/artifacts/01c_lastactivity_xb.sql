-- FP-43784 LastActivityDate lookup for pass-2 matched users — bucket: xb (7 users)
SELECT u.Username AS MatchedUsername, u.LastActivityDate
FROM (VALUES (N'BEYONDxxHELP'),(N'Brazenleader641'),(N'FlouryImp'),(N'Lilstumpy328'),(N'NoahDestroyer18'),(N'Silverwolf1887'),(N'TheShadows4966')) AS v(Name)
INNER JOIN dbo.Users u WITH (NOLOCK)
    ON u.Username = v.Name COLLATE SQL_Latin1_General_CP1_CI_AS
ORDER BY u.Username;
