// FP-43631 ban log backfill — STEAM PROD Mongo
// Run against [F2P] STEAM PROD Mongo (collection: banLog)
// Posts 75 retroactive entries for the cohort banned via week2-ban-execution.sql on 2026-05-17 ~23:30 UTC.
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation).

var TS    = ISODate("2026-05-17T23:30:00.000Z");
var MSG_C = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up — no-show abuse (week-2 comparison)' until 2026-06-17 00:00:00";
var MSG_S = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up — no-show abuse (week-2 comparison)' until 2026-06-01 00:00:00";

db.banLog.insertMany([
  // CONTINUED (37) — BanEndDate 2026-06-17
  { Timestamp: TS, UserId: "3e9cf475-df93-4a27-af1a-3e39e7d7df1a", Message: MSG_C, RequestId: null }, // AC_GAMEBOT
  { Timestamp: TS, UserId: "af03131f-0553-4ea3-bb33-480d4c0b1d3c", Message: MSG_C, RequestId: null }, // BolinhaWJB
  { Timestamp: TS, UserId: "7f670dac-aa1b-4c86-b264-faa1dbb8a7a7", Message: MSG_C, RequestId: null }, // chenmuya
  { Timestamp: TS, UserId: "f4c50336-cff0-42ef-8934-4e73db14f0b7", Message: MSG_C, RequestId: null }, // chinaDF5C
  { Timestamp: TS, UserId: "c252a85e-94e5-4e10-88a3-ceac37a85a9d", Message: MSG_C, RequestId: null }, // Edukoi
  { Timestamp: TS, UserId: "f80df54f-b077-4665-9822-a43414055b1e", Message: MSG_C, RequestId: null }, // EsseDouble
  { Timestamp: TS, UserId: "d9b3468f-50ec-43a9-bcb1-266c75d9b6d3", Message: MSG_C, RequestId: null }, // fomaka8
  { Timestamp: TS, UserId: "ae005a2a-313a-4412-be77-a80fdfb7a454", Message: MSG_C, RequestId: null }, // FT.ZZZ
  { Timestamp: TS, UserId: "7a0f9e1f-441b-4dc7-9286-e1dae75d88a6", Message: MSG_C, RequestId: null }, // FUMATII-ESTAA
  { Timestamp: TS, UserId: "746be21d-ad49-4224-9cbe-2bb96efc0b5c", Message: MSG_C, RequestId: null }, // IFC_DIT-TO
  { Timestamp: TS, UserId: "cd4a6026-713b-4a9c-995a-8970f18fbd33", Message: MSG_C, RequestId: null }, // IkanBobo
  { Timestamp: TS, UserId: "652885cd-dba6-4e2f-ad8f-8b91fcaf805b", Message: MSG_C, RequestId: null }, // JAMNF13
  { Timestamp: TS, UserId: "7043d475-a8f7-4421-bdf1-f3256fb9d4fc", Message: MSG_C, RequestId: null }, // LeeooRP
  { Timestamp: TS, UserId: "8e756e04-1a3d-471c-9c10-a55f6023bb1f", Message: MSG_C, RequestId: null }, // lin-123
  { Timestamp: TS, UserId: "68c047fc-9f03-4195-8a59-e1d258eb9253", Message: MSG_C, RequestId: null }, // Master10086
  { Timestamp: TS, UserId: "06ca0e9c-8ebb-4456-a94e-8d1d407a30c3", Message: MSG_C, RequestId: null }, // MOF_Adriano
  { Timestamp: TS, UserId: "b8ca6b12-3057-4bbe-9980-53f655fcf065", Message: MSG_C, RequestId: null }, // Myky0576
  { Timestamp: TS, UserId: "c4d9c8fa-613c-4f4f-92c1-94979367161d", Message: MSG_C, RequestId: null }, // NicePoopMachine11
  { Timestamp: TS, UserId: "23ef4804-3530-4917-b3d0-03c9e862ab6b", Message: MSG_C, RequestId: null }, // nM.Wokka
  { Timestamp: TS, UserId: "bf3d187d-1b30-45cf-8c50-fb43b1439669", Message: MSG_C, RequestId: null }, // NotoriousOne
  { Timestamp: TS, UserId: "0d08dbc9-eaba-4b72-b806-2fb5e22845ab", Message: MSG_C, RequestId: null }, // O7_MR
  { Timestamp: TS, UserId: "b71d270f-fa17-4e99-9ae6-8f7169379449", Message: MSG_C, RequestId: null }, // o-huo
  { Timestamp: TS, UserId: "b6825b26-a30b-4063-a21b-61359f8b92ec", Message: MSG_C, RequestId: null }, // PKOne_official
  { Timestamp: TS, UserId: "551a9cfd-d2ed-4d40-822e-7956da9efce5", Message: MSG_C, RequestId: null }, // rambo04
  { Timestamp: TS, UserId: "e7e26744-fb2e-4c5a-8851-949eaa8d219c", Message: MSG_C, RequestId: null }, // Rodmaster88
  { Timestamp: TS, UserId: "5b3f6d46-004b-4eb6-a823-e9153bf75463", Message: MSG_C, RequestId: null }, // ScummyLIVE
  { Timestamp: TS, UserId: "15bcb6ab-60db-4ae0-9b8e-91ac3ed01a1c", Message: MSG_C, RequestId: null }, // Serega_MiG
  { Timestamp: TS, UserId: "11363837-35d7-43d2-bd9d-a3044f35c5a3", Message: MSG_C, RequestId: null }, // Sne4CKy
  { Timestamp: TS, UserId: "b8428b8d-7ebf-4924-a9ed-29cb02ce01fc", Message: MSG_C, RequestId: null }, // TheBestAHFan
  { Timestamp: TS, UserId: "22acf515-3d8e-4554-b5a0-faab06a0d4b2", Message: MSG_C, RequestId: null }, // tsukuyxmi
  { Timestamp: TS, UserId: "741ce389-345e-4d53-8a46-e2cb3f026902", Message: MSG_C, RequestId: null }, // UKROP_UA
  { Timestamp: TS, UserId: "14b955ca-2044-4171-bd98-e768418878c8", Message: MSG_C, RequestId: null }, // vodou61
  { Timestamp: TS, UserId: "80c34ed9-a35f-4fc7-8c6f-7a6578b47e86", Message: MSG_C, RequestId: null }, // W0lfver1ne
  { Timestamp: TS, UserId: "56189f57-f7df-4dc7-837c-0f10533e26ea", Message: MSG_C, RequestId: null }, // wanyi12138
  { Timestamp: TS, UserId: "135725a2-637f-44f3-8389-df61b85f4e67", Message: MSG_C, RequestId: null }, // X1aoDouYa
  { Timestamp: TS, UserId: "95c8f164-8baf-467e-9826-9cafdcfa968e", Message: MSG_C, RequestId: null }, // X-SacredAngler
  { Timestamp: TS, UserId: "0a030aa4-e9dd-4c88-b0b0-934003afc79a", Message: MSG_C, RequestId: null }, // Zoio_Bruxo157

  // STARTED (38) — BanEndDate 2026-06-01
  { Timestamp: TS, UserId: "0ae5b8cd-f06e-4cf5-bd0c-3c2d945632d8", Message: MSG_S, RequestId: null }, // Batu38
  { Timestamp: TS, UserId: "6f8d28f6-e440-40cb-8cce-6161c3b48765", Message: MSG_S, RequestId: null }, // CirnoOOObaka
  { Timestamp: TS, UserId: "f1fdc8d1-6090-4a4a-b6ba-d61ec5087034", Message: MSG_S, RequestId: null }, // EmersonSparky
  { Timestamp: TS, UserId: "a3e0adcb-fb01-4b6e-8809-d3d0de48ce8b", Message: MSG_S, RequestId: null }, // FigaroFegget
  { Timestamp: TS, UserId: "10a0fff3-e631-413b-b5fa-30208635f2a6", Message: MSG_S, RequestId: null }, // FOGGIA1920
  { Timestamp: TS, UserId: "261b0ba0-5be1-4ec1-95bc-bd2350fe2fda", Message: MSG_S, RequestId: null }, // GloomyBayOutlaw
  { Timestamp: TS, UserId: "342e02e6-2369-4f00-be91-012d1bc924d5", Message: MSG_S, RequestId: null }, // GrayPlanktonPaladin
  { Timestamp: TS, UserId: "a686254b-4451-4609-968f-10cba4be9505", Message: MSG_S, RequestId: null }, // irvin85
  { Timestamp: TS, UserId: "13d390e6-0cb7-4f30-9846-24cc994bbde2", Message: MSG_S, RequestId: null }, // JFF_Gothyka
  { Timestamp: TS, UserId: "7ba48b70-cf01-4671-8183-e11ddb5e5b63", Message: MSG_S, RequestId: null }, // JFF_Vinss62
  { Timestamp: TS, UserId: "3f0b7ecb-e81b-4123-974d-f1f6a4f77b3e", Message: MSG_S, RequestId: null }, // KOP_LR07
  { Timestamp: TS, UserId: "dec5654d-3307-4ce3-acfb-187af3ca66e6", Message: MSG_S, RequestId: null }, // KOP_Speedy
  { Timestamp: TS, UserId: "bb1fb1c6-cda5-4cc4-975b-797db64bfb8b", Message: MSG_S, RequestId: null }, // kos1904_UA
  { Timestamp: TS, UserId: "7a31dbbb-b87f-4fad-bc2d-8ffe5101f85b", Message: MSG_S, RequestId: null }, // Kris61
  { Timestamp: TS, UserId: "ecd7c883-b869-4723-af93-9e50c7a78dd9", Message: MSG_S, RequestId: null }, // Mokraya_Pisichka
  { Timestamp: TS, UserId: "0e9ef191-68bb-48de-bf02-f11571119a6f", Message: MSG_S, RequestId: null }, // Mr-Crabs
  { Timestamp: TS, UserId: "553881ab-8528-4311-b562-75cf39f54312", Message: MSG_S, RequestId: null }, // NWTRASLER
  { Timestamp: TS, UserId: "a054c29e-8d62-4129-8b4d-fe049915531e", Message: MSG_S, RequestId: null }, // OnyxGillsRogue
  { Timestamp: TS, UserId: "f193e57a-d3d5-483f-8aa2-5e5303ca7d35", Message: MSG_S, RequestId: null }, // Pescadora_Selvagem
  { Timestamp: TS, UserId: "b52a537f-f1d7-4862-a644-e8e3a99705df", Message: MSG_S, RequestId: null }, // Pescapiaui
  { Timestamp: TS, UserId: "15a01b1c-b694-4147-8466-af94428f48cc", Message: MSG_S, RequestId: null }, // Pexi86
  { Timestamp: TS, UserId: "952eed36-e6a1-40dd-acd6-7bc8831500cb", Message: MSG_S, RequestId: null }, // Pilou62
  { Timestamp: TS, UserId: "fb74806a-aa01-4d6c-a1c6-b697b4b3e6da", Message: MSG_S, RequestId: null }, // ProAndy.EXE
  { Timestamp: TS, UserId: "c684a7fe-7e30-49c7-a52d-506e0cac9470", Message: MSG_S, RequestId: null }, // RedCompGenius
  { Timestamp: TS, UserId: "a2316687-f0dc-4cee-bef2-5a42d6af275a", Message: MSG_S, RequestId: null }, // RI-1-Prabowo
  { Timestamp: TS, UserId: "8fb4514c-ed11-4440-8f18-6b5fcf22027a", Message: MSG_S, RequestId: null }, // shadow-fear
  { Timestamp: TS, UserId: "edd8d34e-325b-4b10-8a9a-7507c3d1bfe9", Message: MSG_S, RequestId: null }, // sledingMANTANistri
  { Timestamp: TS, UserId: "bf3579a2-5207-4159-a1b7-51acaa729b54", Message: MSG_S, RequestId: null }, // SUMBULBRIFIR
  { Timestamp: TS, UserId: "e5040b18-f216-4244-b4a1-ae90a26a0550", Message: MSG_S, RequestId: null }, // SVIP999
  { Timestamp: TS, UserId: "f164efe3-72a0-4517-96a3-7574c90aab91", Message: MSG_S, RequestId: null }, // SwiftLagoonLord
  { Timestamp: TS, UserId: "5a66db98-970c-4d1c-869a-4eb8ed75d2f9", Message: MSG_S, RequestId: null }, // taktuu
  { Timestamp: TS, UserId: "4d3efd74-6b2b-4e65-b434-a63d08bc6f68", Message: MSG_S, RequestId: null }, // TTC-SWAX
  { Timestamp: TS, UserId: "0a315cff-7b68-4ef0-b4e7-8490ae84c58b", Message: MSG_S, RequestId: null }, // U420A
  { Timestamp: TS, UserId: "ca9e447a-ec21-4989-bdf5-c047a52b70dd", Message: MSG_S, RequestId: null }, // UjangBlonde
  { Timestamp: TS, UserId: "d2dd7657-e8fc-4994-bb75-d7e894f53462", Message: MSG_S, RequestId: null }, // UkrainianLegend
  { Timestamp: TS, UserId: "8ad35c2d-b6ea-429d-8fc0-3cdbab4d260d", Message: MSG_S, RequestId: null }, // VM_NOi
  { Timestamp: TS, UserId: "254580ab-a1bf-4a18-99e0-2675abf013ba", Message: MSG_S, RequestId: null }, // WoulduRather7
  { Timestamp: TS, UserId: "0f706f7c-0d3f-45fb-adb3-f9ca23a4bdd0", Message: MSG_S, RequestId: null }  // xFenrir
]);

// Verify (expect 75):
// db.banLog.find({ Timestamp: ISODate("2026-05-17T23:30:00.000Z"), Message: /FP-43631 follow-up/ }).count();
