# confluence-md: Bidirectional Markdown ↔ ADF Converter — Design Spec

**Date:** 2026-03-24
**Task:** FP-41844 (Fish Weight Generation — Create Documentation)
**Status:** Approved

## Purpose

A file-based bidirectional converter between annotated Markdown and Atlassian Document Format (ADF) JSON, enabling a Confluence publishing workflow where:

- **Confluence = SSoT.** Published pages are the authoritative version.
- **Local MD = working drafts.** Prepared and edited locally, pushed to Confluence when ready.
- **Archive = git history.** Finished drafts archived under `confluence/archive/` for `git log` navigation.
- **Drift tracking.** `.adf.json` files can be stored in VCS to make Confluence-side edits visible as diffs.

## Workflow

```
Author edits .md locally
    → to-adf → .adf.json
    → Claude publishes via MCP (createConfluencePage / updateConfluencePage)

Colleague edits in Confluence
    → Claude fetches ADF via MCP (getConfluencePage)
    → saves .adf.json
    → to-md → .md
    → Author continues editing locally
```

## Markdown Convention

All drafts in `confluence/workspace/` use **native `extended-markdown-adf-parser` syntax** for Confluence-specific elements, plus two pre-processed extensions (LaTeX and TOC).

### Native (handled by the package)

| Element              | Syntax                                                                   |
|----------------------|--------------------------------------------------------------------------|
| Panel                | `~~~panel type=info title="Title"` ... `~~~`                             |
| Expand (collapsible) | `~~~expand title="Title"` ... `~~~`                                      |
| Status / lozenge     | `{status:Text\|color:red}` (neutral/green/red/yellow/blue/purple)        |
| Image in container   | `~~~mediaSingle layout=center width=80` ... `![Cap](media:id)` ... `~~~` |
| Smart link           | `[text](card:https://...)`                                               |
| Code block           | ` ```lang ` ... ` ``` `                                                  |

Panel types: `info`, `warning`, `error`, `success`, `note`.

### Pre-processed extensions

| Element      | MD syntax            | ADF node                                       |
|--------------|----------------------|------------------------------------------------|
| LaTeX inline | `$x + y$`            | `inlineExtension` (extensionKey: `mathinline`) |
| LaTeX block  | `$$\np(s) = ...\n$$` | `bodiedExtension` (extensionKey: `mathblock`)  |
| TOC          | `<!-- {toc} -->`     | `extension` (extensionKey: `toc`)              |

All three use `extensionType: "com.atlassian.confluence.macro.core"`.

### Superseded conventions

The following conventions from the FP-41844 journal (lines 51–58) are replaced:

| Old                                  | New                              |
|--------------------------------------|----------------------------------|
| `<span class="lozenge red">X</span>` | `{status:X\|color:red}`          |
| `<div class="panel blue">...</div>`  | `~~~panel type=info` ... `~~~`   |
| `> [!NOTE]` / `> [!WARNING]`         | `~~~panel type=note/warning` ... |
| `<details><summary>T</summary>`      | `~~~expand title="T"` ... `~~~`  |

LaTeX (`$...$` / `$$...$$`) and TOC (`<!-- {toc} -->`) syntax remain unchanged.

## Pipeline: to-adf (MD → ADF JSON)

```
Step 0: Read .md file
Step 1: Pre-process
        - Scan text, skipping code spans (` `) and code fences (``` ```)
        - Skip escaped \$
        - Replace $$...$$ with block placeholders (CFMD_MATHBLK_0001, CFMD_MATHBLK_0002, ...)
        - Replace $...$ with inline placeholders (CFMD_MATHINL_0001, CFMD_MATHINL_0002, ...)
        - Replace <!-- {toc} --> with TOC placeholder (CFMD_TOC_0001)
        - Store {id → {type, content}} in a map
Step 2: Package parse (extended-markdown-adf-parser: MD → ADF JSON)
Step 3: Post-process — recursive walk of ADF tree:
        - Text node containing CFMD_MATHINL* →
          replace with inlineExtension node:
          {"type": "inlineExtension", "attrs": {
            "extensionType": "com.atlassian.confluence.macro.core",
            "extensionKey": "mathinline",
            "parameters": {"body": "<latex content>"}}}
        - Paragraph containing only CFMD_MATHBLK* →
          replace paragraph with bodiedExtension node:
          {"type": "bodiedExtension", "attrs": {
            "extensionType": "com.atlassian.confluence.macro.core",
            "extensionKey": "mathblock"},
           "content": [{"type": "paragraph", "content": [
             {"type": "text", "text": "<latex content>"}]}]}
        - Paragraph containing only CFMD_TOC* →
          replace paragraph with extension node:
          {"type": "extension", "attrs": {
            "extensionType": "com.atlassian.confluence.macro.core",
            "extensionKey": "toc",
            "parameters": {}}}
Step 4: Write .adf.json file
```

### Pre-processor escaping rules

