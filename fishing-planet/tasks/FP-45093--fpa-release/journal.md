---
jira: FP-45093
title: Prepare and release 2026.5 Anniversary (FPA)
status: in progress
executor: Stanislav Samoilov
created: 2026-07-20
type: story
---
# FP-45093: Prepare and release 2026.5 Anniversary (FPA)

## Status
Planned (created 2026-07-20). Umbrella task for 2026.5 Anniversary (FPA) server
release-prep work that does not belong to a dedicated JIRA task — investigations,
audits, sanity checks, ad-hoc fixes, configuration reviews. Sibling of the FTUE release
task [FP-44389](https://fishingplanet.atlassian.net/browse/FP-44389); FPA continues from
the same MFT20260325 branch.

## Summary
Catch-all task for FPA release-prep work outside other tickets. FPA (2026.5 Anniversary)
ships from MFT20260325 as a continuation of FTUE — the in-branch release boundary is the
`F2PProtocolVersion` 1125→1126 increment. Whatever surfaces while preparing the branch for
the FPA rollout and is not already tracked by a feature/bug ticket lands here:
data-migration validation, schema/config sanity checks, cross-branch deltas,
EnvironmentVariables / AbTests rollout decisions, one-off fixes uncovered during the release
cycle. Each line of work gets its own artifact under `artifacts/`; the journal records
milestones.

Target release date: 2026-07-27 (per release plan at time of writing).

## Plan
No formal multi-phase plan — work is driven by issues as they surface (same model as the
leaderboards release-support umbrella
[FP-41595](https://fishingplanet.atlassian.net/browse/FP-41595)).

Active tracking:
- [Readiness of server tasks on Stanislav](artifacts/currently-mine-readiness.md) — prioritized
  board of FPA server tasks currently assigned to the lead (commit-in-MFT + review/QA state),
  used to drive per-task review in parallel sessions.

## Milestones
- 2026-07-20: JIRA task created (mirrors FTUE release task FP-44389 — Story, Scrum Team FPA,
  Feature Owner + assignee Stanislav, sprint "Other №15 | 20-07"); KB journal created
- 2026-07-22: Audited FPA server tasks on the lead. FPA release (fixVersion 16274) is large
  (355 issues); 26 currently on Stanislav. Verified commit-in-MFT + read review/QA state per
  task; built prioritized readiness board at
  [artifacts/currently-mine-readiness.md](artifacts/currently-mine-readiness.md). Key gaps:
  6 tasks committed on NPN but not yet merged to MFT (FP-44680, FP-44730, FP-41627, FP-41625,
  FP-42124, FP-41616 — 3 of them Resolved), so they cannot ship in FPA until merged down.
  Also cross-checked the "was mine, since moved away" set: all their commits either already in
  MFT or legitimately absent (duplicate / as-designed / client-only / not-started)
