// FP-43631 week-19 -- Tournament-log trajectory dump query (SINGLE, run on all 3 Mongo PROD)
// =============================================================================
// One aggregate, run against each Mongo PROD instance separately. UserIds are globally unique
// (FP GUIDs) -- each platform's Mongo returns only its own candidates.
//
// Window: 2026-08-31T00:00:00Z -> 2026-09-13T23:59:59Z (fourteen days = the whole retention of the
// collection, not a choice). The sweep week is 09-07..09-13; the preceding week is pre-context.
//
// 12 candidates: Steam DB 6, PS 3, Xbox 3.
//
// CRITICAL PATH: ZellyRolled (Xbox) is 3rd of 2347 on the closing weekly board by wins and is the
// only candidate who can collect a top-10 reward at the 00:20Z payout. Every other candidate sits
// outside the money and cannot reach it: the paying cutoff is 3 wins on all three platforms, and no
// one else has more than 2 with at most 1 competition still running. He is ordered first in the
// trial for that reason; the rest carry no deadline.
//
// SUPPORT-BLIND. The annotations carry OUR ban history and OUR prior watchlist entries only.
//
// Output rows: "<UserId>\t<ISO timestamp>\t<verbatim Message>", sorted UserId ASC then Timestamp
// ASC. Save per-platform output into `pcr-log-trajectories-2026-09-13/`:
//   steam-dump-2026-09-13.tsv  (6 candidates expected)
//   ps-dump-2026-09-13.tsv     (3 candidates expected)
//   xb-dump-2026-09-13.tsv     (3 candidates expected)

db.tournamentLog.aggregate([
  { $match: {
      UserId: { $in: [
        // ---- STEAM DB (6) ----
        "952eed36-e6a1-40dd-acd6-7bc8831500cb", // Pilou62            (lapsed competition ban from 2026-06-01, not ours. Upper-bracket: plays 28 MIDDLES, cashes 5 there, sits at 848 under a 977 in-window maximum)
        "d9d89e71-18d8-44e4-83b5-daf07045fe14", // Suna4Y             (29 unproductive of 48 at 60%, -407, ends the window at 0, all 5 prizes in the bottom bracket)
        "10a0fff3-e631-413b-b5fa-30208635f2a6", // FOGGIA1920         (lapsed competition ban from 2026-06-01, not ours)
        "297d97a2-2446-4c13-bf9b-3cf6745086ee", // YOUTUBE-Eduzera-YT (entirely inside MIDDLES: plays 0/10/0, cashes 0/4/0)
        "0ef1a14c-25bc-4f84-b6be-85ee73c8739f", // Mr.Twin            (plays 10 NOOBS / 9 MIDDLES, cashes 4/0/0)
        "a9266367-f0bd-45d7-bdd5-14a21f152862", // AppL33             (plays 6 NOOBS / 18 MIDDLES; 1 of his 4 prizes has no rating recorded at start, so the N/M/T split shows only 3)

        // ---- PS DB (3) ----
        "18514e38-b869-48ba-b39b-b77b3a741b43", // Bog_Zim            (8 prizes, none of them a win; entirely inside MIDDLES, lifetime record 44/36/62)
        "2018b861-7ebf-4d9e-aef8-3656c6a21c22", // AdmiralAckbar98    (23 unproductive of 37 at 62%, plays 7 NOOBS / 7 MIDDLES, cashes 3/1/0)
        "cf9967a8-175f-42ac-a364-c9c658532b58", // sidelong-beak10    (74% unproductive of which 7 are zero-score; plays 15/0/0, cashes 4/0/0, never above 79)

        // ---- XBOX DB (3) ----
        "87223c5f-5082-496f-88d4-507d31b540f5", // ZellyRolled        (**CRITICAL PATH** -- 3rd of 2347 by wins in the closing period. 19 unproductive of 28 at 68%, net +69 rising, plays 8 NOOBS / 1 MIDDLES, cashes 7/1/0)
        "4e051eae-c2a0-4473-ad49-67e48aaf0775", // KovlekPlayz        (**OUR week-18 WATCH returning** -- prizes 5 -> 9, unproductive 8 -> 21, registrations 13 -> 32. Rules 4 and 8 are engaged)
        "1e51550f-db71-4ebc-82d5-06b89693d93a"  // Lesky2123          (7 unproductive of 14, net +102 rising)
      ] },
      Timestamp: { $gte: ISODate("2026-08-31T00:00:00.000Z"), $lte: ISODate("2026-09-13T23:59:59.000Z") },
      Message: { $regex: "^(Tournament reward Competition|Player started scoring time for Competition|Player registered for Competition|Player unregistered from Competition|Registration for tournament Competition|FAILED: Register in competition|About to process tournament Competition|CHEAT:)" }
  } },
  { $sort: { UserId: 1, Timestamp: 1 } },
  { $project: {
      _id: 0,
      line: { $concat: [
        "$UserId", "\t",
        { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }, "\t",
        "$Message"
      ] }
  } }
]);
