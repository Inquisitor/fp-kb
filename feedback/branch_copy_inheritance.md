---
name: Branch-copy inheritance check
description: Before proposing svn merge, verify whether the fix is already inherited in the Code branch via branch copy
type: feedback
---
Before proposing `svn merge` to carry a commit into the Code branch, verify whether it is already inherited via branch copy.

**Why:** SVN branches in this project are created via `svn copy` from a parent branch at a specific revision. Everything on the parent up to that revision is in the new branch automatically — no merge needed. Attempting to merge an already-inherited revision produces a no-op at best and duplicate `mergeinfo` churn at worst. Posting a `Merged → <BRANCH>` line in a JIRA comment for an inherited fix is a false audit claim.

**How to apply:**
1. Before any `svn merge`, read `<kb>/_index.md` → Branch Roles to get the Code branch creation revision (`<branch> @ <creation-rev> ← <source>:<source-rev>`).
2. If the commit under review is on the source branch at revision `≤ <source-rev>`, it is already in the Code branch. Skip the merge.
3. Verify by running `svn log <Code-branch-URL>/<some-file-touched-by-the-commit>` — the original commit revision should appear in the history (branch copies preserve log).
4. In the JIRA comment, omit the `Merged → <CodeBranch>` line entirely. Do not invent an audit trail for an operation that did not happen.
5. `svn mergeinfo` alone is not sufficient — it does not record branch-copy inheritance. Reliance on it will miss this case.

**When this applies:** every cross-branch close that would normally merge to Code. Cost of the check is one `svn log` lookup on one file — always worth it.
