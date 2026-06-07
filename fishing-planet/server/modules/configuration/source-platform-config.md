# Source / Platform Configuration — Deep Dive

How the `Source` setting drives platform support across every server component, how the configs are laid out per environment, and the canonical per-environment values derived from the production reference.

## `Source` semantics

`Source` is a comma-separated list of **platforms a component serves** (not "where a purchase came from"). At startup each component calls `PlatformMapping.Initialize(source)` (`Shared/SharedLib/Config/PlatformMapping.cs`):

- **multi-value** (contains `,`): `platformIdOverride = null`; `SupportedPlatformIds = [all listed]`; `defaultPlatformId = first listed`. The `PlatformMapping(source, country)` instance ctor then resolves `PlatformId` from the per-request `source` argument.
- **single-value**: `platformIdOverride = <that platform>`; `SupportedPlatformIds = [that]`. The ctor **ignores** its `source` argument and always returns the override.
- empty → throws `InvalidOperationException`; unknown token → throws.

### Why it matters (FP-44134 chain)

`Source` → `SupportedPlatformIds` is the filter for `MonetizationCache.LoadProducts` (`GetProductsCache(SupportedPlatformIds, lang)`). `LoadProductsAccessibleLevels` then iterates only the already-filtered product cache, so a platform missing from `Source` means its products carry **no AccessibleLevel entry** → `GetProductAccessibleLevel(productId)` returns `null` → a granted pond-pass `LevelLockRemoval` gets `AccessibleLevel = null` → the merge lookup in `ProfileHelper.PutProductToProfile` (requires `AccessibleLevel != null`) cannot match it → a **parallel** record is created instead of summing days. See [[review FP-44134]].

## Components that consume `Source`

| Component                | Settings accessor                     | Config section / key                              | Config file                                                 |
|--------------------------|---------------------------------------|---------------------------------------------------|-------------------------------------------------------------|
| Photon Master            | `MasterServerSettings.Default.Source` | `<applicationSettings>` `<setting name="Source">` | `…/Config/<env>/Master/bin/Photon.LoadBalancing.dll.config` |
| Photon Game (×N)         | `GameServerSettings.Default.Source`   | same                                              | `…/Config/<env>/GameServer{1,2}/bin/…`                      |
| Photon Chat              | `ChatServerSettings.Default.Source`   | same                                              | `…/Config/<env>/Chat/bin/…`                                 |
| WebAdmin                 | `Settings.Source`                     | `<appSettings>` `<add key="Source">`              | `Build/Configs/WebAdmin/<Env>.Web.config`                   |
| AsyncProcessor           | `Settings.Source`                     | `<appSettings>` `<add key="Source">`              | `Build/Configs/Async/<Env>.AsyncProcessor.exe.config`       |
| ReleaseTool (build tool) | `Settings.Source`                     | `<appSettings>`                                   | `SoftwareDistributor/Configs/<Plat>.ReleaseTool.exe.config` |

**Two formats**: Photon uses `<setting name="Source"><value>…</value>`; WebAdmin/Async use `<add key="Source" value="…"/>`. Any scan must cover both.

### AsyncProcessor's separate single-platform `PlatformId`

AsyncProcessor (and other components) also read `Settings.PlatformId` (`<add key="PlatformId">`, single int, default Steam=1). This drives **platform-specific scheduled jobs** (`AsyncProcessorScheduleExecutor`): `SteamRefundProcessorJob` when `PlatformId==Steam`, `PlayStationAccountClosureJob` when `==PlayStation`. It is independent of `Source`.

**AsyncProcessor has no product-delivery path** — no `PutProductToProfile` / `LevelLockRemoval` / `AccessibleLevel` references anywhere. Its monetization jobs are analytics (`DetectBundlePurchasesJob` → `MarkAsBundle`) and revocation (`SteamRefundProcessorJob`, `AndroidVoidedPurchasesProcessorJob`). So widening Async `Source` does NOT fix any delivery bug; it is config-hygiene only. The FP-44134 delivery path lives on Game Server + WebAdmin grant.

## Deployment topology

