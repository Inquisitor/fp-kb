---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15807
jira: https://fishingplanet.atlassian.net/browse/FP-41754
---

# Review: FP-41754 — Tracking the depth of fish generation

## Summary

A mission requires `HookDepth: 48` — fish must be hooked at 48m or deeper. Fish generates at correct depth (-60m), but while the rod is on a stand the fish drags the bait upward for ~45 seconds. By the time the player picks up the rod and hooks the fish, depth is only 42m — mission fails despite proper generation depth.

Fix: record depth at fish generation time (`GenerationDepth`) separately from hook time (`HookDepth`), and add new mission condition fields `MinGenerationDepth` / `MaxGenerationDepth`.

### Files modified (4)

- `Shared/ObjectModel/Fish/Fish.cs`
- `Shared/ObjectModel/Mission/ConditionsGame/FishConditions.cs`
- `Shared/ObjectModel/Mission/InteractionsGame/ReleaseFishFromCageInteraction.cs`
- `Photon/src-server/Loadbalancing/LoadBalancing/GameLogic/GameProcessor.cs`

### What changed

1. `Fish.cs` — added `float GenerationDepth` property with `[NoClone]`, XML doc comment.
2. `FishConditions.cs` — added `MinGenerationDepth` / `MaxGenerationDepth` to `IFishCondition` interface and `BaseFishCondition` class. Added validation in `MatchFishPredicate()`.
3. `ReleaseFishFromCageInteraction.cs` — added same properties for cage-release mission conditions.
4. `GameProcessor.cs` — set `fish.GenerationDepth = -terminalTacklePosition.Y` at fish attack generation (line 3482). Copied in `CopyFishingCycleProperties()`.

### SQL migration (from Jira comment, not committed)

```sql
UPDATE mt SET ConfigJson = REPLACE(mt.ConfigJson, 'HookDepth', 'MinGenerationDepth')
FROM MissionTasks mt WHERE mt.ConfigJson LIKE '%HookDepth%'

UPDATE mt SET ConfigJson = REPLACE(mt.ConfigJson, 'MaxHookDepth', 'MaxGenerationDepth')
FROM MissionTasks mt WHERE mt.ConfigJson LIKE '%MaxHookDepth%'
```

Note from author: after using new fields, missions cannot be synced to Norwegian servers without merging changes to the Norwegian branch first.

## Checklist

- [x] Correctness of `GenerationDepth` assignment — set at fish attack start (before hook), captures the right moment. **Correct.**
- [x] Serialization — `Fish` uses `MemberSerialization.OptOut`, no `[JsonIgnore]` on `GenerationDepth` — serialized to JSON (cage storage). **Correct.**
- [x] `CopyFishingCycleProperties()` — copies `GenerationDepth`. **Correct.**
- [x] `MatchFishPredicate()` — validation logic follows existing `HookDepth`/`MaxHookDepth` pattern. **Correct.**
- [ ] Tests — **none**, but no existing tests for `MatchFishPredicate()` or any `FishCondition` at all. Pre-existing gap, not specific to this commit.

## Notes

### 1. Interface setters (medium)

`IFishCondition` declares `MinGenerationDepth` and `MaxGenerationDepth` with `{ get; set; }`, but existing analogues `HookDepth` / `MaxHookDepth` are `{ get; }` only. `MatchFishPredicate()` only reads these properties — setters are unnecessary on the interface.

### 2. Naming inconsistency (low)

Existing pattern: `HookDepth` (implicit min) + `MaxHookDepth`. New pattern: `MinGenerationDepth` + `MaxGenerationDepth` (explicit min/max). The new naming is clearer, but inconsistent with the established convention. Team decision.

### 3. No tests (low — pre-existing gap)

No unit tests for `MatchFishPredicate()` or any `FishCondition` exist in the codebase at all. Not specific to this commit — the entire mission conditions area has zero test coverage. Worth addressing separately.
