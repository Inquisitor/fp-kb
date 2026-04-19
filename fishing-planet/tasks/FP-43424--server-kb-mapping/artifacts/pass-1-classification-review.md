# Pass 1.5 — Classification review

Agent-drafted categorization of 101 `.csproj` + key subfolders into coarse buckets, incorporating hints from `pass-1-user-notes.md`. Reviewed by the system expert — edit in place, commit, done.

## How to edit

- **Move** a line to a different section by cut-and-paste if the agent put it wrong
- **Kill** a dead / abandoned line with `~~strikethrough~~`
- **Comment** by appending ` — your note` (after the existing note if any)
- **Ask** the agent to consider something by prefixing a line with `# Q: ...`
- **Leave alone** what's correct — silence = approval
- **Don't rewrite** — just react

Scope: `.csproj` boundary only. Domain-cluster grouping (missions-as-one-module-across-5-projects) is Pass 3 work, not here.

---

## A. Core runtime modules

Substantial domain-carrying projects expected to become module cards.

- `Photon\src-server\Loadbalancing\LoadBalancing\LoadBalancing.csproj` — main server host; likely splits into MasterServer / GameServer / ChatServer / ClubServer / LoadBalancer / GameLogic as separate modules in Pass 5
- `Photon\src-server\GameModel\GameModel.csproj` — fish / rod / hook game-simulation models
- `Shared\BiteSystem\BiteSystem.csproj` — fish bite / catch mechanics
- `Photon\src-server\AntiCheat\AntiCheat.csproj` — anti-cheat subsystem
- `Photon\src-server\CounterPublisher\CounterPublisher.csproj` — performance counter publisher (own sln)

---

## B. SharedLib — special case

One `.csproj` with ~33 domain subfolders (Achievements, Balance, Caching, Clubs, CurrencyExchange, DailyMissions, FarmReboots, Leaderboards, Leagues, Licenses, Missions, Monetization, Payments, Shop, Tournaments, Rewards, TargetedAds, …). In Pass 3 this project splits into ~20-25 domain modules; each subfolder becomes part of a domain-cluster module (combined with matching parts from ObjectModel / Dal / Photon.Interfaces / GameLogic).

- `Shared\SharedLib\SharedLib.csproj` — will split per domain subfolder in Pass 3

---

## C. Platform SDK adapters

Thin wrappers around vendor SDKs. Likely become one system `_systems/platforms.md` with small cards each.

- `Shared\Steamworks\Steamworks.csproj` — Steam
- `Shared\Epic\Epic.csproj` — Epic Games
- `Shared\Nintendo\Nintendo.csproj` — Nintendo Switch
- `Shared\Xb1Utils\Xb1Utils.csproj` — Xbox One
- `Shared\Apple\Apple.csproj` — Apple
- `Shared\Android\Android.csproj` — Android
- `Shared\XblRestApi\XblApiHelper\XblApiHelper.csproj` — Xbox Live REST API helper
- `Shared\Denuvo\Denuvo.csproj` — Denuvo anti-tamper integration (per user note)

---

## D. Data access implementations

Repository-pattern providers. Likely become one system `_systems/dal.md` with per-backend cards.

- `Dal\Sql.MsSql\Sql.MsSql.csproj` — SQL Server provider
- `Dal\NoSql.Mongo\NoSql.Mongo.csproj` — MongoDB provider
- `Dal\NoSql.FileStorage\NoSql.FileStorage.csproj` — file-storage NoSQL provider

---

## E. Cross-cutting infrastructure

Used by many modules, not a domain of their own. No card required — mention in system overviews.

- `Shared\ObjectModel\ObjectModel.csproj` — shared DTO library (per user). Domain subfolders inside are consumed by domain modules in Pass 3.
- `Shared\DT\DT.csproj` — date/time helpers (per user, `UtcNow()` swappable for tests)
- `Shared\Photon.Interfaces\Photon.Interfaces.csproj` — RPC contracts (18 feature subfolders); each subfolder will be absorbed by its domain module in Pass 3
- `Dal\DalAbstraction\DalAbstraction.csproj` — core DAL interfaces
- `Dal\Dal.Common\Dal.Common.csproj` — common DAL utilities
- `Dal\DalUtilities\DalUtilities.csproj` — DAL utilities
- `Dal\Dal.Log\Dal.Log.csproj` — DAL logging
- `Dal\Sql.Interface\Sql.Interface.csproj` — SQL interface contracts (~31 domain subfolders, absorbed by domain modules in Pass 3)
- `Dal\NoSql.Interface\NoSql.Interface.csproj` — NoSQL interface contracts
- `AsyncProcessor\Async.Common\AsyncCommon.csproj` — shared async infra

