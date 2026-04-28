# Leaderboards — control variables

13 environment variables gate the leaderboards subsystem at runtime. They split into one master flag (UI visibility) and a 3 × 4 matrix of subsystem kill-switches (3 leaderboard types × 4 pipeline stages).

```
                  Update  Rewards  Jobs  UI
Competitive         ✓        ✓      ✓    ✓
Global              ✓        ✓      ✓    ✓
Fish                ✓        ✓      ✓    ✓
```

Plus master `IsLeaderboardsOn`.

## Master flag — `IsLeaderboardsOn`

**Default:** `false` (opt-in, must be explicitly set at release).

**Server effect (minimal):** gates `TryRaiseLeaderboardsResetEvent` only (`Photon/src-server/Loadbalancing/LoadBalancing/GameServer/GameClientPeer_Leaderboards.cs` → `TryRaiseLeaderboardsResetEvent`). Update / Get / Job paths are **not** gated by it — they have their own per-subsystem flags.

**Broadcast:** sent to client in `GameClientPeer.cs` → `SendCustomVariables` (variable bag).

**Client effect (heavy):**
- `MenuPrefabsSpawner._alternativeAddressablesLinks[FormsEnum.Leaderboards]` — entire Leaderboards menu form is spawned only when `true`. Without it, the main menu has no Leaderboards entry at all.
- `LeaderboardRewardsUpdateCounter.RewardGiven` — claim-counter forced to `0` when `false`.
- `InfoServerMessagesHandler.LeaderboardsReset` — incoming "leaderboards reset" toast suppressed when `false`.

> **Asymmetry, intentional:** flipping `IsLeaderboardsOn=N` blanks the **client** UI but leaves the **server** writing data, running jobs, and (potentially) issuing rewards. To stop server-side activity you must flip the per-subsystem flags. This lets operators hide UI without disrupting in-flight period accounting.

## Subsystem flags (3 × 4)

Naming: `Is{Type}Leaderboards{Stage}On` for `Type ∈ {Competitive, Global, Fish}` × `Stage ∈ {Update, Rewards, Jobs, UI}`.

**Default:** `true` for all 12 (`EnvironmentVariableCache.GetBoolValue(name, true)`). Absence of the row in `EnvironmentVariables` does not disable the subsystem.

| Stage        | What it gates                                                                                                                       | Adapter methods                                                                                                                                                          |
|--------------|-------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `…UpdateOn`  | Inbound writes — gameplay events feed scores into period tables                                                                     | `Update{Type}Leaderboards` (early `return false` when off)                                                                                                               |
| `…UIOn`      | Outbound reads — client-facing queries return empty                                                                                 | `Get{Type}Leaderboard*`, `Get{Type}LeaderboardRewards`, `GetFishLeaderboardSpecies` (early empty / `Ok` when off)                                                        |
| `…JobsOn`    | AsyncProcessor periodic work                                                                                                        | `Cleanup{Type}LeaderboardsData`, `FinalizeAndRestart{Type}Leaderboards`, `RotateCurrent{Type}Leaderboards`, plus `CalculateCompetitiveLeaderboardChange` for Competitive |
| `…RewardsOn` | Reward distribution at finalization. Periods still close, ranks still record — only `rewardRulesByPlace.Clear()` runs before payout | called inside `Finalize…` flow                                                                                                                                           |

`…RewardsOn` is the most subtle: it lets operators run a leaderboard period **dry** — accumulate scores, close the period — without paying rewards. Useful for the first period after a release if reward configs are not finalized.

## Push-to-static refresh

The 12 subsystem flags are **static auto-properties** on `LeaderboardsAdapter`:

```csharp
// Shared/SharedLib/Leaderboards/LeaderboardsAdapter_Competitive.cs (and analogues for Global, Fish)
public static bool IsCompetitiveLeaderboardsUpdateOn { get; set; }
public static bool IsCompetitiveLeaderboardsRewardsOn { get; set; }
public static bool IsCompetitiveLeaderboardsJobsOn   { get; set; }
public static bool IsCompetitiveLeaderboardsUIOn     { get; set; }
```

`EnvironmentVariableCache.UpdateStaticVariables` (`Shared/SharedLib/Config/EnvironmentVariableCache.cs`) writes them on every cache refresh:

