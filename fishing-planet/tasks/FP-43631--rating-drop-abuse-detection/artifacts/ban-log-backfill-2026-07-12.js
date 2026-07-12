// FP-43631 week-10 ban log backfill -- 4 rating-drop abusers (2 NEW + 2 REPEAT) banned via bans-2026-07-12.sql
// =============================================================================
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation), same as
// prior cycles. Run EACH section against its own platform Mongo (collection: banLog).
//
// 5 of the trial-confirmed BAN verdicts (JFF_Gothyka, CreekSamurai, MLG720YOLO, Da Sneaky Snake,
// CraddiePoosta) were already Support-actioned before our sweep -- they are NOT included here.
// Plus sandaljepitt is a Support-pre-actioned case where Support banned on cheat-trigger vector
// (not rating-drop) and trial gave WATCH on rating-drop grounds -- orthogonal-vector case, not
// re-banned.
//
// >>> Set TS to the actual UTC time you ran the Profile ban (bans-2026-07-12.sql COMMIT). <<<
var TS         = ISODate("2026-07-12T22:20:00.000Z");   // <-- adjust to real ban time
var MSG_NEW    = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-10)' until 2026-07-27 00:00:00";
var MSG_REPEAT = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-10, recidivism)' until 2026-08-10 00:00:00";

// ---- [F2P] STEAM PROD Mongo (2: 1 NEW + 1 REPEAT) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "17999a3e-1bab-479a-b4de-374eb48ff867", Message: MSG_NEW,    RequestId: null }, // Captain_Djack_Sparrow  (NEW, mixed 5N+1M, 3 MIDDLES->NOOBS drops)
//  { Timestamp: TS, UserId: "47fee9fa-c9e6-4dbe-8742-63b56558d890", Message: MSG_REPEAT, RequestId: null }  // LaccFarro              (REPEAT, our week-6 BAN expired 2026-06-29, immediate recidivism)
//]);
// Verify (expect 2): db.banLog.find({ Timestamp: TS, Message: /week-10/ }).count();

// ---- [F2P] PS PROD Mongo (1 REPEAT) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "1f0b293c-2a06-45cc-bbc5-9b0d0715728f", Message: MSG_REPEAT, RequestId: null }  // Miron_33  (REPEAT, sink-comp repeat targeting, 5 MIDDLES->NOOBS drops)
//]);
// Verify (expect 1): db.banLog.find({ Timestamp: TS, Message: /week-10/ }).count();

// ---- [F2P] XB PROD Mongo (1 NEW) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "6572e942-f8a7-4f7b-915e-007f21d6e81c", Message: MSG_NEW, RequestId: null }  // alphaBiTsoop16  (NEW, 79% no-show extreme, PCR 54 -> 0)
]);
// Verify (expect 1): db.banLog.find({ Timestamp: TS, Message: /week-10/ }).count();
