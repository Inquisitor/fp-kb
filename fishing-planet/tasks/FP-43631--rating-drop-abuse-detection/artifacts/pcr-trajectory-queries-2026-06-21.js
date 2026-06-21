// FP-43631 week-7 — Tournament-log trajectory dump query (SINGLE, run on all 3 Mongo PROD)
// =============================================================================
// One aggregate, run against each Mongo PROD instance separately. UserIds are
// globally unique (FP GUIDs) — each platform's Mongo will return only its own
// candidates, the others silently match nothing. Window: 2026-06-01T00:00:00Z
// -> 2026-06-21T23:59:59Z (3 weeks: ~2 weeks pre-context + the week-7 window).
//
// Each output row is "<UserId>\t<ISO timestamp>\t<verbatim Message>", sorted
// UserId ASC then Timestamp ASC so a per-UserId grep yields a chronological slice.
//
// Save each per-platform output to one .tsv next to this file:
//   steam-dump-2026-06-21.tsv  (9 candidates expected)
//   ps-dump-2026-06-21.tsv     (15 candidates expected)
//   xb-dump-2026-06-21.tsv     (2 candidates expected)
// I'll split them into per-candidate files via `grep "^<uid>" | cut -f2-`
// (drops the UserId leading column to match the week-6 per-candidate format the
// collector agent expects).

db.tournamentLog.aggregate([
  { $match: {
      UserId: { $in: [
        // ---- STEAM (9) ----
        "09daa0c8-856a-4328-8001-9cc1b2683fab", // FurryCurrentMaster   (REPEAT, our week-4 ban expired today)
        "1030bc70-976f-4ae8-8464-5e73a4f5382d", // TF_B4ngwal           (NEW)
        "41c022cf-88c4-43f0-a8e5-c1f6f4963242", // Kacumi               (BANNED_NOW by Support, BanEnd 2026-07-20)
        "37fe52ec-f9d1-4439-9ddd-2c38982c66c3", // Dokidepp             (REPEAT, ban expired 2026-04-06)
        "6218ffde-5eac-4566-bba5-711422d44f57", // Ramboo051            (NEW)
        "3043cb8f-281b-47df-bec7-5ca722fa0394", // Audrey_HH            (NEW)
        "004e4969-131b-426f-b936-6b75f2b6bcd0", // poink                (BANNED_NOW by Support, BanEnd 2026-07-17)
        "45bb43b9-8690-43ae-aa4d-190515f4f2ec", // OZBULLDOG            (NEW, mixed N+M)
        "d2e0ba0e-3ac5-42ec-a645-f8c66137f310", // VovaTemniy           (NEW, climbing)

        // ---- PS (15) ----
        "84f0d212-9f87-4851-9cee-86e2a6dfcb8b", // A-J-Rimmer-BSC       (BANNED_NOW, BanEnd 2026-07-05)
        "c5d90e33-5022-4049-9960-c39a28b0d2a4", // jorja09              (NEW, 10 NOOBS prizes)
        "b879ab80-43e5-455f-a045-b5a28480af04", // rabolio41100         (week-6 WATCH escalator, 8 NOOBS this week)
        "c5a87a36-e9a3-44c6-b69a-cb08adbeadea", // Matiamo_PL           (NEW)
        "76b5f7f3-346a-46b1-9c70-4fe0743572c3", // Flo-GrayFOX          (REPEAT, ban expired 2026-06-01)
        "5db0a328-1307-4762-a1db-7ff34e63bfe5", // bostonbroncos24      (REPEAT, ban expired 2026-06-01)
        "e812002d-0618-48eb-abae-d88078a4c9f8", // maminapokorny83      (week-5 WATCH escalator, 6 NOOBS this week)
        "224f5d15-c1b9-4b5e-9435-3f7fc6184adf", // nowa_zajawka         (BANNED_NOW by Support, BanEnd 2026-07-21)
        "4277fb92-d6e9-4ca5-9940-ea77cb5dfa6c", // Neterrall            (NEW, extreme 77% no-show)
        "09bdc8bf-b133-493e-9ebe-e5c145cb0fde", // ST-9257              (NEW, TOP-flavor PCR 943)
        "f6816fd8-9a24-424a-aa90-04b1fd4565e8", // Fat_tuna_mama        (NEW)
        "8893b30e-73bb-49e0-b573-d1c44cc78075", // TR-dennisfb          (NEW, MIDDLES-only flavor)
        "c6fa0149-53a9-42a6-83a6-aeaf1614989a", // Tight_LinesJoe65     (STALE_FLAG with 2025 BanEnd, MIDDLES-only)
        "8e2477c7-c8a1-4850-a4d1-5e2579855656", // TheFastestDevil      (NEW)
        "cc4044a9-0829-40e6-a6ba-d3222dbce8d0", // strullendorfer       (borderline 33% no-show)

        // ---- XB (2) ----
        "1abb20a3-8696-4737-a0c4-5620a8a374df", // LEBOOGIEEEE          (NEW, 10 prizes 9N+1M, Win10)
        "013368d1-e8a8-437a-88b0-71059e3287eb"  // BuzzingLemur417      (REPEAT, ban expired 2026-06-01)
      ] },
      Timestamp: { $gte: ISODate("2026-06-01T00:00:00.000Z"), $lte: ISODate("2026-06-21T23:59:59.000Z") }
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
