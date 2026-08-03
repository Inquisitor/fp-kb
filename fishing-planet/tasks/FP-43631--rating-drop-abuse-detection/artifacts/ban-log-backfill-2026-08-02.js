// FP-43631 week-13 ban log backfill -- 7 rating-drop abusers (5 NEW + 2 REPEAT) banned via bans-2026-08-02.sql
// =============================================================================
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation), same as prior
// cycles. Run EACH section against its own platform Mongo (collection: banLog).
//
// Durations changed this cycle: 4 weeks first offence, 8 weeks recidivism (was 2W/4W).
//
// Seven further review-confirmed BAN verdicts were already Support-actioned before the sweep
// (LuizFernandoo, BarbosUa, MORPH3US, ELPEZGORDO12, aperno, La_Iena_River_, ZacKasoN) and are
// NOT included here.
//
// >>> Set TS to the actual UTC time you ran the Profile ban (bans-2026-08-02.sql COMMIT). <<<
var TS         = ISODate("2026-08-02T21:30:00.000Z");   // <-- adjust to real ban time
var MSG_NEW    = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-13)' until 2026-08-31 00:00:00";
var MSG_REPEAT = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-13, recidivism)' until 2026-09-28 00:00:00";

// ---- [F2P] STEAM PROD Mongo (3: 2 NEW + 1 REPEAT) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "5ed0507e-3d58-4fa7-b5c5-a3df361b791f", Message: MSG_NEW,    RequestId: null }, // FarantirPL  (NEW, returned after two absent cycles following a week-9 WATCH)
//  { Timestamp: TS, UserId: "da1e5723-6f95-4600-98cd-f3e680e5163e", Message: MSG_NEW,    RequestId: null }, // wallims     (NEW, within-bracket detector, LB Rank 2 at PCR 25)
//  { Timestamp: TS, UserId: "132e8be9-7515-4898-b4d6-acf7fade37c7", Message: MSG_REPEAT, RequestId: null }  // Aorney      (REPEAT, ban lapsed 2026-07-01, flavor changed to NOOBS)
//]);
// Verify (expect 3): db.banLog.find({ Timestamp: TS, Message: /week-13/ }).count();

// ---- [F2P] PS PROD Mongo (3: 2 NEW + 1 REPEAT) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "30f95ada-24fa-4fa1-8671-48f73d804156", Message: MSG_NEW,    RequestId: null }, // BOOMDATRUTH2     (NEW, week-12 WATCH returning, prizes 4N -> 8N)
//  { Timestamp: TS, UserId: "17c96f92-269f-4811-af1e-813afc75e144", Message: MSG_NEW,    RequestId: null }, // Old-Black-Fisher (NEW, 5N pure, 19 NS 70%)
//  { Timestamp: TS, UserId: "882bb61a-9f03-4706-b58e-aa9a279e303b", Message: MSG_REPEAT, RequestId: null }  // kokoljj          (REPEAT, our week-8 ban lapsed 2026-07-13, sink-comp repeat)
//]);
// Verify (expect 3): db.banLog.find({ Timestamp: TS, Message: /week-13/ }).count();

// ---- [F2P] XB PROD Mongo (1 NEW) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "6de2b7ad-6ea2-4f67-ab64-2c4cd4cbcdca", Message: MSG_NEW, RequestId: null }  // Mjolnir8761  (NEW, 12 prizes -- largest haul in cohort)
]);
// Verify (expect 1): db.banLog.find({ Timestamp: TS, Message: /week-13/ }).count();
