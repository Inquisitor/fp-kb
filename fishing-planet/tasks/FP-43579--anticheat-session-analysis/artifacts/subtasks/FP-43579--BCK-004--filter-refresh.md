---
id: BCK-004
title: Filter form + refresh (CustomEvent + history.pushState + popstate)
slice: VS1
status: todo
depends-on: [FRT-001]
effort: S
---

## Scope
Wire the Razor filter form (Apply button) to refresh Vue data without full page reload, per [architecture → Top-Level Structure](../architecture.md#top-level-structure).

## Files
- Modify: `Areas/Anticheat/Views/GameSessionAnalysis/Index.cshtml` — filter form + Kendo date pickers + JS handler that intercepts submit, calls `history.pushState`, dispatches `CustomEvent('anticheat:refresh', { detail: ... })`
- Modify: `src/main.ts` — replace stub listener with re-fetch logic (refire `fetchMonitorInfo / fetchEvents / fetchScreenshots` with new params)

## Implementation notes
- Date pickers via existing `CreateKendoUtcDateTimePickerFor` helper (same as `Views/Player/FishingLog.cshtml`).
- Submit handler: `e.preventDefault()` → build `URLSearchParams` → `pushState({}, '', '?' + qs)` → `dispatchEvent('anticheat:refresh', { detail })`.
- **`popstate` handler** (Back/Forward button): `window.addEventListener('popstate', () => { /* read URLSearchParams from window.location.search, dispatch the same anticheat:refresh CustomEvent */ })`. Without this, Back-button silently changes URL but Vue stays on stale data.
- Vue listener: read `detail.userId / from / to`, call `App.vue` exposed `refresh(detail)` (or emit through a singleton `refreshTrigger` ref).
- Ensure listener attached BEFORE handler can fire (Vue mounts in `main.ts`, listener added in same `onMounted`).
- VS1 reality: Events / Screenshots endpoints are stubs at this point — `refresh` triggers the stubs to re-resolve (they return empty until VS2 / VS3). MonitorInfo refresh is real.

## Exit criteria
- [ ] Apply with new range → URL changes, no full reload, MonitorInfo re-renders for new range
- [ ] Browser Back button restores previous range and re-fetches (popstate handler verified in DevTools)
- [ ] Browser Forward button after Back also re-fetches
- [ ] Refresh-fired before Vue mounts is safe (CustomEvent silently dropped, no JS error)
