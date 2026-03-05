# Knowledge Base System Design

**Date:** 2026-03-05
**Status:** Approved
**Author:** Team Lead + Claude Code (expert panel review)

## 1. Purpose

Personal tool for a game server team lead + AI agent (Claude Code) to:

1. **Orient quickly** — agent reads 2-3 files instead of grepping 2000+ .cs files
2. **Preserve decisions** — append-only logs at every level, survives across sessions
3. **Modernize Confluence** — index → assess → draft → publish back (Confluence stays source of truth)
4. **Track tasks** — per-task workspace with journal, backlog, artifacts
5. **Review tasks** — per-review workspace with checklist and notes
6. **Scale to multiple projects** — fishing-planet, train-planet, etc.

## 2. Principles

- **Confluence remains source of truth** for the team. KB is a workbench where updates are prepared.
- **Content > infrastructure.** Start with 5 module cards. Add complexity only when proven necessary.
- **Write friction must be minimal.** If recording a fact takes > 30 seconds — simplify.
- **Module cards are navigation aids**, not documentation. 20-40 lines: where to look, not code retelling.
- **Never write security root causes** (exploit details, bypass methods) into KB.
- **Never store credentials**, connection strings, API keys.
- **Decisions are preserved per-task.** Each non-trivial task has a decision journal — why X over Y.
- **Tasks are findable by topic and time.** Quickly find "what was done with leaderboards" or "decisions last month".
- **Backlog items bubble up** on task close — nothing is silently lost.
- **Executor (not Assignee)** in task/review files — who did the work, not current JIRA assignment.

## 3. Structure

```
D:\kb\
├── CLAUDE.md                              ← agent instructions when working from kb\
├── _index.md                              ← entry point: active tasks, reviews, confluence work
├── log.md                                 ← KB-level decisions (append-only)
├── backlog.md                             ← KB-level backlog (live list)
│
├── fishing-planet\
│   ├── server\
│   │   ├── _index.md                      ← server code map
│   │   ├── log.md                         ← server architecture decisions
│   │   ├── backlog.md                     ← server-level open items
│   │   └── modules\
│   │       ├── matchmaking.md             ← navigation card
│   │       ├── matchmaking.log.md         ← module-level decisions
│   │       ├── matchmaking.backlog.md     ← module-level open items
│   │       ├── caching.md
│   │       ├── dal.md
│   │       ├── clubs.md
│   │       ├── fishing-gameplay.md        ← GameProcessor + StateMachine
│   │       └── ...                        ← added as needed
│   │
│   ├── client\
│   │   ├── _index.md                      ← client code map
│   │   ├── log.md                         ← client architecture decisions
│   │   ├── backlog.md
│   │   └── modules\
│   │       └── ...
│   │
│   ├── glossary.md                        ← canonical terminology
│   │
│   ├── tasks\
│   │   ├── FP-41746--matchmaking\
│   │   │   ├── journal.md                 ← decisions, scope changes
│   │   │   ├── backlog.md                 ← open items for this task
│   │   │   └── artifacts\                 ← plans, designs, TSV data, etc.
│   │   ├── FP-42033--torch-sinker\
│   │   │   └── journal.md
│   │   └── SPIKE--cache-strategy\         ← tasks without JIRA
│   │       └── journal.md
│   │
│   └── review\
│       └── FP-41962--line-logging\
│           └── review.md                  ← executor, checklist, notes
│
├── confluence\
│   ├── _index.md                          ← assessment progress
│   ├── log.md                             ← Confluence reorg decisions
│   ├── backlog.md                         ← pages to assess, topics to consolidate
│   └── workspace\                         ← active drafts
│       └── caching-update\
│           ├── draft.md                   ← draft for Confluence publication
│           ├── source-pages.md            ← which Confluence pages were used
│           └── backlog.md                 ← remaining work for this draft
│
└── train-planet\                          ← same structure when needed
```

## 4. File Formats

### 4.1. `_index.md` (root)

