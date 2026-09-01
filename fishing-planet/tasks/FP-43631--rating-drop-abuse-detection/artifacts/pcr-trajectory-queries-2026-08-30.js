// FP-43631 week-17 -- Tournament-log trajectory dump query (SINGLE, run on all 3 Mongo PROD)
// =============================================================================
// One aggregate, run against each Mongo PROD instance separately. UserIds are globally unique
// (FP GUIDs) -- each platform's Mongo returns only its own candidates.
//
// Window: 2026-08-10T00:00:00Z -> 2026-08-30T23:59:59Z (three weeks).
//
// WHY THREE WEEKS AND NOT THE USUAL ~1+2. Enforcement was paused by agreement with the CS lead
// for two Sundays, so this window IS the gap: 08-10..08-16, 08-17..08-23 and the sweep week
// 08-24..08-30. It also matches what the week-14 watchlist review established -- the slow variant
// of this abuse does not resolve inside seven days. Two candidates here (TrcikLowFiv, martelli04)
// pass the detection gate ONLY on the cumulative window and are invisible to the weekly sweep.
//
// 21 candidates: Steam DB 8, PS DB 11, Xbox DB 2.
//
// SUPPORT-BLIND. The annotations below carry OUR ban history and OUR prior watchlist entries
// only. Nothing here indicates who Support has already actioned; that cross-check happens at the
// operator step, after the review, so the verdicts stay an independent test.
//
// Output rows: "<UserId>\t<ISO timestamp>\t<verbatim Message>", sorted UserId ASC then Timestamp
// ASC. Save per-platform output into `pcr-log-trajectories-2026-08-30/`:
//   steam-dump-2026-08-30.tsv  (8 candidates expected)
//   ps-dump-2026-08-30.tsv     (11 candidates expected)
//   xb-dump-2026-08-30.tsv     (2 candidates expected)

db.tournamentLog.aggregate([
  { $match: {
      UserId: { $in: [
        // ---- STEAM DB (8) ----
        "890eef14-daca-451e-ae0d-ee7454d996fd", // ASOAWELS
        "a6255ad3-8198-49a9-a27f-b3643b0d994a", // Saintmnk
        "c7b81940-4368-4604-9fb8-b487fa03ae0f", // HEAVENFALL
        "11aaa18e-d387-4431-b195-60130ceeb90b", // MrAl3xXx           (carries a lapsed competition ban from 2026-07-22, not ours)
        "4b47ae81-1b95-4bb2-9b21-77186189665a", // RubyMarlinSultan
        "f19ab1bb-4482-459d-9d4b-b8bb753ffffe", // SoRA6r
        "250a6ab6-af79-454f-881b-7af2655a970e", // loseloop
        "9757fd6a-8435-409a-9f83-33214af80424", // TrcikLowFiv        (**OUR ban lapsed 2026-06-12 -> REPEAT**; week-14 WATCH; = StillWaterMind, one of the ground-truth accounts named at task inception. Passes the gate only cumulatively)

        // ---- PS DB (11) ----
        "afbb0707-23c7-4601-abfd-e8093490813b", // DJTigar
        "51873b16-7a58-4fc6-b234-7f3617c0ce91", // Leelos90
        "275768bf-834b-44e4-9297-11b946c070e0", // Akkord_8           (21 zero-score finishes out of 35 starts -- drain may be running through zero-score rather than absence)
        "9c7cea54-909b-41f9-994b-05dccb86c144", // blue102180
        "46e9e18f-0e49-4f9e-b91c-b074823cf02b", // tigrou_le_boss42   (carries a lapsed competition ban from 2026-07-13, not ours)
        "2a9e0031-cd4a-41b7-a791-20e395c43abb", // bigbruney24
        "783f7778-52a1-4d72-b569-26665cd72714", // lolofifa29
        "469df796-d270-40ff-bad9-8a5b9d83b6dc", // CFC-T-W-T-32568    (**OUR week-11 ban lapsed 2026-08-03 -> REPEAT**; returned inside three weeks)
        "ebc824ac-464e-4186-b896-a937a0599d6c", // HIflyfishingGH     (**our week-12 watchlist entry returning**)
        "a8ec6ba8-58e5-491a-a7a1-f5914d2ff332", // FM_AirForceZero    (11 zero-score out of 15 starts, only 8 no-shows -- same possible zero-score drain)
        "1d95d7d9-d983-4f8a-b8f2-2e2bb3aaa247", // martelli04         (**our week-14 WATCH returning**; held then on rule 3, which no longer applies -- 17 starts across this window. Passes the gate only cumulatively)

        // ---- XBOX DB (2) ----
        "13090ffe-7894-4c66-9af2-0cd81c1a03eb", // ChaChaWuu9588
        "2f692613-2090-4d4c-8e52-736a6bef5c2c"  // ScionHades8639
      ] },
      Timestamp: { $gte: ISODate("2026-08-10T00:00:00.000Z"), $lte: ISODate("2026-08-30T23:59:59.000Z") },
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
