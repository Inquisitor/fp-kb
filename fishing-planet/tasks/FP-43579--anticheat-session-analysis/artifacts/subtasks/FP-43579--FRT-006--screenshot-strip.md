---
id: FRT-006
title: ScreenshotStrip component with paging
slice: VS3
status: done
depends-on: [BCK-003]
effort: M
---

## Scope
Render thumbnail strip via existing `/Player/GetScreen?id=N` URLs. Pager controls (prev/next + page indicator). `activeId` selection emits to `App.vue`.

## Files
- Modify: `src/components/ScreenshotStrip.vue` — implementation (props `screenshots`, `total`, `page`, `activeId`, `isLoading`; emits `update:activeId`, `update:page`)
- Modify: `src/App.vue` — wire `screenshotsLoading`, paging state, AJAX kick on `page` change
- Modify: `src/composables/useApiClient.ts` — `fetchScreenshots(userId, from, to, page, pageSize)`

## Implementation notes
- Thumbnail = `<img src="/Player/GetScreen?id={id}">` — admin auth cookie is shared, no extra bridging.
- Active thumbnail: distinct border / outline (Kendo accent `#3e80cf` per palette).
- `update:activeId` writes through to `calibration.activeScreenshotId` — persists via FRT-005.
- Don't preload full-resolution; thumbnails sized via CSS `max-height: 80px; max-width: 120px`.

## Exit criteria
- [x] Page renders 20 thumbnails for userId with > 20 screenshots *(verified via TST-002 smoke 2026-05-04)*
- [x] Prev / Next paginate correctly; `total / pageSize` displayed *(verified via TST-002 smoke 2026-05-04)*
- [x] Click thumbnail → `activeId` flows up *(verified via TST-002 smoke 2026-05-04 — also drives heatmap background swap)*

## Implementation notes (DONE 2026-05-03)
- Pager controls (Prev/Next + page indicator + total) in component header. `pageSize` is now a prop (not hardcoded inside) so App.vue owns it; default 20 in App.vue (`SCREENSHOTS_PAGE_SIZE` constant).
- Click thumbnail toggles activeId — second click on same thumbnail unselects (return to bbox/hatch mode).
- `<img loading="lazy">` so off-screen thumbnails don't slam the network when paged sets are large.
- Active border `#3e80cf` (Kendo accent), inactive transparent border (so layout doesn't shift on hover/select).
- App.vue: `onScreenshotPage` triggers `loadScreenshots()` directly; only this load call is page-aware (events / monitor are unaffected).
- Strict TS clean.
