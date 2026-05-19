-- FP-43784 2nd-pass variant + email lookup — bucket: ps
-- 54 (original, variant) pairs
;WITH PollPairs(OriginalNick, Variant, Source) AS (
    SELECT N'2Wally', N'TwoWally', 'username'
    UNION ALL
    SELECT N'adas.snaj', N'adas_snaj', 'username'
    UNION ALL
    SELECT N'adas.snaj', N'adassnaj', 'username'
    UNION ALL
    SELECT N'Andy Cavalera', N'AndyCavalera', 'username'
    UNION ALL
    SELECT N'Andy Cavalera', N'Andy_Cavalera', 'username'
    UNION ALL
    SELECT N'Argiris - dio', N'Argiris', 'username'
    UNION ALL
    SELECT N'Argiris - dio', N'Argiris-dio', 'username'
    UNION ALL
    SELECT N'Argiris - dio', N'Argirisdio', 'username'
    UNION ALL
    SELECT N'Auréle', N'Aurele', 'username'
    UNION ALL
    SELECT N'Auréle', N'Aurèle', 'username'
    UNION ALL
    SELECT N'Australia.  Outgoing_ape', N'Outgoing_ape', 'username'
    UNION ALL
    SELECT N'Australia.  Outgoing_ape', N'Outgoingape', 'username'
    UNION ALL
    SELECT N'Big e', N'Bige', 'username'
    UNION ALL
    SELECT N'Big e', N'Big_e', 'username'
    UNION ALL
    SELECT N'C_J_ 92', N'C_J_92', 'username'
    UNION ALL
    SELECT N'C_J_ 92', N'CJ_92', 'username'
    UNION ALL
    SELECT N'CAPO DEI CAPI', N'CAPODEICAPI', 'username'
    UNION ALL
    SELECT N'CAPO DEI CAPI', N'CAPO_DEI_CAPI', 'username'
    UNION ALL
    SELECT N'Elzbeth', N'Elizbeth', 'username'
    UNION ALL
    SELECT N'Elzbeth', N'Elsbeth', 'username'
    UNION ALL
    SELECT N'Fatboy-1954', N'Fatboy_1954', 'username'
    UNION ALL
    SELECT N'Fatboy-1954', N'Fatboy1954', 'username'
    UNION ALL
    SELECT N'FPI FIT_Clavale61', N'FIT_Clavale61', 'username'
    UNION ALL
    SELECT N'FPI FIT_Clavale61', N'Clavale61', 'username'
    UNION ALL
    SELECT N'FPI FIT_Clavale61', N'FPI_FIT_Clavale61', 'username'
    UNION ALL
    SELECT N'Gravitaxe-x8', N'Gravitaxe_x8', 'username'
    UNION ALL
    SELECT N'Gravitaxe-x8', N'Gravitaxex8', 'username'
    UNION ALL
    SELECT N'hawai', N'hawaii', 'username'
    UNION ALL
    SELECT N'jm costarica', N'jm', 'username'
    UNION ALL
    SELECT N'jm costarica', N'jmcostarica', 'username'
    UNION ALL
    SELECT N'jm costarica', N'jm_costarica', 'username'
    UNION ALL
    SELECT N'Lt_major_laser', N'Ltmajorlaser', 'username'
    UNION ALL
    SELECT N'Lt_major_laser', N'Lt.major.laser', 'username'
    UNION ALL
    SELECT N'Malachi Bey (inchiwetrust PS5)', N'inchiwetrust', 'username'
    UNION ALL
    SELECT N'Malachi Bey (inchiwetrust PS5)', N'Malachi Bey', 'username'
    UNION ALL
    SELECT N'Malachi Bey (inchiwetrust PS5)', N'MalachiBey', 'username'
    UNION ALL
    SELECT N'newish - ferry 1234', N'newish', 'username'
    UNION ALL
    SELECT N'newish - ferry 1234', N'ferry1234', 'username'
    UNION ALL
    SELECT N'newish - ferry 1234', N'newish-ferry1234', 'username'
    UNION ALL
    SELECT N'No ty', N'Noty', 'username'
    UNION ALL
    SELECT N'No ty', N'No_ty', 'username'
    UNION ALL
    SELECT N'Panda Man Jack', N'PandaManJack', 'username'
    UNION ALL
    SELECT N'Panda Man Jack', N'Panda_Man_Jack', 'username'
    UNION ALL
    SELECT N'Quiberon 1958', N'Quiberon1958', 'username'
    UNION ALL
    SELECT N'Quiberon 1958', N'Quiberon_1958', 'username'
    UNION ALL
    SELECT N'SHOGUN 77', N'SHOGUN77', 'username'
    UNION ALL
    SELECT N'SHOGUN 77', N'SHOGUN_77', 'username'
    UNION ALL
    SELECT N'strict88 [test]', N'strict88', 'username'
    UNION ALL
    SELECT N'Tamasannttamigayu 90', N'Tamasannttamigayu', 'username'
    UNION ALL
    SELECT N'Tamasannttamigayu 90', N'Tamasannttamigayu90', 'username'
    UNION ALL
    SELECT N'Tamasannttamigayu 90', N'Tamasannttamigayu_90', 'username'
    UNION ALL
    SELECT N'The goon man', N'Thegoonman', 'username'
    UNION ALL
    SELECT N'The goon man', N'The_goon_man', 'username'
    UNION ALL
    SELECT N'TypsyGrasshopper....', N'TypsyGrasshopper', 'username'
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
