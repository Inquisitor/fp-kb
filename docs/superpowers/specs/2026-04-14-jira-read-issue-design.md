# jira-read-issue — Design Spec

**Date:** 2026-04-14
**Purpose:** Load full JIRA issue context into Claude's conversation — comments (ADF → markdown), description, metadata, and status timeline. One invocation ("посмотри задачу FP-XXXXX") → readable briefing in context.

## Problem

Reading JIRA comments via the Atlassian MCP plugin is painful:

1. No dedicated "get comments" endpoint — must use `getJiraIssue` with `expand=changelog` and `fields=[comment,...]`
2. Response is 50-60KB+ (ADF comment bodies + 25 changelog entries + renderedFields) — overflows into a temp file
3. Comment bodies are Atlassian Document Format (nested JSON), not readable text
4. Extracting and converting requires a subagent + manual JSON parsing — adds 30+ seconds

## Solution: Two Components

### 1. Node.js CLI utility: `jira-format.js`

**Location:** `D:\kb\tools\confluence-md\jira-format.js`
**Rationale:** Lives alongside `confluence-md` to import `toMd()` directly. No intermediate files per comment.

**Interface:**
```
node jira-format.js <input.json>
```
- **Input:** Path to JSON file containing `getJiraIssue` response (schema: `{issues: {totalCount, nodes: [{...}]}}`)
- **Output:** Markdown briefing to stdout (UTF-8)
- **Exit code:** 0 on success, 1 on structural errors

**Extraction logic:**
- `fields.summary` — issue title
- `fields.status.name` + `fields.status.statusCategory.name` — current status
- `fields.assignee.displayName` — current assignee
- `fields.resolution.name` + `fields.resolutiondate` — resolution info
- `fields.description` — ADF → markdown via `toMd()`
- `fields.comment.comments[]` — each comment: `.author.displayName`, `.created`, `.updated`, `.id`, `.body` (ADF → `toMd()`)
- `changelog.histories[]` — filter for status transitions and assignee changes only

**Structure validation:**
The script validates expected JSON paths before processing. Missing or structurally incompatible data produces explicit errors, not silent empty sections:
- Missing `issues.nodes[0]` → error: "No issue data found in JSON"
- Missing `fields.comment` → error: "Comment field not found — check getJiraIssue fields parameter"
- `fields.comment.comments` not an array → error: "Unexpected comment structure — API format may have changed"
- Missing `fields.description` → warning in output: "[No description]"
- Missing `changelog` → Timeline section omitted with note: "[Changelog not available — use expand=changelog]"
- Individual comment ADF conversion failure → `[ADF conversion error: <message>]` in that comment's body, other comments processed normally

**Timeline extraction from changelog:**
```
changelog.histories[] → for each history:
  history.items[] → filter where field === "status" or field === "assignee"
  emit: { date: history.created, author: history.author.displayName, field, from, to }
```
Sort chronologically. Format as markdown table.

### 2. Claude Code skill: `jira-read-issue`

**Triggers:** "посмотри задачу", "ознакомься с задачей", "почитай комментарии к", "сверься с JIRA", "что в JIRA по FP-..."

**Skill steps:**
1. Extract issue key from user message (e.g., `FP-42033`)
2. Call `getJiraIssue` with:
   - `cloudId`: `fishingplanet.atlassian.net`
   - `issueIdOrKey`: extracted key
   - `expand`: `changelog`
   - `fields`: `["summary", "status", "assignee", "resolution", "resolutiondate", "description", "comment"]`
   - `responseContentFormat`: `adf`
3. Save response to temp file (if not already overflow-saved by runtime)
4. Run: `node D:/kb/tools/confluence-md/jira-format.js <path-to-json>`
5. Read stdout — this is the briefing, now in conversation context

## Output Format

```markdown
# FP-42033: [Rod setup][Torch] A torch and sinker are retained after the line breaks when pressing the B key
**Status:** Closed (Done) | **Assignee:** Mykhailo Horishnyi
**Resolution:** Done | **Resolved:** 2026-02-11

## Description
після обриву ліски по клавіші B, на сетапі з торч-оснасткою НЕ втрачаються торч та сінкер.
...

## Timeline
| Date             | Event                                   |
|------------------|-----------------------------------------|
| 2026-02-11 12:04 | → In Progress (Zhanna Melnyk)           |
| 2026-02-11 16:07 | Assignee → Mykhailo Horishnyi           |
| 2026-02-11 16:07 | → Resolved (Stanislav Samoilov)         |
| 2026-02-12 13:27 | → Verified (Mykhailo Horishnyi)         |
| 2026-02-16 12:00 | → Closed (Mykhailo Horishnyi)           |

## Comments (3)

### Stanislav Samoilov — 2026-02-11 15:58 [id:12345]
The problem was that when the player pressed B to cut the line...

### Stanislav Samoilov — 2026-02-11 16:07 [id:12346]
<span style="color: #ff991f">**LBM **</span>@ [15783](https://svn.fishingplanet.com/...): Fix torch and sinker...
- Extracted `CleanupLeader()` from `BreakLeaderLoseTackle`...

### Mykhailo Horishnyi — 2026-02-12 13:27 [id:12347] *(edited 2026-02-12 14:00)*
Перевірено на Steam, qa branch (52149), test server (15784).
```

**Color preservation:** `toMd()` emits `<span style="color: ...">` for ADF `textColor` marks — these are kept as-is in the output. Claude reads them as color annotations.

**Edited indicator:** Shown as `*(edited <date>)*` after the comment ID, only when `updated !== created`.

## Error Handling

| Scenario                      | Behavior                                                                        |
|-------------------------------|---------------------------------------------------------------------------------|
| `getJiraIssue` MCP call fails | Skill reports error, does not proceed                                           |
| JSON structure mismatch       | `jira-format.js` exits with code 1 + explicit error message naming what's wrong |
| Individual comment ADF fails  | That comment shows `[ADF conversion error]`, rest processed normally            |
| No comments exist             | "Comments (0)" — valid state, not an error                                      |
| No changelog in response      | Timeline section shows "[Changelog not available]"                              |
| Description missing           | Shows "[No description]"                                                        |

## Future Extensibility

The Node.js utility is the foundation for a broader Atlassian toolset:
- Additional formatters (e.g., sprint reports, linked issues graph)
- Could evolve into a standalone CLI alongside `confluence-md`
- `toMd()` is already shared infrastructure
