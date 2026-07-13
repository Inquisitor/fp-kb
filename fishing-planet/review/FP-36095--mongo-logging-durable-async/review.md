---
status: resolved
executor: Yuriy Burda
branch: IMV20250220 @ r13997-r14026
jira: https://fishingplanet.atlassian.net/browse/FP-36095
---

# Review: FP-36095 — Server Logging: make Mongo logging durable and asynchronous

## Summary

Reworks user-log writing so a MongoDB outage does not take down the game farm. Instead of writing log records directly to Mongo (synchronously or via `BeginInvoke`), the server can be switched to write each log record synchronously to a local disk file via log4net, and a background process (`UserLogsToMongoSync`) tails those files and ships batches to Mongo asynchronously. Toggled per-application by the `UserLogs_SaveToFs_IsEnabled` app-setting; disabled by default (direct-to-Mongo `LogBase` path).

## Re-review context (trigger)

- **Production incident (today):** MongoDB on prod went down and the whole farm went down with it — exactly the failure mode this task was meant to eliminate ("збій Mongo призводить до збою ферми").
- Task was reviewed in-JIRA by Stanislav Samoilov (In Review 2025-04-07 → Resolved 2025-12-17). Reviewer flagged at closure: *"We have to check that this is disabled for now."* Reviewer recalls having seen problems during the original review that were not fully written up.
- No prior KB review card existed → new card. This KB review re-examines the design against today's incident.

## Scope

Commits per JIRA comments (face value; SVN audit in Investigation Journal). All on IMV20250220 (Code branch at the time; now OldStable). Inherited by the current Code/Content line via branch copy (to verify).

### IMV20250220
- **r13997** — Add file system loggers for user logs as replacement to default Mongo logging; add FS->Mongo synchronization; add settings (Mongo by default); remove Mongo `_id` fields from models
- **r13998** — Switch new project type from .NET Standard to .NET Framework (build-agent issue)
- **r13999** — Enable saving user logs to files for yellow dev (config)
- **r14001** — Enable saving user logs to files for yellow test and nx dev (config)
- **r14007** — Do not write duplicate user logs with default appenders (`Additivity=false`)
- **r14015** — `IgnoreExtraElementsConvention` in unit tests (fix `_id` deserialization failure)
- **r14026** — Use minimal lock model in log4net appender to allow deleting old log files

## Investigation Journal

- Executor field (`customfield_11224`) = Yuriy Burda — matches commit author. Hygiene OK.
- Branch identified as IMV from JIRA comment "(IMV)" markers; IMV was Code branch in April 2025 (now OldStable per `_index.md`).
- Feature code confirmed present in MFT WC by direct read (LogCollection, UserLogsToMongoSync, ServerUserLogParameters) — consistent with branch-copy inheritance from IMV.
- SVN audit: all 7 JIRA-listed commits confirmed on IMV20250220 via `svn log | grep`; no extra/missing commits. WC = MFT @ r16248; diffs read from repo (`svn diff -c`), so stale-WC risk N/A.
- r13997 diff of `LogBase.cs` = cosmetic only (`ToCollectionName` extraction). The direct-to-Mongo path (Unacknowledged insert, error-swallowing try/catch, `IsSyncLogging`, `LogAsync`->`AsyncInvoke`) is **pre-existing**, not introduced/changed here. So the disabled-path Mongo coupling is not a regression from this task.
- Prod config check: grep of `Config/prod/{Master,GameServer1,GameServer2,Club,Chat}` for `UserLogs_SaveToFs_IsEnabled` / `IsSyncLogging` → **no matches**. Key absent ⇒ `FromAppSettings()` returns Default ⇒ FS logging OFF in prod. Only yellowdev/yellowtest/nxdev enable it. This is the incident link and matches reviewer's closing note "check that this is disabled for now".
- Verified data-loss mechanics against `UserLogsToMongoStatus` (per-line `TrackPosition`, persisted every 5s) + `UserLogsToMongoBuffer.FlushBuffer` (TryRemove-then-throw): positions for lines in a failed batch are already tracked, so a failed flush skips them permanently on resume.
- Codex (gpt-5.5) independent review reconciled: confirmed F-1 (split into "prod on old path" + "disabled path stalls farm"), F-3, F-4, F-5, F-6. Corrected F-2 mechanism (flush throw is swallowed by the parse try/catch, position advances → continuous loss, task does not die on batch flush) — verified against `MonitorFile:311-325`. Added F-7 (buffer concurrency race), F-8 (half-config), F-9 (`ConvertToIsoDates` over-broad, verified), F-10 (filename parse). No disagreements; Codex found no reason to reject the disabled-path farm-down theory.
- Prod `noSql` connection strings are plain `mongodb://localhost/main` with no short server-selection/socket timeout overrides (Codex) → outage = block-until-driver-timeout on the calling/thread-pool thread. Reinforces F-1.
- Scope reframed by reviewer mid-review: goal is now to finish the implementation to production quality and enable it (not just assess). Findings F-2/F-7/F-9 become must-fix-before-enable; F-4/F-5/F-6/F-8/F-10 are harden/measure. Open design decision: synchronous log4net file write (measure) vs restore the spec's in-memory queue so the game thread never touches disk.

