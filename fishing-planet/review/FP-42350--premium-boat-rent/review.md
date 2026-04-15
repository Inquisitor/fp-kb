---
task: FP-42350
title: "FTUE. PremPromo. Server - Free Boat Rent for Prem.Acc"
executor: Yevhenii Shust
status: resolved
started: 2026-04-15
resolved: 2026-04-15
---

## Summary

Free boat rent for Premium Account holders. Server multiplies rent price by 0 for premium users, forces 1-day rent to prevent exploit, and allows zero-price transactions through.

## Scope

### Server commits (MFT)
| Rev    | Description                                                     |
|--------|-----------------------------------------------------------------|
| r15985 | Add premium multiplier for boat rent price; set to zero         |

### Client commits (CodeBranch)
| Rev    | Description                                                       |
|--------|-------------------------------------------------------------------|
| r53061 | Boat rent DiscountMultiplier is now calculated using SharedConsts |

## Review comments (posted to JIRA)

### Comment 1 — Server review resolution
LGTM. Server logic correct: `daysCount` forced to 1 for premium (anti-exploit), `|| fullPrice == 0` allows zero-price transactions. Minor note: `(int)` cast truncates rather than rounds — not an issue with current multiplier (0).

### Comment 2 — Notes for client lead (@Kyrylo Rovnyi)
1. Server forces `daysCount = 1` for premium — client `BoatRentHandler` still shows day selector, should hide/lock it.
2. Pre-existing: `BoatRentHandler.RentABoat()` always passes `PricePerDay × daysRequested` to `FullBuyFlow`, even in tournaments where actual price is `PricePerHour × InGameDuration`.

## Findings

### F-1: Analytics logs incorrect price on boat rent [High] → FP-43407
Pre-existing. `analytics.LogRentBoat()` passes `price.PricePerDay * daysCount` instead of `fullPrice` in both tournament (line 1592) and regular (line 1644) rent paths. Trade log (`DbLog.Trade`) logs correctly. Two affected scenarios:
- Tournament: always wrong (different price base)
- Regular rent with premium: logs full price instead of 0

Filed as FP-43407. Fix target: LBM (current release).

### F-2: `(int)` truncation on discounted price [Low]
`(int)(fullPrice * Multiplier)` truncates instead of rounding. Not an issue with current multiplier (0 or 1). Pre-existing pattern — old code did the same with divider.

### F-3: Client day selector not hidden for premium [Info]
`QuantityController.SetActive(false)` only in tournament path. For regular rent with premium, day selector is visible but server ignores selection. Delegated to client team.

### F-4: Client `RentABoat()` wrong formula in tournaments [Info]
`FullBuyFlow` always receives `PricePerDay × daysRequested`, even during tournaments. Pre-existing, masked by multiplier = 0. Delegated to client team.
