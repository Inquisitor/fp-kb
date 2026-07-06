// FP-43631 week-9 -- Tournament-log trajectory dump query (SINGLE, run on Steam + PS Mongo PROD)
// =============================================================================
// One aggregate, run against each Mongo PROD instance separately. UserIds are
// globally unique (FP GUIDs) -- each platform's Mongo will return only its own
// candidates, the others silently match nothing. Window: 2026-06-15T00:00:00Z
// -> 2026-07-05T23:59:59Z (3 weeks: ~2 weeks pre-context + the week-9 window).
//
// 12 candidates total: Steam 8, PS 4, Xbox 0 (Xbox cohort empty this week).
//
// Each output row is "<UserId>\t<ISO timestamp>\t<verbatim Message>", sorted
// UserId ASC then Timestamp ASC so a per-UserId grep yields a chronological slice.
//
// Save each per-platform output to one .tsv inside `pcr-log-trajectories-2026-07-05/`:
//   steam-dump-2026-07-05.tsv  (8 candidates expected)
//   ps-dump-2026-07-05.tsv     (4 candidates expected)
// I'll split them into per-candidate files via `grep "^<uid>" | cut -f2-`.

db.tournamentLog.aggregate([
  { $match: {
      UserId: { $in: [
        // ---- STEAM (8) ----
        "07782225-67bf-4863-a1a2-eb2fab29cbfd", // ArTeM209        (already BANNED, Support pre-actioned; BanEnd 2026-08-04)
        "e0a2f28a-f5be-4a5c-9898-43f2c093dbb1", // Ti_To           (NEW, 6N+1M mostly-NOOBS)
        "702cdd67-82e7-40ec-bfeb-d57fb7ceae1f", // VM_Vigor        (3rd-cycle returning: week-6 WATCH, week-8 WATCH, TOP-flavor persists)
        "8987d0b6-e42e-45b1-b66a-beff60d7d3c5", // CreekSamurai    (NEW, 7N pure, fresh Level 62, borderline 32% NoShow)
        "e98d05d2-4e6f-45bc-8421-9ed08cdce54e", // H.a.r.y44       (NEW, 6N pure, heavy veteran lifetime 178)
        "5ed0507e-3d58-4fa7-b5c5-a3df361b791f", // FarantirPL      (NEW, 5N pure)
        "ef40b474-3f12-493d-ac39-a4a425be6600", // Gustyn112       (already BANNED, Support pre-actioned; BanEnd 2026-08-05)
        "53e1b654-48bd-413c-ae77-6e58c39cfc14", // IaMiya          (NEW, 4N pure, small sample)

        // ---- PS (4) ----
        "c896536d-28fa-4785-a85e-48c27b947590", // Panonski_Alas   (REPEAT stale BanEnd 2026-06-01; MASTERS PCR 1025, TOP-flavor)
        "5c5b4305-bc67-403e-a013-640e396f1a9f", // EL-_-Diablo-_-51 (NEW, 6N pure)
        "eea41d0d-3987-403f-a479-f2f8efe326d7", // San-miculsan    (NEW, 5N+0+1T mixed)
        "e28dd543-32ff-449f-8a0f-02af1c615d38"  // kevynrdm13      (NEW, 3N+1M borderline)
      ] },
      Timestamp: { $gte: ISODate("2026-06-15T00:00:00.000Z"), $lte: ISODate("2026-07-05T23:59:59.000Z") }
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