```csharp
EnvironmentVariables.OnRefreshPerformed += UpdateStaticVariables;
// ...
LeaderboardsAdapter.IsCompetitiveLeaderboardsUpdateOn = IsCompetitiveLeaderboardsUpdateOn;
// ... 11 more lines, one per subsystem flag
```

`IsLeaderboardsOn` (and most other env-vars) instead use **computed properties** (`=> EnvironmentVariables.Cache.GetBoolValue(...)`) that read fresh on every access.

**Implication:** flipping any of the 12 subsystem flags **does not require a server restart** — it requires triggering an env-var cache refresh (WebAdmin "Refresh Server Caches" button, or wait for periodic refresh tick). The push happens via the `OnRefreshPerformed` event. `IsLeaderboardsOn` updates immediately on the next access (no refresh needed for it).

## Storage

Originally all 13 flags lived in `EnvironmentVariables`. As of LBM-002 (`LBM.M.2025.12.17-002`, FP-38716), the **non-flag** leaderboards configs (query types, accepted fish sources, surrounding-places counts) moved to `GlobalVariables`. The 13 boolean flags **stayed in `EnvironmentVariables`** — they are operator-controlled toggles, not balance config.

DB row name accepts both bare and `Leaderboards.`-prefixed forms; both resolve identically because `EnvironmentVariableCache.RemovePrefix` strips the first dot-separated segment when loading. Patch-installed canonical form is **bare** for the 13 flags (`IsLeaderboardsOn`, `IsCompetitiveLeaderboardsUpdateOn`, …) and `Leaderboards.`-prefixed for the configs (`Leaderboards.CompetitiveLeaderboardsQueryType`, …). The Leaderboards GDD itself mixes prefixed and bare in different paragraphs — both work.

## Client surface

| Flag                                          | Mirrored on client?    | Where read on client                                                                          |
|-----------------------------------------------|------------------------|-----------------------------------------------------------------------------------------------|
| `IsLeaderboardsOn`                            | yes                    | `MenuPrefabsSpawner.cs`, `LeaderboardRewardsUpdateCounter.cs`, `InfoServerMessagesHandler.cs` |
| `IsCompetitiveLeaderboardsUIOn`               | declared, **not read** | `Assets/Photon Server Networking/PhotonServerConnection_LeaderBoards.cs` (declaration only)   |
| `IsGlobalLeaderboardsUIOn`                    | declared, **not read** | same file (declaration only)                                                                  |
| `IsFishLeaderboardsUIOn`                      | declared, **not read** | same file (declaration only)                                                                  |
| `Is{Type}Leaderboards{Update,Rewards,Jobs}On` | not present            | server-only                                                                                   |

The 3 per-type `…UIOn` flags exist on the client API surface (`IPhotonServerConnection_Leaderboards`) but no client code currently consumes them. The operator-visible effect of toggling them is purely server-side (empty responses to Get-queries), which the client renders as empty tabs.

> **Open question:** are the per-type `…UIOn` declarations on the client a planned hook for finer per-tab gating, or stale boilerplate? See `log.md`.

## Defaults summary

| Flag                                       | Default | Implication if row absent             |
|--------------------------------------------|:-------:|---------------------------------------|
| `IsLeaderboardsOn`                         | `false` | feature off (client hides menu entry) |
| 12 × `Is{Type}Leaderboards{Stage}On`       | `true`  | subsystem on                          |

Project policy: at release time the master flag is flipped to `Y`; the 12 subsystem flags can stay absent (their absence ≡ `true`), but standard practice is to insert all 13 rows explicitly so the WebAdmin EV view shows the toggles. SQL patches insert all 13 with `'N'`; release procedure flips them to `'Y'` manually.

## Related env-vars (other modules)

These flags appeared together with leaderboards in the LBM rollout but belong to other subsystems:

- `IsRatingByPlaceEnabled` — [matchmaking](../matchmaking/_card.md) and rating subsystem. Selects between place-based rating (new GDD, JSON-driven) and legacy `TournamentRatingCalculator` formula. Mirrored on client to gate the "Rating points" column in tournament-result UI.
- `IsDailyMissionsOn` — [missions](../missions/_card.md) (daily missions). Server-only kill-switch for generation / regeneration / scheduling / WebAdmin display. No client mirror.

For the consolidated LBM-release flip list (snapshot in time), see `tasks/FP-41595--leaderboards-release-support/artifacts/abtests-and-envvars-audit.md`.
