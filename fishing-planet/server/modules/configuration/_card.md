---
name: configuration
system: configuration
code_paths:
  - Shared/SharedLib/Config/PlatformMapping.cs
  - SoftwareDistributor/Configs/
  - Build/Configs/
  - Photon/src-server/Loadbalancing/Config/
---

# configuration

Per-environment / per-component server configuration, with focus on the `Source` (platform list) setting that gates product loading and platform support across all server roles.

## Entry Points

- `PlatformMapping.Initialize(source)` — `Shared/SharedLib/Config/PlatformMapping.cs` — parses `Source` into `SupportedPlatformIds`; called at startup by every component.
- `MasterServerSettings` / `GameServerSettings` / `ChatServerSettings` `.Default.Source` — Photon servers (applicationSettings `<setting name="Source">`).
- WebAdmin `Settings.Source` + AsyncProcessor `Settings.Source` — appSettings `<add key="Source">`.

## Key Types

- `PlatformMapping` — static `SupportedPlatformIds` / `Source` / `defaultPlatformId` / `platformIdOverride`; instance ctor resolves per-request `PlatformId` (only when override is null, i.e. multi-value `Source`).
- AsyncProcessor `Settings.PlatformId` — single platform (default Steam), drives platform-specific jobs; **distinct from `Source`**.

## Dependencies

- → `MonetizationCache.LoadProducts` filters products by `SupportedPlatformIds` → feeds `ProductAccessibleLevels` (null-AccessibleLevel is the FP-44134 root cause)
- ← consumed at startup by Photon Master/Game/Chat, WebAdmin, AsyncProcessor

## Deep Dives

- [source-platform-config.md](source-platform-config.md) — `Source` semantics, the two config formats, deployment topology (GameOnMaster / AllInOne / deploy.cmd), production reference matrix, RetailXBox `Win10` anomaly history, canonical per-env rules.

## Related Tasks

- [[review FP-44134]] — TEST WebAdmin `Source="Steam"` (no Epic) → null AccessibleLevel → pond-pass duplicate; fixed r16130 (`Steam,Epic`). Surfaced the broader cross-component `Source` non-uniformity.
