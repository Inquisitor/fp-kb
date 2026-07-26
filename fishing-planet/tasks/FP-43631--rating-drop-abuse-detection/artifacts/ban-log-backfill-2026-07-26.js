// FP-43631 week-12 ban log backfill -- 6 rating-drop abusers (5 NEW + 1 REPEAT) banned via bans-2026-07-26.sql
// =============================================================================
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation), same as
// prior cycles. Run EACH section against its own platform Mongo (collection: banLog).
//
// 3 of the review-confirmed BAN verdicts (KondaFlk BanEnd 2026-08-08, VGB_N4rkos060905
// 2026-08-07, rascof molotov 2026-08-25) were already Support-actioned before our sweep --
// they are NOT included here.
//
// >>> Set TS to the actual UTC time you ran the Profile ban (bans-2026-07-26.sql COMMIT). <<<
var TS         = ISODate("2026-07-26T23:00:00.000Z");   // <-- adjust to real ban time
var MSG_NEW    = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-12)' until 2026-08-10 00:00:00";
var MSG_REPEAT = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-12, recidivism)' until 2026-08-24 00:00:00";

// ---- [F2P] STEAM PROD Mongo (4: 3 NEW + 1 REPEAT) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "99247bde-f4cb-4698-8a5c-679550d9f369", Message: MSG_NEW,    RequestId: null }, // dreadloc  (NEW, operator override -- LB Won Place 6 at LifePCR 46, 7N pure)
  { Timestamp: TS, UserId: "cb167d53-bd55-4228-8b44-f41a284e7c3e", Message: MSG_NEW,    RequestId: null }, // Albbert   (NEW, 7N pure, rule 5 defeats net-positive PCR)
  { Timestamp: TS, UserId: "b3440760-bbd6-4af0-b0ee-def6b131de62", Message: MSG_NEW,    RequestId: null }, // Zemaro    (NEW, W11 WATCH returning, rule 8 persistence)
  { Timestamp: TS, UserId: "eb4273ee-eb6a-488f-8ac7-6c40809e1229", Message: MSG_REPEAT, RequestId: null }  // jackylu   (REPEAT, prior ban lapsed 2026-07-10, back within 16 days)
]);
// Verify (expect 4): db.banLog.find({ Timestamp: TS, Message: /week-12/ }).count();

// ---- [F2P] PS PROD Mongo (1 NEW) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "35ed0e4a-4acb-4072-b23a-10d5b5578fea", Message: MSG_NEW, RequestId: null }  // vlad_spain  (NEW, W11 WATCH returning, NOOBS prizes 5 -> 11, largest escalation in cohort)
]);
// Verify (expect 1): db.banLog.find({ Timestamp: TS, Message: /week-12/ }).count();

// ---- [F2P] XB PROD Mongo (1 NEW) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "ff382a4e-f0c7-4dc4-a882-80f32276e095", Message: MSG_NEW, RequestId: null }  // TurboBandz6351  (NEW, W11 WATCH returning, rule 9 > rule 6, ZeroScore 5 -> 9)
]);
// Verify (expect 1): db.banLog.find({ Timestamp: TS, Message: /week-12/ }).count();
