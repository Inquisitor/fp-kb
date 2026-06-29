// FP-43631 week-8 — Tournament-log trajectory dump query (SINGLE, run on all 3 Mongo PROD)
// =============================================================================
// One aggregate, run against each Mongo PROD instance separately. UserIds are
// globally unique (FP GUIDs) — each platform's Mongo will return only its own
// candidates, the others silently match nothing. Window: 2026-06-08T00:00:00Z
// -> 2026-06-28T23:59:59Z (3 weeks: ~2 weeks pre-context + the week-8 window).
//
// 24 candidates total: Steam 7, PS 15, Xbox 2.
//
// Each output row is "<UserId>\t<ISO timestamp>\t<verbatim Message>", sorted
// UserId ASC then Timestamp ASC so a per-UserId grep yields a chronological slice.
//
// Save each per-platform output to one .tsv inside `pcr-log-trajectories-2026-06-28/`:
//   steam-dump-2026-06-28.tsv  (7 candidates expected)
//   ps-dump-2026-06-28.tsv     (15 candidates expected)
//   xb-dump-2026-06-28.tsv     (2 candidates expected)
// I'll split them into per-candidate files via `grep "^<uid>" | cut -f2-`.

db.tournamentLog.aggregate([
  { $match: {
      UserId: { $in: [
        // ---- STEAM (7) ----
        "c434afc9-875d-4ece-8efa-fe7810c6daff", // ArmlessFisherMan      (NEW, mixed N+M)
        "702cdd67-82e7-40ec-bfeb-d57fb7ceae1f", // VM_Vigor              (week-6 WATCH returning, TOP-flavor persists)
        "883362ef-98a6-4406-b2dc-9636e1d022fc", // BB_Anastasia          (NEW, MIDDLES-heavy mixed, 74 regs volume)
        "aad56c35-bd05-4025-b6e2-6ed364f1d8d7", // KingYakO2             (NEW, 7N pure, PCR 0)
        "222bbe9d-3557-4280-b854-cbef2ae48707", // MonsterFish_fuark     (week-6 WATCH ESCALATOR -- flavor changed to 7N+0+0)
        "4cf530ba-2330-4dc0-bb8b-c03a55176efc", // angeperdu             (NEW, was week-5 borderline WATCH, now 4N+3M mixed)
        "683d0d32-290e-4726-bfe9-ad16a0234324", // krolikusik            (NEW, 3N+1M mixed)

        // ---- PS (15) ----
        "97d1fde6-7ad7-41a7-aed8-79e70220d035", // Adlerblut-Slayer      (BANNED_NOW BanEnd 2026-07-28, 12 NOOBS prizes highest haul)
        "c5a87a36-e9a3-44c6-b69a-cb08adbeaeda", // Matiamo_PL            (week-7 WATCH ESCALATOR -- flavor changed to 8N+0+0)
        "46e9e18f-0e49-4f9e-b91c-b074823cf02b", // tigrou_le_boss42      (NEW, 8N pure)
        "56ed8774-68b1-49b2-b395-e594dbe4b766", // M4R5H_57_             (NEW, 6N pure, 79% no-show extreme)
        "09bdc8bf-b133-493e-9ebe-e5c145cb0fde", // ST-9257               (week-7 WATCH returning, TOP-flavor persists 0N+6M+0)
        "d8cde1ee-38b7-4cd1-ad46-a8b093491c6c", // Ttv_s4muka019         (week-6 WATCH returning, TOP-flavor persists 0N+6M+0)
        "8893b30e-73bb-49e0-b573-d1c44cc78075", // TR-dennisfb           (BANNED_NOW BanEnd 2026-07-23, was week-7 WATCH -- Support caught flavor change to 6N+0+0)
        "06bb9d34-bc04-4591-80f6-0f8ad8f05087", // IKIGAI__1__           (STALE_FLAG REPEAT, BanEnd 2026-06-17 expired, 5N+0+0)
        "56dd5f44-ef78-4bc6-9161-579409201337", // LZ23J7KS              (NEW, MASTERS tier PCR 2215, 80 regs, 1N+1M+2T mixed)
        "cbf68606-df2c-46b3-8086-e76b7019c1d1", // Epic70cosmin          (NEW, 4N pure, 72% no-show)
        "70e09be8-5355-4c3f-ab4e-06ab15b34321", // serber-denis85        (STALE_FLAG MIDDLES-only flavor, BanEnd 2026-06-01, 0N+4M+0)
        "d1320268-0463-4289-a455-24bab60b2363", // MrChadRico            (NEW, 4N pure)
        "ee558d4f-7515-4b5f-b0fd-4c1f47319c3a", // MONSTER-VERT1325      (NEW, 4N pure)
        "330f8b15-1fc5-49dc-9829-8b710b04f80f", // TR-BILECIKLI_CMR      (NEW, 3N+1M mixed)
        "882bb61a-9f03-4706-b58e-aa9a279e303b", // kokoljj               (NEW, 4N pure)

        // ---- XB (2) ----
        "f25a97b7-fdef-4c1c-b50a-0d0a117745d4", // Smooter85             (NEW, 9N pure, 72% no-show, strongest Xbox)
        "8f71ccc8-3d78-4b1c-9072-6f56e48e2862"  // BarNoneD              (NEW, 5N pure, fresh lifetime)
      ] },
      Timestamp: { $gte: ISODate("2026-06-08T00:00:00.000Z"), $lte: ISODate("2026-06-28T23:59:59.000Z") }
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
