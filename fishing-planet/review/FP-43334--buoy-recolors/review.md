---
task: FP-43334
title: "Colored Buoys: Server - Enable Free Marker Buoy Coloring"
executor: Yuriy Burda
status: resolved
started: 2026-04-15
resolved: 2026-04-15
---

## Summary

Enable unlimited free marker buoy recoloring on specific ponds (FTUE starter ponds).
Per-pond boolean flag `UnlimitedBuoyRecolors` + audit enum `BuoyRecolorPricing`.

## Scope

### Server commits (LBM)
| Rev    | Description                                                              |
|--------|--------------------------------------------------------------------------|
| r16003 | Add `UnlimitedBuoyRecolors` per-pond flag in BaseConfigJson              |
| r16006 | Add `LastRecolorPricing` enum on buoy for recolor audit                  |
| r16012 | Move `UnlimitedBuoyRecolors` from JSON to column, extend Buoys in admin  |

### Client commits (CodeBranch)
| Rev    | Description                                                          |
|--------|----------------------------------------------------------------------|
| r53190 | Add `UnlimitedBuoyRecolors` pond flag, temp guards for recolor UI    |

### Merges
| Rev    | Description               |
|--------|---------------------------|
| r16007 | MFT merge (r16003+r16006) |
| r16013 | MFT merge (r16012)        |

## Review comments (posted to JIRA)

1. Move parameter from JSON config to the grid (after pond-associated prices and discounts)
2. Add `BuoyRecolorPricing` to the Buoys table in Profile Card
3. Add buoy color to the Buoys table

All three addressed in r16012.

## Findings

### F-1: `BuoyRecolorPricing` enum — implicit ordinal values [Info]
Enum persists as int in `ProfileJson`. Values are positional (0..6). Explicit numbering would prevent drift on insertion, but team convention handles this. Not actionable.

### F-2: Magic number `100500` in client [Low]
`InGameMap.cs`: `MapHelper.GetFreeRecolorRemaining() ?? 100500`. Commit message says "temp guards". Value not displayed in UI (earlier HasValue check hides it). Functional but fragile — client side, not actionable here.

### F-3: Pricing edge case — base price 0 without premium → `Paid` [Info]
If `BuoyRecolorPriceGc == 0` globally and player has no premium: pricing = `Paid` but log says "for free". Contradictory but extremely unlikely config scenario.

### F-4: `LastRecolorPricing` bypasses dirty tracking [Info]
Plain auto-property, not using `Set()`. Not a bug — always set alongside `ColorId` which triggers dirty tracking. No reason to set it independently.

### F-5: Client `BuoySetting` lacks `LastRecolorPricing` [Info]
Server serializes it, client ignores (Newtonsoft default). Correctly handled via `ObfuscateClientProfile()`.
