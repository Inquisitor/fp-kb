-- FP-43784 2nd-pass variant + email lookup — bucket: steam
-- 158 (original, variant) pairs
;WITH PollPairs(OriginalNick, Variant, Source) AS (
    SELECT N'𝖘𝖑𝖆𝖘𝖍𝖞', N'slashy', 'username'
    UNION ALL
    SELECT N'[PwPro]Andy', N'Andy', 'username'
    UNION ALL
    SELECT N'[PwPro]Andy', N'PwProAndy', 'username'
    UNION ALL
    SELECT N'[PwPro]Andy', N'PwPro_Andy', 'username'
    UNION ALL
    SELECT N'__PILOT__ON__BOARD__', N'PILOT_ON_BOARD', 'username'
    UNION ALL
    SELECT N'__PILOT__ON__BOARD__', N'PILOTONBOARD', 'username'
    UNION ALL
    SELECT N'=Niszczycielswiatow123', N'Niszczycielswiatow123', 'username'
    UNION ALL
    SELECT N'>>Tom<<', N'Tom', 'username'
    UNION ALL
    SELECT N'abhimax68@gmail.com', N'abhimax68', 'username'
    UNION ALL
    SELECT N'abhimax68@gmail.com', N'abhimax68@gmail.com', 'email'
    UNION ALL
    SELECT N'AffableScallopldol', N'AffableScallopIdol', 'username'
    UNION ALL
    SELECT N'Aic Fih', N'AicFih', 'username'
    UNION ALL
    SELECT N'Aic Fih', N'Aic_Fih', 'username'
    UNION ALL
    SELECT N'Bennett Hamilton', N'BennettHamilton', 'username'
    UNION ALL
    SELECT N'Bennett Hamilton', N'Bennett_Hamilton', 'username'
    UNION ALL
    SELECT N'Big T', N'BigT', 'username'
    UNION ALL
    SELECT N'Big T', N'Big_T', 'username'
    UNION ALL
    SELECT N'bjorn.oremus', N'bjorn_oremus', 'username'
    UNION ALL
    SELECT N'bjorn.oremus', N'bjornoremus', 'username'
    UNION ALL
    SELECT N'BottleDogerBandit.gg', N'BottleDogerBandit', 'username'
    UNION ALL
    SELECT N'BottleDogerBandit.gg', N'BottleDogerBanditgg', 'username'
    UNION ALL
    SELECT N'Captain West', N'CaptainWest', 'username'
    UNION ALL
    SELECT N'Captain West', N'Captain_West', 'username'
    UNION ALL
    SELECT N'cardi cardi', N'cardicardi', 'username'
    UNION ALL
    SELECT N'cardi cardi', N'cardi_cardi', 'username'
    UNION ALL
    SELECT N'Cpt Cod Eye', N'CptCodEye', 'username'
    UNION ALL
    SELECT N'Cpt Cod Eye', N'Cpt_Cod_Eye', 'username'
    UNION ALL
    SELECT N'DeathMachineUA _gaming', N'DeathMachineUA', 'username'
    UNION ALL
    SELECT N'DeathMachineUA _gaming', N'DeathMachineUA_gaming', 'username'
    UNION ALL
    SELECT N'DeathMachineUA _gaming', N'DeathMachineUAgaming', 'username'
    UNION ALL
    SELECT N'Disc-manfromthesouth3 fp MrTroyMan', N'MrTroyMan', 'username'
    UNION ALL
    SELECT N'Disc-manfromthesouth3 fp MrTroyMan', N'Disc-manfromthesouth3', 'username'
    UNION ALL
    SELECT N'DJ Truck Driver', N'DJTruckDriver', 'username'
    UNION ALL
    SELECT N'DJ Truck Driver', N'DJ_Truck_Driver', 'username'
    UNION ALL
    SELECT N'Doctor-Law', N'DoctorLaw', 'username'
    UNION ALL
    SELECT N'dope guy', N'dopeguy', 'username'
    UNION ALL
    SELECT N'dope guy', N'dope_guy', 'username'
    UNION ALL
    SELECT N'Đuka99', N'Duka99', 'username'
    UNION ALL
    SELECT N'Đuka99', N'Djuka99', 'username'
    UNION ALL
    SELECT N'DXLUSIXNAL Skettyjr', N'DXLUSIXNAL', 'username'
    UNION ALL
    SELECT N'DXLUSIXNAL Skettyjr', N'Skettyjr', 'username'
    UNION ALL
    SELECT N'EnlightedWhitefishPrince', N'EnlightenedWhitefishPrince', 'username'
    UNION ALL
    SELECT N'EnourmosGarHunter', N'EnormousGarHunter', 'username'
    UNION ALL
    SELECT N'FantasicPerchDaddy62', N'FantasticPerchDaddy62', 'username'
    UNION ALL
    SELECT N'far5915 in fishing planet game, Galaxia90 on steam', N'far5915', 'username'
    UNION ALL
    SELECT N'far5915 in fishing planet game, Galaxia90 on steam', N'Galaxia90', 'username'
    UNION ALL
    SELECT N'Fishing planaet (Edupu) Steam (R.D.A)', N'Edupu', 'username'
    UNION ALL
    SELECT N'Fishing planaet (Edupu) Steam (R.D.A)', N'R.D.A', 'username'
    UNION ALL
    SELECT N'Fishing planaet (Edupu) Steam (R.D.A)', N'RDA', 'username'
    UNION ALL
    SELECT N'Fishing planet nickname: Prost_Plovs  Steam nickname: Pizza_slice', N'Prost_Plovs', 'username'
    UNION ALL
    SELECT N'Fishing planet nickname: Prost_Plovs  Steam nickname: Pizza_slice', N'Pizza_slice', 'username'
    UNION ALL
    SELECT N'Fishing Planet username is Toyotaguy', N'Toyotaguy', 'username'
    UNION ALL
    SELECT N'Fishing planet: D4B0mb        Discord: d4bomb', N'D4B0mb', 'username'
    UNION ALL
    SELECT N'Fishing planet: D4B0mb        Discord: d4bomb', N'd4bomb', 'username'
    UNION ALL
    SELECT N'fishsthick123', N'fishstick123', 'username'
    UNION ALL
    SELECT N'FIxieIsMonk (Fishing Planet) ourguiltandregret (discord)', N'FIxieIsMonk', 'username'
    UNION ALL
    SELECT N'FixieIsMonk (if fishing planet account) Fixie (if discord)', N'FixieIsMonk', 'username'
    UNION ALL
    SELECT N'foesleitner.roland', N'foesleitner_roland', 'username'
    UNION ALL
    SELECT N'foesleitner.roland', N'foesleitnerroland', 'username'
    UNION ALL
    SELECT N'Gkuba1999@gmail.com', N'Gkuba1999', 'username'
    UNION ALL
    SELECT N'Gkuba1999@gmail.com', N'Gkuba1999@gmail.com', 'email'
    UNION ALL
    SELECT N'greedydevsstopmakingpaidDLC''s', N'greedydevsstopmakingpaidDLC', 'username'
    UNION ALL
    SELECT N'greedydevsstopmakingpaidDLC''s', N'greedydevsstopmakingpaidDLCs', 'username'
    UNION ALL
    SELECT N'Guillaume C 3D', N'GuillaumeC3D', 'username'
    UNION ALL
    SELECT N'Guillaume C 3D', N'Guillaume_C_3D', 'username'
    UNION ALL
    SELECT N'Hubert Urbański', N'HubertUrbanski', 'username'
    UNION ALL
    SELECT N'Hubert Urbański', N'Hubert_Urbanski', 'username'
    UNION ALL
    SELECT N'Hunter Billings', N'HunterBillings', 'username'
    UNION ALL
    SELECT N'Hunter Billings', N'Hunter_Billings', 'username'
    UNION ALL
    SELECT N'Indra Kurnia', N'IndraKurnia', 'username'
    UNION ALL
    SELECT N'Indra Kurnia', N'Indra_Kurnia', 'username'
    UNION ALL
    SELECT N'Ivakis Solo', N'IvakisSolo', 'username'
    UNION ALL
    SELECT N'Ivakis Solo', N'Ivakis_Solo', 'username'
    UNION ALL
    SELECT N'Jack Mcerlaine', N'JackMcerlaine', 'username'
    UNION ALL
    SELECT N'Jack Mcerlaine', N'Jack_Mcerlaine', 'username'
    UNION ALL
    SELECT N'Jekyll&Hyde', N'JekyllHyde', 'username'
    UNION ALL
    SELECT N'Jekyll&Hyde', N'Jekyll_Hyde', 'username'
    UNION ALL
    SELECT N'Jeremie kasspied', N'Jeremiekasspied', 'username'
    UNION ALL
    SELECT N'Jeremie kasspied', N'Jeremie_kasspied', 'username'
    UNION ALL
    SELECT N'John Carl', N'JohnCarl', 'username'
    UNION ALL
    SELECT N'John Carl', N'John_Carl', 'username'
    UNION ALL
    SELECT N'kamciolskins.army CS2.ME', N'kamciolskins.army', 'username'
    UNION ALL
    SELECT N'kamciolskins.army CS2.ME', N'kamciolskins', 'username'
    UNION ALL
    SELECT N'kiwiparents0f5', N'kiwiparentsof5', 'username'
    UNION ALL
    SELECT N'Knot_me_Not or O.Azeitona in game.', N'O.Azeitona', 'username'
    UNION ALL
    SELECT N'Knot_me_Not or O.Azeitona in game.', N'OAzeitona', 'username'
    UNION ALL
    SELECT N'Knot_me_Not or O.Azeitona in game.', N'Knot_me_Not', 'username'
    UNION ALL
    SELECT N'KTMO on Discord (KTMO88 on game)', N'KTMO88', 'username'
    UNION ALL
    SELECT N'LKR |·calvin cordobé', N'calvincordobe', 'username'
    UNION ALL
    SELECT N'LKR |·calvin cordobé', N'calvin_cordobe', 'username'
    UNION ALL
    SELECT N'LKR |·calvin cordobé', N'calvincordobé', 'username'
    UNION ALL
    SELECT N'MAJOR DOWNY BROWN', N'MAJORDOWNYBROWN', 'username'
    UNION ALL
    SELECT N'MAJOR DOWNY BROWN', N'MAJOR_DOWNY_BROWN', 'username'
    UNION ALL
    SELECT N'Meateater28  or outstndingpaladin', N'Meateater28', 'username'
    UNION ALL
    SELECT N'Meateater28  or outstndingpaladin', N'outstndingpaladin', 'username'
    UNION ALL
    SELECT N'Mototasma Funkeiro', N'MototasmaFunkeiro', 'username'
    UNION ALL
    SELECT N'Mototasma Funkeiro', N'Mototasma_Funkeiro', 'username'
    UNION ALL
    SELECT N'Mpmento_Mori_UA', N'Memento_Mori_UA', 'username'
    UNION ALL
    SELECT N'My discord name is Prxme or p.r.x.m.e my steam is Br00ther7', N'Br00ther7', 'username'
    UNION ALL
    SELECT N'My discord name is Prxme or p.r.x.m.e my steam is Br00ther7', N'Prxme', 'username'
    UNION ALL
    SELECT N'My discord name is Prxme or p.r.x.m.e my steam is Br00ther7', N'p.r.x.m.e', 'username'
    UNION ALL
    SELECT N'My nickname is Bargearse: In North Queensland, Australia we have the Great Barrier Reef which has great bottom fishing as well as world class Sport and Game fishing along with big sharks and groper. As well as this we have several rivers, both salt and fresh, that contain Barramundi, Catfish, Bull Sharks, etc so I think it would be a great addition to the game. Whatever map you decide to add no doubt we will be heavily restricted by a pay wall so I mightn''t even fish it.', N'Bargearse', 'username'
    UNION ALL
    SELECT N'my steamid is palmtreeman', N'palmtreeman', 'username'
    UNION ALL
    SELECT N'NgChill-Ya-Mancing', N'NgChillYaMancing', 'username'
    UNION ALL
    SELECT N'Nicolas MOENCH', N'NicolasMOENCH', 'username'
    UNION ALL
    SELECT N'Nicolas MOENCH', N'Nicolas_MOENCH', 'username'
    UNION ALL
    SELECT N'nilson-nakamura', N'nilsonnakamura', 'username'
    UNION ALL
    SELECT N'nilson-nakamura', N'nilson_nakamura', 'username'
    UNION ALL
    SELECT N'Nuno Henrique Justo Frazão', N'NunoHenriqueJustoFrazao', 'username'
    UNION ALL
    SELECT N'Nuno Henrique Justo Frazão', N'NunoFrazao', 'username'
    UNION ALL
    SELECT N'Nyoraco‗Twitch', N'Nyoraco', 'username'
    UNION ALL
    SELECT N'Nyoraco‗Twitch', N'Nyoraco_Twitch', 'username'
    UNION ALL
    SELECT N'Nyoraco‗Twitch', N'NyoracoTwitch', 'username'
    UNION ALL
    SELECT N'Ockert 69', N'Ockert69', 'username'
    UNION ALL
    SELECT N'Ockert 69', N'Ockert_69', 'username'
    UNION ALL
    SELECT N'PACO BARBA', N'PACOBARBA', 'username'
    UNION ALL
    SELECT N'PACO BARBA', N'PACO_BARBA', 'username'
    UNION ALL
    SELECT N'pasiek (with cat on profil)', N'pasiek', 'username'
    UNION ALL
    SELECT N'Physcko corndog', N'Physckocorndog', 'username'
    UNION ALL
    SELECT N'Physcko corndog', N'Physcko_corndog', 'username'
    UNION ALL
    SELECT N'pirat patryk', N'piratpatryk', 'username'
    UNION ALL
    SELECT N'pirat patryk', N'pirat_patryk', 'username'
    UNION ALL
    SELECT N'PowerfulCastingMystic   (I clicked and changed my username)', N'PowerfulCastingMystic', 'username'
    UNION ALL
    SELECT N'RANGER_HITAM-Casadei', N'Casadei', 'username'
    UNION ALL
    SELECT N'RANGER_HITAM-Casadei', N'RANGER_HITAM', 'username'
    UNION ALL
    SELECT N'raptorlorient56 niv 96', N'raptorlorient56', 'username'
    UNION ALL
    SELECT N'Reggie Carter', N'ReggieCarter', 'username'
    UNION ALL
    SELECT N'Reggie Carter', N'Reggie_Carter', 'username'
    UNION ALL
    SELECT N'serfuje pl CYGBUD', N'CYGBUD', 'username'
    UNION ALL
    SELECT N'serfuje pl CYGBUD', N'serfuje', 'username'
    UNION ALL
    SELECT N'Spazlux (steam)', N'Spazlux', 'username'
    UNION ALL
    SELECT N'Splendedcarpmercenary', N'Splendidcarpmercenary', 'username'
    UNION ALL
    SELECT N'Sr-Puff', N'SrPuff', 'username'
    UNION ALL
    SELECT N'Sr-Puff', N'Sr_Puff', 'username'
    UNION ALL
    SELECT N'TPassive Killer', N'TPassiveKiller', 'username'
    UNION ALL
    SELECT N'TPassive Killer', N'TPassive_Killer', 'username'
    UNION ALL
    SELECT N'twitch_b0rreg0chan nivel 100', N'twitch_b0rreg0chan', 'username'
    UNION ALL
    SELECT N'twitch_b0rreg0chan nivel 100', N'b0rreg0chan', 'username'
    UNION ALL
    SELECT N'username Spyder_tj nickname Mr. Bones', N'Mr.Bones', 'username'
    UNION ALL
    SELECT N'username Spyder_tj nickname Mr. Bones', N'MrBones', 'username'
    UNION ALL
    SELECT N'username Spyder_tj nickname Mr. Bones', N'Mr_Bones', 'username'
    UNION ALL
    SELECT N'van-62', N'van_62', 'username'
    UNION ALL
    SELECT N'van-62', N'van62', 'username'
    UNION ALL
    SELECT N'vanthanh_', N'vanthanh', 'username'
    UNION ALL
    SELECT N'Vinny Deepwater', N'VinnyDeepwater', 'username'
    UNION ALL
    SELECT N'Vinny Deepwater', N'Vinny_Deepwater', 'username'
    UNION ALL
    SELECT N'WALCZ! | Djabeu', N'Djabeu', 'username'
    UNION ALL
    SELECT N'WALCZ! | Djabeu', N'WALCZ', 'username'
    UNION ALL
    SELECT N'washed.', N'washed', 'username'
    UNION ALL
    SELECT N'water(steam name)', N'water', 'username'
    UNION ALL
    SELECT N'X-Wali', N'XWali', 'username'
    UNION ALL
    SELECT N'X-Wali', N'X_Wali', 'username'
    UNION ALL
    SELECT N'Yargar PL', N'YargarPL', 'username'
    UNION ALL
    SELECT N'Yargar PL', N'Yargar_PL', 'username'
    UNION ALL
    SELECT N'Бойка', N'Boyka', 'username'
    UNION ALL
    SELECT N'Бойка', N'Boika', 'username'
    UNION ALL
    SELECT N'白嫖骑士', N'BaiPiaoQiShi', 'username'
    UNION ALL
    SELECT N'白嫖骑士', N'FreeloaderKnight', 'username'
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