---

## F. Standalone services (own processes / apps)

Each is a runnable service — likely its own module or a small cluster.

- `AsyncProcessor\AsyncProcessor\AsyncProcessor.csproj` — main async job processor (exe)
- `AsyncProcessor\AsyncTranslator\AsyncTranslator.csproj` — translation sync tool (per user: DB ↔ files)
- `AsyncProcessor\AsyncFarmManager\AsyncFarmManager.csproj` — farm management jobs (per user: usage uncertain)
- `WebAdmin\WebAdmin\WebAdmin.csproj` — main admin portal (ASP.NET MVC)
- `WebAdmin\Dashboard\Dashboard.csproj` — dashboard MVC app
- `WebAdmin\DataSyncDashboard\DataSyncDashboard.csproj` — data sync MVC app
- `WebAdmin\WebTranslate\WebTranslate.csproj` — translation portal
- `WebAdmin\WebService\WebService.csproj` — tournament-results web service (per user: abandoned)
- `WebAdmin\RepositoryService\RepositoryService.csproj` — repository service
- `SoftwareDistributor\SoftwareDistributor\SoftwareDistributor.csproj` — server-farm management UI (per user: active — can start/stop servers, install updates)
- `Twitch\TwitchAccountLinking\TwitchAccountLinking.csproj` — Twitch Drops account linker (per user)
- `Twitch\AspNet.Security.OAuth.Epic\...csproj` — OAuth: Epic
- `Twitch\AspNet.Security.OAuth.Nintendo\...csproj` — OAuth: Nintendo
- `Twitch\AspNet.Security.OAuth.PlayStation\...csproj` — OAuth: PlayStation
- `Twitch\AspNet.Security.OAuth.XBox\...csproj` — OAuth: Xbox
- `WebServices\WebHooks\WebHooks\WebHooks.csproj` — webhooks service (ASP.NET Core)

---

## G. Misc Shared libraries

Smaller shared libs that don't fit cleanly above.

- `Shared\Notifications\Notifications.csproj` — email sender (per user note)
- `Shared\StandaloneClient\StandaloneClient.csproj` — inter-server client lib (per user: misnamed; used e.g. WebAdmin → Master)
- `Shared\Lite\Lite\Lite.csproj` — modified Room/Actor logic, originally from Photon samples (per user)
- `Shared\Twitch\Twitch.csproj` — Twitch library (not to be confused with `Twitch\TwitchAccountLinking`)
- `Shared\DataEditing\DataEditing.csproj` — data-editing helpers (marked `tool` in inventory; confirm)

---

## H. Tools

Tools are **not module cards**. They go into a single `_systems/tools.md` overview, grouped by status and subtype.

