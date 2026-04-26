# Knowledge Base

## Navigation
- Start: Read `_index.md` — active tasks, reviews, confluence work
- Server code map: `fishing-planet/server/_index.md`
- Client code map: `fishing-planet/client/_index.md`
- Confluence docs: `confluence/tree.md` → `confluence/sections/.../_pages.yml`
- Glossary: `fishing-planet/glossary.md`

## Discussion Discipline

The agent is **NOT a yes-man** — fluent agreement that masks unchallenged decisions is worse than no agent at all. Maintain active, reasoned, constructive, verified criticism in every discussion:

- **Active** — speak up when something looks unnecessary or wrong; do not stay silent; do not reflex-agree to keep flow
- **Reasoned** — criticism must rest on clear justification, not aesthetic preference
- **Constructive** — pair every critique with a concrete alternative
- **Verified** — counter-arguments must rest on facts obtained by Read / grep / svn log / equivalent. Plausible inference is performative, not active criticism

When tempted to agree without engaging — that's the moment to push back instead.

Full elaboration: [feedback/active_criticism.md](feedback/active_criticism.md).

## Workflows

### Starting a session
- Read `_index.md` first

### Reporting current status
When asked "what's the current status?" / "what's in focus?" / "что сейчас в работе?" / "что в фокусе?" / "покажи статус" / "что по беклогу?" / "где остановились?" / "что у нас активного?" / "на чём сейчас?":
1. Read `_index.md` — Active Tasks, Active Reviews, Active Confluence Work
2. Grep unclosed items across all `backlog.md` files in KB: `grep -rn "^- \[ \]" --include="backlog.md" D:/kb/`
   - Covers: KB-wide, per-project, per-module, per-task, per-area backlogs
3. Present grouped by source (tasks / reviews / modules / project-level / KB-wide)

Scope: **only `backlog.md` files**. Unclosed items in plan files belong to individual task execution, not overall status (handled separately by task/plan skills).

Active items in `_index.md` cover current in-flight work. Backlog items cover everything deferred, queued, or noted for later. Both together = full picture.

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
- Module card frontmatter: minimum required fields:
  ```yaml
  ---
  name: <module-name>
  system: <system-name>       # scalar; one system per module. Cross-cutting handled via dependencies, not multi-membership
  code_paths:
    - <path/to/code/>
    - <another/path/>
  ---
  ```
  Additional fields (`db_tables`, `caches`, `external_deps`, `tests`) only when a concrete cross-module query use case justifies them — do not add preemptively
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

### Authoring (abstraction & memory promotion)

When writing or migrating KB content, abstract from machine/branch/tool specifics:

- **Paths**: use `<kb>/...` (KB root) and `<project>/...` (working tree root) placeholders, not absolute paths
- **Branches**: refer by role (`{branch}`, "Code branch") not by current name; lookup role assignments in `_index.md` → Branch Roles
- **Tools / MCPs**: describe the capability ("DB-access MCP", "JIRA account lookup tool"), not vendor or server name
- **Examples**: concrete data goes in dedicated Example sections; mark transient state ("X at time of writing")

Drop on migration from project memory to KB:
- `originSessionId` and other session-bookkeeping
- "Verified on FP-XXXXX (date)" historical citations
- "This rule was violated on FP-YYYYY" narrative — keep the rule, drop the incident
- User-specific framing — generalize to rational/engineering reasons
- Hard machine paths — replace with placeholders

**Promote periodically.** Project memory captures ad-hoc findings; FP-wide rules belong in KB so they survive SVN branch rotations and machine changes. When a memory entry stabilizes (no recent edits, applied across sessions, applicability beyond one branch/machine), promote per the rules above.

### SVN merge commit format

TortoiseSVN-style header followed by the original commit message verbatim:

```
Merged revision(s) <rev or list> from branches/<source>:
<full original commit message — every line, not just the first>
```

The original message includes the JIRA ID prefix and bullets — keep verbatim.

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

### Before merging: check ancestry

Before running `svn merge` from branch X into branch Y, check `_index.md` → Server Branch Ancestry:

- If Y was created as a copy of X at rev `M` (directly or transitively), any commit on X at rev `≤ M` is already inherited in Y — **skip the merge**.
- `svn mergeinfo` does NOT reflect branch-copy inheritance; it only tracks explicit merges. Relying on it alone misses this case.
- Verify by running `svn log` on a file the commit touched in the target branch URL — the original revision should appear.

### KB target

KB describes the branch currently holding the **Code role** (not a specific named branch). When branch roles rotate — the Code branch becomes Content, a new branch takes the Code role — KB automatically continues describing the new Code branch (the new Code forks from the same snapshot as old Content, so no migration is needed).

For `log.md` entries recording architectural changes, include `[branch r<rev>]` stamps (e.g. `2026-03-15 [MFT r12345] …`) so cross-branch drift is traceable.

When working on a non-Code branch and observing divergence from KB, add a `Finding:` entry in the relevant module `log.md` with the branch stamp; do not rewrite the card — KB continues to reflect the Code branch.

## What to Store in KB

KB is a **navigation and context layer**, not a code copy. The agent can read code at any time; KB exists to answer what code cannot answer alone.

### STORE if the knowledge is:

