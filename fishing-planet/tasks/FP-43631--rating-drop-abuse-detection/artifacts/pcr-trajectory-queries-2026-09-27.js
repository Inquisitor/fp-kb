// FP-43631 week-21 -- Tournament-log trajectory dump (SINGLE query, run on all 3 Mongo PROD)
// =============================================================================
// WHOLE COHORT, all 16 (BurnsTroutFishery has renamed since the screen; UserId from the operator). Extended from
// the deadline subset of 7 before the first run: one dump costs the same as two and the log's
// 14-day retention slides daily. Reading order stays the 7 in the money first.
//
// Payout time: the competitive rewards are enqueued by `CompetitiveLeaderboardFinalizationJob`,
// which runs at **:07 past the hour** -- so 00:07Z, not 00:00Z and not 00:20Z. (:20 is
// `CompetitiveLeaderboardCleanupJob`, which only drops the current-period rows.) A ban bites only
// if it is in `Profiles` AND propagated to `CompetitiveRatingsCurrent.IsBanned` before :07.
//
// Window: 2026-09-14T00:00:00Z -> 2026-09-27T23:59:59Z (fourteen days = the whole retention of the
// collection, not a choice). The sweep week is 09-21..09-27; the preceding week is pre-context.
//
// WHAT THIS IS FOR, week-21: the ledger itself now comes from SQL, which does not omit entries the
// way the log does (week-20: 85 participations of 961 missing, always ones that cost rating). The
// log is pulled for the two things SQL does not carry -- the REGISTRATION TIMESTAMP, which is what
// exposes batch registration, and the PCR chain across no-shows, where `CompetitionRatingAtStart`
// is null by construction. Do not derive status or presence from it.
//
// SUPPORT-BLIND. Annotations carry OUR ban history and OUR prior watchlist entries only.
//
// Output rows: "<UserId>\t<ISO timestamp>\t<verbatim Message>", sorted UserId ASC then Timestamp
// ASC. Save per-platform output into `pcr-log-trajectories-2026-09-27/`:
//   steam-dump-2026-09-27.tsv  (5 candidates expected; 2 of them surfaced only on the post-22:00Z screen re-run)
//   ps-dump-2026-09-27.tsv     (5 candidates expected)
//   xb-dump-2026-09-27.tsv     (8 candidates expected)

db.tournamentLog.aggregate([
  { $match: {
      UserId: { $in: [
        // ---- STEAM DB (1) ----
        "23a99ba9-e0f0-46e0-b5fc-846e5dad0814", // Noob-KAKA1988   (board seat 10, 3 wins, EXACTLY on the paying line. 39 unproductive of 58 at 67%, -530, net -177, plays 5 NOOBS / 17 MIDDLES, cashes 5/3/0, 8 prizes)

        "ce0b47de-48fe-4494-9ae7-10c3defa456f", // NotTheTheFace   (outside the money. REPEAT. 7 no-shows of 27 at 37%, -147, net +3, plays 0/20/0, cashes 0/4/0)
        "3eda1a94-2da6-45b4-a837-465773f5291a", // BurnsTroutFishery (renamed since the screen. outside the money. NEW. 17 no-shows of 22 at 77%, -200, net -71, plays 3/2/0, cashes 3/1/0)
        "1dfd5192-3b71-437f-bb5e-b0a3cfd2c281", // AmazingQuestHero45 (surfaced only on the post-22:00Z screen re-run. NEW. 17 no-shows of 24 at 71%, -228, net -91, plays 7/0/0, cashes 4/0/0, PCR 0; board place 33)
        "67831814-56c8-47ac-bbe2-882dc339072a", // kojldyn         (surfaced only on the post-22:00Z screen re-run. week-20 WATCH returning. 17 no-shows of 32 at 53%, -208, net -37, plays 14/1/0, cashes 4/0/0, PCR 30; unplaced)

        // ---- PS DB (5) ----
        "67e551f8-a305-4bbd-9c1e-8f96ebdd24b1", // HalfSand_       (board seat 2, 5 wins. **REPEAT by our own history** -- competition ban expired 2026-09-07 -- and a returning WATCH from week-20, where he was acquitted and paid. 54 unproductive of 79 at 68%, -752, net -310, plays 5 NOOBS / 23 MIDDLES, cashes 4/4/0)

        "23ad555b-a45c-47ac-ab4a-a469d7ddbe5e", // ShrekUndies     (outside the money. NEW. 12 no-shows of 22 at 59%, -200, net -39, plays 8/2/0, cashes 4/1/0)
        "ebb52e2f-e4ed-42a9-9711-e55facb1668c", // christdu7340    (outside the money. NEW. 11 no-shows of 23 at 48%, -165, net +88, plays 11/1/0, cashes 5/0/0)
        "0bb2e091-9f60-4045-a615-e01e3eca5d71", // silvery_harvest8 (outside the money. REPEAT. 12 no-shows of 27 at 44%, -180, net +5, plays 0/15/0, cashes 0/4/0)
        "a52c7f8b-906a-4e82-8e43-b35e76e4417f", // mregan52        (outside the money. NEW. 5 no-shows of 15 at 40%, -98, net +54, plays 4/6/0, cashes 3/1/0)

        // ---- XBOX DB (8) ----
        "e39c9dab-1697-434f-ade9-d0122265ed13", // TMRyuko         (board seat 2, 4 wins. 26 unproductive of 32 at 81%, -336, net -167, max rating at start 55 -- entirely NOOBS, so the ceiling is the counterfactual only)
        "bdd6d57e-e41f-475e-b067-c0d990a5a92c", // xFenrir77       (board seat 3, 4 wins. Entirely TOPS: plays 0/0/28, cashes 0/0/7, net +330 RISING. Cleared on the same shape in weeks 19 and 20; here to be judged, not to be convicted)
        "95d6f8ae-0562-455e-99e0-6679cc506389", // LaterGENJI      (board seat 5, 4 wins. 8 unproductive of 15 at 53%, -114, net +63, plays 5 NOOBS / 3 MIDDLES, cashes 4/1/0)
        "0521e9f5-dcf5-438c-908d-689f0dfd2242", // Fuzzytacos6571  (board seat 7, 3 wins. REPEAT -- competition ban expired 2026-06-01. 14 unproductive of 19 at 74%, -179, max rating at start 55, cashes 5/0/0)
        "7ace60e8-8b33-401a-ae9f-b315dd848049", // ELTITOGRAVY6    (board seat 8, 3 wins. 24 unproductive of 42 at 57%, -322, net +3, plays 12 NOOBS / 12 MIDDLES, cashes 6/1/0, 7 prizes)
        "7e4889a6-8e26-4eb8-97b5-3c67ad6c423d", // BoraxHook       (outside the money. NEW. 10 no-shows of 17 at 59%, -175, net +81, plays 7/0/0, cashes 6/0/0)
        "013368d1-e8a8-437a-88b0-71059e3287eb", // BuzzingLemur417 (outside the money. BANNED to 2026-11-25, no seat on the board. 25 no-shows of 36 at 69%, -354, net -126, plays 9/1/0, cashes 4/1/0)
        "c6440075-c23c-4b02-80ad-fe1f5ff9b25e"  // UlfsonUlfstroem (outside the money. REPEAT. 11 no-shows of 17 at 71%, -157, net -19, plays 6/0/0, cashes 4/0/0)
      ] },
      Timestamp: { $gte: ISODate("2026-09-14T00:00:00.000Z"), $lte: ISODate("2026-09-27T23:59:59.000Z") },
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
