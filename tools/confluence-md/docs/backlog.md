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

## Confluence formatting rules (for LaTeX-heavy documents)

Rules discovered during Design Analysis publishing:

1. **Tables: simple formulas → bold italic** — `$\alpha$` → `***α***`, numbers, simple equations
2. **Tables: complex formulas → keep LaTeX** — fractions (`\frac`), integrals (`\int`), superscripts (`^\alpha`) stay as texblox nodes (render as blocks but correctly)
3. **Status in tables → bold** — `{status:X|color:red}` conflicts with table pipes, use `**X**` instead
4. **Unicode Greek in tables** — α, λ, μ, σ, φ directly in bold italic