1. `\$` — skip (not a delimiter). The backslash is left in the text for the package parser to handle as a standard Markdown escape.
2. `$` inside backtick code span — skip
3. `$` inside triple-backtick code fence — skip
4. `$$` as block math delimiter — two forms accepted:
   - Fenced: `$$` on its own line opens/closes a block (content on separate lines between delimiters)
   - Inline: `$$content$$` on a single line (opening and closing on same line)
5. `$...$` within a line — inline math (non-greedy, same-line only, no nesting)

### ADF node schemas for extension nodes

**Why inline and block differ:** ADF `inlineExtension` nodes have no body — they carry all data in `attrs.parameters`. ADF `bodiedExtension` nodes carry their body as ADF `content` children. This is the standard ADF convention, not a design choice.

- **mathinline:** LaTeX expression stored in `parameters.body` (string).
- **mathblock:** LaTeX expression stored in `content[0].content[0].text` (text node inside a paragraph inside the bodied extension).
- **toc:** `parameters` is empty (default TOC with no options). This is a deliberate simplification — Confluence's TOC macro accepts `minLevel`, `maxLevel`, etc., but these are not exposed in the `<!-- {toc} -->` syntax. Can be extended later if needed.

### Placeholder scheme

Placeholders are namespaced uppercase tokens: `CFMD_MATHINL_0001`, `CFMD_MATHBLK_0001`, `CFMD_TOC_0001`. Counter increments per type per document.

- `CFMD_` = confluence-md tool namespace
- `MATHINL` = math inline, `MATHBLK` = math block, `TOC` = table of contents
- Multiple `<!-- {toc} -->` in one document: each gets its own placeholder and extension node (no limit, though typically only one TOC per page)
- Collision risk is negligible for these prefixes in natural text. If needed, lengthen to `XCFMD_MATHINL_` + random suffix.

## Pipeline: to-md (ADF JSON → MD)

Mirror of to-adf:

```
Step 0: Read .adf.json file
Step 1: Pre-process — recursive walk of ADF tree:
        - inlineExtension[mathinline] →
          extract LaTeX from attrs.parameters.body
          → replace node with text node containing CFMD_MATHINL* placeholder
        - bodiedExtension[mathblock] →
          extract LaTeX from content[0].content[0].text
          → replace node with paragraph containing CFMD_MATHBLK* placeholder
        - extension[toc] →
          replace node with paragraph containing CFMD_TOC* placeholder
        - All other extension/bodiedExtension/inlineExtension nodes:
          passed through to the package as-is (package emits <!-- adf:unknown --> for unrecognized nodes)
        - Store {id → {type, content}} in map
Step 2: Package parse (extended-markdown-adf-parser: ADF → MD)
Step 3: Post-process:
        - CFMD_MATHINL* → $<content>$
        - CFMD_MATHBLK* → $$\n<content>\n$$
        - CFMD_TOC* → <!-- {toc} -->
Step 4: Write .md file
```

## CLI Interface

```
node confluence-md.js to-adf <file.md> [-o output.adf.json]
node confluence-md.js to-md <file.adf.json> [-o output.md]
```

Default output: extension swap — `.md` ↔ `.adf.json`.

Examples:
```
node confluence-md.js to-adf workspace/article.md
→ workspace/article.adf.json

node confluence-md.js to-md workspace/article.adf.json
→ workspace/article.md

node confluence-md.js to-adf workspace/article.md -o /tmp/preview.adf.json
```

## Project Structure

```
D:\kb\tools\confluence-md\
├── confluence-md.js              # CLI entry point (arg parsing, dispatch)
├── lib/
│   ├── preprocessor.js           # LaTeX/TOC/image extraction & placeholder injection
│   ├── postprocessor.js          # Placeholder → ADF extension nodes / MD syntax
│   ├── placeholder.js            # CFMD_* token management
│   ├── math-adapter.js           # Math plugin adapter (delegates to adapters/)
│   ├── adapters/
│   │   └── texblox.js            # texblox-macro Forge app adapter
│   ├── jira-links.js             # Jira link ↔ inlineCard conversion
│   ├── image-resolver.js         # Image placeholder → mediaSingle ADF nodes (MD→ADF)
│   ├── image-downgrader.js       # mediaSingle → ![alt](file) markdown (ADF→MD)
│   ├── confluence-api.js         # REST API client (pages, attachments)
│   ├── to-adf.js                 # MD→ADF pipeline orchestrator
│   ├── to-md.js                  # ADF→MD pipeline orchestrator
│   └── media.js                  # MediaRegistry (legacy, unused in pipeline)
├── package.json
├── docs/
│   ├── design.md                 # This file
│   ├── plan.md                   # Implementation plan (completed)
│   └── backlog.md                # Remaining work items
└── test/
    ├── preprocessor.test.js      # Extraction, escaping, edge cases
    ├── postprocessor.test.js     # ADF node injection / MD restoration
    ├── image-resolver.test.js    # Image → mediaSingle tests
    ├── image-downgrader.test.js  # mediaSingle → markdown tests
    ├── jira-links.test.js        # Jira link upgrade/downgrade tests
    ├── texblox-adapter.test.js   # texblox adapter tests
    ├── to-adf.test.js            # Full MD→ADF pipeline tests
    ├── to-md.test.js             # Full ADF→MD pipeline tests
    ├── integration.test.js       # MD→ADF→MD roundtrip tests
    ├── smoke.test.js             # Package API smoke tests
    ├── placeholder.test.js       # PlaceholderMap tests
    ├── media.test.js             # MediaRegistry tests
    ├── confluence-api.test.js    # API module load test
    └── fixtures/                 # Sample .md and .adf.json files
```

