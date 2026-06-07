# FP-43705 — Scope results (negative consumable counters)

Per-platform findings from `scope-queries.sql`. Detection = count-stack item (Bait/Feeder/…)
with `Count < 0` in `Profiles.ProfileJson` → `$.Inventory.Items[]`. Type/SubType ids are the
item-category ids (`ParentCategoryId`=ItemType, `CategoryId`=ItemSubType).

## [F2P] MOB PROD MAIN — scanned 2026-06-07

Pre-scan (STEP 1–2) run manually by user (~1h full scan). Candidates materialized in
`dbo.FP43705_Candidates_20260607`. STEP 4 analysis run by agent (fast, PK joins).

**8 affected players, 1 negative item each, all off-rod (Storage = Equipment).**

| Username           | Lvl | Rank | Item                 | Kind      | SubType (id)         | Count |
|--------------------|----:|-----:|----------------------|-----------|----------------------|------:|
| Dave11Bravo        |  56 |    0 | PVA Bag Large Golden | PvaFeeder | PVA Feeders (135)    |   −10 |
| Woi_k0n7ol         | 100 |    2 | Luminous Flying Fish | Bait      | Trolling Baits (188) |    −6 |
| Fishing_ShuRup     |  55 |    0 | PVA Bag Large        | PvaFeeder | PVA Feeders (135)    |    −2 |
| ipansudipan        |  68 |    0 | PVA Mesh Wide        | PvaFeeder | PVA Feeders (135)    |    −2 |
| jimmydruse79       |  55 |    0 | PVA Mesh Wide        | PvaFeeder | PVA Feeders (135)    |    −1 |
| MatheusGarcia      |  60 |    0 | PVA Bag Large Golden | PvaFeeder | PVA Feeders (135)    |    −1 |
| pescadornacional   |  53 |    0 | PVA Bag Large Golden | PvaFeeder | PVA Feeders (135)    |    −1 |
| BlackBassMachine81 |  60 |    0 | PVA Bag Large        | PvaFeeder | PVA Feeders (135)    |    −1 |

Notes: 7/8 are PVA feeders, 1 trolling bait. All single, small magnitude → accidental
trigger, not mass exploitation. Confirms the fix scope (bait + PvaFeeder replenish).

Activity (LastLoginDate, as of 2026-06-07): only 3/8 active in the last ~2 weeks
(MatheusGarcia 06-07 −1, Woi_k0n7ol 06-03 −6, pescadornacional 05-23 −1). The deepest
Mob case (Dave11Bravo −10) has been dormant since 2025-03; jimmydruse79 / ipansudipan
dead since 2024. No active exploitation; not urgent.

## [F2P] STEAM PROD MAIN — scanned 2026-06-07

**141 affected players, 1 negative item each.** Largest platform but same shape.

By item kind: PVA Feeders 97, Insect/Worm Baits 25, Fresh Baits 12, Common Baits 5,
Saltwater Baits 2, Boil Baits 2.

Activity / severity (as of 2026-06-07):
- 25/141 active in the last 2 weeks; of those only **3** are also deep (≤ −20).
- Deepest sane: **−460** (KhoroshunSerg, last login 2026-05-23). Other notable active:
  haiminh992 −117 (06-07), YoungmanFishing −41 (06-06), warius13 −32 (06-03).
- **1 corrupted/overflow value**: JesusIsMyFishingBuddy1969 = −1,773,901,869 (int wrap),
  level 3, dormant since 2020 — an old separate artifact caught by the same `Count<0` net,
  not current-STR depletion.

Still 1 item per player (no stockpiling). Higher volume but economically trivial
(cheap consumables); only a handful of active+deep cases.

### Cheat-review candidates (deep ≤ −20, recently active)
| Username        | LastLogin  | Lvl | CheatRating | Item           | Count | UserId                               |
|-----------------|------------|----:|------------:|----------------|------:|--------------------------------------|
| haiminh992      | 2026-06-07 | 109 |      169291 | Bluey (Bait)   |  −117 | 437F3477-9F10-4EFC-8D6D-880B75248BA6 |
| warius13        | 2026-06-03 |  98 |       49862 | PVA Bag Large  |   −32 | 8C7289B6-B1C0-46D5-8285-4E681EACF9C0 |
| YoungmanFishing | 2026-06-06 |  47 |        1895 | PVA Mesh Wide  |   −41 | DC178EC2-E273-4130-B48F-2862D8CCCD6F |
| KhoroshunSerg   | 2026-05-23 |  61 |       13436 | PVA Bag Medium |  −460 | D9F4EDD3-248A-49CB-8689-D7176FFA7EFD |

haiminh992 (169k) and warius13 (50k) have markedly elevated CheatRating — flagged for manual review.

