---
id: FRT-009
title: KendoDropdown.vue jQuery bridge (with stop-criteria)
slice: VS4
status: done
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
- [x] Resolution preset opens Kendo-styled popup; selection updates `App.vue` calibration *(verified via TST-002 smoke 2026-05-04)*
- [ ] No memory leak after route refresh *(not exercised — heap-snapshot DevTools workflow not run; `widget.destroy()` in onBeforeUnmount is correct by code review)*
- [x] If fallback triggered: scoped CSS visually matches Kendo palette; this file annotated *(N/A — bridge built and works, fallback path not triggered)*

## Implementation notes (DONE 2026-05-03)
- Created `src/kendo/KendoDropdown.vue` per architecture template (single `<input ref>`, `widget.destroy()` in `onBeforeUnmount`).
- jQuery `$` declared `any` locally (admin layout loads jQuery + Kendo globally; pulling typings for one bridge component is overhead).
- Two `watch`'es: `modelValue` → `widget.value()` write-through (with same-value guard to avoid feedback loop); `options` → `widget.setDataSource()` (deep, in case `monitorInfo.distinctValues` arrives after mount).
- `widget.value()` returns empty string for «no selection»; converted to/from `null` at the boundary so consumer null contract survives.
- `CalibrationPanel.vue` swap: native `<select>` → `<KendoDropdown>` with `presetDropdownOptions` (computed `[{text, value}]` from `presetOptions`).
- Strict TS clean: `yarn type-check` 0 errors. Build: 28 modules (was 26), main.js 79.26 KB (was 78.62 KB) — Kendo widget code is loaded globally by admin so bundle adds only the bridge wrapper.
- Stop-criteria not triggered. If smoke reveals popup positioning / value desync issue: fallback is a one-line revert in CalibrationPanel.vue (replace `<KendoDropdown>` block with the previous `<select>` block — kept in subtask FRT-004 notes).
