---
status: in-progress
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-41746
related: FP-41833
---
# FP-41746: Matchmaking Alignment

## Status
Phase 8 in progress: TRM-003 (full DB rename `GroupId` → `BracketId`) + DCD-004 (IsRated) + DCD-005 (IsCanceled).
Task 0 (diagnostic queries) done — no blockers, findings in design doc. Executing Task 2 (SP files).
Next: Task 2 (SP files) → Task 3 (C# TRM-003) → Task 4 (DCD-004) → Task 1 (SQL patch) → Task 5 (DCD-005).
- [Design](artifacts/TRM-003-DB-Rename-Design.md) | [Implementation Plan](artifacts/TRM-003-Implementation-Plan.md) | [Alignment Plan](artifacts/Matchmaking-Alignment-Plan.md)

## Summary
JIRA task was originally "add 2 new parameters for competitions JSON" (`MaxSize`, `MaxGroupCount`). Investigation revealed misalignment between GDD, TDD and code — outdated terminology, dead code, untested edge cases. Scope expanded into a full alignment effort across documentation, terminology, algorithm, and test coverage.

Related task FP-41833 ("matchmaking algorithm rework: cases with 2 new parameters") covers test infrastructure and test cases.

## Lessons Learned
- When renaming: search by **type consumers**, not property names — generic names like `.Groups` give false positives across unrelated code
- Must search ALL solutions (LoadBalancing, WebAdmin, AsyncProcessor, Twitch, WebHooks) — they build independently, CI catches what grep misses

## Milestones
- 2026-02-08: Started investigating "2 parameters" task, discovered GDD/TDD/code misalignment
- 2026-02-16: Created [Alignment Plan](artifacts/Matchmaking-Alignment-Plan.md) (8 phases, 30+ items)
- 2026-02-17: Phase 1 bug fixes committed (r15797-r15800), started test infrastructure
- 2026-02-18: Created [Terminology-Rename-Plan](artifacts/Terminology-Rename-Plan.md) — rename turned out complex (2-step process, DAL blocker for DTOs)
- 2026-02-21: TRM-002 rename committed (r15812). Missed WebAdmin model — caught only by CI
- 2026-02-22: Deferred DB renames (TRM-003) and Phase 5 (cosmetic). Dead code cleanup committed (r15818-r15819). Pivoted to Phase 6
- 2026-02-23: Created [Group Budget Design](artifacts/Matchmaking-Group-Budget-Design.md) — FFS algorithm, 3 review passes, approved
- 2026-02-25: Phase 6 test infrastructure and Steps 1-6 committed (r15826-r15847)
- 2026-03-02: FFS algorithm implemented (r15864-r15866). Created [ideal GDD](artifacts/MatchMaking-System-1st-Iteration-GDD-ideal.md) + [editing instructions](artifacts/GDD-Editing-Instructions.md) for designer
- 2026-03-04: Extracted common test helpers into shared infrastructure (r15883). Full FFS test coverage committed (r15884)
- 2026-03-05: Migrated task to KB, reorganized artifacts into active/archived structure
- 2026-03-06: Refactored Alignment Plan — Summary to top, DONE items extracted to archived/subtasks/
- 2026-03-08: TRM-003 design change — full DB rename instead of DAL mapper enhancement. DCD-004/DCD-005 added to scope. [Design](artifacts/TRM-003-DB-Rename-Design.md) + [Implementation Plan](artifacts/TRM-003-Implementation-Plan.md) created
