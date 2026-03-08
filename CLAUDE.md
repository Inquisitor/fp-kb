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

### Tasks
- Task artifacts: `tasks/FP-XXXXX--slug/artifacts/`
- Task journals: `tasks/FP-XXXXX--slug/journal.md` — structure top-to-bottom: YAML frontmatter → Status (1-3 sentences) → Summary → Plan (link or inline) → Milestones (append-only, bottom)
- Task backlogs: `tasks/FP-XXXXX--slug/backlog.md` — immediate TODOs, deferred items; bubble up to module on task close
- Subtask files: `artifacts/archived/subtasks/FP-XXXXX--<ID>--<slug>.md` — prefixed with parent JIRA ID
- Temporary work products (audits, investigations) live under `tasks/`, not in `modules/`

### Modules
- Module cards: `modules/<name>/_card.md` — strict 5-section format:
  1. Entry Points (class + file path)
  2. Key Types (type + role)
  3. Dependencies (`→` consumes, `←` consumed by, `~` shared types)
  4. Deep Dives (links to permanent docs in same folder)
  5. Related Tasks
- Module cards: 25-35 lines target, never exceed 40. If overflowing — extract into deep dive
- Deep dives: permanent reference docs in module folder, no line limit
- Module decision logs: `modules/<name>/log.md` — decisions with rationale + lessons learned only
- Module backlogs: `modules/<name>/backlog.md`
- Max nesting: 2 levels from `modules/` — `modules/<name>/<file>.md`

### System overviews
- `modules/_systems/<system>.md` — cross-module data flow and ownership diagrams
- Optional, read on-demand (not a navigation layer)
- Referenced from `_index.md` section headers

### Module grouping
- Groups defined in `server/_index.md` section headers (e.g. "Fishing Gameplay", "Tournaments")
- Module folders stay flat under `modules/` — filesystem encodes location, text encodes relationships

### General
- Metadata format: YAML frontmatter (`---` delimited) for journals, reviews, cards
- No line numbers in analysis docs — use method names (grep-friendly, won't drift)
- Markdown tables: align columns with spaces (readability over token savings)
- Large plans (>200 lines): completed items collapse to one-liner with link to `artifacts/archived/subtasks/<ID>--<slug>.md`

## Navigation Protocol
```
Typical task:       server/_index.md → module/_card.md → code         (2 reads)
Cross-module task:  + modules/_systems/<system>.md                    (3 reads)
Need algorithm:     + deep dive linked from card                      (3-4 reads)
```

## Rules
- All content in English (artifacts from external sources may stay in original language)
- log.md is append-only — never delete entries
- backlog.md items bubble up on task close, never deleted silently
- Never write security root causes (exploit details, bypass methods)
- Never store credentials, connection strings, API keys
- Use Executor (not Assignee) in task/review files
- Subtask IDs (ALG-004, TRM-002, etc.) are KB-internal — never use in commits, GDD, TDD, or any external documentation
