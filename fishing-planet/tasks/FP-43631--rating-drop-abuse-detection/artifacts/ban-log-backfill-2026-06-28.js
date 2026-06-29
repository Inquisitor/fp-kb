// FP-43631 week-8 ban log backfill — 15 rating-drop abusers (14 NEW + 1 REPEAT) banned via bans-2026-06-28.sql
// =============================================================================
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation), same as
// prior cycles. Run EACH section against its own platform Mongo (collection: banLog).
//
// REPEAT users get a 4-week ban (recidivism) and a slightly different reason string;
// NEW users get the standard 2-week ban.
//
// 2 of the trial-confirmed BAN verdicts (Adlerblut-Slayer, TR-dennisfb) were already
// Support-actioned before our sweep -- they are NOT included here; their existing Support bans
// run past our 2W standard (BanEnd 2026-07-28 and 2026-07-23 respectively).
//
// >>> Set TS to the actual UTC time you ran the Profile ban (bans-2026-06-28.sql COMMIT). <<<
var TS         = ISODate("2026-06-28T23:00:00.000Z");   // <-- adjust to real ban time
var MSG_NEW    = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-8)' until 2026-07-13 00:00:00";
var MSG_REPEAT = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-8, recidivism)' until 2026-07-27 00:00:00";

// ---- [F2P] STEAM PROD Mongo (5 NEW) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "c434afc9-875d-4ece-8efa-fe7810c6daff", Message: MSG_NEW, RequestId: null }, // ArmlessFisherMan   (NEW)
//  { Timestamp: TS, UserId: "883362ef-98a6-4406-b2dc-9636e1d022fc", Message: MSG_NEW, RequestId: null }, // BB_Anastasia       (NEW)
//  { Timestamp: TS, UserId: "222bbe9d-3557-4280-b854-cbef2ae48707", Message: MSG_NEW, RequestId: null }, // MonsterFish_fuark  (NEW, watchlist escalator week-6)
//  { Timestamp: TS, UserId: "4cf530ba-2330-4dc0-bb8b-c03a55176efc", Message: MSG_NEW, RequestId: null }, // angeperdu          (NEW, was week-5 borderline WATCH)
//  { Timestamp: TS, UserId: "683d0d32-290e-4726-bfe9-ad16a0234324", Message: MSG_NEW, RequestId: null }  // krolikusik         (NEW)
//]);
// Verify (expect 5): db.banLog.find({ Timestamp: TS, Message: /week-8/ }).count();

// ---- [F2P] PS PROD Mongo (9: 8 NEW + 1 REPEAT) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "c5a87a36-e9a3-44c6-b69a-cb08adbeaeda", Message: MSG_NEW,    RequestId: null }, // Matiamo_PL         (NEW, watchlist escalator week-7)
//  { Timestamp: TS, UserId: "46e9e18f-0e49-4f9e-b91c-b074823cf02b", Message: MSG_NEW,    RequestId: null }, // tigrou_le_boss42   (NEW)
//  { Timestamp: TS, UserId: "56ed8774-68b1-49b2-b395-e594dbe4b766", Message: MSG_NEW,    RequestId: null }, // M4R5H_57_          (NEW, 79% no-show)
//  { Timestamp: TS, UserId: "cbf68606-df2c-46b3-8086-e76b7019c1d1", Message: MSG_NEW,    RequestId: null }, // Epic70cosmin       (NEW, 72% no-show)
//  { Timestamp: TS, UserId: "d1320268-0463-4289-a455-24bab60b2363", Message: MSG_NEW,    RequestId: null }, // MrChadRico         (NEW)
//  { Timestamp: TS, UserId: "ee558d4f-7515-4b5f-b0fd-4c1f47319c3a", Message: MSG_NEW,    RequestId: null }, // MONSTER-VERT1325   (NEW)
//  { Timestamp: TS, UserId: "330f8b15-1fc5-49dc-9829-8b710b04f80f", Message: MSG_NEW,    RequestId: null }, // TR-BILECIKLI_CMR   (NEW)
//  { Timestamp: TS, UserId: "882bb61a-9f03-4706-b58e-aa9a279e303b", Message: MSG_NEW,    RequestId: null }, // kokoljj            (NEW)
//  { Timestamp: TS, UserId: "06bb9d34-bc04-4591-80f6-0f8ad8f05087", Message: MSG_REPEAT, RequestId: null }  // IKIGAI__1__        (REPEAT, prior ban expired 2026-06-17)
//]);
// Verify (expect 9): db.banLog.find({ Timestamp: TS, Message: /week-8/ }).count();

// ---- [F2P] XB PROD Mongo (1 NEW) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "f25a97b7-fdef-4c1c-b50a-0d0a117745d4", Message: MSG_NEW, RequestId: null }  // Smooter85          (NEW, 135.8h no-show streak longest of cohort)
]);
// Verify (expect 1): db.banLog.find({ Timestamp: TS, Message: /week-8/ }).count();
