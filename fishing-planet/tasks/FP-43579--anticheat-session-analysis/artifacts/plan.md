---
phase: 3
status: ready
generated: 2026-05-03
---
# FP-43579 — Implementation Plan

Vertical-slice ordering. Each slice (`VS*`) leaves the tool demo-able. Category prefixes (`DAT/BCK/BLD/FRT/DOC/TST`) are tags, not ordering. Per-subtask details live in [subtasks/](subtasks/).

Effort key: **S** ≤2h, **M** 2-4h, **L** 4-8h.

## VS0 — Architecture corrections (no code)

| ID      | File                                                          | Effort | Status          |
|---------|---------------------------------------------------------------|--------|-----------------|
| DOC-000 | [retention-fix](subtasks/FP-43579--DOC-000--retention-fix.md) | S      | DONE 2026-05-03 |

## VS1 — End-to-end skeleton (one endpoint round-tripped to UI)

Smallest possible vertical: pick the cheapest source (MonitorInfo, no DAL change), wire it through the entire stack including the filter form. Filter form is core navigation, not polish — without it every range change is a manual URL edit.

| ID      | Subtask                                                                       | Depends-on       | Effort | Status          |
|---------|-------------------------------------------------------------------------------|------------------|--------|-----------------|
| BCK-001 | [MonitorInfo endpoint](subtasks/FP-43579--BCK-001--monitorinfo-endpoint.md)   | —                | M      | DONE 2026-05-03 |
| FRT-001 | [Vue tree skeleton](subtasks/FP-43579--FRT-001--vue-tree-skeleton.md)         | —                | M      | DONE 2026-05-03 |
| FRT-002 | [MonitorInfo render](subtasks/FP-43579--FRT-002--monitorinfo-render.md)       | BCK-001, FRT-001 | S      | DONE 2026-05-03 |
| BCK-004 | [Filter form + refresh](subtasks/FP-43579--BCK-004--filter-refresh.md)        | FRT-001          | S      | DONE 2026-05-03 |

**Demo at end of VS1**: open `/Anticheat/GameSessionAnalysis?userId=...&from=...&to=...`, see admin chrome + filter form with Kendo date pickers + 3 stub components mounted; CalibrationPanel shows real Monitor distinct values pulled from Mongo. Apply changes range without full reload (Events / Screenshots stubs return empty until VS2 / VS3 land).

## VS2 — Events visualisation (heatmap)

Main demo value lands here.

| ID      | Subtask                                                                                     | Depends-on | Effort | Status          |
|---------|---------------------------------------------------------------------------------------------|------------|--------|-----------------|
| BCK-002 | [Events endpoint](subtasks/FP-43579--BCK-002--events-endpoint.md)                           | FRT-001    | M      | DONE 2026-05-03 |
| FRT-003 | [HeatmapView canvas](subtasks/FP-43579--FRT-003--heatmap-canvas.md)                         | BCK-002    | M-L    | DONE 2026-05-03 |
| FRT-004 | [CalibrationPanel resolution + offset](subtasks/FP-43579--FRT-004--calibration-controls.md) | FRT-003    | M      | DONE 2026-05-03 |
| FRT-005 | [usePlayerCalibration localStorage](subtasks/FP-43579--FRT-005--calibration-persistence.md) | FRT-004    | S      | DONE 2026-05-03 |

**Demo at end of VS2**: TakeClick / ReleaseClick rendered on canvas; resolution preset and manual offset visibly re-render points; refresh page → calibration restored.

## VS3 — Screenshots paged

DAL signature change ships here, gated by need.

| ID      | Subtask                                                                                   | Depends-on       | Effort | Status          |
|---------|-------------------------------------------------------------------------------------------|------------------|--------|-----------------|
| DAT-001 | [Extend GetPlayerScreens + Count](subtasks/FP-43579--DAT-001--extend-getplayerscreens.md) | —                | S+     | DONE 2026-05-03 |
| BCK-003 | [Screenshots endpoint](subtasks/FP-43579--BCK-003--screenshots-endpoint.md)               | DAT-001          | S      | DONE 2026-05-03 |
| FRT-006 | [ScreenshotStrip + paging](subtasks/FP-43579--FRT-006--screenshot-strip.md)               | BCK-003          | M      | DONE 2026-05-03 |
| FRT-007 | [Heatmap overlay on screenshot](subtasks/FP-43579--FRT-007--heatmap-on-screenshot.md)     | FRT-006, FRT-003 | S      | DONE 2026-05-03 |

**Demo at end of VS3**: thumbnails strip pages 20-at-a-time; click thumbnail → full screenshot loaded → clicks within ±N seconds overlaid.

## VS4 — Polish

| ID      | Subtask                                                                                            | Depends-on                | Effort | Status          |
|---------|----------------------------------------------------------------------------------------------------|---------------------------|--------|-----------------|
| FRT-008 | [Loading + error UI](subtasks/FP-43579--FRT-008--loading-error-ui.md)                              | FRT-002, FRT-003, FRT-006 | S      | DONE 2026-05-03 |
| FRT-009 | [Kendo Dropdown bridge (with stop-criteria)](subtasks/FP-43579--FRT-009--kendo-dropdown-bridge.md) | FRT-004                   | M      | DONE 2026-05-03 |
| DOC-001 | [README + KendoDropdown gotchas](subtasks/FP-43579--DOC-001--readme.md)                            | FRT-009                   | S      | DONE 2026-05-03 |

## VS5 — Tests

| ID      | Subtask                                                                       | Depends-on | Effort | Status                  |
|---------|-------------------------------------------------------------------------------|------------|--------|-------------------------|
| TST-001 | [DAL tests for date-range + paging](subtasks/FP-43579--TST-001--dal-tests.md) | DAT-001    | M      | DEFERRED to post-v1     |
| TST-002 | [Manual smoke checklist](subtasks/FP-43579--TST-002--smoke-checklist.md)      | All        | S      | DONE 2026-05-04         |

## Out of scope (handled by separate items)

- KB `logging` module promotion → DOC-003 in [backlog](../backlog.md), separate task
- KB `web-admin` module promotion → DOC-002 in [backlog](../backlog.md), post-v1
- Vue unit-test infrastructure (vitest) — deferred; manual smoke + DAL-level tests sufficient for v1
- **Controller / model unit tests** in `WebAdmin.Tests` (date-validation guards in BCK-001/002/003, regex parser in BCK-002, 4xx error path) — covered by manual smoke (TST-002) only. Decision rationale: WebAdmin.Tests has no fixture infrastructure for controllers, Abuse-gated admin tool with low blast radius doesn't justify scaffolding cost for v1. Reconsider if Phase 4 anomaly scoring lands testable business logic.
- `RawEventsView`, cross-component highlight, anomaly scoring — Phase 4+ per [architecture.md](architecture.md#future-phase-compatibility-arc-006)

## Execution

Each subtask is a SVN commit. Subtasks within a slice may be ordered loosely; cross-slice deps enforced by the table.

Workflow: read subtask file → implement → run smoke → svn commit → mark `status: done` in subtask frontmatter → tick checkbox here.

**Commit message format** (per project memory): `FP-43579: [<topic>] <summary>` + bullets (`+ - = *`) + `(<task type>: <JIRA summary>)` + JIRA URL. **Do NOT** include subtask IDs (BCK-001, DAT-001, ...) — they are KB-internal. **Do NOT** include count narrative («added 6 tests», «updated 21 files»). **Do NOT** include intra-session revert history. Bullets describe the feature as it lands, not the path.
