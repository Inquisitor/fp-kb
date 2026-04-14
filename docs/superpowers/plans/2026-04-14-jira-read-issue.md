# jira-read-issue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Node.js utility + Claude Code skill that loads full JIRA issue context (comments, description, timeline) into Claude's conversation as readable markdown.

**Architecture:** A `jira-formatter.js` library module (testable logic) + `jira-format.js` CLI entry point, both living alongside the existing `confluence-md` tool. A Claude Code skill orchestrates the MCP call → JSON → CLI → markdown pipeline.

**Tech Stack:** Node.js (ESM), `node:test`, imports `toMd()` from `confluence-md/lib/to-md.js`

**Spec:** `docs/superpowers/specs/2026-04-14-jira-read-issue-design.md`

---

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `tools/confluence-md/lib/jira-formatter.js` | Core logic: validate JSON, extract fields, convert ADF, build markdown |
| Create | `tools/confluence-md/jira-format.js` | CLI entry point: read file, call `formatJiraIssue()`, write stdout |
| Create | `tools/confluence-md/test/jira-formatter.test.js` | Unit tests for all formatting functions |
| Create | `tools/confluence-md/test/fixtures/jira-issue-minimal.json` | Minimal JIRA response fixture for tests |
| Create | Skill file (location TBD via writing-skills) | Claude Code skill: orchestrate MCP → JSON → CLI → context |

---

### Task 1: Test fixture and structure validation

**Files:**
- Create: `tools/confluence-md/test/fixtures/jira-issue-minimal.json`
- Create: `tools/confluence-md/test/jira-formatter.test.js`
- Create: `tools/confluence-md/lib/jira-formatter.js`

- [ ] **Step 1: Create minimal test fixture**

Create `tools/confluence-md/test/fixtures/jira-issue-minimal.json` — a minimal but structurally complete JIRA `getJiraIssue` response:

```json
{
  "issues": {
    "totalCount": 1,
    "nodes": [{
      "key": "FP-99999",
      "fields": {
        "summary": "Test issue summary",
        "status": {
          "name": "In Progress",
          "statusCategory": { "name": "In Progress" }
        },
        "assignee": { "displayName": "John Doe" },
        "resolution": null,
        "resolutiondate": null,
        "description": {
          "type": "doc", "version": 1,
          "content": [{ "type": "paragraph", "content": [
            { "type": "text", "text": "Issue description text." }
          ]}]
        },
        "comment": {
          "total": 2,
          "comments": [
            {
              "id": "10001",
              "author": { "displayName": "Alice" },
              "created": "2026-03-01T10:00:00.000+0200",
              "updated": "2026-03-01T10:00:00.000+0200",
              "body": {
                "type": "doc", "version": 1,
                "content": [{ "type": "paragraph", "content": [
                  { "type": "text", "text": "First comment." }
                ]}]
              }
            },
            {
              "id": "10002",
              "author": { "displayName": "Bob" },
              "created": "2026-03-02T14:30:00.000+0200",
              "updated": "2026-03-02T15:00:00.000+0200",
              "body": {
                "type": "doc", "version": 1,
                "content": [{ "type": "paragraph", "content": [
                  { "type": "text", "text": "Edited comment with " },
                  { "type": "text", "text": "bold", "marks": [{ "type": "strong" }] },
                  { "type": "text", "text": " and " },
                  { "type": "text", "text": "code", "marks": [{ "type": "code" }] },
                  { "type": "text", "text": "." }
                ]}]
              }
            }
          ]
        }
      },
      "changelog": {
        "histories": [
          {
            "created": "2026-03-01T09:00:00.000+0200",
            "author": { "displayName": "Alice" },
            "items": [
              { "field": "status", "fromString": "To Do", "toString": "In Progress" },
              { "field": "assignee", "fromString": null, "toString": "John Doe" }
            ]
          },
          {
            "created": "2026-03-02T16:00:00.000+0200",
            "author": { "displayName": "Bob" },
            "items": [
              { "field": "status", "fromString": "In Progress", "toString": "Resolved" },
              { "field": "priority", "fromString": "Medium", "toString": "High" }
            ]
          }
        ]
      }
    }]
  }
}
```

- [ ] **Step 2: Write tests for structure validation**

