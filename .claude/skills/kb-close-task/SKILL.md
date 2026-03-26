---
name: kb-close-task
description: >
  Close a KB task — finalize milestone, clean cross-references, bubble up backlogs, update indexes.
  Use when user says "закрыть задачу", "close task", "задача закрыта", "давай закроем",
  or when all plan items are done and user confirms closure.
maturity: draft
argument-hint: "[task-slug, e.g. FP-41844--weight-gen-docs]"
---

# Close Task

Close KB task `$ARGUMENTS` — finalize the last milestone, clean up all references, and archive.

## Steps

### 1. Read task journal
- Path: `D:\kb\fishing-planet\tasks\$ARGUMENTS\journal.md`
- Identify: modules affected, Confluence artifacts, related/blocked tasks, plan status

### 2. Final milestone (invoke kb-finalize-milestone)
- Run `kb-finalize-milestone` with the same task slug
- This captures the last batch of work: journal Status + milestone, module log/card, task backlog, plan collapse

### 3. Set status: completed
- Journal YAML frontmatter: `status: completed`
- Journal `## Status`: replace with final summary (what was delivered, no "next" items)

### 4. Cross-reference cleanup
- Extract task key from slug (same as Step 9). Grep the key across:
  - `D:\kb\fishing-planet\tasks\*/journal.md` and `backlog.md`
  - `D:\kb\fishing-planet\server\modules\*/_card.md` and `backlog.md`
- For each hit in an **active** task or module file, propose an update:
  - `blocked-tasks:` frontmatter → remove or clear the entry
  - Status sections referencing this task as "next" → update to reflect completion
  - Related links → change label to "(completed)", link to journal instead of JIRA
  - Backlog phases fulfilled by this task → mark done with links to deliverables
- Show all findings as a list. Ask user: apply one by one or all at once?

### 5. Final backlog sweep
- Read task backlog: `D:\kb\fishing-planet\tasks\$ARGUMENTS\backlog.md`
- If no backlog file → skip
- For each remaining open item:
  - **Valuable:** bubble up to the relevant module backlog (from Step 1) with origin note
  - **Not valuable:** mark as explicitly dropped (with brief reason)
- Show the list before applying

### 6. Confluence artifact check
- Grep task ID in `D:\kb\confluence\workspace\*.md` (frontmatter `related_tasks`)
- Grep task ID in `D:\kb\confluence\sections\**\_pages.yml`
- If found, verify for each page:
  - `page_id` is present in draft frontmatter
  - Matching `_pages.yml` entry has `last_pushed_version` set
  - `verified` date is current
- Report any stale or incomplete artifacts
- Skip entirely if no Confluence artifacts found

### 7. Remove from _index.md
- Remove task row from `D:\kb\_index.md` Active Tasks table

### 8. Update memory
- Update Current Focus in MEMORY.md — mark task as closed or remove

### 9. JIRA reminder
- Extract task key from the slug (everything before the first `--`)
- Remind user to transition the task to Resolved, including the key and `jira:` URL from journal frontmatter

### 10. Commit KB changes
- Show list of all changed files
- Output commit message following KB conventions. Do NOT run git commands.

### 11. Reflection (maturity: draft)
- Was anything missed that required manual cleanup after the skill ran?
- Would an additional step have prevented it?
- If yes — suggest a specific edit to this skill.
- Remove this step once `maturity` is changed from `draft`.

## Discipline
- Every step is **mandatory**, not advisory.
- If a step says "Ask the user" — ask. Do not assume the answer.
- If a step says "invoke skill X" — invoke it. Do not inline its logic.
- Show the user what you're changing before writing.

## Rules
- All content in English
- Do NOT run `git commit` — only output commit message text
- Do NOT transition JIRA — only remind the user
- Cross-reference cleanup targets **active** tasks and modules only, not the closing task's own files
