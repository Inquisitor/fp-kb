# confluence-md — Backlog

## Publish (MD → Confluence)

- [x] Strip first H1 from ADF — `toAdf()` strips by default, `--keep-h1` to disable
- [x] Automated image upload — `publish` uploads attachments via REST API, resolves fileId in-memory
- [x] Jira issue links → inlineCard widgets — `*.atlassian.net/browse/*` URLs auto-upgraded

## Download (Confluence → MD)

- [x] Image resolution — mediaSingle → `![alt](filename)` via attachments API lookup
- [x] Jira inlineCard → clean `[KEY](url)` markdown links
- [ ] Preserve YAML frontmatter — restore from existing .md or template on download
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

## Offline mode

- [x] `to-adf --page-id=ID` — lookups existing attachments to resolve images without upload
- [x] `to-md` — auto-extracts pageId from `collection` attr, fetches attachments for filename resolution
- [x] Graceful fallback — warning placeholders when API unavailable

## Removed

- ~~Media registry (`media-registry.yml`)~~ — replaced by direct API calls; fileId is ephemeral (changes on each upload), so caching it is unreliable. Attachments API provides filename↔fileId mapping on demand.

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
   - Are there images? Verify local files exist for all `![alt](path)` references
   - Missing files → warn, ask whether to proceed
3. Publish: `node confluence-md.js publish <file.md> --page-id=ID`
   - Uploads images automatically
   - Strips H1, upgrades Jira links, injects LaTeX nodes
4. Verify: open page URL, ask user to confirm rendering
5. Post-publish:
   - Update `_pages.yml` if new page
   - Move draft to `confluence/archive/` if finalized

### Table formatting rules (for LaTeX docs)
Embed in skill instructions:
- Simple formulas in tables → bold italic Unicode (`***α***`)
- Complex formulas (fractions, integrals, superscripts) → keep as LaTeX (texblox)
- Status in tables → bold text (pipe conflict)

### Download variant
1. `node confluence-md.js download <page-id> -o <file.md>`
2. Restore frontmatter from existing .md if available
3. Review diff if .md already exists

## Confluence formatting rules (for LaTeX-heavy documents)

Rules discovered during Design Analysis publishing:

1. **Tables: simple formulas → bold italic** — `$\alpha$` → `***α***`, numbers, simple equations
2. **Tables: complex formulas → keep LaTeX** — fractions (`\frac`), integrals (`\int`), superscripts (`^\alpha`) stay as texblox nodes (render as blocks but correctly)
3. **Status in tables → bold** — `{status:X|color:red}` conflicts with table pipes, use `**X**` instead
4. **Unicode Greek in tables** — α, λ, μ, σ, φ directly in bold italic
