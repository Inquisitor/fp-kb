// FP-43631 week-20 ban log backfill -- SECOND PACK, 2 rating-drop abusers (2 NEW)
// =============================================================================
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation).
// Run EACH section against its own platform Mongo (collection: banLog).
//
// SHIPPED WITH BOTH insertMany BLOCKS ACTIVE, as the standing rule requires. Select a section
// together with the var TS / MSG_NEW lines above it and run that selection; comment the block out
// in your own copy after it has run, so an accidental re-run is harmless. Composed from the
// methodology section, not by copying the previous artifact.
//
// These two were decided after the payout, by reading the trajectory directly rather than by
// tribunal. Both NEW by our own history, so one message constant.
//
// TS should be the moment the layer-1 profile bans actually commit. The value below is the time
// this file was written; if the bans go in materially later, set it to the real commit moment --
// banLog is the audit trail and a wrong hour makes it useless for correlating with anything else.
var TS      = ISODate("2026-09-21T14:06:53.000Z");
var MSG_NEW = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-20)' until 2026-10-19 00:00:00";

// ---- [F2P] STEAM PROD Mongo (1 NEW) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "6b94e751-0d2f-40b0-81ea-fb7c9da0fd14", Message: MSG_NEW, RequestId: null }  // Iron.Claw (no schedule to explain the absences at all; 4 entries above rating 100 in 14 days with 0 prizes and an average of 20th, against 20 entries and 5 prizes below it; registered 3 slots at rating 105 three minutes after the reward that took him across, attended none; 0 unregistrations in 48 participations)
//]);
// Verify (expect 1): db.banLog.find({ Timestamp: TS, Message: /week-20/ }).count();

// ---- [F2P] PS PROD Mongo (1 NEW) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "54ea8084-5546-4ea8-8068-4c1fdbe77d4a", Message: MSG_NEW, RequestId: null }  // Bas_di08 (holds a 951..1050 band astride the 1001 line for the whole fortnight: 6 excursions above, 6 no-show returns, net -11; 23 no-shows of 48 events almost all at the maximum -20; all 4 prizes taken in MIDDLES against a counterfactual ceiling inside TOPS)
]);
// Verify (expect 1): db.banLog.find({ Timestamp: TS, Message: /week-20/ }).count();
