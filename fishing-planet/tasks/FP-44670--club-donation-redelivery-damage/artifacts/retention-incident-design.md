# FP-44478 — club-transfer log retention incident: design

## Problem

`AsyncProcessor` job `LogClearingJob` (daily 01:01) calls `MongoAsyncProvider.DeleteOldMessages()`, which
deletes `clubLog` docs older than `ClubLogStoreHorizon = 60 days` **when `IsImportant` is false or absent**.
Club donation transfers (`Received/Sent bait`, `Received/Sent ClubToken`, buoy send/accept) are logged via
`UserLog(msg, isImportant: false)`, so every transfer record is purged ~60 days after it is written, on a
rolling daily basis. Bait and buoy transfers have **no other persistent ledger** (club tokens also persist
in SQL `Stmt`, `Currency='CT'`; bait/buoy do not), so once a `clubLog` line ages past 60 days the transfer
is gone for good. This is the only record of player-to-player item movement.

## Goals

- Preserve the surviving (≤60-day) club transfer records before further loss.
- Stop the ongoing rolling deletion of transfer records without a game-server release.
- Make future transfer records survive the cleaner permanently.

## Non-goals

- `chatLog` retention. The cleaner also deletes `chatLog` >60 days (it merely shares the same 60-day
  variable; no `IsImportant` filter), but that is unrelated to FP-44478 transfers and out of scope here.
  (The original "chat history loss" symptom was the in-memory `ChatChannel` ordering bug, already fixed.)
- Recovering pre-window history — it is already deleted and unrecoverable.
- Remediating the re-deliveries themselves — the dupers are anti-cheat-flagged bot accounts (see
  `damage-recon/account-vetting.md`); broad remediation is not pursued here.

## Scope — what counts as a "transfer line"

All value transfers (bait + token + buoy), matched by `Message` prefix:

```
^(Sent bait #|Received bait #|Sent ClubToken |Received ClubToken |Sent buoy |Accepted .* on pond .* for request ')
```

Requests (`Requested …`) and declines are excluded — no value moves.

## Workstreams (in order of irreversibility)

### A. Backup `clubLog` (immediate insurance)

`mongodump` the whole `clubLog` collection on each of the five F2P prod Mongo (Steam/EGS, PS, Xbox, Mobile,
Nintendo) to off-DB cold storage, BSON. Full fidelity including `_id` (an `ObjectId` whose first 4 bytes are
the insert time — an immutable second-granularity timestamp independent of the app-set `Timestamp` field).
Run before tonight's 01:01 cleaner. After this, nothing else is time-critical.

### B. Stop further loss — retro-mark `IsImportant=true` (zero-deploy)

`updateMany` on each prod Mongo, setting `IsImportant: true` on all transfer lines (scope regex above). The
cleaner only deletes `IsImportant` false/absent, so marked rows are skipped. `_id` is untouched. This is a
prod write — handed to the user to run per platform.

**Caveat:** protects only the rows that exist now (≤60 days). New transfer lines are still written
`IsImportant: false` until workstream C ships, so if C is not deployed within ~60 days, re-run this
`updateMany` before the newest unprotected rows age out.

### C. Forward code fix (next game-server release)

Add `isImportant: true` to the transfer `UserLog(...)` calls in SharedLib so future transfer records are born
important and survive the cleaner. Sites:

- `Shared/SharedLib/Clubs/ClubAdapter_ClubTokens.cs` — `Sent ClubToken`, `Received ClubToken`
- `Shared/SharedLib/Clubs/ClubAdapter_BaitsBuoysFishing.cs` — `Sent bait`, `Received bait`, `Sent buoy`,
  buoy accept (`Accepted {buoy} … on pond …`)

Each uses the `UserLog(string message, bool isImportant = false)` overload → pass `isImportant: true`. This
is a SharedLib change (runs on game servers) → ships in the normal server release, not instantly; it closes
the forward gap that B patches temporarily.

## Sequencing & ownership

1. **B — retro-mark** (user runs `updateMany` ×5) — FIRST, before 01:01; protects live rows from tonight's
   cleaner immediately.
2. **Verify B** (after-count of unprotected transfer rows == 0) — gate before backing up; if not clean, stop
   and investigate rather than snapshot a bad state.
3. **A — backup** (user runs `mongodump` ×5) — after B, before 01:01; the dump then captures the already-marked
   (protected) state. (Backup-after-mutate is acceptable here only because B is a content-free, reversible
   boolean flip — all transfer rows were originally `IsImportant=false`, so there is nothing to recover.)
4. **C — code fix** (dev change + normal release) — permanent; removes the need to re-run B.

A and B are prod operations the user executes (read/ write handoff per DB-access rules). C is a code change.

## Verification

- A: dump row count per platform == `db.clubLog.countDocuments({})` (or the transfer subset) at dump time.
- B: `countDocuments({ Message: <regex>, IsImportant: { $ne: true } })` == 0 after the update; and
  `countDocuments({ Message: <regex>, IsImportant: true })` == the pre-update transfer count.
- C: after release, a fresh donation writes a `clubLog` row with `IsImportant: true` (spot-check), and it
  survives a `-clear-logs` dry run on a non-prod environment.

## Risks

- Prod writes (B) — scoped by an anchored regex on `Message`; only sets one boolean; `_id`/content untouched.
- ObjectId `_id` time is second-granularity — fine as an immutable cross-check, not as the primary
  equal-millisecond ordering key.
- If C slips past 60 days without a re-run of B, newly written transfers resume being purged.
