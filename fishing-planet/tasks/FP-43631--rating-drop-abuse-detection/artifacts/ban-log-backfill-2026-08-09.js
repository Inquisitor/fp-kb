// FP-43631 week-14 ban log backfill -- 10 rating-drop abusers (all NEW) banned via bans-2026-08-09.sql
// =============================================================================
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation), same as prior
// cycles. Run EACH section against its own platform Mongo (collection: banLog).
//
// Durations unchanged: 4 weeks first offence, 8 weeks recidivism. No REPEAT this cycle.
//
// RGC_ReeL_SKiiLLz is included here even though the SQL WHERE clause skips his Profile row -- he
// already carries a Support ban to 2026-09-09, which runs longer than ours, and shortening it
// would be a regression. The banLog entry records our independent finding (LaccFarro precedent,
// week-10). His Profile is intentionally left as Support set it.
//
// >>> Set TS to the actual UTC time you ran the Profile ban (bans-2026-08-09.sql COMMIT). <<<
var TS      = ISODate("2026-08-10T00:30:00.000Z");   // <-- adjust to real ban time
var MSG_NEW = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-14)' until 2026-09-07 00:00:00";

// ---- [F2P] STEAM PROD Mongo (4 NEW) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "82c921b5-1383-437d-9afa-9d711a344481", Message: MSG_NEW, RequestId: null }, // Dr.Seven       (8 prizes all NOOBS, five descend-and-cash cycles in eight days)
//  { Timestamp: TS, UserId: "9584b60d-67d5-4362-8021-f1065562a5bc", Message: MSG_NEW, RequestId: null }, // lailailaiyu    (all up-crossings played, 6 of 7 down-crossings no-shows)
//  { Timestamp: TS, UserId: "b4b0c273-5b5c-4a0c-bddf-e204ee7f6b1a", Message: MSG_NEW, RequestId: null }, // ShadowOfOxigen (6 prizes 5N+1M, 27 NS 66%)
//  { Timestamp: TS, UserId: "4422cd0f-153b-477b-a4f5-60353c37b5ea", Message: MSG_NEW, RequestId: null }  // Martino_CZ     (upper-bracket harvest, first ban under the rewritten rule 1)
//]);
// Verify (expect 4): db.banLog.find({ Timestamp: TS, Message: /week-14/ }).count();

// ---- [F2P] PS PROD Mongo (5 NEW) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "c51f5f26-2816-4ff9-88f3-530af5e7e875", Message: MSG_NEW, RequestId: null }, // RGC_ReeL_SKiiLLz (Profile NOT changed -- Support ban to 2026-09-09 runs longer; record of intent)
//  { Timestamp: TS, UserId: "92264697-3829-4c7a-93f3-861f4533c3ba", Message: MSG_NEW, RequestId: null }, // Angel_of_Dunkirk (9 prizes all NOOBS, 18 NS 60%)
//  { Timestamp: TS, UserId: "bfaf6154-7a56-4025-a4a8-4ffe8d6b74b1", Message: MSG_NEW, RequestId: null }, // switch-toad      (7 prizes all NOOBS, 23 NS 52%)
//  { Timestamp: TS, UserId: "ab70490a-bffb-4e18-9297-b3479bac4369", Message: MSG_NEW, RequestId: null }, // Seu_Kuka_Beludo  (7 prizes 5N+2M, 18 NS 35%)
//  { Timestamp: TS, UserId: "67e551f8-a305-4bbd-9c1e-8f96ebdd24b1", Message: MSG_NEW, RequestId: null }  // HalfSand_        (4 prizes all NOOBS, 9 NS 47%)
//]);
// Verify (expect 5): db.banLog.find({ Timestamp: TS, Message: /week-14/ }).count();

// ---- [F2P] XB PROD Mongo (1 NEW) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "646efd1d-3a4b-4d62-b8cf-d3bc767ac646", Message: MSG_NEW, RequestId: null }  // Pilou625057 (Win10 on the Xbox DB; week-13 WATCH returning)
]);
// Verify (expect 1): db.banLog.find({ Timestamp: TS, Message: /week-14/ }).count();
