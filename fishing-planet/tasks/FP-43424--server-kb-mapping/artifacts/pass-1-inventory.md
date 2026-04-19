# Pass 1 — Inventory

Branch at inventory time: `LBM20251201` r`16012` (Last Changed Rev, 2026-04-15)

Note: LBM is the Content branch; used here as Code-proxy since MFT took Code role on 2026-04-06 and structural
divergence at inventory level is minimal. Re-check against MFT starts in Pass 2.

Totals: **15 solutions**, **101 `.csproj` files** (excluding `obj`/`bin`).

Completeness verified via `find` + `diff`: all 15 `.sln` and 101 `.csproj` paths under the branch appear in this
artifact, and every path in the artifact resolves to a real file.

Project counts below = non-folder `Project(` entries in the `.sln` (solution folders with GUID `{2150E333-…-46DE8}`
filtered out).

## Solutions

| Solution            | Path                                                      | Projects count |
|---------------------|-----------------------------------------------------------|----------------|
| LoadBalancing       | `Photon\src-server\Loadbalancing\LoadBalancing.sln`       | 71             |
| WebAdmin            | `WebAdmin\WebAdmin.sln`                                   | 30             |
| AsyncProcessor      | `AsyncProcessor\AsyncProcessor.sln`                       | 29             |
| WebTranslator       | `WebAdmin\WebTranslator.sln`                              | 19             |
| Twitch              | `Twitch\Twitch.sln`                                       | 5              |
| DataPump            | `Photon\tools\DataPump\DataPump\DataPump.sln`             | 3              |
| XblApiTest          | `Shared\XblRestApi\XblApiTest.sln`                        | 3              |
| SoftwareDistributor | `SoftwareDistributor\SoftwareDistributor.sln`             | 2              |
| MaintenanceManager  | `Photon\tools\MaintenanceManager\MaintenanceManager.sln`  | 2              |
| Updater             | `Updater\Updater.sln`                                     | 2              |
| CounterPublisher    | `Photon\src-server\CounterPublisher\CounterPublisher.sln` | 1              |
| AlterIdentity       | `Photon\tools\AlterIdentity\AlterIdentity.sln`            | 1              |
| EmailGenerator      | `Photon\tools\EmailGenerator\EmailGenerator.sln`          | 1              |
| PhotonTool          | `Photon\tools\PhotonHelper\PhotonTool.sln`                | 1              |
| WebHooks            | `WebServices\WebHooks\WebHooks.sln`                       | 1              |

## Projects

### Photon server core (`Photon\src-server\`)

| Project                  | Path                                                                             | Type       | Nature | Notes                                                                   |
|--------------------------|----------------------------------------------------------------------------------|------------|--------|-------------------------------------------------------------------------|
| LoadBalancing            | `Photon\src-server\Loadbalancing\LoadBalancing\LoadBalancing.csproj`             | production | module | Main runtime host — MasterServer / GameServer / ChatServer / ClubServer |
| LoadBalancing.Tests      | `Photon\src-server\Loadbalancing\LoadBalancing.Tests\LoadBalancing.Tests.csproj` | tests      | tests  | MSTest suite for LoadBalancing                                          |
| Loadbalancing.TestClient | `Photon\src-server\Loadbalancing\TestClient\Loadbalancing.TestClient.csproj`     | tool       | tool   | Console test client                                                     |
| GameModel                | `Photon\src-server\GameModel\GameModel.csproj`                                   | production | module | Fish / rod / hook game-simulation models                                |
| GameModel.Tests          | `Photon\src-server\GameModel.Tests\GameModel.Tests.csproj`                       | tests      | tests  | Tests for GameModel                                                     |
| AntiCheat                | `Photon\src-server\AntiCheat\AntiCheat.csproj`                                   | production | module | Anti-cheat subsystem                                                    |
| CounterPublisher         | `Photon\src-server\CounterPublisher\CounterPublisher.csproj`                     | production | module | Performance counter publisher (own sln)                                 |
| LoadBalancing.TestBot    | `Photon\src-server\LoadBalancing.TestBot\LoadBalancing.TestBot.csproj`           | tool       | tool   | Load-generation bot                                                     |

### Photon tools (`Photon\tools\`)

