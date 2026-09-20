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
Final flow document published: options page 5768642569 evolved into the prescriptive "Git Flow
for the Server Team" (content v7, rename v8); options content preserved as page history (up to
v6), its workspace draft archived. Task deliverable complete — closure pending (JIRA transition,
backlog bubble-up). Related workstreams (platform choice, sync, pilot deploy) remain separate.

## Summary
Server code migrates from SVN (rotating role-based release branches, upward hotfix merges) to Git,
starting with the Dev branch. This task produces the documented Git flow description for the server
team: long-lived branch model, task-branch lifecycle, merge policy, hotfix propagation, and
release-cycle mapping. Related workstreams are tracked separately: Git platform choice, SVN-Git
sync restoration, pilot deploy from a Git branch.

## Design decisions
- **History model — DECIDED: Option A (first-parent linearity)** (team meeting, recorded
  2026-07-22). Structural merges between long-lived branches stay real merge commits; task
  branches land linearly. Option B (cherry-pick propagation) rejected — hand-maintained tracking,
  silent miss/drift risks.
- **Landing style within A — DECIDED: fast-forward only** (recorded 2026-08-02). Task branches
  land via rebase + ff; squash is a per-MR option for small/messy branches; curated multi-commit
  landing when behavior/NFC separation is worth keeping. Semi-linear rejected: whole-task revert
  is an exceptional event in team practice and does not justify a boundary commit per task —
  mainline grouping is already carried by the `FP-#####:` commit prefix. Structural merges between
  long-lived branches are exempt from the ff-only rule (privileged maintainer push, not a task MR).
- **Branch naming — DECIDED**: `fp-12345-short-slug` (recorded 2026-08-04).
- **`Fixes:` trailer — optional** (recorded 2026-08-15): hotfix commits may carry it; not mandated.
- **Structural merge messages — DECIDED** (recorded 2026-08-04): git default subject + auto
  shortlog of merged subjects (`merge.log 500`), reproducing the SVN merge-message habit without
  hand-authoring; full bodies not embedded (merged commits are already in the target history).
- **Commit convention — DECIDED** (recorded 2026-08-02): `[NFC]` marker after `[Topic]` for
  behavior-neutral commits (LLVM precedent); unrelated cleanup goes to its own MR under the
  standing quarterly Tech Debt ticket; subject format enforced by a platform push rule (allowed
  forms: task commit / structural merge / protocol increment — concrete regex in the flow doc);
  body bullets are plain `-` items — the SVN `+/-/=/*` classification is dropped in Git
  (recorded 2026-08-04).

## Plan
- [x] Create problem-only JIRA issue
- [x] Draft flow-options article for the team meeting — [confluence draft](../../../confluence/workspace/FP-44946--git-flow-options.md)
- [x] Team meetings: history model decided — Option A (first-parent)
- [x] Settle landing style + commit-granularity convention (squash vs curated commits, NFC separation)
- [x] Final Git flow description — published over the options page (5768642569, retitled "Git Flow for the Server Team", v8)

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
- 2026-07-22: Team accepted **Option A** (first-parent linearity), no objections. Still open:
  landing style and commit-granularity convention — direction voiced: keep branches squashable OR
  curate meaningful commits, and make behavior-affecting commits distinguishable from
  behavior-neutral cleanup/refactoring.
- 2026-08-02: Landing style settled — **fast-forward only**; semi-linear dropped (whole-task
  revert is exceptional in team practice; FP-ID prefixes group mainline commits by task). Squash
  stays a per-MR option. Structural cross-branch merges exempt from ff-only (privileged push, not
  a task MR).
- 2026-08-02: Commit-convention tails accepted — `[NFC]` marker; standing quarterly Tech Debt
  ticket as the FP-ID home for standalone cleanup MRs. Final flow document drafted to
  confluence/workspace/FP-44946--git-flow.md.
- 2026-08-04: Doc review round — commit bullets simplified to plain dashes (Git era only);
  enforcement regex extended with the concrete protocol-increment alternative (verified against
  SVN r16281/r16321); branch naming `fp-12345-short-slug` approved; structural merge messages =
  git default + `merge.log` shortlog.
- 2026-08-15: `Fixes:` trailer kept optional — flow-document content finalized; publication
  placement pending.
- 2026-08-15: Published — options page evolved into the final document (v7 content via
  confluence-md, v8 rename to "Git Flow for the Server Team" via API; title-only publish is not
  supported by the tool). Rationale link now points to page version history. Options draft moved
  to confluence/archive/.
- 2026-08-15: Follow-up conversion ticket FP-45872 created (Story, Server, Internal/Async, Tech
  Debt 2026 Q3): convert the repo to Git on GitLab. First-conversion audit input gathered —
  [fp-server branch inventory](../FP-45872--repo-conversion/artifacts/fp-server-branch-inventory.md) (full SVN
  tree as of 2026-04-08, no MFT20260325/NPN20260602, no SVN-rev metadata, committer dates =
  import dates). Retroactive semver tagging agreed as a separate follow-up after conversion.
- 2026-08-15: Semver follow-up ticket FP-45873 created (Story, Server, Internal/Async, Tech Debt
  2026 Q3; Relates: FP-45872 (JIRA-linked as blocked-by)): go-forward scheme, retroactive release
  tags on the converted repo, Confluence timeline documentation.
