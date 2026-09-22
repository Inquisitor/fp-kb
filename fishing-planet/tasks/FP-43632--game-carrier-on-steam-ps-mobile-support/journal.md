---
status: in-progress
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-43632
parent: FP-35367
related: FP-43669, FP-43670
---
# FP-43632: [GameCarrier] Migration coordination — Mobile / PS / Steam

## Status
**Mobile is on GameCarrier** (2026-09-17). The first production rollout shipped under `2026.5.1 GameCarrier Migration`: build NxGC#18 from IMV r16547, farm rebooted and verified behind a closed firewall, minor protocol version incremented afterwards (IMV r16565, `1122.9 -> 1122.10`). The first two PlayStation nodes went onto GameCarrier the same day; PlayStation came through its observation weekend without incident; its downtime window is 23-24 September, when the four remaining Photon nodes leave, two more prepared GameCarrier nodes join the two already carrying the farm, and the master is moved over. Steam is being prepared in parallel rather than after, so the two platforms overlap. Track 2 is delivered — FP-43670 closed, prod GC configs for Mobile / PS / Steam in VCS and merged to MFT. Track 1 (FP-43669 build automation) is still To Do with GC dev; Track 3 (local dev environment) stays deferred behind it. The host switch itself is run by DevOps under the release checklist, which now shuts players out with the firewall while the farm is checked.

Earlier context (through 2026-05-10), awaiting external delivery on Tracks 1 and 2 (FP-43669 build automation, FP-43670 prod GC configs in VCS — both with GC dev). Server-side coordination cycle is complete: TeamCity pipeline audit done, canonical `vhosts[]` ordering established and applied to existing Nintendo/XBox configs, two adjacent JIRA stories filed for GC-dev work, context comment + canonical reference attached to FP-43670, Confluence reference page "Server Transport Ports" published under Infrastructure (id 5579014145). Track 3 (local dev environment) intentionally deferred until Track 1 lands the first automatic build. Two non-blocking parking lots in [backlog](backlog.md): Chat-port cleanup tech-debt and a one-time GC sources audit for PHOTON-over-UDP transport. Resumes when Track 1 / Track 2 progress lands.

## Summary
Meta-task tracking the migration of the FP server transport layer from Photon to GameCarrier. GameCarrier is an in-house drop-in replacement that hosts the unchanged business logic (`Photon.LoadBalancing.dll`); the migration replaces only the transport framework underneath. Inter-server communication is implemented in business logic, so it is binary-compatible across both frameworks. This task does **not** implement the migration itself — it decomposes the work into independent subtasks (each will get its own JIRA-ID), drives requirements gathering, and tracks delivery.

Two config families are involved per node:
- **Business-logic config** (`Photon.LoadBalancing.dll.config`, sits next to the business-logic DLL) — unchanged across Photon and GameCarrier.
- **Transport config** — Photon uses `PhotonServer.config` (XML); GameCarrier uses `config.json` (JSON, see existing `Nintendo.Master.config.json`).

Migration plan (per stakeholder briefing):
1. Staging nodes first (`*DEV`, `*TEST`, `*QA` per platform) → GameCarrier
2. Tiny test stack (Master + Game + Chat+Club) to verify inter-server communication
3. Gradually swap Game nodes one at a time in the production farm, monitor, scale up if healthy
4. Replace Master+Game and Chat+Club nodes during scheduled downtime — migration complete

**Hard constraint**: no node ever runs Photon and GameCarrier configs simultaneously.

**Scope**: Mobile, PlayStation, Steam/EGS. Already migrated: Nintendo, XBox, Yellow* (test). **Out of scope**: Retail* platforms.

## Plan
Three work tracks, to be filed as adjacent JIRA stories (not subtasks of FP-43632) — each with its own assignee for time tracking:

1. **Build automation** — automatic build of GameCarrier core repos on GitHub, shipping artifacts to the `artifacts` repo on GitHub. GC dev owns implementation choices.
2. **VCS-formalised env configs** — first-time formalisation of GameCarrier configs in VCS for all relevant staging envs (Mobile/PS/Steam to-be-migrated + Nintendo/XBox/Yellow already-migrated-but-undocumented) and PROD farms (Mobile/PS/Steam). Commit in LBM, merge to MFT (Code) afterwards.
3. **Local dev environment** — GC dev provides distributable framework + jointly-designed local config blueprint and scripts; pilot setup validated by the server team lead.

Detailed rough requirements per track + environment matrix + open questions: [artifacts/rough-requirements.md](artifacts/rough-requirements.md).

