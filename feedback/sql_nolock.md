---
name: SQL NOLOCK mandatory on read-only reads
description: WITH (NOLOCK) is mandatory on every table reference in any read-only SQL (local + prod-handoff); the only exception is a read whose result drives a data mutation, where a dirty read can corrupt/lose data
type: feedback
---

`WITH (NOLOCK)` on **every** table reference is **mandatory** for every read-only SQL statement — local DB checks via the DB-access MCP, prod-handoff queries written for the user to paste, sanity reads, exploratory scans, joins, even a single-row `SELECT TOP 1` or a `COUNT`. It is a read hint: on a pure read it cannot corrupt data, it only accepts dirty-read risk.

**Why:**
- **Prod Stats fact tables** (`StatsFact`, `MissionsFact`, `Stmt`, `FishFact`, `SilverStmt`, `Balance`, `ActionStats`, `CCU`, ...) take a heavy continuous INSERT stream from the game servers. A normal shared-lock read can block the write path or be blocked by it; on multi-billion-row tables a scan can hold locks long enough to hurt live ingestion.
- **Hot config tables** (`EnvironmentVariables`, `AbTests`, ...) feed game-server cache reloads. Locking them on prod can stall cache refreshes and live traffic.

Dirty-read semantics are acceptable for read-only audits/analytics where exact-instant consistency is not required.

**How to apply:** put `WITH (NOLOCK)` on each table in every `FROM`/`JOIN`, unconditionally — do not rely on a query being "small" or "local".

**The only exception — when NOLOCK can actually corrupt or lose data:** a `SELECT` whose result set **drives a data mutation** — a data-fix `INSERT ... SELECT ... WITH (NOLOCK)`, or an `UPDATE`/`DELETE` whose target rows or computed values come from a NOLOCK read. Under concurrent writes a dirty read can return **duplicated rows, skip rows** (allocation-order scan during page splits), or read **uncommitted** data — and the mutation then writes garbage, corrupting or losing data. For any read that feeds a write, use a consistent committed read (default isolation / appropriate locking), not NOLOCK.

**Caveat — not an exception (still apply NOLOCK):** a verification `COUNT` compared against a known number can over-/under-count under concurrent writes when read with NOLOCK. That is a read-*accuracy* concern, not data safety — it does not license dropping NOLOCK from the audit. If you need an exact reconciliation figure, re-check that one number with a committed read separately. (Static archive/restored copies with no concurrent writer: NOLOCK is harmless but redundant there — still not a reason to omit it by default.)
