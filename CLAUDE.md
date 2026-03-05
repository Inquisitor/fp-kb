# Knowledge Base

## Navigation
- Start: Read `_index.md` — active tasks, reviews, confluence work
- Server code map: `fishing-planet/server/_index.md`
- Client code map: `fishing-planet/client/_index.md`
- Glossary: `fishing-planet/glossary.md`

## Workflows
- Starting a session: read `_index.md` first
- Starting a task: find or create `tasks/FP-XXXXX--slug/`
- Working on code: read relevant `modules/*.md` for entry points
- Making a decision: append to nearest `log.md` (task > module > server/client > KB root)
- Closing a task: set status to `completed` in journal, remove from `_index.md`, bubble up open backlog items (task → module/server → KB root)
- Reviewing: create/update `review/FP-XXXXX--slug/review.md`
- Confluence work: check `confluence/_index.md`, work in `confluence/workspace/`

## Conventions
- Task artifacts: `tasks/FP-XXXXX--slug/artifacts/`
- Task journals: `tasks/FP-XXXXX--slug/journal.md`
- Module decision logs: `modules/<name>.log.md`
- Module backlogs: `modules/<name>.backlog.md`
- Journal/review metadata: blockquote with `\` line breaks (not `##` headings)
- No line numbers in analysis docs — use method names (grep-friendly, won't drift)

## Rules
- All content in English (artifacts from external sources may stay in original language)
- Module cards: 20-40 lines max, navigation only
- log.md is append-only — never delete entries
- backlog.md items bubble up on task close, never deleted silently
- Never write security root causes (exploit details, bypass methods)
- Never store credentials, connection strings, API keys
- Use Executor (not Assignee) in task/review files
