// FP-43631 week-7 ban log backfill — 17 rating-drop abusers (12 NEW + 5 REPEAT) banned via bans-2026-06-21.sql
// =============================================================================
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation), same as
// prior cycles. Run EACH section against its own platform Mongo (collection: banLog).
//
// REPEAT users get a 4-week ban (recidivism) and a slightly different reason string;
// NEW users get the standard 2-week ban.
//
// 4 of the 21 trial-confirmed BAN verdicts (Kacumi, poink, A-J-Rimmer-BSC, nowa_zajawka) were
// already Support-actioned before our sweep -- they are NOT included here; their existing
// Support bans run past our 2W standard.
//
// >>> Set TS to the actual UTC time you ran the Profile ban (bans-2026-06-21.sql COMMIT). <<<
var TS         = ISODate("2026-06-21T23:00:00.000Z");   // <-- adjust to real ban time
var MSG_NEW    = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-7)' until 2026-07-06 00:00:00";
var MSG_REPEAT = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-7, recidivism)' until 2026-07-20 00:00:00";

// ---- [F2P] STEAM PROD Mongo (7: 5 NEW + 2 REPEAT) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "1030bc70-976f-4ae8-8464-5e73a4f5382d", Message: MSG_NEW,    RequestId: null }, // TF_B4ngwal           (NEW)
//  { Timestamp: TS, UserId: "6218ffde-5eac-4566-bba5-711422d44f57", Message: MSG_NEW,    RequestId: null }, // Ramboo051            (NEW)
//  { Timestamp: TS, UserId: "3043cb8f-281b-47df-bec7-5ca722fa0394", Message: MSG_NEW,    RequestId: null }, // Audrey_HH            (NEW)
//  { Timestamp: TS, UserId: "45bb43b9-8690-43ae-aa4d-190515f4f2ec", Message: MSG_NEW,    RequestId: null }, // OZBULLDOG            (NEW)
//  { Timestamp: TS, UserId: "d2e0ba0e-3ac5-42ec-a645-f8c66137f310", Message: MSG_NEW,    RequestId: null }, // VovaTemniy           (NEW)
//  { Timestamp: TS, UserId: "09daa0c8-856a-4328-8001-9cc1b2683fab", Message: MSG_REPEAT, RequestId: null }, // FurryCurrentMaster   (REPEAT, our own week-4 ban expired 2026-06-15)
//  { Timestamp: TS, UserId: "37fe52ec-f9d1-4439-9ddd-2c38982c66c3", Message: MSG_REPEAT, RequestId: null }  // Dokidepp             (REPEAT)
//]);
// Verify (expect 7): db.banLog.find({ Timestamp: TS, Message: /week-7/ }).count();

// ---- [F2P] PS PROD Mongo (8: 6 NEW + 2 REPEAT) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "c5d90e33-5022-4049-9960-c39a28b0d2a4", Message: MSG_NEW,    RequestId: null }, // jorja09              (NEW)
//  { Timestamp: TS, UserId: "b879ab80-43e5-455f-a045-b5a28480af04", Message: MSG_NEW,    RequestId: null }, // rabolio41100         (NEW, watchlist escalator week-6)
//  { Timestamp: TS, UserId: "e812002d-0618-48eb-abae-d88078a4c9f8", Message: MSG_NEW,    RequestId: null }, // maminapokorny83      (NEW, watchlist escalator week-5)
//  { Timestamp: TS, UserId: "4277fb92-d6e9-4ca5-9940-ea77cb5dfa6c", Message: MSG_NEW,    RequestId: null }, // Neterrall            (NEW)
//  { Timestamp: TS, UserId: "f6816fd8-9a24-424a-aa90-04b1fd4565e8", Message: MSG_NEW,    RequestId: null }, // Fat_tuna_mama        (NEW)
//  { Timestamp: TS, UserId: "cc4044a9-0829-40e6-a6ba-d3222dbce8d0", Message: MSG_NEW,    RequestId: null }, // strullendorfer       (NEW)
//  { Timestamp: TS, UserId: "76b5f7f3-346a-46b1-9c70-4fe0743572c3", Message: MSG_REPEAT, RequestId: null }, // Flo-GrayFOX          (REPEAT)
//  { Timestamp: TS, UserId: "5db0a328-1307-4762-a1db-7ff34e63bfe5", Message: MSG_REPEAT, RequestId: null }  // bostonbroncos24      (REPEAT)
//]);
// Verify (expect 8): db.banLog.find({ Timestamp: TS, Message: /week-7/ }).count();

// ---- [F2P] XB PROD Mongo (2: 1 NEW + 1 REPEAT) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "1abb20a3-8696-4737-a0c4-5620a8a374df", Message: MSG_NEW,    RequestId: null }, // LEBOOGIEEEE          (NEW, Win10, 48 no-shows)
//  { Timestamp: TS, UserId: "013368d1-e8a8-437a-88b0-71059e3287eb", Message: MSG_REPEAT, RequestId: null }  // BuzzingLemur417      (REPEAT)
//]);
// Verify (expect 2): db.banLog.find({ Timestamp: TS, Message: /week-7/ }).count();