- **GameOnMaster**: Game + Master on one machine. Introduced because the master app underutilizes the master box, so a Game instance runs there too. `GameOnMaster.…dll.config` carries the same `Source` as Game.
- **AllInOne**: everything on one box — Master, Game, Chat, Club, WebAdmin, Async. Retail prod deploys this way; most test/staging envs too (often incl. SQL Server on the same box). Retail DB is believed to be separate.
- Photon configs deploy from `Photon/src-server/Loadbalancing/Config/<lowercase-env>/…/bin/Photon.LoadBalancing.dll.config` to `C:\Photon` via `deploy.cmd` / `deploy-fast.cmd`.
- `Build/Configs/` holds per-env Async + WebAdmin (+ Web, Tests) with the env name in the filename (mixed case). Much of `Build/Configs` is stale; only Async + WebAdmin are in scope. "остальное старьё".
- `SoftwareDistributor/Configs/` = **production**, one folder, named per **platform** (not env-name): `Steam`, `PlayStation`, `XBox`, `Nintendo`, `Mobile`, `RetailSteam`, `RetailPlayStation`, `RetailXBox`. Treated as the reference / etalon (single folder, live values).

> Env-name mapping caveat: Photon folders are lowercase (`test`, `test2`, `qa`); WebAdmin/Async filenames are mixed-case (`Test`, `TEST2`, `QA`). Match by normalized name when auditing.

## Production reference (SoftwareDistributor) — etalon

| Platform          | Photon (Master/Game/GoM/Chat) | WebAdmin         | Async            | ReleaseTool     | Uniform |
|-------------------|-------------------------------|------------------|------------------|-----------------|---------|
| Steam             | `Steam,Epic`                  | `Steam,Epic`     | `Steam,Epic`     | `Steam,Epic`    | yes     |
| PlayStation       | `PlayStation`                 | `PlayStation`    | `PlayStation`    | `PlayStation`   | yes     |
| XBox              | `XBox,Win10`                  | `XBox,Win10`     | `XBox,Win10`     | `XBox,Win10`    | yes     |
| Nintendo          | `Nintendo`                    | `Nintendo`       | `Nintendo`       | `Nintendo`      | yes     |
| Mobile            | `Apple,Android`               | `Apple,Android`  | `Apple,Android`  | `Apple,Android` | yes     |
| RetailSteam       | `Steam`                       | `Steam`          | `Steam`          | —               | yes     |
| RetailPlayStation | `PlayStation`                 | `PlayStation`    | `PlayStation`    | —               | yes     |
| RetailXBox        | `XBox`                        | **`XBox,Win10`** | **`XBox,Win10`** | —               | **NO**  |

Notes:
- PC prod (Steam) = `Steam,Epic` with **no Apple** — this is the PC canon. Staging PC envs carrying `Steam,Apple,Epic` have a stray Apple.
- Retail carries **no Epic and no Win10** — retail builds ship neither (last serious retail release 2021 from the MI branch).
- `M.RU` (mail.ru) and `Tencent` are never-launched / decommissioned platforms; absent from all prod configs. `M.RU` lingers only in staging GC (Web + Async); `Tencent` is in no current config `Source` value.
- RetailXBox WebAdmin/Async `XBox,Win10` was an anomaly — **fixed 2026-06 [MFT] → `XBox`** (see History).

## History: RetailXBox `Win10` anomaly

- Photon retail-Xbox `Source` = `XBox` since **r7004 (ivan)**, never changed; MI/2020 identical.
- MI/2020 RetailXBox WebAdmin/Async had **only** `PlatformId=3`, no multi-platform `Source`.
- The multi-platform `Source` key was rolled into WebAdmin/Async after the MI era; RetailXBox was given `XBox,Win10` copied from the **digital XBox** template — a copy/paste error (retail ships on neither Win10/Microsoft Store nor Epic).
- Present across all current branches (IMV already had it by 2025-02; KNW/LBM/MFT inherit via branch copy).
- **r15382** (dmytro.kurylovych, 2025-11-27, `ReplaceTabsInAppSettings` tool over STAGING+PROD) only mechanically rewrote the line — it is the `svn blame` top but NOT the value origin.
- **Canonical target**: RetailXBox WebAdmin/Async → `XBox` (match the Photon side). **Applied 2026-06 [MFT]** in `SoftwareDistributor/Configs/RetailXBox.{WebAdmin.Web,AsyncProcessor.exe}.config`.

## Canonical rules (per-environment target)

| Env type                                 | Target `Source` (all components)          |
|------------------------------------------|-------------------------------------------|
| PC (Steam/Epic) — incl. PondDev          | `Steam,Epic`                              |
| Master base `DEV`, Code-branch `Yellow*` | all platforms (intentional, for dev)      |
| Console / Mobile staging                 | match the corresponding prod platform set |
| Retail                                   | platform only — no `Win10`, no `Epic`     |
| `M.RU` (mail.ru), `Tencent` — dead       | remove                                    |

Within a single environment, every component (Master / Game / Chat / Club / WebAdmin / Async) must carry the **same** `Source`.
