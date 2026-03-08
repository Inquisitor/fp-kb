# Decision Log — Server

## 2026-03-07: KB module structure v2 — grouped flat with system overviews

Reviewed by two expert agents (documentation architect + AI KB specialist). Both independently rejected nested hierarchy (Approach A) in favor of grouped flat modules (Approach C+).

**Decision:** Flat `modules/` folder, grouping via `_index.md` sections, optional `_systems/` for cross-module overviews.

**Key conventions adopted:**
- Card format: strict 5-section (Entry Points, Key Types, Dependencies, Deep Dives, Related Tasks), 25-35 lines
- Dependencies use directional markers: `→` consumes, `←` consumed by, `~` shared types
- Max nesting: 2 levels from `modules/`
- `_systems/` — optional cross-module data flow docs, not a navigation layer
- Deep dives: permanent docs in module folder, no line limit
- Temporary work: under `tasks/`, not in `modules/`
- Design doc: not written separately (documented in this log entry + CLAUDE.md conventions)
