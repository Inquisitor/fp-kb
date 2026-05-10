---
page_id: "5579014145"
section: tech-guidelines/server/infrastructure
related_tasks:
  - FP-43632
  - FP-43669
  - FP-43670
---
# Server Transport Ports

Reference for the network ports each FP server role exposes, the transport protocols behind them, and how the per-platform configuration is structured. Applies to both the legacy Photon stack and the GameCarrier replacement.

<!-- {toc} -->

---

## Background

Each FP server role (Master, Game, Chat, Club) listens on a specific set of endpoints, distinguished along three axes:

- **Wire protocol**: `PHOTON` (original; used by all clients today and by all server-to-server traffic) or `GAME_CARRIER` (newer protocol introduced with the GameCarrier transport framework, used by clients on the GameCarrier-aware build path).
- **Transport**: `tcp`, `wss` (WebSocket Secure), or `quic`.
- **Transport-layer protocol** (OSI layer 4): TCP for `tcp` and `wss` listeners; UDP for `quic`.

Photon natively supports both TCP and WSS for the PHOTON wire protocol. In FP, WSS-PHOTON listeners are bound only on Retail Xbox — the sole currently-active Photon-based stack subject to MS platform certification, which forbids the plaintext TCP wire protocol for client traffic. All other Photon-based stacks (Steam/EGS, PlayStation, Mobile) bind TCP-PHOTON only.

GameCarrier-based servers bind a wider set than any Photon stack: the same PHOTON listeners plus GAME_CARRIER-over-WSS and GAME_CARRIER-over-QUIC for GameCarrier-aware clients. Once a platform stack is fully migrated and old clients have rolled out of circulation, the PHOTON listeners stay open for compatibility but client-facing traffic concentrates on GAME_CARRIER.

## Migration status

The Photon → GameCarrier replacement is in progress:

- **Nintendo** — done (launched directly on GameCarrier; never ran on Photon).
- **Xbox** — done.
- **Steam/EGS, PlayStation, Mobile** — current phase.
- **Retail (Steam, PlayStation, Xbox)** — planned later.

## Listening endpoints

The table below lists every endpoint a node may bind, by port ascending. Each row shows the transport, the wire protocol, and which app provides the endpoint on each node role (`AllInOne`, `Chat`, `Master`, `Game`). The default `config.json` shipped in the `vegasrc/artifacts` repo encodes the AllInOne column.

|  Port | Transport | Net | Protocol     | AllInOne   | Chat | Master      | Game |
|------:|-----------|-----|--------------|------------|------|-------------|------|
|  4520 | tcp       | TCP | PHOTON       | Master S2S | Chat | Master S2S  | —    |
|  4521 | tcp       | TCP | PHOTON       | Chat       | —    | —           | —    |
|  4522 | tcp       | TCP | PHOTON       | Club       | Club | —           | —    |
|  4530 | tcp       | TCP | PHOTON       | Master     | —    | Master      | —    |
|  4531 | tcp       | TCP | PHOTON       | Game       | —    | Game        | Game |
|  4540 | quic      | UDP | GAME_CARRIER | Master     | —    | Master      | —    |
|  4541 | quic      | UDP | GAME_CARRIER | Game       | —    | Game        | Game |
|  4550 | wss       | TCP | GAME_CARRIER | Master     | —    | Master      | —    |
|  4551 | wss       | TCP | GAME_CARRIER | Game       | —    | Game        | Game |
|  9090 | wss       | TCP | PHOTON       | Master     | —    | Master      | —    |
|  9091 | wss       | TCP | PHOTON       | Game       | —    | Game        | Game |

`Net` is the transport-layer (OSI layer 4) protocol — TCP for `tcp` and `wss` listeners (WSS is WebSocket Secure over TCP), UDP for `quic`. Photon historically supports a UDP variant of the PHOTON wire protocol on ports 5055 (Master) and 5056 (Game), but FP does not use it and no UDP listener is bound in any version-controlled config.

### Notes

