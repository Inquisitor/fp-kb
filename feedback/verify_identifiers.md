---
name: Verify identifiers, never substitute placeholders
description: When an external identifier (URL, account ID, repo name, file path, host) is unknown at command time, run the trivial verify step first; never substitute a "looks plausible" placeholder like `https://svn.example/` or `user@example.com`
type: feedback
---
When you don't know a concrete identifier — URL, account ID, repo name, file path, host, branch name, table name — **do not** fill in a plausible-looking placeholder. Run the cheap verify step first, then call the real command.

Examples of the failure mode and the fix:
- Unknown SVN URL → ran `svn log https://svn.example/branches/...` (placeholder URL). Fix: `svn info` first, then real URL. Or skip the URL — `svn log` works on the working copy without one.
- Unknown JIRA account ID → don't make up an `accountId`. Use `lookupJiraAccountId` first.
- Unknown DB connection / schema → don't infer from code. Query via the available DB-access MCP, or read the migrations.
- Unknown file path → don't reason about it. Use `Glob` or `Read` first.

**Why:** This is a recurring LLM failure mode — instead of asking/checking, the model plugs in a syntactically reasonable placeholder. The command then fails confusingly (`svn: Unable to connect`, `404`, `null reference`), wastes a turn, and the user notices the made-up identifier in transcript review.

**How to apply:** When composing a command and you reach for an external identifier you don't have in context: stop, run the trivial lookup, then proceed. The lookup is almost always one tool call; the placeholder costs at minimum one wasted command and a credibility hit.
