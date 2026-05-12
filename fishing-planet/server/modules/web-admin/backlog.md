# WebAdmin — Backlog

Module-level follow-ups. Items bubble up here when a closing task leaves usable findings; sub-modules carve out their own backlogs when introduced.

## Open — low-priority (revisit on touch)

Bubbled from FP-43579 (closed 2026-05-12) deep code review. Tool-specific to `AntiCheatTool` but worth surfacing at the module level until an AntiCheat sub-module is carved out by FP-43424.

- [ ] **Mongo `$regex` pre-filter unanchored** (`GameSessionAnalysisEventsModel`): `BsonRegularExpression("TakeClick|ReleaseClick")` matches substrings anywhere in `Message`. C# downstream filter currently catches false-positives, so no data corruption — just unnecessary BSON deserialisation if a future log message contains either substring in another context. If observed, anchor to `(?:TakeClick|ReleaseClick):`.
- [ ] **`usePlayerCalibration` redundant persist on userId switch**: `data.value = loaded` triggers the deep watcher → `schedulePersist()` queues a write of the just-loaded data. Harmless (data unchanged, `ts` touched twice). Guard with an `isHydrating` flag if timing tightens.
- [ ] **`useRefreshSignal` no de-duplication**: Apply with same form values fires a duplicate refresh. Cosmetic only (double-load); add a deep-equal guard if it becomes annoying.

Origin: FP-43579 backlog → "Code review findings (post-v1, low-priority)" section. Affects only `WebAdmin/Components/AntiCheatTool/`.
