// FP-43631 week-3 ban log backfill — 4 rating-drop abusers banned via bans-2026-05-25.sql
// (the applied ban reason/message below keeps its original "tank-and-farm" wording — it's already in prod)
// =============================================================================
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation), same as
// the 2026-05-17 backfill. Run EACH section against its own platform Mongo (collection: banLog).
//
// >>> Set TS to the actual UTC time you ran the Profile ban (bans-2026-05-25.sql COMMIT). <<<

var TS  = ISODate("2026-05-24T23:30:00.000Z");   // <-- adjust to real ban time
var MSG = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up — no-show abuse (week-3 tank-and-farm)' until 2026-06-08 00:00:00";

// ---- [F2P] STEAM PROD Mongo ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "5e3f0096-55ed-4715-ba43-4a7f377507a4", Message: MSG, RequestId: null }  // Holekko
//]);
// Verify (expect 1): db.banLog.find({ Timestamp: TS, Message: /week-3 tank-and-farm/ }).count();

// ---- [F2P] PS PROD Mongo ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "8f36f30f-ade0-4d9a-bc88-765ae61e5384", Message: MSG, RequestId: null }  // IIGot-_-Smoked
//]);
// Verify (expect 1): db.banLog.find({ Timestamp: TS, Message: /week-3 tank-and-farm/ }).count();

// ---- [F2P] XB PROD Mongo ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "5cec46b5-e4ca-43bd-9bd1-3bb493460a4e", Message: MSG, RequestId: null }, // VITAO4460
  { Timestamp: TS, UserId: "4bf7e769-1526-47a4-9795-5a7b3fdf1d3c", Message: MSG, RequestId: null }  // profpaulo18
]);
// Verify (expect 2): db.banLog.find({ Timestamp: TS, Message: /week-3 tank-and-farm/ }).count();