Create `tools/confluence-md/test/jira-formatter.test.js`:

```javascript
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { formatJiraIssue } from '../lib/jira-formatter.js';

describe('formatJiraIssue — structure validation', () => {
  it('throws on empty JSON', () => {
    assert.throws(() => formatJiraIssue({}), /No issue data found/);
  });

  it('throws on missing nodes', () => {
    assert.throws(() => formatJiraIssue({ issues: { nodes: [] } }), /No issue data found/);
  });

  it('throws on missing comment field', () => {
    const json = {
      issues: { totalCount: 1, nodes: [{ key: 'X-1', fields: { summary: 'x' } }] }
    };
    assert.throws(() => formatJiraIssue(json), /Comment field not found/);
  });

  it('throws on malformed comment structure', () => {
    const json = {
      issues: { totalCount: 1, nodes: [{ key: 'X-1', fields: {
        summary: 'x',
        comment: { total: 0 }  // missing .comments array
      }}] }
    };
    assert.throws(() => formatJiraIssue(json), /Unexpected comment structure/);
  });
});
```

- [ ] **Step 3: Run tests — verify they fail**

Run: `cd D:/kb/tools/confluence-md && node --test test/jira-formatter.test.js`
Expected: FAIL — `formatJiraIssue` not found (module doesn't exist yet)

- [ ] **Step 4: Implement structure validation**

Create `tools/confluence-md/lib/jira-formatter.js`:

```javascript
// JIRA issue JSON → readable markdown briefing.
// Designed for getJiraIssue responses from Atlassian MCP plugin.

import { toMd } from './to-md.js';

/**
 * Format a JIRA issue JSON response into a readable markdown briefing.
 * @param {object} json - Full getJiraIssue response ({issues: {totalCount, nodes: [...]}})
 * @returns {string} Formatted markdown
 */
export function formatJiraIssue(json) {
  const issue = extractIssue(json);
  const fields = issue.fields;
  validateComments(fields);

  const parts = [];
  parts.push(formatHeader(issue));
  parts.push(formatDescription(fields));
  parts.push(formatTimeline(issue));
  parts.push(formatComments(fields));

  return parts.join('\n\n') + '\n';
}

// --- extraction & validation ---

function extractIssue(json) {
  const node = json?.issues?.nodes?.[0];
  if (!node) {
    throw new Error('No issue data found in JSON');
  }
  return node;
}

function validateComments(fields) {
  if (!fields.comment) {
    throw new Error('Comment field not found — check getJiraIssue fields parameter');
  }
  if (!Array.isArray(fields.comment.comments)) {
    throw new Error('Unexpected comment structure — API format may have changed');
  }
}

// --- formatters (stubs, implemented in subsequent tasks) ---

function formatHeader(issue) {
  return `# ${issue.key}: ${issue.fields?.summary || '[No summary]'}`;
}

function formatDescription() {
  return '## Description\n[stub]';
}

function formatTimeline() {
  return '## Timeline\n[stub]';
}

function formatComments() {
  return '## Comments\n[stub]';
}
```

- [ ] **Step 5: Run tests — verify they pass**

Run: `cd D:/kb/tools/confluence-md && node --test test/jira-formatter.test.js`
Expected: 4 tests PASS

- [ ] **Step 6: Commit**

```
Add jira-formatter with structure validation
+ `lib/jira-formatter.js` — `formatJiraIssue()` with JSON structure validation
+ `test/jira-formatter.test.js` — tests for empty/missing/malformed input
+ `test/fixtures/jira-issue-minimal.json` — minimal JIRA response fixture
```

---

### Task 2: Header and description formatting

**Files:**
- Modify: `tools/confluence-md/lib/jira-formatter.js`
- Modify: `tools/confluence-md/test/jira-formatter.test.js`

- [ ] **Step 1: Write tests for header and description**

Append to `test/jira-formatter.test.js`:

```javascript
import { readFileSync } from 'node:fs';

const fixture = JSON.parse(
  readFileSync(new URL('./fixtures/jira-issue-minimal.json', import.meta.url), 'utf-8')
);

