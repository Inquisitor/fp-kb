# Backlog - FP-44594

## Immediate
- [ ] Connect Photon Tool to staging under load; capture `stats` / `stats peer 20 8` / `stats sql 20 8` / `stats nosql 20 8` / `stats queue` / `tops` snapshots
- [ ] Static pass: enumerate the cache registry from startup init; classify each cache by key dimension + growth law; flag per-account accumulating ones (leak candidates)
- [ ] One calibration snapshot on staging (dotMemory or PerfView) to measure real per-entry retained sizes + find blind-spot retainers
- [ ] Write the perf-diagnostics playbook (deliverable 1)
- [ ] Assemble memory map (deliverable 2) and CPU map (deliverable 3)

## Deferred (follow-up tech-debt, bubble up to module/epic)
- [ ] Photon Tool: emit raw JSON instead of preformatted CSV strings (`OperationStatsSnapshot.ToCsvString`)
- [ ] Compute self-time (Peer minus child Sql/NoSql) in `PerformanceAdapter`
- [ ] Add `mem` / `caches` console commands (perf-counter heap metrics + per-cache count/size)
- [ ] WebAdmin stats page (reuse existing `StandaloneClient` connection; auth/roles/audit)
- [ ] Metrics exporter (delta-based) -> Prometheus/Grafana with alerts

## Open questions
- [ ] Which staging environment + which Game server(s) to profile under realistic load
- [ ] Estimate per-cache retained size without a full object-graph walk (sharing makes naive deep-size overcount)
