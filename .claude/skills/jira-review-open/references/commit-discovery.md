# Commit Discovery — Pitfalls

Three common attribution problems in JIRA review and their mitigations.

## Pitfall 1: Executor forgot to post commit info to JIRA

Commit was made on the branch but not announced in JIRA comments. Default Phase 2 audit (`svn log -r <low>:HEAD <branch-URL> | grep "FP-XXXXX"`) catches this — found commits that aren't in JIRA become an executor-quality finding.

**Fallback if discovery feels sparse:** AskUserQuestion to scan executor's commits in the time window `created..resolved`, present candidates for manual review.

## Pitfall 2: Commit message references the wrong JIRA-ID

Commit references FP-XXXXX in message but the actual change belongs to FP-YYYYY (typo, copy-paste from previous task, etc.). Default audit picks this up only if the wrong ID matches the task being reviewed.

**Mitigation:** cross-validate found commits via `svn diff -c <rev> --summarize` — if files don't relate to the task topic, flag for user. User can drop unrelated commits from scope.

## Pitfall 3: Commit message has no JIRA-ID at all

Truly orphaned commit — only findable via author + time-window scan (`svn log <branch-URL> -l <N> --search <executor-name>` or similar). High false-positive rate; the scan returns commits unrelated to the review.

The skill offers: "Found N other commits by `<executor>` in this window. Review manually?" — but does not auto-include in scope.

## Default approach

Trust JIRA comments + `svn log | grep`. Fall back to time-window scan only when:
- User signals discrepancy ("there should be more commits than shown")
- Skill detects suspicious sparseness (e.g., a feature task has only one commit but description suggests larger work)

Aggressive scanning is reserved for cases where analysis reveals something missing — not a default behavior. The cost of false positives (manual review of unrelated commits) outweighs the benefit when the task is clean.
