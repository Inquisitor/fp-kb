# TeamCity Build Pipeline & Config Flow — Audit Notes

Reference document built during the TeamCity audit phase of FP-43632. Purpose: capture the factual mechanism by which TC builds and SoftwareDistributor deploys land binaries and configs onto staging and production nodes — both for the legacy Photon stack and the new GameCarrier stack — so that designs for Mobile / PS / Steam migration rest on facts rather than inference.

## Summary of build pipeline patterns

Two axes of variation: **staging vs prod** and **Photon vs GameCarrier**.

|                 | Staging (push to one node + restart)                                                                                               | Prod (build → package; deploy via SoftwareDistributor)                                                                                                                     |
|-----------------|------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Photon**      | YellowDEV — Photon transport via `Inject Photon config` step                                                                       | `prod.kts` (F2P all-platforms) — packages binaries; configs come from `SoftwareDistributor\Configs\<Platform>.<App>.PhotonServer.config`                                   |
| **GameCarrier** | YellowTEST — replaces Photon shim libs with GC libs; copies `artifacts/deploy/`; runs on default `config.json` from artifacts repo | `nx-prod.kts` / `xb-prod.kts` — packages binaries (same skeleton as Photon prod); configs come from `SoftwareDistributor\Configs\GameCarrier\<Platform>.<App>.config.json` |

### What changes when migrating a TC build from Photon to GameCarrier

Diff (compared head-to-head on YellowDEV → YellowTEST and on F2P-prod → nx-prod / xb-prod):

1. **Add VCS root** `PhotonServer_ArtifactsGc` (mounts `artifacts` repo as `+:.  → artifacts` with `checkoutMode = ON_SERVER`).
2. **Add step** "Replace Photon libraries with GameCarrier libraries" (`copy /y artifacts\libs\* lib`) — substitutes the Photon-API shim DLLs before business-logic build.
3. **Add step** "Deploy GameCarrier artifacts" — wipes `c:\Photon\deploy` and copies `artifacts\deploy` into it.
4. **Add step** "Change application path from Photon to GameCarrier" — `move c:\Photon\deploy\Loadbalancing → adapters\netframework`, same for `CounterPublisher`.
5. **Disable** the "Deploy pre-compiled Photon binaries" (`Photon/deploy/preDeploy.cmd`) step.

For **staging** GC pipelines, the additional differences vs Photon staging are operational rather than structural:
- Stop/Start service uses the GC service name `"Game Carrier Socket Server: LoadBalancing"` (Photon used `*photon*` wildcard).
- A `Backup current deployment` step copies `c:\Photon\deploy → c:\deploy-backup\<timestamp>` on the target node before the new deploy lands.
- An `Enable trace peers` step creates `Flags\TracePeers` files in the per-app folders (debug aid; not appropriate for prod).

For **prod** GC pipelines, the patch is exactly the 5-line diff listed above; no operational differences. NX-prod and XB-prod are step-for-step identical apart from VCS roots, build name, and id — which means **the template for Mobile / PS / Steam prod builds is already established and proven** (clone nx-prod.kts, swap VCS roots and name).

## Config flow — the four sources

