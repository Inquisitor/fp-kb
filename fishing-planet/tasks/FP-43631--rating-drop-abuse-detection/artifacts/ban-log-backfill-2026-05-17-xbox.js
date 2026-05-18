// FP-43631 ban log backfill — XBOX PROD Mongo
// Run against [F2P] XB PROD Mongo (collection: banLog)
// Posts 26 retroactive entries for the cohort banned via week2-ban-execution.sql on 2026-05-17 ~23:30 UTC.
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation).

var TS    = ISODate("2026-05-17T23:30:00.000Z");
var MSG_C = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up — no-show abuse (week-2 comparison)' until 2026-06-17 00:00:00";
var MSG_S = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up — no-show abuse (week-2 comparison)' until 2026-06-01 00:00:00";

db.banLog.insertMany([
  // CONTINUED (10) — BanEndDate 2026-06-17
  { Timestamp: TS, UserId: "38856606-9a1c-458a-91a6-cef9aca5e5a3", Message: MSG_C, RequestId: null }, // BellaCiOoo
  { Timestamp: TS, UserId: "18494a55-d471-40db-955c-4bc1f0cb633e", Message: MSG_C, RequestId: null }, // Buckslayer86433
  { Timestamp: TS, UserId: "3d174d5c-0a64-4f13-bf2c-e7fa69a56e19", Message: MSG_C, RequestId: null }, // Direwolfx70
  { Timestamp: TS, UserId: "9439d534-3527-4d9c-a2d0-0b3df836b572", Message: MSG_C, RequestId: null }, // RaidedBYoff
  { Timestamp: TS, UserId: "ec371f4d-633e-45db-8b29-83de86c09dcb", Message: MSG_C, RequestId: null }, // rascof molotov
  { Timestamp: TS, UserId: "979e2b34-0aaa-4722-a800-f97ea2fa7032", Message: MSG_C, RequestId: null }, // RidwanJaya01
  { Timestamp: TS, UserId: "f1661b4b-025e-4aaf-a0a7-cad86c72498a", Message: MSG_C, RequestId: null }, // Roman77UA
  { Timestamp: TS, UserId: "93146a41-d7d2-4434-a35e-5a1bfef40cb8", Message: MSG_C, RequestId: null }, // SCATTER FS
  { Timestamp: TS, UserId: "353b440e-68bf-499a-9cb9-161d901dfcd2", Message: MSG_C, RequestId: null }, // ShrubnSE
  { Timestamp: TS, UserId: "87223c5f-5082-496f-88d4-507d31b540f5", Message: MSG_C, RequestId: null }, // ZellyRolled

  // STARTED (16) — BanEndDate 2026-06-01
  { Timestamp: TS, UserId: "8537cb8e-2bfc-417f-be59-584010a4fa97", Message: MSG_S, RequestId: null }, // AllBrokeByHate
  { Timestamp: TS, UserId: "df30183b-a1a5-45a9-8e65-e48d1470106c", Message: MSG_S, RequestId: null }, // Arayatron33
  { Timestamp: TS, UserId: "e8e1e33c-5579-4deb-906f-95634355800b", Message: MSG_S, RequestId: null }, // AZE GOYCAY
  { Timestamp: TS, UserId: "9df68aad-9a79-4680-81bd-8e6c7b6ec544", Message: MSG_S, RequestId: null }, // BadSirGame
  { Timestamp: TS, UserId: "013368d1-e8a8-437a-88b0-71059e3287eb", Message: MSG_S, RequestId: null }, // BuzzingLemur417
  { Timestamp: TS, UserId: "74d3cca7-0a1d-4f82-8b99-d86044c6e44c", Message: MSG_S, RequestId: null }, // Clepac ONJD
  { Timestamp: TS, UserId: "77b13cbc-24b2-4bf9-9a5b-e03052f277a0", Message: MSG_S, RequestId: null }, // DelfinatorFish
  { Timestamp: TS, UserId: "116c7330-b20b-4ff9-9321-c43c496b783b", Message: MSG_S, RequestId: null }, // DJBKINGZ6796
  { Timestamp: TS, UserId: "9cc51aed-3a80-4464-bd46-00c62c14189b", Message: MSG_S, RequestId: null }, // DOU FOR LIFE
  { Timestamp: TS, UserId: "0521e9f5-dcf5-438c-908d-689f0dfd2242", Message: MSG_S, RequestId: null }, // Fuzzytacos6571
  { Timestamp: TS, UserId: "0fe47a61-87ea-40bc-8fde-9d0d03217760", Message: MSG_S, RequestId: null }, // Maine John
  { Timestamp: TS, UserId: "87d7e8f8-c89c-4e0d-b0fb-f41c1bc42af6", Message: MSG_S, RequestId: null }, // SmirkyWord9283
  { Timestamp: TS, UserId: "970fab06-e54c-48e6-a731-754b4de600c4", Message: MSG_S, RequestId: null }, // TBF Fox
  { Timestamp: TS, UserId: "7d8fdbbc-37bd-4588-a890-a97f5d109337", Message: MSG_S, RequestId: null }, // TM BolinhaWJ
  { Timestamp: TS, UserId: "1ce9ebef-5c0d-49ae-9ba6-5abc67e45cf3", Message: MSG_S, RequestId: null }, // ToBeng3522
  { Timestamp: TS, UserId: "bdd6d57e-e41f-475e-b067-c0d990a5a92c", Message: MSG_S, RequestId: null }  // xFenrir77
]);

// Verify (expect 26):
// db.banLog.find({ Timestamp: ISODate("2026-05-17T23:30:00.000Z"), Message: /FP-43631 follow-up/ }).count();
