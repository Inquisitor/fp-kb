// FP-43631 week-18 ban log backfill -- 9 reviewed rating-drop abusers (7 NEW + 2 REPEAT)
// =============================================================================
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation).
// Run EACH section against its own platform Mongo (collection: banLog).
//
// SHIPPED WITH ALL THREE insertMany BLOCKS ACTIVE, as the standing rule requires. Select a section
// together with the var TS / MSG_* lines above it and run that selection; comment the block out in
// your own copy after it has run, so an accidental re-run is harmless. This file was composed from
// the methodology section, not by copying the previous cycle's artifact -- that artifact is left in
// post-run state with sections commented out, and copying it is what inverted the protection in
// week-14.
//
// The nine were convicted in three passes this cycle and the reason matters for the record:
//   * 4 at the first hearing (Leelos90, ST-9257, I JEEPERS I, CFC-T-W-T-32568);
//   * 2 by operator override ahead of the reward run under the week-12 leaderboard criterion
//     (seagate22022 at weekly rank 2, o Lord Mac o at rank 3), both later confirmed independently
//     by the re-hearing at confidence 8 and 9;
//   * 3 by the re-hearing on a corrected brief (Ilija1982, codeco, Myky0576).
// The first hearing returned only 4 of 17 because the brief omitted the standing week-12 finding
// that a same-second ledger group is a flush moment rather than proof of presence; prosecutors built
// their sequence cases on that artifact and judges struck them down. The correction is a briefing
// rule, not a rule-1 change.
//
// Leelos90's Profile was NOT changed by bans-2026-09-06.sql -- he carries a Support ban to
// 2026-10-03 imposed mid-window on 2026-09-03, and the WHERE clause skips anyone already effectively
// banned. His row here records our independent finding only (LaccFarro precedent, week-10). Note our
// tariff would have run two days longer; the convention is still not to touch another team's ban.
//
// Myky0576 sits on the Steam database but is an Epic account.
var TS         = ISODate("2026-09-07T00:00:00.000Z");
var MSG_NEW    = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-18)' until 2026-10-05 00:00:00";
var MSG_REPEAT = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-18, recidivism)' until 2026-11-02 00:00:00";

// ---- [F2P] STEAM PROD Mongo (4: 3 NEW + 1 REPEAT) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "267a4a3d-0a1d-456c-b766-6fc1891f0c26", Message: MSG_NEW,    RequestId: null }, // seagate22022 (weekly rank 2 of 2969; 10 of 11 prizes at rating <= 100; counterfactual ceiling 416 against actual 77)
//  { Timestamp: TS, UserId: "e7b743e8-fbf0-4c6c-8a27-cc333c199baf", Message: MSG_NEW,    RequestId: null }, // Ilija1982    (5 of 5 prizes in the bottom bracket, never above PCR 95, 61% unproductive)
//  { Timestamp: TS, UserId: "a7d0b667-2796-462e-9763-2b2acaf4e2b9", Message: MSG_NEW,    RequestId: null }, // codeco       (plays MIDDLES, cashes NOOBS; 60% unproductive, -212 from them)
//  { Timestamp: TS, UserId: "b8ca6b12-3057-4bbe-9980-53f655fcf065", Message: MSG_REPEAT, RequestId: null }  // Myky0576     (REPEAT, our week-2 ban lapsed 2026-06-17; Epic account; 27 zero-score finishes against 1 no-show)
//]);
// Verify (expect 4): db.banLog.find({ Timestamp: TS, Message: /week-18/ }).count();

// ---- [F2P] PS PROD Mongo (3: 2 NEW + 1 REPEAT) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "51873b16-7a58-4fc6-b234-7f3617c0ce91", Message: MSG_NEW,    RequestId: null }, // Leelos90        (Profile NOT changed -- Support ban to 2026-10-03; week-17 WATCH returning, 74% unproductive, ends the window at 0)
//  { Timestamp: TS, UserId: "09bdc8bf-b133-493e-9ebe-e5c145cb0fde", Message: MSG_NEW,    RequestId: null }, // ST-9257         (990 actual against a 1164 counterfactual ceiling; cashes a bracket below his own play)
//  { Timestamp: TS, UserId: "469df796-d270-40ff-bad9-8a5b9d83b6dc", Message: MSG_REPEAT, RequestId: null }  // CFC-T-W-T-32568 (REPEAT, our week-11 ban lapsed 2026-08-03; also week-17 watchlist, so a second return)
//]);
// Verify (expect 3): db.banLog.find({ Timestamp: TS, Message: /week-18/ }).count();

// ---- [F2P] XB PROD Mongo (2 NEW) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "1c653428-2c77-4f8e-8194-422aa3d63c8f", Message: MSG_NEW, RequestId: null }, // o Lord Mac o (weekly rank 3 of 2334; all 4 prizes in the bottom bracket; largest drain in the cohort at -374)
  { Timestamp: TS, UserId: "92517835-3c2f-449d-ae3e-1ecebe9e656a", Message: MSG_NEW, RequestId: null }  // I JEEPERS I  (plays MIDDLES, cashes NOOBS; 57% unproductive, net -85)
]);
// Verify (expect 2): db.banLog.find({ Timestamp: TS, Message: /week-18/ }).count();
