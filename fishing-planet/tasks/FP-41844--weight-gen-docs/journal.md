---
status: in-progress
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-41844
related: FP-41845, FP-33182
epic: FP-26788 (Leaderboards and ratings)
---
# FP-41844: Fish Weight Generation — Create Documentation

## Status
confluence-md converter mature (112 tests). Design Analysis fully published with LaTeX, panels, status, Jira widgets, 6 SVG figures. Next: write publish-to-confluence skill, publish GD guide via skill, review both pages.

## Summary

### Goal
Create Confluence documentation describing the new fish weight generation system (edge distribution, algorithms, configuration) for GD, QA, and developers.

### Source Material
- KB deep dives: [weight-generation.md](../../server/modules/fish-generator/weight-generation.md), [edge-distribution.md](../../server/modules/fish-generator/edge-distribution.md)
- Design spec: [edge-distribution-design.md](../FP-41845--weight-generation-v2/artifacts/edge-distribution-design.md)
- WebAdmin UI (simulator, settings, preview curves)
- FP-41845 task artifacts

### Context
- Implementation complete in FP-41845 (Phase 2a, r15918–r15937)
- System is live on LBM20251201 branch with edge distribution defaulting to `None`
- GD needs documentation to understand parameters and configure the system

## Plan

- [x] Define page structure and target audience
- [x] Draft content in KB workspace (`confluence/workspace/`)
- [x] Review with user — both drafts reviewed and iteratively improved
- [x] Build md→ADF converter — `D:\kb\tools\confluence-md\` (112 tests)
- [x] Republish Design Analysis via ADF with full formatting (LaTeX, Jira widgets, panels, TOC, 6 SVG images)
- [ ] Write publish-to-confluence skill
- [ ] Publish GD guide (fish-weight-edge-distribution) via skill
- [ ] Review published pages in Confluence

## Artifacts

### Confluence pages (created)
- **Bite System** — 5450858521 (container page under Business Logic)
- **Edge Distribution — Design Analysis** — 5449973771 (full ADF with LaTeX, panels, Jira widgets, 6 SVGs)

### Drafts in workspace
- `FP-41844--fish-weight-edge-distribution.md` — GD-facing practical guide (needs LaTeX, lozenges, panels, TOC + first Confluence publish)
- `FP-41844--edge-distribution-design-analysis.md` — developer deep dive (published as ADF)
- `fig-weight-zones.svg` — weight range zones diagram for first draft

### Confluence formatting conventions (superseded)
Old conventions replaced by native `extended-markdown-adf-parser` syntax. See [design spec](../../../tools/confluence-md/docs/design.md) § Markdown Convention.

### Converter tool
- **Location:** `D:\kb\tools\confluence-md\`
- **Docs:** [design.md](../../../tools/confluence-md/docs/design.md), [plan.md](../../../tools/confluence-md/docs/plan.md), [backlog.md](../../../tools/confluence-md/docs/backlog.md)

### Known limitations
- `{status:Text|color:red}` cannot be used inside markdown tables — the `|` conflicts with table cell delimiters. Use **bold** instead. Status works everywhere else (headings, paragraphs, list items).
- Panel title roundtrips with slightly different syntax: `title="X"` → `attrs='{"title":"X"}'`. Functionally identical.
- Block math style may change on roundtrip: `$$content$$` (inline form) → `$$\ncontent\n$$` (fenced form). Semantically identical.

## Milestones
- **2026-03-25:** confluence-md converter polished — strip H1, Jira inlineCard, automated image upload/download, offline image resolution. Design Analysis republished with full formatting and 6 SVG figures.
