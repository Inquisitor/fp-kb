---
name: Mongo log semantics — stateful vs event before cloning Find
description: Before reusing or copying a Mongo log provider's Find(userId, from, to) method, check whether the log records stateful snapshots or an event stream — the date-range semantics differ
type: feedback
---
Before cloning a `Find(userId, from, to)` method between Mongo log providers, verify whether the log records stateful snapshots (configuration state active from record-time onwards) or an event stream (each record an independent occurrence). The two require different date-range semantics.

**Why:** Reflex-copying `Find(userId, start, end)` from `MongoErrorProvider` (event-stream) onto e.g. `MongoSysInfoProvider` (stateful-snapshot) returns *empty* for a user whose only SysInfo record predates `start` — wrong by reflex, not just inefficient. Same trap for `diagIpLog` / `diagMacLog` (also stateful). Caught in FP-43579 VS1 smoke after the first impl shipped.

**How to apply:**

1. Identify what each record represents:
   - **Event stream** (errors, fishing actions, chat messages): each record is an independent occurrence. `Find(userId, from, to)` = records with `Timestamp ∈ [from, to]`. Records outside the range are not relevant.
   - **Stateful snapshot** (sys info, IP changes, MAC changes, license state): each record is the state that became active at `Timestamp` and remains active until the next record. `Find(userId, from, to)` over a range needs the latest record with `Timestamp ≤ from` (carry-over of active state at range start) PLUS records with `Timestamp ∈ (from, to]` (changes during the range).
2. If unsure: read the call-site that *consumes* the result — does it want a list of events or a state-over-time? The data shape betrays the semantics.
3. Name the carry-over variant explicitly: `FindActiveDuring(userId, from, to)` (FP-43579 convention) — distinguishes it from event-stream `Find` at the call site.

**Known semantics in FP server:**

- Event stream: `fishingLog`, `diagErrLog`, `chatLog`, `tradeLog`, `clubLog`, `inventoryLog`
- Stateful snapshot: `diagSysInfoLog`; `diagIpLog`, `diagMacLog` suspected (pending DOC-003 logging-module promotion to confirm)

If extending log-provider coverage, add the new log's semantics to the (future) logging module card.
