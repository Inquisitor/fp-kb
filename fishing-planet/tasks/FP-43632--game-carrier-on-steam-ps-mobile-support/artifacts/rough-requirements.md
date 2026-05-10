# Rough Requirements — GameCarrier Migration

Initial pass at scoping the three work tracks under FP-43632. The tracks will be filed as adjacent JIRA stories (not subtasks of FP-43632), each with its own assignee for time tracking.

## Existing GameCarrier surface in repo

The repo already contains partial GameCarrier scaffolding:

- `SoftwareDistributor\Configs\GameCarrier\` — JSON deploy manifests (`Master.json`, `Chat.json`, `Game.json`, `AllInOne.json`, `SQL.json`, `Tech.json`) referencing `%FarmName%.<App>.config.json` files. Existing PROD-side per-platform configs: `Nintendo.{Master,Game,Chat}.config.json`, `XBox.{Master,Game,Chat}.config.json`.
- `SoftwareDistributor\Actions\GameCarrier\` — cmd scripts: `Add.cmd`, `Apply.cmd` (per-app variants), `Backup.cmd`, `Download.cmd`, `GetStatus.cmd`, `Remove.cmd`, `Start.cmd`, `Stop.cmd`. AllInOne variants present.
- Deploy target (per `AllInOne.json`): `C:\Photon\deploy\config.json`. Same root path as Photon — confirms drop-in replacement at the directory level.

Sample GC config (`Nintendo.Master.config.json`) — top-level keys: `working_dir`, `logging`, `transports[]` (tcp/wss/quic), `adapters[]` (binds to `Photon.LoadBalancing.dll`), `vhosts[]` (per-app port bindings).

The drop-in mechanism: the GameCarrier `artifacts` repo ships a Photon-API shim layer (DLLs named `Photon.SocketServer.dll`, `PhotonLoadbalancingApi.dll`, `ExitGamesLibs.dll`, etc.) so the unchanged business logic links against the same Photon API names while the runtime underneath is GameCarrier.

## Environment matrix (factual, from `svn ls`)

| Platform    | Staging envs in SVN                      | PROD `FarmName` | GC migration                                                |
|-------------|------------------------------------------|-----------------|-------------------------------------------------------------|
| Mobile      | `mobdev`, `mobtest`, `mobtest2`, `mobqa` | `Mobile`        | Not started                                                 |
| PlayStation | `psdev`, `pstest`, `pstest2`, `psqa`     | `PlayStation`   | Not started                                                 |
| Steam/EGS   | `steamdev`, `test`, `test2`, `qa`        | `Steam`         | Not started                                                 |
| XBox (UWP)  | `xbdev`, `xbtest`, `xbqa`, `xbcert`      | `XBox`          | **Done** (configs not in SVN)                               |
| Nintendo    | `nxdev`, `nxtest`, `nxqa`, `nxcert`      | `Nintendo`      | **Done** (configs not in SVN)                               |
| Yellow      | `yellowdev`, `yellowtest`                | —               | Partial — `yellowtest` runs GC; config not reflected in SVN |
| Retail*     | 8 `retail*` folders                      | `Retail*`       | Out of scope this cycle                                     |

> Note: the Steam/EGS row covers both Steam and the Epic Games Store; in some external/industry docs this stack is referred to as the "PC stack". Within this project's terminology, the canonical name is **Steam** or **Steam/EGS**.

In every staging folder above, only Photon configs are present today (`PhotonServer.config` + `Photon.LoadBalancing.dll.config` per app). No `config.json` for GameCarrier exists in SVN, even for already-migrated platforms.

User-stated framing of "12 combinations (4 envs × 3 platforms)" is a simplification: actual delta is 3 PROD farm configs + ~13 staging GC configs for to-be-migrated platforms, plus formalising 8+ staging GC configs of already-migrated platforms (their authoritative source location to be confirmed).

## Two config families per node

| Family         | File                                               | Hosting framework    | Changed by migration?      |
|----------------|----------------------------------------------------|----------------------|----------------------------|
| Business logic | `Photon.LoadBalancing.dll.config`                  | Both                 | No                         |
| Transport      | `PhotonServer.config` (XML) → `config.json` (JSON) | Photon → GameCarrier | Yes — that's the migration |

A node runs **either** Photon or GameCarrier transport configs, never both at once.

## Track 1 — Build automation

**Our requirement**: tagged builds of the GameCarrier core repos are produced and shipped automatically — not by hand. The `artifacts` repo is the natural extension of the existing manual flow; on top of it we propose layering tag-based GitHub Releases, so consumers can download and reference specific versions reliably.

**Required of each shipped build**:
- A versioned tag in the `artifacts` repo (one tag per build), so consumers can pin to a known-good drop and address any past tagged build (not only the latest).
- Version metadata embedded in every shipped DLL/EXE — at minimum `AssemblyVersion`, `AssemblyFileVersion`, `AssemblyInformationalVersion` (carrying the git commit hash). Goal: incident-time forensics on any deployed binary can identify the exact source revision that produced it. Identification metadata (`AssemblyProduct`, `AssemblyCompany`, `AssemblyCopyright`, `AssemblyConfiguration`) is desirable but secondary.

**Acceptance criterion**: given any deployed DLL/EXE, an engineer can recover the version and source git commit hash either via Windows Explorer file properties or via a CLI command (the latter as a fallback for non-Windows build hosts in the future).

**Server-team role on this track**: monitoring of new builds. Integration of these artifacts into server deployment pipeline (TeamCity) is tracked separately under Track 2.

**Implementation choices** (CI tool, build pipeline, multi-repo coordination, version scheme, auth, retention policy) are GC dev's domain — not ours.

## Track 2 — VCS-formalised env configs

**Goal**: every relevant farm and staging environment has a complete, deployable set of GameCarrier configs committed to SVN. After deploy through SoftwareDistributor with these configs, any node powers up on GameCarrier with no manual on-machine edits.

**Audit findings** (full details in [teamcity-and-config-flow.md](teamcity-and-config-flow.md)):
- AllInOne staging nodes (`yellowtest` and, by extension, future `mobtest`/`pstest`/etc.) run on the default `config.json` from the `artifacts` repo. **No env-specific GC configs need to be committed to SVN for staging.**
- For prod, SoftwareDistributor copies `Configs\GameCarrier\<Platform>.<App>.config.json` to `C:\Photon\deploy\config.json` on the node via `Master.json` / `Game.json` / `Chat.json` manifests (`%FarmName%` substitution).
- Mobile / PS / Steam should follow the **Nintendo template** (full TCP/WSS/QUIC vhost set). XBox's dummy TCP is a platform-specific workaround (MS bans unencrypted client TCP; GC runtime required at least one TCP vhost for S2S — hence the dummy).
- Canonical vhosts ordering: **protocol (PHOTON → GAME_CARRIER) → transport (tcp → wss → quic) → port ascending**.

**Deliverables** (PROD only — staging requires nothing):

- Add to `SoftwareDistributor\Configs\GameCarrier\`:
  - `Mobile.{Master,Game,Chat}.config.json`
  - `PlayStation.{Master,Game,Chat}.config.json`
  - `Steam.{Master,Game,Chat}.config.json`
  Cloned from the Nintendo template, with the canonical vhosts ordering applied.
- `*.AllInOne.config.json` only if the AllInOne deploy form is intended for these platforms (currently only Retail* uses AllInOne in PROD; out of scope this cycle).

**Branch path**: commit in LBM (Content), then merge to MFT (Code) per branch-roles convention. Merge to MFT must not be missed — server team catches on acceptance if forgotten. *Incident history*: GC dev commits to this folder have been missed cross-branch before — extra vigilance.

**Open question** (see backlog): retroactively re-sort existing `Nintendo.*` and `XBox.*` configs to canonical vhosts ordering in the same commit, or only apply canonical order to newly-authored Mobile/PS/Steam configs.

**Definition of done**: any prod node for Mobile / PS / Steam can be redeployed via SoftwareDistributor with the new configs and starts on GameCarrier with no manual edits.

## Track 3 — Local dev environment

**Goal**: a developer working on business logic (`Photon.LoadBalancing.dll` and dependent assemblies) can stand up a fully working AllInOne GameCarrier stack on their workstation and iterate, without ad-hoc per-developer machine setup.

**Ownership**: GC dev designs the path jointly with server devs — distribution form, local config layout, start/stop scripts, and personal dev profiles are all collaborative decisions. No premature commitments at this stage.

**Pilot scope** (within FP-43632): a single working local setup for the server team lead, validating that the GC-dev-supplied infrastructure is usable end-to-end. Individual setups by other server developers are out of scope (each developer's responsibility on their own time).

**Documentation home**: Confluence-only (no SVN README required).

**Out of scope**: CI for the local-dev image, multi-developer shared-state environments, containerisation.

## Suggested sequencing

1. Track 1 first — produces the artifact channel Track 3 consumes.
2. Track 2 in parallel — independent of Track 1 because GC configs already exist on live machines; pulling and committing them does not depend on the new artifact pipeline.
3. Track 3 last — consumes outputs of Tracks 1 and 2.

## Active criticisms surfaced during initial drafting

- **"4 envs × 3 platforms = 12"** is misleading. Real envs per platform are heterogeneous (Mobile/PS/XBox/Nintendo each have ~4 staging variants; Steam/EGS stack uses `steamdev`, `test`, `test2`, `qa`). Numerical framing should be replaced with the explicit matrix above.
- **"Закоммитить начиная с LBM ветки"** describes the branch path correctly per branch-roles convention, but the actual scope is a **first-time** formalisation, not a relocation — easy to miscommunicate as "moving files from somewhere".
- **"3 platforms"** undersells the work — Nintendo and XBox staging configs also need pulling into SVN to close the audit gap, otherwise we lose the configs of already-migrated farms in case of incident.
- **Steam/EGS staging schema is unobvious from the folder layout alone** — the bare `test`/`test2`/`qa` folders look like cross-platform defaults but are Steam/EGS-specific. Worth flagging explicitly to GC dev so configs land in the correct envs.
