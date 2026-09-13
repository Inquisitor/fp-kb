// FP-43631 week-18 -- Tournament-log trajectory dump query (SINGLE, run on all 3 Mongo PROD)
// =============================================================================
// One aggregate, run against each Mongo PROD instance separately. UserIds are globally unique
// (FP GUIDs) -- each platform's Mongo returns only its own candidates.
//
// Window: 2026-08-24T00:00:00Z -> 2026-09-06T23:59:59Z (fourteen days).
//
// WHY FOURTEEN AND NOT MORE. `tournamentLog` retains exactly fourteen days (measured week-17), so
// this window is the entire ledger, not a choice. Asking for more returns silently truncated data.
// The sweep week is 08-31..09-06; the preceding week is pre-context and happens to be the week-17
// sweep week, which is what the two returning candidates are read against. If the dump is run a day
// later, the 08-24 end of the window will have aged out -- re-check the earliest timestamp returned.
//
// 17 candidates: Steam DB 9, PS DB 5, Xbox DB 3.
//
// SUPPORT-BLIND. The annotations below carry OUR ban history and OUR prior watchlist entries only.
// Three candidates carry an active or lapsed competition ban that is NOT ours (LuizFernandoo,
// trumcautrom, ST-9257) and are annotated NEW accordingly; the SQL `Verdict` column reads REPEAT on
// them because it keys off the raw flag and cannot tell whose ban it is. The cross-check against
// Support happens at the operator step, after the review, so the verdicts stay an independent test.
//
// Output rows: "<UserId>\t<ISO timestamp>\t<verbatim Message>", sorted UserId ASC then Timestamp
// ASC. Save per-platform output into `pcr-log-trajectories-2026-09-06/`:
//   steam-dump-2026-09-06.tsv  (9 candidates expected)
//   ps-dump-2026-09-06.tsv     (5 candidates expected)
//   xb-dump-2026-09-06.tsv     (3 candidates expected)

db.tournamentLog.aggregate([
  { $match: {
      UserId: { $in: [
        // ---- STEAM DB (9) ----
        "267a4a3d-0a1d-456c-b766-6fc1891f0c26", // seagate22022
        "f3150296-cc7f-43b0-90a5-cc941b45e960", // HavocHHH
        "d3e8334c-49b0-4e75-a759-bdcc95738444", // Novan07
        "e7b743e8-fbf0-4c6c-8a27-cc333c199baf", // Ilija1982
        "13ec8b47-ba33-4510-9cf7-9c365e0bd267", // LuizFernandoo      (carries a lapsed competition ban from 2026-08-31, not ours -- NEW)
        "b8ca6b12-3057-4bbe-9980-53f655fcf065", // Myky0576           (**OUR week-2 ban lapsed 2026-06-17 -> REPEAT**; Epic account. 27 zero-score finishes against 1 no-show -- the drain runs almost entirely through zero-score)
        "a7d0b667-2796-462e-9763-2b2acaf4e2b9", // codeco
        "dae6c504-81a4-4f34-bcaf-9c94008bf4ca", // trumcautrom        (carries a lapsed competition ban from 2026-07-26, not ours -- NEW)
        "5d6f2740-5780-4936-bd4d-cc542e244cf2", // BENJUN_DFT

        // ---- PS DB (5) ----
        "51873b16-7a58-4fc6-b234-7f3617c0ce91", // Leelos90           (**our week-17 WATCH returning**; the one week-17 re-hearing that did not flip to BAN)
        "09bdc8bf-b133-493e-9ebe-e5c145cb0fde", // ST-9257            (carries a lapsed competition ban from 2026-07-16, not ours -- NEW. Upper-bracket profile: plays 22 MIDDLES / 19 TOPS, cashes 4 MIDDLES / 1 TOPS)
        "3c8d3bbd-dca4-4412-98ab-98f7c8fab1f5", // jujiito
        "469df796-d270-40ff-bad9-8a5b9d83b6dc", // CFC-T-W-T-32568    (**OUR week-11 ban lapsed 2026-08-03 -> REPEAT**; also our week-17 watchlist entry, returning a second time)
        "1cdb373f-5a08-4d3a-ab4a-83dab1f00685", // anatoly2026

        // ---- XBOX DB (3) ----
        "92517835-3c2f-449d-ae3e-1ecebe9e656a", // I JEEPERS I
        "4e051eae-c2a0-4473-ad49-67e48aaf0775", // KovlekPlayz
        "1c653428-2c77-4f8e-8194-422aa3d63c8f"  // o Lord Mac o
      ] },
      Timestamp: { $gte: ISODate("2026-08-24T00:00:00.000Z"), $lte: ISODate("2026-09-06T23:59:59.000Z") },
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
