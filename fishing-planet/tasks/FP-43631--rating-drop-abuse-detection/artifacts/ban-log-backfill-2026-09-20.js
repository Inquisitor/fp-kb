// FP-43631 week-20 ban log backfill -- 5 rating-drop abusers (5 NEW)
// =============================================================================
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation).
// Run EACH section against its own platform Mongo (collection: banLog).
//
// SHIPPED WITH ALL THREE insertMany BLOCKS ACTIVE, as the standing rule requires. Select a section
// together with the var TS / MSG_NEW lines above it and run that selection; comment the block out in
// your own copy after it has run, so an accidental re-run is harmless. This file was composed from
// the methodology section, not by copying the previous cycle's artifact -- that one is left in
// post-run state with sections commented out, and copying it is what inverted the protection in
// week-14.
//
// No REPEAT tariff this cycle: all 5 are NEW by our own ban history, so there is only one message
// constant.
//
// 2 of the 5 are OPERATOR OVERRIDES of WATCH verdicts -- CrazyGepard and HavocHHH. The banLog line
// carries the standard reason string regardless: banLog and AdminComment describe the offence and
// the duration, not how the decision was reached. The ground for both overrides is recorded in the
// header of bans-2026-09-20.sql and in the cycle record, and both require a blind re-hearing.
// TS is the actual moment the layer-1 profile bans were committed on all three PROD MAIN
// databases, not a rounded placeholder -- banLog is the audit trail and a made-up hour makes it
// useless for correlating with anything else.
var TS      = ISODate("2026-09-20T23:59:15.000Z");
var MSG_NEW = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-20)' until 2026-10-19 00:00:00";

// ---- [F2P] STEAM PROD Mongo (2 NEW) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "dcb21f48-6b54-4f74-8a3f-9caae8bff6a0", Message: MSG_NEW, RequestId: null }, // LEK_TARNO (trial BAN conf 8; board place 1 with 7 wins, 6 in-window boundary drops, 9 of 12 prizes in NOOBS against a MIDDLES ceiling)
  { Timestamp: TS, UserId: "f3150296-cc7f-43b0-90a5-cc941b45e960", Message: MSG_NEW, RequestId: null }  // HavocHHH  (operator override of WATCH; peaks at 988 against a TOPS floor of 1001 and flushes there in the same second, all 7 prizes in MIDDLES, counterfactual ceiling 1264)
]);
// Verify (expect 2): db.banLog.find({ Timestamp: TS, Message: /week-20/ }).count();

// ---- [F2P] PS PROD Mongo (2 NEW) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "80b05c6c-7719-40b5-89ca-3a358f0bd166", Message: MSG_NEW, RequestId: null }, // Gentleman83190 (trial BAN conf 9; 26 unproductive of 35 at 74%, net -149, 3 in-window boundary drops, 5 of 6 prizes in NOOBS)
  { Timestamp: TS, UserId: "a92ed0c7-bb5e-43ac-971c-7af91fd47d31", Message: MSG_NEW, RequestId: null }  // CrazyGepard    (operator override of WATCH; parks at exactly 100 -- the top of NOOBS -- and sheds 5 no-shows at 2-hour intervals, twice in the window, all 8 prizes in NOOBS, counterfactual ceiling 375)
]);
// Verify (expect 2): db.banLog.find({ Timestamp: TS, Message: /week-20/ }).count();

// ---- [F2P] XB PROD Mongo (1 NEW) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "16dda5f1-e9c3-46f5-a43f-bfb806de1f8f", Message: MSG_NEW, RequestId: null }  // Rapidstrapon (trial BAN conf 8; 42 unproductive of 53 at 79%, net -175, 2 in-window boundary drops, 7 of 8 prizes in NOOBS)
]);
// Verify (expect 1): db.banLog.find({ Timestamp: TS, Message: /week-20/ }).count();