Sequencing: Track 1 first (it produces the artifact channel that Track 3 consumes); Track 2 in parallel (independent of build automation since GC configs already exist on live machines); Track 3 last (consumes outputs of Tracks 1 and 2).

## Milestones
- 2026-05-06: Task created. Initial repo audit identified existing GC infrastructure (`SoftwareDistributor\Configs\GameCarrier\` + `Actions\GameCarrier\`) and the staging-config layout in `Photon\src-server\Loadbalancing\Config\<env>\`. Key gap recorded: GC configs of `nxtest`/`xbtest`/`yellowtest` are not present in SVN — need to be sourced and committed as part of Track 2 (authoritative source location to be confirmed). Three work tracks scoped, rough requirements logged, blocking questions logged in backlog
- 2026-05-07: First requirements pass against the user's answers — most Track 1/2/3 questions resolved (Steam/EGS=`steamdev`+bare`test`/`test2`/`qa`; Retail* out of scope; merge LBM→MFT strict invariant; tracks filed as adjacent JIRA stories rather than subtasks; implementation choices left to GC dev where applicable). Two new pre-work items surfaced: TeamCity pipeline audit and `C:\Photon` vs `D:\FishingPlanet\GameCarrier` side-by-side comparison. Next: file adjacent JIRA stories for Tracks 1–3
- 2026-05-07: TeamCity audit complete — audit notes captured in [artifacts/teamcity-and-config-flow.md](artifacts/teamcity-and-config-flow.md). Key findings: (1) GC migration of any TC build is a fixed 5-line patch (1 VCS root + 3 added steps + 1 disabled step); nx-prod and xb-prod are step-for-step identical apart from VCS roots and naming, so Mobile/PS/Steam prod builds are clones of nx-prod with substitutions. (2) Config flow has 4 sources mapped explicitly; SoftwareDistributor manifest mechanism (`Master.json`/`Game.json`/`Chat.json` referencing `%FarmName%.<App>.config.json`) handles prod GC config injection — Apply.cmd only unpacks binaries. (3) Confirmed with GC dev: AllInOne staging works on default `artifacts/deploy/config.json`; **no env-specific GC configs need to be committed to SVN for staging**. (4) Mobile/PS/Steam should clone the Nintendo template, not XBox (XBox's dummy TCP is an MS-certification workaround for unencrypted client TCP). (5) Canonical vhosts ordering established: protocol (PHOTON → GAME_CARRIER) → transport (tcp → wss → quic) → port ascending. Track 2 staging-side work reduces to zero; prod-side work is well-scoped and templated
- 2026-05-07: Canonical vhosts ordering applied to existing Nintendo/XBox configs in LBM [r16074], merged to MFT [r16075]. Two files reordered (`Nintendo.Master.config.json`, `XBox.Master.config.json`); the other four (Nintendo/XBox Game and Chat) were already canonical. Reference file [artifacts/config.canonical.json](artifacts/config.canonical.json) committed in KB; canon to be proposed to GC dev for adoption in `vegasrc/artifacts/deploy/config.json`. Confluence search confirmed there is no existing page documenting server transport ports — gap added to backlog as future work
- 2026-05-07: Track 1 JIRA story filed — [FP-43669](https://fishingplanet.atlassian.net/browse/FP-43669) `[GameCarrier] Automate framework build & artifact publishing`, parent FP-35367, assignee Stas (executor to be set to GC dev). Description scoped to two requirements (versioned tags in `artifacts` repo + version metadata embedded in DLL/EXE) and one acceptance criterion (engineer can recover version + git commit hash from a deployed binary). Implementation choices left at GC dev's discretion
- 2026-05-07: Track 2 JIRA story filed — [FP-43670](https://fishingplanet.atlassian.net/browse/FP-43670) `[GameCarrier] Add prod GC configs in VCS for Mobile / PS / Steam`, parent FP-35367, assignee Stas (executor to be set to GC dev). Description scoped to nine new files under `SoftwareDistributor\Configs\GameCarrier\` (Mobile/PS/Steam × Master/Game/Chat) using the canonical vhosts ordering, branch path LBM → MFT, and acceptance criterion that any prod node redeploys cleanly. Staging side is intentionally not in scope (AllInOne staging works on the default `artifacts/deploy/config.json`)
- 2026-05-07: Commit + merge note for r16074/r16075 posted to FP-43632 per the KB JIRA-comment-format reference (combined into one ADF comment); context comment posted to FP-43670 with reasoning for the canonical sort + the `config.canonical.json` reference attached for cross-repo adoption
- 2026-05-09: Indentation fix in `Nintendo.Chat.config.json` and `XBox.Chat.config.json` (one-space alignment of `transports[0]` opening brace); LBM r16076, merged to MFT r16077; combined commit-note posted to FP-43632
- 2026-05-09: First draft of the Confluence "Server Transport Ports" page written to [confluence/workspace/FP-43632--server-transport-ports.md](../../../confluence/workspace/FP-43632--server-transport-ports.md). Targets parent page Infrastructure (id 46628932) under `tech-guidelines/server`. After review iterations: two original tables (canonical AllInOne + per-role) merged into one sweep (`Port × Transport × Protocol × AllInOne / Chat / Master / Game`), Chat/Club S2S nature explicit, Chat/Club port-history note added, transport-layer (TCP/UDP) split clarified (QUIC = UDP), Xbox special case covers both runtimes (Retail Xbox on Photon-native WSS; current Xbox on GameCarrier WSS+QUIC), new "Why two server frameworks coexist" block added (Nintendo launched directly on GC; Xbox migrated next; Mobile/PS/Steam current; Retail later, transparent to clients). Awaiting publishing
- 2026-05-10: Page polished — explicit `Net` column added to the endpoints table (TCP for tcp/wss, UDP for quic), Photon UDP variant noted (5055/5056, unused) plus parking-lot question whether GameCarrier provides any PHOTON-over-UDP transport, "PC stack" mention removed (not in team usage). Two new backlog items filed: Chat-port cleanup (fix Chat at 4521 universally when the common-template config rework lands) and a one-time GC sources audit for any PHOTON-over-UDP transport. Memory updated: `feedback_steam_terminology.md` tightened (no "PC" anywhere); `reference_fp_release_versions.md` added to record F2P vs Retail distinction
- 2026-05-10: Further polish — vhosts-ordering section retitled "Canonical `vhosts[]` ordering (GameCarrier configs)" with intro explaining the difference between Photon's `PhotonServer.config` (XML, separate listener-kind elements) and GameCarrier's `config.json` (single flat `vhosts[]` array). Platform lists across the page reordered to the team-convention Steam/EGS → PlayStation → Xbox → Mobile → Nintendo. Yellow re-classified explicitly as staging cluster, not a game platform. F2P removed from platform-list contexts (it is a release-version, not a platform). "Where configs live" split into Staging-and-local-dev section (`Photon/src-server/Loadbalancing/Config/<env>/`) and Production section (`SoftwareDistributor/Configs/`); future restructuring of the Photon vs GameCarrier subtree split flagged as deferred. Memory: `feedback_fp_platform_order.md` added recording the team platform-listing order convention
- 2026-05-10: Final tightening pass — "Why two server frameworks coexist" rewritten as a tight "Migration status" bullet list (Nintendo done, Xbox done, Steam/EGS / PlayStation / Mobile current, Retail later); the Steam/EGS gloss removed from Per-platform variations for symmetry with Mobile (no Apple+Android gloss). User confirmed page acceptable
- 2026-05-10: Page published to Confluence as [Server Transport Ports](https://fishingplanet.atlassian.net/wiki/pages/viewpage.action?pageId=5579014145) (id 5579014145, parent Infrastructure 46628932, version 2). Workspace frontmatter updated with page_id; parent_id removed
- 2026-05-10: KB index reorganised — Infrastructure converted from a flat-page entry under `tech-guidelines/server/_pages.yml` into its own indexed subsection. Created `tech-guidelines/server/infrastructure/_pages.yml` populated with all 39 direct child pages of the Infrastructure Confluence page (descendants pulled via API), Server Transport Ports listed there with `verified: 2026-05-10` / `last_pushed_version: 2`. Server-section `_pages.yml` updated: Infrastructure removed from `pages:`, added under `subsections:` (slug `infrastructure`, indexed). `tree.md` updated to show Infrastructure as indexed (39 pages). Workspace draft `section:` field rebased to `tech-guidelines/server/infrastructure`
- 2026-05-10: Task placed on hold pending external delivery on Tracks 1/2. No active server-side work until GC dev lands FP-43669 / FP-43670
- 2026-09-16: Track 2 delivered and the first production rollout scoped. FP-43670 closed — prod GC configs for
  Mobile / PS / Steam now in VCS (authored in NPN r16405-16406, reached MFT by merge r16524); Nintendo/XBox configs
  gained `counters.per_second_window`. Release vehicle created — `2026.5.1 GameCarrier Migration` carrying FP-43632
  (driver; stays open and moves to the next stage when the version is released), FP-43670 and FP-46179 — shipping
  from the same build as `2026.5.2 PremiumShop Rod-Setup Display Server Hotfix`. Patch window: r16388 (minor
  increment after the 2026.5 Anniversary Steam release) to r16550.
  Verified while scoping: GC configs are inert on platforms still on Photon, because `Actions/` and
  `Actions/GameCarrier/` are parallel script sets and no Photon script reads `config.json`.
  Process note: the server release checklist template does not apply to this rollout — the Photon -> GameCarrier host
  switch is run by DevOps, with the server side supplying configs rather than checklist steps.
  Relates: FP-46179 (the Game port unification shipping in the same version; its own card carries the port detail and
  the firewall prerequisite)
- 2026-09-17: Mobile pilot accepted on connection-level evidence rather than absence of complaints. Over 46 hours
  under the full load of the platform, with GameCarrier carrying about 490 of the 526 connections at peak, not one
  GameCarrier connection was ever orphaned. Comparing the pilot against Nintendo and Xbox traces did uncover a
  defect, present on Nintendo for 220 days and never measured before: peer objects whose connection dropped before
  authentication are never released, in exactly one combination - the Game application over TCP. The same TCP on a
  Master node and the same Game application over WSS and QUIC are clean, and counters appeared to show the
  sockets already closed while the objects remained - a reading overturned on 21 September, see below. Not a regression of the migration, and cleared by any deployment; questions for
  GC dev parked in [backlog](backlog.md). Measurement and matrix:
  [artifacts/orphaned-peers.md](artifacts/orphaned-peers.md)
- 2026-09-17: Verification checklist for the rollout published as
  [2026.5.1 - GameCarrier Migration Server Release checklist](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/5960925185/2026.5.1+-+GameCarrier+Migration+Server+Release+checklist)
  under SERVER RELEASE CHECKLISTS, in the standard template format. Built from the DevOps reconfiguration kit,
  the distributor mechanics and this task's findings; the database and content steps of the template are
  listed as explicitly out of scope, with the reason. Kept in Confluence only - `confluence-md` publishes
  markdown task lists as plain bullets, so the page is maintained through the API and no local copy is held.
  The release-checklists section was indexed in KB in the process, and the converter gap parked in the KB
  backlog.
- 2026-09-17: First production rollout shipped. Mobile is fully on GameCarrier - build 18 from IMV deployed, farm
  rebooted and verified - and the first two PlayStation nodes were introduced on GameCarrier the same day, from the
  MFT-side package (Xbox build 28; one package serves every platform, the distributor picks configs by farm name).
  Minor protocol version incremented on IMV afterwards - r16565, `1122.9 -> 1122.10` - marking the boundary in
  Stats -> Errors; the farm had been on an October 2025 build, so it took three accumulated fixes along with the
  transport switch. Schedule page updated with the actual date.
- 2026-09-17: Firewall gating folded into the release procedure, out of this rollout. The farm is now closed to
  players before it is started, checked from the inside while they are still shut out, and opened only after;
  clearing the maintenance file moved to the very end, because that file is what explains an outage to the
  client - cleared early, an emergency stop looks to players like a plain connection failure. The value showed
  immediately: missing performance counters were caught behind the gate and fixed with a farm restart nobody
  saw. Applied to the checklist template and to both unreleased checklists, this release's and Australia's.
- 2026-09-21: PlayStation passed its observation weekend without incident, and the orphaned-peer question was
  settled from the nodes themselves, with counters and socket state rather than trace alone. The earlier reading
  was wrong: an orphan is not an object outliving its connection but an open `Established` socket, matched one by
  one against the trace by remote address and creation time. The cause shows in the counters - the TCP transport
  never sets a connection timer, `tcp.api.calls.connectionsettimer.total` standing at zero across 162 533 accepted
  connections on one node - so a connection that sends nothing after being established has nothing to close it,
  while QUIC escapes because msquic times out idle connections itself. A Photon node on the same farm accumulates
  the same way at a fraction of the rate: three such sockets over 48 days against GameCarrier's eight over four.
  Not a blocker, not a regression of the migration, and the question to GC dev is now specific enough to act on.
  Full analysis: [artifacts/orphaned-peers.md](artifacts/orphaned-peers.md)
- 2026-09-21: PlayStation window moved to 23-24 September and its shape settled - four Photon nodes out, the two
  prepared GameCarrier nodes in alongside the two already running, master and chat moved in the same window, the
  rest of the spare pool introduced by load as needed. Steam preparation runs in parallel rather than waiting for
  PlayStation to close, which is the overlap the plan describes as possible acceleration and does not assume: the
  cost is two farms mid-swap at once and a messier retreat, accepted deliberately. The 22 September detector in
  the plan is therefore spent without the schedule slipping.
