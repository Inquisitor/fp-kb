# Pass 1 — User annotations

Expert corrections and additions to `pass-1-inventory.md`. The inventory stays as agent-generated (preserved as
execution output); corrections and expert knowledge live here.

Read by the planning session **together with `pass-1-inventory.md`** before Pass 2/3.

---

## 1. Classification corrections

Entries where the agent got `type` or `nature` wrong.

Leave rows blank (or delete the example row) if there's nothing to correct in a category.

| Path (as in inventory)                                               | Field  | Agent said | Should be     | Short reason                                       |
|----------------------------------------------------------------------|--------|------------|---------------|----------------------------------------------------|
| `Photon\src-server\Loadbalancing\LoadBalancing\LoadBalancing.csproj` | nature | module     | project       | Actually is the main project containing game logic |
| `Shared\ObjectModel\ObjectModel.csproj`                              | nature | module     | cross-cutting | Contains models used across project                |
| `Shared\DT\DT.csproj`                                                | nature | module     | cross-cutting | Date-Time helpers                                  |

| Path (as in inventory)                                    | Note correction                                                                                                     |
|-----------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------|
| `Shared\DT\DT.csproj`                                     | Date-time helpers used across project. Contains `UtcNow()` (can be swapped with custom implementation for testing). |
| `Shared\Notifications\Notifications.csproj`               | Email sender                                                                                                        |
| `Shared\StandaloneClient\StandaloneClient.csproj`         | Despite the name, contains client library used for inter-server communication (e.g. WebAdmin->Master)               |
| `Shared\Lite\Lite\Lite.csproj`                            | Contains now-modified Room/Actor logic, originally from Photon sample apps (Lite, Loadbalancing)                    |
| `Shared\Denuvo\Denuvo.csproj`                             | Denuvo anticheat integration                                                                                        |
| `Dal\Sql.MsSql\Sql.MsSql.csproj`                          | Implementation of SQL data access providers for MS SQL server - not sure if "SQL Server backend" meant this         |
| `Dal\NoSql.Mongo\NoSql.Mongo.csproj`                      | Implementation of NoSQL data access providers for MongoDB - not sure if "MongoDB backend " meant this               |
| `Dal\NoSql.FileStorage\NoSql.FileStorage.csproj`          | Implementation of NoSQL data access providers for storing data in files                                             |
| `AsyncProcessor\AsyncTranslator\AsyncTranslator.csproj`   | Import-export tool for syncing translation stored in DB with files                                                  |
| `AsyncProcessor\AsyncFarmManager\AsyncFarmManager.csproj` | Contains jobs related to the server farm management. Not sure if used.                                              |
| `SoftwareDistributor\`                                    | Contains web application used for managing server farm. Can start, stop servers, download and install updates, etc. |
| `Twitch\TwitchAccountLinking\TwitchAccountLinking.csproj` | A web service for users so that they can link their in-game accounts with Twitch accounts to receive Twitch Drops.  |
| `WebAdmin\WebService\WebService.csproj`                   | Web service API for tournament results. Abandoned.                                                                  |
| `Updater\`                                                | Patch distribution system? Unreleased, abandoned.                                                                   |
| `FGL\`                                                    | An attempt to write own laguage for defining fish spawn points. Abandoned.                                          |
| `PowerDesigner\`                                          | Outdated DB model.                                                                                                  |
|                                                           |                                                                                                                     |

---

## 2. Missed entries

Paths the agent did not capture — new `.csproj`, subfolders, or other relevant locations you know about.

| Path | Type | Nature | Short note |
|------|------|--------|------------|
|      |      |        |            |

---

## 3. Tools usage status

For every tool in the inventory — usage status.

- `active` — used by team / in pipeline
- `deprecated` — replaced / no longer run, but kept in repo
- `dead` — genuinely abandoned, nobody runs it
- `unknown` — you haven't touched it (that's fine, leave `unknown`)

| Tool                           | Usage      | Note                                                                                                                               |
|--------------------------------|------------|------------------------------------------------------------------------------------------------------------------------------------|
| `AlterIdentity`                | dead       | A tool used for generating SQL scripts for changing IDENTITY columns in the database. Not sure if it's still used. Probably not.   |
| `Chat` (under `Photon\tools\`) | dead       | Unfinished standalone chat app to perform private chats with players. Contains almost no code                                      |
| `ClubServiceTester`            | deprecated | Load tester for the Clubs service. It's not used very much nowadays because the Club service is now also not used a lot.           |
| `ConfigTool`                   | deprecated | A tool for performing mass editing of game server configs (we currently have a copy of config per-env). Plans to retire it.        |
| `CountWords`                   | dead       | Word count utility. Once made, now unused.                                                                                         |
| `DataChangesImport`            | active     | A tool used for importing data changes from `DataChanges`table written by WebAdmin. Used to repair DB corruption once.             |
| `DataDumper`                   | dead       | Dumps data from the DB to the file on disk. Not used.                                                                              |
| `DataPump`                     | active     | Tool used in the data pipeline. Copies world data between env DBs. Actively maintaned.                                             |
| `DbMergeTool`                  | dead       | Data pipeline-related tool. Now unused.                                                                                            |
| `DbMergeToolGui`               | dead       | GUI for data pipeline, now unused.                                                                                                 |
| `EmailGenerator`               | dead       | Editor for transactional email templates. Unused.                                                                                  |
| `EnvironmentSwitcher`          | active     | A tool for switching environment profiles i. e. switching between branches. Changes paths stored in system's environment vars.     |
| `GcTest`                       | dead       | A tool used for experimenting with C# garbage collector.                                                                           |
| `ImageDumper`                  | active     | A tool used for dumping images stored in the DB to the client. Part of the data pipeline.                                          |
| `MaintenanceManager`           | active     | CLI tool used to control messages during maintenance. When the servers are offline, client shows messages set by this tool.        |
| `MongoExport`                  | dead       | A tool used to export data from logs stored in MongoDB for some task.                                                              |
| `OfflineChatMessagesImport`    | dead       | A tool used for some task that required importing a lot of messages for the Chat server.                                           |
| `PerfCounterManager`           | active     | A tool for seting up Windows Performance Counters for custom apps that are not part of the standard Loadbalancing app from Photon. |
| `PhotonTool`                   | active     | Console client that connects to master/game/chat servers. Has debug functionality. Needs to be heavily rewritten to be usable.     |
| `PondJsonExporter`             | dead       | One-time tool used for exporting JSON config of some ponds to disk from DB.                                                        |
| `ReleaseTool`                  | active     | Used to perform some specific operations, like converting player profiles, during releases.                                        |
| `ServiceControl`               | dead       | Utility used for controlling apps running on servers. Abandoned.                                                                   |
| `SqlCheck`                     | active     | DB migrations utility. Checks for pending migrations, runs migration scripts.                                                      |
| `TournamentAudit`              | dead       | In-game tournament audit automation attempt. Abandoned.                                                                            |
| `TwitchApiTester`              | dead       | A tool used or testing Twitch API duting integrating Twitch Drops into the system. Unused.                                         |
| `XBoxCertChecker`              | active     | Checks validity of certificates used in communication with Xbox servers.                                                           |
| `XblApiTester`                 | dead       | Tool used for testing Xbox Live API. Unused.                                                                                       |
| `XstsTester`                   | dead       | Tool user for testing XSTS token verification after Microsoft changes something in their libraries.                                |
| `JsonVerificator` (WebAdmin)   | unknown    | Has its compiled `.exe` referenced from the WebAdmin code.                                                                         |
| `ProfileUtils` (WebAdmin)      | unknown    | The purpose is (seemingly) CRUD operations for Profile JSON stored in the DB. Compiled `.exe` is referenced from WebAdmin code.    |
| `DataEditing` (Shared)         | module     | Web Admin module for editing data in tables.                                                                                       |
| `StandaloneClient` (Shared)    | module     | Photon client used for connecting o Photon server instances. Part of the SharedLib, despite the name.                              |
| `Loadbalancing.TestClient`     | dead       | Load-testing client used on early development stages. Now abandoned.                                                               |
| `LoadBalancing.TestBot`        | dead       | Load-testing client used on early development stages. Now abandoned.                                                               |

---

## 4. Domain cross-cutting hints

Knowledge about which domains are deeply woven across many places — the stuff the agent cannot derive from paths alone.
**Most valuable section** — saves Pass 3 days of grep-fishing.

Format per domain:

- **`<domain>`** — brief description + real paths to check in Pass 3 beyond the obvious ObjectModel / SharedLib / Dal /
  Photon.Interfaces mirror.

Example:

- **`missions`** — integration points reach far beyond the obvious mirror. Triggered from fishing loop events, inventory
  changes, profile events, etc. In Pass 3, also check: `GameLogic\<path>`, `<another area>`, …

### Your domains

- ``

---

## 5. Notes / clarifications

Free-form section for:

- Explaining `?` Notes in the inventory (e.g. what `Photon\tools\Chat\Chat.csproj` actually is)
- Confusing naming (e.g. why `Shared\Twitch\Twitch.csproj` and `Twitch\TwitchAccountLinking\` are different things)
- Historical context that affects interpretation ("this was an old experimental thing we never removed")
- Anything the agent might misinterpret later

Bullet list or paragraphs — whichever is faster to write.

### Notes

- `Photon\` path is the root of the server project. It's called "Photon" because it was based on the "LoadBalancing"
  sample app shipped with Photon 3. The Photon server was upgraded from Photon 3 to Photon 4. The folder now contains
  not only the Photon server code, but also lots of other unrelated projects and tools. That's why "Photon tools" is
  simply wrong. Most of these tools are not even remotely related to Photon or the server.
- `Photon\src-server\` is not Photon server core, it's mostly the game logic. There Photon itself is a library, located
  in `Photon\deploy\`.
- Photon is not the only game server framework used in the project. We have our own game server framework called "
  GameCarrier". It's not a part of Photon. We developed it ourselves. Practically, all projects, utilities, environment
  names containing "GC" are named after GameCarrier, not garbage collector, except "GcTest" (dead). There are some
  `GC.Collect()` calls that call garbage collector, but I can't remember any occurrence of naming a project, namespace,
  class, or even field "GC"  after garbage collector. It's safe to assume that all "GC" names in tools, projects, etc.
  are related to GameCarrier.
- Game Carrier source code is not available in the repository.
- Idea: a lot of history and context may be discovered by looking at the history of the project. Especially, unknown
  tools purpose.