describe('formatJiraIssue — header', () => {
  const md = formatJiraIssue(fixture);

  it('starts with issue key and summary as H1', () => {
    assert.ok(md.startsWith('# FP-99999: Test issue summary'));
  });

  it('contains status with category', () => {
    assert.ok(md.includes('**Status:** In Progress (In Progress)'));
  });

  it('contains assignee', () => {
    assert.ok(md.includes('**Assignee:** John Doe'));
  });

  it('omits resolution line when resolution is null', () => {
    assert.ok(!md.includes('**Resolution:**'));
  });
});

describe('formatJiraIssue — header with resolution', () => {
  const resolved = structuredClone(fixture);
  resolved.issues.nodes[0].fields.resolution = { name: 'Done' };
  resolved.issues.nodes[0].fields.resolutiondate = '2026-03-05T12:00:00.000+0200';
  const md = formatJiraIssue(resolved);

  it('shows resolution and date', () => {
    assert.ok(md.includes('**Resolution:** Done'));
    assert.ok(md.includes('**Resolved:** 2026-03-05'));
  });
});

describe('formatJiraIssue — description', () => {
  const md = formatJiraIssue(fixture);

  it('contains Description section', () => {
    assert.ok(md.includes('## Description'));
  });

  it('converts ADF description to markdown', () => {
    assert.ok(md.includes('Issue description text.'));
  });
});

describe('formatJiraIssue — no description', () => {
  const noDesc = structuredClone(fixture);
  noDesc.issues.nodes[0].fields.description = null;
  const md = formatJiraIssue(noDesc);

  it('shows placeholder for missing description', () => {
    assert.ok(md.includes('[No description]'));
  });
});
```

- [ ] **Step 2: Run tests — verify new tests fail**

Run: `cd D:/kb/tools/confluence-md && node --test test/jira-formatter.test.js`
Expected: structure validation tests PASS, new header/description tests FAIL (stubs return `[stub]`)

- [ ] **Step 3: Implement header and description formatting**

Replace the stub `formatHeader` and `formatDescription` in `lib/jira-formatter.js`:

```javascript
function formatHeader(issue) {
  const f = issue.fields;
  const summary = f.summary || '[No summary]';
  const status = f.status?.name || 'Unknown';
  const category = f.status?.statusCategory?.name;
  const assignee = f.assignee?.displayName || 'Unassigned';
  const resolution = f.resolution?.name;
  const resDate = f.resolutiondate ? f.resolutiondate.slice(0, 10) : null;

  let line1 = `# ${issue.key}: ${summary}`;
  let line2 = `**Status:** ${status}`;
  if (category) line2 += ` (${category})`;
  line2 += ` | **Assignee:** ${assignee}`;

  if (resolution) {
    line2 += `\n**Resolution:** ${resolution}`;
    if (resDate) line2 += ` | **Resolved:** ${resDate}`;
  }

  return `${line1}\n${line2}`;
}

function formatDescription(fields) {
  if (!fields.description) {
    return '## Description\n[No description]';
  }
  const { md } = convertAdf(fields.description);
  return `## Description\n${md}`;
}

function convertAdf(adf) {
  try {
    return toMd(adf);
  } catch (err) {
    return { md: `[ADF conversion error: ${err.message}]`, warnings: [] };
  }
}
```

- [ ] **Step 4: Run tests — verify they pass**

Run: `cd D:/kb/tools/confluence-md && node --test test/jira-formatter.test.js`
Expected: all tests PASS

- [ ] **Step 5: Commit**

```
Add header and description formatting to jira-formatter
= `formatHeader()` — status, category, assignee, resolution
= `formatDescription()` — ADF → markdown via `toMd()`, fallback for null
+ Tests for header with/without resolution, description with/without content
```

---

### Task 3: Comment formatting

**Files:**
- Modify: `tools/confluence-md/lib/jira-formatter.js`
- Modify: `tools/confluence-md/test/jira-formatter.test.js`

- [ ] **Step 1: Write tests for comment formatting**

Append to `test/jira-formatter.test.js`:

```javascript
describe('formatJiraIssue — comments', () => {
  const md = formatJiraIssue(fixture);

  it('shows comment count', () => {
    assert.ok(md.includes('## Comments (2)'));
  });

  it('formats comment header with author, date, id', () => {
    assert.ok(md.includes('### Alice — 2026-03-01 10:00 [id:10001]'));
  });

  it('converts comment body ADF to markdown', () => {
    assert.ok(md.includes('First comment.'));
  });

  it('shows edited indicator when updated differs from created', () => {
    assert.ok(md.includes('[id:10002] *(edited 2026-03-02 15:00)*'));
  });

  it('does not show edited indicator when dates match', () => {
    assert.ok(!md.includes('[id:10001] *(edited'));
  });

  it('preserves bold and code marks from ADF', () => {
    assert.ok(md.includes('**bold**'));
    assert.ok(md.includes('`code`'));
  });
});

