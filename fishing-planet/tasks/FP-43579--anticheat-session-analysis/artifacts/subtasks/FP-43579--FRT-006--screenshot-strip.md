---
id: FRT-006
title: ScreenshotStrip component with paging
slice: VS3
status: todo
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
- [ ] Page renders 20 thumbnails for userId with > 20 screenshots
- [ ] Prev / Next paginate correctly; `total / pageSize` displayed
- [ ] Click thumbnail → `activeId` flows up (verifiable via DevTools / `App.vue` debug print)
