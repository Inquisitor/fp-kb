# Release checklist content — `Environment Variables and AB Tests` step

**Target:** [2026.3 - Leaderboards/Matchmaking/DailyMissions Server Release checklist](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/5403607042/2026.3+-+Leaderboards+Matchmaking+DailyMissions+Server+Release+checklist) — step "Environment Variables and AB Tests"
**Format:** matches existing checklist style (`<Variable>`= `<Value>` for EVs; `<Platform> #<TestId> (<Name>) - Default Value - <bool> (<bit>), Enabled - <bool> (<bit>)` for tests).
**Source data:** QA snapshot 2026-04-27 + GD requirements confirmation 2026-04-27.

**Scope:** only `EnvironmentVariables` and `AbTests` rows (which are patch-managed and require manual rollout actions). `GlobalVariables` and `JsonVariables` are fully replaced from QA via DataPump (release checklist step "Transfer data updates from QA") — they need no entries in this checklist step.

---

## ★ Paste this into Confluence cell

GD requirements (2026-04-27): leaderboards fully disabled; rating enabled; daily missions enabled; new A/B tests (21, 22) inactive with `DefaultValue=false` (return false for all players); `UseTrackedDelivery` disabled.

```markdown
**Environment Variables:**

Leaderboards (disabled):
- `IsLeaderboardsOn`= `N`
- `Leaderboards.IsCompetitiveLeaderboardsUpdateOn`= `N`
- `Leaderboards.IsCompetitiveLeaderboardsRewardsOn`= `N`
- `Leaderboards.IsCompetitiveLeaderboardsJobsOn`= `N`
- `Leaderboards.IsCompetitiveLeaderboardsUIOn`= `N`
- `Leaderboards.IsGlobalLeaderboardsUpdateOn`= `N`
- `Leaderboards.IsGlobalLeaderboardsRewardsOn`= `N`
- `Leaderboards.IsGlobalLeaderboardsJobsOn`= `N`
- `Leaderboards.IsGlobalLeaderboardsUIOn`= `N`
- `Leaderboards.IsFishLeaderboardsUpdateOn`= `N`
- `Leaderboards.IsFishLeaderboardsRewardsOn`= `N`
- `Leaderboards.IsFishLeaderboardsJobsOn`= `N`
- `Leaderboards.IsFishLeaderboardsUIOn`= `N`

Matchmaking / Rating (enabled):
- `IsRatingByPlaceEnabled`= `Y`

Daily Missions (enabled):
- `IsDailyMissionsOn`= `Y`

Tracked Delivery (disabled):
- `UseTrackedDelivery`= `false`

**Ab Tests:**

- All platforms #21 (Override Daily Missions MinLevel) - Default Value - `false` (`0`), Enabled - `false` (`0`)
- All platforms #22 (Skip Character Customization on Start) - Default Value - `false` (`0`), Enabled - `false` (`0`)
```

---

## Background sections (analytical reference; superseded by GD-confirmed paste block above)

## Section 1 — LB / MM / Rating / DM

⚠ **TBD — to verify with feature owners 2026-04-28**

### Environment Variables

```
IsLeaderboardsOn                                  = N
Leaderboards.IsCompetitiveLeaderboardsUpdateOn    = N
Leaderboards.IsCompetitiveLeaderboardsRewardsOn   = N
Leaderboards.IsCompetitiveLeaderboardsJobsOn      = N
Leaderboards.IsCompetitiveLeaderboardsUIOn        = N
Leaderboards.IsGlobalLeaderboardsUpdateOn         = N
Leaderboards.IsGlobalLeaderboardsRewardsOn        = N
Leaderboards.IsGlobalLeaderboardsJobsOn           = N
Leaderboards.IsGlobalLeaderboardsUIOn             = N
Leaderboards.IsFishLeaderboardsUpdateOn           = N
Leaderboards.IsFishLeaderboardsRewardsOn          = N
Leaderboards.IsFishLeaderboardsJobsOn             = N
Leaderboards.IsFishLeaderboardsUIOn               = N
IsRatingByPlaceEnabled                            = Y
IsDailyMissionsOn                                 = Y
```

All 15 values pulled from QA. Verify with:
- Leaderboards owner — 13× `Leaderboards.Is*On` + `IsLeaderboardsOn`
- MM/Rating owner — `IsRatingByPlaceEnabled`
- DM owner — `IsDailyMissionsOn`

### Ab Tests

```
All platforms #21 (Override Daily Missions MinLevel) — Default Value false (0), Enabled false (0)
```