- **`Master S2S` on 4520** is server-to-server only — Game / Chat / Club nodes connect to it on this port. Never exposed to clients.
- **Chat and Club** have no client-facing endpoints. They use the S2S communication protocol; client chat traffic travels through Master / Game and is forwarded by Chat over S2S.
- **Master node and `GameOnMaster`**: the Master role co-hosts a Game adapter (`GameOnMaster`), so Master nodes also bind the Game endpoints.
- **Chat / Club port history.** The Chat app originally lived alone on port `4520` when the Chat node was a separate machine. AllInOne deployments later reused `4520` for Master S2S, so Chat shifted to `4521` to avoid the collision. When the Club app was added as a co-resident with Chat, it was placed on `4522` (the next free port after Chat's `4521`). On a Chat-only node, where Master S2S is absent, Chat moves back to `4520` and Club stays on `4522`. The per-role rebase of Chat is historical inertia — planned cleanup is to fix Chat at `4521` universally; tracked in the migration backlog.
- **Photon vs GameCarrier coverage.**
  - Non-Xbox Photon-based servers (Steam/EGS, PlayStation, Mobile) bind only the TCP-PHOTON endpoints (`4520`–`4531`). No WSS, no QUIC.
  - Retail Xbox (Photon-based) additionally binds WSS-PHOTON (`9090`/`9091`) via Photon's native `<WebSocketListeners>` with TLS, because MS platform certification disallows the plaintext TCP wire protocol for client traffic.
  - GameCarrier-based servers bind the TCP-PHOTON endpoints (Xbox case omits the `Game 4531` client TCP, see below) **plus** WSS-PHOTON (`9090`/`9091`), GAME_CARRIER-WSS (`4550`/`4551`) and GAME_CARRIER-QUIC (`4540`/`4541`). On GameCarrier the WSS implementation comes from the GameCarrier transport rather than Photon native.

## Per-platform variations

The layout above applies identically to every platform stack — Steam/EGS, PlayStation, Mobile, Nintendo, plus DEV/PONDDEV servers and the Yellow staging cluster — with one documented exception.

### Xbox special case

Microsoft platform certification for Xbox titles disallows the unencrypted Photon TCP wire protocol for client traffic. Xbox configs therefore drop the `Game 4531` (PHOTON tcp) client endpoint on both Master and Game nodes — Xbox clients only connect to Master / Game over WSS and QUIC. This applies regardless of host runtime:

- **Retail Xbox (Photon-based)**: WSS is provided by Photon's native `<WebSocketListeners>` on `9090`/`9091` with TLS (`Secure="true"`).
- **Current Xbox (GameCarrier-based)**: WSS for both wire protocols comes from the GameCarrier transport — `9090`/`9091` (PHOTON), `4550`/`4551` (GAME_CARRIER); QUIC adds `4540`/`4541` (GAME_CARRIER).

On a Game-only GameCarrier-based Xbox node this leaves no client-facing TCP listener at all, which the GameCarrier transport requires to keep its TCP runtime alive for S2S. To satisfy that constraint, a single dummy TCP endpoint is bound on `4520` on those nodes — not used by clients, not advertised, present purely so the TCP transport will start.

All other platforms keep the standard layout including the `Game 4531 tcp PHOTON` client endpoint.

## Canonical `vhosts[]` ordering (GameCarrier configs)

Photon and GameCarrier use different config file formats. Photon's `PhotonServer.config` (XML) groups listeners by kind under separate elements (`<TCPListeners>`, `<WebSocketListeners>`, …), each kind ordered as the author wrote it; there is no cross-kind ordering convention beyond Photon's native schema. GameCarrier's `config.json` (JSON) puts every listening endpoint into a single flat `vhosts[]` array — and we adopt a canonical sort for those entries so that diffs between platform configs reflect actual semantic differences rather than entry shuffling.

The sort for `vhosts[]` is:

1. By **`protocol`**: `PHOTON` first, `GAME_CARRIER` second.
2. Within the same protocol, by **`transport`**: `tcp` → `wss` → `quic`.
3. Within the same `(protocol, transport)`, by **`port`** ascending.

The tuple `(protocol, transport, port)` is unique within a single `vhosts[]` array (one listener per IP+port+transport), so these three keys fully order any vhost set without further tiebreaks.

Apps inside `adapters[].apps[]` and entries in `transports[]` are listed alphabetically, matching the historical Photon convention of starting apps in alphabetical order.

## Where server configs live

Configs are stored in version control along two lines, depending on environment.

### Staging and local-dev configs

Located under `Photon/src-server/Loadbalancing/Config/<env>/`. This directory holds both:

- **Staging environment configs** — one folder per staging cluster (`mobtest`, `psqa`, `yellowdev`, etc.).
- **Local developer configs** — committed for convenience so developers can share or restore their machine setups.

For staging environments that run a single AllInOne process per stack on GameCarrier, the default `config.json` shipped from the GameCarrier `artifacts` repo is used as-is — there are no env-specific GameCarrier configs in version control for staging.

### Production configs

Production configs are stored in the SoftwareDistributor configs tree and applied to nodes by SoftwareDistributor at deploy time. Photon and GameCarrier configs currently live in different subtrees:

- **Photon**: `SoftwareDistributor/Configs/<Platform>.<Role>.PhotonServer.config` and `<Platform>.<Role>.Photon.LoadBalancing.dll.config`.
- **GameCarrier**: `SoftwareDistributor/Configs/GameCarrier/<Platform>.<Role>.config.json` (one file per `(Platform, Role)` pair). The `<role>.json` manifests in the same directory tell SoftwareDistributor which file to copy to `C:\Photon\deploy\config.json` on the node, based on the node's `FarmName`.

Once the migration to GameCarrier completes, the GameCarrier subtree may be merged into the main configs directory — or the structure may be reorganised entirely. Decision deferred.
