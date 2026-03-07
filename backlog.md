# Backlog — KB

## Module Cards
- [x] matchmaking — done
- [ ] Plan which modules to card next (explore codebase first, then decide)

## Code Maps
- [ ] Plan server/_index.md code map (requires codebase exploration)
- [ ] Plan client/_index.md code map (requires codebase exploration)

## Workflows
- [ ] Design flow for "waiting for release" tasks (code done, need post-release verification). Consider JIRA filter vs KB tracking
- [ ] Create release-tracking file: task ↔ release mapping for daily routine ("which release shipped? → check those tasks")
- [ ] Compose KB use cases and verify the structure supports them
- [ ] Design review template and completion criteria

## Confluence
- [ ] Index SERVER section into confluence/_index.md

## Glossary
- [ ] Fill glossary.md with canonical terminology from TRM-002

## Infrastructure
- [x] Add KB pointer to server project CLAUDE.md
- [ ] Add KB pointer to client project CLAUDE.md
- [ ] Set up backup script (robocopy + Task Scheduler)

## Tasks Structure
- [x] Refactor FP-41746 Alignment Plan: Summary to top, DONE items → one-liners + `archived/subtasks/`
- [x] Clean module matchmaking/log.md: remove non-decisions, keep only decisions with rationale
- [x] Convert FP-41746 and FP-42033 journals to YAML frontmatter + `## Status`
- [ ] Fix stale path in Alignment Plan (pre-KB migration reference to `Docs/Plans/Architecture/Matchmaking/`)
- [ ] Retrospective: review task workflow after applying it to 1-2 fresh tasks. Validate conventions, fix pain points, then codify as skill

## Future
- [ ] Append-only daily journal (cross-task temporal view) — when pain is real
- [ ] Skills: kb-create-task, kb-create-review, kb-close-task, kb-orient — after conventions stabilize
- [ ] Skill: task workflow (for Claude — task lifecycle automation)
- [ ] SQLite index — add when grep on log.md/backlog.md stops scaling (~500+ entries)
