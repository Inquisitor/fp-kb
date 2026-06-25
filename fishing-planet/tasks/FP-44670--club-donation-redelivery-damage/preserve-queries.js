// =============================================================================
// FP-44478 - preserve club item/token transfer history from clubLog (MongoDB)
// =============================================================================
// WHY
//   Bait (and buoy) transfers have NO persistent ledger - clubLog is the only
//   record, and it is best-effort (unacknowledged writes). Worse, clubLog IS
//   actively purged: MongoAsyncProvider.DeleteOldMessages() deletes clubLog docs
//   older than 60 days whose IsImportant is false/absent. Donation receives are
//   logged unimportant, so the transfer lines are deleted ~60 days after writing
//   (confirmed: delivery data floors at run date - 60d on every platform). This
//   is a ROLLING DAILY loss - only the last 60 days ever exist. Snapshot now.
//   (Club tokens (CT) ALSO persist in the SQL `Stmt` table, Currency='CT', with
//   far longer retention - see the Stmt query at the tail; bait does not, so the
//   60-day clubLog slice is all the bait history there will ever be.)
//
// SCOPE
//   The actual transfer lines (given + received) for bait, club tokens, buoys.
//   Run per F2P platform Mongo (Steam/EGS, PS, Xbox, Mobile, Nintendo); logs DB,
//   collection clubLog. EXPORT each result to a durable file (JSON/BSON).
//
// NOTE
//   This is a `find` (not aggregate) so raw docs are preserved verbatim
//   (UserId, ClubId, Message, Timestamp, RequestId, _id). ~70k rows total across
//   platforms - small. Use mongoexport for a clean dump if preferred (see tail).
// =============================================================================

// --- P1: all club item/token transfer lines (export this to file, per platform) ---
db.clubLog.find(
  { Message: /^(Sent bait #|Received bait #|Sent ClubToken |Received ClubToken |Accepted .* on pond .* for request ')/ },
  { _id: 1, UserId: 1, ClubId: 1, Message: 1, Timestamp: 1, RequestId: 1 }
).sort({ Timestamp: 1 })

// --- P1b: sanity count before/after export (rows expected in the dump) ---
db.clubLog.countDocuments(
  { Message: /^(Sent bait #|Received bait #|Sent ClubToken |Received ClubToken |Accepted .* on pond .* for request ')/ }
)

// -----------------------------------------------------------------------------
// Preferred durable dump (shell, not this console) - one file per platform:
//
//   mongoexport --uri "<platform-mongo-uri>" --db main2 --collection clubLog \
//     --query '{ "Message": { "$regex": "^(Sent bait #|Received bait #|Sent ClubToken |Received ClubToken |Accepted .* on pond .* for request '\'')" } }' \
//     --out clubLog-transfers-<platform>-2026-06-24.json
//
// Keep the dumps off the live DB (task artifacts / cold storage).
// -----------------------------------------------------------------------------

// === Club-token cross-check / fuller history from the PERSISTENT ledger (SQL Stmt, Stats DB) ===
// Run on each platform's PROD STATS connection (not Mongo). Stmt has longer
// retention than clubLog, so it may show CT donation receipts further back than
// the clubLog window - and confirms the balance was actually credited.
//
//   SELECT UserId, COUNT(*) AS ctDonationReceipts,
//          MIN(Timestamp) AS firstTs, MAX(Timestamp) AS lastTs
//   FROM Stmt WITH (NOLOCK)
//   WHERE Currency = 'CT' AND Msg LIKE '%Receive donated ClubToken%'
//   GROUP BY UserId
//   HAVING COUNT(*) > 1
//   ORDER BY COUNT(*) DESC;
