---
jira: FP-44594
title: Map CPU/memory usage of Photon server processes + diagnostic playbook
status: planning
executor: Stanislav Samoilov
created: 2026-06-21
type: story
---

## Status

Plan and approach agreed; deliverable work not started. The Photon Tool was investigated end-to-end (how `stats`/`tops`/`gc`/`e` actually measure CPU and memory) and the org/build-vs-buy strategy is decided. Next: produce the three deliverables (playbook, memory map, CPU map). Parent epic: FP-43213 (Technical Debt - 2026 Q2).

## Summary

Goal: understand what dominates **CPU and memory** in the Photon server processes (Master / Game / Chat / Club) and have a repeatable way to measure it. The base instrument is the **Photon Tool** interactive console (`PhotonTool.exe c`). Confluence: Photon Tool, page id `3702784005`.

How the tool measures things (established by reading the source, not docs):
- **CPU is measured indirectly via per-operation wall-clock time.** `PerformanceAdapter` wraps every operation and records timing into four buckets: **Peer** (`stats peer` - game-logic ops), **Fiber** (`stats fiber` - enqueue/fiber processing), **Sql**, **NoSql**. `stats` shows the aggregate; `stats <bucket> [n] [order]` shows top-N ordered by a column index. `stats queue` shows per-peer/per-room backlog. `tops [opmask] [n]` is the per-op trace tree (sub-step timing).
- **Memory** has no object-level profiling: only `gc.collect`/`gc.compact` (report Physical/Managed/Unmanaged before/after) and `e` for live inspection of caches/collections.

## Design decisions (the "why")

1. **Two distinct jobs, different tools.** Continuous *monitoring* (is it healthy / leaking / GC-pressured) vs one-off *forensics* (which objects, who retains them). Do not conflate.
2. **CPU signal = self-time, not wall-clock.** `duraTot` mixes queue-wait + Sql + NoSql + compute. Real CPU proxy = Peer time minus child Sql/NoSql time (computable from the existing `OperationTrace` sub-steps that back `tops`).
3. **.NET Framework 4.7.2 kills half the modern tooling.** `dotnet-counters`/`gcdump`/`trace` (EventPipe) and `GC.GetGCMemoryInfo()`/`GetTotalAllocatedBytes()` are .NET Core 3.0+ and **do not apply**. On Framework the live channels are **ETW (PerfView)** and **`.NET CLR Memory` perf counters**; `AppDomain.MonitoringTotalAllocatedMemorySize` gives alloc rate; dotMemory/procdump+SOS for forensics.
4. **Organization: do not build a desktop GUI.** Monitoring -> Grafana (the UI solves itself). Interactive ops (`stats`/`tops`/`e`/`kill`/`cache.refresh`) -> **WebAdmin**, because WebAdmin already holds the same `StandaloneClient`/`PhotonHelper` connection to Photon (see `Global.asax.cs`) plus auth/roles/audit and the game-server registry. Thin CLI stays as break-glass + scripting.
5. **Build vs buy for memory.** *Build* the monitoring (perf counters + alloc rate + a domain-specific per-cache accounting that no generic profiler can give in business terms). *Buy/use* existing profilers (dotMemory/PerfView) for forensic "which objects / who holds them".
6. **A byte-exact memory map from code alone is impossible** (object-graph sharing -> dominator tree only known at runtime; fragmentation; hidden native/pool retainers). What is realistic: a **structural/parametric model** `Memory ~= Sum(cache.count * unitSize) + PeerCount * peerSize + RoomCount * roomSize + residual`, with counts queried live (`e ...Items.Count`, `e ctx.GameApp.PeerCount`) and unit sizes calibrated by one profiler snapshot. Caches dominate and are enumerable, which makes this unusually feasible here.

## Entry points (where to look)

- **Server debug-command dispatch**: `Photon/src-server/Loadbalancing/LoadBalancing/GameServer/GameClientPeer_System.cs` -> `HandleDebugCommand` (routes to `CacheHelper`, `GcHelper`, `PerformanceAdapter`).
- **Stats/tops core**: `.../LoadBalancing/DalAdapters/PerformanceAdapter.cs` -> `HandleStatRequest`; four buckets via `OperationStats.{GameStats,FiberStats,SqlStats,NoSqlStats}`; `GetTracking`/`logDelay` do the per-op timing; `FlushStats` flush interval = 20s dev / 300s prod.
- **Stats columns**: `Dal/Dal.Common/Stats/OperationStatsSnapshot.cs` (`count`, `duraAVG/duraMAX/duraTot`, `wAVG`, `countLong5/10`). Formatting is baked into `ToCsvString()` -> blocks Grafana/WebAdmin consumers; emitting raw JSON is the unblocking change.
- **GC/memory**: `.../LoadBalancing/Helpers/GcHelper.cs` (`gc.collect`/`gc.compact` report Physical/Managed/Unmanaged; sets `SustainedLowLatency`).
- **CLI**: `Photon/tools/PhotonHelper/PhotonHelper/PhotonConsole/PhotonConsoleHelper.cs` (commands), `.../EntryPoint.cs` (load-test modes `mc`/`ml`/`rc`).
- **WebAdmin already talks to Photon**: `WebAdmin/WebAdmin/Global.asax.cs` (`PhotonHelper.InitTcp/InitWss` via `StandaloneClient`, MessengerUser) - basis for a WebAdmin stats page.

## Plan (deliverables)

1. **Photon Tool perf-diagnostics playbook** - reading `stats`/`tops`/`stats queue`/`gc.*`/`e`; column meanings; wall-clock vs self-time; CPU and memory checklists; prod warnings (`gc.compact`/`gc.collect 2` = blocking pause; `kill`/`cache.refresh` intrusive).
2. **Memory map** - inventory of `Caches`/`DataCaches` (~40+) from startup init, classified by key + growth law (reference/content - per-online - per-account accumulating = leak candidates); parametric model + one calibration snapshot.
3. **CPU map** - operations ranked by self-time; typical top consumers.

Follow-up tech-debt tasks (separate, same epic): Photon Tool JSON output + self-time in `PerformanceAdapter`; WebAdmin stats page; metrics exporter to Grafana; `mem`/`caches` console commands.

## Milestones

- 2026-06-21 Investigated Photon Tool architecture (Confluence page 3702784005 + source: `PhotonConsoleHelper`, `EntryPoint`, `PerformanceAdapter`, `GcHelper`, `OperationStatsSnapshot`, `GameClientPeer_System.HandleDebugCommand`). Established stats/tops/gc/e mechanics and the design decisions above.
- 2026-06-21 Created JIRA FP-44594 (Story) under epic FP-43213 (Technical Debt - 2026 Q2), Scrum Team = Other, assignee Stanislav. Created this KB card.
