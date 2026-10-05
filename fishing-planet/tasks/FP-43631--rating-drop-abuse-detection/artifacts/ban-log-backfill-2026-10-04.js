// FP-43631 week-22 ban log backfill -- 13 rating-drop abusers (10 NEW, 3 REPEAT), one pack
// =============================================================================
// ONE script, ONE expression. Run it whole, unchanged, on each platform Mongo ([F2P] STEAM / PS / XB
// PROD Mongo, database main2). Nothing to select, nothing to comment out, safe to run twice.
//
// How it works:
//   1. Platform detection -- an account belongs to this Mongo if `diagIpLog` holds any line for its
//      UserId. That collection has the longest retention of the per-user logs (180 days, see
//      `MongoAsyncProvider.DeleteOldMessages`; most logs keep 14) and is indexed on UserId. Each
//      account is found on exactly one platform.
//   2. Idempotency -- the audit line is inserted only if the identical line (UserId + Timestamp +
//      Message) is not already there. A re-run reports "already present" and inserts nothing.
//   3. Verification -- the script returns how many lines it inserted, how many were already there,
//      how many accounts are not on this platform, and the cycle's line count in banLog against the
//      number of accounts detected here (OK / MISMATCH), plus one line per account.
//
// The message format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation).
// banLog and AdminComment describe the offence and the duration, not how the decision was reached.
//
// The timestamp is the operator's COMMIT moment of bans-2026-10-04.sql -- banLog is the audit trail.
// One pack, one moment for all three platforms: 2026-10-04 23:35Z.
//
// Expected result per platform (the operator checks the three sums add up to the cohort):
//   STEAM  inserted 5, not on this platform 8   -> verify 5 of 5 OK
//   PS     inserted 6, not on this platform 7   -> verify 6 of 6 OK
//   XB     inserted 2, not on this platform 11  -> verify 2 of 2 OK
//
// Between cycles only CYCLE, MSG, the T* timestamps and ROWS change.
(function () {
  var CYCLE = "week-22";
  var MSG = {
    NEW:    "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-22)' until 2026-11-05 00:00:00",
    REPEAT: "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-22, recidivism)' until 2026-12-05 00:00:00"
  };
  var T1 = ISODate("2026-10-04T23:35:00.000Z");
  // The platform comments are for the reader; the script does not use them -- diagIpLog decides.
  // Expected per platform: STEAM 5 (1 REPEAT + 4 NEW) / PS 6 (1 REPEAT + 5 NEW) / XB 2 (1 REPEAT + 1 NEW) = 13.
  var ROWS = [
    // ---- STEAM (5) ----
    { uid: "60d42746-1430-4d54-a479-29583b87b0a5", name: "Mariusz1029",    verdict: "REPEAT", ts: T1 }, // Steam
    { uid: "76dc3e6b-4bea-47ed-83a4-d0649d605ff9", name: "JoeCoviDodo",    verdict: "NEW",    ts: T1 }, // Steam
    { uid: "17d9446a-6115-42b0-a48d-14914922f593", name: "Tho1324",        verdict: "NEW",    ts: T1 }, // Steam
    { uid: "8e2f69a6-b63b-46e6-a0b8-cdfb5741dd50", name: "mr.GreeM",       verdict: "NEW",    ts: T1 }, // Steam
    { uid: "daa00f0b-2ba8-49a5-8be2-9880d6c856e3", name: "MP_Alan",        verdict: "NEW",    ts: T1 }, // Steam
    // ---- PS (6) ----
    { uid: "2c393625-f229-4284-8db2-962bebde0774", name: "marzak66",       verdict: "NEW",    ts: T1 }, // PS
    { uid: "bb7842cc-e2f4-491a-a6a1-0083d202bcf7", name: "keeno1",         verdict: "NEW",    ts: T1 }, // PS
    { uid: "e3a99cf5-48d9-423f-998b-d714cc1668f6", name: "thebig35994",    verdict: "NEW",    ts: T1 }, // PS
    { uid: "496e32d7-cd9f-4f8f-96df-f9171fce1e93", name: "zezinho_curuja", verdict: "NEW",    ts: T1 }, // PS
    { uid: "d442b23b-4502-4427-8e08-ca35871ddc4d", name: "popeye-43",      verdict: "NEW",    ts: T1 }, // PS
    { uid: "c896536d-28fa-4785-a85e-48c27b947590", name: "Panonski_Alas",  verdict: "REPEAT", ts: T1 }, // PS
    // ---- XB (2) ----
    { uid: "13090ffe-7894-4c66-9af2-0cd81c1a03eb", name: "ChaChaWuu9588",  verdict: "REPEAT", ts: T1 }, // Xbox
    { uid: "623a4d04-bc0d-486b-aff5-fea169cbd915", name: "ArticSquid71",   verdict: "NEW",    ts: T1 }  // Xbox
  ];

  var lines = [], inserted = 0, present = 0, foreign = 0, expected = 0;
  ROWS.forEach(function (r) {
    var here = db.diagIpLog.find({ UserId: r.uid }).limit(1).count(true) > 0;
    if (!here) { foreign++; return; }
    expected++;
    var doc = { Timestamp: r.ts, UserId: r.uid, Message: MSG[r.verdict], RequestId: null };
    if (db.banLog.find({ UserId: r.uid, Timestamp: r.ts, Message: doc.Message }).limit(1).count(true) > 0) {
      present++; lines.push("present  " + r.name + " (" + r.verdict + ")"); return;
    }
    db.banLog.insertMany([doc]);
    inserted++; lines.push("inserted " + r.name + " (" + r.verdict + ")");
  });

  var actual = db.banLog.find({
    UserId: { $in: ROWS.map(function (r) { return r.uid; }) },
    Message: { $regex: "\\(" + CYCLE + "(, recidivism)?\\)" }
  }).count();

  return CYCLE + ": inserted " + inserted + ", already present " + present + ", not on this platform " + foreign +
         "\nverify: banLog holds " + actual + " " + CYCLE + " line(s) for " + expected + " account(s) detected here -> " +
         (actual === expected ? "OK" : "MISMATCH") + "\n" + lines.join("\n");
})()