### H.1 — Active
- `Photon\tools\DataChangesImport\` — import data changes from DataChanges table
- `Photon\tools\DataPump\` — world data copy between env DBs (actively maintained)
- `Photon\tools\EnvironmentSwitcher\` — switch env profiles / branches via sys env vars
- `Photon\tools\ReleaseTool\` — release pipeline
- `Photon\tools\ServiceControl\` — start/stop services
- `Photon\tools\TournamentAudit\` — tournament integrity audit
- `Photon\tools\PondJsonExporter\` — pond JSON exporter
- `Photon\tools\SqlCheck\` — SQL lint/check
- `Photon\tools\XblApiTester\` — Xbox Live API tester
- `Photon\tools\XstsTester\` — XSTS token tester
- `Photon\tools\XBoxCertChecker\` — Xbox cert validation
- `Photon\tools\TwitchApiTester\` — Twitch API manual tester
- `Photon\tools\MaintenanceManager\` — maintenance manager
- `Photon\tools\PhotonHelper\PhotonTool\` — photon helper
- `Photon\tools\PerfCounterManager\` — perf counter CLI
- `Photon\tools\OfflineChatMessagesImport\` — offline chat import
- `Photon\tools\MongoExport\` — Mongo data export
- `Photon\tools\ImageDumper\` — image extraction
- `Photon\tools\GcTest\` — GC / perf test
- `Photon\tools\ConfigTool\` — mass config edit (per user: deprecated — plans to retire; moving to H.2)
- `WebAdmin\JsonVerificator\` — JSON validation utility
- `WebAdmin\ProfileUtils\` — profile helper CLI

### H.2 — Dead / deprecated (per user or agent guess)
- `Photon\tools\AlterIdentity\` — SQL IDENTITY generator (per user: probably dead)
- `Photon\tools\Chat\` — unfinished standalone chat app (per user: almost no code)
- `Photon\tools\ClubServiceTester\` — load tester (per user: deprecated along with Club service)
- `Photon\tools\CountWords\` — word count (per user: once made, now unused)
- `Photon\tools\DataDumper\` — DB dump to disk (per user: not used)
- `Photon\tools\DbMergeTool\` — data pipeline (per user: now unused)
- `Photon\tools\DbMergeToolGui\` — GUI version (per user: now unused)
- `Photon\tools\EmailGenerator\` — email template editor (per user: unused)
- `Photon\src-server\Loadbalancing\TestClient\` — console test client
- `Photon\src-server\LoadBalancing.TestBot\` — load-generation bot

### H.3 — Unknown (user hasn't touched; agent doesn't know either)
(empty — move entries here from H.1/H.2 if genuinely unknown)

---

## I. Dead / abandoned code (skip in KB entirely)

Projects and top-level dirs that exist in the repo but should not be described in the navigation layer. Mention at most as a one-liner in a graveyard note.

- `Updater\Patcher\Patcher.csproj` — per user: unreleased, abandoned
- `Updater\Updater.Core\Updater.Core.csproj` — per user: unreleased, abandoned
- `FGL\` (top-level dir) — per user: custom fish-spawn-point language attempt, abandoned
- `PowerDesigner\` (top-level dir) — per user: outdated DB model
- `WebAdmin\WebService\` — per user: abandoned tournament-results web service — **move here from F if you confirm**

---

## J. Non-code top-level (reference only)

Reference — no KB card, but relevant for context.

- `SQL\` — 700+ `.sql` migration / admin / setup scripts; Pass 3 decides whether to create `_systems/db-schema.md`
- `Build\` — build scripts + configs
- `Photon\deploy\`, `Photon\doc\`, `Photon\version.txt` — deploy / docs / version
- `props\` — shared MSBuild `.props` + `.runsettings`
- `lib\` — external DLL drop (Photon SDK, ServiceStack, SimplePsd, log4net, ExitGames)
- `NoSql\` — Mongo setup / index scripts
- `Monitoring\` — Zabbix agent config
- `.editorconfig`, `CLAUDE.md`, `.claude\` — repo-level config

---

## K. Tests — not individually reviewed

15 test projects; each follows its source module. No per-project review needed; listed for completeness.

- `Photon\src-server\Loadbalancing\LoadBalancing.Tests\`
- `Photon\src-server\GameModel.Tests\`
- `Dal\Sql.MsSql.Tests\`
- `Dal\NoSql.Mongo.Tests\`
- `Dal\Dal.Common.Tests\`
- `Shared\ObjectModel.Tests\`
- `Shared\SharedLib.Tests\`
- `Shared\BiteSystem.Tests\`
- `Shared\Denuvo.Tests\`
- `Shared\Twitch.Tests\`
- `Shared\Streamworks.Tests\` (typo in path, carried from code)
- `Shared\XblRestApi\XblApiHelperTest\`
- `WebAdmin\WebAdmin.Tests\`
- `AsyncProcessor\AsyncProcessor.Test\`
- `Photon\tools\ReleaseTool.Tests\`

---

## L. Uncertain — resolve in later passes

Things I'm unsure about; flagging for explicit confirmation later. Not blocking Pass 2; Pass 3 will read code and clarify.

- **LoadBalancing.csproj internal granularity** — is this one module or 5-6 (MasterServer, GameServer, ChatServer, ClubServer, LoadBalancer, GameLogic)? Current guess: split; GameLogic alone is 5800 LOC oracle.
- **WebAdmin internal granularity** — Controllers + Filters + Models + Views + Components. Single card or split by functional area (Players, Balance, Missions, Tournaments, …)? Pass 3.
- **AspNet.Security.OAuth.* (4 projects)** — single `oauth-providers` module or 4 cards? Mild preference: single, 4 listed inside.
- **Dashboard / DataSyncDashboard / WebTranslate / RepositoryService** — each a standalone MVC app; each its own module, or collapse some?
- **SharedLib vs ObjectModel duplication** — they mirror each other domain-wise. In Pass 3: each domain cluster pulls in both SharedLib\X and ObjectModel\X subfolders; clean.

---

## M. Missed — add here if anything is missing

(empty — add lines if the inventory missed something relevant)
