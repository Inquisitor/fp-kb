// FP-43631 week-5 ban log backfill — 8 rating-drop abusers (6 NEW + 2 REPEAT) banned via bans-2026-06-07.sql
// =============================================================================
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation), same as
// the 2026-05-31 backfill. Run EACH section against its own platform Mongo (collection: banLog).
//
// REPEAT users get a 4-week ban (recidivism) and a slightly different reason string;
// NEW users get the standard 2-week ban.
//
// Adversarial-review note: a 9th candidate Lay_D14S (PS) was downgraded to WATCH; no PS section
// this cycle. The two-platform layout (Steam + Xbox) reflects that.
//
// >>> Set TS to the actual UTC time you ran the Profile ban (bans-2026-06-07.sql COMMIT). <<<
var TS         = ISODate("2026-06-07T23:00:00.000Z");   // <-- adjust to real ban time
var MSG_NEW    = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up — rating-drop abuse (week-5)' until 2026-06-22 00:00:00";
var MSG_REPEAT = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up — rating-drop abuse (week-5, recidivism)' until 2026-07-06 00:00:00";

// ---- [F2P] STEAM PROD Mongo (5: 3 NEW + 2 REPEAT) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "8fd87705-6500-4717-b459-387b07d7b471", Message: MSG_NEW,    RequestId: null }, // JuliaRybalka      (NEW, escalator)
//  { Timestamp: TS, UserId: "4545581f-c2db-4fa4-986e-9aee3f9ccb48", Message: MSG_NEW,    RequestId: null }, // Kaneki_Ken2907    (NEW, escalator)
//  { Timestamp: TS, UserId: "0386a8aa-954f-44cf-b371-6c5bab96943f", Message: MSG_NEW,    RequestId: null }, // emer_85_he        (NEW)
//  { Timestamp: TS, UserId: "5c99be5a-a7fb-49b1-aafb-188e26693ca7", Message: MSG_REPEAT, RequestId: null }, // I_MACTEP_I        (REPEAT, 30-hour tank campaign)
//  { Timestamp: TS, UserId: "4d3efd74-6b2b-4e65-b434-a63d08bc6f68", Message: MSG_REPEAT, RequestId: null }  // TTC-SWAX          (REPEAT, ban expired today)
//]);
// Verify (expect 5): db.banLog.find({ Timestamp: TS, Message: /week-5/ }).count();

// ---- [F2P] XB PROD Mongo (3 NEW) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "e81a2739-534a-4299-80e7-7bf54b573be8", Message: MSG_NEW, RequestId: null }, // nggaaah           (NEW, Win10/Xbox)
//  { Timestamp: TS, UserId: "ae6a4bc7-2dbf-4662-b5c3-7a8296a0f387", Message: MSG_NEW, RequestId: null }, // Bejk76 cz         (NEW)
//  { Timestamp: TS, UserId: "82da4897-61ab-4b56-bd82-4c654b54b7da", Message: MSG_NEW, RequestId: null }  // Bizkit3209        (NEW)
//]);
// Verify (expect 3): db.banLog.find({ Timestamp: TS, Message: /week-5/ }).count();
