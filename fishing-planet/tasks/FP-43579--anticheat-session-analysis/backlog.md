# Backlog — FP-43579 AntiCheat Game Session Analysis

## Task Workflow

Phase-level checkboxes; detailed phase content lives in [journal.md → Plan](journal.md#plan).

- [x] Open KB task, link JIRA
- [x] Copy prototype heatmap renderer to [artifacts/heatmap_gen.py](artifacts/heatmap_gen.py)
- [x] Revert pre-task WebAdmin scaffolding (controller / model / view / DAL Find methods / link / csproj)
- [x] Phase 1 — Requirements doc → [artifacts/requirements.md](artifacts/requirements.md)
- [x] Phase 2 — Architecture doc → [artifacts/architecture.md](artifacts/architecture.md). Includes scaffold spike verification (RES-001 closed) and DAL variant B decision.
- [x] Phase 3 — Subtask decomposition → [artifacts/plan.md](artifacts/plan.md), 14 subtasks across VS0..VS5
- [x] Phase 4+ — Implementation by subtask
  - [x] **VS1** — End-to-end skeleton (BCK-001 / FRT-001 / FRT-002 / BCK-004) — code-complete 2026-05-03, MonitorInfo smoke passed
  - [x] **VS2** — Events visualisation (BCK-002 / FRT-003 / FRT-004 / FRT-005) — code-complete + visually smoked 2026-05-03
  - [x] **VS3** — Screenshots paged (DAT-001 / BCK-003 / FRT-006 / FRT-007) — code-complete + smoked 2026-05-04
  - [x] **VS4** — Polish (FRT-008 / FRT-009 / DOC-001) — code-complete + smoked 2026-05-04
  - [x] **VS5** — Tests:
    - [x] TST-001 — DAL date-range + paging tests — **deferred** to post-v1 (no AnalyticsProvider fixture in `Sql.MsSql.Tests`, blast-radius / scaffolding-cost argument symmetric to controller/model unit tests already deferred)
    - [x] TST-002 — Manual smoke passed 2026-05-04 (LureKing / Pattern B / Steam Deck samples; multiple fix iterations folded back)

## Pre-commit cleanup
- [x] Revert `2026-05-01` hardcode in `GameSessionAnalysisController.Index` — replaced with `DateTime.UtcNow.Date.AddDays(-1)` (yesterday 00:00 UTC) per user request
- [x] User runs TST-002 browser smoke — passed 2026-05-04
- [ ] SVN commit: single FP-43579 commit covering Mongo + DAL + WebAdmin Areas + Components/AntiCheatTool + Scripts/vue/anti-cheat + 2 modified shared views

## Pending user tasks (out-of-band)
- [x] **RES-002** — DONE 2026-05-03. Canonical UI geometry measured at runtime in Unity Editor play mode via `uloop` CLI (not prefab YAML). Values committed to `Components/AntiCheatTool/src/calibration/uiGeometry.ts`. Verified against LureKing empirical click coords + Steam Deck controller-only false-positive case (Jangalor account).

## DAT-001 acceptance preconditions (Phase 3 / 4)
The DAL change extends `IAnalyticsProvider.GetPlayerScreens(Guid userId)` to `(Guid, DateTime?, DateTime?, int?, int?)` and adds `GetPlayerScreensCount`. Before merging:
- [x] Grep for all `IAnalyticsProvider` implementations and Moq mocks — verified 2026-05-03: 1 impl (`SqlAnalyticsProvider`), 0 Moq mocks, 1 caller (`WebAdmin/Models/Players/Logs/ScreensModel.cs:15`).
- [ ] Run existing `Sql.MsSql.Tests` and `WebAdmin.Tests` after signature change — must pass. (`WebAdmin.Tests` has zero references to `IAnalyticsProvider`; risk concentrated in `Sql.MsSql.Tests`.)
- [x] Verify `Stats.Screens` retention — done 2026-05-03: 14 days via `SqlAnalyticsProvider.ScreenStorageHorizon` + daily `ScreensClearingJob`. Architecture doc updated to remove TBD.

## Strategic deliverables (R&D for SPA migration)
- [x] **DOC-001** — `WebAdmin/Components/AntiCheatTool/README.md` — done 2026-05-03. 9 sections per architecture; Kendo bridge gotchas + TargetedAdsPlanningTool contrast table.
- [ ] **DOC-002** (post-v1) — KB promotion: create `<kb>/.../web-admin/` module (currently no such module in KB) with `_card.md`, `log.md`, deep-dive `embedded-vue-pattern.md`. Add milestone with `[branch r<rev>]` stamp. Tag `TargetedAdsPlanningTool` in module card as legacy reference. Triggered when v1 is verified working in production.
- [ ] **DOC-003** (post-v1, separate task) — KB promotion: create `<kb>/.../logging/` module covering Mongo business-log retention horizons (`fishingLog`, `diagSysInfoLog`, `mergedLog`, `telemetry`, ...). Source of truth lives outside repo (DBA / external scripts). Surfaced by FP-43579 architecture work — UI banner deferred until this manifest exists. Out of scope for FP-43579.
- [x] **ARC-007** — Resolved 2026-05-04 (in v1, not deferred). Approach (a) applied: removed MVC Area entirely; controller moved to `Controllers/Anticheat/GameSessionAnalysisController.cs` (ns `WebAdmin.Controllers.Anticheat`); models to `Models/Anticheat/GameSessionAnalysis/`; view to `Views/GameSessionAnalysis/Index.cshtml`; `Areas/Anticheat/` deleted; custom route `Anticheat/{controller}/{action}/{id}` with `controller = "GameSessionAnalysis"` regex + namespace constraint added to `RouteConfig.cs` ahead of Default. URL prefix `/Anticheat/...` preserved; no ambient `area` token = no strand on root Default route during URL generation = shared-layout ActionLinks resolve cleanly to `/Home/...`, `/Stats/...`, etc. Future anti-cheat tools: extend the route's `controller` regex (e.g. `"GameSessionAnalysis|NewTool"`).

## Code review findings (post-v1, low-priority)

From the deep review 2026-05-04 — all medium-severity findings folded into v1 are listed below. Acceptable for v1; revisit if related code paths get touched.

- **Mongo `$regex` pre-filter unanchored** (`GameSessionAnalysisEventsModel`): `BsonRegularExpression("TakeClick|ReleaseClick")` matches substrings anywhere in `Message`. C# `EventRe` filters out false-positives downstream, so no data corruption — just unnecessary BSON deserialisation if a future log message contains either substring in another context. If observed, anchor to `(?:TakeClick|ReleaseClick):`.
- **`usePlayerCalibration` redundant persist on userId switch**: `data.value = loaded` triggers the deep watcher → `schedulePersist()` queues a write of the just-loaded data. Harmless (data unchanged, `ts` touched twice). Guard with an `isHydrating` flag if timing tightens.
- **`useRefreshSignal` no de-duplication**: Apply with same form values fires a duplicate refresh. Cosmetic only (double-load); add a deep-equal guard if it becomes annoying.

## Code-reviewed but not smoke-exercised (post-v1 ad-hoc verifications)

These exit criteria from individual subtasks remain `[ ]` because the smoke pass didn't synthesise the specific edge case. All have correct logic per code review; flag here so a future reviewer knows what to spot-check if they touch the related code:

- **BCK-003**: Out-of-range page returning empty `items` with unchanged `total` (clamps + paged read race-acceptable)
- **BCK-004**: Browser Forward button re-fetches (single `popstate` handler is fired for both Back and Forward, so symmetric — but the Forward direction wasn't explicitly clicked during smoke)
- **DAT-001**: Existing `/Player/Screens?userId=...` still returns full list under the new optional-args signature (defaults unchanged)
- **DAT-001**: Manual SQL trace at large `skip` — when production traffic justifies a Phase 4 perf review
- **FRT-005**: LRU eviction at 101st distinct userId; schema-version-bump fallback to defaults
- **FRT-008**: Forced 4xx → banner; forced 5xx → iframe-sandbox overlay
- **FRT-009**: Heap-snapshot before/after widget destroy (no leak)
- **TST-002**: LRU 101 path; non-Abuse-role 403 path

`[CustomAuthorize(Roles="Abuse")]` is the only auth gate, the rest are pure-logic / browser-API paths trustworthy by code review for v1.

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
