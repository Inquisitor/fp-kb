# KB System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create the Knowledge Base directory structure, seed initial content, migrate existing docs from Google Drive, and write the first module card.

**Architecture:** Flat MD files with hierarchical `_index.md` entry points. No database. No code. Just files and conventions.

**Tech Stack:** Markdown files, Claude Code tools (Write/Read/Edit), Atlassian MCP for Confluence indexing.

---

## Task 1: Create KB skeleton

**Files:**
- Create: `D:\kb\CLAUDE.md`
- Create: `D:\kb\_index.md`
- Create: `D:\kb\log.md`
- Create: `D:\kb\backlog.md`

**Step 1: Create CLAUDE.md**

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
- Never write security root causes (exploit details, bypass methods)
- Never store credentials, connection strings, API keys
- Use Executor (not Assignee) in task/review files
```

**Step 2: Create root `_index.md`**

Seed with current active tasks from MEMORY.md:

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
(none yet)

## Quick Links
- [FP Server modules](fishing-planet/server/_index.md)
- [FP Client modules](fishing-planet/client/_index.md)
- [Confluence progress](confluence/_index.md)
- [Glossary](fishing-planet/glossary.md)
```

**Step 3: Create root `log.md`**

```markdown
# Decision Log — KB

## 2026-03-05
- Created KB system at D:\kb\ based on approved design (see docs/plans/2026-03-05-kb-system-design.md)
- Expert panel review: 5 agents (DevOps, PM, Solo Dev, Info Architect, Security)
```

**Step 4: Create root `backlog.md`**

```markdown
# Backlog — KB

- [ ] Write first 5 module cards (matchmaking, caching, dal, clubs, fishing-gameplay)
- [ ] Populate server/_index.md with code map
- [ ] Populate client/_index.md with code map
- [ ] Index Confluence SERVER section (152 pages) into confluence/_index.md
- [ ] Set up backup script (robocopy + Task Scheduler)
- [ ] Add KB pointer to server project CLAUDE.md
- [ ] Add KB pointer to client project CLAUDE.md
- [ ] Fill glossary.md with canonical terminology from TRM-002
```

**Step 5: Verify**

Run: `ls -la D:/kb/` — should show CLAUDE.md, _index.md, log.md, backlog.md, docs/

---

## Task 2: Create fishing-planet project skeleton

**Files:**
- Create: `D:\kb\fishing-planet\server\_index.md`
- Create: `D:\kb\fishing-planet\server\log.md`
- Create: `D:\kb\fishing-planet\server\backlog.md`
- Create: `D:\kb\fishing-planet\client\_index.md`
- Create: `D:\kb\fishing-planet\client\log.md`
- Create: `D:\kb\fishing-planet\client\backlog.md`
- Create: `D:\kb\fishing-planet\glossary.md`

**Step 1: Create server `_index.md`**

```markdown
# Fishing Planet — Server Code Map

## Architecture
Photon Server (.NET 4.7.2, C# 9). MasterServer + GameServer + ChatServer + ClubServer.
See CLAUDE.md in server repo for full architecture overview.

## Module Cards
(none yet — see backlog)

## Key Paths
- Game logic: `Photon/src-server/Loadbalancing/GameLogic/`
- Shared libs: `Shared/`
- DAL: `Dal/`
- WebAdmin: `WebAdmin/`
- SQL scripts: `SQL/`
```

**Step 2: Create server `log.md` and `backlog.md`**

log.md — empty with header. backlog.md — empty with header.

**Step 3: Create client `_index.md`, `log.md`, `backlog.md`**

Placeholder structure — client code map to be filled when working on client tasks.

**Step 4: Create `glossary.md`**

Seed with matchmaking terminology from TRM-002:

```markdown
# Glossary — Fishing Planet

## Matchmaking
| Term | Code Name | Notes |
|------|-----------|-------|
| Bracket | `TournamentBracket` | Rating range definition (was: GroupSettings) |
| Bucket | `TournamentBucket` | Group of players within a bracket (was: Group) |
| Group Budget | `AllocateGroupBudget()` | How many groups per bucket |
```

**Step 5: Create empty modules directory**

