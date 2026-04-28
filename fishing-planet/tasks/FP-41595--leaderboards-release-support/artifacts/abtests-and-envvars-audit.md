# AbTests & EnvironmentVariables audit — LBM ancestry

**Date:** 2026-04-27
**Scope:** all changes to rows in `AbTests` and `EnvironmentVariables` tables introduced into the LBM20251201 branch lineage since branch GRM20240409 was created (r11916).
**Why:** these two tables are not data-migrated between branches; LBM release must deliver every required row via SQL patches.

**Out of scope:**
- `GlobalVariables` and `JsonVariables` — fully replaced by QA→PROD DataPump at release (release checklist step "Transfer data updates from QA"). Their final prod state equals QA state at sync time, regardless of patch contents. Mentioned in this audit **only** where an EV→GV migration spans both tables (LBM-002: 6 `Leaderboards.*` rows — EV-side deletes are patch-driven; GV-side inserts come from QA sync).

## Starting point

GRM20240409 was branched from FTG20230906 at **r11916** (per [Confluence "Environment and branch status"](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/68616199/Environment+and+branch+status)). LBM20251201 transitively inherits via:

```
GRM20240409 (r11916) → IMV20241106 (r13159) → HFH20241126 (r13260)
  → IMV20250220 (r13733) → JLM20250520 (r14174) → KNW20250723 (r14593) → LBM20251201 (r15396)
```

