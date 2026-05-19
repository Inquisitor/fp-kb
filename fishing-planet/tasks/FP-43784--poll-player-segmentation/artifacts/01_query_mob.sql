-- FP-43784 lookup — bucket: Mobile (Android + iOS) (109 unique nicks, case-insensitive)
-- Read-only. NOLOCK on every Prod table.
-- Match key: Users.Username (SQL_Latin1_General_CP1_CI_AS).
-- Payer rule mirrors SqlMonetizationProvider.GetHasPaidTransactions().

;WITH PollNicks(Nickname) AS (
    SELECT v.Nickname COLLATE SQL_Latin1_General_CP1_CI_AS
    FROM (VALUES
    (N'Bramahi-mahi'),
    (N'Caknarfisherman0.2'),
    (N'MonstaFishing'),
    (N'Pangara_F'),
    (N'ajirasta08-SIDATZEUS'),
    (N'PaksiwNiDrei'),
    (N'VIETNAMxXx'),
    (N'D3W'),
    (N'AnarchyDGAF'),
    (N'PapillonSerge'),
    (N'UCHIHA_BAYU'),
    (N'AnglerApaYa'),
    (N'DaenerysTargaryen-VIl'),
    (N'Rajil Afwa'),
    (N'MinaKiMiko1'),
    (N'WhiteTrout007'),
    (N'Eryka'),
    (N'Zlayer95'),
    (N'IDN-Jacob'),
    (N'GUANAJUATO.MEXICO'),
    (N'GiganticBarnclekozak'),
    (N'Jf-fishing'),
    (N'THE-Xx-UMBRE-xX'),
    (N'AFC-SpingX7'),
    (N'Holyfelf'),
    (N'96Patryk'),
    (N'TaruMR11'),
    (N'no.pvp.ok'),
    (N'NanyaAjaDiBecandain'),
    (N'nd1245'),
    (N'Fuzzy21202'),
    (N'Jesus712018'),
    (N'AnatoliyRivne'),
    (N'X-Daiwa'),
    (N'G.R.A.F'),
    (N'PESCADOR_TRAIRAO'),
    (N'AT_NeoLex'),
    (N'AFC-Azeskk'),
    (N'Neko7T7'),
    (N'LeopoldStotch'),
    (N'mbokne_ancok'),
    (N'Velardi_77'),
    (N'Tonecapone1'),
    (N'Navy'),
    (N'Tongiiii2TH'),
    (N'Lam28082012'),
    (N'Focus_1314'),
    (N'FARWAN_XD'),
    (N'IwakUcengHunter'),
    (N'GoodGuyHits'),
    (N'Fishing_Lemon'),
    (N'StrikePaduwww'),
    (N'Karachekrak_ZP_UA'),
    (N'Roman29020'),
    (N'Mba_Ika'),
    (N'BabaPikeFishing'),
    (N'ThailandAmz'),
    (N'Piyakronn'),
    (N'Harolduyyyy'),
    (N'16_denver'),
    (N'Jhanmaggot'),
    (N'LupinEmi'),
    (N'Bank'),
    (N'ranzz_fp'),
    (N'Seanbet'),
    (N'Santinooooo'),
    (N'Melody'),
    (N'polo826'),
    (N'Ilieser'),
    (N'FamousQuestAssassin36'),
    (N'Mboyak898'),
    (N'KM56'),
    (N'tizu_basah'),
    (N'IDA_NILON100'),
    (N'CapitanAkap'),
    (N'FurryNetTheif1'),
    (N'@Quack-Attack83'),
    (N'Jons'),
    (N'Xiztnc'),
    (N'Minhaz Shakil'),
    (N'Non'),
    (N'SK_B_07'),
    (N'TsukijanSensei'),
    (N'loploplop'),
    (N'zliouba'),
    (N'chevylover223'),
    (N'CrakSkun'),
    (N'Klepon_Balappp'),
    (N'Hirai-Ren'),
    (N'RapalaProFisher'),
    (N'Koroku'),
    (N'Kuroko023'),
    (N'Sumthingfishy420'),
    (N'FoxconNnBG'),
    (N'DanielMartinez'),
    (N'Rushtize'),
    (N'Name: omarxd       level:86'),
    (N'Herushim'),
    (N'MDIOgre'),
    (N'Paatriick'),
    (N'KamuiUA'),
    (N'Brad3134'),
    (N'11VERMILLION'),
    (N'LOCOL99'),
    (N'Siu1Maai2Lou2'),
    (N'Piolgntng'),
    (N'Caneli_sfishingplanet'),
    (N'Wolf_maitresse'),
    (N'Heinz-Harald')
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
