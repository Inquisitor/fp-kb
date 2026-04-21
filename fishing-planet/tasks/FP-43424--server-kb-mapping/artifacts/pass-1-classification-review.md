# Pass 1.5 — Classification review

Agent-drafted categorization of 101 `.csproj` + key subfolders into coarse buckets, reviewed by the system expert.

Scope: `.csproj` boundary only. Domain-cluster grouping (missions-as-one-module-across-5-projects) is Pass 3 work, not here.

**Companion artifacts:**
- `pass-3-catalogue-draft.md` — file-level domain catalogue and detailed observations (LOC, tool internals, test coverage, module assignments). Formerly Section M of this file; see that file for depth.
- `folder-tree.md` — annotated folder tree with module tags (reference, read on-demand).
- Security findings — extracted to a private out-of-repo audit file (formerly Section N of this file).

## How to edit

- **Move** a line to a different section by cut-and-paste if the agent put it wrong
- **Kill** a dead / abandoned line with `~~strikethrough~~`
- **Comment** by appending ` — your note` (after the existing note if any)
- **Ask** the agent to consider something by prefixing a line with `# Q: ...`
- **Leave alone** what's correct — silence = approval
- **Don't rewrite** — just react

---

## Naming caveats (do not trust paths/names blindly)

Critical expert knowledge the system expert provided — agents reading KB must know these up front:

