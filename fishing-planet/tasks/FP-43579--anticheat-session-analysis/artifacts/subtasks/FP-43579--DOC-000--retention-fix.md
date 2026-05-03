---
id: DOC-000
title: Architecture retention correction
slice: VS0
status: done
depends-on: []
effort: S
done: 2026-05-03
---

## Scope
Replace the «Mongo retention 14d» / «Stats.Screens TBD» claims in [architecture.md → Data availability constraints](../architecture.md#data-availability-constraints) with verified state, and remove the planned UI retention banner.

## Why
- `fishingLog` 14d — confirmed by user. Source-of-truth is **out-of-band** (DBA scripts), not in repo.
- `diagSysInfoLog` retention — was «assumed same», not verified. No TTL index in `NoSql/indexes.js`, no AsyncProcessor cleanup job. Treat as unverified.
- `SQL Stats.Screens` 14d — verified in code (`SqlAnalyticsProvider.ScreenStorageHorizon=14` + `ScreensClearingJob`).
- A hardcoded retention banner in UI risks misleading moderators if external retention drifts. Defer banner until a verified manifest exists.

## Files modified
- `architecture.md` — Data availability constraints table + UI behavior paragraph
- `backlog.md` — DAT-001 preconditions ticked / annotated; new DOC-003 item «KB logging module promotion»

## Exit criteria
- [x] Architecture doc no longer contains TBD or unverified retention assertions
- [x] Backlog DOC-003 captures the KB-promotion follow-up (out of scope for FP-43579)
