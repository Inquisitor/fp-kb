---
status: resolved
executor: Yevhenii Shust
branch: MFT @ r15985, CodeBranch @ r53061
jira: https://fishingplanet.atlassian.net/browse/FP-42350
---

# Review: FP-42350 — FTUE. PremPromo. Server - Free Boat Rent for Prem.Acc

## Summary

Free boat rent for Premium Account holders. Server multiplies rent price by 0 for premium users, forces 1-day rent to prevent exploit, and allows zero-price transactions through.

## Scope

### MFT
- **r15985** — Add premium multiplier for boat rent price; set to zero

### CodeBranch
- **r53061** — Boat rent DiscountMultiplier is now calculated using SharedConsts

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
