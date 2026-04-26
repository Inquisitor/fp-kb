---
status: resolved
executor: Yuriy Burda
branch: LBM20251201 @ r15976, merged to MFT20260325 @ r15983
jira: https://fishingplanet.atlassian.net/browse/FP-43265
---

# Review: FP-43265 — [Daily Missions][Localization] Fish weight in a task changes when using the Italian language

## Summary

When client switches to Italian, daily-mission task text shows a different fish-weight value (and length hints for line/leader) than in other languages while the JSON task definition is unchanged. Server-side `MeasuringSystemManager.ChangeMeasuringSystem(int languageId)` had no `case 8` (Italian); the switch fell through silently and `_currentMeasuringSystem` stayed at its field-initializer value `0 = MeasuringSystem.Imperial` — so weight/length conversions ran kg→lb (×2.2046) and cm→inch, suffixes returned `lb`/`inch`/`ft`. The fix adds `case 8: EnglishMetric + CultureInfo("it-IT")`, consistent with peer western-european locales (de-DE, fr-FR, es-ES, nl-NL).

## Scope

- **LBM r15976** — Fix Italian locale missing from server MeasuringSystemManager
  - Adds `case 8` to `ChangeMeasuringSystem(int languageId)` mapping Italian to `MeasuringSystem.EnglishMetric` + `CultureInfo("it-IT")`
- **MFT r15983** — Merge of LBM r15976 (clean apply, `svn:mergeinfo` updated)

## Investigation Journal

- 2026-04-27: User-provided context — triage-file `<kb>/fishing-planet/server/modules/missions/triage-2026-04.md` for active routing; feature is in Test environment, not production. Severity-assessment rule for data-integrity / backfill collapse N/A — fix is purely additive, no findings of that class.
- 2026-04-27: Initial misread of `svn log | grep -A3` output suggested LBM r15987 / MFT r15984 belonged to FP-43265. Re-grepped without context flags — clean output confirmed exactly one commit per branch (LBM r15976 + MFT r15983), JIRA comment is correct.
- 2026-04-27: Branch-copy inheritance verified — MFT base is LBM:15942, fix is at LBM r15976 (> 15942), so explicit merge required (and present at MFT r15983). No inheritance shortcut.
- 2026-04-27: Code-reviewer agent confirmed (a) per-call instantiation of `MeasuringSystemManager` at three call sites — no singleton/threading concern; (b) precise root cause via field-initializer `Imperial` fallthrough; (c) no regression risk for existing cases 1–14 (purely additive label). Agent surfaced one extra pre-existing observation (`TaskLocalizer.Term()` bypasses `_currentCulture`) — added to backlog.
- 2026-04-27: Pre-existing observations routed to new `<kb>/fishing-planet/server/modules/localization/backlog.md` (no module card yet — backlog only).

## Notes (pre-existing observations, not introduced by this commit)

All routed to [`modules/localization/backlog.md`](../../server/modules/localization/backlog.md):

- Switch lacks `default:` clause → silent fallthrough into `Imperial` is the architectural root cause. Fix is symptomatic.
- `case 12` and `case 13` both map to `zh-CN` — possible Simplified/Traditional confusion (related to parent ticket FP-43264).
- `MeasuringSystemManager` has no unit-test coverage.
- `TaskLocalizer.Term()` uses default thread culture rather than `measuring.Format()`; decimal separators in mission text won't follow player locale (found by code-reviewer agent, unrelated to this fix's symptom but adjacent).

## Verdict

**Approve** — LBM r15976 + MFT r15983.

The fix is correct, minimal, and surgical: maps Italian to the same measuring system + culture as peer western-european locales (Italy uses metric, never Imperial). Diff in MFT merge is byte-identical to LBM original; `svn:mergeinfo` updated. Per-call instantiation of the class precludes cross-player state bleed. No regression risk for existing locales.

Pre-existing design and coverage gaps are tracked in `modules/localization/backlog.md`; they do not block this approval.
