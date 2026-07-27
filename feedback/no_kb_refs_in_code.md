---
name: No KB references outside KB
description: Source code and outward-facing artifacts (JIRA, Confluence, commit messages) must never reference KB paths, notes, review cards, or agent-investigation framing
type: feedback
---

Source code (production .cs, .sql, etc.) must not contain pointers to KB artifacts. This includes paths
like `reference/foo.md`, phrases like "see KB note on X", or any reference to internal documentation
structure. Applies to inline comments, XML-doc `<remarks>`, file headers -- every textual surface in code.

**Extended scope:** the same ban covers all outward-facing artifacts -- JIRA issues and comments,
Confluence pages, commit messages. No KB paths, no "see the review card", no "during the
review/investigation of X we found" framing that leans on internal agent-review artifacts. State the
product-level facts directly instead.

**Why:** KB is a navigation layer that lives independently of the versioned codebase. KB paths drift on
their own schedule; embedding pointers creates rot no diff will catch. Outward artifacts may be read by
people with zero access to (or context of) the KB -- a reference is dead weight at best, confusing at
worst. Every artifact must stand on its own.

**How to apply:** When tempted to write "see `kb/path/to/doc.md`", "see KB on X", or "found during the
review" in code, JIRA, Confluence, or a commit message -- inline the relevant product-level context
directly instead. KB references belong ONLY in KB-internal artifacts (journals, plans, module cards,
review cards). Cross-checks: search for `kb/` or `reference/` strings in diffs before commit; re-read
JIRA drafts for investigation/review framing before posting; flag in code review.