| Project                   | Path                                                                      | Type  | Nature | Notes                          |
|---------------------------|---------------------------------------------------------------------------|-------|--------|--------------------------------|
| AlterIdentity             | `Photon\tools\AlterIdentity\AlterIdentity.csproj`                         | tool  | tool   | Own sln                        |
| Chat                      | `Photon\tools\Chat\Chat.csproj`                                           | tool  | tool   | ?                              |
| ClubServiceTester         | `Photon\tools\ClubServiceTester\ClubServiceTester.csproj`                 | tool  | tool   | Manual tester for club service |
| ConfigTool                | `Photon\tools\ConfigTool\ConfigTool.csproj`                               | tool  | tool   | Config edit/validation         |
| CountWords                | `Photon\tools\CountWords\CountWords.csproj`                               | tool  | tool   | Text utility                   |
| DataChangesImport         | `Photon\tools\DataChangesImport\DataChangesImport.csproj`                 | tool  | tool   | Data migration helper          |
| DataDumper                | `Photon\tools\DataDumper\DataDumper.csproj`                               | tool  | tool   | DB dump utility                |
| DataPump                  | `Photon\tools\DataPump\DataPump\DataPump.csproj`                          | tool  | tool   | Own sln; data pipeline         |
| DbMergeTool               | `Photon\tools\DbMergeTool\DbMergeTool.csproj`                             | tool  | tool   | CLI DB merge                   |
| DbMergeToolGui            | `Photon\tools\DbMergeToolGui\DbMergeToolGui.csproj`                       | tool  | tool   | GUI DB merge                   |
| EmailGenerator            | `Photon\tools\EmailGenerator\EmailGenerator.csproj`                       | tool  | tool   | Own sln                        |
| EnvironmentSwitcher       | `Photon\tools\EnvironmentSwitcher\EnvironmentSwitcher.csproj`             | tool  | tool   | Env profile switcher           |
| GcTest                    | `Photon\tools\GcTest\GcTest.csproj`                                       | tool  | tool   | GC/perf test                   |
| ImageDumper               | `Photon\tools\ImageDumper\ImageDumper.csproj`                             | tool  | tool   | Image extraction               |
| MaintenanceManager        | `Photon\tools\MaintenanceManager\MaintenanceManager.csproj`               | tool  | tool   | Own sln                        |
| MongoExport               | `Photon\tools\MongoExport\MongoExport.csproj`                             | tool  | tool   | Mongo data export              |
| OfflineChatMessagesImport | `Photon\tools\OfflineChatMessagesImport\OfflineChatMessagesImport.csproj` | tool  | tool   | Offline chat import            |
| PerfCounterManager        | `Photon\tools\PerfCounterManager\PerfCounterManager.csproj`               | tool  | tool   | Perf counter CLI               |
| PhotonTool                | `Photon\tools\PhotonHelper\PhotonHelper\PhotonTool.csproj`                | tool  | tool   | Own sln                        |
| PondJsonExporter          | `Photon\tools\PondJsonExporter\PondJsonExporter.csproj`                   | tool  | tool   | Pond JSON exporter             |
| ReleaseTool               | `Photon\tools\ReleaseTool\ReleaseTool\ReleaseTool.csproj`                 | tool  | tool   | Release pipeline helper        |
| ReleaseTool.Tests         | `Photon\tools\ReleaseTool.Tests\ReleaseTool.Tests.csproj`                 | tests | tests  | Tests for ReleaseTool          |
| ServiceControl            | `Photon\tools\ServiceControl\ServiceControl.csproj`                       | tool  | tool   | Service start/stop CLI         |
| SqlCheck                  | `Photon\tools\SqlCheck\SqlCheck.csproj`                                   | tool  | tool   | SQL lint/check                 |
| TournamentAudit           | `Photon\tools\TournamentAudit\TournamentAudit\TournamentAudit.csproj`     | tool  | tool   | Tournament integrity audit     |
| TwitchApiTester           | `Photon\tools\TwitchApiTester\TwitchApiTester.csproj`                     | tool  | tool   | Twitch API manual tester       |
| XBoxCertChecker           | `Photon\tools\XBoxCertChecker\XBoxCertChecker.csproj`                     | tool  | tool   | Xbox cert validation           |
| XblApiTester              | `Photon\tools\XblApiTester\XblApiTester.csproj`                           | tool  | tool   | Xbox Live API tester           |
| XstsTester                | `Photon\tools\XstsTester\XstsTester.csproj`                               | tool  | tool   | XSTS token tester              |

