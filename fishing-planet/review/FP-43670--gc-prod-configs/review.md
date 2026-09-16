---
status: resolved
executor: Oleksandr Kondratenko
branch: NPN20260602 @ r16405, r16406, merged to MFT20260325 @ r16524
jira: https://fishingplanet.atlassian.net/browse/FP-43670
---

# Review: FP-43670 — [GameCarrier] Add prod GC configs in VCS for Mobile / PS / Steam

## Summary

Adds the production GameCarrier server configs to VCS for the Mobile, PlayStation and Steam/EGS
platform stacks under `SoftwareDistributor\Configs\GameCarrier\`, so a prod node of any of those
platforms can be redeployed via SoftwareDistributor without manual on-machine edits. New files follow
the canonical `vhosts[]` ordering (protocol `PHOTON` → `GAME_CARRIER`, then transport
`tcp` → `wss` → `quic`, then port ascending) already applied to the Nintendo/XBox prod configs in
r16074 (LBM) / r16075 (MFT).

A second commit in scope extends all Nintendo and XBox configs with a `counters` section
(`per_second_window = 10`) — beyond the ticket's stated scope.

## Scope

### NPN20260602
- **r16405** — Add `counters.per_second_window = 10` to all Nintendo and XBox configs (Chat, Game, Master)
- **r16406** — Add prod GC configs for Mobile, PlayStation and Steam (Chat, Game, Master per platform)
  - Created via `svn copy` from the corresponding `Nintendo.*` files at r16405 (history preserved)
  - Chat: TCP only, Photon apps Chat (4520) and Club (4522)
  - Game: TCP + WSS + QUIC — Photon (tcp 4531, wss 9091), Game Carrier (wss 4551, quic 4541)
  - Master: TCP + WSS + QUIC — Master and Game apps, Master S2S endpoint (tcp 4520)

Not present on LBM20251201 or MFT20260325 (verified by `svn ls` on both branches at HEAD).

## Findings

### F-1: GC configs and the Photon configs of dedicated Game nodes disagree on the Game TCP port for Mobile / PlayStation / Steam [Medium]

> **Reframed after review (see Round 2).** This finding was first written as "the GC configs carry the
> wrong port" at severity High. That framing was wrong on both counts and is corrected here; the
> original text is kept below the corrected description for the record. The GC configs follow the port
> matrix, which assigns the Game application `4531` on every node role — [FP-46179](https://fishingplanet.atlassian.net/browse/FP-46179)
> states this explicitly and puts GC configs out of its scope. What was inconsistent was the legacy
> state of the dedicated Game nodes' Photon configs, which predate the matrix and took `4530` as the
> lowest free port of the range. Severity drops to Medium: reaching the disagreement required
> redeploying a dedicated Game node onto GameCarrier, which is itself the migration step, and the
> migration had not started.

**Corrected description:** between r16406 and FP-46179 the two config families deployed to the same
node disagreed. `GameCarrier/Game.json` copies both `GameCarrier\%FarmName%.Game.config.json` (GC
transport, vhost `tcp 4531`) and `%FarmName%.Game.Photon.LoadBalancing.dll.config` (business logic,
`GamingTcpPort = 4530` at the time) onto a dedicated Game node. A node redeployed onto GameCarrier in
that window would have had its transport listening on 4531 while the Game application reported 4530 to
the Master — and the Master hands the client whatever the Game application reported, since the game
node's port lives only in the game node's own config. Clients would have been sent to a port with
nothing behind it. The window was latent: a redeploy onto GC is the migration itself, and Mobile / PS /
Steam had not been migrated.

**Original description (superseded):** `Mobile.Game.config.json`, `PlayStation.Game.config.json` and `Steam.Game.config.json`
declare a single `PHOTON`/`tcp` vhost on port **4531**, inherited verbatim from the Nintendo template.
On these three platforms a dedicated Game node announces **4530** to clients
(`<Platform>.Game.Photon.LoadBalancing.dll.config` → `GamingTcpPort = 4530`, `RelayPortTcp = 0`), and
their current Photon transport configs listen on 4530 accordingly. Port 4530 is absent from the new GC
configs, so after migrating a dedicated Game node to GameCarrier the address the Master hands to the
client points at a port nothing is bound to. These platforms have no WSS or QUIC client transport
today, so TCP is the only client path. The `GameOnMaster` instance is unaffected (it genuinely runs on
4531), which makes the failure capacity-dependent rather than immediately total: players routed to the
Master node still join, players routed to any dedicated Game node cannot.

**Investigation:**
- `svn diff -c 16406 <NPN>/SoftwareDistributor/Configs/GameCarrier` — read the nine added files in
  full; all three platforms are byte-identical to each other, and the `Game` file's only `PHOTON`/`tcp`
  vhost is port 4531.
- `svn cat` on `<Platform>.Game.Photon.LoadBalancing.dll.config` for all five platforms: `GamingTcpPort`
  = **4530** for Steam / PlayStation / Mobile, **4531** for Nintendo / XBox. `GamingWebSocketPort` =
  9091 everywhere.
- `svn cat` on `<Platform>.GameOnMaster.Photon.LoadBalancing.dll.config` for all five platforms:
  `GamingTcpPort` = **4531** everywhere — so the `Game tcp 4531` entry in the new `*.Master.config.json`
  files is correct; the defect is confined to the dedicated-Game-node files.
- `svn cat` on `<Platform>.Game.PhotonServer.config`: Steam / PlayStation / Mobile bind
  `TCPListener Port="4530" OverrideApplication="Game"`; Nintendo / XBox bind no TCP listener at all and
  serve clients over `WebSocketListener` 9091. Confirms 4530 is the live client port on the three
  new platforms and 4531 is Nintendo-specific.
- `svn cat` on `<Platform>.{Master,Game}.PhotonServer.config` for the three new platforms: zero
  `WebSocketListener` elements — TCP is their only client transport, so no fallback path exists.
- Control-flow trace at the reviewed revision, read end-to-end: `GameApplication.cs:112` loads
  `GameServerSettings.Default.GamingTcpPort`; `OutgoingMasterServerPeer.cs:338` sends it to the Master
  as `TcpPort` when `RelayPortTcp == 0` (verified 0 for all three platforms);
  `IncomingGameServerPeer.cs:208-212` builds `TcpAddress = "<Address>:<registerRequest.TcpPort>"`;
  `GameState.cs:335-340` (`GetServerAddress`) returns exactly that field for
  `NetworkProtocolType.Tcp` peers. Chain is complete from config value to client-facing address.
- `RelayPortTcp` / `RelayPortWebSocket` / `RelayPortUdp` read as `0` for Steam / PlayStation / Mobile /
  Nintendo, so no node-id-offset port arithmetic applies.
- Codex independently re-derived the same defect and the same code path with its own `svn` access, and
  independently confirmed the committed file content is 4531.

**Resolution:** Skipped — superseded by r16547..r16551 (FP-46179), which moved the dedicated Game nodes
of all three platforms to `GamingTcpPort = 4531` and shifted their Photon listener to match. The GC
configs were not touched and did not need to be.

**Original resolution (superseded — see the reframing note above):** Blocking. Two admissible fixes — either change the `PHOTON`/`tcp` vhost in the three
`*.Game.config.json` files to 4530 (leaving the Master files' `Game` vhost at 4531), or move these
platforms to `GamingTcpPort = 4531` in their `Game.Photon.LoadBalancing.dll.config` as part of the
migration. The choice is the GC dev's; what is not admissible is the current state, where the two files
disagree. Note the ticket's own source requirement (`<kb>` FP-43632 audit notes, "Their configs include
the standard `Game tcp 4531 PHOTON` endpoint") asserts 4531 for these platforms and is itself wrong —
the executor implemented the spec faithfully, so the correction belongs to the requirement as much as
to the commit.

**Discovered by:** skill recon (independently confirmed by Codex; code-reviewer agent concurred but
could not read the committed files itself)

### F-2: Commits landed on NPN20260602, not on the LBM → MFT path the ticket prescribes [Medium]

**Description:** The ticket's Branch path says "commit in LBM, then merge to MFT"; both commits went to
NPN20260602 (Code) instead, and neither LBM20251201 nor MFT20260325 has the nine new files. With
`Fix Version = Internal/Async` — a version described as released as soon as it is done — the change
reaches a prod farm only when the 2026.6 release ships from NPN, unless it is merged down. Whether that
is actually a blocker depends on which branch currently feeds SoftwareDistributor prod packages for
Mobile / PS / Steam, and on whether the GC migration of those platforms is deliberately tied to the
2026.6 release train — neither is determinable from the repository.

**Investigation:**
- `svn log -r 16000:HEAD <branch-URL> | grep FP-43670` on LBM20251201, MFT20260325 and NPN20260602:
  matches only on NPN.
- `svn log -v -r 16405` / `-r 16406`: every changed path is under `/branches/NPN20260602/`.
- `svn ls` on `SoftwareDistributor/Configs/GameCarrier` at HEAD for all three branches: LBM and MFT
  contain only the `Nintendo.*` and `XBox.*` files plus the role manifests; the nine new files exist on
  NPN only. Codex reproduced this independently via remote `svn ls`; the code-reviewer agent reproduced
  it via `Glob` over the local checkouts of both branches.
- `svn log -r 16400:HEAD` over the repo root: r16406 is HEAD, so no later revert or forward-merge
  exists that would change this.
- Branch roles re-read fresh from `<kb>/_index.md` (Code = NPN20260602, Content = MFT20260325,
  Stable = LBM20251201) — the ticket text dates from May, when MFT was Code, so "LBM → MFT" needs
  restating in current role terms rather than being applied literally.
- **Unresolved:** the branch from which prod SoftwareDistributor packages are currently built could not
  be established — the TeamCity build definitions are outside this repository and `<kb>`
  `teamcity-and-config-flow.md` records the config *flow* but not the source branch per build. Severity
  is therefore stated as a conditional rollout risk, not as a confirmed deployment blocker.

**Resolution:** Pending author/owner decision on the target branch set; the commits then have to be
ported there together with the F-1 fix. `<kb>` FP-43632 backlog records this exact risk as a strict
invariant ("this merge must not be missed"), with a prior incident of XBox GC configs missed
cross-branch and backfilled later.

**Discovered by:** skill recon (independently confirmed by both delegates)

### F-3: r16405 changes already-migrated Nintendo / XBox prod configs, outside the ticket's scope [Low]

**Description:** The ticket covers adding Mobile / PS / Steam configs; r16405 instead modifies the six
existing Nintendo and XBox configs, which drive farms already running on GameCarrier in production.
The change itself is a monitoring-window tweak and is applied uniformly, but it rides on an unrelated
ticket and, given F-2, lands only on NPN — leaving Nintendo/XBox configs divergent between NPN and the
LBM/MFT copies that the currently-shipping releases carry.

**Investigation:**
- `svn diff -c 16405` on the GameCarrier config dir: exactly one added block per file,
  `"counters": { "per_second_window": 10 }`, at the same position in all six files; no other edits.
- `svn cat` over all fifteen platform/role configs on NPN: `per_second_window` present in every one —
  the commit message's "consistent with the rest of the platform configs" holds, though the consistency
  it appeals to was created by this same commit.
- Ticket description and the FP-43632 deliverable list (`<kb>` rough-requirements, Track 2) scope the
  work to the nine new files; retroactive edits to Nintendo/XBox were scoped as the canonical-ordering
  pass only, already delivered in r16074/r16075.
- `svn ls` comparison across branches (see F-2): the counters block exists on NPN only.
- **Unresolved:** the executor's claim that this averages per-second counters over a sliding 10-second
  window "instead of the default 60 seconds" could not be verified — `per_second_window` appears
  nowhere in this repository outside the fifteen config files, and the GameCarrier runtime and its
  schema live in the external `artifacts`/`vegasrc` repo. Both delegates reached the same dead end.
  The claim is recorded unverified and is not used to support the severity.

**Resolution:** Accepted as a change, flagged for routing — it should be stated on the ticket (or moved
to its own) so the Nintendo/XBox prod-config edit is not invisible, and it inherits F-2's branch
decision.

**Discovered by:** skill recon (independently confirmed by both delegates)

### F-4: New configs enable WSS and QUIC transports on platforms that run TCP-only today [Info]

**Description:** The nine new files declare `gcs-wss` and `gcs-quic` transports and the matching
`GAME_CARRIER` vhosts (4550/4551 wss, 4540/4541 quic) plus `PHOTON` wss 9090/9091, copied from
Nintendo. Steam / PlayStation / Mobile nodes currently bind no WebSocket listener at all, so these
endpoints are new surface for them. Whether the GC runtime starts cleanly when a WSS transport is
declared but the node has no TLS certificate is the open question — if it refuses to start, the
ticket's "no manual edits on the machine" acceptance criterion fails.

**Investigation:**
- `svn cat` on `<Platform>.{Master,Game}.PhotonServer.config` for Steam / PlayStation / Mobile: no
  `WebSocketListener` elements (count 0 in all six files); Nintendo and XBox serve clients over WSS.
- `<kb>` FP-43632 audit notes record that `Apps.Apply.cmd` wipes `c:\Photon` while preserving only the
  `tls\` subdirectory, i.e. certificates are node-resident state outside VCS.
- Hypothesis "the `CertificateCachePath` asymmetry between platforms evidences missing TLS material"
  disproven: `svn cat` shows the setting present only on Nintendo/XBox Master (and all XBox roles), but
  `GameApplication.cs:897-915` uses it solely for `AppleCertificateHelpers` /
  `AndroidCertificateHelpers` / `EpicRemoteCertificateSource` / `Xb1CertificateHelpers`
  `RemoteCertificateSource.Init` — platform-authentication certificate caching, unrelated to transport
  TLS. Not evidence for this finding.
- **Unresolved:** GC runtime start-up behaviour with a declared-but-uncertificated WSS transport could
  not be settled — the GameCarrier sources are in the external `artifacts`/`vegasrc` repo, and no
  Steam/PS/Mobile node was available to probe. Recorded as an open question, not used to support any
  severity above Info.

**Discovered by:** skill recon (code-reviewer agent concurred; Codex did not raise it)

## Notes

- Executor's JIRA comment states no branch — it is raw `svn log` output only, so the branch had to be
  recovered by audit (see F-2).
- Canonical `vhosts[]` ordering verified by hand on all nine new files: protocol `PHOTON` before
  `GAME_CARRIER`, transport `tcp` → `wss` → `quic`, port ascending within each pair. No violations.
- Files were added with `svn copy` from the Nintendo originals, so per-file history is preserved.
- No `*.AllInOne.config.json` for the new platforms — correct per the FP-43632 scope decision (AllInOne
  is a Retail-only prod deploy form this cycle).
- Chat configs (4520 Chat / 4522 Club) match the shared `Chat.PhotonServer.config` and the Nintendo and
  XBox equivalents; the 4520-vs-4521 rebase is pre-existing tech debt already parked in the FP-43632
  backlog, not introduced here.
- Master S2S vhost (tcp 4520) confirmed necessary: `MasterApplication.cs:277` identifies game-server
  peers by `LocalPort == MasterServerSettings.Default.IncomingGameServerPeerPort`, which is 4520 on
  every platform.
- Every remaining vhost in the nine files (Chat 4520/4522; Game wss 9091, GC wss 4551, GC quic 4541;
  Master tcp 4520/4530/4531, wss 9090/9091, GC wss 4550/4551, GC quic 4540/4541) was audited entry by
  entry against the platform's own Photon configs and DLL settings and found correct.
- Outside this review's scope, noted in passing: `CertificateCachePath` is absent from all Mobile
  configs although Mobile serves Apple and Android and `GameApplication.cs:897/903` passes that setting
  to the Apple/Android certificate-source initialisers. Pre-existing, untouched by these commits, not
  investigated.

## Investigation Journal

- Phase 1 intake: JIRA read via MCP; Executor field populated; commit list taken at face value from
  comment 134047.
- Phase 2 VCS audit: `svn log | grep FP-43670` run against LBM, MFT and NPN — matched on NPN only,
  contradicting the ticket's prescribed LBM→MFT path (→ F-2). Layer-3 pass over `svn log -r 16400:HEAD`
  found no revert or follow-up citing r16405/r16406.
- WC at r16404, i.e. behind both reviewed revisions; `svn status` clean under the touched tree. Chose
  the `svn diff`/`svn cat` path over updating the shared WC, and propagated an explicit stale-WC
  warning plus the exact commands into both delegated reviewers' prompts.
- Initial hypothesis "the three new platform files must differ from each other" disproven — they are
  byte-identical; the real platform delta turned out to be against Nintendo, not between the three.
- Hypothesis "SoftwareDistributor needs the new files registered somewhere" disproven — `Master.json` /
  `Game.json` / `Chat.json` resolve `GameCarrier\%FarmName%.<Role>.config.json` by farm name, so the
  files are picked up with no manifest change.
- The FP-43632 audit notes were treated as a claim to test, not as ground truth: their assertion that
  Mobile/PS/Steam "include the standard `Game tcp 4531 PHOTON` endpoint" is contradicted by those
  platforms' own `GamingTcpPort = 4530` (→ F-1). The requirement, not just the commit, needs correcting.
- Delegation caveat: the `code-reviewer` agent had no shell/`svn` access (its `WebFetch` against the SVN
  host returned 401) and read this review card, so its agreement on F-1 is partly circular. Its
  independent contribution was the upstream evidence and the `GameState.cs` link in the trace, which
  was re-verified here directly. Codex had working `svn` access and is a genuinely independent
  confirmation of F-1, F-2 and F-3.
- Delegate-surfaced lead on `CertificateCachePath` investigated and rejected as evidence for F-4 (it is
  platform-auth certificate caching, not transport TLS).

## Round 2

Re-review after the executor's commits were rolled out across the branch chain and the port conflict
was resolved independently. Repository HEAD at re-audit: r16561.

### Scope

- **IMV20250220 r16519** — new configs copied from NPN@16406; also pulls r16246 (apply-script perf
  counters) and r16267 (structured adapter/app args)
- **KNW20250723 r16522** — merged from IMV
- **LBM20251201 r16523** — merged from KNW
- **MFT20260325 r16524** — merged from LBM
- **NPN20260602 r16525** — record-only; content originated here and came back around the chain

Port resolution landed under a separate ticket, FP-46179 *[GameServer] Bind the Game application to
4531 regardless of node role*:

- **IMV20250220 r16547** → **KNW20250723 r16548** → **LBM20251201 r16549** → **MFT20260325 r16550** →
  **NPN20260602 r16551** — `GamingTcpPort` 4530 → 4531 in the Game business-logic configs of Mobile /
  PlayStation / Steam, and the `Game` TCP listener moved 4530 → 4531 in the matching
  `<Platform>.Game.PhotonServer.config`

### Finding resolutions

- **F-1 → Skipped — superseded by r16547..r16551 (FP-46179), and reframed.** The port matrix assigns the
  Game application `4531` on every node role; the GC configs already followed it, and FP-46179 names GC
  configs as explicitly out of its scope. The inconsistent side was the dedicated Game nodes' Photon
  configs, which predate the matrix. FP-46179 moved those nodes to 4531 on both the business-logic and
  the transport side. Verified at HEAD, not from the commit message: `svn cat` on all three branches
  shows `GamingTcpPort = 4531` for Mobile / PlayStation / Steam `Game` configs,
  `TCPListener Port="4531" OverrideApplication="Game"` in their `PhotonServer.config`, and
  `port 4531 / app Game / tcp / PHOTON` in the GC `*.Game.config.json`.

  Two corrections to this review's own output, recorded because both were wrong in a way that would
  have misinformed the ticket: the finding's framing (GC config blamed for what was legacy Photon state)
  and its severity (High, where the disagreement was only reachable by redeploying a node onto GC — the
  migration step itself, which had not happened). FP-46179 is also not a consequence of this review:
  its description lays out the port matrix as a long-standing convention problem and was authored
  independently.
- **F-2 → Skipped — superseded by r16519..r16525.** The nine files are present on IMV, KNW, LBM, MFT and
  NPN. Content verified identical across all five branches by md5 over `svn cat` for every one of the
  nine files — the five-branch merge chain introduced no drift.
- **F-3 → Accepted.** The `counters` block reached every branch with the rollout; `per_second_window`
  is present in the final files on all of them. The scope observation stands as a record only.
- **F-4 → unchanged, still Info and still unresolved.** Nothing in this round bears on whether the GC
  runtime starts with a declared WSS transport and no TLS certificate.

### Notes

- Nintendo and XBox `Chat` / `Master` configs differ between IMV/KNW and LBM/MFT/NPN. Diffed: the delta
  is the canonical `vhosts[]` ordering plus a one-space indent fix, i.e. r16074/r16076, which were
  applied from LBM upward and never reached the two older branches. Expected, not rollout drift.
- Final file state audited in full on MFT: `counters` present, `adapters[].apps[].args` in the
  structured object form from r16267, canonical `vhosts[]` ordering intact.

### Verdict — approve

Both findings that gated the ticket are resolved in VCS and verified at HEAD on every branch that
carries the files. The remaining items are an accepted scope note (F-3) and an operational question
(F-4) closed by the task owner.

No `Verification scope:` line is carried into the posted comment. It was mandatory while F-1 stood at
High, because the approve would then have implied coverage the review did not have. After the
reframing, the residue was "a node was not booted on GameCarrier" — self-evident for a review of
config files and of no use to the ticket's readers. Dropped from the verdict and from JIRA together,
rather than quietly kept in one and not the other.

**Carried out of scope, for FP-46179 rather than this ticket:** moving the `Game` TCP listener to 4531
changes a port on platforms still serving production traffic on Photon. Clients learn the game-node port
dynamically from the Master, so no client change is implied — but anything pinned to 4530 outside the
application (firewall rules, load-balancer or health-check targets on the Game nodes) would need to
follow. Not investigated here; flagged because the rollout already reached every branch.

### Resolution update — operational readiness confirmed by the task owner

Both remaining items were operational rather than code questions, and the task owner (who coordinates
this migration with the GC dev and DevOps) confirmed them directly:

- **F-4 → Accepted.** DevOps have already provisioned GameCarrier servers, and TLS certificates are part
  of their standard node preparation. The "WSS transport declared with no certificate on the node"
  state therefore does not occur in practice, so the finding is latent by construction rather than
  reachable. The underlying technical question — what the GC runtime does in that state — remains
  untested, but is no longer review-relevant. Source: task owner's statement, not an instrument reading.
- **Firewall / load-balancer port follow-up (FP-46179) → closed.** DevOps are briefed on the port change
  and handle the infrastructure side. No action carried out of this review.

Verdict unchanged: **approve**. The verification-scope caveat above still applies to what this review
established by instrument; the operational preconditions rest on the owner's confirmation.
