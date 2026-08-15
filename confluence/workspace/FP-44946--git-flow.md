---
page_id: "5768642569"
section: tech-guidelines/server/infrastructure
related_tasks:
  - FP-44946
---
# Git Flow for the Server Team

This document is prescriptive: it describes how the server team works in Git after the migration from SVN. Alternatives considered and the rationale behind these decisions: FP-44946 and [earlier versions of this page](https://fishingplanet.atlassian.net/wiki/pages/viewpreviousversions.action?pageId=5768642569) — up to v6 this page was the Options document comparing the candidate history models.

## Branch model

- Long-lived branches: **Dev** (main development), **Content** (content/balance stabilization), and released branches in hotfix mode until EOL. Target state is at most Dev + Content in parallel plus the released branch; several live old-stable branches at once is a situation to avoid, not to plan for.
- **History model: first-parent linear.** Task branches land linearly (fast-forward); merges between long-lived branches are real merge commits. `git log --first-parent` on any long-lived branch reads the way the SVN branch log reads today: a chain of task commits plus hotfix intake points.
- **Merge direction** (unchanged from SVN): Released -> Content -> Dev, always upward. Nothing merges downward; a downward transfer, when unavoidable, is an explicit `git cherry-pick -x`, and the change then travels upward normally from there.
- **Structural merges** between long-lived branches are a privileged operation: a maintainer merges locally and pushes to the protected branch directly; they do not go through a task MR. Merge commits use git's default subject (`Merge branch 'X' into Y`) plus the auto-generated shortlog of merged commit subjects (`merge.log`, see Toolbox) — with the FP-ID subject convention, the merge commit itself lists which tasks arrived, reproducing the SVN merge-message habit without hand-authoring. Full original messages are not embedded: unlike SVN, the merged commits are part of the target branch history, `git log <merge>^1..<merge>` shows them in full.

## Task branches

- One task = one branch = one owner. Branch from the long-lived branch the task targets (normally Dev). Keep branches short-lived. Naming: `fp-12345-short-slug`.
- Keep the branch current by **rebasing** onto its base. Force-push only with `--force-with-lease`. Enable `git rerere` once per clone — conflicts resolved during one rebase re-apply automatically on the next. Reviewers use `git range-diff` to see what actually changed between two versions of a rebased branch.
- Landing is **via MR only**; direct pushes to long-lived branches are disabled for task work (structural merges excepted, see Branch model).
- **Landing style: fast-forward only.** Choose the content mode per task:
  - **Squash** — the default for small or messy branches. The branch lands as one commit; the final message is written at merge time and follows the commit convention. The branch itself may be WIP-grade, nobody curates it.
  - **Curated commits** — for tasks that benefit from separation (preparatory refactoring vs the behavior change). The branch history is curated (`git rebase -i`, `git commit --fixup` + `git rebase --autosquash`, `git add -p`) and lands as-is. Every commit follows the commit convention.
- CI runs on the rebased branch before landing. With fast-forward landing, the tested tree is byte-identical to what the mainline receives.

## Commit convention

The message format carries over from SVN, with one simplification: body bullets are plain markdown-style `-` list items — the old `+/-/=/*` prefix classification is dropped.

```
FP-#####: [<Topic>] <summary>
- change description
- change description
(<task type>: <JIRA summary>)
<JIRA link>
```

Every commit subject starts with the JIRA ID and `[Topic]`. Bullets and the trailer block are used when the commit is large enough to benefit; a small curated commit may carry the subject line only.

- **`[NFC]` marker** (*No Functional Change*, LLVM convention): behavior-neutral commits — refactoring, renames, moves, formatting, comment and doc edits — carry `[NFC]` after the topic: `FP-12345: [Matchmaking][NFC] Extract queue rebuild into a helper`. Consumers: reviewers (lighter review pass), `git bisect` (skip candidates), history filtering (`git log --grep="\[NFC\]" --invert-grep` shows behavior-only history).
- **NFC discipline**: the marker is a claim, not a proof. An NFC commit must not change test expectations; reviewers verify code moves with `git diff --color-moved`. When in doubt, do not mark.
- In a curated branch, preparatory NFC commits go **before** the behavior change: make the change easy, then make the easy change.
- **Unrelated cleanup does not ride in a task branch.** Opportunistic tidying beyond the task's blast radius goes to its own small MR under the standing quarterly Tech Debt ticket.
- Optional: a hotfix commit may carry a `Fixes: <sha> ("<subject>")` trailer (kernel convention) naming the commit that introduced the bug — it makes affected-branch reasoning instant.
- **Enforcement**: the platform validates the first message line with a push rule / commit-message pattern. Allowed forms — task commit, structural merge, protocol increment: `^(FP-\d+: \[\w+\]|Merge |\[\w+\] Increment (major|minor) protocol version)`. The increment alternative matches the established convention, e.g. `[MFT] Increment minor protocol version after the 2026.4.2 FTUE (Consoles) release: 1125.1 -> 1125.2`.

## Hotfix flow

- The fix is committed on the released branch (through an MR into it; the same ff rules apply there).
- It propagates upward with structural merges: Released -> Content -> Dev. Git's merge tracking replaces `svn:mergeinfo`: a repeated merge picks up only the delta, and "did the fix reach Dev?" is answered by the graph — `git branch --contains <sha>` lists every branch that already has it.
- Downward transfer is exceptional: `git cherry-pick -x` (keeps the origin SHA in the message), and the change then travels upward normally.

## Release cycle

- **Branch cut**: a new long-lived branch is created from Dev at a tagged point. The cut is a single ref creation — cut early, the moment a new release topic needs separation or Dev transitions toward release stabilization; delaying the cut buys nothing anymore.
- **Role rotation** (Dev -> Content -> Released) is a change of branch protection rules and pointers, not a data operation.
- **Tags**: annotated tags at every protocol-version increment (major and minor) and at release boundaries. One branch can host several releases; tags mark the in-branch boundaries (the protocol-increment commit is the natural tag point).

## SVN-Git transition period

- The Git branch mirrored to SVN is **append-only**: no rebase, no force-push, ever — sync tooling does not survive history rewrites. All rewriting happens on Git-only task branches; landings arrive as appended commits.
- Released branches stay in SVN until their EOL; fixes made there reach Git through the existing SVN merge path into the mirrored branch.

## Platform requirements

Feeds the "Choose Git platform" workstream:

- Enforced fast-forward-only merge method for task MRs; per-MR squash option.
- Protected long-lived branches: MR-only for task work, direct push allowed for maintainers (structural merges).
- Commit-message pattern enforcement (push rule / ruleset) with the allowed-forms pattern from the commit convention.
- Rebase UX in the MR flow (one-click rebase or an equally clean local flow).
- Merge queue: not required at the current team size; nice-to-have as the team grows.

## Toolbox (one-time setup per clone)

- `git config rerere.enabled true` — remember and re-apply conflict resolutions across rebases.
- `git config merge.log 500` — structural merge messages list the subjects of merged commits (the default cap of 20 truncates bulk merges).
- `git config alias.lg "log --first-parent --oneline"` — the SVN-style branch log.
- `git worktree add ../<branch> <branch>` — sibling-folder layout, one clone with several checked-out branches, matching today's on-disk habits.
- `git push --force-with-lease` — the only allowed force-push form.
- `git range-diff` — compare two versions of a rebased branch during re-review.
