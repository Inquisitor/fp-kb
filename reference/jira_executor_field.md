---
name: JIRA Executor field
description: customfield_11224 = "Executor" (userpicker) in FP project — pointer for review workflow detect-only hygiene nudge
type: reference
---
JIRA "Executor" field in the Fishing Planet project is a custom user-picker field, distinct from Assignee/Reporter/Creator.

- **Field ID:** `customfield_11224`
- **Type:** `com.atlassian.jira.plugin.system.customfieldtypes:userpicker`
- **Display name:** `Executor`

**Distinct from:**
- `assignee` — often the reviewer, not the implementer
- `reporter` — typically the bug reporter (QA/PM)
- `creator` — whoever opened the ticket
- `customfield_11224` (Executor) — the actual implementer (commit author)

**How to read:** include `"customfield_11224"` in the `fields` array of `getJiraIssue`. The default `jira-read-issue` skill drops custom fields, so this must be requested explicitly. Use `expand=names,schema` once per session if uncertain about the mapping.

**How to apply (review workflow Phase 1):** if `customfield_11224` is empty, surface a one-line nudge — `⚠ Executor field empty (expected: <commit author from JIRA comment>)`. Do NOT block, do NOT auto-fill, do NOT AskUserQuestion. The user decides whether to fill.
