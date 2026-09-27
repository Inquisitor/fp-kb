// FP-43631 week-20 -- Trajectory dump, REMAINDER of the cohort (10 candidates)
// =============================================================================
// The 6 deadline candidates are in `pcr-trajectory-queries-2026-09-20.js` and already in trial.
// These 10 carry no payout deadline: none is inside the paying top 10 on the weekly Won board,
// and none can reach it from our own bans (checked with the production ranking -- DENSE_RANK over
// CompetitionsWon DESC, CompetitionsWonTs ASC, CompetitionsWonExp DESC, banned rows excluded
// before ranking). The weekly Rating board is not a route for this vector at all: it pays for
// rating GAINED and the offence consists of shedding it.
//
// Excluded from the cohort of 18: AppL33 (Steam) and bold_blade409 (PS) are currently
// competition-banned, so there is nothing to apply.
//
// Window: 2026-09-07T00:00:00Z -> 2026-09-20T23:59:59Z. Sweep week 09-14..09-20, the week before
// is pre-context.
//
// Save into `pcr-log-trajectories-2026-09-20/`:
//   steam-dump-rest-2026-09-20.tsv      (4 candidates)   + steam-presence-rest-2026-09-20.tsv
//   ps-dump-rest-2026-09-20.tsv         (3 candidates)   + ps-presence-rest-2026-09-20.tsv
//   xb-dump-rest-2026-09-20.tsv         (3 candidates)   + xb-presence-rest-2026-09-20.tsv

db.tournamentLog.aggregate([
  { $match: {
      UserId: { $in: [
        // ---- STEAM DB (4) ----
        "67831814-56c8-47ac-bbe2-882dc339072a", // kojldyn          (board place 28, 2 wins. 25 unproductive of 42 at 60%, -370, net -119, plays 17 NOOBS / 1 MIDDLES, cashes 7/0/0, current PCR 0)
        "daa00f0b-2ba8-49a5-8be2-9880d6c856e3", // MP_Alan          (board place 77. 23 unproductive of 59 at 39%, net -97, plays 0/34/4, cashes 0/5/0, max rating at start 1009 -- reaches TOPS)
        "6b94e751-0d2f-40b0-81ea-fb7c9da0fd14", // Iron.Claw        (board place 57. 21 unproductive of 36 at 58%, -323, plays 14 NOOBS / 1 MIDDLES, cashes 4/0/0)
        "76dc3e6b-4bea-47ed-83a4-d0649d605ff9", // JoeCoviDodo      (board place 13 with 3 wins -- rises only to 11 if both Steam candidates above him are banned, so outside the money, but inside the 10+N risk zone and dumped for that reason)

        // ---- PS DB (3) ----
        "3c88816f-250b-44fd-9ab3-2d41ddf24d0a", // EZ-Enlightened1  (board place 132 by rating / 133 by wins. 16 unproductive of 42 at 38%, plays 0/0/26, cashes 0/0/4, current PCR 2145 -- entirely TOPS, lifetime 268/232/216)
        "54ea8084-5546-4ea8-8068-4c1fdbe77d4a", // Bas_di08         (board place 331 by rating / 125 by wins. 14 unproductive of 30 at 47%, plays 0/13/3, cashes 0/4/0, max rating at start 1032)
        "8451ec2f-001f-4697-94c3-0ae532d942ed", // flacheman2       (no wins at all this period. 9 unproductive of 28 at 32%, plays 5 NOOBS / 17 MIDDLES, cashes 3/1/0)

        // ---- XBOX DB (3) ----
        "bdd6d57e-e41f-475e-b067-c0d990a5a92c", // xFenrir77        (**REPEAT** -- competition ban expired 2026-06-01. 7th on the weekly RATING board with 338 against a cutoff of 308, i.e. in the money there. But plays and cashes entirely in TOPS: 0/0/31 and 0/0/8, current PCR 3212, so there is no bracket below him to be displaced into and limb 1(b) is likely unreachable. Judged for completeness and because of the prior ban)
        "03de1972-344f-4eef-935a-7574f652320d", // M4M Ovi          (board place 23. 18 unproductive of 33 at 55%, plays 0/0/15, cashes 0/0/4, current PCR 6694 -- entirely TOPS)
        "013368d1-e8a8-437a-88b0-71059e3287eb"  // BuzzingLemur417  (**REPEAT** -- ban expired 2026-07-20. 14 unproductive of 31 at 45%, plays 6 NOOBS / 12 MIDDLES, cashes 2/2/0)
      ] },
      Timestamp: { $gte: ISODate("2026-09-07T00:00:00.000Z"), $lte: ISODate("2026-09-20T23:59:59.000Z") },
      Message: { $regex: "^(Tournament reward Competition|Player started scoring time for Competition|Player registered for Competition|Player unregistered from Competition|Registration for tournament Competition|FAILED: Register in competition|About to process tournament Competition|CHEAT:)" }
  } },
  { $sort: { UserId: 1, Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [
      "$UserId", "\t", { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }, "\t", "$Message"
  ] } } }
]);

// ---- Companion A: all-line timestamps, for presence_gaps ----
db.tournamentLog.aggregate([
  { $match: {
      UserId: { $in: [
        "67831814-56c8-47ac-bbe2-882dc339072a", "daa00f0b-2ba8-49a5-8be2-9880d6c856e3",
        "6b94e751-0d2f-40b0-81ea-fb7c9da0fd14", "76dc3e6b-4bea-47ed-83a4-d0649d605ff9",
        "3c88816f-250b-44fd-9ab3-2d41ddf24d0a", "54ea8084-5546-4ea8-8068-4c1fdbe77d4a",
        "8451ec2f-001f-4697-94c3-0ae532d942ed", "bdd6d57e-e41f-475e-b067-c0d990a5a92c",
        "03de1972-344f-4eef-935a-7574f652320d", "013368d1-e8a8-437a-88b0-71059e3287eb"
      ] },
      Timestamp: { $gte: ISODate("2026-09-07T00:00:00.000Z"), $lte: ISODate("2026-09-20T23:59:59.000Z") }
  } },
  { $sort: { UserId: 1, Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [
      "$UserId", "\t", { $dateToString: { format: "%Y-%m-%dT%H:%M:%SZ", date: "$Timestamp" } }
  ] } } }
]);
