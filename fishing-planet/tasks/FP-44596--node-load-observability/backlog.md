# FP-44596 - Backlog

- [ ] Confirm WinRM (or perf-counter RPC) reachability from the SD box to farm nodes for `-WithPerf` (else CPU%/RAM% show n/a) - coordinate with DevOps
- [ ] Decide tool home: commit `Get-NodeLoad.ps1` to SVN (where?) vs keep local on the SD box
- [ ] Evaluate centralized LoadLevel collection: directed Graphite sender vs broadcast PhotonDashboard
- [ ] Optional: add CPU%/RAM% history or HTML export to the tool
- [ ] Optional: promote load-balancing observability notes to a server module card / Confluence
