// FP-43631 week-14 -- Tournament-log trajectory dump query (SINGLE, run on all 3 Mongo PROD)
// =============================================================================
// One aggregate, run against each Mongo PROD instance separately. UserIds are
// globally unique (FP GUIDs) -- each platform's Mongo returns only its own
// candidates. Window: 2026-07-20T00:00:00Z -> 2026-08-09T23:59:59Z
// (3 weeks: ~2 weeks pre-context + the week-14 window).
//
// 19 candidates: Steam DB 8, PS DB 10, Xbox DB 1.
// As before, the per-DB split is by database, not by the player's platform label --
// Pilou625057 is a Win10 account living on the Xbox DB.
//
// Message filter change this cycle: the denied-registration event has TWO wire
// formats and the filter only carried one, so the parser undercounted. Both are
// now matched -- "Registration for tournament ..." and "FAILED: Register in
// competition ...". The signal itself is not treated as evidence of intent
// (see the retraction in bans-2026-08-02.md); this is a completeness fix only.
//
// Output rows: "<UserId>\t<ISO timestamp>\t<verbatim Message>", sorted UserId ASC
// then Timestamp ASC. Save per-platform output into `pcr-log-trajectories-2026-08-09/`:
//   steam-dump-2026-08-09.tsv  (8 candidates expected)
//   ps-dump-2026-08-09.tsv     (10 candidates expected)
//   xb-dump-2026-08-09.tsv     (1 candidate expected)

db.tournamentLog.aggregate([
  { $match: {
      UserId: { $in: [
        // ---- STEAM DB (8) ----
        "82c921b5-1383-437d-9afa-9d711a344481", // Dr.Seven        (NEW; 8 prizes all NOOBS, 29 NS 60%, PCR 28, lifetime 11 -- purest farm signature of the cohort)
        "9584b60d-67d5-4362-8021-f1065562a5bc", // lailailaiyu     (NEW; 8 prizes 7N+1M, 18 NS 42%, PCR 144, played 9N+15M+1T)
        "b4b0c273-5b5c-4a0c-bddf-e204ee7f6b1a", // ShadowOfOxigen  (NEW; 6 prizes 5N+1M, 27 NS 66%, PCR 72, lifetime 8)
        "f80df54f-b077-4665-9822-a43414055b1e", // EsseDouble      (REPEAT stale BanEnd 2026-06-17; **upper-bracket harvest candidate** -- 6 prizes all MIDDLES, played 1N+26M+4T, play +445 vs absence -415. Lifetime gold crossed 12 this week, 11 -> 14)
        "9757fd6a-8435-409a-9f83-33214af80424", // TrcikLowFiv     (REPEAT stale BanEnd 2026-06-12; **= StillWaterMind, one of the ground-truth abusers named by Support at task inception**; PCR 996, one point under the TOPS boundary; 6 prizes 5M+1T, lifetime 64)
        "883362ef-98a6-4406-b2dc-9636e1d022fc", // x.Anastasia.x   (REPEAT stale BanEnd 2026-07-13; plays and cashes ONLY in TOPS -- played 0N+0M+22T, prizes 0+0+5. LZ23J7KS shape, harvests no lower bracket)
        "020542dd-5597-4a70-9f5a-b3ff6d3d3a3c", // Tyrant-Kraken   (NEW; **upper-bracket harvest candidate** -- played 0N+22M+13T, prizes 0+3M+1T, play +278 vs net -11)
        "4422cd0f-153b-477b-a4f5-60353c37b5ea", // Martino_CZ      (NEW; **upper-bracket harvest candidate** -- played 0N+6M+5T, prizes all 4 in MIDDLES, play +136 vs net -68)

        // ---- PS DB (10) ----
        "c51f5f26-2816-4ff9-88f3-530af5e7e875", // RGC_ReeL_SKiiLLz (Support pre-actioned -> 2026-09-09; 9 prizes 8N+1M, 27 NS 61%)
        "92264697-3829-4c7a-93f3-861f4533c3ba", // Angel_of_Dunkirk (NEW; 9 prizes all NOOBS, 18 NS 60%, played 10N+2M)
        "53ce591a-f6e8-4907-a0fc-f1cd30f22413", // Costaz_Rexyus    (Support pre-actioned -> 2026-09-09; **harshest profile of the week** -- 57 NS at 86%, PCR 0, 8 prizes all NOOBS, 2 DQs)
        "bfaf6154-7a56-4025-a4a8-4ffe8d6b74b1", // switch-toad      (NEW; 7 prizes all NOOBS, 23 NS 52%, played 18N+3M)
        "ab70490a-bffb-4e18-9297-b3479bac4369", // Seu_Kuka_Beludo  (NEW; 7 prizes 5N+2M, 18 NS 35%, played 7N+25M+1T -- mixed)
        "1d95d7d9-d983-4f8a-b8f2-2e2bb3aaa247", // martelli04       (NEW; 5 prizes all NOOBS, 12 NS 57%)
        "9fcd3f1e-df02-47e7-936d-16b70f76dc22", // Bongler          (NEW; 4 prizes all NOOBS, 15 NS 68%)
        "67e551f8-a305-4bbd-9c1e-8f96ebdd24b1", // HalfSand_        (NEW; 4 prizes all NOOBS, 9 NS 47%)
        "c6e216db-4596-40c8-b404-b7bb16b7269f", // PgS_DaveSon      (NEW; 4 prizes all NOOBS, 8 NS 47%, played 9N only)
        "38ccd8c2-ba30-45e5-87c6-9e5a6435495c", // RoBot-lau        (NEW; **capping-shape candidate** -- PCR 769, never entered TOPS in the window, 4 prizes all MIDDLES, lifetime 9/9/13. Composed prize score 2.00 against the MIDDLES promotion thresholds)

        // ---- XBOX DB (1) ----
        "646efd1d-3a4b-4d62-b8cf-d3bc767ac646"  // Pilou625057      (**Win10 account on the Xbox DB**; **week-13 WATCH returning** -- rule 8 persistence check; 4 prizes 3N+1M, 17 NS 50%, played 11N+4M+2T)
      ] },
      Timestamp: { $gte: ISODate("2026-07-20T00:00:00.000Z"), $lte: ISODate("2026-08-09T23:59:59.000Z") },
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
