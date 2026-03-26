---
name: publish-confluence
description: >
  Publish a markdown draft from confluence/workspace/ to Confluence Cloud.
  Handles page creation, updates, image upload, and KB index registration.
  Use when user says "publish to confluence", "опубликуй в confluence",
  "запаблиши статью", "обнови страницу", "push to confluence".
argument-hint: "[path to .md file in confluence/workspace/]"
---

# Publish to Confluence

Publish a markdown draft to Confluence Cloud with full formatting (LaTeX, panels, status, Jira widgets, images).

## Prerequisites

- `confluence-md` tool at `D:\kb\tools\confluence-md\`
- Credentials at `~/.config/confluence/credentials`
- Draft in `D:\kb\confluence\workspace\`

## Frontmatter Format

Drafts use minimal YAML frontmatter:

```yaml
---
page_id: "5449973771"          # present after first publish (source of truth)
parent_id: "5450858521"        # where to create; optional after first publish
section: tech-guidelines/server/business-logic/bite-system  # path to _pages.yml
related_tasks:                 # optional metadata, not used for routing
  - FP-41844
  - FP-41845
---
```

Routing logic:
- `page_id` present → **update** existing page
- `page_id` absent, `parent_id` present → **create** new page under parent
- Neither → **ask the user**

## Steps

### 1. Identify the draft

- If `$ARGUMENTS` is provided, use it as the file path
- Otherwise, ask the user which draft to publish
- Read the file. If YAML frontmatter is missing or incomplete:
  - Ask: "Is this an update to an existing page (need page_id) or a new page (need parent_id)?"
  - Ask for `section` path (for `_pages.yml` registration)
  - Create the frontmatter block at the top of the file
- Extract the page title from the first `# H1` heading in the markdown body

### 2. Determine action

| `page_id` | `parent_id` | Action                            |
|-----------|-------------|-----------------------------------|
| present   | —           | **Update** → go to Step 4         |
| absent    | present     | **Create** → go to Step 3         |
| absent    | absent      | **Ask user** for one of the above |

### 3. Ensure parent exists (create flow only)

The `parent_id` must point to a real Confluence page. Verify:

1. Use MCP `getConfluencePage` on `parent_id` (`cloudId`: `fishingplanet.atlassian.net`)
2. If it exists → proceed to Step 3a
3. If it does NOT exist → the parent is a planned section page that hasn't been created yet

**Creating missing intermediate pages:**

Read `_pages.yml` at `D:\kb\confluence\sections\fishing-planet\{section}\_pages.yml`.
Walk **up** the section path, checking `page_id` in each ancestor's `_pages.yml`,
until you find one with a non-null `page_id` — that's the **anchor**.

For each missing intermediate between the anchor and the target (top-down):
1. Use MCP `createConfluencePage`:
   - `cloudId`: `fishingplanet.atlassian.net`
   - `spaceId`: get from MCP `getConfluencePage` on the anchor page
   - `parentId`: the anchor (or previously created intermediate)
   - `title`: from the intermediate's `_pages.yml` `title:` field
   - `body`: `"This section contains technical documentation for {title}."`
   - `contentFormat`: `markdown`
2. Update the intermediate's `_pages.yml`: set `page_id` to the new ID
3. Update `tree.md` if the section was listed with `—` as ID

After all intermediates exist, the article's `parent_id` is the innermost section page ID.

**3a. Create the article page:**

```bash
cd D:/kb/tools/confluence-md && node confluence-md.js create "<draft-path>" --parent-id=<PARENT_ID> --title="<PAGE_TITLE>"
```

The command uploads images, converts LaTeX/Jira links, strips H1, creates the page.

**Capture the page ID** from the output: `Created page "Title" (id: XXXXXXXXXX)`

Proceed to Step 5.

### 4. Update existing page

**Pre-publish version check:** Use MCP `getConfluencePage` on `page_id` and note the live version number. Check `_pages.yml` for the `last_pushed_version:` field on this page entry:

- `last_pushed_version:` **matches** live version → safe to publish
- `last_pushed_version:` **differs** → someone edited in Confluence since our last push. **Stop and warn the user:** "Publishing will overwrite the page completely. Live version is N, our last pushed version was M. Please verify no important changes will be lost, or confirm the overwrite is intentional."
- `last_pushed_version:` **absent** → no tracking data. **Ask the user:** "No pushed version recorded. Publishing will overwrite the page completely. Proceed?"

Only proceed after explicit user confirmation when versions differ or are untracked.

```bash
cd D:/kb/tools/confluence-md && node confluence-md.js publish "<draft-path>" --page-id=<PAGE_ID> --message="<description of changes>"
```

Ask the user for a brief change description for the version message.

Proceed to Step 5.

### 5. Verify

Use MCP `getConfluencePage` with the page ID to confirm it exists and has content. Note the new version number.

Report to the user:
- Page title and version number
- Page URL: `https://fishingplanet.atlassian.net/wiki/pages/<PAGE_ID>`
- Diff URL: `https://fishingplanet.atlassian.net/wiki/pages/diffpagesbyversion.action?pageId=<PAGE_ID>&selectedPageVersions=<VERSION>&selectedPageVersions=<VERSION-1>`
- Ask the user to check the diff and verify rendering

### 6. Update frontmatter

Edit the draft's YAML frontmatter:
- Add `page_id: "<new-page-id>"` (if this was a create)
- Remove `parent_id` (no longer needed — derivable from API)

### 7. Update `_pages.yml`

Path: `D:\kb\confluence\sections\fishing-planet\{section}\_pages.yml`

Find the page entry matching this draft (by `workspace:` field, `title:`, or `id:`).

**If entry exists** — update it:
- `id:` → the Confluence page ID
- `verified:` → today's date (YYYY-MM-DD)
- `last_pushed_version:` → the version number from Step 5
- Remove `workspace:` field (Confluence is now SSoT)

**If no entry** — add one:
```yaml
  - id: "<page-id>"
    title: "<page title>"
    verified: YYYY-MM-DD
    last_pushed_version: <version number>
```

### 8. Commit KB changes

Show the user the list of changed files (draft frontmatter, `_pages.yml`, possibly `tree.md`).

Output a commit message following KB conventions. Do NOT run git commands — wait for user to commit.

## Discipline

- Every step in this skill is **mandatory**, not advisory.
- Do NOT skip steps because they seem obvious.
- If a step says "Ask the user" — ask. Do not assume the answer.
- Always verify the page exists (Step 5) before updating indexes (Steps 6-7).

## Rules

- All file content in English
- Do NOT run `git commit` — only output the commit message text
- Confluence is SSoT — local drafts are working copies, not authoritative
- `_pages.yml` is an index, not content — keep entries minimal
- `tree.md` is a section router — only update if a section ID changed from `—` to a real number
- Page title comes from the `# H1` heading, not from frontmatter
