# Backlog — KB

## Module Cards
- [x] matchmaking — done
- [ ] Plan which modules to card next (explore codebase first, then decide)

## Code Maps
- [ ] Plan server/_index.md code map (requires codebase exploration)
- [ ] Plan client/_index.md code map (requires codebase exploration)

## Workflows
- [x] Design flow for "waiting for release" tasks (code done, need post-release verification). Consider JIRA filter vs KB tracking
  - Done 2026-04-17: design captured in `review-workflow-draft.md` → Waiting-for-release Workflow. Tracking via `_index.md` Active Reviews + `status: waiting-for-release` in card. Will be codified in `jira-review-close` skill.
- [ ] Create release-tracking file: task ↔ release mapping for daily routine ("which release shipped? → check those tasks")
- [ ] Compose KB use cases and verify the structure supports them
- [ ] Design review template and completion criteria
- [ ] Workflow for unclosed items in plan files (`docs/plans/*.md`, task artifacts). Separate from backlog.md — plan items are scoped to task execution. Need: when to resume, how to surface stale plans, handoff between plan and backlog on task close.

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
- [ ] Add `module:` field to task/review frontmatter. Validate module relation on task open AND close, update frontmatter accordingly. Enables reverse lookup: "show all tasks/reviews related to module X" from module card. Blocked on: wider module coverage in KB.
- [x] Retrospective: review task workflow after applying it to 1-2 fresh tasks. Validate conventions, fix pain points, then codify as skill
  - Done 2026-03-09: Phase 8 revealed satellite file update gap → kb-finalize-milestone skill planned

## Future
- [ ] Append-only daily journal (cross-task temporal view) — when pain is real
- [ ] Skills: kb-create-task, kb-create-review, kb-close-task, kb-orient — conventions stable enough, ready to implement
- [ ] First skill: kb-finalize-milestone (satellite file updates on milestone completion) — pain point confirmed
- [ ] Symlink `D:\kb\.claude\skills\` → project `.claude\skills\` for each working branch
- [ ] Skill: task workflow (for Claude — task lifecycle automation)
- [ ] SQLite index — add when grep on log.md/backlog.md stops scaling (~500+ entries)
