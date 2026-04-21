# Folder tree — LBM20251201

Root: `LBM20251201`

Excluded: .git, .idea, .vs, TestResults, bin, node_modules, obj, packages

```
LBM20251201/
├── AsyncProcessor                      # module: async-processor — async job runner service `FP.AsyncProcessor` (Windows Service); ~47 active jobs (~40 root-level + 12 domain subfolders); jobs disperse to ~15 domain modules (see subfolders); uses SchedulerIterationTimeout=10s + AbstractJob/ScheduleExecutor base from Async.Common
│   ├── Async.Common                    # module: async-processor (core infra) — AbstractJob base (~85 LOC with JobType/JobFrequancy TYPO enum) + ScheduleExecutor (~179 LOC with 10s loop + Thread.Sleep + DateTime.Now/UtcNow inconsistency L85/L93/L109/L114)
│   │   ├── Properties
│   │   └── Scheduler                   # AbstractJob + ScheduleExecutor + LogUtils; schedule rebuild based on local-hour (DST/timezone drift risk); silent-swallow in HasSkip() L149-151
│   ├── AsyncFarmManager                # module: farm-reboots — **alive but isolated** standalone Windows Service `FP.AsyncFarmManager`; 2 active jobs (FarmRebootJob + FarmScheduleRebootJob); **excessive Thread.Sleep (13× calls each, 1-10s intervals)** for machine-control sequencing (registry + network commands + server-state queries); zero cross-refs from other projects — operational artifact for farm-level reboot orchestration; complements `Shared\SharedLib\FarmReboots\` (client-facing runtime)
│   │   ├── Jobs                        # module: farm-reboots — FarmRebootJob + FarmScheduleRebootJob (heavy Thread.Sleep loops)
│   │   └── Scheduler                   # FarmManagerScheduleExecutor (Farm-specific connection string)
│   ├── AsyncProcessor                  # module: async-processor — main host csproj (~80 files); EntryPoint.cs ~582 LOC (service install/uninstall + `-tt`/`-gw`/`-rw` CLI runners) + DependencyInjection.cs + AsyncService ServiceBase wrapper + 14 cache initializers; AsyncProcessorScheduleExecutor.cs registers 47 active jobs + platform-conditional (PS/Steam/Android); 4 commented-out jobs on lines 43,77-79
│   │   ├── Extensions                  # module: async-processor — EqualityComparer utility (for ReportedAbusersBanJob dedup)
│   │   ├── Jobs                        # dispersed: ~40 root-level jobs + 12 domain subfolders; dispersion across moderation/clubs/competitions-lifecycle/user-generated-lifecycle/tournament-results/email-notifications/fishing-together/leaderboards/leagues/monetization/purchases/product-delivery/push-notifications/analytics-events/twitch-drops/account-closure plus NEW: cache-infra / sys-admin / weather / chat-moderation
│   │   │   ├── AbuseReporting          # module: moderation — 8 files: ReportedAbusersBanJob + AutoReportedAbusersBanJob + AbuseReportsCleanJob + AbuseAutoReportsCleanJob + AdminActionLogCleanJob + 3 support files (ChatBanReason/NotEligibleToBanUsers/UserNotificationSystem)
│   │   │   ├── Bans                    # module: moderation — RemoveExpiredBanJob (TimeOut 5m)
│   │   │   ├── Clubs                   # module: clubs — ClubJoinRequestsClearingJob + PresidentDemoteOnAfkJob
│   │   │   ├── Competitions            # module: competitions-lifecycle + user-generated-lifecycle — ApproveSponsoredUgcJob + ISponsoredUgcValidator + SponsoredUgcValidatorBase + SponsoredUgcValidators (4 files)
│   │   │   ├── Emailing                # module: email-notifications — SendQueuedMailJob (single file)
│   │   │   ├── FishingTogether         # module: fishing-together — FinishSuspendedFishingTogetherSessionsJob + FishingTogetherSessionsCleanupJob
│   │   │   ├── Leaderboards            # module: leaderboards — 7 files: CalculateCompetitiveLeaderboardChangeJob + 3× CleanupJob (Competitive/Fish/Global) + 3× FinalizationJob (Competitive/Fish/Global)
│   │   │   ├── Leagues                 # module: leagues — 7 files mirroring lifecycle: LeagueScheduleChampJob/StartSeasonJob/StartChampJob/EndSeasonJob/EndChampJob/SeasonArchivationJob/UnbanPlayersJob
│   │   │   ├── Monetization            # module: monetization + purchases + product-delivery — DetectBundlePurchasesJob (single; 5s-window bundle detection)
│   │   │   ├── Push                    # module: push-notifications — 6 files: PushBatchesClearingJob/PushDevicesClearingJob/PushLoginReminderJob/PushNewTournamentRegistrationJob/PushNotificationAdsBatchingJob/PushNotificationSendJob
│   │   │   ├── Stats                   # module: analytics-events — 3 files: CollectLegacyRevenueStatsJob + FishingSessionCleanupJob + GameSessionCleanupJob (last 2 also duplicated at root — misplaced)
│   │   │   └── Twitch                  # module: twitch-drops — RefreshTwitchLinksJob (single)
│   │   ├── Properties
│   │   └── Scheduler                   # AsyncProcessorScheduleExecutor: platform-conditional (PlayStationAccountClosureJob / SteamRefundProcessorJob / AndroidVoidedPurchasesProcessorJob); 4 commented-out jobs L43,77-79 (TopWebTransferJob dead + 3 embedded in UserCountriesCalcJob)
│   ├── AsyncProcessor.Test             # note: MSTest; limited coverage — only 3 domains tested (Competitions/Emailing/Monetization); 9 test files; 9 domains untested (Stats/Leagues/Push/Twitch/Clubs/FishingTogether/Bans/AbuseReporting/Leaderboards); SchedulerTests + DependencyInjectionTests + AssemblyConfiguration + TestParametersProvider at root
│   │   └── Jobs
│   │       ├── Competitions            # ApproveSponsoredUgcJobTests + SponsoredUgcValidatorsTests (DI mocked)
│   │       ├── Emailing                # SendQueuedMailJobTests (mocked email infra)
│   │       └── Monetization            # DetectBundlePurchasesJobTests (mocked analytics/monetization providers)
│   └── AsyncTranslator                 # module: async-translator — translation sync tool (DB ↔ SmartCat files); standalone Windows Service; 4 jobs (TranslationExportJob/ImportJob/SyncJob + DocumentExportJob); SmartCat integration config — see private audit; **`.Result` sync-over-async** in SmartCatHelper L84-86,91,98
│       ├── Helpers                     # SmartCatHelper (HttpClient + BasicAuth + polling Thread.Sleep 1s) + WebClientHelper
│       ├── Jobs                        # 4 jobs: TranslationExportJob (Daily 23:00) + TranslationImportJob + TranslationSyncJob + DocumentExportJob
│       ├── Models                      # 2 internal DTOs
│       ├── Scheduler                   # AsyncTranslator scheduler
│       └── SmartCatModels              # 7 API response DTOs: ProjectInfo/ProjectWorkflowStage/DocumentInfo/DocumentWorkflowStage/DocumentExecutive/Task + supporting
├── Build                               # note: build artifacts + per-service configs (Async, Tests, Web, WebAdmin) + cmd scripts that package binaries (installed later via software-distributor)
│   └── Configs
│       ├── Async
│       ├── Tests
│       ├── Web
│       └── WebAdmin
├── Dal                                 # system: dal — data access layer; groups all dal-*, nosql-*, sql-* modules below
│   ├── Dal.Common                      # module: dal-common — data mapping (DB → DTO); `Stats` subfolder measures query duration, read later via PhotonTool
│   │   └── Stats
│   ├── Dal.Common.Tests                # note: pure unit tests — 3 files (CryptoTest + TraceTests + FloatingPointPrecisionTests); FloatingPointPrecisionTests decorated [Ignore]
│   ├── Dal.Log                         # module: dal-log — logging library (including to Mongo)
│   │   ├── Async
│   │   ├── Common
│   │   └── Logs
│   ├── DalAbstraction                  # module: dal-abstraction — DI container (service locator/provider) for DAL layer
│   ├── DalUtilities                    # module: dal-utilities — ItemFactory: typed DTO factory for inventory system (item types are distinct classes)
│   ├── NoSql.FileStorage               # module: nosql-file-storage — log provider: writes to files; a separate service later reads them and ships to MongoDB
│   ├── NoSql.Interface                 # dispersed: only Async/ + Log/ILogBase+IDiagProvider+LogEntries are pure infra; rest disperses to domain modules (auth / chat-server / messaging / moderation / anti-cheat / clubs / fishing-together / competitive / debug / error-stats / admin-audit)
│   │   ├── Async                       # module: nosql-interface — INoSqlAsync (background cleanup contract)
│   │   ├── Chat                        # dispersed: chat-server+messaging (IChatLogger+ChatMessageDto+LogMessageBase), moderation (IAbuseReporter+IAbuseAutoReporter+SingleAbuseReport+AbuseReportItem), anti-cheat (CheatMessage), clubs (ClubMessage), fishing-together (TogetherMessage), competitive (TournamentMessage), debug (ClientDebugMessage), dal-log (LogMessage base DTO)
│   │   ├── Diag                        # module: error-stats — ErrorDto (HTML-formatted stack trace) + FpsDto + SysInfoDto (MAC/OS/CPU/RAM/DX/video dedup) + IpDto + MacAddressDto; 3 DTOs in wrong namespace (.Chat instead of .Diag)
│   │   ├── Log                         # dispersed: dal-log (ILogBase+IDiagProvider+LogEntries core), moderation (IBanLog+BanType+BanSource), anti-cheat (ICheatLog), debug (IClientDebugLog), clubs (IClubLog), fishing-together (ITogetherLog), competitive (ITournamentLog), admin-audit (IAdminActionLogStorage+AdminActionItem)
│   │   └── OnlineCash                  # module: auth — IOnlineCash (session tracking; typo `OnlineCash` should be `OnlineCache`)
│   ├── NoSql.Mongo                     # dispersed: only Common/ is pure infra; rest disperses to domain modules (same targets as NoSql.Interface)
│   │   ├── Chat                        # dispersed: chat-server+messaging (MongoChatLogger), moderation (MongoAbuseReporter+MongoAbuseAutoReporter)
│   │   ├── Common                      # module: nosql-mongo — MongoAccessorBase (empty Dispose!) + MongoDbHelper (new MongoClient per call — no pooling!)
│   │   ├── Diag                        # module: error-stats — MongoDiagProvider composite with 4 nested providers (Error/Fps/SysInfo/Ip), WriteConcern.Unacknowledged + millisecond-sampled catches
│   │   ├── Log                         # dispersed: dal-log (LogBase core), moderation (BanLog), anti-cheat (CheatLog — hardcoded Take(100)), debug (ClientDebugLog), clubs (ClubLog), fishing-together (TogetherLog), competitive (TournamentLog), admin-audit (MongoAdminActionLogStorage)
│   │   └── OnlineCash                  # module: auth — MongoOnlineCash + OnlineUser (hardcoded collection "oc"; Guid-as-ObjectId hybrid)
│   ├── NoSql.Mongo.Tests               # note: INTEGRATION tests — requires local MongoDB at `localhost/main` (hardcoded in App.config + MongoDbHelper.Initialize); 4 files (OnlineCashTest/ChatTest/DiagTest + LocalTimeProvider mock-time helper)
│   ├── Sql.Interface                   # dispersed: only Common/ is pure infra; ~290 files ~9.7k LOC across 31 subfolders, each disperses to its owning domain module
│   │   ├── Analytics                   # module: analytics-events + error-stats — IAnalyticsProvider (SaveAnalyticsData/SaveMissionData/SaveTargetedAdsFact/CaptureAction/SaveRoom) + 20 DTOs
│   │   ├── Async                       # module: async-processor + farm-reboots — IAsyncProvider (PersistFishCatch/TransferTopsToWeb/CalculateRetentionStats/CaptureCcu/CalculatePayerStats) + CcuDto/FarmRebootDto/FarmRebootScheduleDto
│   │   ├── Chat                        # module: chat-server + messaging — IPrivateChatMessagesProvider + IOfflineMessagePersister contracts
│   │   ├── Club                        # module: clubs — IClubProvider (Create/Join/GetMembers/GetJoinRequests) + 15 DTOs (Club/ExtendedClub/ClubMember/ClubTrophy)
│   │   ├── Common                      # module: sql-interface (core) — DtoBase + ProviderBase + RewardDto
│   │   ├── CurrencyExchange            # module: purchases — ICurrencyExchangeRateProvider (GetExchangeRate/GetAllExchangeRates/UpdateExchangeRates) + CurrencyExchangeRateDto
│   │   ├── Data                        # module: localization — IDataProvider + IDistributedDataProvider + DictionaryItemDto (with `// TODO: restore data.`)
│   │   ├── Device                      # module: auth — DeviceIntegrityDataDto (hardware ID, integrity checks); consumed alongside Shared\SharedLib\Device
│   │   ├── DisconnectSignal            # module: disconnect — IDisconnectSignalProvider (CreateDisconnectSignal/GetDisconnectSignals/ExpireDisconnectSignals)
│   │   ├── Fortune                     # module: reel-of-fortune — IReelOfFortuneProvider (GetRewards/GetCohorts/GetGoldRewards) + 5 DTOs
│   │   ├── Game                        # dispersed: fish-registry (FishDto/FishCategoryDto) + levels (LevelDto) + achievements (AchivmentDto/AchivmentStageDto — TYPO missing 'e') + rewards (RewardDto) — IGameProvider aggregate
│   │   ├── Images                      # module: localization + user-generated-lifecycle — IImagesProvider (GetImages/GetImageReferences/GetImageDuplicates/GetUnusedImages) + 4 DTOs
│   │   ├── Interactive                 # module: interactive-objects — IInteractiveProvider + InteractiveObjectDto
│   │   ├── Leaderboards                # module: leaderboards — 3 split interfaces (ILeaderboardsProvider_Global/_Fish/_Competitive) + 23 files; matches 3-sub-domain structure in SharedLib\Leaderboards
│   │   ├── Leagues                     # module: leagues — ILeagueProvider + ILeagueTestProvider (Season/Champ/Division/Player/Trophy DTOs) + 17 files
│   │   ├── Log                         # module: rewards — ILootTableLog single-file (Log: timestamp/userId/source/entityId/rewardId)
│   │   ├── Mission                     # module: daily-missions + missions — IMissionProvider (GetAllMissions/GetMissionTasks/GenerateFishDailyMissionJson/GetDailyMissionKindSettings)
│   │   ├── Monetization                # dispersed: monetization/purchases/product-delivery/shop — IMonetizationProvider + IMonetizationStatsProvider + 51 DTOs (Currency/Product/Tran/Offer/PondUnlock/Subscription/PayerStats/MarketingEvent); largest subfolder ~1.3k LOC
│   │   ├── Notification                # module: email-notifications + push-notifications — INotificationProvider (GetNotificationSettings/QueueNotification/GetNotificationsToSend/MarkNotificationSent) + NotificationDto/EmailNotificationDto + NotificationTypes enum
│   │   ├── Profile                     # dispersed: profile-management + account-lifecycle + identity-checks + moderation — IProfileProvider + ILoginProvider + 26 DTOs (Player/PlayerProfile/ExternalPlatformBinding/TwitchUserLink/DenuvoBan/DeletedAccount); 1543 LOC
│   │   ├── Push                        # module: push-notifications — IPushNotificationsProvider (RegisterPushDevice/GetAudience/CreateBatch/SendBatch) + 9 DTOs
│   │   ├── Rooms                       # module: game-rooms — IRoomProvider (GetRoomsPopulation/GetOwnRoom/MoveToRoom/MoveToBase/GetRoomCapacity)
│   │   ├── Shop                        # dispersed: shop + prem-shop + inventory-items + licenses — IShopProvider (GetAllItems/GetLicenses/GetInventoryParams/GetTargetedAds) + 23 DTOs; TYPO `LincenseTranslationDto` uses public fields not properties
│   │   ├── Skins                       # module: skins (NEW — cosmetic customization; consumed by clubs _Logo subsystem + premium character customization) — ISkinsProvider (GetAllSkinElements/Types/SubTypes/ContentType)
│   │   ├── Stats                       # dispersed: fishing-session (IFishingSessionProvider) + game-session (IGameSessionProvider) + analytics-events (IFishStatsProvider + ISessionStatsProvider) — 16 files ~540 LOC
│   │   ├── Sys                         # dispersed: sql-interface (core) + localization + cache — ISysProvider (GetLanguages/GetGlobalVariables/CreateCacheRefreshSignal/LookupIpInDatabase/GetAbTests) + AbTest/CachedEntity/Glossary/IpDatabase DTOs
│   │   ├── Together                    # module: fishing-together — IFishingTogetherProvider (CreateSession/AddHostUser/AddUserInvite/UpdateFishingResult/CleanupSessions) + 8 DTOs
│   │   ├── Tops                        # module: tops — ITopsProvider (GetTopPlayers/GetTopFish/GetTopTournamentPlayers) — legacy leaderboards pre-`leaderboards` module
│   │   ├── Tournaments                 # dispersed: tournaments-lifecycle + tournament-scoring + tournament-results — ITournamentProvider + ITournamentTestProvider + 27 files (Tournament/Participant/Series/Template/IndividualResults)
│   │   ├── Travel                      # dispersed: travel + ponds + boats + boat-rent + pond-unlocks — ITravelProvider (GetAvailablePonds/GetPondConfig/GetLocationsInfo/GetBoats/GetBuoyColors) + 14 DTOs
│   │   └── Weather                     # module: weather — IWeatherProvider (GetPeriods/GetPondConfig/SetPondRandomizedAcceleratorsConfig/SaveGeneratedWeather) + 5 DTOs
│   ├── Sql.MsSql                       # dispersed: only Common/ is pure infra; ~26k LOC across 30 subfolders implementing Sql.Interface contracts; each disperses to same domain modules as Sql.Interface counterpart; dominant pattern: inline SQL + stored procedures + ORM-lite extensions (ExecuteList/ExecuteScalar/ExecuteNonQuery); known query-composition risks — see private audit; 4 god-methods >150 LOC
│   │   ├── Analytics                   # module: analytics-events + error-stats — SqlAnalyticsProvider (~1.1k LOC, 33 SqlCommand; magic TOP 100 L517,L523; separate SqlAnalyticsConnectionString)
│   │   ├── Async                       # module: async-processor + farm-reboots — SqlAsyncProvider (~1.4k LOC, 52 SqlCommand; TOP 1 farm reboots L493,L567,L589; stored procs PersistFishCatch/CalculateTopTournamentPlayer)
│   │   ├── Chat                        # module: chat-server + messaging — PrivateChatMessageProvider (~130 LOC, operator concat `<`/`>` L27) + SqlOfflineMessagePersister (~141 LOC, SqlBulkCopy BulkCopyTimeout=999)
│   │   ├── Club                        # module: clubs — SqlClubProvider (~297 LOC, stored procs CreateClub/UpdateClub dominant)
│   │   ├── Common                      # module: sql-mssql (core) — SqlProviderBase (~454 LOC, 10 SqlCommand) + MsSqlHelper legacy ORM-lite extensions
│   │   ├── CurrencyExchange            # module: purchases — SqlCurrencyExchangeRateProvider (~69 LOC, simple CRUD via sprocs)
│   │   ├── Data                        # module: localization — SqlDataProvider (~213 LOC, **god-method `GetDictionaryData()` ~200 LOC L12-L210** massive switch+dual-SQL; 2 TODOs L21,L147) + SqlDistributedDataProvider (~96 LOC)
│   │   ├── DisconnectSignal            # module: disconnect — SqlDisconnectSignalProvider (~58 LOC, log-only)
│   │   ├── Fortune                     # module: reel-of-fortune — SqlReelOfFortuneProvider (~29 LOC, sproc wrapper)
│   │   ├── Game                        # dispersed: fish-registry+levels+achievements+rewards — SqlGameProvider (~432 LOC, 11 SqlCommand, multi-join NameSID translations; sprocs GetFishForPond)
│   │   ├── Images                      # module: localization + user-generated-lifecycle — SqlImagesProvider (~202 LOC, sprocs GetImageMetadata/SaveImageMetadata)
│   │   ├── Interactive                 # module: interactive-objects — SqlInteractiveProvider (~47 LOC, sprocs only)
│   │   ├── Leaderboards                # module: leaderboards — 3 split providers matching interface: SqlLeaderboardsProvider_Competitive (~630 LOC) + _Fish (~593 LOC) + _Global (~572 LOC) + 3 test variants (377+193+170 LOC); duplicate SQL patterns across providers — lack of abstraction; TOP 1 subqueries L202,L525 in Competitive
│   │   ├── Leagues                     # module: leagues — SqlLeagueProvider (~2.4k LOC, 114 SqlCommand) + SqlLeagueTestProvider (~569 LOC); TOP 1 literals L2237,L2313
│   │   ├── Log                         # module: rewards — SqlLootTableLog (~37 LOC, single-method)
│   │   ├── Mission                     # module: daily-missions + missions — SqlMissionProvider (~682 LOC, 25 SqlCommand; sprocs AcceptMission/CompleteMission/FailMission; no error handling around sproc params)
│   │   ├── Monetization                # dispersed: monetization+purchases+product-delivery+shop — SqlMonetizationProvider (**~3.5k LOC**, 80 SqlCommand; **god-method `GetTargetedAdsStats()` ~248 LOC L2317**; BulkCopyTimeout=999 L2509)
│   │   ├── Notification                # module: email-notifications + push-notifications — SqlNotificationProvider (~73 LOC, sproc wrapper)
│   │   ├── Profile                     # dispersed: profile-management+account-lifecycle+identity-checks+moderation — SqlLoginProvider (~1.6k LOC, 63 SqlCommand, **TODO L284 "Delete all user related data here"** cascading delete unimplemented) + SqlProfileProvider (~1k LOC) + SqlTestProfileProvider (~305 LOC); **no TransactionScope** for multi-table updates Profiles+Users
│   │   ├── Push                        # module: push-notifications — SqlPushNotificationsProvider (~1k LOC, 44 SqlCommand; audience-predicate query composition — see private audit)
│   │   ├── Rooms                       # module: game-rooms — SqlRoomProvider (~290 LOC, 11 SqlCommand; sprocs dominant RoomJoin/RoomLeave)
│   │   ├── Shop                        # dispersed: shop+prem-shop+inventory-items+licenses — SqlShopProvider (~865 LOC, 30 SqlCommand; string concat WHERE L510 `"WHERE \r\n    " + string.Join("\r\n    AND ", additionalFilters)` — ad-hoc filter join)
│   │   ├── Skins                       # module: skins — SkinsProvider (~20 LOC, **inherits ProviderBase not SqlProviderBase** — inheritance mismatch flag)
│   │   ├── Stats                       # dispersed: fishing-session+game-session+analytics-events — SqlFishStatsProvider (~592 LOC) + SqlPlayerStatsProvider (~76 LOC) + SqlLeagueStatsProvider (~25 LOC); aggregation-heavy TOP 1/MIN/MAX/GROUP BY without explicit sort guarantees
│   │   ├── Sys                         # module: sql-mssql (core) + localization + cache — SqlSysProvider (~410 LOC, 16 SqlCommand; IP database lookup TOP 1 L269)
│   │   ├── Together                    # module: fishing-together — SqlFishingTogetherProvider (~347 LOC, TOP 1 subqueries L46; sprocs CreateSession/JoinSession)
│   │   ├── Tops                        # module: tops — SqlTopsProvider (~108 LOC, **`NotImplementedException` L87** incomplete tournament kinds)
│   │   ├── Tournaments                 # dispersed: tournaments-lifecycle+tournament-scoring+tournament-results+user-generated-lifecycle — SqlTournamentProvider (**~3.6k LOC, 127 SqlCommand — highest in codebase**; predicate composition in `DeleteTournamentKind` — see private audit; stored procs PersistTournamentResult/CalculateTournamentResult) + SqlTournamentTestProvider (~200 LOC)
│   │   ├── Travel                      # dispersed: travel+ponds+boats+boat-rent+pond-unlocks — SqlTravelProvider (~502 LOC, 19 SqlCommand, sprocs TravelFish/StartTravel/FinishTravel)
│   │   └── Weather                     # module: weather — SqlWeatherProvider (~210 LOC, 7 SqlCommand, sprocs for state retrieval)
│   ├── Sql.MsSql.Tests                 # note: INTEGRATION tests — requires local SQL Server `Data Source=.;Initial Catalog=Main`; 18 test files + Utils\SqlDirectAccessProvider; 9 [Ignore]d tests + 1 commented-out; test-config notes — see private audit
│   │   ├── Async
│   │   ├── Chat
│   │   ├── Common
│   │   ├── Together
│   │   └── Utils
│   └── SqlServerProject                # note: SSDT .sqlproj — **NOT a schema project** (despite name); alive and in use — CLR-assembly with 3 regex UDFs (RegexReplace/RegexReplaceGroup/RegexIsMatch) + 1 aggregate (StringAggDistinct), deployed via CREATE ASSEMBLY and consumed by `Dal\Sql.MsSql\` queries at DB level; schema authoritative source lives in `SQL\Patches\` migration scripts
├── FGL                                 # dead: ancient attempt at a custom fish-definition language; abandoned
│   └── fgl
│       ├── Functions
│       ├── JSONParser
│       │   ├── syntaxtree
│       │   └── visitor
│       ├── Parser
│       │   ├── syntaxtree
│       │   └── visitor
│       ├── Preprocessor
│       └── Runtime
├── lib                                 # note: external DLLs (Photon SDK, ServiceStack, log4net, etc.); many likely unused — candidates for future cleanup
│   ├── Exitgames.MSBuild.Tasks
│   │   └── 1.0.1.1
│   ├── ServiceStack
│   │   ├── ServiceStack.3.9.54
│   │   │   └── lib
│   │   │       └── net35
│   │   ├── ServiceStack.Common.3.9.54
│   │   │   └── lib
│   │   │       ├── net35
│   │   │       ├── sl4
│   │   │       └── sl5
│   │   ├── ServiceStack.Common.3.9.71
│   │   │   └── lib
│   │   │       └── net35
│   │   ├── ServiceStack.OrmLite.SqlServer.3.9.54
│   │   │   └── lib
│   │   ├── ServiceStack.Redis.3.9.54
│   │   │   └── lib
│   │   │       └── net35
│   │   ├── ServiceStack.Redis.3.9.71
│   │   │   └── lib
│   │   │       └── net35
│   │   ├── ServiceStack.Text.3.9.54
│   │   │   └── lib
│   │   │       ├── net35
│   │   │       ├── sl4
│   │   │       ├── sl4-windowsphone71
│   │   │       └── sl5
│   │   └── ServiceStack.Text.3.9.71
│   │       └── lib
│   │           └── net35
│   ├── SimplePsd
│   └── zedgraph_dll_v5.1.5
│       ├── de
│       ├── es
│       ├── fr
│       ├── hu
│       ├── it
│       ├── ja
│       ├── pt
│       ├── ru
│       ├── sk
│       ├── sv
│       ├── tr
│       ├── zh-cn
│       └── zh-tw
├── Monitoring                          # note: Zabbix agent binaries + configs (server monitoring)
│   └── zabbix
│       ├── scripts
│       └── win64
│           └── dev
├── NoSql                               # note: MongoDB migration scripts — collection indexes + archived one-off release scripts + export instructions text file
│   ├── Releases
│   └── Setup
│       └── OldIndexes
├── Photon                              # note: originally a copy of Photon SDK; game logic was grown on top of the LoadBalancing and Lite samples; still carries SDK structural remnants alongside server game logic
│   ├── deploy                          # note: base Photon installation files (usually copied to C:\photon); contains install/build scripts
│   │   ├── bin_tools                   # note: utilities shipped with Photon (Stardust is a Photon client that generates load for testing)
│   │   │   ├── 7zip
│   │   │   ├── baretail
│   │   │   ├── dashboard
│   │   │   │   └── Web
│   │   │   │       ├── css
│   │   │   │       │   ├── egcss
│   │   │   │       │   ├── img
│   │   │   │       │   └── oocss
│   │   │   │       └── img
│   │   │   ├── firewalltool
│   │   │   ├── perfmon
│   │   │   ├── stardust
│   │   │   └── stardust.client
│   │   ├── bin_Win64                   # note: Photon server binaries + configs
│   │   ├── CounterPublisher            # note: small utility that publishes Photon performance counters to Windows
│   │   ├── keys                        # note: game-server keys for external services (Google, etc.)
│   │   ├── log                         # note: runtime logs written by the game server
│   │   └── Policy                      # note: Silverlight cross-domain policy files; unused in practice
│   │       └── assets
│   ├── doc                             # note: Photon SDK documentation (CHM + PDF); candidate for later extraction to MD for KB agent reference
│   │   └── applications
│   ├── src-server
│   │   ├── AntiCheat                   # module: anti-cheat — accumulates a "cheat rating" that resets on ban but influences nothing; noisy, ineffective, called from many places; consumes CPU without actually banning anyone
│   │   ├── CounterPublisher            # module: counter-publisher — Photon app (own .sln) that installs Windows performance counters; Photon is deeply integrated with Windows; Photon docs describe the counters; some are used in monitoring (TODO: document which)
│   │   ├── GameModel                   # dispersed (~4.7k LOC, 16 files): fish-generator (FishGenerator 1500 LOC god-class + FishTemplate) / bite-system (AutoHookModel + Hooker + LiveBaitModel + RodInGameConfig) / wear (LeaderBreaker + LeaderCutterOnLineSlack + LeaderCutterOnLineTension + LineBreaker) / game-model-core root (CurrentGameConfig). Subfolders annotated below.
│   │   │   ├── Converters              # module: game-model-core — JSON converters for game-model primitives (BaitAccelerator, BaitColorAttraction, DragAttraction)
│   │   │   ├── Fish                    # module: fish-fight — fish stamina/tiredness during the fight (FishTireModel)
│   │   │   ├── Helpers                 # module: game-model-core — utility helpers (condition checks, NormalRandom with history)
│   │   │   └── Stats                   # module: game-model-core — async stats/telemetry persistence for fish-generation events
│   │   ├── GameModel.Tests             # note: test project for GameModel (see review section K)
│   │   ├── Loadbalancing               # note: MAIN game-server solution (`LoadBalancing.sln`, opens in Visual Studio when working on game server); csproj inside hosts 4 apps + load-balancer module + cross-cutting infra; depends on external projects (SharedLib, etc.) that also ship to WebAdmin / async-processor solutions
│   │   │   ├── Config                  # note: per-environment server configs — each env repeats Chat / Club / GameServer1-2 / Master / (Server); copied at deploy; ambition: replace with single template + env overlays and remove secrets from VCS
│   │   │   │   ├── auto-testing
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── cbt
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── clubtest
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── dev
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── devmirror
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── devred
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── dima
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── gclocal
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── gctest
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── gdktest
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── ivan
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── ivani
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── ivanps
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── ivanr
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── ivanrps
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── ivanrwss
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── ivanwss
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── local
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── localdb
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── localExpress
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── mobdev
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── mobqa
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── mobtest
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── mobtest2
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── nxcert
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── nxdev
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── nxqa
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── nxtest
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── OceanTest
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── ponddev
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── prod
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── psdev
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── psqa
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── pstest
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── pstest2
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── qa
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── retaildev
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── retaildevmirror
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── retailpsqa
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── retailpstest
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── retailsteamqa
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── retailxbcert
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── retailxbqa
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── retailxbtest
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── stable
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── stan-home-153.2
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── stan-home-153.3
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── stan-office-pt
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── stan-office-pt-wifi
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── stan-office-pt-wss
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   └── Master
│   │   │   │   ├── steamdev
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── test
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── test2
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── testvova
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── xbcert
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── xbdev
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── xbqa
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── xbtest
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   ├── yellowdev
│   │   │   │   │   ├── Chat
│   │   │   │   │   ├── Club
│   │   │   │   │   ├── GameServer1
│   │   │   │   │   ├── GameServer2
│   │   │   │   │   ├── Master
│   │   │   │   │   └── Server
│   │   │   │   └── yellowtest
│   │   │   │       ├── Chat
│   │   │   │       ├── Club
│   │   │   │       ├── GameServer1
│   │   │   │       ├── GameServer2
│   │   │   │       ├── Master
│   │   │   │       └── Server
│   │   │   ├── LoadBalancing          # dispersed: one csproj hosting 4 Photon apps (master-server, game-server, chat-server, club-server) plus cross-cutting infra; some folders look like SDK remnants
│   │   │   │   ├── Auth               # module: auth — authentication + login-time validations (device integrity, IP geo-block, ban/approval); 7 platforms; LoginAdapter.cs is ALSO part of product-delivery module (intertwined code — codebase-wide problem)
│   │   │   │   ├── Caching             # module: cache — small debug slice of the cache module (CacheHelper, CachingDebugConfig); module name is `cache`, folder name `Caching` is a historical misnaming (non-native-English authors)
│   │   │   │   ├── ChatServer         # app: chat-server — message bus; originated as chat server, now also carries inter-server / service messages
│   │   │   │   │   ├── Channeling     # module: chat-server — channel engine (ChatChannel + ChannelMemoryCache): persistent (clubs/ponds/UGC/FT) vs transient channels, size-capped FIFO cache, lazy history load
│   │   │   │   │   ├── GameServer     # module: server-to-server — inbound S2S peer from game-servers (IncomingGameServerPeer mirror of OutgoingChatServerPeer + GameServerCollection)
│   │   │   │   │   ├── Messages       # module: chat-server — message DTOs (ChatMessage with runtime state; UpdatePlayerListMessage is DEAD)
│   │   │   │   │   └── Processing     # module: chat-server — message pipeline (ChatProcessor 929 LOC god-class + 3 queues: Incoming → Delayed → Offline; state machine with 6 statuses; IMessageProcessor/MessageProcessingStatus/MessageProcessingSource)
│   │   │   │   ├── ClubServer         # app: club-server — in-memory service for the `leagues` feature; counts each club's points in the league season in real time
│   │   │   │   │   └── GameServer     # module: server-to-server — inbound S2S peer from game-servers (IncomingGameServerPeer mirror of OutgoingClubServerPeer + GameServerCollection)
│   │   │   │   ├── CommandLine        # module: chat-commands — admin "cheat-code"-style commands invoked via chat console; each command bypasses game rules and calls functions in other modules (achievements, targeted-ads, time, welcome screen, …)
│   │   │   │   │   └── Commands
│   │   │   │   ├── Common             # dispersed: mostly truly-common infra (peer/operation/S2S plumbing, HTTP queue in Net/), but also contributions to disconnect, debug, counter-publisher, chat-server, load-balancer modules — TODO: sort out and redistribute files to their rightful owners
│   │   │   │   │   └── Net
│   │   │   │   ├── DalAdapters        # dispersed: DAL-facing slices of MANY modules (adapters → see Missed). Each file is a module's DAL gateway; the folder is the richest single disperse-point in the codebase. 18 adapter files covering account-lifecycle, identity-checks, profile-management, end-of-day, friends, rewards, referrals, moderation, events, payments, auth (OnlineCache), chat/messaging, tops, licenses, weather, ponds, boats, boat-rent, fish-registry, bite-system-editor, game-rooms, game-actions, interactive-objects, fishing-together, inventory-items, wear, fish-generator, shop, product-delivery, tournaments/scoring/results, analytics-events, error-stats, disconnect, performance, game-session, diagnostics, navigation, ranks, reel-of-fortune, time-mechanics, ads, monetization, dal-abstraction
│   │   │   │   ├── Diagrams           # note: PlantUML diagrams (6 .puml files) — state-machine + fishing-cycle reference docs for the `game` system; made once to understand the tangled code. Read as aid when disentangling game-state / game-actions / bite-system.
│   │   │   │   ├── Events             # module: game-rooms (TENTATIVE) — 5 tiny event DTOs (AppStatsEvent, GameListEvent, GameListUpdateEvent, GameServerOfflineEvent, QueueEvent); very old code carried from the Photon LoadBalancing / Lite sample. Usage unclear — may be live and part of game-rooms, may be dead. Verify.
│   │   │   │   ├── GameLogic          # dispersed: core fishing-game logic. 37 files / ~700 KB. Files map to modules: `game-state` (GameStateMachine + state/transition files + SceneStateManager + GameProcessor 261 KB + MultiRodGameProcessor 70 KB + GameProcessorLogger), `ads` (TargetedAdsManager 4 partial, ~162 KB), `achievements` (AchievementManager 23 KB), `boats` (BoatManager 20 KB + BoatRodRelatedManager), `wear` (WearSystem 18 KB + ApplyWearTo* in GameProcessor), `licenses` (LicenseModel 18 KB + FishLicenseInfo), `hitches` (HitchGenerator 14 KB), `rewards` (RewardManager 14 KB + BonusManager), `analytics-events` + `ads` (StatsManager 13 KB — dispersed), `tablet` (MapSettingsProvider 9 KB), `levels` (LevelingManager + FishExperienceCalculator + FishValueModulator), `fishing-session` (FishingSessionManager 6 KB), `fish-fight` (StrongFishEscapeModel + fight methods in GameProcessor), `clubs` (ClubRoomBonusModulator), `fishing-together` (FishingTogetherBonusModulator), `rate-us` (RateUsManager), plus legacy OffersManager (dead, replaced by personal-offers in ads) and ServersideVectorDeserializer (legacy Point3 deserializer).
│   │   │   │   ├── GameServer         # app: game-server — main worker node; hosts all game logic; players spend most of their connection time here
│   │   │   │   ├── Helpers           # dispersed: 14 small utilities (~36 KB). `performance` ×4 (BadPingDetector, GcHelper [.NET GC tuning, not GameCarrier], OpTimer, OperationProcessingStats); `auth` (ConsoleHelper — Xbox/PS4 token decryption); `anti-cheat` (DenuvoProtectionHelper); `error-stats` (DiagHelper); `boats` (BoatTelemetryDto); `game-state` (FishingTelemetryDto); `game-rooms` (RoomUtilities); truly-common infra (RandomHelper, SimpleAverager, TelemetryLogger); dead (DateTimeHelper — empty stubs).
│   │   │   │   ├── LoadBalancer       # module: load-balancer — collects load/health info from game-servers (they report state); routes new players to the least-loaded game-server
│   │   │   │   │   └── Configuration
│   │   │   │   ├── LoadShedding       # module: load-balancer — Photon-SDK feedback-control load-shedding (WorkloadController reads CPU/RAM/I-O/queue/peer counters → FeedbackControlSystem → FeedbackLevel for throttling/shedding). Usage unverified — see section L.
│   │   │   │   │   ├── Configuration
│   │   │   │   │   └── Diagnostics
│   │   │   │   ├── MasterServer       # app: master-server — main load balancer + auth gateway; also delivers offline-purchase products and handles profile localization on language change
│   │   │   │   │   ├── ChannelLobby   # module: game-rooms — channel-scoped lobby variant (GameChannel + GameChannelList + GameChannelKey): property-filter channels, lazy instantiation, per-subscription cleanup cascade
│   │   │   │   │   ├── GameServer     # module: server-to-server — inbound S2S peer from game-servers (IncomingGameServerPeer mirror of OutgoingMasterServerPeer + GameServerCollection + GameServerState comparator for least-loaded selection; owns heartbeat watchdog + Flags\UpdateServerStateDelay file-based state machine)
│   │   │   │   │   └── Lobby          # module: game-rooms — master-side room registry (AppLobby + 3 IGameList backends: GameList in-memory load-aware / SqlGameList SQL-backed / GameChannelList delegating to ChannelLobby; GameState 698 LOC master-side room mirror; LobbyFactory + LinkedListDictionary; IGameList/ILobbyPeer/IGameListSubscibtion interfaces; AppLobbyType enum)
│   │   │   │   ├── Monetization       # dispersed: real-money plumbing. `purchases` module (per-platform receipt validators: Apple/Android/Epic/UnityIap/Steam + `PaymentPlatformSelector`, `PromoCodesManager`, interfaces `IPaymentEngine`/`IReceiptValidator`, DTOs). Plus `twitch-drops` module (`TwitchManager.cs` — Twitch Drops delivery via Twitch API + `RewardManager`). Both under `monetization` system.
│   │   │   │   ├── Operations        # dispersed: Photon protocol request/response DTOs (Authenticate / CreateGame / JoinGame / JoinLobby / JoinRandomGame / FindFriends / ChatMessage / ConfirmMessage / DebugGame / Profile + enums/parameters). Each DTO conceptually belongs to its domain module (auth / game-rooms+master-server / friends / messaging / debug / profile-management). Not a module; plumbing.
│   │   │   │   │   └── Profile
│   │   │   │   ├── Properties        # note: .NET project Properties folder — only `launchSettings.json` (VS launch config boilerplate). No domain content.
│   │   │   │   ├── ServerToServer    # dispersed: Photon S2S protocol plumbing (`Events\`: UpdateGame/RemoveGame → game-rooms, UpdateServer → load-balancer, UpdateAppStats → counter-publisher, AuthenticateUpdate → auth, ChatMessage/MessageConfirmation → messaging, ServerEventCode/ServerParameterCode enums; `Operations\`: RegisterGameServer[Response] → load-balancer + master-server, OperationCode enum). Not a module; inter-server plumbing.
│   │   │   │   │   ├── Events
│   │   │   │   │   └── Operations
│   │   │   │   └── Tops              # module: tops — legacy leaderboards per-peer controller (`TopsController.cs`: weekly-exp rolling 7-day tracking + TopPlayersDto async write via `IAsyncProvider`). Distinct from the new `leaderboards` module under development in this branch.
│   │   │   ├── LoadBalancing.Tests
│   │   │   │   ├── Client
│   │   │   │   ├── Core
│   │   │   │   ├── DailyMissions
│   │   │   │   ├── DalAdapters
│   │   │   │   ├── GameLogicTests
│   │   │   │   ├── Inventory
│   │   │   │   ├── NavBuoys
│   │   │   │   ├── Radar
│   │   │   │   └── Stats
│   │   │   └── TestClient
│   │   │       ├── ConnectionStates
│   │   │       ├── Const
│   │   │       ├── Properties
│   │   │       └── Stats
│   │   └── LoadBalancing.TestBot       # dead: early-dev load-generation bot (see review section H.2)
│   │       └── Properties
│   └── tools                           # note: all classified in review section H (10 active H.1 / 18 dead H.2); misnamed "Photon tools" — most unrelated to Photon SDK; **~29k LOC total** (19.8k active + 9.3k dead)
│       ├── AlterIdentity               # H.2 dead — ~409 LOC 5 files; SQL IDENTITY column script generator
│       │   └── Properties
│       ├── Chat                        # H.2 dead — ~52 LOC 3 files; unfinished chat app stub
│       ├── ClubServiceTester           # H.2 dead — ~565 LOC 7 files; load tester superseded by PhotonHelper
│       │   └── Properties
│       ├── ConfigTool                  # H.2 dead — ~166 LOC 3 files; config-manipulation utility
│       │   └── Properties
│       ├── CountWords                  # H.2 dead — ~85 LOC 3 files; word-count CLI
│       ├── DataChangesImport           # H.1 ACTIVE — module: data-pipeline (~236 LOC 4 files; console .exe imports pending DB schema-update changelog rows via interactive confirm-then-apply UPDATE; `-q` quiet mode)
│       │   └── Properties
│       ├── DataDumper                  # H.2 dead — ~294 LOC 3 files; **last-mod Feb 4 2024 + NotImplementedException stub L220** — someone touched but didn't finish replacement; superseded by DataPump
│       ├── DataPump                    # H.1 ACTIVE — module: data-pipeline (~1.6k LOC 6 files; bulk DB→DB MERGE with forbidden-tables list L28-32 + replication mode + cache-refresh signaling + comparison; `source target table_list [q|r|f|c|e]`; sync-over-async `.Result` L310-319)
│       │   └── DataPump
│       │       ├── EnvScripts          # per-env setup scripts
│       │       ├── Patches             # data-transformation patches
│       │       └── Properties
│       ├── DbMergeTool                 # H.2 dead — ~406 LOC 3 files; superseded by DataPump
│       ├── DbMergeToolGui              # H.2 dead — **~2.2k LOC 18 files** — largest dead tool; WinForms GUI superseded by DataPump CLI
│       │   ├── Helper
│       │   ├── Models
│       │   └── Patches
│       ├── EmailGenerator              # H.2 dead — ~674 LOC 23 files; email template editor + SMTP
│       │   ├── Db
│       │   │   └── Model
│       │   ├── Extensions
│       │   ├── Google
│       │   ├── Models
│       │   ├── Services
│       │   └── Templates
│       ├── EnvironmentSwitcher         # H.1 ACTIVE — module: deploy-ops (~604 LOC 11 files; WPF MVVM desktop app switching Windows env vars `SvnServer`/`SvnClient` via `Environment.SetEnvironmentVariable(...User)`; requires UAC write)
│       ├── GcTest                      # H.2 dead — ~567 LOC 3 files; C# GC experiments (**the one tool** where GC=Garbage Collector not GameCarrier/Gold Coins)
│       ├── ImageDumper                 # H.1 ACTIVE — module: shop (asset tooling) / data-pipeline-adjacent (~203 LOC 4 files + ~37 MB on-disk binary; exports product-image blobs from DB via SHA256-hash-compare + optional orphan delete)
│       ├── MaintenanceManager          # H.1 ACTIVE — module: deploy-ops (~360 LOC 8 files; console .exe with Microsoft.Extensions.DependencyInjection; generates maintenance-window JSON + SFTP-uploads to trigger remote deployment-scripts via Renci.SshNet; `env=<name> [message=<msg>] [type=Off|Scheduled|Custom] [endTime=... | duration=...]`)
│       │   ├── Extensions
│       │   ├── Properties
│       │   ├── Services
│       │   └── Settings
│       ├── MongoExport                 # H.2 dead — ~152 LOC 4 files; legacy Mongo export
│       ├── OfflineChatMessagesImport   # H.2 dead — ~110 LOC 3 files; post-downtime offline-message replay
│       │   └── Properties
│       ├── PerfCounterManager          # H.1 ACTIVE — module: counter-publisher (tooling) (~308 LOC 7 files; `-i`/`-u` install/uninstall Windows Perf Counters via dispatcher to ChatServerCounters/ClubServerCounters/CommonServerCounters; **typo "Couters" L64/L73**)
│       ├── PhotonHelper                # H.1 ACTIVE — module: qa-load-testing (wrapper folder — actual tool in nested PhotonHelper\PhotonConsole\)
│       │   └── PhotonHelper
│       │       ├── PhotonConsole       # (~1.4k LOC 7 files; console .exe embedding game-client `StandaloneClient`; load-tester spins N dev-account connections simulating fishing actions; `mc|mpc|mcc count pondId maxPlayers` + `ml|mpl|mlc` + `rc|c|p<password>`; credential-handling notes — see private audit; **user flagged "needs heavy rewrite"** — single-threaded loop + `Thread.Sleep(200ms)` throttle + commented-out multi-threaded refactor L211-212 + magic GUID L214)
│       │       └── Properties
│       ├── PondJsonExporter            # H.2 dead — ~52 LOC 3 files; one-time pond JSON export
│       ├── ReleaseTool                 # H.1 ACTIVE — module: release-tooling (**~15.8k LOC 44 files, 17 subfolders — largest tool**; console .exe with 102-case switch dispatcher for release-time migrations + one-off hotfixes; `async Task Main` but entry not awaited L38; **~30-40 of 102 commands are pre-2020 release hotfixes** — candidates for archival)
│       │   └── ReleaseTool
│       │       ├── Achievements        # ~38 LOC — small migration bucket
│       │       ├── Cmd                 # empty placeholder
│       │       ├── Common              # ~784 LOC shared helpers
│       │       ├── Converters          # ~151 LOC profile JSON converters (TargetedAdConverter likely obsolete)
│       │       ├── Disconnect          # ~38 LOC force-disconnect logic
│       │       ├── Helpers             # ~24 LOC SteamTranHelper stub (likely deprecated)
│       │       ├── Inventory           # ~2.4k LOC item move/merge/generation migrations
│       │       ├── Leagues             # ~95 LOC club-points distribution
│       │       ├── LicenseUpdate       # ~164 LOC license grant/revoke
│       │       ├── Messages            # ~121 LOC notification sending
│       │       ├── Money               # ~417 LOC currency sync with Stats DB
│       │       ├── Products            # ~557 LOC — last-mod Mar 17 2024
│       │       ├── Profile             # **~7.9k LOC largest subfolder** — profile JSON conversions; last-mod Apr 19 2024; **4 TODOs "Replace for PS" L777/L782/L828/L830** incomplete PS migration
│       │       ├── Properties
│       │       ├── Releveling          # ~406 LOC rank recalculation
│       │       ├── Scripts
│       │       │   └── ServerVisitorsFinder  # ~160 LOC analytics script
│       │       ├── Tournaments         # ~224 LOC tournament-reward processing
│       │       └── UserGenerator       # ~87 LOC synthetic test-account creation
│       ├── ReleaseTool.Tests           # note: test project for ReleaseTool (see K-section)
│       │   └── TestData
│       ├── ServiceControl              # H.2 dead — ~103 LOC 3 files; Windows Service install/start/stop boilerplate
│       ├── SqlCheck                    # H.1 ACTIVE — module: deploy-database (~673 LOC 7 files; console .exe scanning `SQL\Patches\` for .sql + checking against DB `AppliedPatches` + applying pending with 2×-patch-name-in-file safety validation; sync-over-async `.Result` L319; fragile string-replace count L147)
│       │   └── Properties
│       ├── TournamentAudit             # H.2 dead — ~374 LOC 5 files; tournament audit automation attempt
│       │   └── TournamentAudit
│       ├── TwitchApiTester             # H.2 dead — ~115 LOC 3 files; Twitch API integration test
│       ├── XblApiTester                # H.2 dead — ~82 LOC 3 files; Xbox Live API test; superseded by `Shared\XblRestApi\`
│       ├── XBoxCertChecker             # H.1 ACTIVE — module: deploy-ops (~280 LOC 4 files; console .exe inspecting local X.509 certificate store for FP + Business Partner certs with color-coded expiration; hardcoded domain list L14-18; **`DateTime.Now` vs cert `NotAfter` timezone bug L86**)
│       │   └── Properties
│       └── XstsTester                  # H.2 dead — ~53 LOC 3 files; XSTS token verification test; superseded by `Shared\Xb1Utils\XstsTokenUtils`
├── PowerDesigner
│   └── Main
├── props
├── Shared
│   ├── Android                         # module: auth + purchases — AndroidHelper (427 LOC) Google Sign-In JWT validation + Play Integrity API + Google Play Publisher v3 purchase validation; config/credential notes — see private audit; 17 files, 1140 LOC
│   │   ├── CertificateHelpers          # LocalCertificateSource (Windows machine store X.509) + RemoteCertificateSource (Google OAuth2 JWKs fetch with in-memory + file cache)
│   │   └── Types                       # 13 enums/models (PurchaseState / IntegrityApiAppRecognitionVerdict / VoidedPurchase)
│   ├── Apple                           # module: auth + purchases — AppleHelper (207 LOC) Apple ID Sign-in JWT + App Store receipt validation; credential notes — see private audit; 39 files, 3139 LOC
│   │   ├── CertificateHelpers          # RemoteCertificateSource — fetches Apple public keys from `appleid.apple.com/.well-known/keys`
│   │   └── Receipt                     # PKCS#7 container parsing + verification
│   │       ├── Models                  # AppleAppReceipt / AppleInAppPurchaseReceipt / AppleTransactionReceipt + 5 enums
│   │       │   ├── Converters
│   │       │   └── Enums
│   │       ├── Parser                  # module: purchases — binary App Store receipt parser
│   │       │   ├── Asn1                # **homegrown ASN.1 BER/DER decoder** — Asn1Node (525 LOC deprecated ArrayList + manual recursion) + Asn1Type/Tag/Oid/IAsn1Node
│   │       │   ├── Models
│   │       │   └── Services
│   │       │       └── NodesParser
│   │       │           └── Apple       # AppleReceiptParserService / Asn1NodesParser / AppleAsn1NodesParser
│   │       └── Verifier                # module: purchases — AppleReceiptVerifierService + IAppleReceiptCustomVerifierService + AppleReceiptVerificationSettings
│   │           ├── Models
│   │           │   └── IAPVerification # IAPVerificationRequest / IAPVerificationResponse + IAPVerificationResponseStatus enum
│   │           └── Services
│   ├── BiteSystem                      # module: bite-system — fish bite/catch core; client+server-shared csproj; ~6.4k LOC across 51 prod files; thin client-facing surface (raw weights + geometry) + thick server-private logic (edge distribution + chum boost + form crossover) — anti-cheat-by-design
│   │   ├── Common                      # module: bite-system (shared DTOs — exposed to client; anti-cheat surface defines what client may know)
│   │   │   └── ObjectModel             # 24 files ~2.2k LOC — Pond (root container, FindMap/Chart/FishGroup, GetWaterDepth/GetFishWeight) + BiteMap (extends ProbabilityMap, byte→float patches) + PondArea (geometry waypoint arrays, StormArea + SpeedLimitPenalty) + Fish/FishData/FishDescription/FishGroup/FishLayer + HeightMap/SplatMap/FlowMap raster terrain + BiteMapPatch/ProbabilityMap/Curve/TimeChart + Weather/WindyMaps/TimedMaps + Settings + NormalDistribution (Marsaglia)
│   │   └── ServerOnly                  # module: bite-system (server-private logic — anti-cheat-protected from client)
│   │       └── FishWeight              # 4 files ~450 LOC — FishWeightGenerator (~214 LOC, **god-method `Generate()` 86 LOC L65-151** with 4 piecewise CDF branches) + FishWeightGeneratorConfig (~148 LOC, **volatile `Current` for thread-safe atomic swap**, `FromSettings` clamps zones to [0,1] + 80% overlap-prevention) + FishWeightRounding (3 DP AwayFromZero) + FishWeightSimulationService (Monte Carlo bucket validation)
│   │           └── EdgeDistribution
│   │               └── Strategies      # 5 files ~130 LOC — `IEdgeDistributionStrategy` (Sample(rnd,u) + EdgeAreaFraction prop) + 4 strategies: `CapAtThreshold` (A=0 fail-safe default — no edge fish) / `Unrestricted` (A=1 identity) / `PowerLawEdge` (p=(1-s)^α, A=1/(α+1), hard boundary) / `ExponentialEdge` (p=e^(-λs), asymptotic, no u=1 guard); both PowerLaw+Exponential clamp params to 1e-10 for /0 + ln(0)
│   ├── BiteSystem.Tests                # note: 8 files ~1.4k LOC; **0 [Ignore]d** tests; high-quality coverage of edge-distribution math + FishWeightGenerator pipeline + ChumTests/FormatTests/HeightMapTests/PondsTests; EdgeDistributionTests has 22 methods validating range/monotonicity/boundaries/steepness-ordering
│   │   ├── Common
│   │   │   └── ObjectModel
│   │   └── FishWeight
│   ├── DataEditing
│   │   ├── Db
│   │   ├── Metadata
│   │   └── Serialization
│   ├── Denuvo                           # module: anti-cheat — thin HTTP facade for Denuvo AC-SRV API (DenuvoHelper.StartPlay/EndPlay for Steam+Epic); credential notes — see private audit
│   │   └── Properties
│   ├── Denuvo.Tests
│   │   └── Properties
│   ├── DT                               # cross-cutting infra: swappable UTC provider `DT.Helper.UtcNow` (injectable Now delegate for tests) + FP format helpers
│   ├── Epic                            # module: auth + purchases + account-lifecycle + product-delivery — EpicHelper (340 LOC) JWT auth + EpicWebApi REST client for ecommerce entitlements/ownership; 10 files, 1074 LOC; config/credential notes — see private audit; **`NotImplementedException` L325** `ValidateOwnershipToken` "unsafe without validating entitlement token"
│   │   ├── CertificateHelpers          # EpicRemoteCertificateSource (345 LOC) — fetches JWKs from **2 URLs** (Auth API v1/v2 + Ecommerce) — rotation complexity
│   │   ├── Types                       # AuthTicketValidationResult + EpicPurchaseValidationResult
│   │   └── WebResponses                # EpicEntitlement + EpicOwnership + EpicWebRequestError
│   ├── Lite                            # note: **modified Photon 4.x Lite SDK sample fork** — production-hardened foundation inherited by `Game.cs` + `GameClientPeer` + `MasterClientPeer`; ~5.4k LOC across 42 files (nested `Lite\Lite\` csproj layout)
│   │   └── Lite
│   │       ├── assets                  # note: non-code resources (skip)
│   │       ├── Caching                 # module: game-rooms (core) — RoomCacheBase (~200 LOC generic room cache + ref counting + empty-room TTL scheduler) + LiteGameCache (~42 LOC singleton) + EventCache (SortedDict<byte, Hashtable> per-actor event cache for late-joiners) + EventCacheDictionary + RoomEventCache + RoomReference (ref-counted accessor)
│   │       ├── Common                  # module: game-rooms (core) — PropertyBag<T> (~generic key-value + PropertyChanged event) + Property<T> + PropertyChangedEventArgs<T>
│   │       ├── Diagnostics             # module: performance + debug — Counter static `Games` NumericCounter (dashboard-exposed); CounterLogger deprecated; CounterDecorator (fiber queue/exec counter with label suffix)
│   │       │   └── OperationLogging    # module: debug — LogEntry (UtcNow + Action + Message + ToString CSV) + LogQueue (fixed-capacity `DefaultCapacity=1000`, writes if `IsDebugEnabled`) — **FP-added** (not vanilla Photon SDK)
│   │       ├── Events                  # module: game-rooms (core) — LiteEventBase (ActorNr + Code + Data) + JoinEvent + LeaveEvent + CustomEvent (Code 177+) + PropertiesChangedEvent
│   │       ├── Messages                # module: game-rooms (core) — GameMessageCodes enum (Operation / RemovePeerFromGame) + IMessage + RoomMessage
│   │       └── Operations              # module: game-rooms (core) — 11 files ~700 LOC: JoinRequest/Response + LeaveRequest + RaiseEventRequest + GetProperties/SetProperties + ChangeGroups + CacheOperation + PropertyType/ReceiverGroup enums
│   ├── Nintendo                        # module: auth + purchases + account-lifecycle + product-delivery — NintendoHelper (164 LOC) orchestrator for consumables/subscriptions/delivery + NintendoWebClient REST wrapper + Common env enum + AuthHandler + JWT claims; 14 files, 945 LOC; **5× `.GetAwaiter().GetResult()` sync-over-async** L22/L39/L48/L57/L83; env-aware (Dev/Prod via ConcurrentDictionary); `externalId` format `env:userId` parsed at runtime w/o validation
│   │   ├── Models                      # 8 DTOs — ErrorResponse/TransactionData/SubscriptionLicenseResponse/ConfirmDeliveryRequestItem
│   │   └── Results                     # RequestResult<T> generic wrapper
│   ├── Notifications                    # module: email-notifications — EmailSender (SMTP client + Initialize + sync/async send) + IEmailSender contract + EmailNotificationManager (pulls templates from SQL via DalFactory.GetNotificationProvider, silent-fail if DB down) + EmailMessageProducer (variable substitution)
│   ├── ObjectModel                     # dispersed: ~518 files ~68.8k LOC across 35 subfolders — shared DTO library (client+server wire format); mirrors `SharedLib\` + `Sql.Interface\` decomposition; each subfolder disperses to same domain module(s) as siblings in those projects
│   │   ├── Balance                     # module: economy + monetization — 1 file ~63 LOC: `BalanceMovementType` enum (62 income/expense types)
│   │   ├── Characters                  # module: game-state — 2 files: CharacterEventType + SpawnCoordinates
│   │   ├── Chat                        # module: chat-server + messaging — 4 files ~195 LOC: `ChatLogic` (static persistence logic) + ChatMessageBase + PrivateChatMessage
│   │   ├── Clubs                       # module: clubs — 19 files ~702 LOC: Club / ClubMember / ClubEvent / ClubContext / ClubLogo / ClubInvite / ClubTrophy
│   │   ├── Common                      # module: game-model-core — 23 files ~1.5k LOC: `Amount` + `Point3`/`Point2`/`Box` geometry primitives + BaitColorPattern + CachedValue + CollectionUtilities + SerializationHelper
│   │   ├── Configuration               # module: sys-admin (minor) — 4 files ~105 LOC: MaintenanceConfig / VariablesConfig / IndexConfig / MaintenanceStatus
│   │   ├── DailyMissions               # module: daily-missions — 47 files ~1k LOC (incl. nested CatchFishTasks/Entities/Enums)
│   │   │   ├── CatchFishTasks          # module: daily-missions — task-specific DTOs
│   │   │   ├── Entities                # module: daily-missions — entity models
│   │   │   └── Enums                   # module: daily-missions — enums
│   │   ├── Debug                       # module: debug — 2 files ~44 LOC: PlayerDesc + RoomDesc (minimal)
│   │   ├── Diagnostics                 # module: error-stats + analytics-events — 2 files ~54 LOC: PlayerReport + InternalResult
│   │   ├── Fish                        # module: fish-registry + fish-generator — 10 files ~672 LOC: Fish / FishBrief / FishCarousel / FishEnums
│   │   ├── FishCage                    # module: rewards (post-fishing capture state) — 1 file ~125 LOC: FishCageContents
│   │   ├── Fortune                     # module: reel-of-fortune — 12 files ~963 LOC: ReelOfFortuneContext (ITrackable) + ReelOfFortuneEventType + Reward + GoldenReelContext
│   │   ├── Game                        # module: game-state + achievements — 12 files ~585 LOC: Achievement + AchievementStage + AttackVector + BaitAccelerator
│   │   ├── Helpers                     # module: game-model-core — 14 files ~1.8k LOC: `ChangeTracker` (ITrackable visitor pattern) + DateTimeExtensions + EnumHelper + utility mixins
│   │   ├── Hint                        # module: game-state + missions — 26 files ~4.6k LOC UI hint engine: HintMessage + HintArrowType + HintBackgroundType + HintGizmoType
│   │   │   └── Hints
│   │   ├── Interactive                 # module: interactive-objects — 2 files ~73 LOC: InteractiveObject + InteractiveGameObjectType
│   │   ├── Inventory                   # dispersed: 118 files ~12.1k LOC — inventory-items/boats/boat-rent/rod-setup/wear/repair/gifting/chum/skins/ponds
│   │   │   ├── BoatGear                # module: boat-rent + wear — 5 files ~350 LOC: BoatGearBase + BoatAnchor + BoatFishBox + BoatFuel
│   │   │   ├── Boats                   # module: boats + boat-rent — 9 files ~510 LOC: Boat base + MotorBoat/FishingYacht/Kayak/Zodiak/BassBoat + IFishingTogetherBoat
│   │   │   ├── Carp                    # module: fish-generator + game-state — 4 files ~90 LOC (empty enum stubs for carp-specific items)
│   │   │   ├── Feeder                  # module: chum — 3 files ~280 LOC: Chum / ChumRecipe / FeedAttractionLevel
│   │   │   ├── Main                    # module: inventory-items + rod-setup — 12 files ~1.6k LOC: Inventory class extends List<InventoryItem> + InventoryItem base + InventoryChange + Rod/Reel server-only
│   │   │   ├── Misc                    # module: inventory-items — 6 files ~156 LOC misc catch gear
│   │   │   ├── Outfit                  # module: skins — 3 files ~42 LOC (avatar clothing enum)
│   │   │   ├── Property                # module: inventory-items + ponds — 5 files ~130 LOC (fish house / trophy room)
│   │   │   ├── Rigs                    # module: rod-setup — 4 files ~98 LOC: RigClasses + OffsetHook + SpinningSinker + Tail
│   │   │   ├── TerminalTackle          # module: rod-setup — 16 files ~2.1k LOC: Line/Hook/Bobber/Bait/Lure/JigBait/JigHead + **RodTemplates (31k LOC monolithic!)** + Slider + SquidChain
│   │   │   └── Tools                   # module: repair — 3 files ~54 LOC: Spoon + Thermometer + FishScaler
│   │   ├── Leaderboards                # module: leaderboards + tournament-scoring — 21 files ~613 LOC: CompetitiveLeaderboardStanding + Reward + History DTOs
│   │   ├── Leagues                     # module: leagues + competitions-lifecycle — 19 files ~1.7k LOC: League + LeagueChamp + LeagueChampResultMessage + DebugClubServerEvent
│   │   ├── Localization                # module: localization — 1 file ~92 LOC: `LocalizationManager` static singleton
│   │   ├── Mission                     # dispersed: 162 files ~23.6k LOC — largest DTO hub (~27% of ObjectModel); mostly missions+daily-missions+interactive-objects+game-state
│   │   │   ├── Boxes                   # module: missions + rewards — 6 files ~910 LOC: MissionFishBox + MissionHitchBox + MissionDynamicFish
│   │   │   ├── Client                  # module: missions + game-state — 8 files ~1.1k LOC: MissionClientConfiguration + HintMessageTranslationOnClient
│   │   │   ├── Conditions              # module: missions + daily-missions — 12 files ~1.9k LOC: ClientCondition (IPropertyAccessor) + BaseCondition + CounterAchievement + SerialAchievement + StepByStepAchievement
│   │   │   ├── ConditionsGame          # module: missions + game-state — 17 files ~2.3k LOC: FishConditions + BeginFishingCycleCondition + HitchConditions + LocationCondition
│   │   │   ├── Exceptions              # module: missions — 2 files ~136 LOC: MissionException + MissionFishingException
│   │   │   ├── Interactions            # module: interactive-objects + missions — 8 files ~880 LOC: InteractiveState + InteractiveAction + InteractiveEventType
│   │   │   ├── InteractionsGame        # module: interactive-objects + game-state — 8 files ~1.1k LOC game-specific interaction logic
│   │   │   ├── Inventory               # module: inventory-items + missions — 7 files ~1.1k LOC mission-specific inventory constraints
│   │   │   ├── Profile                 # module: profile-management + missions — 14 files ~2k LOC mission progress tracking
│   │   │   └── Resources               # module: missions + game-state — 10 files ~2k LOC: BoxGeometry_Server + CylinderGeometry_Server + GeometryReference (server-only shapes — several NotImplementedException stubs)
│   │   ├── Monetization                # module: monetization + purchases + product-delivery — 34 files ~1.8k LOC: Currency + PurchaseReceipt + InAppPurchaseData
│   │   │   ├── AndroidPurchaseReceipt  # module: purchases — Google Play receipt DTO
│   │   │   └── UnityIAP                # module: purchases — Unity IAP receipt DTO
│   │   ├── Profile                     # module: profile-management + identity-checks — 34 files ~3.4k LOC: `Profile` mega-class + BoatRent + CooldownItem + BuoySetting + ChumRecipes; **static `LevelCap` property mutable (thread-safety risk)**
│   │   ├── Push                        # module: push-notifications — 8 files ~158 LOC: PushNotification + PushBatch + PushDevice + PushBatchStatus
│   │   ├── Radar                       # module: fish-radar — 5 files ~373 LOC: FishRadarContext + LocationFishData + SquareLocation + FishRadarDataChangeSet
│   │   ├── Randomization               # module: game-model-core — 5 files ~292 LOC: CryptoRandom + DeterministicRandom + IRandom + RandomType
│   │   ├── RateUs                      # module: rate-us — 3 files ~76 LOC: RateUsPopupStatus + RateUsWarmUpDialogAnswer + RateUsWarmUpDialogButtonType
│   │   ├── RodSetup                    # module: rod-setup — 2 files ~226 LOC: RodSetup + InventoryRodSetups
│   │   ├── Serialization               # module: game-model-core — 23 files ~1.6k LOC: ClientObjectModelBinder + CompressHelper + DerivedOnlyContractResolver + AmountFromStringConverter
│   │   ├── Skins                       # module: skins — 5 files ~67 LOC: SkinElement + SkinElementType + SkinContentType + SkinSubType
│   │   ├── Stats                       # module: analytics-events + leaderboards — 7 files ~2.3k LOC: PlayerStats + DailyStats + LeaderboardStats + BoatBoardingStats
│   │   ├── Together                    # module: fishing-together — 21 files ~1.1k LOC: FishingTogetherBoatContext + FishingTogetherBoatMember + EndFishingTogetherResult + FishingTogetherBoatMemberState
│   │   ├── Tops                        # module: leaderboards + tops — 4 files ~66 LOC: TopFish + TopPlayers + TopPlayerBase + TopTournamentPlayers
│   │   ├── Tournaments                 # module: tournaments-lifecycle + tournament-results + tournament-scoring + user-generated-lifecycle — 39 files ~4.3k LOC: UserCompetitionPublic + UserCompetitionLogic + FilterForUserCompetitions + MetadataForUserCompetition + SecondaryReward; **TODO L… "remove after 01.08.2020"** stale dead-code marker
│   │   └── Travel                      # module: travel + pond-unlocks + ponds + licenses — 22 files ~835 LOC: BoatDesc + Country + PondDesc + BuoyColor + PondLicenseInfo + ChangeResidenceInfo
│   ├── ObjectModel.Tests               # note: 15 test files ~18k LOC — UNIT tests (DTO validation + logic methods, no integration/DB); strong DTO-schema coverage + Fortune logic (~4.7k LOC in 1 file); Core helpers with underscore-named separator methods (intentional test-flow markers)
│   │   ├── App_Data                    # test fixture data files
│   │   │   └── DailyMissions
│   │   │       └── CatchFishTasks
│   │   ├── Buoys                       # 1 file ~0.3k LOC — buoy state transitions
│   │   ├── Core                        # 5 files ~6.3k LOC helpers: RodTemplatePrototype + AssertInventory + TestFlow + TestCounter
│   │   ├── DailyMissions               # 2 files ~1.1k LOC DTO validation
│   │   │   └── Entities
│   │   ├── Fortune                     # 1 file ~4.7k LOC — ReelOfFortuneLogicTests (spin logic unit validation)
│   │   ├── Mission                     # 1 file ~1.8k LOC condition game logic
│   │   │   └── ConditionsGame
│   │   ├── Radar                       # 1 file ~0.4k LOC radar DTO
│   │   ├── Stats                       # 3 files ~2k LOC PlayerStats aggregation
│   │   └── Travel                      # 1 file ~0.8k LOC travel cost / pond unlock logic
│   ├── Photon.Interfaces               # dispersed: 62 files ~1.6k LOC — Photon RPC contracts (OperationCode / ParameterCode / ErrorCode / SubOperationCode / EventCode enums) shared client+server; 18 subfolders disperse to domain modules; 10 root-level files incl. master `OperationCode.cs` (195 LOC ~50 ops) + massive `Chat.cs` (405 LOC cross-cutting messaging infra) + `SharedConsts.cs` (protocol v1124 + 14 languages + 8 platforms + A/B test IDs)
│   │   ├── Auth                        # module: auth + identity-checks — 1 file 8 LOC: AndroidAuthParameters (device-integrity data POJO)
│   │   ├── Chat                        # module: chat-server + messaging — 1 file 16 LOC: ChatSubOperationCode (5 ops Send/Confirm/GetPlayersCount/GetMessages); main chat infra lives in root Chat.cs (see above)
│   │   ├── Fortune                     # module: reel-of-fortune + rewards — 3 files 58 LOC: ReelOfFortuneParameterCode + ErrorCode + SubOperationCode (regular/premium/ads/golden spin types)
│   │   ├── Game                        # module: game-state + game-actions + fishing-session — 3 files 80 LOC: GameActionCode (25 actions Throw/Water/Spool/Move/FightFish/CatchFish/Board/Walk + ElectricAutoWinding code 24) + BaitConsumeReason + FishEscapeStatus
│   │   ├── Inventory                   # module: inventory-items + rod-setup + wear + repair — 2 files 34 LOC: InventoryParameterCode (22 keys) + RodSetupParameterCode + InventoryOperationCode + InventoryErrorCode
│   │   ├── LeaderBoards                # module: leaderboards — 5 files 97 LOC: SubOperationCode / ParameterCode / ErrorCode / LeaderBoardEnums / LeaderboardsQueryType (Competitive + Global + Fish)
│   │   ├── Leagues                     # module: leagues + clubs + competitions-lifecycle — 3 files 120 LOC: LeaguesSubOperationCode + LeaguesParameterCode (50+ keys covering seasons/champs/divisions/scores/bans/disqualification) + LeaguesErrorCode
│   │   ├── Monetization                # module: monetization + ads + purchases + product-delivery — 5 files 90 LOC: ThirdPartyAdsSubOp/Param/Error + PremiumShopSubOp + ProductTypes enum (MoneyPack/StarterKit/PremiumAccount/PondPass/InventoryExtension/RodPreset/Buoys/ChumRecipe/Container/NavBuoys/RepairKit)
│   │   ├── MultiRods                   # module: rod-setup + fishing-session — 2 files 26 LOC: MultiRodsParameterCode (StandId/RodId/Identifier) + MultiRodsErrorCode; **enums live but `GameClientPeer_MultiRods.cs` client dispatcher is commented-out** (prior N-finding)
│   │   ├── NavBuoys                    # module: buoys + travel + pond-unlocks — 3 files 48 LOC: NavBuoySubOp (Set/Take/Rename/CanTravel/Travel/RemoveTravelCooldown) + ParameterCode + ErrorCode
│   │   ├── Profile                     # module: profile-management + account-lifecycle + identity-checks — 4 files **223 LOC** (largest Profile scope): ProfileParameterCode (96 codes login/profile/device-integrity/subscriptions/rankings/bans/buoys/clubs) + ProfileSubOperationCode + ErrorCode + **ActorPropertyCode** (in-room player props: avatar/level/rank/club/boat-color/TPM); **TODO L27** "remove after merge" (TpmBranchType legacy cosmetics)
│   │   ├── Push                        # module: push-notifications + messaging — 3 files 71 LOC: PushNotificationsSubOperationCode (RegisterDevice/UpdateDeviceToken/CanAskForPermission/GetIsPermissionRequested/ResetIsPermissionRequested) + ParameterCode + ErrorCode
│   │   ├── RateUs                      # module: rate-us — 1 file 8 LOC: RateUsSubOperationCode (RegisterWarmUpDialogAnswer + RegisterPopupShow only)
│   │   ├── SharedMethods               # **MISPLACED** — not RPC contracts; 2 files 136 LOC utility helpers `InGameTimeHelper` (pond-day calc ≠ calendar-day, starts at 5am, max 30-day stays, IsNewDayStarted, HasPondStayFinished) + `TimeRewinder` (cooldown multiplier removing night hours); **namespace `SharedLib.Game` mismatches folder** — should be in `SharedLib\Game\` or separate infra folder; consumed by game-state + fishing-session + time-mechanics
│   │   ├── SkinElements                # module: skins + clubs (absorbed) — 3 files 20 LOC minimal: SkinElementsSubOperationCode (GetAll=0 only) + ParameterCode + ErrorCode — single read-only op, consumed by club-logo editor
│   │   ├── Sys                         # module: debug + cache + system — 3 files 51 LOC: SysSubOperationCode (SetAddProps/GetCurrentEvent/GetLatestEula/SignEula/CreateSupportTicket/GetAbTestSelection/SpawnFish; **codes 2/3/10/11/12 skipped** — refactored/deprecated) + SysParameterCode + `UserLib` (DLL metadata for anti-cheat asset-integrity validation: path/size/hash/PE-signature)
│   │   ├── Together                    # module: fishing-together + friends + game-rooms — 3 files 152 LOC: FishingTogetherSubOperationCode (GetPonds/GetPondWeather/Boats/Friends/Clubmates + Create/Update/Delete/Start/Finish + InvitePlayer/Accept/Decline/Move/MakeCaptain/SyncBoatContext/TakeBoatControl/ReturnBoatControl/SetScreenMode + OnContextChanged/Result/OnBoatContextChanged/OnTeleported events) + ParameterCode + ErrorCode
│   │   └── Tournaments                 # module: tournaments-lifecycle + tournament-scoring + tournament-results + competitions-lifecycle + user-generated-lifecycle — **5 files 444 LOC — LARGEST subfolder**: TournamentSubOperationCode (28 ops) + UserCompetitionSubOperationCode (27 UGC ops) + TournamentParameterCode + UserCompetitionErrorCode + **TournamentKinds enum** (Sport=1 / Competition=3 / UserGenerated=4)
│   ├── SharedLib
│   │   ├── AbTests
│   │   ├── Achievements                 # module: achievements — single file AchievementUtils (~55 LOC) resolving achievement counters from PlayerStats by counter type
│   │   ├── Async                        # module: farm-reboots — misnamed folder; actually FarmRebootSchedule POCO + AsyncHelper deserialization (not async-processor-related)
│   │   ├── Balance                      # economy foundation: single file BalanceHelper (~226 LOC) — currency-wallet primitive (IncrementBalance sync/async + Check + statement/analytics dual-write) used by dozens of GameLogic call-sites
│   │   ├── Caching                      # module: cache — core infrastructure (CachedEntity + CachedEntityBase + Caches registry + DataCache TTL-variant + CacheRefreshHelper background polling thread + CacheWrapper + ICachedEntity); base classes for all 56 domain caches
│   │   ├── Clubs                        # module: clubs — core runtime (~2.7k LOC, 19 files): ClubAdapter main + 10 concern partials (_CRUD / _JoinLeave / _InviteToClub / _UpDownRoleKick / _Afk / _BaitsBuoysFishing / _ClubTokens / _ClubEvents / _Search / _Logo) + ClubAdapterExtensions + IClubPeer + MockClubPeer + StandaloneClubPeer + SynchronizedClubContext + ClubActivityRewardModel + logo-skin subsystem (SkinElementPrice + SkinHelper)
│   │   ├── Config                       # module: cache — 56 domain cache classes + config infra (CacheClasses generic hashes + CacheGroups enum + ConfigParametersProvider + PlatformMapping + StaticHandlersConfig + JsonVariables partials); each XxxCache disperses into its owning module (see review for dispersal table)
│   │   ├── CurrencyExchange             # module: purchases — CurrencyFreaks.com external-API integration (USD-equivalent revenue calc); DI registration + IRateDownloader contract; fuels MonetizationCache.GetCurrencyExchangeRate
│   │   │   └── CurrencyFreaks           # module: purchases — HTTP client + 3 DTOs (GetLatestRatesResponse + GetSupportedCountriesResponse + SupportedCurrency)
│   │   ├── DailyMissions                # module: daily-missions — core runtime (~4k LOC, 33 files): DailyMissionAdapter main+2 partials (_Admin/_Core) + DailyMissionGenerator main+3 partials (_MissionDifficulty/_Similarity/_Utils) + MissionBuilderBase/Catch + PondPoolBuilder + DailyMissionLocalizer + DailyMissionUtils (massive 509 LOC DTO converter) + IDailyMissionPeer contract + Mock/Standalone peers + ObjectModelExtensions
│   │   │   └── CatchFishTasks           # module: daily-missions — task-building sub-subsystem (17 files): 5 cached settings services + 5 interfaces (DI) + TaskBuilderBase main+2 partials (_FishFormCountWeight/_OtherConditions) + 3 concrete TaskBuilder{First/Second/Third} (exploration-strategy, NOT difficulty tiers) + TaskLocalizer
│   │   ├── Device                       # module: auth — Android Play Integrity / SafetyNet adapter (DeviceIntegrityAdapter + DeviceIntegrityData); challenge-response nonce flow
│   │   ├── Diagnostics                  # dispersed: module `debug` (Log4netDebugUtility dev-server trace hub + IntervalDebugMarker throttler) + `diagnostics` system (StatisticEventsHive singleton counter-aggregator + StatisticEventsCounter)
│   │   ├── FarmReboots                  # module: farm-reboots — FarmRebootAdapter (state-machine emits OnReboot/OnRebootCancel events with 60/30/10/5-min threshold debouncing) + FarmRebootHelper (background scheduler, 60s Check Phase + 10s Wait Phase + 60-min visibility horizon)
│   │   ├── Fortune                      # module: reel-of-fortune — ReelOfFortuneAdapter main + _Peristence partial (typo) + Extensions + IReelOfFortunePeer + MockReelOfFortunePeer; 2-tier A/B+geo feature-gates; regular/golden spin variants
│   │   ├── Game                         # dispersed: module `fish-registry` (FishCache L0 — referenced by dozens of modules + IFishCache + ServerFish entity + FishUtils code-suffix parser) + module `bite-system` (BiteSystemCache L2, InitOnMaster/Game/Tech variants) + module `profile-management` (InitialProfileCache L0 starter-template) + module `fish-fight` (PullingForceMultiplier POCO) + infra DistributedCache wrapper
│   │   ├── Helpers                      # dispersed: pure cross-cutting utilities (UnitOfWork transaction/saga base — heavily used by leagues; ParameterDictionaryExtensions for all Photon RPC; Rational exact-fraction; VariablesDictionary; DataFileHelper CSV/GZip; MathUtility hot-path Lerp/Clamp; ExceptionExtensions; IpAddressHelper; TextHelper range parser; EnumerableExtensions; PingPongTraversalIterator; StringDictionaryExtensions)
│   │   ├── Leaderboards                 # module: leaderboards (new, LBM20251201 branch) — 3x2 structure (~2.7k LOC, 8 files): LeaderboardsAdapter main + 3 sub-domain partials (Competitive tournament-linked / Global player XP+5 fish counters / Fish pond×species) + LeaderboardsHelper main + 3 sub-domain partials; stateful Adapter (DAL + reward distribution) vs stateless Helper (DTO conversion + dimension mapping); period rotation state machine 8 states; 12 feature flags; reward delivery via chat-server async + LeaguesAdapter club points
│   │   ├── Leagues                      # module: leagues — core runtime (3 clusters + 11 scheduled jobs, ~6.5k LOC): LeaguesAdapter (10 partials — stateless logic for game-server + club-server), GlobalLeaguesContext (game-server app-wide state with ActiveSeason/Champ + events), InMemoryClubPointService (5 partials — real-time scoring engine hosted by club-server), UnitOfWork_* (11 lifecycle jobs: TryScheduleChamps/TryStartSeason/TryStartChamp/TryEndChamp/TryEndChampReview/EndChampReview/TryEndSeason/TryEndSeasonReview/EndSeasonReview/TryArchiveSeasons/TryUnbanPlayers), peer interfaces (ILeaguesPeer/MockLeaguesPeer/StandaloneLeaguesPeer), SafeIdQueue
│   │   ├── Licenses                     # module: licenses — single file LicenseHelper (~134 LOC): DTO→PlayerLicense transformation + cost/discount calc + resident-vs-non-resident + inactive-fish filter
│   │   ├── Logging                      # module: dal-log — user-activity log shipping pipeline (UserLogsToMongoSync 352 LOC async filesystem→Mongo with reflection-based StreamReader position tracking + backoff + stale-file cleanup; UserLogsToMongoBuffer/Settings/Status) + logger decorators (ILoggerWrapper ExitGames + ILogWrapper log4net) + InventoryLoggingExtensions
│   │   ├── MeasuringUnits               # module: localization — MeasuringSystemManager (430 LOC per-locale metric/imperial/metric-English conversion via UnitsNet library, 13 language→system mappings) + MeasuringConvertationException (typo "Convertation")
│   │   ├── Missions                     # module: missions — single file MissionHelper.cs (~583 LOC cross-cutting admin+analytics utility used by both missions core + daily-missions): 14-case admin switch (mission lifecycle ops) + 2 daily-mission ops + CreateDailyMissionAdapter factory (StandaloneDailyMissionPeer for offline WebAdmin) + LogMissionData + DTO converters
│   │   ├── Monetization                 # dispersed: module `product-delivery` (ProductDeliveryService router + TrackedProductDelivery 980 LOC engine + DeliveryContent 7 DTOs + MonetizationHelper 595 LOC utilities) + module `purchases` (LocalPriceCalculator 285 LOC Smart Beautify regional price algorithm) + module `third-party-ads` DEPRECATED (ThirdPartyAdsAdapter + IThirdPartyAdsPeer + MockThirdPartyAdsPeer)
│   │   ├── Payments                     # module: purchases — single file PaymentHelper (~92 LOC): regional price lookup (currency+country) + currency-specific rounding (CLP/JPY/CNY/KRW/CRC variants) + discount-window check
│   │   ├── Profile                      # dispersed: module `profile-management` (ProfileHelper ~1892 LOC foundational serialization hub + AvatarHelper + IProfilePeer contract; MockProfilePeer + TestProfileHelper are misplaced test-only) + module `account-lifecycle` (UserAccountAdapter multi-account binding + AccountBindingHelper) + module `purchases` (PromoCodeAdapter ~92 LOC — misplaced, belongs with Monetization\PromoCodesManager)
│   │   ├── Push                         # module: push-notifications — core runtime (~2.65k LOC, 22 files): PushNotificationsAdapter main + 2 concern partials (_Notifications / _PushDevices) + 4 plugin contracts (IPushNotificationsPeer/Sender/SendSkipper/VariableProvider) + PushNotificationsLogic + PushCountPerUserCache (per-user throttle, also consumed by ChatProcessor) + MockPushNotificationsPeer + 5 Senders (FCM Android/Apple via abstract FirebaseCloudMessagingSender 378 LOC + log-only Steam/PushLog) + 7 UnitOfWork notification-generation jobs (CreateBatchNotification / GenericNotification / LoginReminder / NewTournamentRegistration / IncomingItemReceived / SendNotifications 511 LOC main dispatcher / SendNotificationsAll loop wrapper)
│   │   │   └── Senders                  # module: push-notifications — FCM implementations: abstract FirebaseCloudMessagingSender (500-token batch chunking + Unregistered-error token-invalidation) + concrete AndroidFcmPushNotificationSender + AppleFcmPushNotificationSender + PushLogPushNotificationSender (log-only base) + SteamPushNotificationSender (via log-only)
│   │   ├── Radar                        # module: fish-radar — FishRadarManager (~350 LOC BFS grid-square search with 4-min refresh; consumes IFishRadarHost + FishRadarContext + GameServerCache + host.BiteMap + GlobalVariablesCache.SonarSquareLength) + IFishRadarHost interface (impl'd by GameClientPeer_Radar) + RadarAreaPrediction (~100 LOC max-reach + IsInArea with 1.2× backward-area multiplier); plus IMapSettingsProvider for module `tablet`
│   │   ├── Rewards                      # module: rewards — single file RewardUtils (~494 LOC biggest single reward utility): DTO→Model parser + loot-table resolver (FromDtosWithLootTableResolve + InheritReward merge) + random selector (SelectSpecificReward non-repeatable retry-loop / repeatable with replacement) + view-data cache hydration + startup ValidateRewards (cross-platform coverage checks)
│   │   ├── Shop                         # module: shop — item-template rendering subsystem (~236 LOC, 6 files): MultilingualTemplate lang→template + InventoryParam DTO hierarchy + InventoryParamProducer template engine (substitute {paramName} + metric↔imperial for lang=1 USA) + InventorySortingGroup UI hierarchy tree + ItemParameterTemplateData config + MeasurementUnits enum
│   │   ├── TargetedAds                  # module: ads — single file TargetedAdsHelper (~66 LOC): payer cohort definitions (Minnows/Dolphins/Whales + Monthly variants) + StatsCollectingPeriodDays/NewPayerMaxAgeDays constants for analytics bucketing
│   │   ├── Together                     # module: fishing-together — core runtime (~3.5k LOC, 17 files): FishingTogetherAdapter main + 10 concern-grouped partials (_Create / _Invite / _JoinLeave / _Capitanicity (typo → Captaincy) / _Boat (603 LOC biggest) / _StartFinish / _Persistence / _Chat / _Time / _Stats) + Extensions + IFishingTogetherPeer contract with nested IRoom (impl in Game.cs) + Mock + Standalone peers + MockRoom + SynchronizedFishingTogetherContext (placeholder with just SessionId)
│   │   ├── Tournaments                  # dispersed: competitive system runtime across 5 modules (~6.5k LOC, 24 files) — tournaments-lifecycle + competitions-lifecycle + user-generated-lifecycle + tournament-scoring + tournament-results. 6 lifecycle adapters (TournamentScheduling/Start/End/RatingCalculator/sHelper + MatchmakingLogic tournament-bracket seeding NOT room-matchmaking) + UGCProcess main class with 13 numbered partials (8 lifecycle phases across 7 role-interfaces Public/Player/Host/Reviewer/System/Events/Internals) + UGCProcessUtils + 4 UserCompetition* adapters (Start/Promotion/Cleanup/Exception)
│   │   ├── Travel                       # module: weather — WeatherBuilder (~213 LOC batch generator for 9 time-of-day windows) + RandomizeWeatherModel (~495 LOC WebAdmin form with 15 variation params + AttackAccelerators export) + WeatherExtensions (DTO converters + base-vs-generated name check)
│   │   └── Web                          # dispersed: module `product-delivery` (ProductHelper ~705 LOC admin product-delivery orchestrator with SendProductToPlayer/GiveOfflineProduct/DeliverInitialStarters/RefundProduct multi-system reversal) + WebAdmin utilities (EntityCloningRule bulk-clone DTO + TranStatuses constants)
│   ├── SharedLib.Tests
│   │   ├── Clubs
│   │   ├── Config
│   │   ├── DailyMissions
│   │   │   └── CatchFishTasks
│   │   │       └── TestSettings
│   │   ├── Helpers
│   │   ├── Leaderboards
│   │   ├── Leagues
│   │   ├── Logging
│   │   ├── Monetization
│   │   ├── Profile
│   │   ├── Radar
│   │   ├── Together
│   │   ├── Tournaments
│   │   │   └── Helpers
│   │   ├── Travel
│   │   └── Web
│   ├── StandaloneClient                 # module: photon-standalone-client — Photon client library for inter-server RPC (misnamed "client"; server-only). PhotonStandaloneClient ~1300 LOC main wrapper + PhotonHelper static factory + PhotonHelperDynamic + ClubHelper + 8 request/response DTOs. Consumed by Auth/WebAdmin/TwitchManager/tests.
│   │   ├── Helpers
│   │   └── Models
│   ├── Steamworks                       # module: purchases — SteamHelper (Steam Partner API: auth-ticket validation + DLC ownership + MicroTxn lifecycle + DlcPrice batch + reports); 3-tier URL fallback; credential notes — see private audit; SteamUtils language+OrderId conversion
│   ├── Streamworks.Tests
│   ├── Twitch                           # module: twitch-drops — TwitchApiUtils (Twitch Helix API: ValidateToken + RefreshToken async + GetDropEntitlements paginated + FulfillDropEntitlements batch-PATCH); credential notes — see private audit; separate from top-level Twitch\TwitchAccountLinking OAuth service
│   ├── Twitch.Tests
│   ├── Xb1Utils                        # module: auth — minimal Xbox One SDK; XbUtils device-type check (XboxOne/Scarlett) + XstsTokenUtils JWT parsing; 9 files, 1004 LOC; no hardcoded secrets (good)
│   │   ├── CertificateHelpers          # LocalCertificateSource (Windows store) + RemoteCertificateSource (Xbox Live XSTS keys) + CertNotValidException
│   │   ├── Classes                     # XstsTokenData (claims + expiry)
│   │   └── Enums                       # XstsValidationResult + Xb1Const + Xb1UserPrivileges
│   └── XblRestApi                      # module: auth + product-delivery — Xbox Live delegated-auth library (server-to-server REST calls)
│       ├── XblApiHelper                # 19 files, 2763 LOC — XblApi REST client + complex ECC-signed delegated auth (Microsoft proprietary XSTS pattern)
│       │   ├── DelegatedAuth           # 12 files ~1.1k LOC — XstsDelegatedAuth (325 LOC signed-request builder) + SignaturePolicy + ProofKeyUtility ECC-signing + XstsServiceToken[Controller] caching + XblEndpointsController + XblEndpointsContext + EccJsonWebKey
│       │   ├── Middleware              # XstsMiddleware (37 LOC — parses/validates claims + expiry `UtcNow`) + XstsClientToken JWT claims
│       │   ├── Models                  # XblPeopleResponse
│       │   └── Utilities               # XstsConstants + XstsUtilities
│       └── XblApiHelperTest            # note: Program.cs stub, NOT real unit tests
├── SoftwareDistributor                  # module: software-distributor — standalone ASP.NET MVC 4.0 (.NET Framework 4.7.2, EOL 2026) server-farm lifecycle UI; Distributor.json-driven farm+node config; broadcasts Start/Stop/Download/Apply commands via ScriptExecutor remote-invocation; SimpleMembership legacy auth
│   ├── Actions
│   │   └── GameCarrier
│   ├── Configs
│   │   └── GameCarrier
│   ├── DistributorCommon
│   └── SoftwareDistributor
│       ├── App_Data
│       ├── App_Start
│       ├── Content
│       │   └── themes
│       │       └── base
│       │           ├── images
│       │           └── minified
│       │               └── images
│       ├── Controllers
│       ├── Filters
│       ├── Images
│       ├── Models
│       ├── Properties
│       │   └── PublishProfiles
│       ├── Scripts
│       ├── SoftwareDistribution
│       └── Views
│           ├── Account
│           ├── Home
│           ├── Manage
│           └── Shared
├── SQL
│   ├── AdHoc
│   ├── Admin
│   ├── AntiCheat
│   ├── Constraints
│   ├── Import
│   ├── Inventory
│   ├── Missions
│   ├── Patches
│   │   ├── DevOnly
│   │   ├── Initial
│   │   ├── Main
│   │   │   ├── Functions
│   │   │   ├── Procedures
│   │   │   ├── Triggers
│   │   │   └── Views
│   │   ├── OldRetail
│   │   ├── PrepareTests
│   │   ├── SqlCheck
│   │   ├── Stats
│   │   │   ├── Functions
│   │   │   ├── Procedures
│   │   │   ├── Triggers
│   │   │   └── Views
│   │   └── UgcOld
│   ├── Reapply
│   ├── Releases
│   ├── Setup
│   ├── StatsDB
│   ├── StatsDbReplication
│   ├── Translations
│   └── Users
├── Twitch                               # top-level Twitch umbrella: contains TwitchAccountLinking service + 4 OAuth provider libraries (NOT same as Shared\Twitch\ Helix-API helper for drops — see that folder)
│   ├── AspNet.Security.OAuth.Epic       # module: oauth-providers — Epic OAuth handler (JWT introspection via IdentityModel.TokenIntrospectionRequest)
│   │   └── Extensions
│   ├── AspNet.Security.OAuth.Nintendo   # module: oauth-providers — Nintendo OAuth (minimal: Options + Defaults + Extensions only; handler inherited)
│   │   └── Extensions
│   ├── AspNet.Security.OAuth.PlayStation  # module: oauth-providers — PlayStation OAuth (Basic-auth header from ClientId:ClientSecret + Initializer pre-auth + external-logout URI)
│   ├── AspNet.Security.OAuth.XBox       # module: oauth-providers — Xbox OAuth (form-body client_secret + AuthUserRequest/Response DTOs)
│   │   ├── Extensions
│   │   └── Models
│   └── TwitchAccountLinking             # module: twitch-account-linking — standalone ASP.NET Core MVC; OAuth2 auth-code flow for Twitch + platform auth middleware (Steam/PS/Apple/Google/Epic/Xbox/Nintendo via oauth-providers sub-modules); credential + session-cookie notes — see private audit; 10-day session timeout
│       ├── .config
│       ├── Controllers
│       ├── DAL
│       ├── Extensions
│       ├── Models
│       ├── Properties
│       │   └── PublishProfiles
│       ├── Utils
│       ├── Views
│       │   ├── Authentication
│       │   ├── Home
│       │   └── Shared
│       └── wwwroot
│           ├── css
│           ├── images
│           ├── js
│           └── lib
│               ├── bootstrap
│               │   └── dist
│               │       ├── css
│               │       └── js
│               ├── jquery
│               │   └── dist
│               ├── jquery-validation
│               │   └── dist
│               └── jquery-validation-unobtrusive
├── Updater
│   ├── Patcher
│   └── Updater.Core
│       └── Exe
├── WebAdmin                            # note: 8 web-apps/utilities for admin operations; main `WebAdmin\WebAdmin\` + 4 satellite MVC apps + 2 CLI utilities + tests; all ASP.NET Framework 4.7.2 + MVC 4.x + SimpleMembership auth + Kendo UI Q2 2013 (11yo!); security notes — see private audit
│   ├── Dashboard                       # module: admin-portal (NEW, minor) — tiny real-time counter widget (~60 LOC): HomeController.GetDashboardCounter + DashboardCounterModel + TournamentResult; endpoint-protection notes — see private audit
│   │   ├── App_Data
│   │   ├── App_Start
│   │   ├── Controllers                 # HomeController 2 actions
│   │   ├── css
│   │   ├── Fonts
│   │   │   ├── codropsicons
│   │   │   └── menuicons
│   │   ├── img
│   │   ├── js
│   │   ├── Models                      # DashboardCounterModel + TournamentResult
│   │   ├── Properties
│   │   │   └── PublishProfiles
│   │   └── Views
│   │       └── Home
│   ├── DataSyncDashboard               # module: admin-portal (NEW, minor) — monitor cross-env data sync status (PROD/QA/DEV/etc) ~70 LOC; MVC 4.0 (older than main); HomeController.Index + Changes + AccountController; logging-config notes — see private audit; [Authorize] on HomeController
│   │   ├── App_Data
│   │   ├── App_Start
│   │   ├── Content
│   │   │   └── themes
│   │   │       └── base
│   │   │           ├── images
│   │   │           └── minified
│   │   │               └── images
│   │   ├── Controllers
│   │   ├── Filters
│   │   ├── Images
│   │   ├── Models                      # DataSync + Environment + StatusCache + Dal + TimestampedEvent + DataChange
│   │   ├── Properties
│   │   │   └── PublishProfiles
│   │   ├── Scripts
│   │   └── Views
│   │       ├── Account
│   │       ├── Home
│   │       └── Shared
│   ├── JsonVerificator                 # tool: alive (confirmed) — compiled console .exe ~73 LOC; validates JSON deserialization against ObjectModel types via reflection; usage `JsonVerificator.exe <file.TypeName>`; consumed by WebAdmin code as compiled .exe reference; references ObjectModel only, no DB access
│   ├── ProfileUtils                    # tool: alive (confirmed) — compiled console .exe ~182 LOC; Profile JSON DB↔file export/import; usage `ProfileUtils.exe [in|out] <userId> <file>`; direct `SqlConnection` via `ConfigurationManager.ConnectionStrings["sql"]`; reflection-based SQL parameter-binding (see private audit) + no transaction on UPDATE + silent catches
│   ├── RepositoryService               # module: admin-portal (NEW, minor) — SVN revision-query HTTP handler (~100 LOC); `CheckRevision.ashx` handler + Settings; queries svn log between revisions; **no authentication + command-injection risk** in comment param concatenation to `svn log` shell command L79-81; SVN credentials in Web.config Settings
│   │   └── Properties
│   │       └── PublishProfiles
│   ├── WebAdmin                        # module: admin-portal (main) — main admin portal ASP.NET MVC 4 / .NET 4.7.2; 399 C# files + 377 Razor views ~59k LOC; SimpleMembership + FormsAuth; CustomAuthorize with role-based checks (`Roles="Missions"` etc); config secrets notes — see private audit; **Kendo UI Q2 2013** (build-machine dep on `C:\Program Files (x86)\Telerik\Kendo UI for ASP.NET MVC Q2 2013\`); 21 controllers incl. PlayerController 2057 LOC + StatsController 1645 LOC + HomeController 1412 LOC + ToolsController 1210 LOC
│   │   ├── App_Data
│   │   ├── App_Start
│   │   ├── Components
│   │   │   └── TargetedAdsPlanningTool # module: ads (Vue SPA embedded in Razor) — ~16 MB bundle; Vue 2.6.11 + Vuetify 2.2.11 + TypeScript 3.9.3; @vue/cli 4.5; config-planning UI for targeted ads (PersonalOffers + TargetedAds + WelcomeAds); static dictionaries (AchievementStages/Currency/Fish/InventoryItems/Levels/Missions/Ponds/Tournaments); Axios to WebAdmin API endpoints (inherits Razor auth, no separate token)
│   │   │       ├── dist
│   │   │       │   ├── assets
│   │   │       │   └── Tools
│   │   │       │       ├── TargetedAdsPlanningData
│   │   │       │       └── TargetedAdsPlanningDictionary
│   │   │       ├── public
│   │   │       │   └── Tools
│   │   │       │       ├── TargetedAdsPlanningData
│   │   │       │       └── TargetedAdsPlanningDictionary
│   │   │       ├── scripts
│   │   │       │   └── modules
│   │   │       └── src
│   │   │           ├── api
│   │   │           ├── assets
│   │   │           ├── components
│   │   │           ├── modules
│   │   │           ├── plugins
│   │   │           └── types
│   │   ├── Content
│   │   │   ├── kendo
│   │   │   │   └── 2013.2.918
│   │   │   │       ├── Black
│   │   │   │       ├── BlueOpal
│   │   │   │       ├── Bootstrap
│   │   │   │       ├── Default
│   │   │   │       ├── Flat
│   │   │   │       ├── HighContrast
│   │   │   │       ├── images
│   │   │   │       ├── Metro
│   │   │   │       ├── MetroBlack
│   │   │   │       ├── Moonlight
│   │   │   │       ├── Silver
│   │   │   │       ├── textures
│   │   │   │       └── Uniform
│   │   │   └── themes
│   │   │       └── base
│   │   │           ├── images
│   │   │           └── minified
│   │   │               └── images
│   │   ├── Controllers                 # 21 controllers; dispersed across domain modules — Account (admin-portal auth) / Home god 1412 LOC (admin-portal table CRUD) / Player 2057 LOC (profile-management+account-lifecycle+moderation) / Stats 1645 LOC (analytics-events) / Tools 1210 LOC (admin-portal) / Clubs / DailyMissions / Reports (moderation+anti-cheat) / Logs (admin-audit) / Message / PushNotifications / WeatherInfo / Environment
│   │   │   └── WorldSettings
│   │   ├── Filters                     # CustomAuthorize + anti-forgery filter config
│   │   ├── Helpers
│   │   ├── Images
│   │   ├── Migrations                  # EF migrations for WebAdmin schema
│   │   ├── Models                      # dispersed: ~200 files ~42k LOC mirror domain structure
│   │   │   ├── Abstractions            # module: admin-portal — base model classes
│   │   │   ├── Abuse                   # module: moderation
│   │   │   │   └── AntiCheat           # module: anti-cheat — Denuvo ban management + behavior flags
│   │   │   ├── AdminActionLogging      # module: admin-audit
│   │   │   ├── BiteSystem              # module: bite-system + bite-system-editor
│   │   │   │   └── DepthMap            # pond depth-map editor
│   │   │   ├── Clubs                   # module: clubs
│   │   │   ├── Common                  # module: admin-portal — shared view models
│   │   │   ├── DailyMissions           # module: daily-missions
│   │   │   ├── Inventory               # module: inventory-items
│   │   │   ├── Leaderboards            # module: leaderboards
│   │   │   ├── Leagues                 # module: leagues
│   │   │   │   └── Validation          # leagues validation rules
│   │   │   ├── Missions                # module: missions
│   │   │   ├── Monetization            # module: monetization + purchases + product-delivery
│   │   │   ├── Players                 # module: profile-management + account-lifecycle
│   │   │   │   └── Logs                # module: admin-audit — player action logs
│   │   │   ├── Push                    # module: push-notifications
│   │   │   ├── ReelOfFortune           # module: reel-of-fortune
│   │   │   ├── Security                # module: moderation — bans + suspensions
│   │   │   ├── Skins                   # module: skins
│   │   │   ├── Stats                   # module: analytics-events
│   │   │   │   ├── CurrencyOwnership
│   │   │   │   ├── FishCatch
│   │   │   │   ├── Ftue
│   │   │   │   ├── Leaderboards        # module: leaderboards — leaderboard stats
│   │   │   │   └── PlayersDashboard
│   │   │   ├── TargetedAdsStats        # module: ads — ad-campaign targeting stats
│   │   │   ├── Tools                   # module: admin-portal — meta/tools
│   │   │   ├── Trans                   # module: localization
│   │   │   └── UgcApprove              # module: user-generated-lifecycle — UGC content moderation
│   │   ├── Properties
│   │   │   └── PublishProfiles
│   │   ├── Scripts
│   │   │   ├── ace
│   │   │   │   └── snippets
│   │   │   ├── kendo
│   │   │   │   └── 2013.2.918
│   │   │   └── vue
│   │   │       ├── css
│   │   │       └── js
│   │   └── Views
│   │       ├── Account
│   │       ├── Clubs
│   │       ├── DailyMissions
│   │       ├── Environment
│   │       ├── Home
│   │       ├── Logs
│   │       ├── Message
│   │       ├── Player
│   │       ├── Reports
│   │       ├── Settings
│   │       ├── Shared
│   │       │   └── EditorTemplates
│   │       ├── Stats
│   │       ├── Tools
│   │       └── WeatherInfo
│   ├── WebAdmin.Tests                  # note: **minimal coverage** — 2 test classes (CrossServerHelperTest + VersionTests) ~118 LOC; only utility helpers tested; NO controller/model/integration tests
│   │   └── Helpers
│   ├── WebService                      # **ABANDONED** (user-confirmed) — tournament-results Web API ~60 LOC; CatchDataController routes `/api/catchData/catches/{dates}/+ponds/+baits/+languages/+fish`; endpoint-protection notes — see private audit; manual DateTime parsing format `yyyyMMddTHHmm`; likely used by external analytics consumers pre-deprecation
│   │   ├── App_Data
│   │   ├── App_Start
│   │   ├── Controllers
│   │   ├── Models                      # Catch + Pond + Bait + Fish + Language
│   │   └── Properties
│   │       └── PublishProfiles
│   └── WebTranslate                    # module: localization — crowdsourced translation portal ~150 LOC ASP.NET MVC 4.7; AccountController + HomeController + BaseController; TranslationEditingModels + RoleModel + StatsModel + ProgressModel + HistoryModel; SimpleMembership `[Authorize]` on HomeController; shares Web.config with main WebAdmin
│       ├── App_Data
│       ├── App_Start
│       ├── Content
│       │   ├── kendo
│       │   │   └── 2013.2.918
│       │   │       ├── Black
│       │   │       ├── BlueOpal
│       │   │       ├── Bootstrap
│       │   │       ├── Default
│       │   │       ├── Flat
│       │   │       ├── HighContrast
│       │   │       ├── images
│       │   │       ├── Metro
│       │   │       ├── MetroBlack
│       │   │       ├── Moonlight
│       │   │       ├── Silver
│       │   │       ├── textures
│       │   │       └── Uniform
│       │   └── themes
│       │       └── base
│       │           ├── images
│       │           └── minified
│       │               └── images
│       ├── Controllers
│       ├── Filters
│       ├── Helpers
│       ├── Images
│       ├── Models
│       ├── Properties
│       │   └── PublishProfiles
│       ├── Scripts
│       │   ├── ace
│       │   │   └── snippets
│       │   └── kendo
│       │       └── 2013.2.918
│       ├── Utils
│       └── Views
│           ├── Account
│           ├── Home
│           └── Shared
│               └── EditorTemplates
└── WebServices                          # module: webhooks — standalone ASP.NET Core API service receiving external events (primary: Denuvo anti-cheat); API-versioned (V1/V2); X-FP-API-Key header auth; legacy System.Data.SqlClient DAL (not EF/Dapper); MongoDB ban-logs
    └── WebHooks
        └── WebHooks
            ├── Controllers               # V1/V2 AnticheatController: GET /api/v{version}/anticheat/denuvo/label/{cheater|vac-banned}/{externalId} — platform→user resolve → label validation with ImmediateBanOn+NonPayersOnlyBan+payable-exemption → ban + disconnect-signal → Mongo DenuvoBan log
            │   ├── V1
            │   └── V2
            ├── DAL
            │   └── MongoDB
            ├── Helpers
            ├── Middleware
            ├── ObjectModel
            │   └── Denuvo
            ├── Properties
            └── Swagger
```