## Findings

### F-1: Durability fix is opt-in and OFF in production — default path still stalls the farm on a Mongo outage [High]

**Description:** The task's goal is that a Mongo outage must not take down the farm. The implementation delivers that **only** when `UserLogs_SaveToFs_IsEnabled=true`. Prod config templates do not set the key, so production runs the default direct-to-Mongo `LogBase` path. There, game-thread logging goes `Log`/`LogAsync` -> `LogInt` -> `Collection.Insert(..., WriteConcern.Unacknowledged)`; the try/catch swallows the eventual exception, but when Mongo is unreachable the legacy driver **blocks** (server-selection/connect/socket timeout) before throwing, stalling game-operation threads, and `LogAsync`'s `AsyncInvoke` fan-out can exhaust the thread pool. Consistent with today's prod farm-down. r13997 did not change this path (pre-existing exposure), but the ticket was resolved "Done" with the protection inactive in prod.

**Investigation:** Read `LogBase.cs`, `LogCollection` factory, `ServerUserLogParameters`; grep of prod configs (key absent); `svn diff -c 13997 LogBase.cs` (cosmetic only). Blocking-vs-throwing behavior of the legacy driver is the crux — verify against driver config (server-selection/connect timeouts) and confirm with Codex.

**Resolution:** Blocking / reopen-worthy — the central verdict. Options: (a) enable FS logging on prod (the intended fix) after clearing F-2/F-4; (b) otherwise decouple logging from Mongo availability (bounded non-blocking write, tight server-selection timeout, circuit-breaker). Needs a decision, not just a config flip.

**Discovered by:** skill recon + reviewer's incident context.

### F-2: Enabled-path sync silently and continuously drops records during a Mongo outage [High] (Codex: Critical)

**Description:** `UserLogsToMongoBuffer.FlushBuffer` does `TryRemove(buffer)` then `InsertBatch`, and on Mongo error logs "records lost" and `throw`s. Two loss mechanisms, both advancing past undelivered lines:
- **Batch-triggered flush (dominant):** the flush runs *inside* `AddDocument`, which in `MonitorFile` is wrapped by the line's parse try/catch (`UserLogsToMongoSync.cs:313-321`). The Mongo throw is swallowed as "Error parsing line", then execution falls through to `TrackPosition` (`:322`) — position advances even though the batch was discarded. The tailer does **not** die; it keeps reading and keeps losing every subsequent batch → **continuous silent loss** for the whole outage. (This corrects the initial hypothesis that the task dies once.)
- **EOF/timer flush (`:267`, `:325`):** these are outside the inner try, so they propagate to the outer catch and end the task; rescan restarts from the already-advanced persisted position → those lines skipped too.

Raw lines remain in the on-disk file (recoverable by resetting the `.LogSyncStatus.dat` position file), so "undelivered" rather than destroyed — but durability is broken exactly in the outage window it targets. Partial (non-atomic) `InsertBatch` success before the throw can also duplicate on resume (no stable `_id` — see F-9-adjacent). Currently latent (enabled only in test envs) but a hard blocker for any F-1 remediation that enables the feature in prod.

