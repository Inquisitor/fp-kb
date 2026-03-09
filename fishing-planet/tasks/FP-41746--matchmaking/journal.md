---
status: in-progress
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-41746
related: FP-41833
---
# FP-41746: Matchmaking Alignment

## Status
Phase 8 complete: TRM-003 + DCD-004 + DCD-005 — committed (r15898).
Next: documentation phases — Phase 7 (GDD/TDD cleanup, 11 items), Phase 6 docs (MaxGroupCount/MaxGroupSize), Phase 2 (TRM-001 TDD terminology).
- [Alignment Plan](artifacts/Matchmaking-Alignment-Plan.md)

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
- 2026-03-08: Phase 8 implementation: SQL patch `LBM.M.2026.03.08-028`, 21 SP files updated, 20+ C# files changed across all layers. Builds successfully
- 2026-03-09: Phase 8 finalized: patch upgraded to `028-v2` (added ConfigJson dead param removal), tests passed (114/121 tournament, 5 pre-existing failures), deep code review passed. Committed
