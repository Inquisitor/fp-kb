---
id: BCK-004
title: Filter form + refresh (CustomEvent + history.pushState + popstate)
slice: VS1
status: done
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
- [x] Apply with new range → URL changes, no full reload, MonitorInfo re-renders for new range *(verified via TST-002 smoke 2026-05-04)*
- [x] Browser Back button restores previous range and re-fetches (popstate handler verified in DevTools) *(verified via TST-002 smoke 2026-05-04)*
- [x] Browser Forward button after Back also re-fetches
- [x] Refresh-fired before Vue mounts is safe (CustomEvent silently dropped, no JS error) — listener attached in `main.ts` synchronously after `app.mount()`; if `<script type="module">` runs before form JS (typical browser order, modules deferred), listener is in place before any submit can trigger

## Implementation notes (DONE 2026-05-03)
- Refresh wiring: **module-level singleton ref** in `composables/useRefreshSignal.ts`. App.vue `watch`-es it; `main.ts` listener mutates it via `emitRefreshSignal(detail)`. This is the «singleton `refreshTrigger` ref» variant from architecture, chosen over `defineExpose` (poor types, leaks app internals).
- App.vue: extracted `loadMonitorInfo` / `loadEvents` / `loadScreenshots` / `loadAll`; `onMounted` and the watch both call `loadAll`. `loadEvents` / `loadScreenshots` resolve to empty until BCK-002/003 land — by design, no 404 from the stub fetchers.
- Page reset on refresh: `screenshotsPage = 1` — new range invalidates pagination context.
- Date format guarantee: hidden input emits `yyyy-MM-ddTHH:mm:ss.fffZ` (UTC ISO with explicit `Z`) so JS `new Date(value)` interprets as UTC. Kendo write-back format (`yyyy-MM-dd HH:mm:ss.fff`, no TZ) is parsed local-time by JS on next reload — known WebAdmin convention; server normalises to `Kind=Utc` in `MongoSysInfoProvider.Find(userId, start, end)`.
- popstate: reads URL `URLSearchParams`, applies a client-side `defaultRange()` mirror (yesterday 00:00 UTC → now) when URL has only userId without from/to, and syncs form inputs + Kendo widget values via `widget.value(new Date(...))` so the visible form matches the URL state being navigated to. Without the mirror, Back to an initial-load URL (`?userId=...` only) dispatched a refresh with empty from/to that `main.ts` rejected as "incomplete detail".
- **Layout switch (post-VS3)**: form changed from vertical `<table>` to horizontal flex row (`display: flex; gap: 8px; align-items: end`) — saves vertical space. Each field is a `<label>` flex-column with span-prompt + input. Apply button is the last flex item.
- Listener uses `Partial<AntiCheatRefreshDetail>` typing + guards on all three required fields; logs warning + returns if incomplete.
