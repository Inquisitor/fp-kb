---
jira: https://fishingplanet.atlassian.net/browse/FP-44591
title: No-email Twitch linking - capture, backfill & reward gating
status: planned
executor: Stanislav Samoilov
created: 2026-06-21
type: story
epic: FP-44593
related: FP-44590, FP-44592, FP-34340, FP-28678
---
# FP-44591: No-email Twitch linking - capture, backfill & reward gating

## Status
**Planned (design approved, no code yet).** Originated from a Twitch-linking log analysis (2026-06-11..06-17) that found an `@TwitchEmail` `SqlException` blocking ~44% of link attempts (134 failures / 18 users retrying deterministically). Product (Producer + Live-Ops + CS Lead) decided: allow links with a NULL e-mail, capture/backfill the e-mail when the user confirms it on Twitch (linking page + at drop delivery + a daily sweep), and gate reward delivery on a present e-mail. Work is organised under epic **FP-44593** "[Twitch] Integration maintenance" with three stories — **FP-44590** (unify the Twitch client to netstandard2.0, prerequisite), **this** (FP-44591), and **FP-44592** (OAuth error handling + DataProtection keys).

Next: implementation starts with FP-44590 — it blocks the shared `GetUserInfo` the backfill depends on.

- Design spec: [twitch-no-email-linking-design.md](artifacts/2026-06-20-twitch-no-email-linking-design.md)
- Subsystem reference: [twitch-drops module](../../server/modules/twitch-drops/_card.md)

## Summary
Twitch's `/helix/users` returns `email` only for a granted-scope + verified account; otherwise it is absent. `DalAdapter.CreateLink` passed that null straight into `AddWithValue("@TwitchEmail", null)`, which SqlClient rejects ("parameter not supplied") -> HTTP 500, blocking the link entirely. The column is nullable, so the crash fix is `DBNull.Value`; the broader feature adds e-mail backfill (3 touchpoints, shared `GetUserInfo` + `SetTwitchEmail`) and a delivery gate per the product decision. Delivery itself uses the stored token (TwitchId), not the e-mail — so the gate is a product rule, captured in the module [log](../../server/modules/twitch-drops/log.md).

## Milestones
- 2026-06-21: Log analysis + root cause (`AddWithValue(null)` != `DBNull.Value`); Twitch docs verified (email = verified-only); product decision (reward gate); epic FP-44593 + stories FP-44590/91/92 created and linked; `twitch-drops` KB module authored; design spec written and approved via Plannotator review.
