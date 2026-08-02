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
**Released on Steam 2026-07-30** (server v1126.0, SRV/16375). Still open: the release has not gone
to EGS and the consoles yet, and FP-45166 (protocol-compatibility enforcement) ships separately via
Next Server Hotfix — so this umbrella stays open until the remaining platforms are out.

Umbrella task for 2026.5 Anniversary (FPA) server release-prep work that does not belong to a
dedicated JIRA task — investigations, audits, sanity checks, ad-hoc fixes, configuration reviews.
Sibling of the FTUE release task [FP-44389](https://fishingplanet.atlassian.net/browse/FP-44389);
FPA continues from the same MFT20260325 branch.

## Summary
Catch-all task for FPA release-prep work outside other tickets. FPA (2026.5 Anniversary)
ships from MFT20260325 as a continuation of FTUE — the in-branch release boundary is the
`F2PProtocolVersion` 1125→1126 increment. Whatever surfaces while preparing the branch for
the FPA rollout and is not already tracked by a feature/bug ticket lands here:
data-migration validation, schema/config sanity checks, cross-branch deltas,
EnvironmentVariables / AbTests rollout decisions, one-off fixes uncovered during the release
cycle. Each line of work gets its own artifact under `artifacts/`; the journal records
milestones.

Target release date: 2026-07-30 (moved from 2026-07-27).

## Plan
No formal multi-phase plan — work is driven by issues as they surface (same model as the
leaderboards release-support umbrella
[FP-41595](https://fishingplanet.atlassian.net/browse/FP-41595)).

Active tracking:
- [Readiness of server tasks on Stanislav](artifacts/currently-mine-readiness.md) — prioritized
  board of FPA server tasks currently assigned to the lead (commit-in-MFT + review/QA state),
  used to drive per-task review in parallel sessions.
- [Release checklist steps mapping](artifacts/release-steps-mapping.md) — branch-specific release
  steps for this release (sweep window, per-category instances, paste-ready blocks).

Procedure references: [what content belongs in the checklist](../../../reference/release_checklist_field.md)
and [how to edit the checklist page](../../../reference/release_checklist_editing.md) — the latter was
authored from this release; read it before touching a checklist page.

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
- 2026-07-29: Release-eve state. FPA effectively clear: everything Resolved except FP-45166
  (protocol-compatibility gate, Reopened) — it carries an online-flag-sticking tail and ships via
  Next Server Hotfix, so it does not block the FPA cut. Non-critical / sensitive-tail tasks trimmed
  out of FPA to NSH / Australia (weather cluster, RU-ban, broken-fish, Dragonfly donate). Corrected
  FP-41616 fixVersion (was still 16274) -> Next Server Hotfix + 2026.6 Australia, matching its
  weather siblings. Board refreshed to the final release-day snapshot
- 2026-07-30: **Released on Steam**, window 09:00-11:00 UTC, downtime 45 min. Protocol 1125.0 ->
  1126.0; Build F2P#831, SRV/16375, BM/56607; client 6.0.13 (post-release bumped to 6.0.14, EGS domain
  `epic_v34`). The date slipped from 07-27 because the EGS client sat in certification at Epic — which
  bought the time for the backlog pass below. Release incident, recorded in the Server Release Log: the
  Master server was upgraded (96 -> 192 GB memory, CPU 6132 -> 6230) and TLS 1.2 was missing from the
  setup script on the new box, so the Master would not start. Post-release checklist steps all done —
  minor protocol increment (MFT r16388, 1126.0 -> 1126.1), Environment and branch status (v378),
  Server Release Log, Releases 2026 (v39).
  Backlog pass during the slip: FP-41593 turned out to be **absent from MFT** — its fix (r16158) had
  been reverted an hour later by r16159 (`committed to wrong branch instead of NPN20260602`), which the
  task-id grep never saw; it surfaced on QA and was traced only because the author remembered. Decided
  not to re-apply: moved to Next Server Hotfix + 2026.6 Australia, where the code already lives (NPN).
  The lesson is now in `reference/release_checklist_field.md`. Also dropped the FPA tag from FP-31878
  (To Do, unspeced GD work that was never going to ship) so the release report is clean.
  Known and accepted: MFT r16321 and NPN r16322 both took major protocol 1126.0 eight minutes apart, so
  1126.0 is currently shared between shipped Steam prod and the NPN code branch; NPN will move to 1127
