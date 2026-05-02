# LureKing — cheat tool notes

Reference notes on the LureKing (鲁亚王 / 路亚王) cheat for Fishing Planet, gathered from a public Chinese gaming forum post ([source](https://www.96fuzhu.com/thread-24997-1-1.html)) and triangulated against in-house telemetry findings (FP-43579 investigation).

This document is for **detection** purposes only. Specific bypass / evasion technique details are intentionally omitted per KB policy.

## Etymology

`LureKing` reuses Chinese 鲁亚王 / 路亚王 (`luya wang` = "lure king"). Tool advertises itself by this name on the source forum.

## Distribution

- Posted on `96fuzhu.com` (gaming-cheat forum, Chinese)
- Forum thread length and engagement suggest moderate adoption among Chinese-speaking players
- One-time tool style (no clear subscription mechanic in the visible thread)

## Technical model

| Aspect               | What is known                                                                        |
|----------------------|--------------------------------------------------------------------------------------|
| Detection mechanism  | Screen-based (template matching against the Fishing Planet UI), not memory injection |
| Required window mode | Windowed (Steam launch option `-window` documented as required)                      |
| Required privileges  | Administrator                                                                        |
| Activation           | Hotkeys `F2`–`F7` for various automated functions                                    |
| Versioning           | `v4.7.9` (last update April 2026; tool is actively maintained)                       |
| Anti-detection       | None explicitly documented in the visible thread                                     |

The screen-based model + fixed window size requirement is what produces the **stable hardcoded screen coordinates** we observe in our telemetry: when the cheat needs to click "KEEP" or "RELEASE", it sends a synthesized click at coordinates that were calibrated once against a specific window resolution — without dynamic rescaling.

## Detection signals (server-side)

These are signals already actionable from existing telemetry (no client patch needed).

### Strong signals (high confidence)

- **TakeClick / ReleaseClick at identical sub-pixel coordinates across unrelated accounts**.
  Observed pair: `(663, 89)` for KEEP, `(473, 89)` for RELEASE. Two unrelated accounts cannot produce these by chance; the cause is shared cheat-tool calibration.
- **Click concentration ratio ≥ 95% in a 3×3 px window** sustained over 100+ events.
  No human click pattern matches this.

### Soft signals (additive, not standalone)

- Sustained "auto-keep" pattern: TakeClick >> ReleaseClick (indicates auto-take of every catch)
- Reported monitor resolution ≠ detected click-window resolution — informational, not blocking
- Window width derived from cluster geometry not in the standard list (16:9, 16:10, 4:3) — cheat calibrated against a custom-sized window (`-window` with non-default dimensions)

## Functions advertised

From the forum thread, the cheat advertises:

- Auto fishing detection (auto-cast / auto-engage)
- Auto-catch mechanics (auto-reel / auto-keep)
- Fish size detection
- Bait management
- Full-screen monitoring

The detection signals listed above target the auto-catch / auto-keep paths specifically (because those are the only ones currently surfaced in our telemetry via TakeClick / ReleaseClick).

## Gaps in our knowledge

- Exact window dimensions used by LureKing (cluster geometry suggests ~1136 px wide; not yet matched to a known Steam launch preset)
- Whether the cheat tool repositions the cursor or simulates input directly (both are consistent with our observations, but the distinction would matter for cross-checking with `Mouse.current.position` semantics)
- Whether other functions (cast detection, bait management) leave their own observable telemetry signatures — needs separate investigation if Phase 4 anomaly detection wants to extend coverage
