// FP-43631 ban log backfill — PS PROD Mongo
// Run against [F2P] PS PROD Mongo (collection: banLog)
// Posts 84 retroactive entries for the cohort banned via week2-ban-execution.sql on 2026-05-17 ~23:30 UTC.
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation).

var TS    = ISODate("2026-05-17T23:30:00.000Z");
var MSG_C = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up — no-show abuse (week-2 comparison)' until 2026-06-17 00:00:00";
var MSG_S = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up — no-show abuse (week-2 comparison)' until 2026-06-01 00:00:00";

db.banLog.insertMany([
  // CONTINUED (22) — BanEndDate 2026-06-17
  { Timestamp: TS, UserId: "413754c5-5afe-4c5a-81ae-e6f662220ac6", Message: MSG_C, RequestId: null }, // Besy_1991
  { Timestamp: TS, UserId: "8a4e6218-28f4-4cff-8c2d-49a85fc66378", Message: MSG_C, RequestId: null }, // browney73
  { Timestamp: TS, UserId: "becc3b59-5ef7-4aad-a428-9122f7a870a0", Message: MSG_C, RequestId: null }, // DaKingslayer34
  { Timestamp: TS, UserId: "262f4cbb-0970-44e3-b9d0-5139bdac86eb", Message: MSG_C, RequestId: null }, // Geelevens
  { Timestamp: TS, UserId: "1a1e819f-ae99-477e-80eb-7d0f4cfe4cde", Message: MSG_C, RequestId: null }, // Guns4Gary
  { Timestamp: TS, UserId: "06bb9d34-bc04-4591-80f6-0f8ad8f05087", Message: MSG_C, RequestId: null }, // IKIGAI__1__
  { Timestamp: TS, UserId: "6407b03e-d273-4329-8ba0-91bcd94d148e", Message: MSG_C, RequestId: null }, // jeffbob1979
  { Timestamp: TS, UserId: "16e9369a-8710-40a1-90fd-7938daae9bb7", Message: MSG_C, RequestId: null }, // LIP_RIPPER3233
  { Timestamp: TS, UserId: "cb3703a3-1a93-49c9-aafd-946bc825ff47", Message: MSG_C, RequestId: null }, // lucyrex69
  { Timestamp: TS, UserId: "418f3ed0-c447-430f-a808-f197ac668c13", Message: MSG_C, RequestId: null }, // michelplat
  { Timestamp: TS, UserId: "cfdf2fa5-7c1d-4531-9238-b2aadef27391", Message: MSG_C, RequestId: null }, // mirador01
  { Timestamp: TS, UserId: "6940d7a1-d527-4484-9ea7-0676a6d8a5ef", Message: MSG_C, RequestId: null }, // naked-fishing
  { Timestamp: TS, UserId: "abd1ea6d-3ee0-4b4e-bc3b-66c7fae4028b", Message: MSG_C, RequestId: null }, // olimpiada__80
  { Timestamp: TS, UserId: "77d4ca73-e111-4f74-bee7-20a76a02d3e0", Message: MSG_C, RequestId: null }, // otc-X1-
  { Timestamp: TS, UserId: "3c8366e8-9669-47a4-87eb-1059d07eae21", Message: MSG_C, RequestId: null }, // Proz_For_Life
  { Timestamp: TS, UserId: "553d6b17-7aca-4f9f-9fcc-d5a38276b990", Message: MSG_C, RequestId: null }, // QG_Geo_vane
  { Timestamp: TS, UserId: "66687801-8051-48bf-a297-07d6f95ff338", Message: MSG_C, RequestId: null }, // QG_ZOCA
  { Timestamp: TS, UserId: "118b21ed-1d89-4a8d-8296-922452775439", Message: MSG_C, RequestId: null }, // Sajler_1_
  { Timestamp: TS, UserId: "13d1c7c7-1b4d-4a3e-9890-8b4391519ebf", Message: MSG_C, RequestId: null }, // Whip-_-FP-_-
  { Timestamp: TS, UserId: "4f4e4cdc-eef1-4d79-91c0-47e552afd7e1", Message: MSG_C, RequestId: null }, // yohan-josse-85
  { Timestamp: TS, UserId: "c869b021-3535-4205-a818-b23344024001", Message: MSG_C, RequestId: null }, // Zatumbik
  { Timestamp: TS, UserId: "d1cb3b8d-c3c4-4491-8af2-6123fd9606c2", Message: MSG_C, RequestId: null }, // Zlat87_X-Series

  // STARTED (62) — BanEndDate 2026-06-01
  { Timestamp: TS, UserId: "4a3375b0-59fc-415f-97f7-e8882de62524", Message: MSG_S, RequestId: null }, // AAPC-kaige
  { Timestamp: TS, UserId: "93e7f4b7-9499-408c-a239-70abdeb457d5", Message: MSG_S, RequestId: null }, // BE_Cr1st1an
  { Timestamp: TS, UserId: "4d6c6744-33a8-48c6-9d16-d0ad72327202", Message: MSG_S, RequestId: null }, // berg-zug
  { Timestamp: TS, UserId: "fe73183f-eed7-4dfa-ad85-d279c5fd80b6", Message: MSG_S, RequestId: null }, // Black_pantherUSA
  { Timestamp: TS, UserId: "cf481161-89dc-4072-90a9-82cb2b27de4f", Message: MSG_S, RequestId: null }, // bold_blade409
  { Timestamp: TS, UserId: "5db0a328-1307-4762-a1db-7ff34e63bfe5", Message: MSG_S, RequestId: null }, // bostonbroncos24
  { Timestamp: TS, UserId: "9f90e055-b7e8-4458-8565-f4c88ad7f7f4", Message: MSG_S, RequestId: null }, // boule_tueuse
  { Timestamp: TS, UserId: "8c49f4d0-8df2-46d1-9af3-fcd24c5a25e4", Message: MSG_S, RequestId: null }, // Brasil-Fernando_
  { Timestamp: TS, UserId: "4d62bbe9-29f3-4815-851b-2c30d65996fe", Message: MSG_S, RequestId: null }, // bullr1de5
  { Timestamp: TS, UserId: "7338b1a9-3a20-486f-97b7-4a60493422dc", Message: MSG_S, RequestId: null }, // car_wild995
  { Timestamp: TS, UserId: "d21225c2-00bb-45e2-a7ce-c132d9a6448c", Message: MSG_S, RequestId: null }, // Cedric-02000
  { Timestamp: TS, UserId: "d17de48c-4ca9-43c8-b006-ffa6183a6f1a", Message: MSG_S, RequestId: null }, // CFC-Marquezim
  { Timestamp: TS, UserId: "00f02301-1d40-4666-80bd-f5bb68196cf4", Message: MSG_S, RequestId: null }, // chris65445690099
  { Timestamp: TS, UserId: "c161f041-5afb-464b-b6d5-bca02b6cff08", Message: MSG_S, RequestId: null }, // Closedporcupine
  { Timestamp: TS, UserId: "b2f00f2e-2018-44a8-b8b2-0708d3597fb6", Message: MSG_S, RequestId: null }, // connorsamson6546
  { Timestamp: TS, UserId: "80ad43c0-f3ff-4fe8-b2dd-b653f169f75f", Message: MSG_S, RequestId: null }, // coro280
  { Timestamp: TS, UserId: "c7cc4081-3f8e-4591-ace2-8f5715ba2263", Message: MSG_S, RequestId: null }, // CP_Rojao12Vala
  { Timestamp: TS, UserId: "e4e9f1dd-5c49-4f89-a41f-0ef5e9829913", Message: MSG_S, RequestId: null }, // Cra-Poulette
  { Timestamp: TS, UserId: "dffe7879-d8fa-439e-8ecf-31636f49cfd7", Message: MSG_S, RequestId: null }, // DaSs-2613
  { Timestamp: TS, UserId: "2cd5cec1-a3ef-4611-84c2-d799d4e6b9a6", Message: MSG_S, RequestId: null }, // dommitab
  { Timestamp: TS, UserId: "e235f02d-e3c7-48a8-9ea7-999042cf4301", Message: MSG_S, RequestId: null }, // ellgringo1983
  { Timestamp: TS, UserId: "08211913-bd17-4126-8fb1-946085f67238", Message: MSG_S, RequestId: null }, // eraul50100
  { Timestamp: TS, UserId: "ef811669-3c30-4469-accb-3d5ec74dcde6", Message: MSG_S, RequestId: null }, // EZ-AllenWrench
  { Timestamp: TS, UserId: "3ace0f99-6215-4963-b1ec-72ca62855992", Message: MSG_S, RequestId: null }, // fabinoux53
  { Timestamp: TS, UserId: "ea640f76-2e33-4459-8cf3-1ef69eb6d00f", Message: MSG_S, RequestId: null }, // fiestero45
  { Timestamp: TS, UserId: "c2c46bea-48db-4640-afa8-b66f228210f5", Message: MSG_S, RequestId: null }, // Fifi082017
  { Timestamp: TS, UserId: "76b5f7f3-346a-46b1-9c70-4fe0743572c3", Message: MSG_S, RequestId: null }, // Flo-GrayFOX
  { Timestamp: TS, UserId: "0e4c4a88-af28-4e7e-b57f-9a85133f96e8", Message: MSG_S, RequestId: null }, // FPI_BostonGeorg_
  { Timestamp: TS, UserId: "fb1c37cd-b5d2-4a1e-b3e8-a9173621b2a4", Message: MSG_S, RequestId: null }, // FPI_Fvmazz
  { Timestamp: TS, UserId: "ae57251d-7708-4947-bab4-fa71552cebca", Message: MSG_S, RequestId: null }, // FPS_Zerbino85
  { Timestamp: TS, UserId: "bf9bcf1b-92ef-4c38-8588-14c456988cb9", Message: MSG_S, RequestId: null }, // fredtoso
  { Timestamp: TS, UserId: "56ae0ff1-7337-49bc-87e9-0b05f435ad44", Message: MSG_S, RequestId: null }, // glp023
  { Timestamp: TS, UserId: "7de8392c-6b0f-495b-ad09-43296a20fef7", Message: MSG_S, RequestId: null }, // guszto001
  { Timestamp: TS, UserId: "4f1c90f0-2a81-4595-9339-b548dd34cd0b", Message: MSG_S, RequestId: null }, // imminent_shoe3
  { Timestamp: TS, UserId: "51ff4dfb-31bf-4b74-b984-2e8cb6a1696b", Message: MSG_S, RequestId: null }, // james2629
  { Timestamp: TS, UserId: "62d767a5-9397-4146-bc98-a96f027817df", Message: MSG_S, RequestId: null }, // JOCHEN-666-
  { Timestamp: TS, UserId: "2e94e069-bc25-4590-b047-50816502feee", Message: MSG_S, RequestId: null }, // kamson170612
  { Timestamp: TS, UserId: "ef573a5d-e882-4be6-a388-2e6b03f4dad4", Message: MSG_S, RequestId: null }, // krzysztof-widz
  { Timestamp: TS, UserId: "23203c27-2301-49e9-ad19-2df699568227", Message: MSG_S, RequestId: null }, // Le_Zenzen80
  { Timestamp: TS, UserId: "e7b04618-95a1-4a8a-83c4-43becbbad9da", Message: MSG_S, RequestId: null }, // magikstar
  { Timestamp: TS, UserId: "bc99ae7e-aeaa-4e4f-959a-deee1b0ab03e", Message: MSG_S, RequestId: null }, // maitines
  { Timestamp: TS, UserId: "f0547940-6531-405a-8fd1-20f54b803935", Message: MSG_S, RequestId: null }, // MEGA_GRAVITIES
  { Timestamp: TS, UserId: "1ab9c5e1-c2a1-4cc9-a26c-35bf336016e0", Message: MSG_S, RequestId: null }, // MohandGamer7
  { Timestamp: TS, UserId: "7e745998-3686-4cc9-90f5-2c7001e44dbf", Message: MSG_S, RequestId: null }, // mrtoffeeman75
  { Timestamp: TS, UserId: "fd845e61-3261-4ccd-9ca1-85873d10445d", Message: MSG_S, RequestId: null }, // Ms-LisahLis
  { Timestamp: TS, UserId: "b9e10f37-0dea-4824-a8b2-ab55bc633ddc", Message: MSG_S, RequestId: null }, // Onlinebusiness
  { Timestamp: TS, UserId: "c896536d-28fa-4785-a85e-48c27b947590", Message: MSG_S, RequestId: null }, // Panonski_Alas
  { Timestamp: TS, UserId: "d2bd9321-da45-4454-b5a8-947248319973", Message: MSG_S, RequestId: null }, // pluczmers
  { Timestamp: TS, UserId: "0d087e43-d987-4473-8a8a-86c74ad1ee9f", Message: MSG_S, RequestId: null }, // RedBlitz77
  { Timestamp: TS, UserId: "0161d8c6-66c9-4d56-8ee3-fd0b8b9c752f", Message: MSG_S, RequestId: null }, // rentner365
  { Timestamp: TS, UserId: "422f528b-a147-42e8-a15c-2c817e6a45aa", Message: MSG_S, RequestId: null }, // Ro_kostbar_kraft
  { Timestamp: TS, UserId: "690ac9f2-4839-409e-8eeb-07d05685b252", Message: MSG_S, RequestId: null }, // RosUnbent
  { Timestamp: TS, UserId: "70e09be8-5355-4c3f-ab4e-06ab15b34321", Message: MSG_S, RequestId: null }, // serber-denis85
  { Timestamp: TS, UserId: "dba5f812-973c-4b50-b230-fc3e92dec118", Message: MSG_S, RequestId: null }, // sikosmiths
  { Timestamp: TS, UserId: "e25c082e-8a19-4236-aa8b-c345137e9ea3", Message: MSG_S, RequestId: null }, // STARI40K_YT
  { Timestamp: TS, UserId: "31b4ded5-7e65-4074-bc05-effd897c6d91", Message: MSG_S, RequestId: null }, // SUB-ZERO2430
  { Timestamp: TS, UserId: "881d8ada-db1a-4413-afb4-5674a75e8fc2", Message: MSG_S, RequestId: null }, // svs-Stefken
  { Timestamp: TS, UserId: "c30809b6-fb50-421a-ac66-435a31d4b278", Message: MSG_S, RequestId: null }, // thesoftandlazy
  { Timestamp: TS, UserId: "14db7502-f904-4e95-b82b-3212045fe4a2", Message: MSG_S, RequestId: null }, // TTVteamLazic
  { Timestamp: TS, UserId: "691f3b70-f538-4f99-96d8-74d62dd9887d", Message: MSG_S, RequestId: null }, // V1SENT1M_Lz
  { Timestamp: TS, UserId: "3e09ef0e-6bd0-425a-809a-4bb8fcd21378", Message: MSG_S, RequestId: null }, // xldizzylx420
  { Timestamp: TS, UserId: "99695d7b-e98d-4e1c-9153-e6fbd7f812d8", Message: MSG_S, RequestId: null }  // X-Series_Rodrigo
]);

// Verify (expect 84):
// db.banLog.find({ Timestamp: ISODate("2026-05-17T23:30:00.000Z"), Message: /FP-43631 follow-up/ }).count();
