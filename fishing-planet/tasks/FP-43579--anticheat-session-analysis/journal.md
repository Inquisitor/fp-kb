---
status: planning
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-43579
---
# FP-43579: AntiCheat Game Session Analysis

## Status
Design phase. Capturing requirements and architecture before any code.
Next: draft requirements doc covering data sources, processing rules, UI flows, known cheat signatures.

## Summary
WebAdmin tool for moderators to inspect player game sessions for anti-cheat patterns. Lives under Player → Moderation. Goal: visualize a player's fishing sessions with click-coordinate heatmaps, event timelines, and raw log views, surfacing bot signatures that are otherwise hidden in the merged log.

Iteration goal: cleanly designed backend (thin controller + service + DAL) and frontend (Vue 3 component tree) with reusable building blocks — no inline boilerplate.

## Background — investigation findings

A pre-task investigation (prototype Python heatmap renderer) established the analytical patterns this tool will operationalize:

- **TakeClick / ReleaseClick coordinates** are written to Mongo `fishingLog` by the client via `Mouse.current.position.ReadValue()` at the moment the handler fires — whether triggered by mouse click, hotkey, or programmatic invocation. Coordinates are pixel-integer (Windows mouse pixel space)
- **Honest player**: clicks scatter across the actual KEEP / RELEASE button area on screen
- **Pattern A — LureKing** (confirmed bot signature, primary threat): hardcoded screen coordinates — `(663, 89)` for KEEP, `(473, 89)` for RELEASE — identical to the pixel across multiple unrelated accounts (sample: `LUYA168`, `rrsrewr`). Calibrated against a non-standard ~1136-wide window. No plausible non-bot explanation: two unrelated accounts cannot independently produce identical sub-pixel coordinates. Distribution and technical details captured in [artifacts/lureking-notes.md](artifacts/lureking-notes.md).
- **Pattern B — window-center cluster** (suspicious, attribution open): clicks concentrate at approximately `(window_w/2, window_h/2)` in client coords (sample: `W_CHUANQI`, `Niepan.LD`, `DFT_KennPF`, `adidan`). Two competing hypotheses, neither yet ruled out:
  - bot programmatically positions cursor before each handler invocation
  - Unity auto-centers cursor on some event (screen change / focus loss) and controller-only play leaves it there
  - A cluster outside KEEP/RELEASE button areas is **suspicious** regardless of cause and warrants per-case investigation. The tool is being built specifically to make this attribution feasible.

Catch panel UI geometry constants, scaling rule (match-width), recalibration guidance, and notes on why the empirical method is a stopgap (the proper approach is reading the prefab in Unity Editor) — see [artifacts/ui-geometry-calibration.md](artifacts/ui-geometry-calibration.md).

## Plan

Phases describe the workflow pipeline. Inside each phase, individual work items use 3-letter category prefixes (per FP-41746 convention): **ARC** = architecture decision, **RES** = research / spike, **DAT** = data access layer, **BCK** = backend C#, **BLD** = build pipeline, **FRT** = frontend Vue, **DOC** = documentation, **TST** = tests. Subtask IDs are KB-internal and never appear in commit messages or external docs.

- [x] **Phase 1 — Requirements doc** — see [artifacts/requirements.md](artifacts/requirements.md). v1 scope, future phases, data sources, UI behaviors, server architecture sketch, frontend stack candidate, open hypotheses, long-term goal. Concretization happens in subsequent phases.

- [ ] **Phase 2 — Architecture doc** — output: `artifacts/architecture.md`. Each item below is a separate architectural decision; some need a small spike to be answerable.
  - **RES-001** — Vue 3 build pipeline spike: does it integrate with WebAdmin host page (mount-point, initial state injection, hot-reload during dev)? Existing `TargetedAdsPlanningTool` (Vue 2 + Vuetify) is a reference for *integration*, not for code style. Fallback if it doesn't fly: vanilla JS module.
  - **RES-002** — Read `CatchedFishInfo.prefab` in Unity Editor for canonical UI geometry (replaces the stopgap empirical method documented in [ui-geometry-calibration.md](artifacts/ui-geometry-calibration.md)). Output: confirmed canvas-coord constants + `CanvasScaler` mode, written into the calibration doc.
  - **ARC-001** — Frontend stack & host integration: Vue 3 + TS confirmed (or fallback per RES-001 result). Mount-point in MVC view, initial-state-as-JSON pattern, dev server / build commands documented.
  - **ARC-002** — Backend layering: namespaces and responsibilities for Controller (thin, routing + auth), Service (logic), DAL (existing providers + new read methods), DTO/ViewModel boundary. No DAL types leak past Service.
  - **ARC-003** — Data contracts: JSON shapes for AJAX endpoints (sessions list, session details, events stream, screenshot fetch). Versioned implicitly by endpoint path; explicit if breaking changes anticipated.
  - **ARC-004** — Component tree: AntiCheatApp → SessionsListView → SessionCard → (TimelineView / HeatmapView / RawEventsView / CalibrationPanel). Props and events between components.
  - **ARC-005** — Persistence schema: localStorage keys and JSON format for per-player calibration. Migration story for schema changes.
  - **ARC-006** — Reuse hooks: how future phases (timeline expansion, pond map, anomaly detection) plug into the same component primitives without rewriting them.

- [ ] **Phase 3 — Subtask breakdown** — output: ordered list of implementation subtasks (DAT / BCK / BLD / FRT / DOC / TST) with scope, files affected, entry/exit criteria, rough effort, dependencies. Vertical-slice approach: each subtask leaves the tool in a demo-able state.

- [ ] **Phase 4+ — Implementation** — execute subtasks in order. After each: review, integrate, update journal milestones and backlog. New findings during implementation either open new subtasks or fold into existing ones.

## Milestones

- 2026-05-02: JIRA FP-43579 created. Pre-task prototype investigation completed (heatmap renderer + cheat signature analysis on 6 sample players). Initial WebAdmin scaffolding written, then reverted — restart with proper architecture. KB task opened. Requirements doc drafted — v1 scope, future phases, open hypotheses captured. LureKing identified as primary threat (Pattern A), notes captured in [artifacts/lureking-notes.md](artifacts/lureking-notes.md).