### Shared libraries (`Shared\`)

| Project           | Path                                                         | Type       | Nature        | Notes                                                                      |
|-------------------|--------------------------------------------------------------|------------|---------------|----------------------------------------------------------------------------|
| ObjectModel       | `Shared\ObjectModel\ObjectModel.csproj`                      | production | module        | Core domain model — fish, inventory, profiles, tournaments, etc.           |
| ObjectModel.Tests | `Shared\ObjectModel.Tests\ObjectModel.Tests.csproj`          | tests      | tests         |                                                                            |
| SharedLib         | `Shared\SharedLib\SharedLib.csproj`                          | production | module        | Business logic: achievements, balance, clubs, leaderboards, missions, etc. |
| SharedLib.Tests   | `Shared\SharedLib.Tests\SharedLib.Tests.csproj`              | tests      | tests         |                                                                            |
| BiteSystem        | `Shared\BiteSystem\BiteSystem.csproj`                        | production | module        | Fish bite / catch mechanics                                                |
| BiteSystem.Tests  | `Shared\BiteSystem.Tests\BiteSystem.Tests.csproj`            | tests      | tests         |                                                                            |
| DT                | `Shared\DT\DT.csproj`                                        | production | module        | Data Tables system                                                         |
| Photon.Interfaces | `Shared\Photon.Interfaces\Photon.Interfaces.csproj`          | infra      | cross-cutting | RPC interface contracts                                                    |
| Notifications     | `Shared\Notifications\Notifications.csproj`                  | production | module        | Push notification delivery                                                 |
| DataEditing       | `Shared\DataEditing\DataEditing.csproj`                      | tool       | tool          | Data editing helpers                                                       |
| StandaloneClient  | `Shared\StandaloneClient\StandaloneClient.csproj`            | tool       | tool          | Standalone client lib                                                      |
| Lite              | `Shared\Lite\Lite\Lite.csproj`                               | production | module        | Lite variant                                                               |
| Denuvo            | `Shared\Denuvo\Denuvo.csproj`                                | production | module        | DRM integration                                                            |
| Denuvo.Tests      | `Shared\Denuvo.Tests\Denuvo.Tests.csproj`                    | tests      | tests         |                                                                            |
| Twitch (Shared)   | `Shared\Twitch\Twitch.csproj`                                | production | module        | Twitch integration (lib, distinct from `Twitch\` top-level)                |
| Twitch.Tests      | `Shared\Twitch.Tests\Twitch.Tests.csproj`                    | tests      | tests         |                                                                            |
| Steamworks        | `Shared\Steamworks\Steamworks.csproj`                        | production | module        | Steam platform SDK adapter                                                 |
| Streamworks.Tests | `Shared\Streamworks.Tests\Streamworks.Tests.csproj`          | tests      | tests         | Tests for Steamworks (name typo carried from code)                         |
| Epic              | `Shared\Epic\Epic.csproj`                                    | production | module        | Epic Games SDK adapter                                                     |
| Nintendo          | `Shared\Nintendo\Nintendo.csproj`                            | production | module        | Nintendo Switch SDK adapter                                                |
| Xb1Utils          | `Shared\Xb1Utils\Xb1Utils.csproj`                            | production | module        | Xbox One SDK adapter                                                       |
| Apple             | `Shared\Apple\Apple.csproj`                                  | production | module        | Apple platform SDK adapter                                                 |
| Android           | `Shared\Android\Android.csproj`                              | production | module        | Android platform SDK adapter                                               |
| XblApiHelper      | `Shared\XblRestApi\XblApiHelper\XblApiHelper.csproj`         | production | module        | Xbox Live REST API helper                                                  |
| XblApiHelperTest  | `Shared\XblRestApi\XblApiHelperTest\XblApiHelperTest.csproj` | tests      | tests         |                                                                            |

### Data Access Layer (`Dal\`)

| Project           | Path                                             | Type       | Nature        | Notes                      |
|-------------------|--------------------------------------------------|------------|---------------|----------------------------|
| DalAbstraction    | `Dal\DalAbstraction\DalAbstraction.csproj`       | infra      | cross-cutting | Core DAL interfaces        |
| Dal.Common        | `Dal\Dal.Common\Dal.Common.csproj`               | infra      | cross-cutting | Common DAL utilities       |
| DalUtilities      | `Dal\DalUtilities\DalUtilities.csproj`           | infra      | cross-cutting | DAL utilities              |
| Dal.Log           | `Dal\Dal.Log\Dal.Log.csproj`                     | infra      | cross-cutting | DAL logging                |
| Sql.Interface     | `Dal\Sql.Interface\Sql.Interface.csproj`         | infra      | cross-cutting | SQL interface contracts    |
| Sql.MsSql         | `Dal\Sql.MsSql\Sql.MsSql.csproj`                 | production | module        | SQL Server backend         |
| Sql.MsSql.Tests   | `Dal\Sql.MsSql.Tests\Sql.MsSql.Tests.csproj`     | tests      | tests         |                            |
| NoSql.Interface   | `Dal\NoSql.Interface\NoSql.Interface.csproj`     | infra      | cross-cutting | NoSQL interface contracts  |
| NoSql.Mongo       | `Dal\NoSql.Mongo\NoSql.Mongo.csproj`             | production | module        | MongoDB backend            |
| NoSql.Mongo.Tests | `Dal\NoSql.Mongo.Tests\NoSql.Mongo.Tests.csproj` | tests      | tests         |                            |
| NoSql.FileStorage | `Dal\NoSql.FileStorage\NoSql.FileStorage.csproj` | production | module        | File storage NoSQL backend |
| Dal.Common.Tests  | `Dal\Dal.Common.Tests\Dal.Common.Tests.csproj`   | tests      | tests         |                            |

### AsyncProcessor (`AsyncProcessor\`)

| Project             | Path                                                            | Type       | Nature        | Notes                          |
|---------------------|-----------------------------------------------------------------|------------|---------------|--------------------------------|
| AsyncProcessor      | `AsyncProcessor\AsyncProcessor\AsyncProcessor.csproj`           | production | module        | Main async job processor (exe) |
| AsyncProcessor.Test | `AsyncProcessor\AsyncProcessor.Test\AsyncProcessor.Test.csproj` | tests      | tests         |                                |
| AsyncCommon         | `AsyncProcessor\Async.Common\AsyncCommon.csproj`                | infra      | cross-cutting | Shared async infra             |
| AsyncTranslator     | `AsyncProcessor\AsyncTranslator\AsyncTranslator.csproj`         | production | module        | Translation service (exe)      |
| AsyncFarmManager    | `AsyncProcessor\AsyncFarmManager\AsyncFarmManager.csproj`       | production | module        | Farm management service (exe)  |

### WebAdmin (`WebAdmin\`)

| Project           | Path                                                  | Type       | Nature | Notes                                     |
|-------------------|-------------------------------------------------------|------------|--------|-------------------------------------------|
| WebAdmin          | `WebAdmin\WebAdmin\WebAdmin.csproj`                   | production | module | Main admin portal (ASP.NET MVC 4.0-style) |
| WebAdmin.Tests    | `WebAdmin\WebAdmin.Tests\WebAdmin.Tests.csproj`       | tests      | tests  | SDK-style                                 |
| WebService        | `WebAdmin\WebService\WebService.csproj`               | production | module | Internal web service endpoints            |
| Dashboard         | `WebAdmin\Dashboard\Dashboard.csproj`                 | production | module | Dashboard MVC app                         |
| DataSyncDashboard | `WebAdmin\DataSyncDashboard\DataSyncDashboard.csproj` | production | module | Data sync dashboard MVC app               |
| WebTranslate      | `WebAdmin\WebTranslate\WebTranslate.csproj`           | production | module | Translation portal (WebTranslator.sln)    |
| RepositoryService | `WebAdmin\RepositoryService\RepositoryService.csproj` | production | module | Repository service                        |
| JsonVerificator   | `WebAdmin\JsonVerificator\JsonVerificator.csproj`     | tool       | tool   | JSON validation utility                   |
| ProfileUtils      | `WebAdmin\ProfileUtils\ProfileUtils.csproj`           | tool       | tool   | Profile helper CLI                        |

### SoftwareDistributor (`SoftwareDistributor\`)

| Project             | Path                                                                 | Type       | Nature        | Notes                          |
|---------------------|----------------------------------------------------------------------|------------|---------------|--------------------------------|
| SoftwareDistributor | `SoftwareDistributor\SoftwareDistributor\SoftwareDistributor.csproj` | production | module        | ASP.NET MVC distributor portal |
| DistributorCommon   | `SoftwareDistributor\DistributorCommon\DistributorCommon.csproj`     | infra      | cross-cutting | Shared distributor types       |
| DistributorAsync    | `SoftwareDistributor\DistributorCommon\DistributorAsync.csproj`      | infra      | cross-cutting | Distributor async helpers      |

### Twitch & OAuth (`Twitch\`)

| Project                           | Path                                                                                | Type       | Nature | Notes                                |
|-----------------------------------|-------------------------------------------------------------------------------------|------------|--------|--------------------------------------|
| TwitchAccountLinking              | `Twitch\TwitchAccountLinking\TwitchAccountLinking.csproj`                           | production | module | ASP.NET Core account linking service |
| AspNet.Security.OAuth.Epic        | `Twitch\AspNet.Security.OAuth.Epic\AspNet.Security.OAuth.Epic.csproj`               | production | module | Epic OAuth provider                  |
| AspNet.Security.OAuth.Nintendo    | `Twitch\AspNet.Security.OAuth.Nintendo\AspNet.Security.OAuth.Nintendo.csproj`       | production | module | Nintendo OAuth provider              |
| AspNet.Security.OAuth.PlayStation | `Twitch\AspNet.Security.OAuth.PlayStation\AspNet.Security.OAuth.PlayStation.csproj` | production | module | PlayStation OAuth provider           |
| AspNet.Security.OAuth.XBox        | `Twitch\AspNet.Security.OAuth.XBox\AspNet.Security.OAuth.XBox.csproj`               | production | module | Xbox OAuth provider                  |

### Updater (`Updater\`)

| Project      | Path                                       | Type       | Nature | Notes               |
|--------------|--------------------------------------------|------------|--------|---------------------|
| Patcher      | `Updater\Patcher\Patcher.csproj`           | production | module | Patcher entry point |
| Updater.Core | `Updater\Updater.Core\Updater.Core.csproj` | production | module | Update engine core  |

### Web services (`WebServices\`)

| Project  | Path                                            | Type       | Nature | Notes                         |
|----------|-------------------------------------------------|------------|--------|-------------------------------|
| WebHooks | `WebServices\WebHooks\WebHooks\WebHooks.csproj` | production | module | ASP.NET Core webhooks service |

### SQL patches (`SQL\`)

| Project           | Path                                         | Type  | Nature | Notes                    |
|-------------------|----------------------------------------------|-------|--------|--------------------------|
| Sql.Patches.Main  | `SQL\Patches\Main\Sql.Patches.Main.csproj`   | infra | config | Main DB patch container  |
| Sql.Patches.Stats | `SQL\Patches\Stats\Sql.Patches.Stats.csproj` | infra | config | Stats DB patch container |

## Key subfolders (2 levels deep under big projects)

### `Photon\src-server\Loadbalancing\LoadBalancing\` (main host)

| Path                             | Nature        | Purpose signal                      |
|----------------------------------|---------------|-------------------------------------|
| `…\LoadBalancing\Auth`           | module-part   | Authentication handling             |
| `…\LoadBalancing\Caching`        | cross-cutting | Caching infrastructure              |
| `…\LoadBalancing\ChatServer`     | module-part   | Chat server implementation          |
| `…\LoadBalancing\ClubServer`     | module-part   | Club/guild server implementation    |
| `…\LoadBalancing\CommandLine`    | cross-cutting | CLI arg processing                  |
| `…\LoadBalancing\Common`         | infra         | Shared utilities                    |
| `…\LoadBalancing\DalAdapters`    | cross-cutting | DAL adapters                        |
| `…\LoadBalancing\Diagrams`       | generated     | Diagram resources                   |
| `…\LoadBalancing\Events`         | cross-cutting | Event handling                      |
| `…\LoadBalancing\GameLogic`      | module-part   | Fishing session logic (main domain) |
| `…\LoadBalancing\GameServer`     | module-part   | Game server implementation          |
| `…\LoadBalancing\Helpers`        | cross-cutting | Helper utilities                    |
| `…\LoadBalancing\LoadBalancer`   | module-part   | Load balancer core                  |
| `…\LoadBalancing\LoadShedding`   | module-part   | Load shedding                       |
| `…\LoadBalancing\MasterServer`   | module-part   | Master server implementation        |
| `…\LoadBalancing\Monetization`   | module-part   | Monetization logic                  |
| `…\LoadBalancing\Operations`     | cross-cutting | Operation definitions               |
| `…\LoadBalancing\Properties`     | generated     | Assembly info                       |
| `…\LoadBalancing\ServerToServer` | module-part   | S2S communication                   |
| `…\LoadBalancing\Tops`           | module-part   | Tops/rankings                       |

### `Photon\src-server\Loadbalancing\` (other)

| Path                                                                                                                        | Nature | Purpose signal                                                                |
|-----------------------------------------------------------------------------------------------------------------------------|--------|-------------------------------------------------------------------------------|
| `…\Loadbalancing\Config\*` (~60 subdirs)                                                                                    | config | Per-environment configs (prod, qa, dev, nxtest, xbcert, user-home configs, …) |
| `…\Loadbalancing\LoadBalancing.Tests\{Client,Core,DailyMissions,DalAdapters,GameLogicTests,Inventory,NavBuoys,Radar,Stats}` | tests  | Test suites                                                                   |
| `…\Loadbalancing\TestClient\{ConnectionStates,Const,Properties,Stats}`                                                      | tool   | Test client internals                                                         |

### `Photon\src-server\` (non-Loadbalancing)

| Path                                                          | Nature      | Purpose signal               |
|---------------------------------------------------------------|-------------|------------------------------|
| `Photon\src-server\GameModel\{Fish,Converters,Helpers,Stats}` | module-part | Game-simulation internals    |
| `Photon\src-server\LoadBalancing.TestBot\Properties`          | generated   | Assembly info                |
| `Photon\src-server\AntiCheat\` (flat)                         | module      | ~10 `.cs` files, flat layout |
| `Photon\src-server\CounterPublisher\` (flat)                  | module      | ~5 `.cs` files, own sln      |

### `Shared\` (1-level + 2-level under big libs)

| Path                                                                                                                                                                                                                                                                                                                                       | Nature       | Purpose signal                                                                    |
|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------|-----------------------------------------------------------------------------------|
| `Shared\ObjectModel\{Balance,Characters,Chat,Clubs,Common,Configuration,DailyMissions,Debug,Diagnostics,Fish,FishCage,Fortune,Game,Helpers,Hint,Interactive,Inventory,Leaderboards,Leagues,Localization,Mission,Monetization,Profile,Push,Radar,Randomization,RateUs,RodSetup,Serialization,Skins,Stats,Together,Tops,Tournaments,Travel}` | module-part  | Domain model sub-areas (~34 folders)                                              |
| `Shared\SharedLib\{AbTests,Achievements,Async,Balance,Caching,Clubs,Config,CurrencyExchange,DailyMissions,Device,Diagnostics,FarmReboots,Fortune,Game,Helpers,Leaderboards,Leagues,Licenses,Logging,MeasuringUnits,Missions,Monetization,Payments,Profile,Push,Radar,Rewards,Shop,TargetedAds,Together,Tournaments,Travel,Web}`            | module-part  | Business logic sub-areas (~33 folders)                                            |
| `Shared\Photon.Interfaces\{Auth,Chat,Fortune,Game,Inventory,LeaderBoards,Leagues,Monetization,MultiRods,NavBuoys,Profile,Push,RateUs,SharedMethods,SkinElements,Sys,Together,Tournaments}`                                                                                                                                                 | module-part  | RPC contracts per feature area                                                    |
| `Shared\BiteSystem\{Common,ServerOnly}`                                                                                                                                                                                                                                                                                                    | module-part  | Bite logic split                                                                  |
| `Shared\DataEditing\{Db,Metadata,Serialization}`                                                                                                                                                                                                                                                                                           | module-part  | Data editing internals                                                            |
| `Shared\Steamworks\`, `Shared\Epic\`, `Shared\Nintendo\`, `Shared\Xb1Utils\`, `Shared\Apple\`, `Shared\Android\`                                                                                                                                                                                                                           | module       | Platform SDK adapters (with `CertificateHelpers`, `Types`, `Models`, etc. inside) |
| `Shared\XblRestApi\{XblApiHelper,XblApiHelperTest}`                                                                                                                                                                                                                                                                                        | module/tests | Xbox Live REST API lib + tests (own sln)                                          |
| `Shared\Lite\Lite\`                                                                                                                                                                                                                                                                                                                        | module       | Lite variant (nested)                                                             |
| `Shared\StandaloneClient\{Helpers,Models}`                                                                                                                                                                                                                                                                                                 | module-part  | Standalone client internals                                                       |

### `Dal\` (2-level)

| Path                                                                                                                                                                                                                                                                             | Nature      | Purpose signal                                        |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------|-------------------------------------------------------|
| `Dal\Sql.Interface\{Analytics,Async,Chat,Club,Common,CurrencyExchange,Data,Device,DisconnectSignal,Fortune,Game,Images,Interactive,Leaderboards,Leagues,Log,Mission,Monetization,Notification,Profile,Push,Rooms,Shop,Skins,Stats,Sys,Together,Tops,Tournaments,Travel,Weather}` | module-part | SQL interface contracts per domain area (~31 folders) |
| `Dal\Sql.MsSql\{same ~29 domain subfolders}`                                                                                                                                                                                                                                     | module-part | SQL Server implementations mirroring Sql.Interface    |
| `Dal\Sql.MsSql.Tests\{Async,Chat,Common,Together,Utils}`                                                                                                                                                                                                                         | tests       | MSSQL test suites                                     |
| `Dal\NoSql.Interface\{Async,Chat,Diag,Log,OnlineCash}`                                                                                                                                                                                                                           | module-part | NoSQL interface contracts                             |
| `Dal\NoSql.Mongo\{Chat,Common,Diag,Log,OnlineCash}`                                                                                                                                                                                                                              | module-part | Mongo implementations mirroring NoSql.Interface       |
| `Dal\Dal.Common\Stats`, `Dal\Dal.Log\{Async,Common,Logs}`                                                                                                                                                                                                                        | module-part | DAL support areas                                     |

### `WebAdmin\WebAdmin\` (main admin project — 1 level)

| Path                            | Nature        | Purpose signal      |
|---------------------------------|---------------|---------------------|
| `WebAdmin\WebAdmin\App_Data`    | config        | Data storage        |
| `WebAdmin\WebAdmin\App_Start`   | config        | Startup wiring      |
| `WebAdmin\WebAdmin\Components`  | module        | Razor components    |
| `WebAdmin\WebAdmin\Content`     | config        | CSS/static assets   |
| `WebAdmin\WebAdmin\Controllers` | module-part   | MVC controllers     |
| `WebAdmin\WebAdmin\Filters`     | cross-cutting | Action/auth filters |
| `WebAdmin\WebAdmin\Helpers`     | cross-cutting | Helpers             |
| `WebAdmin\WebAdmin\Migrations`  | generated     | EF migrations       |
| `WebAdmin\WebAdmin\Models`      | module-part   | Models              |
| `WebAdmin\WebAdmin\Properties`  | generated     | Assembly info       |
| `WebAdmin\WebAdmin\Scripts`     | config        | JavaScript bundles  |
| `WebAdmin\WebAdmin\Views`       | module-part   | Razor templates     |

### Other WebAdmin projects (1 level)

| Path                                                                                             | Nature        | Purpose signal          |
|--------------------------------------------------------------------------------------------------|---------------|-------------------------|
| `WebAdmin\Dashboard\{App_Start,Controllers,Models,Views,css,js,img,Fonts}`                       | module/config | MVC dashboard           |
| `WebAdmin\DataSyncDashboard\{App_Start,Controllers,Models,Views,Filters,Scripts,Content,Images}` | module/config | Data sync MVC dashboard |
| `WebAdmin\WebService\{App_Start,Controllers,Models,Views}`                                       | module        | Web service project     |

### `AsyncProcessor\` (2 level)

| Path                                                                            | Nature        | Purpose signal                              |
|---------------------------------------------------------------------------------|---------------|---------------------------------------------|
| `AsyncProcessor\AsyncProcessor\{Jobs,Scheduler,Extensions,Properties}`          | module-part   | Main processor internals                    |
| `AsyncProcessor\AsyncFarmManager\{Jobs,Scheduler}`                              | module-part   | Farm manager internals                      |
| `AsyncProcessor\AsyncTranslator\{Jobs,Scheduler,Helpers,Models,SmartCatModels}` | module-part   | Translator internals + SmartCat integration |
| `AsyncProcessor\Async.Common\Scheduler`                                         | cross-cutting | Shared scheduling                           |
| `AsyncProcessor\AsyncProcessor.Test\Jobs`                                       | tests         | Job test stubs                              |

### SoftwareDistributor / Twitch / WebHooks / Updater / CounterPublisher

| Path                                                                                                                               | Nature        | Purpose signal                                |
|------------------------------------------------------------------------------------------------------------------------------------|---------------|-----------------------------------------------|
| `SoftwareDistributor\SoftwareDistributor\{App_Start,Controllers,Filters,Models,Views,Scripts,Content,Images,SoftwareDistribution}` | module/config | Distributor MVC app                           |
| `SoftwareDistributor\Actions\*.cmd`, `SoftwareDistributor\Configs\*.json/.config`                                                  | config        | Install/service scripts + per-service configs |
| `Twitch\TwitchAccountLinking\{Controllers,DAL,Extensions,Models,Utils,Views,Startup.cs,wwwroot,Dockerfile}`                        | module        | ASP.NET Core account linking                  |
| `WebServices\WebHooks\WebHooks\{Controllers,DAL,Helpers,Middleware,ObjectModel,Swagger,Dockerfile}`                                | module        | ASP.NET Core webhooks                         |
| `Updater\Updater.Core\Exe`                                                                                                         | config        | Bundled 7za.exe                               |

## Non-code top-level directories

| Path                                                       | Nature | Content                                                                                                                                        |
|------------------------------------------------------------|--------|------------------------------------------------------------------------------------------------------------------------------------------------|
| `SQL\`                                                     | config | 700+ `.sql` files under `Patches\{Main,Stats}`, `Admin\`, `AntiCheat\`, `Users\`, `Inventory\`, `Missions\`, `Setup\` + ad-hoc scripts at root |
| `Build\`                                                   | config | Build scripts (`Collect.cmd`, `Package.cmd`) + `Configs\`                                                                                      |
| `Photon\deploy`                                            | config | Deploy scripts                                                                                                                                 |
| `Photon\doc`                                               | config | Photon-specific docs                                                                                                                           |
| `Photon\version.txt`                                       | config | Version marker                                                                                                                                 |
| `props\`                                                   | config | Shared MSBuild `.props` + `.runsettings`                                                                                                       |
| `lib\`                                                     | config | External DLL drop (Photon SDK, ServiceStack, SimplePsd, log4net, ExitGames)                                                                    |
| `NoSql\{Releases,Setup,indexes.js,MongoExportExample.txt}` | config | Mongo index scripts + setup                                                                                                                    |
| `Monitoring\{zabbix,zabbix_agentd.conf}`                   | config | Zabbix agent config                                                                                                                            |
| `FGL\`                                                     | config | Mixed artifacts (`fgl.bat`, JSON, `.pgl`, ad-hoc text)                                                                                         |
| `PowerDesigner\{Main,Workspace.sws}`                       | config | PowerDesigner DB model                                                                                                                         |
| `.editorconfig`, `CLAUDE.md`                               | config | Repo-level config                                                                                                                              |
| `.claude\`                                                 | config | Per-branch Claude settings (local)                                                                                                             |

## Summary — type/nature counts

| Type                                    | Count   |
|-----------------------------------------|---------|
| `production` (module nature)            | 40      |
| `infra` (cross-cutting / config nature) | 12      |
| `tests`                                 | 15      |
| `tool`                                  | 34      |
| **Total `.csproj`**                     | **101** |

(Breakdown is first-pass heuristic — Pass 2/3 will validate which `production` projects actually deserve `module` status
vs being split/merged.)
