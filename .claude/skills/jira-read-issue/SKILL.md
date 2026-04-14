---
name: jira-read-issue
description: >
  Read full JIRA issue context into conversation — comments, description, status, timeline.
  Use when user says "посмотри задачу", "ознакомься с задачей", "почитай комментарии к",
  "сверься с JIRA", "что в JIRA по FP-...", or references a JIRA issue key like FP-XXXXX.
argument-hint: "[issue key, e.g. FP-42033]"
---

# Read JIRA Issue

Load full JIRA issue context (description, comments, timeline) into the conversation as readable markdown.

## Steps

### 1. Extract issue key

Get the issue key from `$ARGUMENTS` or from the user's message (e.g., `FP-42033`). If ambiguous, ask.

### 2. Call getJiraIssue MCP tool

Load the tool schema first if needed (`ToolSearch` for `mcp__plugin_atlassian_atlassian__getJiraIssue`), then call:

- `cloudId`: `fishingplanet.atlassian.net`
- `issueIdOrKey`: extracted key
- `expand`: `changelog`
- `fields`: `["summary", "status", "assignee", "resolution", "resolutiondate", "description", "comment"]`
- `responseContentFormat`: `adf`

### 3. Locate the JSON response

- If the MCP result overflowed to a file (you'll see a message with a `.txt` path and "Output has been saved to"), use that path directly.
- If the result is inline JSON, save it to a temp file:
  ```bash
  # Use Bash to write the JSON to a temp file
  cat <<'ENDJSON' > /tmp/jira-<KEY>.json
  <paste the JSON here>
  ENDJSON
  ```

### 4. Run the formatter

```bash
node D:/kb/tools/confluence-md/jira-format.js <path-to-json>
```

Read stdout — this is the formatted briefing with:
- **Header:** issue key, summary, status, assignee, resolution
- **Description:** converted from ADF to markdown
- **Timeline:** status transitions and assignee changes (chronological table)
- **Comments:** all comments with author, date, ID, edited indicator, markdown body (preserves color spans, bold, code, links)

### 5. Present the briefing

The markdown output is now in your context. You have full issue visibility — description, all comments, and status history.

### 6. Error handling

- If the formatter exits with code 1, report the error message. Common causes:
  - `No issue data found in JSON` — MCP returned unexpected structure
  - `Comment field not found` — wrong `fields` parameter in step 2
  - `Unexpected comment structure` — API format may have changed
- If `getJiraIssue` MCP call fails, report the error and do not proceed.