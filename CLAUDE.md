# Knowledge Base

## Navigation
- Start: Read `_index.md` — active tasks, reviews, confluence work
- Server code map: `fishing-planet/server/_index.md`
- Client code map: `fishing-planet/client/_index.md`
- Glossary: `fishing-planet/glossary.md`

## Workflows

### Starting a session
- Read `_index.md` first

### Starting a task
1. Read JIRA issue
2. Show what KB already knows (module card, related tasks) — user validates
3. If clear → draft plan. If not → investigate (module card → codebase)
4. May take several iterations before plan is ready
5. Create `tasks/FP-XXXXX--slug/` with journal.md and backlog.md

### Working on a task
- Working on code: read relevant `modules/<name>/_card.md` for entry points
- Making a decision: append to module `log.md` (decisions with rationale + lessons learned)
- Keep journal `## Status` section current: what's done, what's next, blockers
- Subtask IDs are KB-internal — never mention in commits, GDD, TDD, or external docs
- Multi-area subtasks: track per-area status (e.g. `Code=DONE, GDD=TODO, TDD=TODO`)
- Record anything that affects normal flow (blockers, scope changes) in journal Status

### Reopening a task
- Archive current plan to `artifacts/archived/`, create new plan with link to archived
- Resume normal workflow

### Closing a task
- Set `status: completed` in journal frontmatter
- Remove from `_index.md`
- Bubble up deferred backlog items to module backlog
- Document changes (or add to confluence backlog if nowhere to document yet)
- Add milestone to module card `## Related Tasks`

### Other workflows
- Reviewing: create/update `review/FP-XXXXX--slug/review.md`
- Confluence work: check `confluence/_index.md`, work in `confluence/workspace/`

## Conventions
- Task artifacts: `tasks/FP-XXXXX--slug/artifacts/`
- Task journals: `tasks/FP-XXXXX--slug/journal.md` — structure top-to-bottom: YAML frontmatter → Status (1-3 sentences) → Summary → Plan (link or inline) → Milestones (append-only, bottom)
- Task backlogs: `tasks/FP-XXXXX--slug/backlog.md` — immediate TODOs, deferred items; bubble up to module on task close
- Subtask files: `artifacts/archived/subtasks/FP-XXXXX--<ID>--<slug>.md` — prefixed with parent JIRA ID
- Module cards: `modules/<name>/_card.md`
- Module decision logs: `modules/<name>/log.md` — decisions with rationale + lessons learned only (no milestones or status updates)
- Module backlogs: `modules/<name>/backlog.md`
- Metadata format: YAML frontmatter (`---` delimited) for journals, reviews, cards
- No line numbers in analysis docs — use method names (grep-friendly, won't drift)
- Markdown tables: align columns with spaces (readability over token savings)
- Large plans (>200 lines): completed items collapse to one-liner with link to `artifacts/archived/subtasks/<ID>--<slug>.md`

## Rules
- All content in English (artifacts from external sources may stay in original language)
- Module cards: 20-40 lines max, navigation only
- log.md is append-only — never delete entries
- backlog.md items bubble up on task close, never deleted silently
- Never write security root causes (exploit details, bypass methods)
- Never store credentials, connection strings, API keys
- Use Executor (not Assignee) in task/review files
- Subtask IDs (ALG-004, TRM-002, etc.) are KB-internal — never use in commits, GDD, TDD, or any external documentation
