---
task: FP-43400
title: "Fish.Behaviour: Stamina loss multiplier while using rod pod"
executor: Yuriy Burda
status: resolved
started: 2026-04-15
resolved: 2026-04-15
---

## Summary

Anti-exploit measure: configurable multiplier for fish stamina loss when rod is on a rod pod stand.
New global variable `Fishing.StaminaLoseMultiplierOnRodStand` (default 1.0 = no change).
Bonus: verbose logging cleanup in `FishTireModel` (Pause/Resume logs gated behind `DebugGameLogic` flag).

## Scope

### Server commits (LBM)
| Rev    | Description                                                                    |
|--------|--------------------------------------------------------------------------------|
| r16010 | Add `staminaLoseMultiplierOnRodStand` to `FishTireModel`, wire in GameProcessor, SQL patch, 5 unit tests, verbose logging cleanup |

### Merges
| Rev    | Description     |
|--------|-----------------|
| r16011 | MFT merge       |

## Findings

### F-1: SQL patch missing trailing newline [Skipped]
`LBM.M.2026.04.15-040 [GlobalVariables].sql` ends without newline. Not worth a separate commit.

### F-2: Verbose logging bundled with feature [Approved]
Pause/Resume log suppression + periodic stamina logging added alongside the multiplier. Discussed — intentional spam cleanup, good improvement.

### F-3: `staminaLoseMultiplierOnRodStand` constructor param is `float?` but never receives null [Info]
All callsites pass non-null values. Nullable matches sibling params pattern. Correctly handled via `?? 1f`.

## Verdict

Approved, no blocking findings.
