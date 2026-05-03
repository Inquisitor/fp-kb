---
id: FRT-009
title: KendoDropdown.vue jQuery bridge (with stop-criteria)
slice: VS4
status: todo
depends-on: [FRT-004]
effort: M
---

## Scope
Replace native `<select>` resolution preset with `<KendoDropdown>` Vue wrapper around `kendoDropDownList` jQuery widget per [architecture → Bridge component design](../architecture.md#bridge-component-design).

## Files
- Create: `src/kendo/KendoDropdown.vue` — bridge component (template = single `<input ref>`)
- Modify: `src/components/CalibrationPanel.vue` — swap native `<select>` for `<KendoDropdown>`
- Modify: `src/main.ts` — declare global `$` so widget access is typed (or use shim)

## Stop-criteria (per architecture)
Abort bridge attempt and revert to scoped-CSS `<select>` fallback if any of:
- Popup positioning broken (anchored to wrong element due to Vue DOM ownership)
- Widget value desync survives `watch(() => props.modelValue)` write-through
- Total time > 2 hours

In fallback case: keep native `<select>` from FRT-004, apply `kendo-like-select` scoped class per architecture; document the attempt + cause in this subtask file before closing.

## Implementation notes
- Template: ONE `<input ref="el" />`, do NOT re-render via `v-if` / `v-for`.
- `widget.destroy()` MANDATORY in `onBeforeUnmount` — leaks otherwise.
- Popups attach to `<body>` outside the bridge element → scoped styles do not reach them. If popup needs styling, use global Kendo theme (already loaded).

## Exit criteria
- [ ] Resolution preset opens Kendo-styled popup; selection updates `App.vue` calibration
- [ ] No memory leak after route refresh (heap snapshot before / after a few opens; widget destroyed)
- [ ] If fallback triggered: scoped CSS visually matches Kendo palette; this file annotated with «fell back, reason: ...»