**Investigation:** Re-read `MonitorFile:311-325` — confirmed `AddDocument`/flush is inside the parse try/catch and `TrackPosition` runs unconditionally after it (Codex correction, verified against source). `FlushBuffer` TryRemove-then-throw; `UserLogsToMongoStatus` per-line track + 5s persist.

**Resolution:** Blocking for prod-enablement. Fix: track position only after a successful flush; on flush failure retain/re-queue the buffer and back off (bounded retry) instead of `throw`; make the read->insert a position-atomic unit; give documents a deterministic `_id` (e.g. hash of file+offset) for idempotent re-insert.

**Discovered by:** skill recon; mechanism corrected by Codex.

### F-7: Shared Mongo write-buffer has concurrency races (duplicate-add / add-during-remove) [Medium] (Codex: High)

**Description:** `UserLogsToMongoBuffer.AddDocument` mutates a `ConcurrentBag` inside the `updateValueFactory` of `ConcurrentDictionary.AddOrUpdate`. That delegate is not guaranteed to run once — under contention it can be invoked repeatedly and retried, so `list.Add(doc)` may add the same document more than once, and the `needFlush` flag is set from a possibly-retried delegate. Separately, `FlushBuffer`'s `TryRemove` can race a concurrent `AddDocument` on the same collection bag → records added to an already-removed bag are lost. Multiple `MonitorFile` tasks map to the same collection (e.g. rolling daily files of one channel), so concurrent access is real, not theoretical.

**Investigation:** Read `UserLogsToMongoBuffer.AddDocument`/`FlushBuffer`; confirmed multiple concurrent monitors can target one collection via `LogBase.ToCollectionName`. `AddOrUpdate` non-atomic-delegate semantics are documented BCL behavior.

**Resolution:** Blocking for prod-enablement. Fix: use a proper per-collection lock or a single-writer queue; do not mutate shared state inside `AddOrUpdate` delegates; make flush swap the buffer atomically.

**Discovered by:** Codex.

### F-9: `ConvertToIsoDates` coerces arbitrary string fields to dates; Kind not robust-UTC [Medium]

**Description:** `MongoDbHelper.ConvertToIsoDates` walks every element and converts *any* string matching `yyyy-MM-ddTHH:mm:ss.FFFFFFFZ` into a `BsonDateTime` — not just the `Timestamp` field. A user `Message` (or any field) that happens to match ISO-8601-with-Z is silently stored as a date, causing type drift versus the direct-to-Mongo path (which serializes typed models). Also parses the literal `Z` with `DateTimeStyles.None`, yielding `DateTime.Kind = Unspecified` rather than `Utc`, risking offset/kind inconsistencies. This makes file-path documents not byte-equivalent to legacy Mongo-path documents for the same event.

**Investigation:** Read `MongoDbHelper.ConvertToIsoDates` (`:33-60`) — confirmed it applies to all string elements and recurses into arrays/subdocuments; `DateTimeStyles.None` + literal `Z`.

**Resolution:** Filed / fix before enable — restrict conversion to known date fields (or use `AdjustToUniversal|AssumeUniversal` and `Kind=Utc`); align the file-path schema with the Mongo-path schema so historical queries stay consistent.

**Discovered by:** Codex, verified.

### F-8: One-time log4net setup can permanently half-configure on a mid-way throw [Low]

**Description:** `LogCollection.ConfigureLog4Net` sets `log4NetConfigured = true` *before* building the appenders. If any `ActivateOptions()`/appender step throws mid-loop, the flag is already latched, so every future call returns early without repairing configuration — leaving some channels without their file appender for the process lifetime.

**Investigation:** Read `ConfigureLog4Net:139-208` — flag set at `:148`, appender loop after.

**Resolution:** Accepted / minor — set the latch only after the loop completes; wrap in try and reset on failure.

**Discovered by:** Codex.

### F-10: Log-file channel-name parsing is fragile [Low]

