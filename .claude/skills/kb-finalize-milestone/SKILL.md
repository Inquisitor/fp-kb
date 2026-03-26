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

**This skill does not close tasks.** Even if all plan items are marked done, the task may have unrecorded scope — the user may want additional work before closing. Never set `status: completed` or remove from `_index.md`. For task closure use `kb-close-task`.

## Steps

### 1. Read the task journal
- Path: `D:\kb\fishing-planet\tasks\$ARGUMENTS\journal.md`
- Understand: what was just completed (Status section), which module(s) were affected (needed for Steps 3–5)

### 2. Update journal Status
- Confirm `## Status` has: what's done, **what's next**, blockers
- Append milestone to `## Milestones` section

### 3. Update module decision log
- Path: `D:\kb\fishing-planet\server\modules\<module>\log.md`
- Append decisions made during this milestone (rationale + lessons learned)
- log.md is append-only — never delete entries
- Skip if no architectural/design decisions were made

### 4. Update task backlog
- Path: `D:\kb\fishing-planet\tasks\$ARGUMENTS\backlog.md`
- Mark items completed in this milestone as done
- Skip if no backlog file exists

### 5. Update module card
- Path: `D:\kb\fishing-planet\server\modules\<module>\_card.md`
- Update `## Related Tasks` section with milestone summary

### 6. Collapse completed plan items (if plans exist)
- Check for plan files in `D:\kb\fishing-planet\tasks\$ARGUMENTS\artifacts\`
- If no plan files — skip
- Update phase/subtask statuses to reflect completion
- Extract detail bodies of DONE items into `artifacts/archived/subtasks/<jira-task-id>--<subtask-id>--<slug>.md` (e.g. `FP-41746--TRM-003--db-rename.md`)
- **Use `git-extract` skill** for the extraction — 2-commit technique preserves `git blame` history
- Collapse DONE items: detail section → one-liner in Summary table with `[details](archived/subtasks/<jira-task-id>--<subtask-id>--<slug>.md)` link
- After extraction: verify all cross-references are correct in both the plan (source) and each extracted subtask file (links back to plan, links to related subtasks, links to design docs)
- Only active (TODO/partial) items keep full detail sections below the Summary
- **Bubble-up rule:** deferred items from a completed phase go **one level up** in the plan hierarchy (sub-plan → parent plan → task backlog). Do NOT bubble up to module backlog — that happens only on task closure.

## Discipline
- Every step in this skill is **mandatory**, not advisory.
- Do NOT skip steps because they seem "obvious" or because you think another instruction covers them.
- If a step says "Use skill X" — invoke that skill. If a sub-skill says "Use tool Y" — use tool Y.
- A skill is a checklist: execute every item in order.

## Rules
- All content in English
- Do NOT duplicate information — each file has its own purpose
- Show the user what you're updating before writing
