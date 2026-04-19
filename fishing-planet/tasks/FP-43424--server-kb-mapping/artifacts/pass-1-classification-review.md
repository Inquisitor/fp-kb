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

## Naming caveats (do not trust paths/names blindly)

Critical expert knowledge the system expert provided — agents reading KB must know these up front:

- **"Photon tools"** is a misnomer. Most tools under `Photon\tools\` are **not related to Photon** at all. Historical naming because the project's base was the LoadBalancing sample from Photon 3.
- **`Photon\src-server\`** is **not Photon core** — it's mostly game logic. Actual Photon lives in `Photon\deploy\` as a library.
- **GameCarrier (GC)** is an in-house game server framework alongside Photon. Practically all `GC` in project / namespace / class / tool names refers to **GameCarrier**, NOT garbage collector. The one exception: `GcTest` (dead) is genuinely about garbage collector. GameCarrier source code is **not in this repo**.
- **Dead code is common.** Inventory includes many half-dead `.csproj`. Section I lists abandoned top-levels; Section H.2 lists user-confirmed dead tools. "Last commit > 12mo" is a suspicion signal, not an autodelete rule — some untouched projects (e.g. `JsonVerificator`, `ProfileUtils`) are still live via compiled-EXE references from other projects.

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

- `Shared\Notifications\Notifications.csproj` — email sender (per user)
- `Shared\StandaloneClient\StandaloneClient.csproj` — **module per user**: Photon client for inter-server connections (e.g. WebAdmin → Master); misnamed — part of SharedLib despite the name
- `Shared\Lite\Lite\Lite.csproj` — modified Room/Actor logic, originally from Photon samples
- `Shared\Twitch\Twitch.csproj` — Twitch library (not to be confused with `Twitch\TwitchAccountLinking`)
- `Shared\DataEditing\DataEditing.csproj` — **module per user**: WebAdmin module for editing data in tables (was `tool` in inventory — re-classified)

---

## H. Tools

Tools are **not module cards**. They go into a single `_systems/tools.md` overview, grouped by status and subtype.

Classifications below are **per user annotations** in `pass-1-user-notes.md`.

### H.1 — Active
- `Photon\tools\DataChangesImport\` — import data changes from `DataChanges` table (once used to repair DB corruption)
- `Photon\tools\DataPump\` — world data copy between env DBs (actively maintained, part of data pipeline)
- `Photon\tools\EnvironmentSwitcher\` — switch env profiles / branches via system env vars
- `Photon\tools\ImageDumper\` — image extraction from DB (part of data pipeline)
- `Photon\tools\MaintenanceManager\` — CLI setting maintenance messages shown to clients when servers offline
- `Photon\tools\PerfCounterManager\` — setup Windows Performance Counters for custom apps
- `Photon\tools\PhotonHelper\PhotonTool\` — console client connecting to master/game/chat; debug functionality (needs heavy rewrite)
- `Photon\tools\ReleaseTool\` — release-time operations (e.g. profile conversions)
- `Photon\tools\SqlCheck\` — DB migrations utility (check pending, run migrations)
- `Photon\tools\XBoxCertChecker\` — validate certificates for Xbox server communication

### H.2 — Dead / deprecated
- `Photon\tools\AlterIdentity\` — SQL IDENTITY column script generator (probably dead)
- `Photon\tools\Chat\` — unfinished standalone private-chat app (almost no code)
- `Photon\tools\ClubServiceTester\` — Clubs service load tester (deprecated; Club usage declined)
- `Photon\tools\ConfigTool\` — mass config editor (deprecated; plans to retire)
- `Photon\tools\CountWords\` — word count utility (once made, unused)
- `Photon\tools\DataDumper\` — DB to disk dump (unused)
- `Photon\tools\DbMergeTool\` — data pipeline merge (unused)
- `Photon\tools\DbMergeToolGui\` — GUI for DbMergeTool (unused)
- `Photon\tools\EmailGenerator\` — transactional email template editor (unused)
- `Photon\tools\GcTest\` — C# garbage collector experiments (the one tool where `GC` actually means garbage collector)
- `Photon\tools\MongoExport\` — export from Mongo logs (one-time task)
- `Photon\tools\OfflineChatMessagesImport\` — import many messages to Chat server (one-time task)
- `Photon\tools\PondJsonExporter\` — one-time pond JSON config export
- `Photon\tools\ServiceControl\` — server-app control utility (abandoned)
- `Photon\tools\TournamentAudit\` — tournament audit automation attempt (abandoned)
- `Photon\tools\TwitchApiTester\` — Twitch API testing during Twitch Drops integration (unused)
- `Photon\tools\XblApiTester\` — Xbox Live API testing (unused)
- `Photon\tools\XstsTester\` — XSTS token verification testing (unused)
- `Photon\src-server\Loadbalancing\TestClient\` — early-dev console test client (abandoned)
- `Photon\src-server\LoadBalancing.TestBot\` — early-dev load-generation bot (abandoned)

### H.3 — Unknown (may be live through compiled-EXE references; investigate before dismissing)
- `WebAdmin\JsonVerificator\` — compiled `.exe` referenced from WebAdmin code; likely live despite untouched commit history
- `WebAdmin\ProfileUtils\` — compiled `.exe` referenced from WebAdmin code; purpose seems to be CRUD for Profile JSON stored in DB

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