Test 21 arrives via `LBM.M.2026.03.12-034`. Patch insert values match QA. ⚠ TBD: verify with DM / LiveOps whether to activate (`Enabled=true`) or set `DefaultValue=true` at rollout (QA signal: leave inactive).

---

## Section 2 — Other variables

### 2.1 Existing on prod — preserve current values (no rollout action)

These rows are already on prod from earlier branch releases. Migrations use `IF NOT EXISTS` and never overwrite — current prod values are preserved automatically.

#### Environment Variables (current prod values)

```
UseNewUserSearch                                  = 1                  (intentional Saltwater activation)
AccountDeletionImmediateUnbindPlatforms           = Apple,Android      (mobile-driven default)
FishStats.CollectFishGenerationStats              = Y                  (semantically equivalent to 1)
FishStats.FishGenerationStatsCleanupHorizonDays   = 90                 (retention)
DetailedAnalyticsLoggingMaxLevel                  = 10                 (LBM-001 cherry-picked, FTUE cap)
Ping.DisableTpmPingThresholdMs                    = 0                  (TPM cutoff disabled)
Ping.DisableTpmTriggerDelayMs                     = 3000
Ping.DisconnectClientPingThresholdMs              = 0                  (disconnect-on-bad-ping disabled)
Ping.DisconnectClientTriggerDelayMs               = 5000
Connectivity.IsNetworkThreadEnabled               = N
Connectivity.NetworkThreadPriority                = AboveNormal
```

⚠ TBD — confirm with owners that these are intentional baselines and require no change at rollout. QA snapshot signals "leave inactive" for all but the first three. Owners to consult:
- `UseNewUserSearch` — owner of FP-31648 (already confirmed by user: leave at `1`)
- `AccountDeletionImmediateUnbindPlatforms` — Mobile team / FP-36647 owner
- `FishStats.*`, `DetailedAnalyticsLoggingMaxLevel` — FP-39058 / FP-41294 owners
- `Ping.*` — FP-38665 owner (Dmytro K)
- `Connectivity.*` — FP-38663 owner

#### Ab Tests (current prod values, preserve as-is)

```
All platforms #16 (Personal Offers A/B Test)               — Default Value true  (1), Enabled false (0)   [GD-managed: feature ON for all]
All platforms #17 (New Leaderboards feature is On)         — Default Value false (0), Enabled false (0)   [legacy, superseded by EV IsLeaderboardsOn]
All platforms #18 (Personal Offer: Free Starter Pack)      — Default Value false (0), Enabled false (0)   [GD-managed: feature OFF for all]
All platforms #19 (Personal Offer: New products for start) — Default Value true  (1), Enabled false (0)   [GD-managed: feature ON for all]
All platforms #20 (Hide Pond Passes from PremShop)         — Default Value false (0), Enabled false (0)   [GD-managed: feature OFF for all; LBM-010 already cherry-picked]
```

⚠ TBD — verify with GD/LiveOps whether any of these need a change at rollout (e.g. flip `Enabled` for a launch). Default action: leave as-is.

> Note on tests 16/17/18/19/20: patches use `IF NOT EXISTS`, so even after running migration, current prod rows are preserved. No manual no-op needed.

### 2.2 New at LBM rollout — confirm activation

These rows arrive via LBM patches not yet on prod.

#### Environment Variables (new)

```
UseTrackedDelivery                                = false              (LBM-036 INSERT default)
```

⚠ TBD — verify with FP-41417 owner (Yuriy B) whether to set `'true'` at rollout or leave `'false'` (QA signal: leave at `'false'`). Pairs with new `TransactionDeliveryItems` table.

#### Ab Tests (new)

```
All platforms #22 (Skip Character Customization on Start) — Default Value false (0), Enabled false (0)
```

Test 22 arrives via `LBM.M.2026.03.23-037`. Patch insert values match QA. ⚠ TBD — verify with FTUE / FP-42053 owner whether to activate (`Enabled=true`) or set `DefaultValue=true` at rollout (QA signal: leave inactive).

---

## How to use this content

1. Walk Section 1 + 2.2 through feature owners 2026-04-28 — collect Set/Leave decisions per row.
2. Update statuses here from ⚠ TBD → ✓ confirmed (with owner name + date).
3. Once all TBDs resolved, paste the resulting Section 1 + 2.2 blocks into Confluence release checklist step "Environment Variables and AB Tests" (replacing the current `[TBD]` placeholder).
4. Section 2.1 rows do not go into Confluence checklist (no rollout action), but should be cross-referenced when verifying patch idempotency on each prod stream.
