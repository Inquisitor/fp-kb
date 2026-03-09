---
name: kb-finalize-milestone
description: >
  Finalize a KB task milestone by updating all satellite files.
  Use when a milestone is committed, task phase is completed, or user says
  "фиксировать", "зафиксируем", "закоммитил, давай фиксировать",
  "обновить статус", "готово, запиши".
argument-hint: "[task-slug, e.g. FP-41746--matchmaking]"
---

# Finalize Milestone

You are updating all KB satellite files for task `$ARGUMENTS` after a milestone commit.

## Steps

### 1. Read the task journal
- Path: `D:\kb\fishing-planet\tasks\$ARGUMENTS\journal.md`
- Understand: what was just completed (Status section), which modules were affected

### 2. Update journal Status
- Confirm `## Status` has: what's done, **what's next**, blockers
- If task is fully complete: set `status: completed` in YAML frontmatter
- Append milestone to `## Milestones` section

### 3. Update module decision log
- Path: `D:\kb\fishing-planet\server\modules\<module>\log.md`
- Append decisions made during this milestone (rationale + lessons learned)
- log.md is append-only — never delete entries
- Skip if no architectural/design decisions were made

### 4. Update module backlog
- Read task backlog: `D:\kb\fishing-planet\tasks\$ARGUMENTS\backlog.md`
- Read module backlog: `D:\kb\fishing-planet\server\modules\<module>\backlog.md`
- Mark completed items as done
- If task is closing: bubble deferred items up to module backlog

### 5. Update module card
- Path: `D:\kb\fishing-planet\server\modules\<module>\_card.md`
- Update `## Related Tasks` section with milestone summary

### 6. Update alignment plan (if exists)
- Check for plan files in `D:\kb\fishing-planet\tasks\$ARGUMENTS\artifacts\`
- Extract detail bodies of DONE items into `artifacts/archived/subtasks/<jira-task-id>--<subtask-id>--<slug>.md` (e.g. `FP-41746--TRM-003--db-rename.md`)
- **Use `git-extract` skill** for the extraction — 2-commit technique preserves `git blame` history
- Collapse DONE items: detail section → one-liner in Summary table with `[details](archived/subtasks/<jira-task-id>--<subtask-id>--<slug>.md)` link
- After extraction: verify all cross-references are correct in both the plan (source) and each extracted subtask file (links back to plan, links to related subtasks, links to design docs)
- Update phase/subtask statuses to reflect completion
- Only active (TODO/partial) items keep full detail sections below the Summary

### 7. Update _index.md (only on full task close)
- If `status: completed`: remove task from `D:\kb\_index.md` active tasks table

## Discipline
- Every step in this skill is **mandatory**, not advisory.
- Do NOT skip steps because they seem "obvious" or because you think another instruction covers them.
- If a step says "Use skill X" — invoke that skill. If a sub-skill says "Use tool Y" — use tool Y.
- A skill is a checklist: execute every item in order.

## Rules
- All content in English
- Do NOT duplicate information — each file has its own purpose
- Show the user what you're updating before writing