| Scenario                                                                           | Who places `config.json` (or `*.config`) on the node                  | Where the file comes from                                                                                                      |
|------------------------------------------------------------------------------------|-----------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------|
| Photon staging (YellowDEV / mobtest / etc.)                                        | TC step `Inject Photon config`                                        | `<env>\Server\PhotonServer.config` in SVN under `Photon\src-server\Loadbalancing\Config\`                                      |
| Photon prod (Steam / Mobile / PlayStation / Retail*)                               | SoftwareDistributor reads its own per-role manifests                  | `SoftwareDistributor\Configs\<Platform>.<App>.PhotonServer.config` + `<Platform>.<App>.Photon.LoadBalancing.dll.config` in SVN |
| GameCarrier staging (YellowTEST and, by extension, future mobtest / pstest / etc.) | TC step `Deploy GameCarrier artifacts` (wipes and copies)             | `artifacts/deploy/config.json` — the default config shipped from the GameCarrier `artifacts` repo                              |
| GameCarrier prod (Nintendo / XBox / future Mobile / PS / Steam)                    | SoftwareDistributor reads `Configs\GameCarrier\<role>.json` manifests | `SoftwareDistributor\Configs\GameCarrier\<Platform>.<App>.config.json` in SVN                                                  |

### SoftwareDistributor manifest mechanism

`SoftwareDistributor\Configs\GameCarrier\Master.json` (and its `Game.json` / `Chat.json` / `AllInOne.json` siblings) contains entries like:

```json
{
  "Name": "GameCarrier\\%FarmName%.Master.config.json",
  "Destination": "C:\\Photon\\deploy\\config.json"
}
```

`%FarmName%` is the platform identifier (`Steam`, `Mobile`, `PlayStation`, `Nintendo`, `XBox`, `Retail*`). At deploy time, SoftwareDistributor expands `%FarmName%` for the target farm and copies the matching `<Platform>.<App>.config.json` to `C:\Photon\deploy\config.json` on the node. The Apply scripts only unpack the binary package; they do not handle config files.

### Apps.Apply.cmd — what it does (and doesn't)

`SoftwareDistributor\Actions\GameCarrier\Apps.Apply.cmd` is the worker invoked from the role-specific entry points (`Master.Apply.cmd` → `Apps.Apply.cmd "%version%" "%pass%" Master GameServer1`; `Game.Apply.cmd` → `... GameServer1`; `Chat.Apply.cmd` → `... Chat Club`; `AllInOne.Apply.cmd` → `... Master GameServer1 Chat Club Async WebAdmin`).

It:

1. Unpacks the password-protected `c:\Distrib\Download\Pack\pack<version>.7z` (password is a parameter from SoftwareDistributor) to `c:\Distrib\Work`.
2. Wipes `c:\Photon` (preserving only the `tls\` subdirectory — TLS certs survive).
3. Copies the unpacked `Photon\` tree to `c:\Photon\`.
4. Strips out adapters / applications not requested by the role (e.g., a Game-only node ends up with only `GameServer1` under `adapters\netframework\Loadbalancing\`; renamed to `Game`).
5. Installs `Async` and `WebAdmin` under their own roots (`c:\Async`, `c:\inetpub\WebAdmin`) if the role list includes them.
6. Persists the original 7z to `c:\Distrib\InstalledVersion\` for reference.

It **does not** touch `config.json` or any other file under `Configs\GameCarrier\`. That step is handled by SoftwareDistributor itself via the manifests.

## Nintendo vs XBox config differences

Below is the per-role comparison, with explanation of the lone meaningful difference.

### Master config (Master + GameOnMaster)

| Endpoint   | Transport | Port |   Protocol   | Nintendo | XBox |
|------------|:---------:|:----:|:------------:|:--------:|:----:|
| Game       |    tcp    | 4531 |    PHOTON    |    ✓     |  ❌   |
| Master     |    tcp    | 4530 |    PHOTON    |    ✓     |  ✓   |
| Master S2S |    tcp    | 4520 |    PHOTON    |    ✓     |  ✓   |
| Game       |    wss    | 9091 |    PHOTON    |    ✓     |  ✓   |
| Master     |    wss    | 9090 |    PHOTON    |    ✓     |  ✓   |
| Game       |    wss    | 4551 | GAME_CARRIER |    ✓     |  ✓   |
| Master     |    wss    | 4550 | GAME_CARRIER |    ✓     |  ✓   |
| Game       |   quic    | 4541 | GAME_CARRIER |    ✓     |  ✓   |
| Master     |   quic    | 4540 | GAME_CARRIER |    ✓     |  ✓   |

### Game config (dedicated Game node)

| Endpoint  | Transport | Port |   Protocol   | Nintendo | XBox |
|-----------|:---------:|:----:|:------------:|:--------:|:----:|
| Game      |    tcp    | 4531 |    PHOTON    |    ✓     |  ❌   |
| Dummy S2S |    tcp    | 4520 |    PHOTON    |    ❌     |  ✓   |
| Game      |    wss    | 9091 |    PHOTON    |    ✓     |  ✓   |
| Game      |    wss    | 4551 | GAME_CARRIER |    ✓     |  ✓   |
| Game      |   quic    | 4541 | GAME_CARRIER |    ✓     |  ✓   |

### Chat config

| Endpoint | Transport | Port | Protocol | Nintendo | XBox |
|----------|:---------:|:----:|:--------:|:--------:|:----:|
| Chat     |    tcp    | 4520 |  PHOTON  |    ✓     |  ✓   |
| Club     |    tcp    | 4522 |  PHOTON  |    ✓     |  ✓   |

Identical. Chat is S2S only — no platform-level transport policy applies.

### Why XBox is different (and what it means for Mobile / PS / Steam)

Microsoft platform certification disallows the unencrypted Photon TCP protocol for client-server traffic on XBox. The XBox client therefore connects to Master and Game over WSS only (the Photon TCP endpoints on 4530-range are not exposed to the public client).

However, GameCarrier (at the time XBox was migrated) had a runtime constraint: the TCP transport could not start unless at least one TCP vhost was bound. S2S communication in this codebase uses Photon TCP, so the TCP transport must be running — and to satisfy the constraint, a "dummy" TCP vhost was added on the Game-only node (`Game tcp 4520` labelled `Dummy S2S endpoint`). The Master node already has Master S2S TCP vhosts so no dummy is needed there.

Nintendo, Mobile, PlayStation, and Steam/EGS do not have this restriction — public TCP from clients is permitted. Their configs include the standard `Game tcp 4531 PHOTON` endpoint and do not need the dummy.

**Implication**: when authoring Mobile, PS, and Steam configs, **use Nintendo as the template**, not XBox.

## Canonical vhosts ordering

`vhosts[]` entries follow a canonical sort order to keep configs trivially diffable:

1. By **protocol**: `PHOTON` first, `GAME_CARRIER` second.
2. Within the same protocol, by **transport**: `tcp` → `wss` → `quic`.
3. Within the same `(protocol, transport)`, by **port** ascending.

The tuple `(protocol, transport, port)` is unique within a single `vhosts[]` array (one listener per IP+port+transport), so the three keys are sufficient — no further tiebreaks.

Apps inside `adapters[].apps[]` and entries in `transports[]` are sorted alphabetically (`tcp` → `wss` → `quic` happens to be the alphabetical order anyway). Apps order matches the historical Photon convention of starting apps alphabetically.

Reference file with the canonical ordering applied to the full default `config.json`: [config.canonical.json](config.canonical.json) — proposed to the GC dev for adoption in `vegasrc/artifacts/deploy/config.json` and downstream `Nintendo.*` / `XBox.*` configs.

## What this means for Track 2 (Mobile / PS / Steam)

### Prod side
- Add `Mobile.{Master,Game,Chat}.config.json`, `PlayStation.{Master,Game,Chat}.config.json`, `Steam.{Master,Game,Chat}.config.json` to `SoftwareDistributor\Configs\GameCarrier\`.
- Use Nintendo as the template (full TCP/WSS/QUIC vhost set, no XBox-style dummy).
- Apply the canonical vhosts ordering.
- Manifests (`Master.json` / `Game.json` / `Chat.json`) already work via `%FarmName%` — no changes needed there.

### Staging side
- AllInOne staging nodes (mobtest, mobqa, mobtest2, pstest, ..., steamdev, test, qa, test2) work on the default `config.json` from the `artifacts` repo. Confirmed with the GC dev: AllInOne nodes do not have, and do not need, env-specific GameCarrier configs.
- **Therefore: no env-specific GC configs need to be committed to SVN for staging environments.** This significantly reduces the scope of Track 2 staging-side work — to zero, in fact, for the AllInOne case.

### TC side
- Each prod build (Mobile / PS / Steam) is a clone of `nx-prod.kts` with VCS roots and naming substitutions.
- Each staging build is a clone of `yellowtest.kts` (or its TC ancestor for the platform) with the 5-line GC patch applied to the existing Photon staging build for that env.

## Open follow-ups

- Decide whether to retroactively apply the canonical vhosts ordering to existing `Nintendo.*` and `XBox.*` configs in LBM (one bulk commit), or only to newly-authored Mobile/PS/Steam configs. Trade-off: a bulk reorder creates a merge-conflict risk against ongoing trunk work by the GC dev; doing it only on new configs leaves Nintendo/XBox temporarily non-canonical.
- When merging GC-config commits forward (LBM → MFT), watch for cross-branch drift in `SoftwareDistributor\Configs\GameCarrier\` — the GC dev's commits land on multiple branches and have historically been missed (incident: XBox configs once not delivered cross-branch and had to be backfilled).