```markdown
# Knowledge Base

## Active Tasks
| Task | Project | Topic | Status | Path |
|------|---------|-------|--------|------|
| FP-41746 | FP/server | matchmaking | in-progress | fishing-planet/tasks/FP-41746--matchmaking/ |
| FP-42033 | FP/server | game-logic | investigating | fishing-planet/tasks/FP-42033--torch-sinker/ |

## Active Reviews
| Task | Executor | Path |
|------|----------|------|
| FP-41962 | Stanislav | fishing-planet/review/FP-41962--line-logging/ |

## Active Confluence Work
| Topic | Status | Path |
|-------|--------|------|
| Caching pages consolidation | drafting | confluence/workspace/caching-update/ |

## Quick Links
- [FP Server modules](fishing-planet/server/_index.md)
- [FP Client modules](fishing-planet/client/_index.md)
- [Confluence progress](confluence/_index.md)
- [Glossary](fishing-planet/glossary.md)
```

Target size: 50-80 lines. Only active items — completed tasks are removed (history lives in task journal).

### 4.2. Module Card (`modules/matchmaking.md`)

```markdown
# Matchmaking

## Entry Points
- `MatchmakingManager` → Photon/src-server/.../MatchmakingManager.cs
- `TournamentGroupAllocator` → Photon/src-server/.../TournamentGroupAllocator.cs
- `BalanceGroups()` → main algorithm entry

## Data
- SQL: dbo.CompetitiveActivityBreaks
- Config: WebAdmin → Competitions → Matchmaking Settings

## Depends On
- ObjectModel (TournamentBracket, TournamentBucket)
- Caching (CompetitiveSettingsCache)

## Used By
- CompetitiveActivityProcessor
- WebAdmin CompetitionsController

## Confluence Pages
- 4339925004: Matchmaking (stale — missing group budget algorithm)
- 4339925014: Matchmaking testing (current)

## Key Decisions
- 2026-02: Renamed Groups→Buckets, GroupSettings→Brackets (TRM-002)
- 2026-03: FFS algorithm for group budget allocation (Phase 6)

## Related Tasks
- FP-41746: Alignment plan (active)
```

Target size: 20-40 lines. Navigation only — where to look, not how it works.

### 4.3. Task Journal (`tasks/FP-XXXXX--slug/journal.md`)

```markdown
# FP-41746: Matchmaking Alignment
## Status: in-progress
## Current Step: Phase 6 / Step 10 remainder
## Executor: <name>
## JIRA: https://fishingplanet.atlassian.net/browse/FP-41746

## Decisions
- 2026-01-20: Root cause ALG-004/005/006 — empty groups in Phase B
- 2026-02-10: Terminology rename across ALL solutions (not just LoadBalancing.sln)
- 2026-02-22: FFS algorithm chosen over greedy — better fairness guarantees
- 2026-03-02: GDD ideal version created, sent to designer

## Artifacts
- Matchmaking-Alignment-Plan.md — master plan (8 phases)
- Matchmaking-Group-Budget-Design.md — approved Phase 6 design
- TST-001-output-fixes.tsv — test data corrections
```

Status + Current Step always at the top — agent reads only the header for orientation.

### 4.4. Review Notes (`review/FP-XXXXX--slug/review.md`)

```markdown
# Review: FP-41962 — Improve logging on critical load
## Executor: Stanislav
## Branch: LBM (r15780), KNW (r15781)
## Status: reviewing

## Checklist
- [ ] Log format consistent with existing patterns
- [ ] No performance impact on hot path
- [ ] Edge case: instant tension spike captured?

## Notes
- ...
```

### 4.5. Decision Log (`log.md` at any level)

```markdown
# Decision Log — Server

## 2026-03-05
- Chose FFS over greedy for matchmaking group budget (see FP-41746)

## 2026-02-10
- Unified terminology: Groups→Buckets, GroupSettings→Brackets across all solutions
```

Append-only. Never delete entries. Grouped by date.

### 4.6. Backlog (`backlog.md` at any level)

```markdown
# Backlog — Server

- [ ] Investigate Redis cache invalidation race condition
- [ ] Document ChangeTracker sync protocol
- [ ] Assess Clubs Confluence pages (10 pages)
```

Live list. Items are added, checked off, or bubbled up to parent level on task close.

### 4.7. Confluence Index (`confluence/_index.md`)

```markdown
# Confluence — Fishing Planet / SERVER

## Progress
- Total pages: 152
- Assessed: 12
- Drafts ready: 0
- Published back: 0

## Assessed Pages
| Page ID | Title | Freshness | Notes |
|---------|-------|-----------|-------|
| 4339925004 | Matchmaking | stale | missing group budget, old terminology |
| 3616964613 | Distributed Data Cache | stale | missing Redis layer |
| 46628927 | Game Server Cache | current | |
| 3745251355 | OBSOLETE | skip | container page |
```

