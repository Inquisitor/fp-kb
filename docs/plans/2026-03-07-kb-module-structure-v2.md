# KB Module Structure v2 — Design

**Date:** 2026-03-07
**Status:** Approved
**Trigger:** Fish generator module card exceeded 40-line limit (62 lines). BiteSystem (41 files) not yet documented but needed as peer module. Flat `modules/` folder won't scale for 7+ fishing gameplay modules alongside unrelated domains (tournaments).

## Problem

1. Module cards designed for 20-40 lines overflow when modules are complex (fish-generator: 62 lines)
2. No grouping mechanism — `fish-generator` and `matchmaking` are flat siblings despite belonging to completely different domains
3. BiteSystem is a large peer system (41 files) that needs its own card, creating a cluster of related modules
4. No place for cross-module documentation (data flow between FishGenerator ↔ BiteSystem ↔ GameProcessor)

## Approaches Considered

### A. Systems as folder hierarchy
```
modules/fishing/_card.md → modules/fishing/fish-generator/_card.md
```
**Rejected.** Both experts independently rejected this:
- System-level `_card.md` becomes a mandatory navigation toll (1 extra read every session)
- System cards rot first — nobody works on "fishing-as-a-system"
- Folder hierarchy implies containment (parent-child), but FishGenerator and BiteSystem are peers
- At 15+ modules, boundary disputes waste time ("which system does this belong to?")

### B. Flat modules with cross-references
```
modules/fish-generator/, modules/bite-system/, modules/matchmaking/
```
**Rejected.** Doesn't scale:
- At 20 modules, flat listing is a wall of names with no semantic grouping
- Agent can't distinguish domains without reading every card
- Cross-references in cards help after opening, not before choosing which card to read

### C+ Grouped flat (adopted)
```
_index.md groups modules by domain section headers
modules/ stays flat
_systems/ holds optional cross-module overviews
```
**Adopted.** Combines benefits:
- Grouping in `_index.md` — 1 read, full orientation
- Flat folders — no nesting tax, easy to add modules
- System overviews on-demand — read only when cross-module context needed
- Scales to 40+ modules (index sections stay scannable)

## Expert Panel

Two specialized agents reviewed the design:

**Documentation Architect** (15+ years, game dev studios):
- "Filesystem encodes location, text encodes relationships"
- System-level cards rot first because nobody ever works on the system level
- `_systems/` docs answer "how do pieces compose" — different question from "where to look"
- Temporary work: dated files in module folder OR under tasks/

**AI KB Specialist** (LLM-optimized knowledge bases):
- Explicit textual cross-references (`→ ← ~`) are strictly superior to folder hierarchy for AI agents
- Folder hierarchy implies containment that doesn't exist in code
- Cross-references encode relationship type (direction, optionality) — folders can't
- C scales to 40+ modules; A breaks at ~15; B breaks at ~25
- Temporary work strictly under `tasks/`, never in `modules/` (freshness ambiguity)

## Key Design Decisions

1. **Flat modules, grouped index.** `_index.md` section headers group by domain. Module folders flat under `modules/`.

2. **Strict 5-section card format.** Entry Points, Key Types, Dependencies, Deep Dives, Related Tasks. Target 25-35 lines.

3. **Directional dependency markers.** `→` consumes, `←` consumed by, `~` shared types. Encodes semantics a folder tree cannot.

4. **System overviews as opt-in deep dives.** `modules/_systems/<system>.md` — not a navigation layer, read on-demand.

5. **Deep dives are permanent docs.** No line limit. Live in module folder. Linked from card.

6. **Temporary work under `tasks/`.** Module folder = permanent truth. Task folder = in-progress work.

7. **2-level max nesting.** `modules/<name>/<file>.md` — never deeper.

## Navigation Protocol

```
Typical task:       server/_index.md → module/_card.md → code         (2 reads)
Cross-module task:  + modules/_systems/<system>.md                    (3 reads)
Need algorithm:     + deep dive linked from card                      (3-4 reads)
```

## Supersedes

- `docs/plans/2026-03-05-kb-system-design.md` — module card format and conventions sections