| Category                     | Example                                                                                                         | Why not in code                       |
|------------------------------|-----------------------------------------------------------------------------------------------------------------|---------------------------------------|
| **Why**                      | "Custom matchmaker instead of standard — needs asymmetric load between skill tiers"                             | Motivation / rejected alternatives    |
| **Cross-file link**          | "BiteSystem reads PondConfig from CacheManager, refreshed via AdminBalance webhook"                             | Relationship scattered across files   |
| **Invariant**                | "matchmaking_queue.user_id is unique within a 5-minute window after insert"                                     | Not declared, but assumed             |
| **Gotcha**                   | "Kendo templates eat literal `+` — write `%2B`"                                                                 | Non-obvious pitfall                   |
| **Entry-point**              | "To understand leaderboard closure — start at `LeaderboardScheduler.OnPeriodEnd`"                               | Navigation, "where to look"           |
| **Decision**                 | "2026-02 [MFT r12345] per-region queue; sharding rejected due to Mongo lock contention"                         | History + alternatives                |
| **Non-obvious optimization** | "FishSpawnPool uses array-of-structs for cache locality; measured +30%. Do not refactor to generic collections" | Guards against well-meaning "cleanup" |

### DO NOT store if the knowledge is:

| Category                      | Example                                           | Where it is                            |
|-------------------------------|---------------------------------------------------|----------------------------------------|
| **What** (describes function) | "GenerateWeight computes fish weight"             | Method name                            |
| **Signature**                 | "`GenerateWeight(fishType, location) → float`"    | In code                                |
| **Structure**                 | "`Player` contains Name, Level, Inventory"        | In code                                |
| **Algorithm body**            | "First filter by depth, then sort by weight, ..." | In code (unless genuinely non-obvious) |
| **Values**                    | "MaxPlayersPerGame = 50"                          | In config                              |
| **Obvious dep**               | "UserController uses UserService"                 | Using-statement in same file           |

### Three tests when on the borderline

1. **Delete test:** "If I remove this line, can the agent still solve the task by reading code?" — if YES, delete.
2. **Duplicate test:** "This fact is in code — why am I also writing it to KB?" — the answer must fall in one of the STORE categories. Otherwise delete.
3. **Drift test:** "If the code changes, will this line need editing?" — high drift risk combined with low value = delete.

### Edge cases where "if in code — don't write" does not apply

1. **Code in another repo** (Unity client, third-party SDKs) — agent cannot Read it cheaply → store links and summaries.
2. **Historical behavior** — only if it prevents recurring questions (evidence-based: someone actually asked, not hypothetical). Put in `log.md`, not `_card.md`.
3. **Intentional "weirdness" in code** — reason is offstage (e.g. "using linear search because collection is always <10; don't optimize"). Without this note, agent will "improve" the code. Write it.
4. **Team conventions not visible in code** — e.g. file naming patterns, commit tag format. Write them.
5. **Cross-branch behavior** — e.g. feature rewritten in Code but rolled back in Stable. Neither branch alone holds full state → `log.md` with `[branch r<rev>]` stamps.

### Example agent reasoning when writing to KB

**Case 1.** Writing: `"GenerateWeight(fishType, location) returns float"`
- Check: Signature. Delete test: yes, code makes it obvious. → **DELETE**

**Case 2.** Writing: `"GenerateWeight is bounded below by minWeight from BalanceConfig to avoid discouraging early-game players"`
- Check: Why (motivation) + cross-file (BalanceConfig) + invariant. → **KEEP**

**Case 3.** Writing: `"Table matchmaking_queue has columns user_id, created_at, region_id"`
- Check: Structure. Schema/migrations carry this. → **DELETE**
- But separately: `"matchmaking_queue.user_id is unique within a 5-minute window after insert"` → Invariant. → **KEEP**

**Case 4.** Writing: `"Module X uses Mongo instead of Redis"`
- Check: no one asked about Redis, Redis is not in our stack → preemptive historical. → **DELETE**
- Keep only with evidence of recurring questions: `"Redis was proposed 2026-03 for session cache; rejected — Mongo with TTL indices already covers the use case. No need to revisit."`

### Evidence-based rule

Do NOT document defensively "just in case". Document what actually came up — a real question, a real incident, a real ambiguity. Preemptive documentation inflates KB with noise.

## Feedback Rules

- [Active criticism](feedback/active_criticism.md) — challenge before agreeing; counter-args must be reasoned and verified; yes-man behavior is rejected
- [Branch-copy inheritance check](feedback/branch_copy_inheritance.md) — verify before svn merge that the fix isn't already inherited via branch copy
- [JIRA comment preview](feedback/jira_comment_preview.md) — show draft, get approval, then post; share permalink after
- [Re-read reference at draft-time](feedback/reference_recheck.md) — Read referenced format files immediately before drafting; session-prefetch ≠ application
- [Verify identifiers, no placeholders](feedback/verify_identifiers.md) — run trivial lookup for unknown URL/ID/path; never substitute placeholder

## References

- [JIRA comment formats](reference/jira_comment_formats.md) — ADF formats for SVN commit notes and cross-branch merge notes
- [JIRA Executor field](reference/jira_executor_field.md) — `customfield_11224` (userpicker), fetch explicitly via `getJiraIssue`

## Rules
- Active critical engagement (no yes-man) — see Discussion Discipline above
- All content in English (artifacts from external sources may stay in original language)
- log.md is append-only — never delete entries
- backlog.md items bubble up on task close, never deleted silently
- Never write security root causes (exploit details, bypass methods)
- Never store credentials, connection strings, API keys
- Use Executor (not Assignee) in task/review files
- Subtask IDs (ALG-004, TRM-002, etc.) are KB-internal — never use in commits, GDD, TDD, or any external documentation