Content is NOT cached locally. Agent fetches via MCP when details needed.

## 5. Agent Navigation

### 5.1. `D:\kb\CLAUDE.md`

```markdown
# Knowledge Base

## Navigation
- Start: Read `_index.md` — active tasks, reviews, confluence work
- Server code map: `fishing-planet/server/_index.md`
- Client code map: `fishing-planet/client/_index.md`
- Glossary: `fishing-planet/glossary.md`

## Workflows
- Starting a task: read `_index.md` → find or create `tasks/FP-XXXXX--slug/`
- Working on code: read relevant `modules/*.md` for entry points
- Making a decision: append to `log.md` at appropriate level
- Closing a task: move open backlog items up one level
- Reviewing: create/update `review/FP-XXXXX--slug/review.md`
- Confluence work: check `confluence/_index.md`, work in `confluence/workspace/`

## Rules
- Module cards: 20-40 lines max, navigation only
- log.md is append-only — never delete entries
- backlog.md items bubble up on task close, never deleted silently
- Never write security root causes
- Never store credentials, connection strings, API keys
- Use Executor (not Assignee) in task/review files
```

### 5.2. Addition to project CLAUDE.md files

Each project repo (server, client) gets a pointer:

```markdown
## Knowledge Base
- KB root: D:\kb\
- Before server tasks: Read D:\kb\fishing-planet\server\_index.md
- Module cards: D:\kb\fishing-planet\server\modules\
```

### 5.3. Navigation flow

```
Any task:
  _index.md (root)                    ← what's active (1 read)
    → fishing-planet/server/_index.md ← code map (1 read)
      → modules/caching.md           ← entry points (1 read)
        → actual code via Read/Grep   ← source of truth

History lookup:
  _index.md → tasks/FP-41746--matchmaking/journal.md

Confluence work:
  _index.md → confluence/_index.md → workspace/caching-update/
```

Maximum 3 reads to orient. No grepping.

## 6. Migration Plan

Existing files from `D:\FishingPlanet\Docs\Plans\` move to KB:

| Source | Destination |
|--------|-------------|
| `Architecture/Matchmaking/*.md` | `fishing-planet/tasks/FP-41746--matchmaking/artifacts/` |
| `Architecture/FP2-SM/*.md` | `fishing-planet/tasks/` (new task folder or architecture) |
| `Reference/Matchmaking/*.txt` | `fishing-planet/tasks/FP-41746--matchmaking/artifacts/` |
| `Issues/FP-42033*.md` | `fishing-planet/tasks/FP-42033--torch-sinker/journal.md` |
| `Review/FP-41962*.md` | `fishing-planet/review/FP-41962--line-logging/review.md` |

## 7. Future Extensions (not for MVP)

- **SQLite** — add when grep on log.md/backlog.md stops scaling (~500+ entries)
- **Confluence full index** — populate `confluence/_index.md` with all 152 SERVER pages
- **Code map generation** — automated scan of codebase to populate `server/_index.md`
- **Skills** — `kb-orient` (session start), `kb-close-task` (backlog bubble-up), `kb-verify` (check entry points still exist)
- **Backup script** — `robocopy D:\kb\ E:\kb-backup\ /MIR` via Task Scheduler

## 8. Expert Panel Input

This design was reviewed by 5 specialized agents:

- **DevOps**: Backup strategy needed (Task Scheduler + robocopy). Never put SQLite on cloud sync drives. Add RECOVERY.md.
- **Product Manager**: Content > infrastructure. MVP = 5-7 module cards. ROI: ~5 weeks payback for cards, negative for SQLite+pipeline.
- **Solo Developer**: Friction on write is the make-or-break factor. AI agent as consumer changes the equation — provides feedback loop. CLAUDE.md + MEMORY.md already cover 80%.
- **Information Architect**: Name modules by domain (not class). Add slugs to task folders. Add glossary. Remove unnecessary `server/` nesting only if single-component.
- **Security**: Never store security root causes. Grep-guard on credentials. BitLocker on D:\. Don't commit SQLite dumps to VCS.