## Dependencies

```json
{
  "name": "confluence-md",
  "version": "0.1.0",
  "type": "module",
  "dependencies": {
    "extended-markdown-adf-parser": "^2.4.0"
  }
}
```

No other dependencies. File I/O and JSON parsing via Node.js stdlib.

## Image Workflow

### Media Registry

A YAML file tracking all images uploaded to Confluence, serving as the single mapping between local filenames and Confluence media IDs.

**Location:** `confluence/media-registry.yml`

```yaml
media:
  31938793-5f3b-4d4c-adb9-7b0eb6ba8a59:
    filename: edge-distribution-fig1-desired-pdf.svg
    page_id: 5450858521
    source: server/modules/fish-generator/edge-distribution-fig1-desired-pdf.svg
    uploaded: 2026-03-24
```

Fields:
- `filename` — original filename (used for resolution by name)
- `page_id` — Confluence page the image is attached to
- `source` — path to the original file in KB (optional, for traceability)
- `uploaded` — date of upload

### File layout during editing

```
confluence/workspace/
├── FP-41844--design-analysis.md
├── FP-41844--design-analysis/
│   ├── edge-distribution-fig1-desired-pdf.svg
│   └── edge-distribution-fig2-candidates.svg
├── FP-41844--fish-weight-edge-dist.md
├── FP-41844--fish-weight-edge-dist/
│   └── fig-weight-zones.svg
└── ...

confluence/media-registry.yml
```

Each draft has a sibling folder (same name as the `.md` file, without extension) for its images. On archival, the folder moves with the article.

### Image resolution in to-adf

When the converter encounters `![Caption](filename.svg)`:

1. Look up `filename.svg` in `media-registry.yml` for the target page → found: emit `mediaSingle` with `media:<id>`
2. Not found in registry → emit placeholder text in ADF: `[Image: filename.svg — not uploaded]`

The converter searches for the image file itself (for validation) in:
1. The draft's sibling folder (`article-name/filename.svg`)
2. The `source` path from the registry (if it's a KB file)

### Image resolution in to-md

When the package produces `![alt](media:uuid)`:

1. Look up `uuid` in `media-registry.yml` → found: rewrite to `![alt](filename.svg)`
2. Not found (image added by someone in Confluence) → download attachment via API, save to draft's sibling folder under original filename, add entry to registry

### Phase 1 (manual upload)

1. Upload images to Confluence page via UI
2. Add entry to `media-registry.yml` (media ID from page ADF or attachment API)
3. Reference in markdown as `![Caption](filename.svg)` — the converter resolves via registry

### Phase 2 (automated upload, future)

Add upload step to the publish pipeline:
1. Scan MD for `![alt](filename)` references without registry entries
2. Upload as attachments via Confluence REST API
3. Add entries to `media-registry.yml` automatically

## Error Handling

- Exit code 0 on success, exit code 1 on any error.
- Errors go to stderr, converted output goes to stdout (if no `-o` specified) or to file.
- Malformed input (invalid JSON for to-md, unreadable file): exit 1 with descriptive message.
- Package parser throws: exit 1, forward the error message.
- Post-processor placeholder not found in map (desync): exit 1, report the orphan placeholder ID.
- File write failure (permissions, disk): exit 1, report the OS error.

## Caveats

### LaTeX native support in the package

If `extended-markdown-adf-parser` adds native LaTeX support in a future version, our pre-processor will **conflict** with it (not become a no-op). When upgrading the package:

1. Check changelog for LaTeX/math support
2. If added: disable our pre-processor, adopt the package's native syntax
3. Test roundtrip before switching

### ADF extension node schema

The `mathinline`, `mathblock`, and `toc` extension nodes use Confluence's macro extension type (`com.atlassian.confluence.macro.core`). The exact `parameters` schema was observed from a live Confluence Cloud instance. If Atlassian changes the macro parameter format, the post-processor may need updates.

### Placeholder collision

Placeholders (CFMD_MATHINL*, CFMD_MATHBLK*, CFMD_TOC*) are uppercase alphanumeric strings unlikely to appear in natural text. If a document legitimately contains these strings, the pre-processor will misidentify them. Mitigation: use a longer, more unique prefix if needed (e.g., `XCFMD_MATHINL_` + random suffix per run).