Run: `mkdir -p D:/kb/fishing-planet/server/modules D:/kb/fishing-planet/client/modules`

**Step 6: Verify**

Run: `find D:/kb/fishing-planet -type f` — should show all created files.

---

## Task 3: Create confluence skeleton

**Files:**
- Create: `D:\kb\confluence\_index.md`
- Create: `D:\kb\confluence\log.md`
- Create: `D:\kb\confluence\backlog.md`

**Step 1: Create confluence `_index.md`**

```markdown
# Confluence — Fishing Planet / SERVER

## Progress
- Total pages: 152
- Assessed: 0
- Drafts ready: 0
- Published back: 0

## Assessed Pages
| Page ID | Title | Freshness | Notes |
|---------|-------|-----------|-------|
(none yet)
```

**Step 2: Create `log.md` and `backlog.md`**

backlog.md seed:

```markdown
# Backlog — Confluence

- [ ] Assess Server Architecture section (8 pages)
- [ ] Assess Business Logic section (31 pages)
- [ ] Assess Infrastructure section (50 pages)
- [ ] Assess Game Logic section (10 pages)
- [ ] Assess Development Environment section (12 pages)
- [ ] Assess Modules section (7 pages)
- [ ] Assess remaining sections (Platforms, Monetization, etc.)
```

**Step 3: Create workspace directory**

Run: `mkdir -p D:/kb/confluence/workspace`

**Step 4: Verify**

Run: `find D:/kb/confluence -type f`

---

## Task 4: Migrate FP-41746 matchmaking task

**Files:**
- Create: `D:\kb\fishing-planet\tasks\FP-41746--matchmaking\journal.md`
- Create: `D:\kb\fishing-planet\tasks\FP-41746--matchmaking\backlog.md`
- Move: `D:\FishingPlanet\Docs\Plans\Architecture\Matchmaking\*` → `artifacts/`
- Move: `D:\FishingPlanet\Docs\Plans\Reference\Matchmaking\*` → `artifacts/`

**Step 1: Create journal.md**

Populate from MEMORY.md data — Status, Current Step, JIRA link, Decisions, Artifacts list.

**Step 2: Create backlog.md**

From MEMORY.md "next steps":

```markdown
# Backlog — FP-41746 Matchmaking

- [ ] Phase 6 / Step 10 remainder (TDD + docs)
- [ ] Documentation (Phase 2 + Phase 7) — one pass later
- [ ] Add `Rational` struct to documentation
- [ ] Commit design doc to JIRA task
```

**Step 3: Copy artifact files**

Copy (not move — verify first) all files from:
- `D:\FishingPlanet\Docs\Plans\Architecture\Matchmaking\` → `artifacts/`
- `D:\FishingPlanet\Docs\Plans\Reference\Matchmaking\` → `artifacts/`

Run:
```bash
mkdir -p "D:/kb/fishing-planet/tasks/FP-41746--matchmaking/artifacts"
cp "D:/FishingPlanet/Docs/Plans/Architecture/Matchmaking/"* "D:/kb/fishing-planet/tasks/FP-41746--matchmaking/artifacts/"
cp "D:/FishingPlanet/Docs/Plans/Reference/Matchmaking/"* "D:/kb/fishing-planet/tasks/FP-41746--matchmaking/artifacts/"
```

**Step 4: Verify**

Run: `ls D:/kb/fishing-planet/tasks/FP-41746--matchmaking/artifacts/` — should list all matchmaking docs.

---

## Task 5: Migrate FP-42033 and FP-41962

**Files:**
- Create: `D:\kb\fishing-planet\tasks\FP-42033--torch-sinker\journal.md`
- Create: `D:\kb\fishing-planet\review\FP-41962--line-logging\review.md`

**Step 1: Create FP-42033 journal**

Read `D:\FishingPlanet\Docs\Plans\Issues\FP-42033*.md`, extract key info into journal.md format.

**Step 2: Create FP-41962 review**

Read `D:\FishingPlanet\Docs\Plans\Review\FP-41962*.md`, extract into review.md format with Executor field.

**Step 3: Verify**

Run: `find D:/kb/fishing-planet/tasks D:/kb/fishing-planet/review -type f`

---

## Task 6: Migrate FP2-SM architecture docs

**Step 1: Decide placement**

FP2-SM is a separate client project (Unity 6). Create a task folder or a dedicated architecture section — confirm with user.

Likely: `D:\kb\fishing-planet\tasks\SPIKE--fp2-project-structure\artifacts\`

**Step 2: Copy files**

```bash
mkdir -p "D:/kb/fishing-planet/tasks/SPIKE--fp2-project-structure/artifacts"
cp "D:/FishingPlanet/Docs/Plans/Architecture/FP2-SM/"* "D:/kb/fishing-planet/tasks/SPIKE--fp2-project-structure/artifacts/"
```

**Step 3: Create journal.md**

Minimal journal with status and artifact list.

---

## Task 7: Write first module card — matchmaking

**Files:**
- Create: `D:\kb\fishing-planet\server\modules\matchmaking.md`
- Create: `D:\kb\fishing-planet\server\modules\matchmaking.log.md`
- Create: `D:\kb\fishing-planet\server\modules\matchmaking.backlog.md`

**Step 1: Research entry points**

Agent reads key matchmaking files via Grep/Read to identify:
- Main classes and their paths
- SQL tables / config locations
- Dependencies and dependents

**Step 2: Write matchmaking.md**

20-40 lines, format per design doc section 4.2.

**Step 3: Write matchmaking.log.md**

Seed from MEMORY.md matchmaking decisions:

```markdown
# Decision Log — Matchmaking

