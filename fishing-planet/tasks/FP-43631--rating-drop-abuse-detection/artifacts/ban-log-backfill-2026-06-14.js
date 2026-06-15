// FP-43631 week-6 ban log backfill — 4 rating-drop abusers (2 NEW + 2 REPEAT) banned via bans-2026-06-14.sql
// =============================================================================
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation), same as
// prior cycles. Run EACH section against its own platform Mongo (collection: banLog).
//
// REPEAT users get a 4-week ban (recidivism) and a slightly different reason string;
// NEW users get the standard 2-week ban.
//
// Adversarial-review note: cohort started at 15 candidates; trial cleared 4 for BAN and 11 for
// WATCH. No Xbox section this cycle (the one Xbox candidate MikeikeMOON was downgraded by the
// trial on no-MIDDLES-exposure and net-negative trajectory).
//
// >>> Set TS to the actual UTC time you ran the Profile ban (bans-2026-06-14.sql COMMIT). <<<
var TS         = ISODate("2026-06-14T23:40:00.000Z");   // <-- adjust to real ban time
var MSG_NEW    = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-6)' until 2026-06-29 00:00:00";
var MSG_REPEAT = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-6, recidivism)' until 2026-07-13 00:00:00";

// ---- [F2P] STEAM PROD Mongo (1 NEW) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "47fee9fa-c9e6-4dbe-8742-63b56558d890", Message: MSG_NEW, RequestId: null }  // LaccFarro       (NEW, TOP->NOOBS slide)
//]);
// Verify (expect 1): db.banLog.find({ Timestamp: TS, Message: /week-6/ }).count();

// ---- [F2P] PS PROD Mongo (3: 1 NEW + 2 REPEAT) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "78c4a65f-ef45-482a-a125-88d71973013b", Message: MSG_NEW,    RequestId: null }, // Mr-crimson-21   (NEW)
  { Timestamp: TS, UserId: "e25c082e-8a19-4236-aa8b-c345137e9ea3", Message: MSG_REPEAT, RequestId: null }, // STARI40K_YT     (REPEAT, prior ban expired 06-01)
  { Timestamp: TS, UserId: "8f36f30f-ade0-4d9a-bc88-765ae61e5384", Message: MSG_REPEAT, RequestId: null }  // IIGot-_-Smoked  (REPEAT, our own week-3 ban expired 06-08)
]);
// Verify (expect 3): db.banLog.find({ Timestamp: TS, Message: /week-6/ }).count();
