# Review: FP-41962 — Improve logging on critical load for line and leader
> Status: waiting-for-release \
> Executor: Yuriy Burda \
> Branch: LBM @ r15780, merged to KNW @ r15781 \
> JIRA: https://fishingplanet.atlassian.net/browse/FP-41962

## Summary

A player reported that line id=1178 (Braid 0.2mm) keeps breaking while logs show the critical zone load lasting less than a second. QA could not reproduce. The commit improves logging by tracking the total wall-clock time in the critical zone (instead of the last tick delta) and adding line/leader type and line length to log messages.

### Files modified (3)

- `Photon/src-server/GameModel/LineBreaker.cs`
- `Photon/src-server/GameModel/LeaderBreaker.cs`
- `Photon/src-server/Loadbalancing/LoadBalancing/GameLogic/GameProcessor.cs`

### What changed

1. Added field `DateTime? criticalWearStartTime` in LineBreaker/LeaderBreaker — records moment critical wear begins.
2. `UpdateTime()` sets `criticalWearStartTime ??= DT.Helper.UtcNow` on first call.
3. `TryBreakLine()` / `TryBreakLeader()` — `BreakTime` now = `UtcNow - criticalWearStartTime` (total time) instead of `timeDelta` (last tick only).
4. `Reset()` clears `criticalWearStartTime = null`.
5. `GameProcessor.cs` log messages now include line/leader type and line length.

## Checklist

- [x] Does it affect game mechanics? **NO** — `BreakTime` is used exclusively for logging (GameProcessor.cs:2416, :2428)
- [x] Fix correctness — Before: `BreakTime = timeDelta` (last tick delta, ~tens of ms, meaningless). After: `BreakTime = UtcNow - criticalWearStartTime` (total wall-clock time from first critical zone entry). **Correct.**
- [x] Lifecycle of `criticalWearStartTime` — `CoolDown()` guards with `if (value <= 0) return;`, so `UpdateTime()` is never called during cooldown without prior damage. `criticalWearStartTime` is always set during first damage tick. Reset on break (`value >= 1`) and full cooldown (`value < 0`). **Correct.**
- [x] `UpdateTime()` call pattern — `GameProcessor` (lines 2392-2412) guarantees exactly one call per fight tick (either `TryBreakLine` or `CoolDown`). The `priorTime`-based delta handles transitions. **Correct.**

## Notes

### 1. Double `DT.Helper.UtcNow` call in `UpdateTime()` (non-critical)

```csharp
criticalWearStartTime ??= DT.Helper.UtcNow;  // call 1
var now = DT.Helper.UtcNow;                    // call 2
```

Could be simplified to:
```csharp
var now = DT.Helper.UtcNow;
criticalWearStartTime ??= now;
```

Difference is negligible (nanoseconds), but cleaner.

### 2. `Pause()` / `Resume()` — dead code (pre-existing)

Both `LineBreaker` and `LeaderBreaker` have `Pause()` / `Resume()` with `pauseStartTime` field, never called from anywhere. Pre-existing dead code, unrelated to this commit. Worth noting for future cleanup.

### 3. `BreakTime` includes cooldown periods (by design)

If the line partially cooled down and got overloaded again without full `Reset`, `BreakTime` shows total wall-clock time from first critical entry — including cooldown. Intentional and useful for diagnostics.
