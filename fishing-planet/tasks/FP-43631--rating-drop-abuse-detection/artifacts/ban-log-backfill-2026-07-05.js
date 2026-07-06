// FP-43631 week-9 ban log backfill -- 6 rating-drop abusers (6 NEW + 0 REPEAT) banned via bans-2026-07-05.sql
// =============================================================================
// Format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation), same as
// prior cycles. Run EACH section against its own platform Mongo (collection: banLog).
//
// No REPEAT this cycle -- MSG_REPEAT omitted.
//
// 2 of the trial-confirmed BAN verdicts (ArTeM209, Gustyn112) were already Support-actioned
// before our sweep -- they are NOT included here; their existing Support bans run past our
// 2W standard (BanEnd 2026-08-04 and 2026-08-05 respectively).
//
// Xbox cohort was empty this week -- Xbox section omitted.
//
// >>> Set TS to the actual UTC time you ran the Profile ban (bans-2026-07-05.sql COMMIT). <<<
var TS      = ISODate("2026-07-05T22:40:00.000Z");   // <-- adjust to real ban time
var MSG_NEW = "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-9)' until 2026-07-20 00:00:00";

// ---- [F2P] STEAM PROD Mongo (3 NEW) ----
//db.banLog.insertMany([
//  { Timestamp: TS, UserId: "e0a2f28a-f5be-4a5c-9898-43f2c093dbb1", Message: MSG_NEW, RequestId: null }, // Ti_To       (NEW, PCR 668->38 = -630)
//  { Timestamp: TS, UserId: "e98d05d2-4e6f-45bc-8421-9ed08cdce54e", Message: MSG_NEW, RequestId: null }, // H.a.r.y44   (NEW, veteran flavor change, 10 MIDDLES->NOOBS drops)
//  { Timestamp: TS, UserId: "53e1b654-48bd-413c-ae77-6e58c39cfc14", Message: MSG_NEW, RequestId: null }  // IaMiya      (NEW)
//]);
// Verify (expect 3): db.banLog.find({ Timestamp: TS, Message: /week-9/ }).count();

// ---- [F2P] PS PROD Mongo (3 NEW) ----
db.banLog.insertMany([
  { Timestamp: TS, UserId: "5c5b4305-bc67-403e-a013-640e396f1a9f", Message: MSG_NEW, RequestId: null }, // EL-_-Diablo-_-51  (NEW, Kacumi refinement fires -- net-pos + climb-then-flush)
  { Timestamp: TS, UserId: "eea41d0d-3987-403f-a479-f2f8efe326d7", Message: MSG_NEW, RequestId: null }, // San-miculsan      (NEW)
  { Timestamp: TS, UserId: "e28dd543-32ff-449f-8a0f-02af1c615d38", Message: MSG_NEW, RequestId: null }  // kevynrdm13        (NEW)
]);
// Verify (expect 3): db.banLog.find({ Timestamp: TS, Message: /week-9/ }).count();
