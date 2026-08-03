// FP-43631 week-13 -- Tournament-log trajectory dump query (SINGLE, run on all 3 Mongo PROD)
// =============================================================================
// One aggregate, run against each Mongo PROD instance separately. UserIds are
// globally unique (FP GUIDs) -- each platform's Mongo returns only its own
// candidates. Window: 2026-07-13T00:00:00Z -> 2026-08-02T23:59:59Z
// (3 weeks: ~2 weeks pre-context + the week-13 window).
//
// 18 candidates: Steam DB 10, PS DB 5, Xbox DB 3.
// NOTE: the per-DB split is by database, not by the player's platform label --
// ELPEZGORDO12 is an Epic account living on the Steam DB, Pilou625057 is a Win10
// account on the Xbox DB. First cycle where the cohort is not purely Steam/PS/Xbox.
//
// Server-side Message filter keeps only the event types the parser recognises,
// so the dump stays in the low-MB range.
//
// Output rows: "<UserId>\t<ISO timestamp>\t<verbatim Message>", sorted UserId ASC
// then Timestamp ASC. Save per-platform output into `pcr-log-trajectories-2026-08-02/`:
//   steam-dump-2026-08-02.tsv  (10 candidates expected)
//   ps-dump-2026-08-02.tsv     (5 candidates expected)
//   xb-dump-2026-08-02.tsv     (3 candidates expected)

db.tournamentLog.aggregate([
  { $match: {
      UserId: { $in: [
        // ---- STEAM DB (10) ----
        "13ec8b47-ba33-4510-9cf7-9c365e0bd267", // LuizFernandoo    (Support pre-actioned 07-31 -> 08-31, ONE MONTH; 9N pure, 42 NS 76%, PCR 0, 7 DQs)
        "185a2cba-35c6-4e6a-9313-892a41a2e8c9", // BarbosUa         (Support pre-actioned 08-02 -> 08-16, 2W; 8N pure, 37 NS 57%, LB Rank 20)
        "a0239a6d-6cf4-48ed-92c5-7eddfd118c76", // MORPH3US         (Support pre-actioned 07-31 -> 08-31, ONE MONTH; **W10 WATCH under rule 6 returning** -- Lifetime 6 -> 18, now 8N pure, PCR 0. 4th rule-6 ladder validation)
        "5ed0507e-3d58-4fa7-b5c5-a3df361b791f", // FarantirPL       (NEW; **W9 novice-deference WATCH returning after two clean cycles** -- 21 NS 70%, PCR 0, Lifetime 23. Was flagged in the W11 leaderboard check as walking the gate boundary)
        "56f4b6b1-cda8-43a7-9bc6-9dd2efdaebc2", // ELPEZGORDO12     (**Epic account on the Steam DB** -- first non-Steam row here; Support pre-actioned 08-02 -> 08-16, 2W; 6N pure, net +155)
        "135725a2-637f-44f3-8389-df61b85f4e67", // X1aoDouYa        (REPEAT stale BanEnd 2026-06-17; TOP-flavor 0N+5M+0, PCR 884 -- multi-cycle rule 7 dir 2 closure candidate)
        "f80df54f-b077-4665-9822-a43414055b1e", // EsseDouble       (REPEAT stale BanEnd 2026-06-17; TOP-flavor 0N+4M+0, PCR 805, played 0N+37M+0T -- same closure question)
        "da1e5723-6f95-4600-98cd-f3e680e5163e", // wallims          (NEW; 4N pure, 18 NS 62%, PCR 25, LB Rank 2)
        "4002e06b-bc41-456a-bdf1-84cf2f7b5b05", // aperno           (Support pre-actioned 08-02 -> 08-16, 2W; 4N pure, LB Rank 1, 4 DQs)
        "132e8be9-7515-4898-b4d6-acf7fade37c7", // Aorney           (REPEAT, BanEnd 2026-07-01 expired ~4.5 weeks ago; **was on the week-4 watchlist as a MIDDLES-only flavor**; now 3N+1M, Lifetime 59)

        // ---- PS DB (5) ----
        "30f95ada-24fa-4fa1-8671-48f73d804156", // BOOMDATRUTH2     (NEW; **W12 WATCH returning with escalation** -- prizes 4N -> 8N, NS 12 -> 26, was exactly at the 30% gate last cycle)
        "d7b6151c-3905-4469-801d-9fc6b06fd87a", // La_Iena_River_   (Support pre-actioned 08-02 -> 09-02, ONE MONTH; **operator held this on WATCH last cycle against the leaderboard criterion and was wrong** -- prizes 5N -> 7N, NS 9 -> 21)
        "17c96f92-269f-4811-af1e-813afc75e144", // Old-Black-Fisher (NEW; 5N pure, 19 NS 70%, PCR 75)
        "3da8fa78-f042-4666-83c0-a3c76186d02b", // ZacKasoN         (Support pre-actioned 08-01 -> 09-01, ONE MONTH; 4N pure, 17 NS 63%, PCR 4)
        "882bb61a-9f03-4706-b58e-aa9a279e303b", // kokoljj          (REPEAT -- our week-8 ban lapsed 2026-07-13, back within ~3 weeks; 4N pure, 10 NS 67%)

        // ---- XBOX DB (3) ----
        "6de2b7ad-6ea2-4f67-ab64-2c4cd4cbcdca", // Mjolnir8761      (NEW; **largest prize haul in the cohort at 12** (10N+1M+1T) but plays TOPS too (14N+1M+7T) -- mixed profile, not a pure farmer)
        "88c77680-87e5-4432-b7d2-13414ea0fb78", // eMadkiller5964   (NEW; 4N pure, 19 NS 73%, PCR 69)
        "646efd1d-3a4b-4d62-b8cf-d3bc767ac646"  // Pilou625057      (**Win10 account on the Xbox DB**; 2N+1M+1T mixed, played 6N+3M+9T -- TOPS-heavy, weak farm signature)
      ] },
      Timestamp: { $gte: ISODate("2026-07-13T00:00:00.000Z"), $lte: ISODate("2026-08-02T23:59:59.000Z") },
      Message: { $regex: "^(Tournament reward Competition|Player started scoring time for Competition|Player registered for Competition|Player unregistered from Competition|Registration for tournament Competition|About to process tournament Competition|CHEAT:)" }
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