## 2026-03-04
- All AllocateGroupBudget test cases implemented (Step 9 complete)

## 2026-03-02
- GDD ideal version created, editing instructions sent to designer

## 2026-02-22
- FFS algorithm chosen over greedy for group budget allocation

## 2026-02-10
- Terminology rename: Groups→Buckets, GroupSettings→Brackets (TRM-002)
```

**Step 4: Write matchmaking.backlog.md**

From task backlog, filtered to module scope.

**Step 5: Update server/_index.md**

Add matchmaking.md to Module Cards list.

**Step 6: Verify**

Read the card — does it contain enough to orient an agent unfamiliar with the module?

---

## Task 8: Add KB pointer to server CLAUDE.md

**Files:**
- Modify: `D:\FishingPlanet\src\server\svn\branches\LBM20251201\CLAUDE.md`

**Step 1: Add KB section**

Append to existing CLAUDE.md:

```markdown
## Knowledge Base
- KB root: D:\kb\
- Before server tasks: Read D:\kb\fishing-planet\server\_index.md
- Module cards: D:\kb\fishing-planet\server\modules\
```

**Step 2: Verify**

Read the file, confirm section is appended correctly and doesn't conflict with existing content.

---

## Task 9: Update MEMORY.md

**Files:**
- Modify: `C:\Users\Inquisitor\.claude\projects\D--FishingPlanet-src-server-svn-branches-LBM20251201\memory\MEMORY.md`

**Step 1: Add KB section**

Replace or supplement existing matchmaking-specific entries with pointer to KB:

```markdown
## Knowledge Base
- Location: D:\kb\
- Design: D:\kb\docs\plans\2026-03-05-kb-system-design.md
- When starting any task: Read D:\kb\_index.md first
```

**Step 2: Trim duplicated content**

Matchmaking progress details now live in `D:\kb\fishing-planet\tasks\FP-41746--matchmaking\journal.md`. MEMORY.md should point there instead of duplicating.

---

## Task 10: Cleanup Google Drive docs

**Step 1: Confirm all files migrated**

Compare `D:\FishingPlanet\Docs\Plans\` contents with KB — ensure nothing was missed.

**Step 2: Ask user to verify**

User confirms the old location can be archived or removed.

---

## Execution Notes

- Tasks 1-3 are independent (KB skeleton, project skeleton, confluence skeleton) — can run in parallel
- Task 4-6 depend on Task 2 (project skeleton must exist)
- Task 7 depends on Task 2 (modules directory must exist)
- Task 8-9 are independent of each other but should run after Task 7
- Task 10 is last — only after user verifies everything migrated