**Description:** `MonitorFile` derives the channel via `LastIndexOf('.')` for the start but `IndexOf('-')` from the *beginning* of the filename. A hyphen anywhere before the channel token (e.g. in a server name) or an active file lacking the expected `-yyyyMMdd` suffix mis-parses and the file is dropped from sync.

**Investigation:** Read `MonitorFile:237-245`; filename pattern `{ServerName}.{channel}-{date}.log`.

**Resolution:** Accepted / harden — parse channel from the segment between the last `.` and the date suffix explicitly; validate before dropping.

**Discovered by:** Codex.

### F-3: FileLogBase throttling counters race under concurrent logging (condition itself is OK) [Low]

**Description:** `if (loggingFailsSkipped < loggingFailsLogged)` looks inverted but actually yields an increasing-skip backoff (logs the 1st, 3rd, 6th, 10th... error) — matches the comment, not a bug (corrects an earlier KB mapping-draft claim). However `loggingFailsTotal/Logged/Skipped` are plain non-volatile `int`s incremented with `++` from multiple game threads sharing one FileLog instance → data race. Only skews error-log frequency; the actual writes are serialized by log4net MinimalLock, so no log corruption.

**Investigation:** Hand-traced the counter state machine across successive failures; file inspection of `FileLogBase`.

**Resolution:** Accepted / minor — optionally `Interlocked` the counters. Not blocking.

**Discovered by:** KB mapping-draft (FP-43424) flag, re-verified and downgraded here.

### F-4: Fragile reflection into private StreamReader fields for byte-position tracking [Medium]

