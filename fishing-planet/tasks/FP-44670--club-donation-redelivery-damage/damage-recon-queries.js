// =============================================================================
// FP-44478 - club donation re-delivery: damage recon (MongoDB)
// =============================================================================
// WHAT THIS MEASURES
//   The bug re-delivers a club donation (bait / club token) on rejoin when the
//   dedup record is purged early. Each successful (re-)delivery writes ONE log
//   line to clubLog. A re-delivery produces a BYTE-IDENTICAL line (same itemId,
//   count, requestId GUID, donor) - only Timestamp differs. So:
//       duplicate = identical (UserId, Message) appearing >1 time.
//   surplus per donation = (occurrences - 1).
//
// SCOPE
//   Run on each F2P prod Mongo, in team platform order:
//     Steam/EGS, PlayStation, Xbox, Mobile, Nintendo.
//   Retail is excluded (not patched, separate economy).
//   Select the logs database first: PROD = "main2" (NOT "main" - main is empty on
//   prod); local-dev copy = "main". Collection = clubLog.
//   Prod Mongo is 4.4 - $split / $regex / allowDiskUse all available.
//
// RETENTION CAVEAT
//   clubLog IS actively pruned: MongoAsyncProvider.DeleteOldMessages() deletes
//   unimportant clubLog rows older than 60 days. Donation transfers are logged
//   unimportant, so delivery data floors at ~60 days. Every number below is a
//   LOWER BOUND
//   over whatever window still survives - run Q1 first to see the real span.
//
// PERFORMANCE
//   The Message filter is a regex => full collection scan (Message is not
//   indexed). On a busy platform this is heavy and may time out; run queries
//   one at a time. If needed, narrow by adding a Timestamp lower bound to the
//   first $match, e.g. Timestamp: { $gte: new Date("2025-01-01") }.
// =============================================================================


// --- Q1: clubLog window + size (run FIRST - reveals real retention span) ---
db.clubLog.aggregate([
  { $group: { _id: null,
      minTs:     { $min: "$Timestamp" },
      maxTs:     { $max: "$Timestamp" },
      totalDocs: { $sum: 1 } } }
], { allowDiskUse: true })


// --- Q1b: count of delivery lines (cheap sizing of the regex scan) ---
db.clubLog.countDocuments({ Message: /^Received bait #|^Received ClubToken / })


// --- Q2: HEADLINE - re-delivered bait/token donations, surplus, affected users ---
db.clubLog.aggregate([
  { $match: { Message: /^Received bait #|^Received ClubToken / } },
  { $group: { _id: { u: "$UserId", m: "$Message" }, n: { $sum: 1 } } },
  { $match: { n: { $gt: 1 } } },
  { $group: { _id: null,
      affectedDonations: { $sum: 1 },
      surplusDeliveries: { $sum: { $subtract: ["$n", 1] } },
      users:             { $addToSet: "$_id.u" } } },
  { $project: { _id: 0, affectedDonations: 1, surplusDeliveries: 1,
      affectedUsers: { $size: "$users" } } }
], { allowDiskUse: true })


// --- Q3: DETAIL EXPORT - one row per re-delivered donation (export to CSV) ---
//      Message holds "#<itemId> count <count>" (bait) or "count <count>" (token);
//      surplus items for a row = count * surplus. Parse offline for per-item totals.
db.clubLog.aggregate([
  { $match: { Message: /^Received bait #|^Received ClubToken / } },
  { $group: { _id: { u: "$UserId", m: "$Message" },
      n:     { $sum: 1 },
      first: { $min: "$Timestamp" },
      last:  { $max: "$Timestamp" } } },
  { $match: { n: { $gt: 1 } } },
  { $project: { _id: 0, UserId: "$_id.u", Message: "$_id.m",
      surplus: { $subtract: ["$n", 1] }, deliveries: "$n", first: 1, last: 1 } },
  { $sort: { deliveries: -1 } }
], { allowDiskUse: true })


// --- Q4: CROSS-CHECK by event type - universal accept line (bait+token+buoy) ---
//      Every delivery also writes "Accepted event Type=<Type>, InstanceId='...'".
//      *Response types are the auto re-deliveries that matter; *Request types
//      would indicate sender/manual re-accepts. Confirms Q2 and surfaces buoy.
db.clubLog.aggregate([
  { $match: { Message: /^Accepted event Type=/ } },
  { $group: { _id: { u: "$UserId", m: "$Message" }, n: { $sum: 1 } } },
  { $match: { n: { $gt: 1 } } },
  { $project: {
      type: { $arrayElemAt: [
        { $split: [ { $arrayElemAt: [ { $split: ["$_id.m", ","] }, 0 ] }, "=" ] }, 1 ] },
      surplus: { $subtract: ["$n", 1] } } },
  { $group: { _id: "$type", affectedEvents: { $sum: 1 }, surplus: { $sum: "$surplus" } } },
  { $sort: { surplus: -1 } }
], { allowDiskUse: true })
