-- FP-43784 LastActivityDate lookup for pass-2 matched users — bucket: ps (9 users)
SELECT u.Username AS MatchedUsername, u.LastActivityDate
FROM (VALUES (N'Adas_snaj'),(N'C_J_92'),(N'FIT_Clavale61'),(N'InCHIweTrust'),(N'argiris-dio'),(N'fatboy_1954'),(N'jmcostarica'),(N'newish-ferry1234'),(N'quiberon1958')) AS v(Name)
INNER JOIN dbo.Users u WITH (NOLOCK)
    ON u.Username = v.Name COLLATE SQL_Latin1_General_CP1_CI_AS
ORDER BY u.Username;