describe('formatJiraIssue — no comments', () => {
  const empty = structuredClone(fixture);
  empty.issues.nodes[0].fields.comment = { total: 0, comments: [] };
  const md = formatJiraIssue(empty);

  it('shows Comments (0)', () => {
    assert.ok(md.includes('## Comments (0)'));
  });
});

describe('formatJiraIssue — ADF conversion error in comment', () => {
  const bad = structuredClone(fixture);
  bad.issues.nodes[0].fields.comment.comments[0].body = 'not-valid-adf';
  const md = formatJiraIssue(bad);

  it('shows error for broken comment, still formats others', () => {
    assert.ok(md.includes('[ADF conversion error'));
    assert.ok(md.includes('**bold**'));  // second comment still works
  });
});
```

- [ ] **Step 2: Run tests — verify new tests fail**

Run: `cd D:/kb/tools/confluence-md && node --test test/jira-formatter.test.js`
Expected: new comment tests FAIL

- [ ] **Step 3: Implement comment formatting**

Replace the stub `formatComments` in `lib/jira-formatter.js`:

```javascript
function formatComments(fields) {
  const comments = fields.comment.comments;
  if (comments.length === 0) {
    return '## Comments (0)\n(none)';
  }

  const parts = [`## Comments (${comments.length})`];

  for (const c of comments) {
    const author = c.author?.displayName || 'Unknown';
    const created = formatDateTime(c.created);
    const id = c.id;
    let header = `### ${author} — ${created} [id:${id}]`;

    if (c.updated && c.updated !== c.created) {
      header += ` *(edited ${formatDateTime(c.updated)})*`;
    }

    const { md } = convertAdf(c.body);
    parts.push(`${header}\n${md}`);
  }

  return parts.join('\n\n');
}

/** "2026-03-01T10:00:00.000+0200" → "2026-03-01 10:00" */
function formatDateTime(iso) {
  const match = iso.match(/^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})/);
  return match ? `${match[1]} ${match[2]}` : iso;
}
```

- [ ] **Step 4: Run tests — verify they pass**

Run: `cd D:/kb/tools/confluence-md && node --test test/jira-formatter.test.js`
Expected: all tests PASS

- [ ] **Step 5: Commit**

```
Add comment formatting to jira-formatter
= `formatComments()` — author, date, ID, edited indicator, ADF → markdown
= `convertAdf()` — error-tolerant wrapper around `toMd()`
+ Tests for comment metadata, ADF marks, edited indicator, empty list, broken ADF
```

---

### Task 4: Timeline extraction from changelog

**Files:**
- Modify: `tools/confluence-md/lib/jira-formatter.js`
- Modify: `tools/confluence-md/test/jira-formatter.test.js`

- [ ] **Step 1: Write tests for timeline**

Append to `test/jira-formatter.test.js`:

```javascript
describe('formatJiraIssue — timeline', () => {
  const md = formatJiraIssue(fixture);

  it('contains Timeline section', () => {
    assert.ok(md.includes('## Timeline'));
  });

  it('includes status transitions', () => {
    assert.ok(md.includes('→ In Progress (Alice)'));
    assert.ok(md.includes('→ Resolved (Bob)'));
  });

  it('includes assignee changes', () => {
    assert.ok(md.includes('Assignee → John Doe'));
  });

  it('excludes non-tracked fields (priority)', () => {
    assert.ok(!md.includes('High'));
  });

  it('sorts events chronologically', () => {
    const inProgress = md.indexOf('→ In Progress');
    const resolved = md.indexOf('→ Resolved');
    assert.ok(inProgress < resolved, 'In Progress should appear before Resolved');
  });
});

