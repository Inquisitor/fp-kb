---
id: TST-002
title: Manual smoke-test checklist
slice: VS5
status: todo
depends-on: [all]
effort: S
---

## Scope
Browser-based smoke pass against a local admin running the deployed build. Final gate before SVN commit closing the task.

## Test players
- LureKing reference: `LUYA168`, `rrsrewr` — should show dense KEEP-rect cluster
- Pattern B: `W_CHUANQI`, `Niepan.LD` — center cluster
- Honest controller: `Jangalor` (Steam Deck) — known false-positive; verify tool surfaces it as suspect (not bot)
- 4K honest: `JangalorFP` — scattered

## Pre-flight static checks
- [ ] `cd Components/AntiCheatTool && yarn type-check` — green (vue-tsc strict; not implicit in `yarn build`)
- [ ] `cd Components/AntiCheatTool && yarn build` — succeeds, no warnings; `Scripts/vue/anti-cheat/{main.js, style.css}` updated

## Checklist
- [ ] Navigation: Player → Moderation → AntiCheat analysis link opens `/Anticheat/GameSessionAnalysis?userId=...`
- [ ] Default range: 14 days back → today; immediately fetches all 3 endpoints
- [ ] All 4 endpoints respond with JSON; no console / network errors
- [ ] Heatmap renders dots for events
- [ ] Resolution preset dropdown lists `monitorInfo.distinctValues`
- [ ] Manual mode + offsets visibly shift dots
- [ ] Calibration persists across reload
- [ ] LRU: open 101 distinct userIds, oldest evicted
- [ ] Screenshots strip pages 20 at a time; selection drives heatmap background
- [ ] Apply filter: URL updates, no full reload, sections re-fetch
- [ ] Back button: previous filter restored
- [ ] Authorization: log in as non-Abuse role → 403
- [ ] Each LureKing sample: dense click cluster **visibly** falls inside the KEEP-rect outline (numeric anomaly scoring is Phase 4 — v1 verification is visual only)
- [ ] Jangalor (Steam Deck): cluster visible at window-center, no auto-bot verdict displayed (v1 surfaces signal, doesn't classify)

## Exit criteria
- All boxes ticked → ready to commit closing task
- Any failures → file as backlog item or block close, depending on severity
