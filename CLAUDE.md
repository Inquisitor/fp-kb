# Knowledge Base

## Navigation
- Start: Read `_index.md` — active tasks, reviews, confluence work
- Server code map: `fishing-planet/server/_index.md`
- Client code map: `fishing-planet/client/_index.md`
- Confluence docs: `confluence/tree.md` → `confluence/sections/.../_pages.yml`
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

### Reviewing a task
1. Read Jira issue (description, status, assignee)
2. Find relevant commits:
   - **Jira comments** — team convention: commit ID + description posted as comment; cross-branch merges noted too
   - **SVN log** — commits reference Jira ID in the message: `svn log --search "FP-XXXXX"`
3. Create `review/FP-XXXXX--slug/review.md` immediately, add to Active Reviews in `_index.md`
4. Read the actual VCS diff for each commit (`svn diff -c <rev>`)
5. Review the diff — don't grep the codebase and assume; only review what the diff contains
6. Multi-commit tasks: summarize diffs and analyze as a whole; if many — plan and analyze in parts
7. Findings: assess severity in context (pre-existing gap ≠ author's oversight)
8. Executor = commit author (not Jira assignee)
9. Closure: set status `resolved`, remove from Active Reviews in `_index.md`

### Confluence work
- Navigation: `confluence/tree.md` (section router) → `sections/.../_pages.yml` (page listings)
- Drafting: create `confluence/workspace/FP-XXXXX--slug.md` with YAML frontmatter (`page_id`, `parent_id`, `section`, `related_tasks`)
- After publishing: update `_pages.yml` with page ID and `verified` date. Use `/publish-confluence` skill for the full workflow
- `_pages.yml` = YAML index per section (page IDs, titles, `verified` date, `last_pushed_version` for overwrite protection). NOT content — Confluence is SSoT
- `tree.md` = section-level router with "what's inside" annotations. Does NOT list individual pages
- Sections mirrored under `confluence/sections/<space>/` (e.g. `fishing-planet/`)
- `confluence/archive/` exists for git blame navigation; agents do not index it
- Internal anchor links in workspace drafts: use Confluence TOC format `#Heading-Title` (title case, spaces → dashes, special chars URL-encoded), NOT markdown-style `#heading-title`

## Conventions

### Tasks
- Task artifacts: `tasks/FP-XXXXX--slug/artifacts/`
- Task journals: `tasks/FP-XXXXX--slug/journal.md` — structure top-to-bottom: YAML frontmatter → Status (1-3 sentences) → Summary → Plan (link or inline) → Milestones (append-only, bottom)
- Task backlogs: `tasks/FP-XXXXX--slug/backlog.md` — immediate TODOs, deferred items; bubble up to module on task close
- Subtask files: `artifacts/archived/subtasks/<jira-task-id>--<subtask-id>--<slug>.md` (e.g. `FP-41746--TRM-003--db-rename.md`)
- Temporary work products (audits, investigations) live under `tasks/`, not in `modules/`

### Creating a module
1. Create `modules/<name>/` with `_card.md`, `log.md`, `backlog.md`
2. Register in `server/_index.md` (or `client/_index.md`) under appropriate group section
3. If new group needed — add section header to `_index.md`

### Modules
- Module cards: `modules/<name>/_card.md` — strict 5-section format:
  1. Entry Points (class + file path)
  2. Key Types (type + role)
  3. Dependencies (`→` consumes, `←` consumed by, `~` shared types)
  4. Deep Dives (links to permanent docs in same folder)
  5. Related Tasks
- Module cards: 25-35 lines target, never exceed 40. If overflowing — extract into deep dive
- Deep dives: permanent reference docs in module folder, no line limit
- Module decision logs: `modules/<name>/log.md` — decisions with rationale + lessons learned. Prefix findings (unverified observations) with `Finding:` to distinguish from decisions. Unverified findings → card gets *(UNVERIFIED)* annotation, backlog gets verify item
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
Confluence page:    confluence/tree.md → sections/.../_pages.yml      (2 reads)
Confluence content: + fetch via Confluence MCP API by page ID         (3 reads)
Not in index:       search Confluence via MCP API — index is partial  (organic growth)
```

## Branch Roles

Role definitions and merge direction. Current assignments are in `_index.md`.

| Role      | Color  | Hex       | Merge rule                                      |
|-----------|--------|-----------|-------------------------------------------------|
| Code      | Blue   | `#0747a6` | Main development; receives merges from all      |
| Content   | Orange | `#ff991f` | Content/balance work; merges into Code          |
| Future    | Green  | `#36b37e` | Next major release; not yet active              |
| Stable    | Red    | `#ff5630` | Live release; hotfixes only, merge into all     |
| OldStable | Red    | `#ff5630` | Previous release; hotfixes only, merge into all |

Merge direction: OldStable → Stable → Content → Code (each level merges into all levels above it).

## Rules
- All content in English (artifacts from external sources may stay in original language)
- log.md is append-only — never delete entries
- backlog.md items bubble up on task close, never deleted silently
- Never write security root causes (exploit details, bypass methods)
- Never store credentials, connection strings, API keys
- Use Executor (not Assignee) in task/review files
- Subtask IDs (ALG-004, TRM-002, etc.) are KB-internal — never use in commits, GDD, TDD, or any external documentation
