---
jira: FP-44596
title: Farm node load observability / monitoring
status: in-progress
executor: Stanislav Samoilov
created: 2026-06-21
type: story
---

# FP-44596 - Farm node load observability / monitoring

## Status
Investigation done; first tool drafted (`artifacts/Get-NodeLoad.ps1`, syntax + offline render verified). Open: confirm WinRM reachability to nodes for CPU%/RAM%; decide tool home (SVN vs SD box); evaluate centralized Graphite collection. Parent epic: FP-43213 (Tech Debt 2026 Q2).

## Summary

How a game node's load level is computed and surfaced (entry points):

- **Compute** - `WorkloadController.Update` (LoadShedding) samples perf counters and feeds `FeedbackControlSystem`; each per-metric `FeedbackController` maps a value to a `FeedbackLevel` via a threshold ladder; overall level = MAX across controllers (`FeedbackControllerCollection.CalculateOutput`). Hysteresis lives in `FeedbackController.SetInput` (climbs on the target level's threshold, descends on the lower level's), so a snapshot band is approximate.
- **Expose** - `OutgoingMasterServerPeer.ProcessFlags` writes `<app>\Flags\{LoadLevel, PeerCount, OutOfRotation}`. `EncodeFeedbackLevel` relabels the enum for ops: Lowest->Empty, Low->Low, Normal->Normal, High->High, Highest->Full. Gotcha: the ops-facing words differ from the enum names - "Empty"/"Full" are Lowest/Highest.
- **Collect** - each node runs the SD agent (`ManageController` -> `ScriptExecutor.GetStatus`) on port 90, reading those flag files and returning a CSV; central SD (`DistributorCommon.Distributor.RunCommandAsync`, verb getStatus) polls `http://<ip:90>/Manage/Action?name=getStatus` and parses by field count (4..8; Game=8 has Load at [7], PeerCount [4], OutOfRotation [5]). Node inventory: `SoftwareDistributor\SoftwareDistributor\Distributor.json` (Ip/Role; FarmName not set in the committed copy, so farm grouping is effectively by Role).

Config reality on this deployment:
- Thresholds = code defaults (`LoadShedding\Configuration\DefaultConfiguration.cs`): CPU 20/35/50/70/90, RAM 30/45/60/80/90 - `Workload.config` is not deployed, so defaults are what runs.
- `MaxCcu` is not set in any config -> default 5000 (peer-count controller: Normal=2500, High=4000, Highest=5000).
- `EnableLatencyMonitor=False` -> latency controllers stay inert; `IsRamWorkloadOn=True`.

Observability channels:
- `CounterPublisher` broadcasts all `[PublishCounter]` counters (incl. LoadLevel, CpuAvg, EnetQueueAvg) via UDP 255.255.255.255:40001 (PhotonBinary). Receiver = `PhotonDashboard` (Photon SDK binary - RRD + web UI, installed as a Windows service via InstallUtil). Limited broadcast does not cross subnets, so it does not aggregate across cloud nodes - effectively per-host in this topology.
- `PerfCounterManager` is a separate tool that installs business Windows perf-counter categories (chat/club queues, cache-refresh cycles), NOT the workload counters.
- Zabbix reads raw OS counters, not the computed LoadLevel.

## Plan / deliverables
1. Document the compute/expose/collect chain (this journal; optionally promote to a server module card / Confluence).
2. Tooling - `artifacts/Get-NodeLoad.ps1`: reads Distributor.json, polls getStatus, renders per-node load (+ peers, OOR); `-WithPerf` adds CPU%/RAM% over WinRM (`Invoke-Command` + `Get-Counter`) mapped to the thresholds above; also `-Watch`, `-ShowThresholds`, `-PassThru`. HTTP path needs only port 90; percentages need WinRM.
3. Centralized collection - evaluate a directed `<Sender protocol="Graphite">` to one collector vs the broadcast dashboard, so LoadLevel from all nodes lands in one readable place.

## Milestones
- 2026-06-21 [MFT] Investigated load-level compute/expose/collect chain; created FP-44596 under FP-43213; first tool cut `Get-NodeLoad.ps1` added to artifacts (syntax + offline render verified).
