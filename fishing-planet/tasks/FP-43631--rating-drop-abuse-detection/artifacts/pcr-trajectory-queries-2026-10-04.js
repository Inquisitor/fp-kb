// FP-43631 week-22 -- tournament log pull, whole cohort (SINGLE query, run on all 3 Mongo PROD)
// =============================================================================
// Same query as every cycle; only the UserId list and the two dates change.
//
// Window: 2026-09-21T00:00:00Z -> 2026-10-04T23:59:59Z (14 days = the whole retention of the
// collection). The sweep week is 09-28..10-04; the week before is context.
//
// The log supplies what SQL lacks: the registration time and the rating chain. Status and counts
// come from the SQL pull (participation-ledger-2026-10-04.sql).
//
// Output rows: "<UserId>\t<ISO timestamp>\t<verbatim Message>", sorted UserId ASC then Timestamp ASC.
// Save each platform's result with the header row into `pcr-log-trajectories-2026-10-04/`:
//   steam-dump-2026-10-04.tsv  (6 candidates expected)
//   ps-dump-2026-10-04.tsv     (9 candidates expected)
//   xb-dump-2026-10-04.tsv     (4 candidates expected)

db.tournamentLog.aggregate([
  { $match: {
      UserId: { $in: [
        // ---- STEAM DB (6) ----
        "17d9446a-6115-42b0-a48d-14914922f593", // Tho1324
        "daa00f0b-2ba8-49a5-8be2-9880d6c856e3", // MP_Alan          (cleared in week-20)
        "8e2f69a6-b63b-46e6-a0b8-cdfb5741dd50", // mr.GreeM
        "76dc3e6b-4bea-47ed-83a4-d0649d605ff9", // JoeCoviDodo      (week-20 WATCH)
        "99d3fc51-c708-4c3e-9baf-daab73a22602", // 1st_Demigod
        "60d42746-1430-4d54-a479-29583b87b0a5", // Mariusz1029      (REPEAT, ban ended 2025-02-15)

        // ---- PS DB (8) ----
        "2c393625-f229-4284-8db2-962bebde0774", // marzak66
        "1cdb373f-5a08-4d3a-ab4a-83dab1f00685", // anatoly2026      (reviewed in week-18)
        "bb7842cc-e2f4-491a-a6a1-0083d202bcf7", // keeno1
        "8cff48cd-f1ae-418f-82b4-20fd72b6f1dc", // intro20          (banned elsewhere until 2026-12-02)
        "496e32d7-cd9f-4f8f-96df-f9171fce1e93", // zezinho_curuja
        "e3a99cf5-48d9-423f-998b-d714cc1668f6", // thebig35994
        "d442b23b-4502-4427-8e08-ca35871ddc4d", // popeye-43
        "e25c082e-8a19-4236-aa8b-c345137e9ea3", // STARI40K_YT      (REPEAT, ban ended 2026-07-13)
        "c896536d-28fa-4785-a85e-48c27b947590", // Panonski_Alas    (REPEAT; entered the cohort on the run after 22:00Z)

        // ---- XBOX DB (4) ----
        "623a4d04-bc0d-486b-aff5-fea169cbd915", // ArticSquid71
        "bdd6d57e-e41f-475e-b067-c0d990a5a92c", // xFenrir77        (REPEAT, ban ended 2026-06-01; cleared three cycles running)
        "13090ffe-7894-4c66-9af2-0cd81c1a03eb", // ChaChaWuu9588    (REPEAT, ban ended 2026-09-28)
        "2f692613-2090-4d4c-8e52-736a6bef5c2c"  // ScionHades8639   (REPEAT, ban ended 2026-09-28)
      ] },
      Timestamp: { $gte: ISODate("2026-09-21T00:00:00.000Z"), $lte: ISODate("2026-10-04T23:59:59.000Z") },
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
