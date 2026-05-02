# Backlog — FP-43579 AntiCheat Game Session Analysis

## Task Workflow

Phase-level checkboxes; detailed phase content lives in [journal.md → Plan](journal.md#plan).

- [x] Open KB task, link JIRA
- [x] Copy prototype heatmap renderer to [artifacts/heatmap_gen.py](artifacts/heatmap_gen.py)
- [x] Revert pre-task WebAdmin scaffolding (controller / model / view / DAL Find methods / link / csproj)
- [x] Phase 1 — Requirements doc → [artifacts/requirements.md](artifacts/requirements.md)
- [ ] Phase 2 — Architecture doc → `artifacts/architecture.md`
- [ ] Phase 3 — Subtask decomposition (DAT / BCK / BLD / FRT / DOC / TST)
- [ ] Phase 4+ — Implementation by subtask, vertical-slice approach

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
