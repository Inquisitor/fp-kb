---
page_id: "5768642569"
section: tech-guidelines/server/infrastructure
related_tasks:
  - FP-44946
---
# Git Flow for the Server Team: Options

Prepared for the server team meeting on 2026-07-14 (FP-44946). Decisions needed: the history model for the Git migration (Option A vs Option B below) and the landing style for task branches.

## Context

- The migration starts with the Dev branch; SVN remains authoritative for the older release branches (hotfix mode) until their EOL.
- Related workstreams, tracked separately: Git platform choice, SVN-Git sync restoration, pilot deploy from a Git branch.

## Goals

Carried over from current SVN practice and the migration discussion:

- **Linear, readable history per long-lived branch** — a branch log should read the way the SVN log reads today.
- **Few long-lived branches** — Code + Content in parallel, plus a released branch in hotfix mode. Situations with several live old-stable branches at once are to be avoided going forward.
- **Hotfixes are made on the released branch and propagate upward** (Released -> Content -> Code); never merged downward. A downward transfer, when unavoidable, is an explicit cherry-pick, and the change then travels upward normally.
- **Task branches are rebased onto their base** until ready, then land atomically.
- **The SVN-mirrored branch is append-only** — sync tooling does not survive history rewrites.

## Shared foundation (independent of the option chosen)

- **One task = one branch = one owner**, short-lived, branched from Dev. Rebasing stays cheap, and nobody rewrites a branch someone else is standing on.
- **Landing only via MR/PR into protected branches**; direct pushes disabled. Linearity is enforced by the server, not by discipline — all major platforms (GitLab, GitHub, Azure DevOps, Bitbucket) support this as a repository setting.
- **`git push --force-with-lease`** (never bare `--force`) — a rebase-and-push cannot silently overwrite a colleague's commits.
- **`git rerere`** — a conflict resolved once is re-applied automatically on every later rebase of the same branch.
- **`git range-diff`** — reviewers see what actually changed between two versions of a rebased branch.
- **Annotated tag at every protocol-version increment** — release boundaries become addressable (`git describe`, diff between releases).
- **`git worktree`** — one clone, several checked-out branches in sibling folders; preserves the current working layout on disk.
- **CI runs on the rebased branch before landing** — with linear landing, the tested tree is byte-identical to what the mainline receives (no "tested one thing, merged another").

## Option A — first-parent linear history

Task branches land linearly; structural merges between long-lived branches remain real merge commits — the SVN merge direction, expressed in Git.

```
Released ---*--h1---------*------------------>      h  = hotfix commit
             \             \
Content       *--c1--c2-----M1--*------------>      M  = structural merge (real merge commit)
               \                 \
Code (Dev)      *--f1--f2--f3-----M2--f4----->      f  = task-branch commits landed linearly
```

- **Reading history**: `git log --first-parent` on any long-lived branch shows the SVN-style linear story — task landings plus hotfix intake points. Graph tools show the rails, but the first-parent line is straight.
- **Merge tracking is native**: git knows which commits arrived via M1/M2; a repeated merge picks up only the delta. This is the direct replacement for `svn:mergeinfo`.
- **Hotfix flow**: fix lands on Released; `git merge` Released into Content, then Content into Code — the same ceremony as today's SVN merges, same direction.

Pros:

- Semantics match the current SVN process one-to-one; no retraining of the mental model.
- Fix propagation is bookkept by git itself: "is h1 in Code?" is answered by the graph, not by an audit procedure.
- A conflict surfaces exactly once, at the structural merge, in full context.
- Reverting a propagated fix on a branch = reverting one merge commit.

Cons:

