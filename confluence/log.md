# Decision Log — Confluence

## 2026-03-26: confluence-md converter, first publications, publish skill
- Built `confluence-md` CLI tool (`D:\kb\tools\confluence-md\`, 112 tests): bidirectional MD↔ADF conversion with LaTeX (texblox), TOC, panels, status, expand, Jira inlineCard widgets, automated image upload
- Published two pages under Bite System (5450858521):
  - Edge Distribution — Design Analysis (5449973771, developer deep dive)
  - Fish Weight Generation: Edge Distribution System (5456625665, GD practical guide)
- Created `publish-confluence` skill for repeatable publish workflow (create/update, images, index registration)
- Draft frontmatter simplified: `action`/`status`/`task` removed; routing via `page_id` (update) or `parent_id` (create)
- `_pages.yml` field `freshness` replaced with `verified: YYYY-MM-DD` — freshness is a point-in-time judgment, not a storable fact; `verified` records when we last checked the page
- Media registry (`media-registry.yml`) abandoned — `fileId` changes on every upload, making cached IDs unreliable; attachments API provides the mapping on demand

## 2026-03-23: Structure redesign — section router + nested _pages.yml
- Expanded scope from "SERVER only" to full FP space
- Adopted hybrid navigation: `tree.md` (section router, themes) + `sections/_pages.yml` (page listings)
- `tree.md` contains only sections with "What's Inside" annotations — no individual pages
- `_pages.yml` (YAML) at each indexed level: page IDs, titles, freshness, subsections
- YAML chosen over Markdown tables: no column alignment noise in VCS diffs, easier to edit
- No content storage — Confluence is SSoT
- `_pages.yml` name chosen over `_index.md` to avoid confusion with existing KB convention
- Workspace drafts named `FP-XXXXX--slug.md` with YAML frontmatter (task, target parent ID, status)
- Archive: metadata-only (for git blame navigation), not indexed by agents
- Naming: kebab-case, max 40 chars, Cyrillic → English translation (not transliteration)
- Space-level namespace: `sections/fishing-planet/` for future multi-space support
- New Confluence section planned: TECH > SERVER > Business Logic > Bite System (does not exist yet)
- First draft: FP-41844 fish weight edge distribution → `workspace/FP-41844--fish-weight-edge-distribution.md`

## 2026-03-05
- Identified SERVER section in Fishing Planet Confluence space as primary target
- Decision: do NOT cache page content locally, only index metadata
- Confluence remains source of truth; KB is workbench for preparing updates