- **"Photon tools"** is a misnomer. Most tools under `Photon\tools\` are **not related to Photon** at all. Historical naming because the project's base was the LoadBalancing sample from Photon 3.
- **`Photon\src-server\`** is **not Photon core** — it's mostly game logic. Actual Photon lives in `Photon\deploy\` as a library.
- **`GC` has three meanings** — disambiguate by context:
  - **GameCarrier** (most common): in-house game server framework alongside Photon. Almost all `GC` in project / namespace / class / tool names. Source **not in this repo**.
  - **.NET Garbage Collector** (rare): `Photon\tools\GcTest\` (dead; GC experiments) and `Photon\src-server\Loadbalancing\LoadBalancing\Helpers\GcHelper.cs` (.NET GC tuning + console commands `gc.collect`, `gc.compact`, `gc.set_latency_mode`).
  - **Gold Coins** (in-game premium currency, system name `Baitcoins`, also `BC`): in balance/economy code. See also the in-game currency caveat below.
- **Dead code is common.** Inventory includes many half-dead `.csproj`. Section I lists abandoned top-levels; Section H.2 lists user-confirmed dead tools. "Last commit > 12mo" is a suspicion signal, not an autodelete rule — some untouched projects (e.g. `JsonVerificator`, `ProfileUtils`) are still live via compiled-EXE references from other projects.
- **`Photon\src-server\Loadbalancing\` is the main game-server solution** (`LoadBalancing.sln`). It's what opens in Visual Studio when working on the game server. Its inner csproj hosts 4 Photon apps (master-server, game-server, chat-server, club-server) + the load-balancer module + cross-cutting infra. It depends on external projects such as `Shared\SharedLib\`, which contain shared game logic also consumed by other solutions (WebAdmin, async-processor).
- **`game` system** is the most tangled code in the codebase — it contains `game-actions`, `game-state`, `fish-fight`, `game-model-core`, and likely more `game-*` modules whose boundaries are blurry. Full of bugs; this KB-mapping effort is the precursor to disentangling it. **Treat all `game-*` module assignments as tentative** until the full picture is read. Final boundaries will solidify only after every file is examined.
- **Branch `LBM20251201` = LeaderBoards / Matchmaking**. The branch is where the **new `leaderboards` module is being developed**. The **legacy leaderboards module is `tops`** (named after the internal `TopsCache` / `TopsProvider` terminology). Do not conflate `tops` (legacy, in production) with `leaderboards` (new, WIP).
- **`OnlineCache` is also spelled `OnlineCash`** in some places (e.g. `MongoOnlineCash`, folder `NoSql.Interface\OnlineCash`, `NoSql.Mongo\OnlineCash`). This is a non-native-English typo — *cache* and *cash* are the same thing here. Search both spellings when looking for related code.
- **`Achievement` is misspelled as `Achivement`** (missing "e") throughout `AchievementManager.cs` and likely elsewhere (e.g. `BroadcastEvent_Achivement`, `NotifyClientAboutAchivement`, `RaiseAchivmentProgress`). Search both spellings when grepping for achievement code.
- **In-game currency names** — two currencies, each with two names in code:
  - `SC` = **Silver Coins** = **credits**
  - `GC` = **Gold Coins** = **baitcoins** (`BC`)
  Search all aliases when tracking currency-related code. Do not confuse in-game currency (`shop`, `economy`) with real-money payments (`monetization`).

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
- `Shared\Denuvo\Denuvo.csproj` — Denuvo anti-tamper integration

---

## D. Data access implementations

Repository-pattern providers. Likely become one system `_systems/dal.md` with per-backend cards.

- `Dal\Sql.MsSql\Sql.MsSql.csproj` — SQL Server provider
- `Dal\NoSql.Mongo\NoSql.Mongo.csproj` — MongoDB provider
- `Dal\NoSql.FileStorage\NoSql.FileStorage.csproj` — file-storage NoSQL provider

---

## E. Cross-cutting infrastructure

Used by many modules, not a domain of their own. No card required — mention in system overviews.

- `Shared\ObjectModel\ObjectModel.csproj` — shared DTO library (client+server wire format). Dispersed across ~40 domain modules. File-level dispersal detail in `pass-3-catalogue-draft.md`.
- `Shared\DT\DT.csproj` — date/time helpers (`UtcNow()` swappable for tests)
- `Shared\Photon.Interfaces\Photon.Interfaces.csproj` — RPC contracts (client+server wire protocol); enum-heavy. Detail in `pass-3-catalogue-draft.md`.
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
- `AsyncProcessor\AsyncTranslator\AsyncTranslator.csproj` — translation sync tool (DB ↔ files)
- `AsyncProcessor\AsyncFarmManager\AsyncFarmManager.csproj` — farm management jobs (per user: usage uncertain — resolved in catalogue as alive farm-reboots orchestrator)
- `WebAdmin\WebAdmin\WebAdmin.csproj` — main admin portal (ASP.NET MVC)
- `WebAdmin\Dashboard\Dashboard.csproj` — dashboard MVC app
- `WebAdmin\DataSyncDashboard\DataSyncDashboard.csproj` — data sync MVC app
- `WebAdmin\WebTranslate\WebTranslate.csproj` — translation portal
- `WebAdmin\RepositoryService\RepositoryService.csproj` — repository service
- `SoftwareDistributor\SoftwareDistributor\SoftwareDistributor.csproj` — server-farm management UI (active — can start/stop servers, install updates)
- `Twitch\TwitchAccountLinking\TwitchAccountLinking.csproj` — Twitch Drops account linker
- `Twitch\AspNet.Security.OAuth.Epic\...csproj` — OAuth: Epic
- `Twitch\AspNet.Security.OAuth.Nintendo\...csproj` — OAuth: Nintendo
- `Twitch\AspNet.Security.OAuth.PlayStation\...csproj` — OAuth: PlayStation
- `Twitch\AspNet.Security.OAuth.XBox\...csproj` — OAuth: Xbox
- `WebServices\WebHooks\WebHooks\WebHooks.csproj` — webhooks service (ASP.NET Core)

---

## G. Misc Shared libraries

Smaller shared libs that don't fit cleanly above.

- `Shared\Notifications\Notifications.csproj` — email sender
- `Shared\StandaloneClient\StandaloneClient.csproj` — **module per user**: Photon client for inter-server connections (e.g. WebAdmin → Master); misnamed — part of SharedLib despite the name
- `Shared\Lite\Lite\Lite.csproj` — modified Room/Actor logic, originally from Photon samples
- `Shared\Twitch\Twitch.csproj` — Twitch library (not to be confused with `Twitch\TwitchAccountLinking`)
- `Shared\DataEditing\DataEditing.csproj` — **module per user**: WebAdmin module for editing data in tables

---

## H. Tools

Tools are **not module cards**. They go into a single `_systems/tools.md` overview, grouped by status and subtype. Detailed tool observations (LOC, invocations, internals, module assignments, gotchas) live in `pass-3-catalogue-draft.md`.

Classifications below are per user annotations.

### H.1 — Active
- `Photon\tools\DataChangesImport\` — import data changes from `DataChanges` table (once used to repair DB corruption)
- `Photon\tools\DataPump\` — world data copy between env DBs (actively maintained, data pipeline)
- `Photon\tools\EnvironmentSwitcher\` — switch env profiles / branches via system env vars (WPF desktop app)
- `Photon\tools\ImageDumper\` — image extraction from DB (part of data pipeline)
- `Photon\tools\MaintenanceManager\` — CLI setting maintenance messages shown to clients when servers offline
- `Photon\tools\PerfCounterManager\` — setup Windows Performance Counters for custom apps
- `Photon\tools\PhotonHelper\PhotonHelper\PhotonConsole\` — QA/load-testing console client; per user: needs heavy rewrite
- `Photon\tools\ReleaseTool\` — release-time operations (largest tool)
- `Photon\tools\SqlCheck\` — DB migrations utility (check pending, run migrations)
- `Photon\tools\XBoxCertChecker\` — validate certificates for Xbox server communication
- `WebAdmin\JsonVerificator\` — **confirmed alive**: JSON deserialization validator referenced from WebAdmin code
- `WebAdmin\ProfileUtils\` — **confirmed alive**: Profile JSON DB ↔ file export/import referenced from WebAdmin code

### H.2 — Dead / deprecated
- `Photon\tools\AlterIdentity\` — SQL IDENTITY column script generator
- `Photon\tools\Chat\` — unfinished standalone private-chat app stub
- `Photon\tools\ClubServiceTester\` — Clubs service load tester (superseded by PhotonHelper)
- `Photon\tools\ConfigTool\` — mass config editor (deprecated; plans to retire)
- `Photon\tools\CountWords\` — word-count CLI (unused)
- `Photon\tools\DataDumper\` — DB to disk dump (unused; superseded by DataPump)
- `Photon\tools\DbMergeTool\` — data-pipeline merge (superseded by DataPump)
- `Photon\tools\DbMergeToolGui\` — WinForms GUI for DbMergeTool (superseded)
- `Photon\tools\EmailGenerator\` — transactional email template editor (unused)
- `Photon\tools\GcTest\` — C# garbage-collector experiments (the one tool where `GC` actually means garbage collector)
- `Photon\tools\MongoExport\` — export from Mongo logs (one-time task)
- `Photon\tools\OfflineChatMessagesImport\` — import many messages to Chat server (one-time task)
- `Photon\tools\PondJsonExporter\` — one-time pond JSON config export
- `Photon\tools\ServiceControl\` — server-app control utility (abandoned)
- `Photon\tools\TournamentAudit\` — tournament audit automation attempt (abandoned)
- `Photon\tools\TwitchApiTester\` — Twitch API testing (unused)
- `Photon\tools\XblApiTester\` — Xbox Live API testing (unused)
- `Photon\tools\XstsTester\` — XSTS token verification testing (unused)
- `Photon\src-server\Loadbalancing\TestClient\` — early-dev console test client (abandoned)
- `Photon\src-server\LoadBalancing.TestBot\` — early-dev load-generation bot (abandoned)

### H.3 — Unknown
(empty after audit — all previously unknown tools moved to H.1 or H.2)

---

## I. Dead / abandoned code (skip in KB entirely)

Projects and top-level dirs that exist in the repo but should not be described in the navigation layer. Mention at most as a one-liner in a graveyard note.

- `Updater\Patcher\Patcher.csproj` — unreleased, abandoned
- `Updater\Updater.Core\Updater.Core.csproj` — unreleased, abandoned
- `FGL\` (top-level dir) — custom fish-spawn-point language attempt, abandoned
- `PowerDesigner\` (top-level dir) — outdated DB model
- `WebAdmin\WebService\` — confirmed abandoned tournament-results Web API

---

## J. Non-code top-level (reference only)

Reference — no KB card, but relevant for context.

- `SQL\` — 700+ `.sql` migration / admin / setup scripts; Pass 3 decides whether to create `_systems/db-schema.md`
- `Dal\SqlServerProject\SqlServerProject.sqlproj` — **NOT a T-SQL schema project** (misleading name); **alive and in use** — CLR-assembly deploying regex UDFs to SQL Server. Detail in `pass-3-catalogue-draft.md`.
- `Build\` — build scripts + configs
- `Photon\deploy\`, `Photon\doc\`, `Photon\version.txt` — deploy / docs / version
- `props\` — shared MSBuild `.props` + `.runsettings`
- `lib\` — external DLL drop (Photon SDK, ServiceStack, SimplePsd, log4net, ExitGames)
- `NoSql\` — Mongo setup / index scripts
- `Monitoring\` — Zabbix agent config
- `.editorconfig`, `CLAUDE.md`, `.claude\` — repo-level config

---

## K. Tests — not individually reviewed

15 test projects; each follows its source module. No per-project review needed; listed for completeness. Per-project coverage detail in `pass-3-catalogue-draft.md`.

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
- **Three "session" concepts** — `GameSessionAdapter` (analytics-side, `IGameSessionProvider`), `OnlineCacheAdapter` (auth-side, `IOnlineCacheProvider`, aka `OnlineCash`), and `FishingSessionManager` (fishing-activity + per-catch persistence, `IFishingSessionProvider`). Verify relationships — likely distinct purposes (analytics lifecycle vs auth single-device vs per-pond catch tracking). Decide if any should merge, wrap, or be renamed for clarity. `fishing-session` is currently a separate module, candidate for merge with `game-session`.
- **`fishing-together` — social system membership?** — module is confirmed, but whether it belongs to `social` system (alongside clubs/friends) is undecided. Revisit after more adapters are read.
- **`economy` system name** — tentative. Encompasses in-game currency + items/licenses traded for it. Alternatives to consider: `in-game-economy`, `trading`, `currency`. Decide after seeing more adapters.
- **Licenses cross-cut** — licenses are sold in `shop` (for in-game currency) and `prem-shop` (for real money), and are queried by `travel` (pond access). Decide whether `licenses` is its own module or lives inside one of these three. (Tentatively recorded as a standalone `licenses` module.)
- **`boats` — inventory or travel?** — boats are inventory items (bought, equipped, carry wear), but pond-compat rules (which ponds allow which boats) live in `travel`. Decide system membership later.
- **`achievements` in `progression`?** — tentatively placed under `progression` system alongside `levels` and `pond-unlocks`. Verify by reading achievement code.
- ~~**`ranks` vs `levels`**~~ — **RESOLVED**: merged into `levels` since `LevelingManager.IncrementExperience` routes XP into both in one pass.
- **`disconnect` module split?** — currently holds both "signal delivery" (DisconnectSignalProcessor) and "disconnect fact logging" (AnalyticsAdapter disconnect methods). Decide whether these are one module or two.
- **`navigation` in `buoys` or `travel`?** — user suggests navigation is navigation-buoys, i.e. `buoys` system; but it's also deeply part of `travel`. Decide later.
- **`action-tracker` / FTUE scope** — the `CaptureAction` method with level-based filtering references `SharedConsts.FtueStatsActionName`. Likely FTUE / onboarding funnel. Consider standalone `onboarding` module or absorb into `analytics-events`.
- **`device-tracking` scope** — `LogOs` + `LogMac` only (MAC is for referral tracking, not surveillance). Probably too small for its own module — absorb into `analytics-events` or tie to referrals/auth.
- ~~**`LoadShedding\` actively used?**~~ — **RESOLVED**: this is the server-side piece that reports CPU / memory / counters up the Load Balancing system — valid, live code.
- ~~**`payments` → `purchases`**~~ — **RESOLVED**: module renamed to `purchases`.