- The commit graph is not a single straight line; the team must adopt the `--first-parent` reading habit (a log alias fixes this).
- Structural merge commits need meaningful messages (mirroring today's SVN merge-commit convention).

## Option B — strictly linear history everywhere

No merge commits at all. Task branches land linearly, and cross-branch propagation is done with cherry-picks in both directions.

```
Released ---*--h1---------------------------->
             \
Content       *--c1-*-h1'--c2---------------->      h1'  = copy of h1, different SHA
                     \
Code (Dev)            *--f1--h1''--f2--c2'--->      h1'' = another copy
```

> Note: no graph edges connect `h1 -> h1' -> h1''` (or `c2 -> c2'`) — cherry-picked copies are unrelated commits; the only trace is the `-x` message trailer. That absence is the cost of Option B: merge tracking is gone, and whether a fix reached a branch is invisible to the tool.

- Every branch log is a perfectly straight line natively.

Required process and tooling to stay safe:

- `git cherry-pick -x` everywhere — stamps `(cherry picked from commit ...)` into the message; the only propagation trace.
- Periodic audit — `git log --left-right --cherry-pick Released...Code` (or `git cherry`) to list fixes that never travelled upward; someone must own running it.
- A propagation checklist per hotfix — effectively a hand-maintained replacement for `svn:mergeinfo`.

Pros:

- The simplest possible log on every branch; graph tools show a straight line with no rails.
- No merge commits to name or read.

Cons:

- Propagation safety rests on process, not on the tool. A forgotten cherry-pick of an anticheat/security-sensitive fix fails **silently** — nothing in git flags it.
- A cherry-pick can apply cleanly into a diverged context and still be wrong (semantic drift); a real merge would have surfaced the divergence as a conflict.
- Reverting a propagated fix means finding and reverting every copy separately.

## Comparison

| Dimension                          | A: first-parent                     | B: strictly linear                  |
|------------------------------------|-------------------------------------|-------------------------------------|
| Branch log readability             | straight via `--first-parent` alias | straight natively                   |
| Fix propagation tracking           | native (merge graph)                | manual (`-x` trailers + audits)     |
| "Did the fix reach Dev?"           | answered by git                     | answered by an audit procedure      |
| Closeness to current SVN process   | merge-up preserved                  | merges replaced with copies         |
| Extra tooling required             | a log alias                         | audit script + checklist + owner    |
| Conflict surfacing                 | once, at the structural merge       | per cherry-pick, may pass silently  |
| Reverting a propagated fix         | revert the merge commit             | hunt down every copy                |

## Recommendation

**Option A.** It keeps the semantics the team already trusts from SVN, lets git itself carry the bookkeeping that `svn:mergeinfo` used to carry, and needs no custom tooling. Option B buys a prettier graph at the cost of a hand-maintained propagation process — precisely the failure mode (a silently missed fix) the flow should design away, given that hotfixes routinely travel through several branches.

## Sub-decision within Option A: how task branches land

Each style keeps the first-parent line straight; platforms enforce any of them as a repository setting.

- **Fast-forward only** — the rebased task branch is fast-forwarded onto Dev. Individual commits become the mainline; no trace of the branch boundary. Cleanest line; reverting a whole task means reverting a commit range.
- **Semi-linear** (`rebase`, then merge with `--no-ff`) — history stays railroad-straight, and each task gets a single boundary commit: `git revert -m 1` rolls back the whole task, and the MR/task reference lives on the boundary commit.
- **Squash** — the task branch collapses into a single commit on Dev. Matches today's one-commit-per-task SVN granularity exactly; intra-task history is discarded (it survives in the MR on the platform).

Squash is the closest match to how the team commits in SVN today; semi-linear preserves intra-task commits when they carry value. Worth a show of hands at the meeting.

## Release-cycle mapping

| Today (SVN)                                          | In Git                                                          |
|------------------------------------------------------|-----------------------------------------------------------------|
| New branch cut (new release topic / Code -> Content) | `git branch` from Dev at a tagged point — a single ref, instant |
| Branch role rotation                                 | protection rules + default-branch pointer update                |
| Minor protocol version increment after release       | commit + annotated tag                                          |
| Upward hotfix merges (Released -> Content -> Code)   | Option A: `git merge`; Option B: cherry-pick chain              |
| `svn:mergeinfo`                                      | Option A: merge graph; Option B: `-x` trailers + audit          |
| Branch folders side by side on disk                  | `git worktree` — one clone, several working dirs                |

A side effect worth noting: cutting a branch becomes a single ref creation instead of an infrastructure event, so the historical failure mode "delayed the cut, caused problems" loses its cause — cutting early costs nothing.

## Constraints during the SVN-Git transition

- The Git branch mirrored to SVN is **append-only**: no rebase, no force-push, ever. All history rewriting happens on Git-only task branches; landings arrive as appended commits. Either option satisfies this, and the final flow document must state it as a hard rule.
- Older release branches stay in SVN until EOL; fixes made there reach the Git side through the existing SVN merge path into the mirrored branch.

## Decisions needed at the meeting

- History model: Option A or Option B.
- Landing style for task branches (within A): fast-forward / semi-linear / squash.
- Confirm the hotfix convention stays "fix on the released branch, merge upward". The alternative — fix on Dev first, cherry-pick down to the release branch (as practiced by e.g. Microsoft Release Flow) — is listed for completeness: it guarantees the fix is present in the next release by construction, at the cost of extra ceremony on the release side.
- Platform requirements that follow from the choices (enforced merge method, protected branches, rebase UX, merge-queue availability) — feed into the "Choose Git platform" workstream.
