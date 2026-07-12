// FP-43631 week-10 -- Tournament-log trajectory dump query (SINGLE, run on all 3 Mongo PROD)
// =============================================================================
// One aggregate, run against each Mongo PROD instance separately. UserIds are
// globally unique (FP GUIDs) -- each platform's Mongo will return only its own
// candidates, the others silently match nothing. Window: 2026-06-22T00:00:00Z
// -> 2026-07-12T23:59:59Z (3 weeks: ~2 weeks pre-context + the week-10 window).
//
// 19 candidates total: Steam 10, PS 5, Xbox 4.
//
// Each output row is "<UserId>\t<ISO timestamp>\t<verbatim Message>", sorted
// UserId ASC then Timestamp ASC so a per-UserId grep yields a chronological slice.
//
// Save each per-platform output to one .tsv inside `pcr-log-trajectories-2026-07-12/`:
//   steam-dump-2026-07-12.tsv  (10 candidates expected)
//   ps-dump-2026-07-12.tsv     (5 candidates expected)
//   xb-dump-2026-07-12.tsv     (4 candidates expected)

db.tournamentLog.aggregate([
  { $match: {
      UserId: { $in: [
        // ---- STEAM (10) ----
        "13d390e6-0cb7-4f30-9846-24cc994bbde2", // JFF_Gothyka           (Support pre-actioned 5W, BanEnd 2026-08-12)
        "47fee9fa-c9e6-4dbe-8742-63b56558d890", // LaccFarro             (REPEAT -- our week-6 BAN expired 2026-06-29, Support re-banned 5W 2026-08-12)
        "b187e932-866f-454b-b455-a9f5f3240af3", // JIALIN0720            (NEW, TOP-flavor MIDDLES-veteran family from w5/w6)
        "17999a3e-1bab-479a-b4de-374eb48ff867", // Captain_Djack_Sparrow (NEW, mixed 5N+1M)
        "a0239a6d-6cf4-48ed-92c5-7eddfd118c76", // MORPH3US              (NEW, 6N pure)
        "8987d0b6-e42e-45b1-b66a-beff60d7d3c5", // CreekSamurai          (week-9 novice-deference WATCH, Support pre-actioned 2W BanEnd 2026-07-26 -- validation case)
        "42065519-567d-4d9e-b777-c2f16e9c5080", // wesleytorres1         (NEW, 5N pure, novice threshold)
        "9757fd6a-8435-409a-9f83-33214af80424", // TrcikLowFiv           (REPEAT stale BanEnd 2026-06-12; TOP-flavor 0N+5M+0)
        "7f4002bb-b58e-44aa-adc6-7b46be3bb9e0", // sandaljepitt          (Support pre-actioned 2W, BanEnd 2026-07-26)
        "135725a2-637f-44f3-8389-df61b85f4e67", // X1aoDouYa             (REPEAT stale BanEnd 2026-06-17; TOP-flavor 0N+4M+0)

        // ---- PS (5) ----
        "6a556e93-8267-453b-a447-493216f2fed0", // MLG720YOLO            (Support pre-actioned 5W, BanEnd 2026-08-11)
        "7de51a5c-1745-45d4-a89a-c1bbd76a69e5", // evgeniy3311           (NEW, 8N pure, novice threshold)
        "54ea8084-5546-4ea8-8068-4c1fdbe77d4a", // Bas_di08              (NEW, TOP-flavor 0N+4M+0, PCR 944)
        "9866bcc0-db97-4383-84e4-464c56a098b0", // Adrian_Yaj08          (NEW, small sample 7 played, mixed 4N+0+1T)
        "1f0b293c-2a06-45cc-bbc5-9b0d0715728f", // Miron_33              (REPEAT stale BanEnd 2025-10-10; mixed)

        // ---- XB (4) ----
        "c7d41236-082f-461d-9a2f-b6642fa5d4af", // Da Sneaky Snake       (Support pre-actioned 5W, BanEnd 2026-08-11; 13N -- record haul)
        "6572e942-f8a7-4f7b-915e-007f21d6e81c", // alphaBiTsoop16        (NEW, 6N pure, 79% no-show extreme)
        "8e72cb93-b58c-4fa8-a647-580afedb7b44", // Sir Mijael            (NEW, mixed 6N pure, novice threshold, fresh lifetime 10)
        "445f4a4a-a904-4fe7-8890-57b67e93f861"  // CraddiePoosta         (Support pre-actioned 5W, BanEnd 2026-08-11)
      ] },
      Timestamp: { $gte: ISODate("2026-06-22T00:00:00.000Z"), $lte: ISODate("2026-07-12T23:59:59.000Z") }
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
