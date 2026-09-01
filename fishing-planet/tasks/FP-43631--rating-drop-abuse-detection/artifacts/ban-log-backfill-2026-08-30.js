// FP-43631 week-17 ban log backfill -- 16 reviewed rating-drop abusers (15 NEW + 1 REPEAT)
// =============================================================================
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation).
// Run EACH section against its own platform Mongo (collection: banLog).
//
// SHIPPED WITH ALL THREE insertMany BLOCKS ACTIVE, as the standing rule requires. Select a section
// together with the var TS / MSG_* lines above it and run that selection; comment the block out in
// your own copy after it has run, so an accidental re-run is harmless. Last cycle this file went
// out pre-commented because it had been built by copying the previous cycle's artifact, which sits
// in post-run state -- that inverted the protection and cost the operator manual uncommenting.
//
// Four of the sixteen already carry Support bans running at least as long as ours -- Saintmnk,
// loseloop (Steam), DJTigar, Akkord_8 (PS). Their Profiles are deliberately NOT changed by
// bans-2026-08-30.sql; these banLog rows record our independent finding only (LaccFarro
// precedent, week-10).
var TS         = ISODate("2026-08-30T23:00:00.000Z");
var MSG_NEW    = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-17)' until 2026-09-28 00:00:00";
var MSG_REPEAT = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-17, recidivism)' until 2026-10-26 00:00:00";

// ---- [F2P] STEAM PROD Mongo (7: 6 NEW + 1 REPEAT) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "890eef14-daca-451e-ae0d-ee7454d996fd", Message: MSG_NEW,    RequestId: null }, // ASOAWELS         (8 prizes all taken at PCR <= 100 while reaching 137)
//  { Timestamp: TS, UserId: "11aaa18e-d387-4431-b195-60130ceeb90b", Message: MSG_NEW,    RequestId: null }, // MrAl3xXx         (20 no-shows at 67%)
//  { Timestamp: TS, UserId: "4b47ae81-1b95-4bb2-9b21-77186189665a", Message: MSG_NEW,    RequestId: null }, // RubyMarlinSultan (5 prizes at PCR <= 100)
//  { Timestamp: TS, UserId: "250a6ab6-af79-454f-881b-7af2655a970e", Message: MSG_NEW,    RequestId: null }, // loseloop         (Profile NOT changed -- Support ban to 2026-09-29; 927 -> 0, 83 no-shows at 93%)
//  { Timestamp: TS, UserId: "a6255ad3-8198-49a9-a27f-b3643b0d994a", Message: MSG_NEW,    RequestId: null }, // Saintmnk         (Profile NOT changed -- Support ban to 2026-09-28; counterfactual ceiling 528)
//  { Timestamp: TS, UserId: "f19ab1bb-4482-459d-9d4b-b8bb753ffffe", Message: MSG_NEW,    RequestId: null }, // SoRA6r           (counterfactual ceiling 445 against 12 NOOBS prizes)
//  { Timestamp: TS, UserId: "9757fd6a-8435-409a-9f83-33214af80424", Message: MSG_REPEAT, RequestId: null }  // TrcikLowFiv      (REPEAT, our ban lapsed 2026-06-12; rating 1006 recorded in-window)
//]);
// Verify (expect 7): db.banLog.find({ Timestamp: TS, Message: /week-17/ }).count();

// ---- [F2P] PS PROD Mongo (7 NEW) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "afbb0707-23c7-4601-abfd-e8093490813b", Message: MSG_NEW, RequestId: null }, // DJTigar        (Profile NOT changed -- Support ban to 2026-09-30; 8 prizes all at PCR <= 100)
//  { Timestamp: TS, UserId: "275768bf-834b-44e4-9297-11b946c070e0", Message: MSG_NEW, RequestId: null }, // Akkord_8       (Profile NOT changed -- Support ban to 2026-09-30; 21 zero-score of 40 starts)
//  { Timestamp: TS, UserId: "9c7cea54-909b-41f9-994b-05dccb86c144", Message: MSG_NEW, RequestId: null }, // blue102180     (19 prizes across three weeks, largest haul in the cohort)
//  { Timestamp: TS, UserId: "2a9e0031-cd4a-41b7-a791-20e395c43abb", Message: MSG_NEW, RequestId: null }, // bigbruney24    (prizes at PCR-before 92, 84, 61, 55 and 0)
//  { Timestamp: TS, UserId: "783f7778-52a1-4d72-b569-26665cd72714", Message: MSG_NEW, RequestId: null }, // lolofifa29     (4 prizes all at PCR <= 100)
//  { Timestamp: TS, UserId: "1d95d7d9-d983-4f8a-b8f2-2e2bb3aaa247", Message: MSG_NEW, RequestId: null }, // martelli04     (cumulative charge under rule 8; week-14 WATCH returning)
//  { Timestamp: TS, UserId: "ebc824ac-464e-4186-b896-a937a0599d6c", Message: MSG_NEW, RequestId: null }  // HIflyfishingGH (week-12 WATCH returning; counterfactual ceiling 414)
//]);
// Verify (expect 7): db.banLog.find({ Timestamp: TS, Message: /week-17/ }).count();

// ---- [F2P] XB PROD Mongo (2 NEW) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "13090ffe-7894-4c66-9af2-0cd81c1a03eb", Message: MSG_NEW, RequestId: null }, // ChaChaWuu9588  (5 of 8 prizes at PCR <= 100 while reaching 134)
  { Timestamp: TS, UserId: "2f692613-2090-4d4c-8e52-736a6bef5c2c", Message: MSG_NEW, RequestId: null }  // ScionHades8639 (entered the window at 122, now 0, 69 no-shows at 78%)
]);
// Verify (expect 2): db.banLog.find({ Timestamp: TS, Message: /week-17/ }).count();