**Description:** `StreamReaderExtensions.GetActualPosition` reflects private `StreamReader.charPos/charLen/charBuffer` to compute the true byte offset. This is why r13998 pinned the project to .NET Framework (couldn't cleanly target .NET Standard/Core). Any framework/runtime upgrade that renames or restructures those fields silently breaks position accuracy → data loss or re-processing, with no compile-time signal.

**Investigation:** Read `GetActualPosition`; correlated with r13998 commit ("Switch project type from .NET Standard to .NET Framework... something wrong on build agent").

**Resolution:** Filed / tech-debt — document the framework pin as load-bearing; long-term, track position by counting encoded bytes of each read line instead of reflecting reader internals.

**Discovered by:** skill recon.

### F-5: MinimalLock open/close per log line under high fishing-log volume [Low-Medium]

**Description:** r14026 set the appender to `FileAppender.MinimalLock`, which opens and closes the file for every write, specifically to allow the sync to delete old files. fishingLog is very chatty (per cast/bite/fish). Open/close-per-line I/O may materially raise logging cost; must be load-measured before enabling in prod.

**Investigation:** `LogCollection.ConfigureLog4Net`; r14026 commit rationale.

**Resolution:** Accepted with caveat — measure under production-like load as part of F-1 enablement.

**Discovered by:** skill recon.

### F-6: Unbounded disk growth during an extended Mongo outage [Low-Medium]

**Description:** Rolling files cap at 10 GB each; `DeleteLogFileInterval` (2 days) deletes a file only after it stops being written to. During a Mongo outage the sync stalls but the game keeps appending, so files are not deleted and grow; combined with F-2 the tail is also undelivered. A long outage risks disk pressure on top of log loss.

**Investigation:** `MonitorFile` delete gate (last-write-time based); `ConfigureLog4Net` MaxFileSize.

**Resolution:** Accepted / note — bound total log-dir size or alert on sync lag.

**Discovered by:** skill recon.

## Notes

- **Spec vs implementation gap (Info):** the ticket asked for an in-memory queue, configurable worker-thread count, Performance Counters, and explicit Mongo-unavailability detection with pause. The delivered design is a log4net file writer + single-tailer-per-file background sync — the executor deliberately dropped the in-memory cache (justified in JIRA), but the worker-count config, perf counters, and detect-and-pause were not implemented. The ticket was resolved as if complete.
- **`_id` removal (Info):** r13997's "remove Mongo `_id` from models" broke unit-test deserialization, fixed in r14015 by registering a global `IgnoreExtraElementsConvention` in test assemblies — broad; silently ignores schema drift in tests.

## Scope boundary — Mongo is in the critical path beyond logging

Logging is only one of several Mongo-coupled subsystems on the game hot path. Enabling FS logging is **necessary but not sufficient** to survive a Mongo outage: even with logs off Mongo, an outage still takes down the base because session/SSO state lives in Mongo.

- **Sessions / crude SSO — collection `oc`** ("online cache", frequently mis-typed "online cash"): `Dal\NoSql.Mongo\OnlineCash\MongoOnlineCash.cs` (`IOnlineCash`, `OnlineUser`), routed via `OnlineCacheAdaper.cs` (sic), consumed in `MasterAuthenticator`/`GameAuthenticator` — i.e. Mongo is hit on the auth/session path. A Mongo outage here breaks login/session directly.
- **Player IPs** and **diagnostic data** are also written to Mongo.

This is **out of scope for FP-36095** (which is specifically the user-log path). It is captured here as the boundary and seeds a broader effort: an **epic to remove Mongo from the critical path** — keep Mongo for logs (the log DAL is already swap-able) for now, decouple sessions/IP/diagnostics, and possibly replace Mongo later. Broad-Mongo items go to the server module backlog; this review stays focused on the log path.

**Adjacent follow-up direction (logging subsystem):** logs are currently emitted by direct DAL calls writing mostly raw **strings** (rarely structured document fields). A cleaner target is a routing logger with **structured** records. Noted as a follow-up, not part of FP-36095 remediation.

## Follow-ups filed

- **Epic FP-44798** — "Remove Mongo from the critical path" (stub). Two strategies per subsystem: remove data from Mongo (e.g. `oc` sessions) or buffer through files (e.g. logs). FP-36095 linked `Relates`.
- **FP-44799** (Story, parent FP-44798) — Productionize the file-based user-log → Mongo pipeline. Carries the remediation: F-2, F-7, F-9 (must-fix), F-4, F-5, F-6, F-8, F-10 (harden/measure), hot-path decision, enable + canary rollout.
- **FP-44800** (Story, parent FP-44798, Relates FP-44799) — Structured user logs via a routing logger (replace direct-DAL string logging).
- Broad Mongo-critical-path seeds (sessions/`oc`, player IP, diagnostics, full logging-subsystem review) added to `<kb>/fishing-planet/server/backlog.md` under the epic.

Decision (reviewer): FP-36095 stays Resolved — it delivered the opt-in mechanism; it is **not** reopened. Remediation lives in FP-44799. Prod enablement is deferred until the rework lands (confirmed: will not enable as-is).

## Verdict

FP-36095 does not deliver its stated goal in production and is not being reopened — completion is tracked under epic FP-44798 (FP-44799). Prod runs the default direct-to-Mongo path, so a Mongo outage stalls/starves the game threads (F-1) — the incident that triggered this re-review. The enabled path (the intended fix) is not yet production-safe: continuous silent log loss during exactly a Mongo outage (F-2), buffer concurrency races (F-7), and schema/round-trip drift (F-9) are must-fix before enabling; reflection-based positioning (F-4), MinimalLock write cost (F-5), unbounded disk growth (F-6), half-config-on-throw (F-8), and fragile filename parsing (F-10) are harden/measure items. Independent Codex review concurs (rated F-2/F-7 higher).

Remediation path (to be turned into a plan):
1. Decide the hot-path model — synchronous log4net file write (measure under fishingLog load) vs restore the spec's in-memory queue so the game thread never blocks on disk.
2. Make the sync at-least-once and idempotent (deterministic `_id`, position-after-flush, retain buffer + bounded retry on failure) — closes F-2/F-7 and the duplicate risk.
3. Harden delivery/robustness: F-9 schema alignment, F-4 byte-count positioning, F-6 disk cap/alert, F-8/F-10.
4. Enablement + rollout: add the config keys to prod templates, canary on one game server (compare op-processing metrics), then farm-wide; add the un-shipped ticket asks (perf counters / Mongo-down detection) as needed for observability.
