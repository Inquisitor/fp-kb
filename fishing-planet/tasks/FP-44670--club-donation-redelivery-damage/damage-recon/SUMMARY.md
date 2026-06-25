# FP-44478 damage recon — prod results (cross-validated)

Source: `damage-recon/<platform>/q{1,1b,2,3,4}.json`, run on F2P prod Mongo 2026-06-24.

## Validation (why the numbers are trusted, despite fast queries)

Queries ran in seconds because `clubLog` is moderate (0.17M–1.77M docs), not because they scanned nothing —
Q1b confirms the delivery-line regex matches real data on every platform. Two *independent* log-line
signatures agree **exactly** on every platform:

- Q2/Q3 group `Received bait #…` / `Received ClubToken …` lines.
- Q4 groups the unrelated `Accepted event Type=…` line.
- Per platform: Q2.affectedDonations == Σ Q4.affectedEvents, Q2.surplusDeliveries == Σ Q4.surplus,
  Q3 rows == Q2.affectedDonations. All five match to the unit.

## Per-platform (within surviving retention window)

| Platform  | clubLog docs | retention from | delivery lines | affected donations | affected users | surplus total | bait items | tokens (CT) |
|-----------|-------------:|----------------|---------------:|-------------------:|---------------:|--------------:|-----------:|------------:|
| Steam     |    1,767,682 | 2025-06-18     |         43,663 |                835 |            151 |        24,032 |      7,912 |      16,120 |
| PS        |      869,188 | 2025-08-14     |         12,591 |                489 |             78 |         3,012 |      1,922 |       1,090 |
| Xbox      |      438,279 | 2025-08-19     |          4,634 |                 98 |             27 |           342 |        251 |          91 |
| Mobile    |      704,495 | 2025-09-23     |          6,316 |                425 |             89 |         2,143 |      2,143 |           0 |
| Nintendo  |      174,372 | 2025-11-26     |          2,187 |                143 |             39 |           344 |        341 |           3 |
| **Total** |              |                |     **69,391** |          **1,990** |        **384** |    **29,873** | **12,569** |  **17,304** |

(surplus = extra deliveries beyond the one legit delivery; affected users do not overlap across platform DBs.)

## Key finding — concentration, not breadth

The headline surplus is dominated by a handful of "relogin-loop" accounts, not broad player impact:

- **Steam top-2 accounts = 89% of Steam surplus** (`f139316b…` 13,527; `3b2ea48c…` 7,860).
- **~93% of ALL token surplus = those same 2 Steam accounts** (8,342 + 7,744 = 16,086 of 17,304 CT).
- Those accounts each received 83–110 *distinct* donations, each re-delivered ~120× over a few days
  (top single donation: 327 deliveries in 6 days) — a reconnect/relogin loop, not normal play.
- The remaining ~380 accounts (the tail) got single-digit extra baits each.

## Caveats / open

- **This is a 60-DAY snapshot, not 7–12 months.** `MongoAsyncProvider.DeleteOldMessages()` deletes `clubLog`
  docs older than `ClubLogStoreHorizon = 60 days` **when `IsImportant` is false/absent**. Donation receives
  (`Received bait #…` / `Received ClubToken …`, via `UserLog(msg, isImportant: false)`) are unimportant, so
  every delivery line is purged ~60 days after it is written. Confirmed empirically: `min(first)` across the
  delivery data is 2026-04-25 on every platform (= run date − 60d). The "retention from" column in the table
  above is the `clubLog` overall `minTs` — those are surviving *important* messages (club create/disband,
  roles, kick/leave, logo, "Reset ClubTokens"), NOT the damage window. So the per-platform surplus figures
  are only the **last ~60 days** of a bug live since r10273 (2023-04-27); the multi-year total is gone and
  unrecoverable from `clubLog`. Bait is purged on a rolling daily basis — every day loses the oldest day.
- **Tokens are recoverable; bait is not.** Club-token receipts also persist in SQL `Stmt` (Stats DB,
  `Currency='CT'`), which has far longer retention — so the *full* token history can be reconstructed from
  `Stmt`. Bait/buoy have no second ledger; `clubLog`'s 60-day window is all that exists.
- **Outlier accounts checked** — see [account-vetting.md](account-vetting.md). The token dupers are a few
  relogin-loop / farming accounts (one known to have farmed 230k+ tokens via this exploit); the basis is their
  re-delivery behaviour, NOT the FP anti-cheat (noisy, not relied on). Real legit-player damage is far below
  the raw 60-day surplus.

## Next

1. Preserve the current 60-day `clubLog` transfer slice now (rolling daily loss) — `../preserve-queries.js` P1.
2. Reconstruct full token (CT) history/damage from SQL `Stmt` (longer retention) — `../preserve-queries.js` tail.
3. Bait: accept that only the last ~60 days is knowable; the multi-year total is unrecoverable.
4. Remediation: token inflation sits in already-flagged bot accounts; broad legit-player action likely unwarranted.
5. (Forward fix, separate ticket) mark donation log lines `IsImportant=true` or add a real item-transfer ledger,
   so value transfers stop being thrown away at 60 days.