describe('formatJiraIssue — no changelog', () => {
  const noCl = structuredClone(fixture);
  delete noCl.issues.nodes[0].changelog;
  const md = formatJiraIssue(noCl);

  it('shows notice when changelog is missing', () => {
    assert.ok(md.includes('[Changelog not available'));
  });
});
```

- [ ] **Step 2: Run tests — verify new tests fail**

Run: `cd D:/kb/tools/confluence-md && node --test test/jira-formatter.test.js`
Expected: new timeline tests FAIL

- [ ] **Step 3: Implement timeline extraction**

Replace the stub `formatTimeline` in `lib/jira-formatter.js`:

```javascript
function formatTimeline(issue) {
  const changelog = issue.changelog;
  if (!changelog) {
    return '## Timeline\n[Changelog not available — use expand=changelog]';
  }

  const events = [];
  for (const history of changelog.histories || []) {
    const author = history.author?.displayName || 'Unknown';
    for (const item of history.items || []) {
      if (item.field === 'status') {
        events.push({
          date: history.created,
          text: `→ ${item.toString} (${author})`
        });
      } else if (item.field === 'assignee') {
        events.push({
          date: history.created,
          text: `Assignee → ${item.toString || 'Unassigned'}`
        });
      }
    }
  }

  if (events.length === 0) {
    return '## Timeline\n(no status or assignee changes)';
  }

  events.sort((a, b) => new Date(a.date) - new Date(b.date));

  const rows = events.map(e => `| ${formatDateTime(e.date)} | ${e.text} |`);
  return `## Timeline\n| Date | Event |\n|------|-------|\n${rows.join('\n')}`;
}
```

- [ ] **Step 4: Run tests — verify they pass**

Run: `cd D:/kb/tools/confluence-md && node --test test/jira-formatter.test.js`
Expected: all tests PASS

- [ ] **Step 5: Commit**

```
Add timeline extraction to jira-formatter
= `formatTimeline()` — status transitions + assignee changes from changelog
+ Tests for chronological sorting, field filtering, missing changelog
```

---

### Task 5: CLI entry point and integration test

**Files:**
- Create: `tools/confluence-md/jira-format.js`
- Modify: `tools/confluence-md/test/jira-formatter.test.js`

- [ ] **Step 1: Write integration test**

Append to `test/jira-formatter.test.js`:

```javascript
import { execFileSync } from 'node:child_process';
import { writeFileSync, unlinkSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve, dirname } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const cli = resolve(__dirname, '..', 'jira-format.js');
const fixturePath = resolve(__dirname, 'fixtures', 'jira-issue-minimal.json');

describe('jira-format.js CLI', () => {
  it('outputs markdown to stdout', () => {
    const result = execFileSync('node', [cli, fixturePath], { encoding: 'utf-8' });
    assert.ok(result.includes('# FP-99999:'));
    assert.ok(result.includes('## Description'));
    assert.ok(result.includes('## Timeline'));
    assert.ok(result.includes('## Comments (2)'));
  });

  it('exits with code 1 on missing file', () => {
    assert.throws(
      () => execFileSync('node', [cli, '/tmp/nonexistent.json'], { encoding: 'utf-8' }),
      (err) => err.status === 1
    );
  });

  it('exits with code 1 on invalid JSON structure', () => {
    const tmpPath = resolve(__dirname, 'fixtures', '_tmp_bad.json');
    writeFileSync(tmpPath, '{"not":"jira"}');
    try {
      assert.throws(
        () => execFileSync('node', [cli, tmpPath], { encoding: 'utf-8' }),
        (err) => err.status === 1
      );
    } finally {
      unlinkSync(tmpPath);
    }
  });
});
```

- [ ] **Step 2: Run tests — verify CLI tests fail**

Run: `cd D:/kb/tools/confluence-md && node --test test/jira-formatter.test.js`
Expected: CLI tests FAIL — `jira-format.js` doesn't exist yet

- [ ] **Step 3: Create CLI entry point**

Create `tools/confluence-md/jira-format.js`:

```javascript
#!/usr/bin/env node
// jira-format.js — Format JIRA issue JSON into readable markdown briefing.
// Usage: node jira-format.js <issue.json>

