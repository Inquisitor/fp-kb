// FP-43631 week-11 ban log backfill -- 5 rating-drop abusers (4 NEW + 1 REPEAT) banned via bans-2026-07-19.sql
// =============================================================================
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation), same as
// prior cycles. Run EACH section against its own platform Mongo (collection: banLog).
//
// 4 of the trial-confirmed BAN verdicts (yevhen331 BanEnd 2026-08-18, sen1a 2026-08-17,
// evgeniy3311 2026-08-02, Ricky27sampei 2026-08-02) were already Support-actioned before our
// sweep -- they are NOT included here. Plus one Support-pre-actioned Trial-Support dissent
// (LZ23J7KS, TOP-flavor MASTERS sandbagger family -- Rule 7 direction 2 non-target, 2ND
// dissent on rating-drop, alignment 32/34) is not included either.
//
// >>> Set TS to the actual UTC time you ran the Profile ban (bans-2026-07-19.sql COMMIT). <<<
var TS         = ISODate("2026-07-19T22:20:00.000Z");   // <-- adjust to real ban time
var MSG_NEW    = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-11)' until 2026-08-03 00:00:00";
var MSG_REPEAT = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-11, recidivism)' until 2026-08-17 00:00:00";

// ---- [F2P] STEAM PROD Mongo (1 NEW) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "313eee9d-da0c-42f0-9b1e-e4d0c2598766", Message: MSG_NEW, RequestId: null }  // FoxMilard  (NEW, heavy grinder LB Rank 27 with NOOBS flavor-change, 4 climb-and-cash cycles)
]);
// Verify (expect 1): db.banLog.find({ Timestamp: TS, Message: /week-11/ }).count();

// ---- [F2P] PS PROD Mongo (3: 2 NEW + 1 REPEAT) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "469df796-d270-40ff-bad9-8a5b9d83b6dc", Message: MSG_NEW,    RequestId: null }, // CFC-T-W-T-32568  (NEW, textbook farmer LB Rank 8, PCR 4, 6N pure)
  { Timestamp: TS, UserId: "ce09da31-c3fc-4b21-915a-87eba15367d9", Message: MSG_NEW,    RequestId: null }, // Chuydakid214     (NEW, 4 climb-then-flush cycles, 2 M->N crossings)
  { Timestamp: TS, UserId: "cc4044a9-0829-40e6-a6ba-d3222dbce8d0", Message: MSG_REPEAT, RequestId: null }  // strullendorfer   (REPEAT, our week-7 BAN expired 2026-07-06, immediate recidivism 13d later)
]);
// Verify (expect 3): db.banLog.find({ Timestamp: TS, Message: /week-11/ }).count();

// ---- [F2P] XB PROD Mongo (1 NEW) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "fb67d3bc-e77d-4579-856a-f2df8dc3caa5", Message: MSG_NEW, RequestId: null }  // Belion019  (NEW, 4 Kacumi cycles, 6 batched flushes, 67% no-show; cheat vector orthogonal)
]);
// Verify (expect 1): db.banLog.find({ Timestamp: TS, Message: /week-11/ }).count();
