# Leaderboards — log

## 2026-04-28
Module created during FP-41595 release-support investigation. Deep dive [Control variables](control-variables.md) added — durable runtime semantics for the 13 leaderboards env-var flags (1 master + 12 subsystem), push-to-static refresh mechanics via `EnvironmentVariableCache.UpdateStaticVariables`, and client mirror map.

Finding (open): client (`Assets/Photon Server Networking/PhotonServerConnection_LeaderBoards.cs`) declares 3 per-type `…UIOn` properties (`IsCompetitiveLeaderboardsUIOn`, `IsGlobalLeaderboardsUIOn`, `IsFishLeaderboardsUIOn`) but no client C# code reads them. Either reserved for future per-tab gating, or stale. Worth a clarifying ask to the LB feature team before LBM rollout — if they are stale the WebAdmin/QA bar for testing per-type UI toggles is currently lower than expected (effect is purely empty server response). Backlog item created.

Finding: `IsLeaderboardsOn` server-side gates only `TryRaiseLeaderboardsResetEvent`, not the data flows. Asymmetry is intentional — flipping the master to `N` blanks the client UI without disrupting in-flight period accounting. Documented in `control-variables.md` § Master flag.
