// FP-43631 week-19 ban log backfill -- 7 reviewed rating-drop abusers (7 NEW)
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
// No REPEAT tariff this cycle: all 7 are NEW by our own ban history, so there is only one message
// constant.
//
// ZellyRolled is an OPERATOR OVERRIDE of a WATCH verdict, not a trial conviction. The reason is
// recorded in the header of bans-2026-09-13.sql and in the cycle record; the banLog line carries the
// standard reason string because AdminComment and banLog describe the offence and the duration, not
// how the decision was reached.
var TS      = ISODate("2026-09-14T00:00:00.000Z");
var MSG_NEW = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-19)' until 2026-10-12 00:00:00";

// ---- [F2P] STEAM PROD Mongo (3 NEW) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "952eed36-e6a1-40dd-acd6-7bc8831500cb", Message: MSG_NEW, RequestId: null }, // Pilou62 (reached 1211 in the ledger and sits at 848; 32 unproductive of 59, -511 against +414 earned)
//  { Timestamp: TS, UserId: "0ef1a14c-25bc-4f84-b6be-85ee73c8739f", Message: MSG_NEW, RequestId: null }, // Mr.Twin (plays across 2 brackets, all 4 prizes taken in the lower one)
//  { Timestamp: TS, UserId: "d9d89e71-18d8-44e4-83b5-daf07045fe14", Message: MSG_NEW, RequestId: null }  // Suna4Y  (60% unproductive, -407, ends the window at rating 0)
//]);
// Verify (expect 3): db.banLog.find({ Timestamp: TS, Message: /week-19/ }).count();

// ---- [F2P] PS PROD Mongo (2 NEW) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "2018b861-7ebf-4d9e-aef8-3656c6a21c22", Message: MSG_NEW, RequestId: null }, // AdmiralAckbar98 (62% unproductive, net -71, cashes below where he plays)
//  { Timestamp: TS, UserId: "cf9967a8-175f-42ac-a364-c9c658532b58", Message: MSG_NEW, RequestId: null }  // sidelong-beak10 (17 zero-score finishes across the ledger; entirely inside the bottom bracket)
//]);
// Verify (expect 2): db.banLog.find({ Timestamp: TS, Message: /week-19/ }).count();

// ---- [F2P] XB PROD Mongo (2 NEW) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "4e051eae-c2a0-4473-ad49-67e48aaf0775", Message: MSG_NEW, RequestId: null }, // KovlekPlayz (week-18 WATCH returning; prizes 5 -> 9, unproductive 8 -> 21, registrations 13 -> 32)
  { Timestamp: TS, UserId: "87223c5f-5082-496f-88d4-507d31b540f5", Message: MSG_NEW, RequestId: null }  // ZellyRolled (3rd on the closing weekly board; 5 of his 6 upward crossings of 100 shed back before the next contested event)
]);
// Verify (expect 2): db.banLog.find({ Timestamp: TS, Message: /week-19/ }).count();
