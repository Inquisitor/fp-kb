# confluence-md — Backlog

## Publish (MD → Confluence)

- [ ] Strip first H1 from ADF — duplicates Confluence page title
- [ ] Media registry integration — resolve `![alt](file.svg)` to `media:uuid` via registry
- [ ] Automated image upload — upload attachments via REST API, update registry

## Download (Confluence → MD)

- [ ] Preserve YAML frontmatter — restore from existing .md or template on download
- [ ] Media registry integration — rewrite `media:uuid` to local filename
- [ ] Strip default tableCell attrs — remove `<!-- adf:tableCell attrs='{"colspan":1,"rowspan":1}' -->` noise
- [ ] Table column alignment — lost on roundtrip (package limitation, may need post-processing)
- [ ] Bold-inside-backtick — `**pre-\`x\`**` roundtrips as `**pre-**\`x\`` (package limitation)

## Both directions

- [ ] Block math style — single-line `$$formula$$` when content is one line, fenced `$$\n...\n$$` when multi-line
- [ ] Whitespace normalization — extra blank lines between list items, etc.

## texblox adapter

- [x] Single-char formula workaround — `x` → `{x}`
- [x] Numeric formula workaround — `0.95` → `{0.95}`
- [ ] Inline rendering in tables — `inlineExtension` renders as block inside `tableCell` (plugin limitation, no fix known)

## Image workflow (discovered findings)

### ADF structure for images
SVG files render inline in Confluence Cloud. ADF structure (from real page):
```json
{"type": "mediaSingle", "attrs": {"layout": "center", "width": 760, "widthType": "pixel"},
 "content": [
   {"type": "media", "attrs": {
     "id": "<uuid>", "collection": "contentId-<pageId>",
     "type": "file", "width": 600, "height": 320,
     "alt": "filename.svg"}},
   {"type": "caption", "content": [{"type": "text", "text": "Figure 1"}]}
]}
```

### Publish flow
1. Page must exist first (to attach files to)
2. Upload image as attachment (manual in Phase 1, REST API in Phase 2)
3. Get media UUID from attachment response or page ADF
4. `media-registry.yml` maps filename ↔ UUID ↔ page_id
5. Converter resolves `![Caption](filename.svg)` → `mediaSingle` with `media:<uuid>` via registry
6. If not in registry → placeholder text in ADF, warning to stderr

### Download flow
1. Package produces `![alt](media:uuid)`
2. Lookup UUID in registry → rewrite to `![alt](filename.svg)`
3. If not in registry (image added in Confluence) → download attachment, save locally, add to registry

### File layout
Each draft has a sibling folder for images:
```
confluence/workspace/
├── article.md
├── article/          ← images for this draft
│   ├── fig1.svg
│   └── fig2.svg
```
On archival, folder moves with the article.

### Caption
`![Caption text](media:id)` — alt text in `[]` maps to both `alt` attr on media node and optionally a `caption` child node in `mediaSingle`. Need to verify if the package generates `caption` or only `alt`.

## Skill outline (publish-to-confluence)

### Purpose
Automate the full publish workflow: convert MD → ADF → upload to Confluence, with image and LaTeX handling.

### Trigger
User says "publish to confluence", "опубликуй в confluence", "запаблиши статью", or similar.

### Prerequisites
- `confluence-md` tool installed at `D:\kb\tools\confluence-md\`
- Credentials at `~/.config/confluence/credentials`
- texblox-macro plugin installed in Confluence (for LaTeX)

### Steps (draft)
1. Identify target: which .md file, which page ID (from frontmatter `target_parent_id` or `--page-id`)
2. Pre-flight checks:
   - Are there images? Check media-registry.yml for all `![alt](file)` references
   - Missing images → warn, ask whether to proceed without them
3. Convert: `node confluence-md.js to-adf <file.md>`
4. Review ADF (optional): show stats — mathinline count, mathblock count, panels, status, images
5. Publish: `node confluence-md.js publish <file.md> --page-id=ID`
6. Verify: open page URL, ask user to confirm rendering
7. Post-publish:
   - Update `_pages.yml` if new page
   - Move draft to `confluence/archive/` if finalized
   - Save `.adf.json` alongside for drift tracking (optional)

### Table formatting rules (for LaTeX docs)
Embed in skill instructions:
- Simple formulas in tables → bold italic Unicode (`***α***`)
- Complex formulas (fractions, integrals, superscripts) → keep as LaTeX (texblox)
- Status in tables → bold text (pipe conflict)
- First H1 → strip on publish (duplicates page title)

### Download variant
1. `node confluence-md.js download <page-id> -o <file.md>`
2. Restore frontmatter from existing .md if available
3. Review diff if .md already exists
4. Clean up tableCell attr noise

## Confluence formatting rules (for LaTeX-heavy documents)

Rules discovered during Design Analysis publishing:

1. **Tables: simple formulas → bold italic** — `$\alpha$` → `***α***`, numbers, simple equations
2. **Tables: complex formulas → keep LaTeX** — fractions (`\frac`), integrals (`\int`), superscripts (`^\alpha`) stay as texblox nodes (render as blocks but correctly)
3. **Status in tables → bold** — `{status:X|color:red}` conflicts with table pipes, use `**X**` instead
4. **Unicode Greek in tables** — α, λ, μ, σ, φ directly in bold italic
