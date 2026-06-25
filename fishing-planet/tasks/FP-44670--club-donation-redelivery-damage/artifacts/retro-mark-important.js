// =============================================================================
// FP-44478 - retro-mark club transfer lines IsImportant=true (stop the bleeding)
// =============================================================================
// MongoAsyncProvider.DeleteOldMessages() deletes clubLog docs older than 60 days
// whose IsImportant is false/absent. Donation transfers are logged unimportant,
// so they roll off daily. Setting IsImportant=true makes the cleaner skip them.
//
// RUN ORDER: this FIRST (before the mongodump backup, before the 01:01 cleaner),
// per F2P prod Mongo (Steam/EGS, PS, Xbox, Mobile, Nintendo). Prod DB = main2
// (NOT main - main is empty on prod). Prod WRITE.
// Verify step (3) == 0 BEFORE running the backup - don't snapshot a bad state.
//
// SCOPE: value transfers only (bait + token + buoy send/receive/accept). Other
// clubLog rows and chatLog keep rolling at 60 days (preserved in the backup).
//
// RE-RUN: protects only rows that exist now (<=60 days). New transfer rows are
// written unimportant until the code fix ships - re-run before the newest
// unprotected rows age past 60 days.
//
// _id is not touched (its ObjectId insert-timestamp is preserved).
// =============================================================================

const transferRegex = /^(Sent bait #|Received bait #|Sent ClubToken |Received ClubToken |Sent buoy |Accepted .* on pond .* for request ')/;

// 1) BEFORE - how many transfer rows are still unprotected (record per platform)
db.clubLog.countDocuments({ Message: transferRegex, IsImportant: { $ne: true } })

// 2) PROTECT them
db.clubLog.updateMany(
  { Message: transferRegex, IsImportant: { $ne: true } },
  { $set: { IsImportant: true } }
)

// 3) AFTER - must be 0 unprotected transfer rows (gate before the backup)
db.clubLog.countDocuments({ Message: transferRegex, IsImportant: { $ne: true } })