### Anomaly: int-overflow account
JesusIsMyFishingBuddy1969 (UserId A68A5F6A-78E6-44BE-8DD7-0AE72BBA7D77): Red Worms in Storage,
Count = −1,773,901,869 (int wrap). Level 3, last login 2020-08-21, IsActive=true, CheatRating=NULL.
Suspected old (already-fixed?) exploiter. Decision: **no separate one-off** — it is in the
candidate set and the offline `FixDepletedItems` finalizer will remove the corrupted stack like
any other depleted item (count≤0 off-rod). The account is dormant, so login auto-apply would not
reach it, but the offline finalizer does.

## [F2P] XB PROD MAIN — scanned 2026-06-07

**22 affected players, 1 negative item each** (deepest −44). Off-rod (Equipment, some Storage).
Breakdown by item (Items = #players):

| Item                  | Kind      | SubType (id)          | Storage   | Items | DeepestNeg |
|-----------------------|-----------|-----------------------|-----------|------:|-----------:|
| PVA Bag Large         | PvaFeeder | PVA Feeders (135)     | Equipment |     5 |        −44 |
| PVA Bag Large Golden  | PvaFeeder | PVA Feeders (135)     | Equipment |     4 |         −2 |
| PVA Bag Medium        | PvaFeeder | PVA Feeders (135)     | Storage   |     3 |         −9 |
| PVA Bag Medium Golden | PvaFeeder | PVA Feeders (135)     | Equipment |     2 |        −41 |
| PVA Bag Medium        | PvaFeeder | PVA Feeders (135)     | Equipment |     2 |        −36 |
| PVA Bag Large         | PvaFeeder | PVA Feeders (135)     | Storage   |     1 |        −25 |
| Black Lugworms        | Bait      | Saltwater Baits (184) | Equipment |     1 |        −16 |
| PVA Mesh Wide Golden  | PvaFeeder | PVA Feeders (135)     | Equipment |     1 |         −4 |
| PVA Mesh Narrow       | PvaFeeder | PVA Feeders (135)     | Storage   |     1 |         −1 |
| PVA Mesh Medium       | PvaFeeder | PVA Feeders (135)     | Equipment |     1 |         −1 |
| PVA Mesh Wide         | PvaFeeder | PVA Feeders (135)     | Storage   |     1 |         −1 |

21/22 PVA feeders, 1 saltwater bait. Same pattern as Mob (single item, off-rod, accidental).

Activity (LastLoginDate, as of 2026-06-07): ~8/22 active in the last 2 weeks, and those are
almost all −1 (exceptions: N76058 −44, CaptGraybush609 −9). The deepest cases are mostly
dormant/dead (J1Slapit −41 last login 2023-01, Criminel −36, Welshysi −33, UnpricedCub48 −25).
No stockpiling (1 item each, not growing) -> no active mass exploitation; not urgent.

## [F2P] PS PROD MAIN — scanned 2026-06-07

**56 affected players, 1 negative item each.** Same pattern.
By item: PVA Feeders 49, Fresh Baits 5, Boil Baits 1, Common Baits 1.
Deepest −72 (Marcos_pro_-, last login 2026-05-04). Recent active deep: Sascha730 −37 (06-07),
cedricv14 −21 (06-03). No stockpiling; not urgent.

Scan note: 11M+ rows but full scan took only ~54 min (vs Steam 9M ~2h). Not a skip — the
NOLOCK scan completed cleanly (601 would abort, not silently drop). Avg ProfileJson sampled:
PS ~54 KB vs Steam ~69 KB, so total bytes are comparable despite more rows; the remaining
speed gap is throughput (Steam is the busiest prod; the PS retry also hit a warm buffer cache
from its earlier 601-aborted attempt).

## [F2P] NX PROD MAIN+STATS — scanned 2026-06-07

Pre-scan returned **0 candidates** — no affected players on Nintendo.

## Running tally (all F2P platforms scanned — COMPLETE)
| Platform | Affected | Active ≤2wk | Notes                                                        |
|----------|---------:|------------:|--------------------------------------------------------------|
| Steam    |      141 | 25 (3 deep) | PVA feeders dominate; deepest −460; 1 int-overflow (dormant) |
| PS       |       56 |           — | PVA feeders 49; deepest −72                                  |
| XB       |       22 |          ~8 | deepest −44                                                  |
| Mob      |        8 |           3 | deepest −10                                                  |
| NX       |        0 |           0 | —                                                            |
| Total    |      227 |             | 1 item/player everywhere; PVA feeders dominant; not urgent   |

## Platforms (all done)
- [x] [F2P] STEAM PROD MAIN — 141 affected
- [x] [F2P] PS PROD MAIN — 56 affected
- [x] [F2P] XB PROD MAIN — 22 affected
- [x] [F2P] MOB PROD MAIN — 8 affected
- [x] [F2P] NX PROD MAIN+STATS — 0 affected

## Out of scope
- Retail platforms ([Retail] STEAM/PS, [Retail] XB) — NOT scanned: the fix is not
  deployed to Retail, so remediation does not apply there.
