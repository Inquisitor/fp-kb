# Backlog — FP-43579 AntiCheat Game Session Analysis

## Task Workflow

Phase-level checkboxes; detailed phase content lives in [journal.md → Plan](journal.md#plan).

- [x] Open KB task, link JIRA
- [x] Copy prototype heatmap renderer to [artifacts/heatmap_gen.py](artifacts/heatmap_gen.py)
- [x] Revert pre-task WebAdmin scaffolding (controller / model / view / DAL Find methods / link / csproj)
- [x] Phase 1 — Requirements doc → [artifacts/requirements.md](artifacts/requirements.md)
- [x] Phase 2 — Architecture doc → [artifacts/architecture.md](artifacts/architecture.md). Includes scaffold spike verification (RES-001 closed) and DAL variant B decision.
- [x] Phase 3 — Subtask decomposition → [artifacts/plan.md](artifacts/plan.md), 14 subtasks across VS0..VS5
- [ ] Phase 4+ — Implementation by subtask, starting at VS1 (BCK-001 / FRT-001 / FRT-002)

## Pending user tasks (out-of-band)
- [x] **RES-002** — DONE 2026-05-03. Canonical UI geometry measured at runtime in Unity Editor play mode via `uloop` CLI (not prefab YAML). Values committed to `Components/AntiCheatTool/src/calibration/uiGeometry.ts`. Verified against LureKing empirical click coords + Steam Deck controller-only false-positive case (Jangalor account).

## DAT-001 acceptance preconditions (Phase 3 / 4)
The DAL change extends `IAnalyticsProvider.GetPlayerScreens(Guid userId)` to `(Guid, DateTime?, DateTime?, int?, int?)` and adds `GetPlayerScreensCount`. Before merging:
- [x] Grep for all `IAnalyticsProvider` implementations and Moq mocks — verified 2026-05-03: 1 impl (`SqlAnalyticsProvider`), 0 Moq mocks, 1 caller (`WebAdmin/Models/Players/Logs/ScreensModel.cs:15`).
- [ ] Run existing `Sql.MsSql.Tests` and `WebAdmin.Tests` after signature change — must pass. (`WebAdmin.Tests` has zero references to `IAnalyticsProvider`; risk concentrated in `Sql.MsSql.Tests`.)
- [x] Verify `Stats.Screens` retention — done 2026-05-03: 14 days via `SqlAnalyticsProvider.ScreenStorageHorizon` + daily `ScreensClearingJob`. Architecture doc updated to remove TBD.

## Strategic deliverables (R&D for SPA migration)
- [ ] **DOC-001** — `WebAdmin/Components/AntiCheatTool/README.md` with embed pattern, build commands, dev workflow, Kendo bridge gotchas, explicit contrast with `TargetedAdsPlanningTool` setup. Created as part of Phase 4+, refined as patterns solidify.
- [ ] **DOC-002** (post-v1) — KB promotion: create `<kb>/.../web-admin/` module (currently no such module in KB) with `_card.md`, `log.md`, deep-dive `embedded-vue-pattern.md`. Add milestone with `[branch r<rev>]` stamp. Tag `TargetedAdsPlanningTool` in module card as legacy reference. Triggered when v1 is verified working in production.
- [ ] **DOC-003** (post-v1, separate task) — KB promotion: create `<kb>/.../logging/` module covering Mongo business-log retention horizons (`fishingLog`, `diagSysInfoLog`, `mergedLog`, `telemetry`, ...). Source of truth lives outside repo (DBA / external scripts). Surfaced by FP-43579 architecture work — UI banner deferred until this manifest exists. Out of scope for FP-43579.

## Captured investigation findings (index)
- Pattern A — LureKing → [artifacts/lureking-notes.md](artifacts/lureking-notes.md). Sample accounts: LUYA168, rrsrewr
- Pattern B — window-center cluster → [journal.md → Background](journal.md#background--investigation-findings). Sample accounts: W_CHUANQI, Niepan.LD, DFT_KennPF, adidan
- Catch panel UI geometry + recalibration → [artifacts/ui-geometry-calibration.md](artifacts/ui-geometry-calibration.md)
- `CursorLockMode.Locked` cursor behaviour (controller-only experiment, attribution open) → [journal.md → Background](journal.md#background--investigation-findings)
- Mouse coordinate format (integer pixel space, `##.000` suffix is formatting) → [journal.md → Background](journal.md#background--investigation-findings)

## Out-of-scope (for v1)
- Cast position visualization (data not available in `fishingLog`; needs separate research)
- Cross-player aggregations (top-N suspect list) — future tool
- Persistent verdict storage (`CheatAnalysis` table) — v1 is stateless / recompute-on-view
- Mobile / console client support — separate `CatchedFishInfoMobile.prefab` likely has different UI geometry
- Inter-event timing analysis — promising signal, not in v1
- Auto-flagging / mass scan — this tool is per-player; mass scan is a separate epic
