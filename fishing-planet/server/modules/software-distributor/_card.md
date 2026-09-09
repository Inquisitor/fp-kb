---
module: software-distributor
status: stub
system: operations
code_paths:
  - SoftwareDistributor/
  - Build/Package.cmd
---

# SoftwareDistributor
> ASP.NET MVC 4.0 (.NET Framework 4.7.2) UI for server-farm lifecycle management: start/stop nodes, download and apply updates, add/remove peers, monitor status over AJAX. Runs on the distributor host (build agent 44), which also builds every production package. **Stub** — carved from the FP-43424 catalogue draft plus findings made during FP-43632; deepen when the catalogue is rolled out.

## Entry Points
- `SoftwareDistributor/SoftwareDistributor/Controllers/HomeController.cs` — farm and node management: `Index` (AJAX dashboard), `GetStatus/{nodeId}`, `DownloadUpdate(farmName)` broadcasting `CommandDownload`, `StartAll` / `StopAll` / `ApplyUpdate`, `Add(nodeId)` / `Remove(nodeId)`
- `SoftwareDistributor/DistributorCommon/Distributor.cs` — singleton loading `Distributor.json` (farms and their nodes) and broadcasting commands
- `Build/Package.cmd` — packaging step invoked by the TeamCity production build
- `SoftwareDistributor/Actions/<stack>/` — per-node cmd scripts the distributor invokes remotely (`Download`, `Apply`, `Start`, `Stop`, `Backup`, `GetStatus`, `Add`, `Remove`, plus per-app `*.Apply.cmd`); `GameCarrier/` holds the GameCarrier variants
- `SoftwareDistributor/Configs/<stack>/` — deploy manifests and per-platform configs

## Key Types
- `Farm` — a platform installation (Steam, PlayStation, XBox, Mobile, Nintendo); its name drives `%FarmName%` substitution
- `Node` — role (`RoleDist` / `RoleGame`), status, installed and downloaded version, load, peer count
- `Settings` — node role, directory layout, service names (Photon / AsyncService)
- `ScriptExecutor` — remote script invocation on nodes

## How a deployment is assembled

Manifests (`Master.json`, `Game.json`, `Chat.json`, `AllInOne.json`, …) list source-to-destination pairs and are platform-agnostic; the platform is resolved through `%FarmName%`:

```json
{
  "Name": "GameCarrier\\%FarmName%.Master.config.json",
  "Destination": "C:\\Photon\\deploy\\config.json"
}
```

Entries may declare `"Variables": "PublicIp,PublicAddress"`, which the distributor substitutes per node before delivery. Because the package carries no platform identity, one package serves every platform — the distributor picks configs by farm name and node role.

`Build/Package.cmd` publishes to three separate locations: the versioned archive `pack<N>.7z` to `C:\Shared\Pub`, `SoftwareDistributor/Actions/*` to `C:\Shared\Act`, and `SoftwareDistributor/Configs/*` to `C:\Shared\Cfg`. The two latter are wiped before copying. On the node, `Download.cmd` fetches package and configs from those separate shares; `Apply.cmd` unpacks and applies.

## Gotchas (firm)
- **Only the last build is available.** Package numbers shown as "Installed" / "Available" are TeamCity build counters, and the shares hold one current set. Different platforms therefore sit on wildly different numbers (Photon prod in the 800s, Xbox GC in the 20s, Nintendo in the 10s) purely because they are separate build configurations with separate counters.
- **Neither configs nor actions are versioned with the package.** A deployment is three artefacts — `pack<N>.7z` in `C:\Shared\Pub`, configs in `C:\Shared\Cfg`, action scripts in `C:\Shared\Act` — and only the first carries a version; the other two are wiped and rewritten by every build. Redeploying an older package pairs it with whatever the last build left in the two shares. A backup must cover all three: the package alone does not restore a working node, and a mismatched `Act` breaks Apply itself rather than merely deploying stale settings. See [backlog](backlog.md).
- **Production build configurations differ only by branch.** One build script serves all F2P platforms; separate scripts exist where a platform builds from a different SVN branch, not because the packaging differs.
- **Synchronous I/O in `Distributor.cs` constructor** — `.Result` on file load blocks on a network filesystem (from the FP-43424 catalogue; not re-verified here).

## Dependencies
- → TeamCity production build configurations; the per-node cmd scripts; `Distributor.json`
- ← every production deployment of Photon and GameCarrier stacks

## Related
- [configuration](../configuration/_card.md) — the *content* of the configs this module delivers
- `<kb>/fishing-planet/tasks/FP-43632--game-carrier-on-steam-ps-mobile-support/artifacts/teamcity-and-config-flow.md` — build pipeline and config flow audit
