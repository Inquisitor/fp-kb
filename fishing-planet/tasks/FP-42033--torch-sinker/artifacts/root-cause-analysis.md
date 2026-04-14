# FP-42033: Root Cause Analysis

**File:** `Photon/src-server/Loadbalancing/LoadBalancing/GameLogic/GameProcessor.cs`

When the player presses B (Cut) with a torch rod setup (saltwater bottom + torch), the torch and sinker are not lost. The entire terminal tackle should be destroyed.

## Call flow (current)

```
HandleBreakLine
  +-- if (leader != null)
       +-- BreakLeaderLoseTackle(Cut)
            +-- GetTackleToRemoveWhenLineBreaks(breakLeader: true)
                 +-- Excludes Sinker, Chum, Torch (for non-rig leaders)
     else
       +-- BreakLineLoseTackle(Cut)
            +-- GetTackleToRemoveWhenLineBreaks(breakLeader: false)
                 +-- Removes ALL tackle
```

With a torch setup `leader != null`, so `BreakLeaderLoseTackle` is called, which passes `breakLeader: true` to `GetTackleToRemoveWhenLineBreaks`. For non-rig leaders, Sinker/Chum/Torch are **excluded** from the removal list.

The issue is broader than just the B key: whenever `BreakLineLoseTackle` is called while a leader exists, the leader item is removed from inventory via `LoseItem`, but the `leader` field remains non-null (pointing to a removed object), and chum lifecycle methods (`RemoveExpiredChum`, `ConsumeChum`, `CheckRodIsUnequipped`) are never executed.

## Solution outline (4 steps)

1. **Extract `CleanupLeader()`** — nulls leader, calls `RemoveExpiredChum(unequipRod: true)`, `ConsumeChum()`, `CheckRodIsUnequipped()`. Null-safe (no-op when leader is null).
2. **Use in `BreakLeaderLoseTackle`** — replace inline cleanup with `CleanupLeader()`. Durability wear (`ApplyWear`) stays inline before `LoseItem`.
3. **Call from `BreakLineLoseTackle`** — after `DoInventoryTransactionEvent` block, before final resets. No durability wear in this path (line simply destroys all tackle).
4. **Simplify `HandleBreakLine`** — always call `BreakLineLoseTackle` when `line != null`; defensive fallback + error log when `line` is null but `leader` exists.

## Safety guarantees

- `RemoveItem` has guard `if (!this.Contains(item)) return;` — repeated `LoseItem` calls are safe.
- `CleanupLeader` starts with `if (leader == null) return;` — no-op when no leader present.
- Chum methods safe on repeat: `RemoveExpiredChum` only processes expired chums; `ConsumeChum` checks `rod.ChumConsumed` flag.
- Durability wear order preserved in `BreakLeaderLoseTackle` (before `LoseItem`).

## Affected call sites of `BreakLineLoseTackle`

| Caller                    | Reason | Context                                                            |
|---------------------------|--------|--------------------------------------------------------------------|
| `ApplyWearToLine()`       | Wear   | Line durability reached 0                                          |
| `HandleFightFish()`       | Fight  | Line break during fight (critical wear)                            |
| `HandleBreakLine()`       | Cut    | B key press                                                        |
| `CheckLineBreaksOnCast()` | Cast   | Line break on cast                                                 |
| `HandleFightFish()` (×2)  | Fight  | Fish cuts line on slack / tension (fallback when `leader == null`) |

## Testing plan

- Torch setup (saltwater bottom + torch) + B: torch and sinker must be lost
- Regular setup with leader + B: all terminal tackle is lost
- Regular setup without leader + B: behavior unchanged
- Leader break during fight: behavior unchanged (Sinker/Torch stay for non-rig leaders)
- Line break during fight with leader present: leader is now properly cleaned up
