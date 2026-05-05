---
id: TST-002
title: Manual smoke-test checklist
slice: VS5
status: done
depends-on: [all]
effort: S
---

## Closed 2026-05-04

User-confirmed smoke pass. Multiple iterative fixes during smoke captured in
journal milestones (regex relaxation, comma decimal separator, Mongo-side
$regex pre-filter, click aggregation + log-scale color, `<header>` global CSS
leak, Area routing namespaces constraint, canvas 80vh cap, brightness
overlay, scroll-to-bottom on resolution change, hover crosshair + 9×9/14×14
reference box, `displayMode` toggle, Top-20 + per-kind stats).

## Scope
Browser-based smoke pass against a local admin running the deployed build. Final gate before SVN commit closing the task.

## Test players
- LureKing reference: `LUYA168`, `rrsrewr` — should show dense KEEP-rect cluster
- Pattern B: `W_CHUANQI`, `Niepan.LD` — center cluster
- Honest controller: `Jangalor` (Steam Deck) — known false-positive; verify tool surfaces it as suspect (not bot)
- 4K honest: `JangalorFP` — scattered

## Pre-flight static checks
- [x] `cd Components/AntiCheatTool && yarn type-check` — green (vue-tsc strict; not implicit in `yarn build`)
- [x] `cd Components/AntiCheatTool && yarn build` — succeeds, no warnings; `Scripts/vue/anti-cheat/{main.js, style.css}` updated

## Checklist
- [x] Navigation: Player → Moderation → AntiCheat analysis link opens `/Anticheat/GameSessionAnalysis?userId=...`
- [x] Default range: yesterday 00:00 UTC → now (changed from 14d during smoke); immediately fetches all 3 endpoints
- [x] All 4 endpoints respond with JSON; no console / network errors
- [x] Heatmap renders dots for events
- [x] Resolution preset dropdown lists `monitorInfo.distinctValues`
- [x] Manual mode + offsets visibly shift dots
- [x] Calibration persists across reload
- [ ] LRU: open 101 distinct userIds, oldest evicted *(not exercised by smoke; algorithm covered by code review only)*
- [x] Screenshots strip pages 20 at a time; selection drives heatmap background
- [x] Apply filter: URL updates, no full reload, sections re-fetch
- [x] Back button: previous filter restored
- [ ] Authorization: log in as non-Abuse role → 403 *(not exercised by smoke; `[CustomAuthorize(Roles="Abuse")]` covered by code review only)*
- [x] Each LureKing sample: dense click cluster **visibly** falls inside the KEEP-rect outline (numeric anomaly scoring is Phase 4 — v1 verification is visual only)
- [x] Jangalor (Steam Deck): cluster visible at window-center, no auto-bot verdict displayed (v1 surfaces signal, doesn't classify)

## Exit criteria
- All boxes ticked → ready to commit closing task
- Any failures → file as backlog item or block close, depending on severity
