# Decision Log — Matchmaking

## 2026-03-04
- All `AllocateGroupBudget` test cases implemented (Step 9 complete)
- Phase 6 implementation steps 1-9 done

## 2026-03-02
- GDD ideal version created, editing instructions sent to designer (Step 10)

## 2026-02-22
- FFS algorithm chosen over greedy for group budget allocation
- Design doc `Matchmaking-Group-Budget-Design.md` approved after 3 review passes

## 2026-02-10
- Terminology rename: Groups->Buckets, GroupSettings->Brackets, SubGroups->Groups (TRM-002)
- Lesson: search by type consumers, not property names; search ALL solutions (WebAdmin missed initially)

## 2026-01-20
- Root cause ALG-004/005/006: empty groups in Phase B, off-by-one in pull logic
- Phase 1 bug fixes committed (r15797-r15800)
