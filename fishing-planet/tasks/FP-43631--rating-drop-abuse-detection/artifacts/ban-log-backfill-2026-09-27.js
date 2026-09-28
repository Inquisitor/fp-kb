// FP-43631 week-21 ban log backfill -- 13 rating-drop abusers (10 NEW, 3 REPEAT), three packs
// =============================================================================
// ONE script, ONE expression. Run it whole, unchanged, on each platform Mongo ([F2P] STEAM / PS / XB
// PROD Mongo, database main2). Nothing to select, nothing to comment out, safe to run twice.
//
// How it works (new form from week-21, at the operator's request):
//   1. Platform detection -- an account belongs to this Mongo if `diagIpLog` holds any line for its
//      UserId. That collection has the longest retention of the per-user logs (180 days, see
//      `MongoAsyncProvider.DeleteOldMessages`; most logs keep 14) and is indexed on UserId. Tested
//      on this cycle's 13: each found on exactly one platform, none on the other two.
//   2. Idempotency -- the audit line is inserted only if the identical line (UserId + Timestamp +
//      Message) is not already there. A re-run reports "already present" and inserts nothing.
//   3. Verification -- the script returns how many lines it inserted, how many were already there,
//      how many accounts are not on this platform, and the cycle's line count in banLog against the
//      number of accounts detected here (OK / MISMATCH), plus one line per account.
//
// The message format matches IBanLogExtensions.LogBan output (BanSource.WebAdmin imitation).
// banLog and AdminComment describe the offence and the duration, not how the decision was reached.
//
// Timestamps are the operator's actual COMMIT moments of the three packs, per account, not rounded
// placeholders -- banLog is the audit trail:
//   pack 1  bans-2026-09-27.sql         committed 2026-09-27 23:40Z (the deadline subset, before the payout)
//   pack 2  bans-2026-09-27-second.sql  committed 2026-09-28 00:40Z (the remainder)
//   pack 3  bans-2026-09-27-third.sql   committed 2026-09-28 01:15Z (the two the early screen missed)
//
// Expected result per platform (the operator checks the three sums add up to the cohort):
//   STEAM  inserted 4, not on this platform 9   -> verify 4 of 4 OK
//   PS     inserted 3, not on this platform 10  -> verify 3 of 3 OK
//   XB     inserted 6, not on this platform 7   -> verify 6 of 6 OK
//
// Between cycles only CYCLE, MSG, the T* timestamps and ROWS change.
(function () {
  var CYCLE = "week-21";
  var MSG = {
    NEW:    "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-21)' until 2026-10-26 00:00:00",
    REPEAT: "User banned with Competition ban via WebAdmin by Stanislav Samoilov with reason 'FP-43631 follow-up - rating-drop abuse (week-21, recidivism)' until 2026-11-23 00:00:00"
  };
  var T1 = ISODate("2026-09-27T23:40:00.000Z");
  var T2 = ISODate("2026-09-28T00:40:00.000Z");
  var T3 = ISODate("2026-09-28T01:15:00.000Z");
  // The platform comments are for the reader; the script does not use them -- diagIpLog decides.
  // Expected per platform: STEAM 4 (4 NEW) / PS 3 (1 REPEAT + 2 NEW) / XB 6 (2 REPEAT + 4 NEW) = 13.
  var ROWS = [
    // ---- STEAM (4) ----
    { uid: "23a99ba9-e0f0-46e0-b5fc-846e5dad0814", name: "Noob-KAKA1988",      verdict: "NEW",    ts: T1 }, // Steam, pack 1
    { uid: "3eda1a94-2da6-45b4-a837-465773f5291a", name: "DCUK420",            verdict: "NEW",    ts: T2 }, // Steam, pack 2 (was BurnsTroutFishery)
    { uid: "1dfd5192-3b71-437f-bb5e-b0a3cfd2c281", name: "AmazingQuestHero45", verdict: "NEW",    ts: T3 }, // Steam, pack 3
    { uid: "67831814-56c8-47ac-bbe2-882dc339072a", name: "kojldyn",            verdict: "NEW",    ts: T3 }, // Steam, pack 3
    // ---- PS (3) ----
    { uid: "67e551f8-a305-4bbd-9c1e-8f96ebdd24b1", name: "HalfSand_",          verdict: "REPEAT", ts: T1 }, // PS, pack 1
    { uid: "23ad555b-a45c-47ac-ab4a-a469d7ddbe5e", name: "ShrekUndies",        verdict: "NEW",    ts: T2 }, // PS, pack 2
    { uid: "ebb52e2f-e4ed-42a9-9711-e55facb1668c", name: "christdu7340",       verdict: "NEW",    ts: T2 }, // PS, pack 2
    // ---- XB (6) ----
    { uid: "e39c9dab-1697-434f-ade9-d0122265ed13", name: "TMRyuko",            verdict: "NEW",    ts: T1 }, // Xbox, pack 1
    { uid: "0521e9f5-dcf5-438c-908d-689f0dfd2242", name: "Fuzzytacos6571",     verdict: "REPEAT", ts: T1 }, // Xbox, pack 1
    { uid: "95d6f8ae-0562-455e-99e0-6679cc506389", name: "LaterGENJI",         verdict: "NEW",    ts: T1 }, // Xbox, pack 1
    { uid: "7ace60e8-8b33-401a-ae9f-b315dd848049", name: "ELTITOGRAVY6",       verdict: "NEW",    ts: T1 }, // Xbox, pack 1
    { uid: "c6440075-c23c-4b02-80ad-fe1f5ff9b25e", name: "UlfsonUlfstroem",    verdict: "REPEAT", ts: T2 }, // Xbox, pack 2
    { uid: "7e4889a6-8e26-4eb8-97b5-3c67ad6c423d", name: "BoraxHook",          verdict: "NEW",    ts: T2 }  // Xbox, pack 2
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
