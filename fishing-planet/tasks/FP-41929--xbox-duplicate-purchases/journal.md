---
task: FP-41929
title: "Investigate repeat product purchase on Xbox/UWP"
status: investigating
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-41929
related:
  - FP-42870
---

## Status

Investigation by Kateryna Churylova, Yuriy Burda, and Stanislav Samoilov revealed a systematic pattern — suspected exploit, not accidental double-clicks. Microsoft Store reports quantity 4/6+ to our server, which delivers accordingly. No player complaints about multiple charges received. Stanislav is preparing a request to Microsoft Store for detailed financial investigation.

## Summary

### Initial report (2026-01-17)

Players on Xbox receive duplicate purchases of the same product pack with intervals of ~300ms. Items are actually delivered to inventory each time.

Example — 6 purchases of "Chamaeleon Cruiser Pack" within 1.5 seconds:

| Date & Time                | Product ID | Product                 | Platform | Status   | Price  | Currency | Revenue |
|----------------------------|------------|-------------------------|----------|----------|--------|----------|---------|
| 2026-01-17 01:57:12.057    | 15639      | Chamaeleon Cruiser Pack | XBox     | Complete | 59.990 | USD      | 37.194  |
| 2026-01-17 01:57:12.387    | 15639      | Chamaeleon Cruiser Pack | XBox     | Complete | 59.990 | USD      | 37.194  |
| 2026-01-17 01:57:12.653    | 15639      | Chamaeleon Cruiser Pack | XBox     | Complete | 59.990 | USD      | 37.194  |
| 2026-01-17 01:57:12.917    | 15639      | Chamaeleon Cruiser Pack | XBox     | Complete | 59.990 | USD      | 37.194  |
| 2026-01-17 01:57:13.323    | 15639      | Chamaeleon Cruiser Pack | XBox     | Complete | 59.990 | USD      | 37.194  |
| 2026-01-17 01:57:13.603    | 15639      | Chamaeleon Cruiser Pack | XBox     | Complete | 59.990 | USD      | 37.194  |

### Investigation findings (2026-02-25, Kateryna Churylova)

Not isolated cases — systematic suspicious behavior across multiple players:

- Purchases go directly through Microsoft Store, **not** through in-game ad windows or premium shop
- Platform sends product **quantity 4/6+** to our server; server delivers exactly that amount
- Many cases recorded, but **zero player complaints** about multiple charges → suspected exploit
- Suspicious profile patterns: accounts dormant for months suddenly bulk-buying, or no activity after purchase

**Hypotheses:**
1. **Exploit — refund abuse:** pay for 1 product, receive multiple, refund "erroneous transactions" from platform
2. **Exploit — profile boosting:** duplicate premium + pond passes to rapidly boost new profiles
3. **Exploit — black market:** pump accounts with inventory/premium/gold, sell as "leveled up"
4. **Payment function bug** (Mykola Maslennykov, 2026-01-29): our system may treat a delay or step verification callback as a separate purchase
5. **Microsoft Store bug:** platform genuinely sending incorrect quantities

Screenshot attached to Kateryna's comment (image (52).png, JIRA attachment ID `ef468ac0-de60-4b9f-ac91-ff9102d99d2c`).

**Next step:** Stanislav to file a request with Microsoft Store for financial charge data on suspicious users and refund history.

### Known affected players

| UUID                                   | Pattern                                          | Source              | WebAdmin                                                                                                                                                                                           |
|----------------------------------------|--------------------------------------------------|---------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `9C43DAE4-F2EB-42E7-BA3C-97AEA1447D13` | duplicates on the 28th                           | initial report      |                                                                                                                                                                                                    |
| `C0EC2028-BA16-4235-982B-A49DFA8598C3` | unusual purchase pattern                         | initial report      |                                                                                                                                                                                                    |
| `97c29b84-4f1c-4119-ad20-9a1cdb465581` | new profile, bulk purchases after tutorial       | investigation 02-25 | [MergedLog](https://xb-webadmin.fishingplanet.com/Player/MergedLog?userId=97c29b84-4f1c-4119-ad20-9a1cdb465581&logs=Travel,Fishing,Inventory,Errors,Trade,Ad,License,Sys&time=2026-02-21_01-14-18) |
| `296e3718-e253-4ad9-9f06-69f2d0f1c3d6` | minimal activity, bulk purchases (×10) for years | investigation 02-25 | [PlayerCard](https://xb-webadmin.fishingplanet.com/Player/PlayerCard?userId=296e3718-e253-4ad9-9f06-69f2d0f1c3d6)                                                                                  |
| `daeeec01-d0e1-413a-b558-8ea08a98ac48` | fresh gold statement showing the problem         | investigation 02-25 | [StmtLog](https://xb-webadmin.fishingplanet.com/Player/StmtLog?userId=daeeec01-d0e1-413a-b558-8ea08a98ac48&currency=GC)                                                                            |

## Plan

(not yet drafted)

## Milestones
