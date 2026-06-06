# tradeLog price-string samples (raw copies)

Source: XB PROD Mongo, db `main2`, collection `tradeLog`. Client price-load telemetry
`[CLN]: CLIENT uwp: Price found ...` — carries the raw store string AND the parse result
`(Price/DiscountPrice)`. Saved here because tradeLog retention is **90 days** — these will be purged.
Captured 2026-06-02.

Format of each line: `Timestamp | [CLN]: ... 'Name', ForeignProductId: X - <RAW STRING> CUR (<parsedPrice>/<parsedDiscount>)`

Legend of the bug: parser only handles ASCII `,` / `.`; any other separator the device
locale emits is stripped by `CleanupPriceStr`, fusing the fractional digits → ×100 (or ×1000).

---

## Case 1 — TRY, Arabic separators `٫` (U+066B) / `٬` (U+066C) — ×100

UserId: `816B7D4A-3914-43A6-8DE9-5AE4FD9E489F` (single TRY player; all TRY anomalies in DB are his)
Recorded Transactions: 12 rows, all Price=19000 (mostly product 14503 / 2230), 2026-04-28…05-28.

```
2026-05-30 | #15994 'Norway Weeklong Chronicle' 9P1N0VP9D8L8 - 190٫00 TRY (19000/)
2026-05-30 | #16016 'Norway Monthlong Epos'     9PBPTD00X88H - 285٫00 TRY (28500/)
2026-05-30 | #15921 'Valkyrie Saga Pack'        9NDR1TZ4FH31 - 1٬900٫00 TRY (190000/)   <- thousands ٬ + decimal ٫
2026-05-30 | #15405 'Pro Fishing Starter Pack'  9N54QD90ST8B - 950٫00 TRY (95000/)
2026-04-28 | #2230  '30 DAYS OF PREMIUM ACCOUNT' BV418GFQXTZK - 190٫00 TRY (19000/)     <- matches recorded txn
2026-04-28 | #2190  '2.330 BAITCOINS'           C5GQPPL601SH - 1٬900٫00 TRY (190000/)
2026-04-28 | #2200  '1 DAY OF PREMIUM ACCOUNT'  C0PQ5R7JTQ31 - 28٫00 TRY (2800/)
```

Same user, EUR session (currency incidental — locale is the axis):
```
2026-04-28 | #2140 '50 BAITCOINS'  BNQSGPT638M1 - 2٫99 EUR (299/)
2026-04-28 | #2190 '2.330 BAITCOINS' C5GQPPL601SH - 99٫99 EUR (9999/)
```

---

## Case 2 — SAR, Arabic separator `٫` (U+066B) — ×100 (incl. discounted rows)

UserId: `375FD85C-147F-4BA6-9AB2-12E7C7084275` (one of three SAR players)
Other SAR players: `E732D34A-E950-4D03-8F16-76DE9E0D5B57`, `9E42DA4A-F988-45C6-81ED-05001E42CD42`

```
2026-05-27 | #15994 'Norway Weeklong Chronicle' 9P1N0VP9D8L8 - 37٫50 SAR (3750/)
2026-05-27 | #2230(via 15685 path) 'Maldives Weeklong' 9N4L0HBW1BJP - 37٫50 SAR (3750/)
2026-05-27 | #15650 'Atoll Scout Pack' 9PCPJFL28648 - 104٫30 SAR (14900/10430)   <- base 149٫00 + discount 104٫30, both ×100
2026-05-27 | #15640 'Chamaeleon Cruiser Pack' 9NPRC3H1LMV7 - 156٫80 SAR (22400/15680)
2026-05-27 | #15216 'Green Fortune Event Pack' 9PHKHR8G99VW - 74٫00 SAR (7400/)
```

---

## Case 3 — BRL, dash separator `-` — ×100 (EXOTIC per-user locale, NOT Brazilian norm)

UserId: `659B4C44-96E8-4DB0-BFA4-4A881A2053D9`
Recorded Transactions: 2 rows (3495 product 2230, 8745 product 15094), 2026-02-24/27.
NOTE: latest logs are 2026-03-05 — at the edge of the 90-day window, about to be purged.

```
2026-03-05 | #15921 'Valkyrie Saga Pack'   9NDR1TZ4FH31 - 209-95 BRL (20995/)
2026-03-05 | #15685 'Maldives Weeklong Getaway' 9N4L0HBW1BJP - 34-95 BRL (3495/)
2026-03-05 | #15397 'Pro Upgrade Pack'     9NXS1D19TS32 - 87-45 BRL (8745/)    <- matches recorded txn (product 15094 same price tier)
2026-03-05 | #15922 'Nordic Legend Pack'   9NZB4M68MZ47 - 139-95 BRL (13995/)
2026-03-05 | #15105 'All-Times Christmas Bundle' 9MV08RPCVZCB - 104-95 BRL (10495/)
```

---

## Control — BRL, normal comma `,` — CORRECT (no inflation)

UserId: `9495F883-A579-4502-91FC-0EA7A0B96DFA` (top-volume Brazilian, normal locale)

```
2026-?? | #15994 'Norway Weeklong Chronicle' 9P1N0VP9D8L8 - 34,95 BRL (34,95/)   <- parses to 34.95, correct
2026-?? | #15921 'Valkyrie Saga Pack'        9NDR1TZ4FH31 - 209,95 BRL (209,95/)
2026-?? | #2230-tier 'Pro Upgrade Pack'      9NXS1D19TS32 - 87,45 BRL (87,45/)    <- same product, normal locale: 87.45 not 8745
```

Direct contrast: product `9NXS1D19TS32` (Pro Upgrade Pack) — normal BR user → `87,45` (correct 87.45);
exotic-locale BR user → `87-45` → 8745 (×100). Same product, same currency, different device locale.

---

## Control — KWD, ASCII dot `.` as thousands — ×1000 (the FP-39539 / 3-decimal class)

UserId: `D7926949-4DB7-40DD-9160-34047266A1DF`
This is a different mechanism (ASCII `.` + 3 trailing digits heuristic, 3-decimal currency),
fixed by FP-39539 (pending release). Recorded: 1.800 KWD → 1800, 18.000 KWD → 18000.
