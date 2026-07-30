# Commit Discovery

The Phase 2 VCS audit re-checks the executor because a naive task lookup can diverge from the branch's real state, for two non-adversarial reasons:

- **Executor discipline** — a commit may be unposted in JIRA, carry the wrong JIRA id, carry none, or be reverted/redone by the executor. Re-checked preventively at intake (Pitfalls 1-4).
- **Review lag (drift)** — while a task sits in review, the reviewed code can be rewritten by a *later* commit, often a follow-up bugfix under a *different* task. The diff then no longer matches HEAD (Pitfall 5).

Both show the same symptom — the diff and the branch/HEAD disagree — and neither is settled by grepping the task id. Confirm against branch state.

## Pitfall 1: Executor forgot to post commit info to JIRA

Commit was made on the branch but not announced in JIRA comments. Default Phase 2 audit (`svn log -r <low>:HEAD <branch-URL> | grep "FP-XXXXX"`) catches this — found commits that aren't in JIRA become an executor-quality finding.

**Fallback if discovery feels sparse:** AskUserQuestion to scan executor's commits in the time window `created..resolved`, present candidates for manual review.

## Pitfall 2: Commit message references the wrong JIRA-ID

Commit references FP-XXXXX in message but the actual change belongs to FP-YYYYY (typo, copy-paste from previous task, etc.). Default audit picks this up only if the wrong ID matches the task being reviewed.

**Mitigation:** cross-validate found commits via `svn diff -c <rev> --summarize` — if files don't relate to the task topic, flag for user. User can drop unrelated commits from scope.

## Pitfall 3: Commit message has no JIRA-ID at all

Truly orphaned commit — only findable via author + time-window scan (`svn log <branch-URL> -l <N> --search <executor-name>` or similar). High false-positive rate; the scan returns commits unrelated to the review.

The skill offers: "Found N other commits by `<executor>` in this window. Review manually?" — but does not auto-include in scope.

## Pitfall 4: A found commit was later reverted by the executor

Whether a revert is findable by `grep FP-XXXXX` is the author's choice of message — it may cite the reverted revision (`"Revert r16158..."`), the task, or neither. The grep finds only the ones carrying the id; when the revert omits it, the grep returns the original add alone and the review concludes the fix is present when the branch no longer carries it.

Dangerous when the branch is a release branch — the grep's false "fix present" turns into a false coverage / release-readiness call.

Caught cheaply by protocol layer 3 below — but only for a revert of a *found* revision; a revert of a commit that discipline already hid (Pitfalls 1-3) surfaces only at layer 4.

## Pitfall 5: Reviewed code changed after the commit (review lag)

A long-open review can target a commit whose code a *later* commit has since rewritten — often a bugfix under a different task (the feature shipped, introduced a bug, users filed it, it was fixed). The reviewer sees the change in the task diff but not on disk/HEAD and cannot explain the mismatch. This is drift, not a missing or reverted commit — confirm by the touched file's full history (which later revision and task changed it), not by re-searching this task. (The WC-freshness check in Phase 2 Step 1 covers the narrower case where the local WC is merely stale; this is the case where HEAD itself has moved past the reviewed revision.)

## Discovery protocol (layered)

Layers 1-3 are the preventive baseline run at intake; escalate to 4-5 only on a discrepancy signal (below). No single layer is complete — message content is the author's choice — so the baseline is minimally sufficient *in the absence of a signal*, not a guarantee.

1. **Executor-listed commits** — look up each revision the executor posted in JIRA (`svn log -v -r <rev>`); confirm it exists and touches task-relevant files.
2. **Grep by task id (parallel)** — `svn log -r <low>:HEAD <branch-URL> | grep "FP-XXXXX"` per plausible branch. Cross-check with layer 1: in-JIRA-not-in-VCS and in-VCS-not-in-JIRA are executor-quality notes.
3. **Mention-search of the found revisions** — for each revision from layers 1-2, grep the branch log for its number (`svn log <branch-URL> | grep -E "16158"`). Catches reverts and follow-ups that cite a revision instead of the task id — the Pitfall-4 revert, for free. Blind to a revert of a revision that layers 1-2 never found.
4. **File history (on a discrepancy signal)** — full history of the files the found commits touched (`svn log -v <branch>/<file>`): reveals reverts named by neither id, later rework (Pitfall 5), or a fix that never landed.
5. **Module heuristic (last resort)** — if KB module cards or recon name the files a fix *would* touch, scan their history. Highest false-positive rate; only when a change is strongly believed to exist but layers 1-4 did not find it.

**Escalation signals for layers 4-5** (not taste): HEAD content contradicts "fix present"; the diff does not cover what the task describes; commit count / scope does not match the task's size; a delegate reads a pre-fix state.

**For any "fix is present on release branch X" claim, always confirm by branch state** — full file history, or a fix-marker `svn cat` on X's HEAD — never by the task grep alone. An add commit existing is not the fix being on the branch.
