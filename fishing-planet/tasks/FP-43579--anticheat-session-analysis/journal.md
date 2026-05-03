---
status: in-progress
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-43579
---
# FP-43579: AntiCheat Game Session Analysis

## Status
Phase 2 (architecture) fully closed. RES-001 verified by working scaffold spike (Vue 3 + TS + Vite embeds in WebAdmin Razor page cleanly). RES-002 closed by runtime measurement in Unity Editor play mode via `uloop` CLI — canonical UI geometry committed to `WebAdmin/WebAdmin/Components/AntiCheatTool/src/calibration/uiGeometry.ts` (path within SVN repo), verified against LureKing empirical click coords. DAL strategy fixed as variant B (`GetPlayerScreens` extended with optional `from/to/skip/take`, plus new `GetPlayerScreensCount`). Architecture doc at [artifacts/architecture.md](artifacts/architecture.md).
Next: Phase 3 — subtask decomposition (DAT / BCK / BLD / FRT / DOC / TST) using `superpowers:writing-plans`.

## Summary
WebAdmin tool for moderators to inspect player game sessions for anti-cheat patterns. Linked from Player → Moderation (`Cheat` page) and accessible via top-level URL `/Anticheat/GameSessionAnalysis`. Goal: visualize a player's clicks (TakeClick / ReleaseClick) over a time range as a heatmap on top of player's screenshot, surfacing bot signatures (LureKing hardcoded coords, window-center clusters) that are otherwise hidden in the merged log.

Iteration goal: cleanly designed backend (thin controller + Models per WebAdmin convention, no Services layer) and frontend (Vue 3 + TS + Vite, embedded as island in Razor host, no UI kit, scoped styles) with reusable building blocks — no inline boilerplate.

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

- [x] **Phase 2 — Architecture doc** — see [artifacts/architecture.md](artifacts/architecture.md). All architectural decisions captured (closure table at top of doc). RES-001 verified by working scaffold spike; RES-002 parked as user task (not v1 blocker).
  - [x] **RES-001** — Vue 3 build pipeline spike. Closed by live scaffold + Razor embed verification. Findings: Vuetify (not Vue) was root cause of past `TargetedAdsPlanningTool` embed failure; no UI kit + scoped styles solves it cleanly.
  - [x] **RES-002** — Read canonical UI geometry. Done via `uloop` CLI runtime measurement (not prefab YAML — runtime overrides differ from prefab). Canvas: HUD_UI ScreenSpaceOverlay 1920×1080 reference, ScaleWithScreenSize + Expand. KEEP=PriorityButton, RELEASE=Button. Values in `WebAdmin/WebAdmin/Components/AntiCheatTool/src/calibration/uiGeometry.ts` (in SVN repo), reconciled with LureKing empirical at 1136-wide.
  - [x] **ARC-001..006** — all decided. See [architecture.md](artifacts/architecture.md) closure table.

- [ ] **Phase 3 — Subtask breakdown** — output: ordered list of implementation subtasks (DAT / BCK / BLD / FRT / DOC / TST) with scope, files affected, entry/exit criteria, rough effort, dependencies. Vertical-slice approach: each subtask leaves the tool in a demo-able state.

- [ ] **Phase 4+ — Implementation** — execute subtasks in order. After each: review, integrate, update journal milestones and backlog. New findings during implementation either open new subtasks or fold into existing ones.

## Milestones

- 2026-05-02: JIRA FP-43579 created. Pre-task prototype investigation completed (heatmap renderer + cheat signature analysis on 6 sample players). Initial WebAdmin scaffolding written, then reverted — restart with proper architecture. KB task opened. Requirements doc drafted — v1 scope, future phases, open hypotheses captured. LureKing identified as primary threat (Pattern A), notes captured in [artifacts/lureking-notes.md](artifacts/lureking-notes.md).
- 2026-05-03: Phase 2 (architecture) closed. [artifacts/architecture.md](artifacts/architecture.md) committed — covers stack (Vue 3 + TS + Vite, no UI kit), Area `Anticheat` with `GameSessionAnalysisController`, 3 AJAX endpoints, DAL variant B for `GetPlayerScreens`, component tree (`ScreenshotStrip` + `HeatmapView` + `CalibrationPanel`), localStorage schema (`anticheat:gameSessionAnalysis:monitorCalibrations`, LRU 100), Kendo CSS-class strategy + jQuery-bridge for Dropdown. RES-001 verified by working scaffold spike: 62 KB main.js, 0.4 KB CSS, admin chrome wraps Vue island cleanly, `_ViewStart.cshtml` gotcha for Areas documented. Scaffold files committed in WebAdmin (`Components/AntiCheatTool/`, `Areas/Anticheat/`, `Scripts/vue/anti-cheat/`).
- 2026-05-03: RES-002 closed (Phase 2 fully done). Canonical UI geometry measured at runtime in Unity Editor play mode via `uloop` CLI (not prefab YAML — runtime overrides via code). Host: `HUD_UI` Canvas (ScreenSpaceOverlay, 1920×1080 ref, ScaleWithScreenSize + Expand). Buttons: KEEP=PriorityButton (canvas X 980-1230), RELEASE=Button (canvas X 690-940), both Y 92-154. Catch panel: 610-1310 × 18-408. Values written to `Components/AntiCheatTool/src/calibration/uiGeometry.ts`. Verified against 7 real-world investigation samples with two complementary metrics: (a) `% TakeClicks in KEEP-rect` catches button-targeting bots (LureKing 99-100% vs all others ≤17%); (b) `centroid distance to W/2 H/2` across popular resolutions catches window-center bots (Pattern B detected even on 6-click sparse data via centroid stability). Honest 4K player (Jangalor) correctly identified as not-suspicious. Multi-cluster case (adidan) revealed limitation of single-centroid analysis — Phase 4 anomaly scoring must do per-cluster decomposition (DBSCAN), and v1 tool's primary value is **visual moderator inspection** that catches multi-cluster patterns directly. Verification script at `artifacts/verify_lureking_runtime_geom.py`. `artifacts/ui-geometry-calibration.md` marked superseded.