Method:
1. `Grep` over `SQL/Patches/**/*.sql` for `AbTests` / `EnvironmentVariables` (case-insensitive, word boundary) — yields all DB-changing patches.
2. `svn log -r 11916:HEAD --search "ABTest"` and `--search "EnvironmentVariable"` on the LBM URL — captures code-only commits referencing these tables.
3. Variant searches `--search "env var"` / `--search "AB test"` to catch alternative wording (2 false positives caught: [FP-33065](https://fishingplanet.atlassian.net/browse/FP-33065) actually touched `GlobalVariables`, [FP-33836](https://fishingplanet.atlassian.net/browse/FP-33836) only touched `Profiles`).
4. For every patch file, `svn log -r 1:15396 "URL@15396"` walks back through copy history to locate the first non-branch-creation commit; this gives the original author, revision, and JIRA reference.

---

## A. A/B Tests (table `AbTests`)

| JIRA                                                            | Title                                                                                | TestId | Test name                                | Patch / source                                                                                                                              | Probability | DefaultValue | IsActive |
|-----------------------------------------------------------------|--------------------------------------------------------------------------------------|-------:|------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------|------------:|-------------:|---------:|
| [FP-32720](https://fishingplanet.atlassian.net/browse/FP-32720) | (Personal offers A/B Test, FTG-merge)                                                |     16 | `Personal Offers A/B Test`               | `SQL/Releases/R202407-PersonalOffersAB.sql` (release script — **not an `AppliedPatches`-tracked patch**)                                    |           0 |            0 |        0 |
| [FP-34120](https://fishingplanet.atlassian.net/browse/FP-34120) | [Leaderboards] Server - add and support Leaderboards Environment Variable            |     17 | `New Leaderboards feature is On`         | `GRM.M.2024.10.29-062` (r13118)                                                                                                             |           0 |            0 |        0 |
| [FP-35457](https://fishingplanet.atlassian.net/browse/FP-35457) | [FreeStarterPackPO] ServerDev. Create new AB test id for all platform                |     18 | `Personal Offer: Free Starter Pack`      | `GRM.M.2025.01.08-073` (r13469 → merged r13470)                                                                                             |           0 |            0 |        0 |
| [FP-38009](https://fishingplanet.atlassian.net/browse/FP-38009) | [NPS] Create AB test for new products                                                |     19 | `Personal Offer: New products for start` | `IMV.M.2025.05.27-014` (r14207 → merged r14208)                                                                                             |           0 |            0 |        0 |
| [FP-41732](https://fishingplanet.atlassian.net/browse/FP-41732) | [live ops] Server Dev. Create an A/B test for testing the premium shop on Steam      |     20 | `Hide Pond Passes from PremShop`         | `LBM.M.2026.01.21-010 [ABTests]` (r15708)                                                                                                   |           0 |            0 |        0 |
| [FP-42683](https://fishingplanet.atlassian.net/browse/FP-42683) | DAILY MISSIONS: Server - create ab test                                              |     21 | `Override Daily Missions MinLevel`       | `LBM.M.2026.03.12-034 [ABTests][DailyMissions]` (r15914) — **also sets JsonVariable `DailyMissions.GenerationSettings.AbTestMinLevel = 3`** |         0.5 |            0 |        0 |
| [FP-42053](https://fishingplanet.atlassian.net/browse/FP-42053) | FTUE. Server. ABTEST=1 - Check functionality "Skip character customization on start" |     22 | `Skip Character Customization on Start`  | `LBM.M.2026.03.23-037 [ABTests]` (r15939)                                                                                                   |         0.5 |            0 |        0 |

All tests are inserted with `IsActive=0`; further tuning (`IsActive`, `DefaultValue`, `Probability`) is product/marketing-driven post-deploy.

### A/B test runtime semantics (important for "desired prod" interpretation)

How the runtime resolves a test's outcome for a given player:

| `IsActive` | `DefaultValue` | `Probability` | Effective behavior                                                                    |
|:----------:|:--------------:|:-------------:|---------------------------------------------------------------------------------------|
|   `true`   |   (ignored)    |      `p`      | Players are split: `p` fraction → group A (feature ON), `1-p` → group B (feature OFF) |
|  `false`   |     `true`     |   (ignored)   | **All players** get feature ON (global override)                                      |
|  `false`   |    `false`     |   (ignored)   | **All players** get feature OFF                                                       |

Implications for this audit:

- **"Patch insert values"** in the tables below is the **insertion-time** value — what `INSERT INTO AbTests …` writes the first time the patch runs (`IF NOT EXISTS` → never overwrites an existing row).
- **"Prod current"** is the live row as of the last audit read. For tests already on prod, GD/LiveOps have tuned these — they are not auto-changed at LBM rollout (patches are non-destructive).
- **"Action at LBM release"** answers: do we touch this row during/after rollout?  Possible values:  *(explicit)* "set to X" (with source) | *(TBD)* "ask `<owner>`" | *(no-op)* "leave; patch INSERTs only if absent" | *(verify)* "row should appear automatically — confirm".
- A test with `IsActive=false` is **not equivalent to "off"** — it's "globally on" if `DefaultValue=true`, "globally off" if `DefaultValue=false`. To truly disable a feature gated on a test, both `IsActive=false` AND `DefaultValue=false` are required.

### Code-only commits referencing AbTests (no row INSERT/UPDATE)

| JIRA                                                            | Title                                                                 | What it touches                                                                       |
|-----------------------------------------------------------------|-----------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| [FP-32785](https://fishingplanet.atlassian.net/browse/FP-32785) | Fix Errors in WebAdmin                                                | Procedure `GetAbTestStats` fix; no data change                                        |
| [FP-35874](https://fishingplanet.atlassian.net/browse/FP-35874) | [NPS] Server dev. Improvement of the functionality of personal offers | PersonalOffers cohorts; allows binding ads to ABTest negative value — no new test row |
| [FP-40033](https://fishingplanet.atlassian.net/browse/FP-40033) | Server Caches: Review data validation approach                        | Class rename (`AbTestCache`) — code only                                              |

---

## B. EnvironmentVariables (table `EnvironmentVariables`)

| JIRA                                                                                                                              | Title                                                                                        | Patch                                                                                   | Action                            | Variable                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | Value                                                                            |
|-----------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------|-----------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------|
| [FP-31648](https://fishingplanet.atlassian.net/browse/FP-31648)                                                                   | [Server] Performance investigation for SaltWater release                                     | `GRM.M.2024.05.27-014` (r12249)                                                         | INSERT                            | `UseNewUserSearch`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | `0`                                                                              |
| [FP-32183](https://fishingplanet.atlassian.net/browse/FP-32183) / [FP-32233](https://fishingplanet.atlassian.net/browse/FP-32233) | (Bug) Console competition mail / [REFAC] Remove ToString("O")                                | `GRM.M.2024.06.26-022` (r12465)                                                         | UPDATE format                     | `Marketing.TargetedAdContextResetTime`, `AutoApproveLastSendToReviewDate`, `Async.TargetedAdStatsCollectingTime`, `Leaderboards.TournamentsUpdatedAt`, `Leaderboards.CompetitionsUpdatedAt`, `Async.LeaderboardFinalizationTime`                                                                                                                                                                                                                                                                                                       | reformatted to `yyyy/MM/dd HH:mm:ss`                                             |
| [FP-33142](https://fishingplanet.atlassian.net/browse/FP-33142)                                                                   | Three waves of Instant ban according to Denuvo reports                                       | `GRM.M.2024.09.17-049` (r13054)                                                         | DELETE                            | `DenuvoImmediateBanPeriod`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | (replaced by `Denuvo.ImmediateBanPeriod1/2/3` in `GlobalVariables`)              |
| [FP-34120](https://fishingplanet.atlassian.net/browse/FP-34120)                                                                   | [Leaderboards] Server - add and support Leaderboards Environment Variable                    | `GRM.M.2024.10.29-062` (r13118)                                                         | (also Test 17 — see section A)    | (no INSERT into EV in this patch)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | —                                                                                |
| [FP-34390](https://fishingplanet.atlassian.net/browse/FP-34390)                                                                   | [Server][Release] Prepare and release Patch 10 (Kherson)                                     | `GRM.M.2024.12.12-072` (r13382 → merged r13426)                                         | INSERT (×12)                      | `Leaderboards.IsCompetitiveLeaderboardsUpdateOn`, `…RewardsOn`, `…JobsOn`, `…UIOn`, `Leaderboards.IsGlobalLeaderboardsUpdateOn/RewardsOn/JobsOn/UIOn`, `Leaderboards.IsFishLeaderboardsUpdateOn/RewardsOn/JobsOn/UIOn`                                                                                                                                                                                                                                                                                                                 | all `'N'`                                                                        |
| [FP-34390](https://fishingplanet.atlassian.net/browse/FP-34390)                                                                   | (same)                                                                                       | `HFH.M.2025.02.05-079` (r13647)                                                         | RENAME (×12)                      | (legacy `IsCompetitiveLeaderboardsUpdateOn` etc. → `Leaderboards.…UpdateOn` for Competitive/Global/Fish)                                                                                                                                                                                                                                                                                                                                                                                                                               | —                                                                                |
| [FP-34467](https://fishingplanet.atlassian.net/browse/FP-34467)                                                                   | [Ratings] Restore TournamentRatingCalculator and put it on an env variable switch            | `GRM.M.2024.11.18-070` (r13208 → merged r13209)                                         | INSERT                            | `IsRatingByPlaceEnabled`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | `'N'`                                                                            |
| [FP-36061](https://fishingplanet.atlassian.net/browse/FP-36061)                                                                   | [Leaderboards] Server - add enum to environment variables                                    | `HFH.M.2025.02.11-082` (r13676 → merged r13765)                                         | DELETE + INSERT                   | DEL: `FishLeaderboardsAcceptedFishSources`, `Leaderboards.AcceptedFishSources`, `CompetitiveLeaderboardsQueryType`, `GlobalLeaderboardsQueryType`, `FishLeaderboardsQueryType`, `LeaderborardsQueryType` (sic). INS: `IsLeaderboardsOn`=`N`, `Leaderboards.FishLeaderboardsAcceptedFishSources`=`B,P`, `Leaderboards.CompetitiveLeaderboardsQueryType`=`Top100AndUserAndSurrounding`, `Leaderboards.GlobalLeaderboardsQueryType`=`Top100AndUserAndSurrounding`, `Leaderboards.FishLeaderboardsQueryType`=`Top100AndUserAndSurrounding` | as left                                                                          |
| [FP-36647](https://fishingplanet.atlassian.net/browse/FP-36647) / [FP-36804](https://fishingplanet.atlassian.net/browse/FP-36804) | Mobile - Remove 30day delay for Deleting Account / WebAdmin tool to find associated accounts | `IMV.M.2025.03.24-006` (r13959)                                                         | INSERT                            | `AccountDeletionImmediateUnbindPlatforms`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | `Apple,Android`                                                                  |
| [FP-38665](https://fishingplanet.atlassian.net/browse/FP-38665)                                                                   | [Connectivity] Implement TPM broadcasting pause for high RTT threshold                       | `JLM.M.2025.06.26-004` (r14458)                                                         | INSERT (×2)                       | `Ping.DisableTpmPingThresholdMs`, `Ping.DisableTpmTriggerDelayMs`                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | `0`, `3000`                                                                      |
| [FP-38665](https://fishingplanet.atlassian.net/browse/FP-38665)                                                                   | (same)                                                                                       | `JLM.M.2025.06.28-005` (r14462)                                                         | INSERT (×2)                       | `Ping.DisconnectClientPingThresholdMs`, `Ping.DisconnectClientTriggerDelayMs`                                                                                                                                                                                                                                                                                                                                                                                                                                                          | `0`, `5000`                                                                      |
| [FP-38716](https://fishingplanet.atlassian.net/browse/FP-38716)                                                                   | [Leaderboards] Change constants (PlacesBefore, PlacesAfter)                                  | `JLM.M.2025.07.02-007` (r14472)                                                         | INSERT (×2)                       | `LeaderboardsSurroundingPlacesBefore`, `LeaderboardsSurroundingPlacesAfter`                                                                                                                                                                                                                                                                                                                                                                                                                                                            | `3`, `3`                                                                         |
| [FP-38663](https://fishingplanet.atlassian.net/browse/FP-38663)                                                                   | [Connectivity] Client - global env-based connection thread priority control                  | `JLM.M.2025.08.04-017` (r14638 → merged r14650)                                         | INSERT (×2)                       | `Connectivity.IsNetworkThreadEnabled`, `Connectivity.NetworkThreadPriority`                                                                                                                                                                                                                                                                                                                                                                                                                                                            | `'N'`, `AboveNormal`                                                             |
| [FP-39058](https://fishingplanet.atlassian.net/browse/FP-39058)                                                                   | Stats on Big Fish in Maldives — failed-to-land cases                                         | `KNW.M.2025.08.07-007` (r14655)                                                         | INSERT (×2)                       | `FishStats.CollectFishGenerationStats`, `FishStats.FishGenerationStatsCleanupHorizonDays`                                                                                                                                                                                                                                                                                                                                                                                                                                              | `1`, `90`                                                                        |
| [FP-39703](https://fishingplanet.atlassian.net/browse/FP-39703)                                                                   | DAILY MISSIONS: Server - Daily missions functionality polishing                              | `KNW.M.2025.09.11-044` (r14956)                                                         | INSERT                            | `IsDailyMissionsOn`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | `'N'` (feature flag)                                                             |
| [FP-41294](https://fishingplanet.atlassian.net/browse/FP-41294)                                                                   | [WebAdmin] [Stats] Additional parameters in statistics for FTUE analysis                     | `LBM.M.2025.12.12-001 [EnvironmentVariables]` (r15535)                                  | INSERT                            | `DetailedAnalyticsLoggingMaxLevel`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | `10`                                                                             |
| [FP-38716](https://fishingplanet.atlassian.net/browse/FP-38716)                                                                   | (re-application: migration into GlobalVariables)                                             | `LBM.M.2025.12.17-002 [EnvironmentVariables] [GlobalVariables] [Leaderboards]` (r15559) | MOVE → `GlobalVariables` + DELETE | `Leaderboards.FishLeaderboardsAcceptedFishSources`, `Leaderboards.CompetitiveLeaderboardsQueryType`, `Leaderboards.GlobalLeaderboardsQueryType`, `Leaderboards.FishLeaderboardsQueryType`, `LeaderboardsSurroundingPlacesBefore` → `Leaderboards.LeaderboardsSurroundingPlacesBefore`, `LeaderboardsSurroundingPlacesAfter` → `Leaderboards.LeaderboardsSurroundingPlacesAfter`                                                                                                                                                        | moves into `GlobalVariables` (last two also renamed with `Leaderboards.` prefix) |
| [FP-41417](https://fishingplanet.atlassian.net/browse/FP-41417)                                                                   | [Steam] [Products] tracking product delivery state                                           | `LBM.M.2026.03.16-036 [TransactionDeliveryItems]` (r15924)                              | INSERT                            | `UseTrackedDelivery`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | `'false'`                                                                        |

### Code-only commits referencing EnvironmentVariables (no row change)

| JIRA                                                            | Title                                                                | What it touches                                                                                                                                       |
|-----------------------------------------------------------------|----------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| [FP-31331](https://fishingplanet.atlassian.net/browse/FP-31331) | [Salt-water] FPS drops on long pond sessions                         | Changes default of `IsUnloadUnusedAssetsOn` in code; merged from FTG (r12037 → r12120 on GRM). DB row created earlier on FTG; verify presence on prod |
| [FP-28317](https://fishingplanet.atlassian.net/browse/FP-28317) | WebAdmin improvements: show UTC time in logs, jump over environments | Adds `RefreshServerCaches` button from GlobalVariables/EnvironmentVariables view — UI only                                                            |
| [FP-39221](https://fishingplanet.atlassian.net/browse/FP-39221) | DAILY MISSIONS: Server - Configuration in database                   | Makes `Name` column readonly on edit — UI only                                                                                                        |
| [FP-40033](https://fishingplanet.atlassian.net/browse/FP-40033) | Server Caches: Review data validation approach                       | Renames `EnvironmentVariableCache`/`GlobalVariablesCache`/`JsonVariablesCache` — code only                                                            |

---

## LBM-specific delta (Steam/PS/Xbox migration path)

For Steam/PS/Xbox prod streams currently on KNW-level (Stable Release 1123.x), the LBM rollout brings only the `LBM.*` patches:

- **AbTest 20** `Hide Pond Passes from PremShop` (`LBM.M.2026.01.21-010`)
- **AbTest 21** `Override Daily Missions MinLevel` + JsonVariable `DailyMissions.GenerationSettings.AbTestMinLevel = 3` (`LBM.M.2026.03.12-034`)
- **AbTest 22** `Skip Character Customization on Start` (`LBM.M.2026.03.23-037`)
- EV `DetailedAnalyticsLoggingMaxLevel = 10` (`LBM.M.2025.12.12-001`)
- EV `UseTrackedDelivery = false` (`LBM.M.2026.03.16-036`)
- Move 6 `Leaderboards.*` variables from `EnvironmentVariables` to `GlobalVariables` (`LBM.M.2025.12.17-002`)

For MOB/NX prod streams on the Maldives/IMV20250220-level (1122.x), the LBM rollout additionally brings every `JLM.*` and `KNW.*` patch listed above (the JLM/KNW range was never released to mobile/Switch prod separately).

All inserts use disabled defaults (`IsActive=0` / `Probability=0` / `'N'` / `false`); switching them on is a manual post-deploy operation per stream.

---

## Per-feature breakdown (LBM-release focus: LB / MM / Rating / DM)

This section consolidates everything per feature and is the source for the rollout checklist. Statuses in tables:

- **Patch default** — value the SQL migration inserts on apply
- **Desired prod** — value required at LBM release per GDD/release checklist
- **Action** — `auto` (migration sets the right value), `flip` (manual switch needed post-deploy), `verify` (no value change, but check existence/location)

Cache mechanics relevant to all rows: `Shared/SharedLib/Config/EnvironmentVariableCache.cs:79-87` `RemovePrefix` strips the first dot-separated segment when loading; so `Leaderboards.X` in DB and bare `X` in DB resolve to the same code-side key.

Sources:
- [**Leaderboards GDD - 1st iteration**](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/4532731906/Leaderboards+GDD+-+1st+iteration) — Variables section
- [**MatchMaking System - 1st Iteration GDD**](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/4067721271/MatchMaking+System+-+1st+Iteration+GDD) — Environment Variables section
- [**New competition rating system GDD - 1st iteration**](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/4104945682/New+competition+rating+system+GDD+-+1st+iteration) — Environment Variables section
- [**Daily Missions: GDD 2.0**](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/5351309314/Daily+Missions+GDD+2.0) — JSON value confirmation; no explicit EV directive (`IsDailyMissionsOn` flip is inferred from "feature ships")
- [**2026.3 - Leaderboards/Matchmaking/DailyMissions Server Release checklist**](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/5403607042/2026.3+-+Leaderboards+Matchmaking+DailyMissions+Server+Release+checklist) — explicit step "Environment Variables and AB Tests"

---

### Leaderboards (LB)

#### EnvironmentVariables (still in `EnvironmentVariables` table)

|  # | Variable (DB form)                                | Patch                                                                                                                       | Patch insert | Prod (2026-04-27) | QA (2026-04-27) | Action at LBM release                                                                       |
|---:|---------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|:------------:|:-----------------:|:---------------:|---------------------------------------------------------------------------------------------|
|  1 | `IsLeaderboardsOn`                                | `HFH.M.2025.02.11-082` ([FP-36061](https://fishingplanet.atlassian.net/browse/FP-36061))                                    |     `N`      |        `N`        |       `Y`       | **Set `Y`** (Leaderboards GDD § Variables; QA already at `Y`)                               |
|  2 | `Leaderboards.IsCompetitiveLeaderboardsUpdateOn`  | `GRM.M.2024.12.12-072` ([FP-34390](https://fishingplanet.atlassian.net/browse/FP-34390)); renamed by `HFH.M.2025.02.05-079` |     `N`      |        `N`        |       `Y`       | **Set `Y`**                                                                                 |
|  3 | `Leaderboards.IsCompetitiveLeaderboardsRewardsOn` | same                                                                                                                        |     `N`      |        `N`        |       `Y`       | **Set `Y`**                                                                                 |
|  4 | `Leaderboards.IsCompetitiveLeaderboardsJobsOn`    | same                                                                                                                        |     `N`      |        `N`        |       `Y`       | **Set `Y`**                                                                                 |
|  5 | `Leaderboards.IsCompetitiveLeaderboardsUIOn`      | same                                                                                                                        |     `N`      |        `N`        |       `Y`       | **Set `Y`**                                                                                 |
|  6 | `Leaderboards.IsGlobalLeaderboardsUpdateOn`       | same                                                                                                                        |     `N`      |        `N`        |       `Y`       | **Set `Y`**                                                                                 |
|  7 | `Leaderboards.IsGlobalLeaderboardsRewardsOn`      | same                                                                                                                        |     `N`      |        `N`        |       `Y`       | **Set `Y`**                                                                                 |
|  8 | `Leaderboards.IsGlobalLeaderboardsJobsOn`         | same                                                                                                                        |     `N`      |        `N`        |       `Y`       | **Set `Y`**                                                                                 |
|  9 | `Leaderboards.IsGlobalLeaderboardsUIOn`           | same                                                                                                                        |     `N`      |        `N`        |       `Y`       | **Set `Y`**                                                                                 |
| 10 | `Leaderboards.IsFishLeaderboardsUpdateOn`         | same                                                                                                                        |     `N`      |        `N`        |       `Y`       | **Set `Y`**                                                                                 |
| 11 | `Leaderboards.IsFishLeaderboardsRewardsOn`        | same                                                                                                                        |     `N`      |        `N`        |       `Y`       | **Set `Y`**                                                                                 |
| 12 | `Leaderboards.IsFishLeaderboardsJobsOn`           | same                                                                                                                        |     `N`      |        `N`        |       `Y`       | **Set `Y`**                                                                                 |
| 13 | `Leaderboards.IsFishLeaderboardsUIOn`             | same                                                                                                                        |     `N`      |        `N`        |       `Y`       | **Set `Y`**                                                                                 |

GDD inconsistency note: Leaderboards GDD lists `Leaderboards.IsLeaderboardsOn` (with prefix) in the table at lines 838-854 but `IsLeaderboardsOn` (no prefix) in the bullet description at line 856. The actual SQL patch inserts the bare form. Both spellings resolve identically due to `RemovePrefix`.

#### Variables migrated to `GlobalVariables` (by `LBM.M.2025.12.17-002`, [FP-38716](https://fishingplanet.atlassian.net/browse/FP-38716))

These were originally inserted as EVs and were moved to `GlobalVariables` during the LBM cycle. Patch preserves the existing values on move; the GDD's "EnvironmentVariables" section is technically out-of-date for these (but values still match).

|  # | Variable (DB form, after migration)                | Origin patch                                                                                                       |   Patch insert (move-time)    |               Prod (2026-04-27)                |                        QA (2026-04-27)                        | Action at LBM release                                                                                     |
|---:|----------------------------------------------------|--------------------------------------------------------------------------------------------------------------------|:-----------------------------:|:----------------------------------------------:|:-------------------------------------------------------------:|-----------------------------------------------------------------------------------------------------------|
| 14 | `Leaderboards.FishLeaderboardsAcceptedFishSources` | `HFH.M.2025.02.11-082` ([FP-36061](https://fishingplanet.atlassian.net/browse/FP-36061)), moved by LBM-002         |             `B,P`             |      in EV: `B,P` (move not yet applied)       |                        in GV: `B,P` ✓                         | **Verify** in `GlobalVariables=B,P` after QA→PROD GV sync; absent in `EnvironmentVariables` after LBM-002 |
| 15 | `Leaderboards.CompetitiveLeaderboardsQueryType`    | same → moved                                                                                                       | `Top100AndUserAndSurrounding` |      in EV: `Top100AndUserAndSurrounding`      |            in GV: `Top100AndUserAndSurrounding` ✓             | **Verify** in GV; absent in EV                                                                            |
| 16 | `Leaderboards.GlobalLeaderboardsQueryType`         | same → moved                                                                                                       | `Top100AndUserAndSurrounding` |      in EV: `Top100AndUserAndSurrounding`      |            in GV: `Top100AndUserAndSurrounding` ✓             | **Verify** in GV; absent in EV                                                                            |
| 17 | `Leaderboards.FishLeaderboardsQueryType`           | same → moved                                                                                                       | `Top100AndUserAndSurrounding` |      in EV: `Top100AndUserAndSurrounding`      |            in GV: `Top100AndUserAndSurrounding` ✓             | **Verify** in GV; absent in EV                                                                            |
| 18 | `Leaderboards.LeaderboardsSurroundingPlacesBefore` | `JLM.M.2025.07.02-007` ([FP-38716](https://fishingplanet.atlassian.net/browse/FP-38716)), renamed+moved by LBM-002 |              `3`              | in EV: `LeaderboardsSurroundingPlacesBefore=3` | in GV: `Leaderboards.LeaderboardsSurroundingPlacesBefore=3` ✓ | **Verify** renamed+moved to GV after LBM-002; absent in EV                                                |
| 19 | `Leaderboards.LeaderboardsSurroundingPlacesAfter`  | same → renamed+moved                                                                                               |              `3`              | in EV: `LeaderboardsSurroundingPlacesAfter=3`  | in GV: `Leaderboards.LeaderboardsSurroundingPlacesAfter=3` ✓  | **Verify** renamed+moved to GV after LBM-002; absent in EV                                                |

> QA snapshot 2026-04-27 confirms LBM-002 migration ran cleanly: all 6 rows present in `GlobalVariables` with expected values and absent in `EnvironmentVariables`. QA→PROD GV sync at rollout will deliver these to prod.

#### A/B Tests

| TestId | Name                             | Patch                                                                                    | Patch insert values                             | Prod (2026-04-27)                               | QA (2026-04-27)                                 | Action at LBM release                                                                                                   |
|-------:|----------------------------------|------------------------------------------------------------------------------------------|-------------------------------------------------|-------------------------------------------------|-------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|
|     17 | `New Leaderboards feature is On` | `GRM.M.2024.10.29-062` ([FP-34120](https://fishingplanet.atlassian.net/browse/FP-34120)) | `IsActive=0`, `Probability=0`, `DefaultValue=0` | `IsActive=0`, `Probability=0`, `DefaultValue=0` | `IsActive=0`, `Probability=0`, `DefaultValue=0` | **Leave** (legacy switch — superseded by EV `IsLeaderboardsOn`; QA also leaves test inactive, confirming legacy status) |

---

### Matchmaking (MM)

#### EnvironmentVariables

| # | Variable                 | Patch                                                                                    | Patch insert | Prod (2026-04-27) | QA (2026-04-27) | Action at LBM release                                                                  |
|--:|--------------------------|------------------------------------------------------------------------------------------|:------------:|:-----------------:|:---------------:|----------------------------------------------------------------------------------------|
| 1 | `IsRatingByPlaceEnabled` | `GRM.M.2024.11.18-070` ([FP-34467](https://fishingplanet.atlassian.net/browse/FP-34467)) |     `N`      |        `N`        |       `Y`       | **Set `Y`** (release checklist + MM/Rating GDD; QA at `Y`. Shared flag for MM+Rating)  |

#### A/B Tests

None.

#### Notes

- Tier coefficients, group definitions (`Grouping`, `MinSize`, `MaxGroupCount`, `Groups[]`), bracket boundaries — all in competition JSON, not in `EnvironmentVariables`. Out of scope for this audit.
- GDD also mentions `GlobalVariable` `Tournaments.ParticipantGridMode = AA` — that's `GlobalVariables`, not `EnvironmentVariables`. Out of scope for this audit.

---

### Rating

#### EnvironmentVariables

| # | Variable                 | Patch                                                                                    | Patch insert | Prod (2026-04-27) | QA (2026-04-27) | Action at LBM release                                                       |
|--:|--------------------------|------------------------------------------------------------------------------------------|:------------:|:-----------------:|:---------------:|-----------------------------------------------------------------------------|
| 1 | `IsRatingByPlaceEnabled` | `GRM.M.2024.11.18-070` ([FP-34467](https://fishingplanet.atlassian.net/browse/FP-34467)) |     `N`      |        `N`        |       `Y`       | **Set `Y`** (same flag as Matchmaking; one flip activates both subsystems)  |

#### A/B Tests

None.

#### Notes

- Tier 1..6 rating points table from GDD lives in competition JSON, not in EVs.
- `ZeroScoreRatingPenalty` and `NoShowRatingPenalty` — also competition JSON.

---

### Daily Missions (DM)

#### EnvironmentVariables

| # | Variable            | Patch                                                                                    | Patch insert | Prod (2026-04-27) | QA (2026-04-27) | Action at LBM release                                                                                                                                  |
|--:|---------------------|------------------------------------------------------------------------------------------|:------------:|:-----------------:|:---------------:|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1 | `IsDailyMissionsOn` | `KNW.M.2025.09.11-044` ([FP-39703](https://fishingplanet.atlassian.net/browse/FP-39703)) |     `N`      |        `N`        |       `Y`       | **Set `Y`** (QA at `Y` — strong signal DM ships with LBM. Confirm with DM team that this is final intent and not just QA-test setup)                   |

#### A/B Tests

| TestId | Name                               | Patch                                                                                    | Patch insert values                               | Prod (2026-04-27)                  | QA (2026-04-27)                                   | Action at LBM release                                                                                                                                                                                                |
|-------:|------------------------------------|------------------------------------------------------------------------------------------|---------------------------------------------------|------------------------------------|---------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     21 | `Override Daily Missions MinLevel` | `LBM.M.2026.03.12-034` ([FP-42683](https://fishingplanet.atlassian.net/browse/FP-42683)) | `IsActive=0`, `Probability=0.5`, `DefaultValue=0` | (absent — LBM-034 not yet on prod) | `IsActive=0`, `Probability=0.5`, `DefaultValue=0` | LBM patch will INSERT with patch values (QA matches; QA didn't activate even though `IsDailyMissionsOn=Y`). **TBD — confirm with DM/LiveOps**: activate at release or leave inactive (QA signal: leave inactive)?    |

#### JsonVariables (related, not in EV/ABT scope but part of DM rollout)

| Path                                                  | Patch                                                                                    | Patch insert |        Prod (2026-04-27)         |    QA (2026-04-27)     | Action at LBM release                                     |
|-------------------------------------------------------|------------------------------------------------------------------------------------------|:------------:|:--------------------------------:|:----------------------:|-----------------------------------------------------------|
| `DailyMissions.GenerationSettings` → `AbTestMinLevel` | `LBM.M.2026.03.12-034` ([FP-42683](https://fishingplanet.atlassian.net/browse/FP-42683)) |     `3`      | not yet applied (LBM-034 absent) | not yet verified (TBD) | LBM patch UPDATEs JsonVariable to `3`; matches DM GDD 2.0 |

DM GDD 2.0 references many other `JsonVariables` rows (`DailyMissions.GenerationSettings`, `DailyMissions.TrollingPondIds`, `DailyMissions.CatchFishTasks.*` etc.). Those are populated by the dedicated DM patch series `KNW.M.2025.08.13-010..023` and are outside the EV/ABT audit scope.

---

## Other features — grouped by meaning

Items below appear in chronological tables A and B but are **not** part of LB/MM/Rating/DM. Grouped by feature/concern. Same column convention as the per-feature breakdown: `Patch insert | Prod current | Action at LBM release`. **TBD** = needs owner/JIRA confirmation (collected in backlog).

`Code-only commits` (no DB row change) for these features remain in sections A and B above.

---

### Connectivity / Network quality

Server-side ping thresholds for "transparent player movement" (TPM) broadcast suppression and client-disconnect, plus client-side network-thread tuning.

#### EnvironmentVariables

| # | Variable                               | Patch                                                                                    | Patch insert  | Prod (2026-04-27) | QA (2026-04-27) | Action at LBM release                                                                                                |
|--:|----------------------------------------|------------------------------------------------------------------------------------------|:-------------:|:-----------------:|:---------------:|----------------------------------------------------------------------------------------------------------------------|
| 1 | `Ping.DisableTpmPingThresholdMs`       | `JLM.M.2025.06.26-004` ([FP-38665](https://fishingplanet.atlassian.net/browse/FP-38665)) |      `0`      |        `0`        |       `0`       | **TBD — ask FP-38665 owner** (Dmytro K). QA at patch default → suggests **leave at `0`** unless owner says otherwise |
| 2 | `Ping.DisableTpmTriggerDelayMs`        | `JLM.M.2025.06.26-004` ([FP-38665](https://fishingplanet.atlassian.net/browse/FP-38665)) |    `3000`     |      `3000`       |     `3000`      | **TBD — ask FP-38665 owner**. QA at default → suggests leave; only relevant when #1 > 0                              |
| 3 | `Ping.DisconnectClientPingThresholdMs` | `JLM.M.2025.06.28-005` ([FP-38665](https://fishingplanet.atlassian.net/browse/FP-38665)) |      `0`      |        `0`        |       `0`       | **TBD — ask FP-38665 owner**. QA at default → suggests leave                                                         |
| 4 | `Ping.DisconnectClientTriggerDelayMs`  | `JLM.M.2025.06.28-005` ([FP-38665](https://fishingplanet.atlassian.net/browse/FP-38665)) |    `5000`     |      `5000`       |     `5000`      | **TBD — ask FP-38665 owner**. QA at default → suggests leave; only relevant when #3 > 0                              |
| 5 | `Connectivity.IsNetworkThreadEnabled`  | `JLM.M.2025.08.04-017` ([FP-38663](https://fishingplanet.atlassian.net/browse/FP-38663)) |     `'N'`     |       `'N'`       |      `'N'`      | **TBD — ask FP-38663 owner**. QA at `'N'` → suggests **leave inactive** at LBM rollout                               |
| 6 | `Connectivity.NetworkThreadPriority`   | `JLM.M.2025.08.04-017` ([FP-38663](https://fishingplanet.atlassian.net/browse/FP-38663)) | `AboveNormal` |   `AboveNormal`   |  `AboveNormal`  | **TBD — ask FP-38663 owner**. QA at default → suggests leave; only effective when #5 is `Y`                          |

#### A/B Tests

None.

---

### Stats / Analytics collection

Backend collection of gameplay statistics — fish generation stats and FTUE-tier analytics depth.

#### EnvironmentVariables

| # | Variable                                          | Patch                                                                                    | Patch insert | Prod (2026-04-27)        | QA (2026-04-27) | Action at LBM release                                                                                                                  |
|--:|---------------------------------------------------|------------------------------------------------------------------------------------------|:------------:|:------------------------:|:---------------:|----------------------------------------------------------------------------------------------------------------------------------------|
| 1 | `FishStats.CollectFishGenerationStats`            | `KNW.M.2025.08.07-007` ([FP-39058](https://fishingplanet.atlassian.net/browse/FP-39058)) |     `1`      | `'Y'` (semantically `1`) |       `1`       | **Leave** — `GetBoolValue` accepts `1`/`Y` interchangeably; analytics on per FP-39058 intent (QA matches patch default)                |
| 2 | `FishStats.FishGenerationStatsCleanupHorizonDays` | `KNW.M.2025.08.07-007` ([FP-39058](https://fishingplanet.atlassian.net/browse/FP-39058)) |     `90`     |           `90`           |      `90`       | **Leave `90`** — retention window matches patch intent (QA matches)                                                                    |
| 3 | `DetailedAnalyticsLoggingMaxLevel`                | `LBM.M.2025.12.12-001` ([FP-41294](https://fishingplanet.atlassian.net/browse/FP-41294)) |     `10`     |           `10`           |      `10`       | **TBD — ask FP-41294 owner** (Yuriy B). QA at default → suggests leave at `10`; confirm if cap should change at LBM rollout            |

#### A/B Tests

None.

---

### Account / Identity

Server-side username search optimization and platform-specific account-deletion behavior.

#### EnvironmentVariables

| # | Variable                                  | Patch                                                                                                                                                      |  Patch insert   | Prod (2026-04-27) | QA (2026-04-27) | Action at LBM release                                                                                                                                       |
|--:|-------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|:---------------:|:-----------------:|:---------------:|-------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1 | `UseNewUserSearch`                        | `GRM.M.2024.05.27-014` ([FP-31648](https://fishingplanet.atlassian.net/browse/FP-31648))                                                                   |       `0`       |        `1`        |       `0`       | **Leave `1` on prod** — confirmed intentional Saltwater activation. **Note:** QA at `0` (not synced from prod). If parity desired, set QA to `1` separately |
| 2 | `AccountDeletionImmediateUnbindPlatforms` | `IMV.M.2025.03.24-006` ([FP-36647](https://fishingplanet.atlassian.net/browse/FP-36647) / [FP-36804](https://fishingplanet.atlassian.net/browse/FP-36804)) | `Apple,Android` |  `Apple,Android`  | `Apple,Android` | **TBD — ask Mobile team / FP-36647 owner**. QA at default; confirm if any platforms should be added/removed (e.g. Steam, Epic) at LBM rollout               |

#### A/B Tests

None.

---

### Anti-cheat / Bans

Denuvo ban-period management. Single change in scope is a deletion (the variable was migrated to `GlobalVariables` as three separate keys).

#### EnvironmentVariables

| # | Variable                   | Patch                                                                                    | Patch action |   Prod current (2026-04-27)    | Action at LBM release                                                                                                                                   |
|--:|----------------------------|------------------------------------------------------------------------------------------|--------------|:------------------------------:|---------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1 | `DenuvoImmediateBanPeriod` | `GRM.M.2024.09.17-049` ([FP-33142](https://fishingplanet.atlassian.net/browse/FP-33142)) | DELETE       | absent (deletion already done) | **No action** — row already deleted on prod (KNW already includes GRM-049). Replacement rows `Denuvo.ImmediateBanPeriod1/2/3` live in `GlobalVariables` |

#### A/B Tests

None.

---

### Product delivery (tracking)

Per-component product delivery tracking with retry — feature flag.

#### EnvironmentVariables

| # | Variable             | Patch                                                                                    | Patch insert | Prod (2026-04-27)                  | QA (2026-04-27) | Action at LBM release                                                                                                                                                                                  |
|--:|----------------------|------------------------------------------------------------------------------------------|:------------:|:----------------------------------:|:---------------:|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1 | `UseTrackedDelivery` | `LBM.M.2026.03.16-036` ([FP-41417](https://fishingplanet.atlassian.net/browse/FP-41417)) |  `'false'`   | (absent — LBM-036 not yet on prod) |    `'false'`    | LBM patch will INSERT `'false'` (QA confirms patch insert). **TBD — ask FP-41417 owner** (Yuriy B). QA at default → suggests **leave inactive** at LBM rollout. Pairs with `TransactionDeliveryItems`  |

#### A/B Tests

None.

---

### Personal Offers / live-ops monetization (A/B tests)

A/B tests around premium-shop offers, starter packs, and product visibility for promotional segmentation. All inserted with disabled defaults; current values are configured by GD/LiveOps post-deploy. Patches use `IF NOT EXISTS` and never overwrite — current rows are preserved through migrations automatically.

#### EnvironmentVariables

None directly.

#### A/B Tests

| TestId | Name                                     | Patch                                                                                                                                                                                | Patch insert values                             | Prod (2026-04-27)                                     | QA (2026-04-27)                                       | Effective behavior on prod                     | Action at LBM release                                                                                                                                       |
|-------:|------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------|-------------------------------------------------------|-------------------------------------------------------|------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     16 | `Personal Offers A/B Test`               | `SQL/Releases/R202407-PersonalOffersAB.sql` ([FP-32720](https://fishingplanet.atlassian.net/browse/FP-32720), FTG-merge — **release script, not an `AppliedPatches`-tracked patch**) | `IsActive=0`, `Probability=0`, `DefaultValue=0` | `IsActive=0`, `Probability=0.5`, `DefaultValue=true`  | `IsActive=0`, `Probability=0.5`, `DefaultValue=true`  | feature **ON for all** (DefaultValue override) | **TBD — confirm with GD/LiveOps**. Prod = QA (matched). Default: leave as-is. Patch never overwrites                                                        |
|     18 | `Personal Offer: Free Starter Pack`      | `GRM.M.2025.01.08-073` ([FP-35457](https://fishingplanet.atlassian.net/browse/FP-35457))                                                                                             | `IsActive=0`, `Probability=0`, `DefaultValue=0` | `IsActive=0`, `Probability=0`, `DefaultValue=false`   | `IsActive=0`, `Probability=0.5`, `DefaultValue=false` | feature **OFF for all**                        | **TBD — confirm with GD/LiveOps**. **QA≠PROD on `Probability`** (QA=0.5, PROD=0). Functionally same since `IsActive=false`, but worth aligning              |
|     19 | `Personal Offer: New products for start` | `IMV.M.2025.05.27-014` ([FP-38009](https://fishingplanet.atlassian.net/browse/FP-38009))                                                                                             | `IsActive=0`, `Probability=0`, `DefaultValue=0` | `IsActive=0`, `Probability=0.5`, `DefaultValue=true`  | `IsActive=0`, `Probability=0.5`, `DefaultValue=true`  | feature **ON for all**                         | **TBD — confirm with GD/LiveOps**. Prod = QA. Default: leave as-is                                                                                          |
|     20 | `Hide Pond Passes from PremShop`         | `LBM.M.2026.01.21-010` ([FP-41732](https://fishingplanet.atlassian.net/browse/FP-41732))                                                                                             | `IsActive=0`, `Probability=0`, `DefaultValue=0` | `IsActive=0`, `Probability=0.5`, `DefaultValue=false` | `IsActive=0`, `Probability=0.5`, `DefaultValue=false` | feature **OFF for all**                        | **TBD — confirm with GD/LiveOps**. Prod = QA (LBM-010 cherry-picked). Default: leave as-is                                                                  |

---

### FTUE (First Time User Experience)

Server-side FTUE-related A/B test. (Note: `DetailedAnalyticsLoggingMaxLevel` is also FTUE-driven but lives under "Stats / Analytics" above since it's a logging cap.)

#### EnvironmentVariables

None.

#### A/B Tests

| TestId | Name                                    | Patch                                                                                    | Patch insert values                               | Prod (2026-04-27)                  | QA (2026-04-27)                                   | Action at LBM release                                                                                                                                                  |
|-------:|-----------------------------------------|------------------------------------------------------------------------------------------|---------------------------------------------------|------------------------------------|---------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     22 | `Skip Character Customization on Start` | `LBM.M.2026.03.23-037` ([FP-42053](https://fishingplanet.atlassian.net/browse/FP-42053)) | `IsActive=0`, `Probability=0.5`, `DefaultValue=0` | (absent — LBM-037 not yet on prod) | `IsActive=0`, `Probability=0.5`, `DefaultValue=0` | LBM patch will INSERT with patch values (QA matches; QA didn't activate). **TBD — confirm with FTUE team / FP-42053 owner** (QA signal: leave inactive at release)     |

---

### One-time data cleanup (UPDATE-only patches, no new rows)

Past data-format migrations applied during the LBM ancestry. Listed for completeness; nothing to verify on prod beyond "patch was applied" (tracked by `AppliedPatches`).

| Patch                  | Tickets                                                                                                                          | What it did                                                                                                                                                                                                                                                                            |
|------------------------|----------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `GRM.M.2024.06.26-022` | [FP-32183](https://fishingplanet.atlassian.net/browse/FP-32183), [FP-32233](https://fishingplanet.atlassian.net/browse/FP-32233) | Reformatted 6 datetime EVs (`Marketing.TargetedAdContextResetTime`, `AutoApproveLastSendToReviewDate`, `Async.TargetedAdStatsCollectingTime`, `Leaderboards.TournamentsUpdatedAt`, `Leaderboards.CompetitionsUpdatedAt`, `Async.LeaderboardFinalizationTime`) to `yyyy/MM/dd HH:mm:ss` |

---

## Rollout checklist (consolidated)

Every EV/A/B test row touched in the LBM ancestry, classified by required action at LBM rollout. Use this as the basis for the operational checklist on the release page.

### Group 1 — Explicit actions (known, with QA evidence)

|    # | Item                                                                                                              | Action                                          | Source / evidence                                                            |
|-----:|-------------------------------------------------------------------------------------------------------------------|-------------------------------------------------|------------------------------------------------------------------------------|
|    1 | EV `IsLeaderboardsOn`                                                                                             | Set `Y`                                         | Leaderboards GDD § Variables; QA at `Y` ✓                                    |
| 2-13 | EV 12× `Leaderboards.Is{Competitive\|Global\|Fish}Leaderboards{Update\|Rewards\|Jobs\|UI}On`                      | Set `Y` each                                    | Leaderboards GDD § Variables; QA at `Y` ✓                                    |
|   14 | EV `IsRatingByPlaceEnabled`                                                                                       | Set `Y` (activates MM and Rating)               | Release checklist + MM/Rating GDD § Environment Vars; QA at `Y` ✓            |
|   15 | EV `IsDailyMissionsOn`                                                                                            | Set `Y` (DM ships with LBM)                     | QA at `Y` (strong signal); confirm with DM team that this is final intent    |

### Group 2 — TBD (still need owner confirmation; QA evidence noted)

|  # | Item                                                                            | Owner / source            | Question                                                                                          | QA evidence                                                            |
|---:|---------------------------------------------------------------------------------|---------------------------|---------------------------------------------------------------------------------------------------|------------------------------------------------------------------------|
|  1 | EV `Ping.DisableTpmPingThresholdMs`, `…TriggerDelayMs`                          | FP-38665 owner (Dmytro K) | Activation plan + tuned threshold values?                                                         | QA at patch defaults (`0`/`3000`) — suggests **leave inactive**         |
|  2 | EV `Ping.DisconnectClientPingThresholdMs`, `…TriggerDelayMs`                    | FP-38665 owner (Dmytro K) | Activation plan + tuned threshold values?                                                         | QA at patch defaults (`0`/`5000`) — suggests **leave inactive**         |
|  3 | EV `Connectivity.IsNetworkThreadEnabled` + `Connectivity.NetworkThreadPriority` | FP-38663 owner            | Activation plan? Priority change?                                                                 | QA at patch defaults (`'N'`/`AboveNormal`) — suggests **leave inactive** |
|  4 | EV `DetailedAnalyticsLoggingMaxLevel`                                           | FP-41294 owner (Yuriy B)  | Cap unchanged at `10` for LBM rollout?                                                            | QA at `10` — suggests **leave**                                         |
|  5 | EV `AccountDeletionImmediateUnbindPlatforms`                                    | Mobile / FP-36647 owner   | Add/remove platforms from `Apple,Android` at rollout?                                             | QA at default `Apple,Android` — suggests **leave**                      |
|  6 | EV `UseTrackedDelivery`                                                         | FP-41417 owner (Yuriy B)  | Activate at rollout (set `'true'`) or later?                                                      | QA at `'false'` — suggests **leave inactive**                           |
|  7 | A/B Test 21 `Override Daily Missions MinLevel`                                  | DM / LiveOps (FP-42683)   | Activate (`IsActive=1`), set `DefaultValue=true`, or leave inactive?                              | QA inactive (feature OFF for all) — suggests **leave inactive**         |
|  8 | A/B Test 22 `Skip Character Customization on Start`                             | FTUE / FP-42053 owner     | Activation policy at rollout?                                                                     | QA inactive (feature OFF for all) — suggests **leave inactive**         |
|  9 | A/B Tests 16, 18, 19, 20 (Personal Offers / live-ops)                           | GD/LiveOps                | Confirm current prod values are intended at LBM rollout (note: Test 18 `Probability` differs QA=0.5 vs PROD=0; align?) | QA matches PROD for tests 16, 19, 20; differs for 18 on `Probability`  |

### Group 3 — Leave / verify only (no flip needed)

|  # | Item                                                                                  | Action                                                                                                                          |
|---:|---------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------|
|  1 | A/B Test 17 `New Leaderboards feature is On`                                          | Leave inactive (legacy, superseded by EV `IsLeaderboardsOn`; QA also leaves inactive ✓)                                        |
|  2 | EV `UseNewUserSearch`                                                                 | Leave `1` on prod (intentional Saltwater activation). Note: QA at `0` (not synced); align separately if parity desired           |
|  3 | EV `FishStats.CollectFishGenerationStats`                                             | Leave `'Y'` on prod (semantically equivalent to `1`; QA at `1` — matches functionally)                                          |
|  4 | EV `FishStats.FishGenerationStatsCleanupHorizonDays`                                  | Leave `90` (QA matches ✓)                                                                                                       |
|  5 | EV `DenuvoImmediateBanPeriod`                                                         | Already deleted on prod (KNW includes GRM-049). Replacements live in `GlobalVariables`                                          |
|  6 | 6× moved-to-`GlobalVariables` rows (LB query types, surrounding places, fish sources) | QA→PROD GV sync delivers the rows. QA snapshot confirms: all 6 in GV with expected values; absent in EV ✓                       |
|  7 | EV one-time date format conversions (`GRM.M.2024.06.26-022`)                          | No action — patch already applied (confirmed by `AppliedPatches`)                                                               |