import { readFileSync } from 'node:fs';
import { formatJiraIssue } from './lib/jira-formatter.js';

const inputPath = process.argv[2];
if (!inputPath) {
  console.error('Usage: node jira-format.js <issue.json>');
  process.exit(1);
}

try {
  const json = JSON.parse(readFileSync(inputPath, 'utf-8'));
  const md = formatJiraIssue(json);
  process.stdout.write(md);
} catch (err) {
  console.error(`Error: ${err.message}`);
  process.exit(1);
}
```

- [ ] **Step 4: Run tests — verify they pass**

Run: `cd D:/kb/tools/confluence-md && node --test test/jira-formatter.test.js`
Expected: all tests PASS

- [ ] **Step 5: Manual integration test with real data**

Run against the actual FP-42033 dump saved earlier:

```bash
cd D:/kb/tools/confluence-md && node jira-format.js "C:/Users/Inquisitor/.claude/projects/D--FishingPlanet-src-server-svn-branches-LBM20251201/d7af3488-eaa8-46a2-a547-28e7d3d7a3b2/tool-results/mcp-plugin_atlassian_atlassian-getJiraIssue-1776176298795.txt"
```

Expected: readable markdown briefing with all 3 comments, timeline, description. Verify Ukrainian text and `→` arrow are correct. Check that `<span style="color:">` is preserved.

- [ ] **Step 6: Commit**

```
Add jira-format.js CLI entry point
+ `jira-format.js` — reads JSON file, outputs markdown briefing to stdout
+ CLI integration tests (success, missing file, bad structure)
```

---

### Task 6: Create Claude Code skill

**Files:**
- Create: Skill file for `jira-read-issue`

- [ ] **Step 1: Identify skill file location**

Check where existing custom skills like `kb-close-task` and `publish-confluence` are stored:

```bash
find ~/.claude -name "kb-close-task*" -o -name "publish-confluence*" 2>/dev/null
```

- [ ] **Step 2: Create skill file**

Create the skill at the identified location. Skill content:

```markdown
---
name: jira-read-issue
description: >-
  Read full JIRA issue context into conversation — comments, description,
  status, timeline. Use when user says "посмотри задачу", "ознакомься с задачей",
  "почитай комментарии к", "сверься с JIRA", "что в JIRA по FP-..."
---

# Read JIRA Issue

Load full JIRA issue context (description, comments, timeline) into the conversation as readable markdown.

## Steps

1. **Extract issue key** from user message (e.g., `FP-42033`). If ambiguous, ask.

2. **Call `getJiraIssue`** MCP tool:
   - `cloudId`: `fishingplanet.atlassian.net`
   - `issueIdOrKey`: extracted key
   - `expand`: `changelog`
   - `fields`: `["summary", "status", "assignee", "resolution", "resolutiondate", "description", "comment"]`
   - `responseContentFormat`: `adf`

3. **Locate the JSON response:**
   - If the MCP result overflowed to a file (you'll see a message with a `.txt` path), use that path
   - If the result is inline, save it to a temp file: write the JSON to `/tmp/jira-<key>.json`

4. **Run the formatter:**
   ```
   node D:/kb/tools/confluence-md/jira-format.js <path-to-json>
   ```
   Read stdout — this is the formatted briefing.

5. **Present the briefing** in the conversation. The markdown is now in your context — you have full issue visibility.

6. **If the formatter exits with code 1**, report the error message to the user. Common causes:
   - MCP returned unexpected JSON structure (API change)
   - Missing fields (wrong `fields` parameter)
```

- [ ] **Step 3: Verify skill appears in skill list**

Ask user to confirm the skill shows up (may require session restart).

- [ ] **Step 4: Commit**

```
Add jira-read-issue skill
+ Skill for loading full JIRA issue context into conversation
+ Orchestrates: getJiraIssue MCP → jira-format.js → markdown briefing
```

---

## Verification

After all tasks are complete, perform an end-to-end test:

1. Start a new conversation or clear context
2. Say "посмотри задачу FP-42033"
3. Verify the skill triggers and produces a complete briefing with:
   - Header (key, summary, status, assignee)
   - Description (converted from ADF)
   - Timeline (status transitions, assignee changes)
   - Comments (all 3, with author, date, ID, markdown formatting, color spans)
