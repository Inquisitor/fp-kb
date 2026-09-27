// FP-43631 week-20 -- Tournament-log trajectory dump (SINGLE query, run on all 3 Mongo PROD)
// =============================================================================
// DEADLINE SUBSET. This dump covers only the 6 candidates who are in or can reach the money on
// the closing weekly board. The other 10 of the 18-candidate cohort carry no deadline and are
// dumped separately after the payout.
//
// Payout time: the competitive rewards are enqueued by `CompetitiveLeaderboardFinalizationJob`,
// which runs at **:07 past the hour** -- so 00:07Z, not 00:00Z and not 00:20Z. (:20 is
// `CompetitiveLeaderboardCleanupJob`, which only drops the current-period rows.) A ban bites only
// if it is in `Profiles` AND propagated to `CompetitiveRatingsCurrent.IsBanned` before :07.
//
// Window: 2026-09-07T00:00:00Z -> 2026-09-20T23:59:59Z (fourteen days = the whole retention of the
// collection, not a choice). The sweep week is 09-14..09-20; the preceding week is pre-context.
//
// RULE 5 SPAN (week-20): the 2 boundary drops its test requires must fall inside the SWEEP WEEK.
// The card's `middles_to_noobs_drops` counts the whole fourteen days, so read the dates off the
// ledger before applying the threshold.
//
// SUPPORT-BLIND. Annotations carry OUR ban history and OUR prior watchlist entries only.
//
// Output rows: "<UserId>\t<ISO timestamp>\t<verbatim Message>", sorted UserId ASC then Timestamp
// ASC. Save per-platform output into `pcr-log-trajectories-2026-09-20/`:
//   steam-dump-2026-09-20.tsv  (2 candidates expected)
//   ps-dump-2026-09-20.tsv     (3 candidates expected)
//   xb-dump-2026-09-20.tsv     (1 candidate expected)

db.tournamentLog.aggregate([
  { $match: {
      UserId: { $in: [
        // ---- STEAM DB (2) ----
        "dcb21f48-6b54-4f74-8a3f-9caae8bff6a0", // LEK_TARNO       (board seat 1, 7 wins. 40 unproductive of 72 at 56%, -506, plays 21 NOOBS / 21 MIDDLES, cashes 9/3/0, 12 prizes)
        "f3150296-cc7f-43b0-90a5-cc941b45e960", // HavocHHH        (board seat 8, 3 wins. Entirely MIDDLES: plays 0/24/0, cashes 0/7/0. Net +114 RISING, current PCR 972, max rating at start 955 -- the counterfactual ceiling is the question)

        // ---- PS DB (3) ----
        "a92ed0c7-bb5e-43ac-971c-7af91fd47d31", // CrazyGepard     (board seat 3, 5 wins. 16 unproductive of 26 at 62%, plays 10/0/0, cashes 8/0/0, max rating at start 100 -- entirely NOOBS, rule 9 shape)
        "67e551f8-a305-4bbd-9c1e-8f96ebdd24b1", // HalfSand_       (board seat 10, 3 wins, EXACTLY on the paying line. **REPEAT by our own history** -- competition ban expired 2026-09-07. Plays 0/22/0, cashes 0/4/0)
        "80b05c6c-7719-40b5-89ca-3a358f0bd166", // Gentleman83190  (board seat 13, 3 wins -- reaches seat 10 if the 2 cohort members above him are banned. 26 unproductive of 35 at 74%, -370, net -149)

        // ---- XBOX DB (1) ----
        "16dda5f1-e9c3-46f5-a43f-bfb806de1f8f"  // Rapidstrapon    (board seat 5, 4 wins. 42 unproductive of 53 at 79%, -568, net -175, plays 12 NOOBS / 1 MIDDLES, cashes 7/1/0)
      ] },
      Timestamp: { $gte: ISODate("2026-09-07T00:00:00.000Z"), $lte: ISODate("2026-09-20T23:59:59.000Z") },
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

// NOTE on `presence_gaps` (week-20): the regex above is deliberately narrow and is what feeds the
// ledger table. The presence-gap field needs timestamps of EVERY line regardless of type, so it
// cannot be computed from this output. Run the companion query below per platform and hand both
// files to the parser.

// ---- Companion A: all-line timestamps, for presence_gaps ----
// Save as: steam-presence-2026-09-20.tsv / ps-presence-2026-09-20.tsv / xb-presence-2026-09-20.tsv
db.tournamentLog.aggregate([
  { $match: {
      UserId: { $in: [
        "dcb21f48-6b54-4f74-8a3f-9caae8bff6a0", "f3150296-cc7f-43b0-90a5-cc941b45e960",
        "a92ed0c7-bb5e-43ac-971c-7af91fd47d31", "67e551f8-a305-4bbd-9c1e-8f96ebdd24b1",
        "80b05c6c-7719-40b5-89ca-3a358f0bd166", "16dda5f1-e9c3-46f5-a43f-bfb806de1f8f"
      ] },
      Timestamp: { $gte: ISODate("2026-09-07T00:00:00.000Z"), $lte: ISODate("2026-09-20T23:59:59.000Z") }
  } },
  { $sort: { UserId: 1, Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [
      "$UserId", "\t", { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }
  ] } } }
]);
