// FP-43631 week-12 -- Tournament-log trajectory dump query (SINGLE, run on all 3 Mongo PROD)
// =============================================================================
// One aggregate, run against each Mongo PROD instance separately. UserIds are
// globally unique (FP GUIDs) -- each platform's Mongo will return only its own
// candidates, the others silently match nothing. Window: 2026-07-06T00:00:00Z
// -> 2026-07-26T23:59:59Z (3 weeks: ~2 weeks pre-context + the week-12 window).
//
// 19 candidates total: Steam 7, PS 9, Xbox 3.
//
// Server-side filter on Message keeps only the event types the parser recognises
// (PCR ledger, played-confirmation, registration, process marker, CHEAT) -- the
// raw Fish/Score chatter is dropped before transport, which keeps the per-platform
// dump in the low-MB range instead of tens of MB.
//
// Each output row is "<UserId>\t<ISO timestamp>\t<verbatim Message>", sorted
// UserId ASC then Timestamp ASC so a per-UserId grep yields a chronological slice.
//
// Save each per-platform output to one .tsv inside `pcr-log-trajectories-2026-07-26/`:
//   steam-dump-2026-07-26.tsv  (7 candidates expected)
//   ps-dump-2026-07-26.tsv     (9 candidates expected)
//   xb-dump-2026-07-26.tsv     (3 candidates expected)

db.tournamentLog.aggregate([
  { $match: {
      UserId: { $in: [
        // ---- STEAM (7) ----
        "99247bde-f4cb-4698-8a5c-679550d9f369", // dreadloc             (NEW, 7N pure, 21 NS 48%, PCR 86, Life 11)
        "cb167d53-bd55-4228-8b44-f41a284e7c3e", // Albbert              (NEW, 7N pure, 20 NS 43%, PCR 127, Life 11, played 13N+13M)
        "b3440760-bbd6-4af0-b0ee-def6b131de62", // Zemaro               (**W11 WATCH conf 7 returning** -- rule 8(c): NS 52% -> 65%, Life 8 -> 13)
        "d1d22645-9ea5-4529-925d-b35e7a77db89", // VGB_N4rkos060905     (**W11 WATCH conf 6 as `n4rkos060905`, renamed** -- Support pre-actioned BanEnd 2026-08-07; 3rd rule-6 ladder validation)
        "135725a2-637f-44f3-8389-df61b85f4e67", // X1aoDouYa            (REPEAT stale BanEnd 2026-06-17; TOP-flavor 0N+5M+0, PCR 805 -- rule 7 dir 2 family)
        "eb4273ee-eb6a-488f-8ac7-6c40809e1229", // jackylu              (REPEAT BanEnd 2026-07-10 expired 16d ago; 4N pure, 15 NS 68%)
        "f80df54f-b077-4665-9822-a43414055b1e", // EsseDouble           (REPEAT stale BanEnd 2026-06-17; TOP-flavor 0N+4M+0, PCR 815, played 0/29/1 -- rule 7 dir 2 family)

        // ---- PS (9) ----
        "35ed0e4a-4acb-4072-b23a-10d5b5578fea", // vlad_spain           (**W11 WATCH conf 6 returning with MAJOR escalation** -- rule 8(b) 5N -> 11N prizes, rule 8(c) NS 19/59% -> 39/68%, Life 6 -> 18)
        "a79865b8-46c4-4bf1-86f5-b0b4d98d9bd2", // autoteo78            (NEW, TOP-flavor MASTERS 0N+8M+0, PCR 937 -- rule 7 dir 2 family)
        "ebc824ac-464e-4186-b896-a937a0599d6c", // HIflyfishingGH       (NEW, 8N pure, 16 NS 59%, PCR 126, Life 12)
        "e7a97daf-078e-4907-be9f-7504c1118c7c", // KondaFlk             (Support pre-actioned BanEnd 2026-08-08; 7N pure, **54 NS 88.5% EXTREME**, 5 DQs, PCR 48)
        "c896536d-28fa-4785-a85e-48c27b947590", // Panonski_Alas        (REPEAT stale BanEnd 2026-06-01; TOP-flavor MASTERS 0N+4M+2T, PCR 991, Life 80 -- **rule 7 dir 2 closure candidate, multi-cycle**)
        "74bf1938-4ff2-4263-b0c1-a9ffb4af77d1", // ThorUs422            (NEW, 5N pure, 34 NS 65%, PCR 88, Life 12)
        "d7b6151c-3905-4469-801d-9fc6b06fd87a", // La_Iena_River_       (**W11 WATCH conf 6 returning MODERATED** -- NS 42/84% -> 9/41%, PCR 140 -> 145; rule 6 call looks correct)
        "30f95ada-24fa-4fa1-8671-48f73d804156", // BOOMDATRUTH2         (NEW, 4N pure, 12 NS 30% at gate, PCR 127, Life 12)
        "5c6cca83-e3e1-4cc5-9cad-a53cb783507a", // Alien_Back           (NEW, 4N pure, 10 NS 30% at gate, **7 ZeroScore**, PCR 85, Life 7)

        // ---- XB (3) ----
        "ec371f4d-633e-45db-8b29-83de86c09dcb", // rascof molotov       (Support pre-actioned BanEnd 2026-08-25; 9N pure, LB Rank 1, 22 NS 71%, 3 DQs, PCR 38)
        "ff382a4e-f0c7-4dc4-a882-80f32276e095", // TurboBandz6351       (**W11 WATCH conf 6 returning with escalation** -- rule 8(c) NS 12/46% -> 24/52%, **ZeroScore 5 -> 9**, PCR 81 -> 22, net -140; rule 9 within-bracket signature strengthened)
        "08446c33-7b7f-41fc-af48-dbf8012f9ca3"  // COUNTRY3PER          (NEW, 3N+1M mixed, 10 NS 53%, LB Rank 11, PCR 54, Life 43)
      ] },
      Timestamp: { $gte: ISODate("2026-07-06T00:00:00.000Z"), $lte: ISODate("2026-07-26T23:59:59.000Z") },
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
