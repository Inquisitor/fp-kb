// FP-43631 week-11 -- Tournament-log trajectory dump query (SINGLE, run on all 3 Mongo PROD)
// =============================================================================
// One aggregate, run against each Mongo PROD instance separately. UserIds are
// globally unique (FP GUIDs) -- each platform's Mongo will return only its own
// candidates, the others silently match nothing. Window: 2026-06-29T00:00:00Z
// -> 2026-07-19T23:59:59Z (3 weeks: ~2 weeks pre-context + the week-11 window).
//
// 20 candidates total: Steam 7, PS 11, Xbox 2.
//
// Each output row is "<UserId>\t<ISO timestamp>\t<verbatim Message>", sorted
// UserId ASC then Timestamp ASC so a per-UserId grep yields a chronological slice.
//
// Save each per-platform output to one .tsv inside `pcr-log-trajectories-2026-07-19/`:
//   steam-dump-2026-07-19.tsv  (7 candidates expected)
//   ps-dump-2026-07-19.tsv     (11 candidates expected)
//   xb-dump-2026-07-19.tsv     (2 candidates expected)

db.tournamentLog.aggregate([
  { $match: {
      UserId: { $in: [
        // ---- STEAM (7) ----
        "4ab9d03a-40d4-4e4e-ad29-9628a8397f93", // yevhen331             (Support pre-actioned, BanEnd 2026-08-18; 6N pure, 30 no-shows 68%)
        "b3440760-bbd6-4af0-b0ee-def6b131de62", // Zemaro                (NEW, 6N pure, 12 no-shows 52%, net +22)
        "9177acbe-89ce-4b98-998a-469f353f2afd", // sen1a                 (Support pre-actioned, BanEnd 2026-08-17; 5N pure, 11 no-shows 46%)
        "64d0a9da-9e02-4c2d-99e9-247571cadae0", // TTC-Squilliam         (NEW, 3N+1M mixed, 16 no-shows 46%, MIDDLES-heavy 3/16/0 played)
        "313eee9d-da0c-42f0-9b1e-e4d0c2598766", // FoxMilard             (NEW, 4N pure, 10 no-shows 48%, LB Rank 27, LifetimeGold 21 -- heavy grinder)
        "7b7c21d3-7205-4d75-b31c-38b88679ae44", // CHERTEN0K             (NEW, 3N+1M mixed, 9 no-shows + 3 zero-score, net +62 climbing)
        "d1d22645-9ea5-4529-925d-b35e7a77db89", // n4rkos060905          (NEW, 4N pure, 7 no-shows 35%)

        // ---- PS (11) ----
        "7de51a5c-1745-45d4-a89a-c1bbd76a69e5", // evgeniy3311           (Support pre-actioned, BanEnd 2026-08-02; W10 rule-6 clock VALIDATION -- WATCH last cycle Lifetime 10, now 11N pure 63%)
        "b7663881-7cb4-40fd-b92d-715feaf6fea8", // DraVexTab             (NEW, 8N+1M mixed, 18 no-shows 53%, Lifetime 15)
        "f5df63f8-7dd2-42e4-9886-6ed4281ec34d", // Ricky27sampei         (Support pre-actioned, BanEnd 2026-08-02; 8N pure, 21 no-shows 66%)
        "d7b6151c-3905-4469-801d-9fc6b06fd87a", // La_Iena_River_        (NEW, 3N+3M mixed, 42 no-shows 84% EXTREME, net -376)
        "469df796-d270-40ff-bad9-8a5b9d83b6dc", // CFC-T-W-T-32568       (NEW, 6N pure, 23 no-shows 70%, LB Rank 8, PCR 4)
        "56dd5f44-ef78-4bc6-9161-579409201337", // LZ23J7KS              (Support pre-actioned, BanEnd 2026-08-01; W8 watchlist MASTERS 0N+1M+4T, PCR 925/2250)
        "ce09da31-c3fc-4b21-915a-87eba15367d9", // Chuydakid214         (NEW, 4N+1M mixed, 20 no-shows 53%)
        "35ed0e4a-4acb-4072-b23a-10d5b5578fea", // vlad_spain            (NEW, 5N pure, 19 no-shows 59%)
        "4fd0a4f7-49aa-4083-a828-8c6e8ed83e6c", // Narco_KiNg-_-         (NEW, 5N pure, 14 no-shows 58%)
        "ca565ad3-64c8-4274-aaf9-9274d8c7e2b3", // DiffenDaff            (NEW, TOP-flavor MASTERS 0N+4M+0T, PCR 913, same family as LZ23J7KS/JIALIN0720)
        "cc4044a9-0829-40e6-a6ba-d3222dbce8d0", // strullendorfer        (REPEAT -- our week-7 NEW 2W BanEnd 2026-07-06, expired, returned 13d later; 4N pure)

        // ---- XB (2) ----
        "fb67d3bc-e77d-4579-856a-f2df8dc3caa5", // Belion019             (NEW, 7N pure, 21 no-shows 70%)
        "ff382a4e-f0c7-4dc4-a882-80f32276e095"  // TurboBandz6351        (NEW, 5N pure, 12 no-shows + 5 zero-score -- ZeroScore pivot signature)
      ] },
      Timestamp: { $gte: ISODate("2026-06-29T00:00:00.000Z"), $lte: ISODate("2026-07-19T23:59:59.000Z") }
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
