# Decision Log — KB

## 2026-03-06
- Expert panel review of FP-41746 task structure (PM, Senior Dev, Tech Writer, LLM Specialist, AI KB Specialist)
- Alignment Plan refactoring: DONE items → one-liner + `archived/subtasks/<ID>--<slug>.md`; Summary section moves to top; plan stays compact (~200 lines)
- Task-level backlog.md stays: convenient for immediate TODOs and deferred items during active work; bubble up to module backlog on task close
- Module log.md scoped to decisions with rationale + lessons learned only (no milestones, no status updates)
- "Next Action" problem solved by compact plan + journal TODO section (no separate mechanism needed)
- YAML frontmatter replaces blockquote metadata in journals, reviews, cards
- _index.md stays navigation-only (no completion percentages — avoids manual sync overhead)
- Lessons learned are a type of decision — belong in module log.md
- Task lifecycle workflow defined: JIRA → KB validate → investigate → plan → execute → close. Journal `## Status` always current. Subtask IDs KB-internal only
- Journal structure: frontmatter → Status → Summary → Plan → Milestones (top-to-bottom, most actionable first)
- Multi-area subtasks track per-area status (Code/GDD/TDD independently)
- On task reopen: archive plan, create new with link to archived
- Release tracking: separate file mapping tasks to releases (backlog item, not yet designed)
- Skill for task workflow: defer until validated on 1-2 fresh tasks

## 2026-03-05
- Created KB system at D:\KB\ based on approved design (see docs/plans/2026-03-05-kb-system-design.md)
- Expert panel review: 5 agents (DevOps, PM, Solo Dev, Info Architect, Security)
