// FP-43631 week-4 ban log backfill — 5 rating-drop abusers banned via bans-2026-05-31.sql
// =============================================================================
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation), same as
// the 2026-05-24 backfill. Run EACH section against its own platform Mongo (collection: banLog).
//
// >>> Set TS to the actual UTC time you ran the Profile ban (bans-2026-05-31.sql COMMIT). <<<
var TS  = ISODate("2026-05-31T21:56:39.000Z");   // <-- adjust to real ban time
var MSG = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up — rating-drop abuse (week-4)' until 2026-06-15 00:00:00";

// ---- [F2P] STEAM PROD Mongo ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "09daa0c8-856a-4328-8001-9cc1b2683fab", Message: MSG, RequestId: null }, // FurryCurrentMaster
//  { Timestamp: TS, UserId: "ce0b47de-48fe-4494-9ae7-10c3defa456f", Message: MSG, RequestId: null }, // SplendidTroutAngler
//  { Timestamp: TS, UserId: "9dd3e9df-0ed5-4810-9142-79e6d099710e", Message: MSG, RequestId: null }  // HeitorJR2
//]);
// Verify (expect 3): db.banLog.find({ Timestamp: TS, Message: /week-4/ }).count();

// ---- [F2P] PS PROD Mongo ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "07bdb641-fca0-47e1-94bc-61a1d6f92599", Message: MSG, RequestId: null }, // vybuschna_plina
  { Timestamp: TS, UserId: "84f0d212-9f87-4851-9cee-86e2a6dfcb8b", Message: MSG, RequestId: null }  // sentinel_krk
]);
// Verify (expect 2): db.banLog.find({ Timestamp: TS, Message: /week-4/ }).count();

// (no Xbox section this cycle — week-4 sweep returned zero Xbox abusers)
