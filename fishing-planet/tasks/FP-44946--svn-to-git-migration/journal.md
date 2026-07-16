---
jira: FP-44946
title: Define Git workflow for the server team
status: in-progress
executor: Stanislav Samoilov
created: 2026-07-13
type: story
---
# FP-44946: Define Git workflow for the server team

## Status
Team meeting held 2026-07-14: no final decisions yet, team leans toward Option A. Article
published to Confluence (page 5768642569, v6, TECH > SERVER > Infrastructure) for the team to
read; discussion continues 2026-07-15. Then: record decisions, write the final flow description.

## Summary
Server code migrates from SVN (rotating role-based release branches, upward hotfix merges) to Git,
starting with the Dev branch. This task produces the documented Git flow description for the server
team: long-lived branch model, task-branch lifecycle, merge policy, hotfix propagation, and
release-cycle mapping. Related workstreams are tracked separately: Git platform choice, SVN-Git
sync restoration, pilot deploy from a Git branch.

## Design decisions (pending)
- **History model**: Option A (first-parent linearity — structural merges between long-lived
  branches stay real merge commits) vs Option B (strictly linear — cross-branch propagation via
  cherry-pick). Preliminary lean: **A** — keeps git-native merge tracking (the `svn:mergeinfo`
  replacement); B substitutes it with a hand-maintained audit process and risks silently missed or
  semantically drifted cherry-picks of security-sensitive fixes. Team decision at the meeting.
- **Landing style within A**: fast-forward / semi-linear (`rebase` + `--no-ff` boundary commit) /
  squash. Squash matches today's one-commit-per-task SVN granularity most closely.

## Plan
- [x] Create problem-only JIRA issue
- [x] Draft flow-options article for the team meeting — [confluence draft](../../../confluence/workspace/FP-44946--git-flow-options.md)
- [ ] Team meeting (2026-07-14): capture decisions — history model, landing style, hotfix convention
- [ ] Write the final Git flow description (target surface TBD — likely Confluence)

## Milestones (log)
- 2026-07-13: Task opened. Feasibility of the rebase + fast-forward flow assessed: feasible,
  platform-enforceable on all major Git hosts. Key fork identified — strict linearity conflicts
  with upward hotfix merges; framed as Option A (first-parent) vs Option B (cherry-pick
  propagation). JIRA FP-44946 created (Story, Server component, Tech Debt 2026 Q3 epic,
  Internal/Async). Meeting article drafted.
- 2026-07-14: Team meeting held (article as agenda). Diagrams refined (branches start at fork
  points; Option B shows content commits also travelling via cherry-pick). Article published to
  Confluence: TECH > SERVER > Infrastructure, page 5768642569 (v3 — v2 had the Option B note
  truncated by the md converter; reformatted to a blockquote). Draft moved from task artifacts to
  confluence/workspace/FP-44946--git-flow-options.md.
