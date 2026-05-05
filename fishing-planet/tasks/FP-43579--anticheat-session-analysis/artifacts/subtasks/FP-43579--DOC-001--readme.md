---
id: DOC-001
title: README in Components/AntiCheatTool
slice: VS4
status: done
depends-on: [FRT-009]
effort: S
---

## Scope
Strategic deliverable from [backlog](../backlog.md). Contents per [architecture → DOC-001](../architecture.md#doc-001-readme-in-vue-project-folder). Land at end of polish slice when patterns have stabilized.

## Files
- Create: `WebAdmin/WebAdmin/Components/AntiCheatTool/README.md`

## Required sections
1. What this tool is (1-2 sentences)
2. Architecture overview (Razor host + Vue island)
3. File structure
4. Build commands (`yarn build`, `yarn build:watch`, `yarn lint`, `yarn type-check`)
5. Dev workflow
6. Build output and `WebAdmin.csproj` integration (Compile / Content registrations)
7. Initial state injection pattern (Razor `Json.Serialize` → `data-initial-state` → Vue `JSON.parse(dataset.initialState)`)
8. Kendo widget bridge pattern + gotchas (incl. lessons from FRT-009 attempt or fallback)
9. Explicit contrast with `TargetedAdsPlanningTool`: «If you're building a new admin Vue tool, follow this template, NOT the TargetedAdsPlanningTool's setup. That one uses Vue 2 + Vuetify with `Layout = null` because Vuetify's global CSS reset broke admin layout. We solve that by avoiding UI kits.»

## Exit criteria
- [x] All 9 sections present
- [x] Contrast section explicitly directs future authors away from TargetedAdsPlanningTool's pattern (with comparison table)
- [x] FRT-009 outcome reflected — bridge built, stop-criterion not triggered; fallback path documented as one-line revert

## Implementation notes (DONE 2026-05-03)
- All 9 sections per architecture: tool description, architecture overview, file structure, build commands, dev workflow, csproj integration, initial-state pattern, Kendo bridge pattern + gotchas, TargetedAdsPlanningTool contrast.
- File structure mirrors current state (post-VS4): includes `useErrorReporter`, `kendo/KendoDropdown.vue`, `useRefreshSignal`, etc.
- Kendo bridge gotchas section reflects FRT-009 implementation findings (single `<input ref>` template, mandatory `widget.destroy()`, popup styling outside scoped CSS).
- Build numbers refreshed (Vite output sizes from VS4 final build).
- Strategic deliverable DOC-001 in backlog can be marked done after VS4 commit.
