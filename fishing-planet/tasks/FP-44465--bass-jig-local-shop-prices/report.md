# FP-44465 — Bass Jigs local-shop price fix — change report

**Status:** awaiting game-design sign-off (no DB changes applied yet)
**Environment:** validated on a local copy of the DEV database; target is DEV.
**Source ticket:** [FP-44465](https://fishingplanet.atlassian.net/browse/FP-44465) — *[FTUE][Local shop] Wrong levels and prices on bass jigs in local shops.*

## 1. What the task actually needs

Andrii Maslov's instruction: the Bass Jigs economy was reworked; update **level, rarity and
price** for the 82 listed item IDs in every local shop where they appear; **premium** rarity
keeps the global (baitcoin) price, **common** rarity is **×1.5**; **do not touch pond 119**.

Data-model finding that narrows the work:

- `LocalShop` stores **only a per-pond `Price`** (plus optional discount/date columns). It has
  **no level and no rarity columns**.
- `MinLevel` (level), `RaretyId` (rarity), `Currency` and the reference `Price` live in
  `InventoryItems` and are **shared** between the global shop and every local shop
  (the local shop is exposed via `VW_AllLocalItemInfo`, which reads `Currency`/level/rarity
  from `InventoryItems`).
- On this database `InventoryItems` already holds the **reworked** values for all 82 items
  (sensible Premium/Common split, new levels, new prices). Therefore level and rarity shown in
  local shops are **already correct** — nothing to change there.
- The **only stale, per-pond value is `LocalShop.Price`**. That is what the script fixes.

> The list contains **82** IDs, not 84 (32687 is intentionally absent between 32686 and 32688).
> All 82 exist in `InventoryItems` (`IsActive=1`, `IsGlobal=1`) and appear in at least one local shop.

## 2. Pricing rule (and proof it is the correct convention)

| Rarity | RaretyId | Currency | Local price |
|--------|----------|----------|-------------|
| Premium | 3 | GC (Gold / baitcoins) | = global price (×1.0) |
| Common  | 1 | SC (Cash) or GC       | = `ROUND(global × 1.5, 0)` |

Validation against the rest of the game (all non-bass-jig items, ponds ≠ 119):

- **Common / SC:** 4402 of 5042 local entries are exactly `global × 1.5` (the remainder are
  items with their own discounts). → ×1.5 is the standard local markup.
- **Premium / GC:** **all 2289** local entries are exactly `global × 1.0`. → premium keeps the
  global price.

So Andrii's rule is identical to the game-wide local-shop pricing convention.

## 3. Pond 119 note (correction)

Pond 119 is the **FTUE tutorial pond**. Every item there is priced at **global × 1.0**
(Common/SC: 2364/2364 at ×1.0; Premium: 1325/1325 at ×1.0) — i.e. **no local markup at all**,
not ×1.5. That is exactly why game-design asked to leave it untouched. The ×1.5 reference is the
regular ponds, not 119.

## 4. Scope of changes

Item IDs present per pond and how many rows change (formula applied, pond 119 excluded):

| Pond | Items in shop | Premium | Common | Rows that change |
|-----:|--------------:|--------:|-------:|-----------------:|
| 102  | 8  | 4 | 4  | 2  |
| 106  | 19 | 5 | 14 | 7  |
| 111  | 2  | 1 | 1  | 2  |
| 113  | 19 | 3 | 16 | 10 |
| 115  | 2  | 1 | 1  | 1  |
| 123  | 10 | 2 | 8  | 6  |
| 160  | 1  | 1 | 0  | 0 (already correct) |
| **119** | 82 | 32 | 50 | **excluded (FTUE)** |
| **Total (≠119)** | **61** | | | **28** |

No affected row has a discount price or a Start/End window — only `Price` is touched.

## 5. Detailed change set (28 rows)

`Cur` = current local price, `New` = target local price. Currency is the item's own currency.

| Pond | ItemId | Name | Rarity | Cur | → New | Note |
|-----:|-------:|------|--------|----:|------:|------|
| 102 | 451  | Mini Bass Jig 9 g, #2  | Common SC | 1    | 225  | common ×1.5 (global 150) |
| 102 | 513  | Mini Bass Jig 9 g, #1  | Premium GC| 1    | 2    | premium = global |
| 106 | 515  | Bass Jig 5 g, #2/0     | Premium GC| 645  | 6    | premium = global |
| 106 | 539  | Bass Jig 4 g, #1/0     | Premium GC| 525  | 3    | premium = global |
| 106 | 632  | Bass Jig 7 g, #2/0     | Premium GC| 690  | 6    | premium = global |
| 106 | 634  | Bass Jig 4 g, #3/0     | Common SC | 5    | 720  | common ×1.5 (global 480) |
| 106 | 636  | Bass Jig 4 g, #3/0     | Common SC | 5    | 720  | common ×1.5 (global 480) |
| 106 | 642  | Bass Jig 9 g, #3/0     | Common GC | 6    | 9    | common ×1.5 (global 6) |
| 106 | 644  | Bass Jig 9 g, #3/0     | Common GC | 6    | 9    | common ×1.5 (global 6) |
| 111 | 451  | Mini Bass Jig 9 g, #2  | Common SC | 1    | 225  | common ×1.5 (global 150) |
| 111 | 513  | Mini Bass Jig 9 g, #1  | Premium GC| 1    | 2    | premium = global |
| 113 | 650  | Bass Jig 14 g, #4/0    | Common SC | 7    | 1050 | common ×1.5 (global 700) |
| 113 | 651  | Bass Jig 14 g, #4/0    | Common SC | 7    | 1050 | common ×1.5 (global 700) |
| 113 | 654  | Bass Jig 28 g, #4/0    | Common SC | 8    | 975  | common ×1.5 (global 650) |
| 113 | 655  | Bass Jig 28 g, #4/0    | Common SC | 8    | 975  | common ×1.5 (global 650) |
| 113 | 1254 | Bass Jig 14 g, #3/0    | Common SC | 7    | 870  | common ×1.5 (global 580) |
| 113 | 1256 | Bass Jig 14 g, #3/0    | Common SC | 1050 | 900  | common ×1.5 (global 600), price drops |
| 113 | 1257 | Bass Jig 14 g, #3/0    | Common SC | 1050 | 900  | common ×1.5 (global 600), price drops |
| 113 | 1258 | Bass Jig 14 g, #3/0    | Common SC | 7    | 870  | common ×1.5 (global 580) |
| 113 | 1260 | Bass Jig 21 g, #3/0    | Premium GC| 900  | 7    | premium = global |
| 113 | 1265 | Bass Jig 28 g, #2/0    | Premium GC| 780  | 7    | premium = global |
| 115 | 1463 | Bass Jig 56 g, #6/0    | Premium GC| 1500 | 10   | premium = global |
| 123 | 647  | Bass Jig 14 g, #4/0    | Common SC | 990  | 1050 | common ×1.5 (global 700) |
| 123 | 649  | Bass Jig 14 g, #4/0    | Common SC | 990  | 1050 | common ×1.5 (global 700) |
| 123 | 648  | Bass Jig 14 g, #4/0    | Premium GC| 990  | 9    | premium = global |
| 123 | 653  | Bass Jig 28 g, #4/0    | Premium GC| 1170 | 9    | premium = global |
| 123 | 1032 | Bass Jig 56 g, #6/0    | Common SC | 10   | 1500 | common ×1.5 (global 1000) |
| 123 | 1033 | Bass Jig 56 g, #6/0    | Common SC | 10   | 1500 | common ×1.5 (global 1000) |

The pattern matches the bug exactly: common jigs were sitting at absurd low prices (1/5/7/8/10)
and several premium jigs at old inflated SC-style prices (525–1500) instead of single-digit GC.

## 6. Apply script

`artifacts/apply-local-shop-bass-jig-prices.sql` — a read-only PREVIEW query plus a transactional
APPLY block that sets `LocalShop.Price` for the 82 IDs in all ponds except 119 using the rule above,
records each change in the DataChanges commit-log (author + comment), and validates before committing.

## 7. Open questions for game-design

1. Confirm only `LocalShop.Price` needs changing — i.e. the reworked `InventoryItems` (level,
   rarity, global price) is the intended source of truth and is already correct on DEV.
2. Confirm `ROUND(×1.5, 0)` rounding for common items (no effect on the current set — all land on
   integers — but it fixes the rule going forward).
3. A few common items see their local price **drop** (e.g. pond 113 #1256/#1257: 1050 → 900) and
   a few rise — confirm that following the formula uniformly is desired even where the current
   value happened to be higher.
