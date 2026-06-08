# Crashed-currency / misconfigured-discount — evidence (2026-06, XB PROD)

Raw query outputs backing the FP-42870 #15 follow-up. Source: XB PROD MAIN, `PaymentSystemId IN ('XBox','Win10')`, `Status='Complete'`, `Products.Price>0`. Metric `capture = EquivalentPrice / Products.Price` (net USD booked ÷ USD catalog).

## Root cause: misconfigured regional discount (time series, capture by month)

Xbox and Win10 move in lockstep every month → **config issue, not the price parser** (parser is Win10-only). Discount was set ~10x too deep, then corrected.

### ARS — monthly capture (Xb+UWP)

| Period            |     Capture |             ≈ discount | Txns/mo |
|-------------------|------------:|-----------------------:|--------:|
| 2024-06 … 2025-09 | 0.006–0.010 |            ~98–99% off | 150–700 |
| 2025-10 … 2026-02 |   0.03–0.10 |             transition |   20–45 |
| 2026-03 … 2026-06 |   0.15–0.23 | ~65–75% off (intended) |     ~30 |

### TRY — monthly capture (Xb+UWP)

| Period            |                 Capture |          ≈ discount | Txns/mo |
|-------------------|------------------------:|--------------------:|--------:|
| 2024-06 … 2025-08 |             0.041–0.054 |         ~92–95% off |  50–250 |
| 2025-09           | transition (max → 0.29) |                     |         |
| 2025-10 … 2026-06 |               0.24–0.28 | ~70% off (intended) |  ~10–50 |

After the fix (~Sep–Oct 2025) volume collapsed (ARS ~700→~30/mo, TRY ~250→~20/mo): the cheap price was drawing the buyers/switchers.

## Value-capture ladder (all currencies, Xb+UWP, ≥20 txns, asc)

| Cur                            |  Txns | Capture | | Cur |    Txns | Capture |
|--------------------------------|------:|--------:|-|-----|--------:|--------:|
| ARS                            |  9580 |   0.021 | | NZD |    3790 |   0.526 |
| TRY                            |  4621 |   0.066 | | MXN |    1908 |   0.537 |
| COP                            |   174 |   0.295 | | CAD |   27122 |   0.577 |
| CLP                            |   379 |   0.297 | | ZAR |    7340 |   0.584 |
| IDR                            |    61 |   0.304 | | AUD |   28093 |   0.608 |
| CNY                            |    27 |   0.322 | | HUF |    4110 |   0.612 |
| UAH                            |   438 |   0.371 | | GBP |   71280 |   0.673 |
| INR                            |    37 |   0.383 | | EUR |   69971 |   0.684 |
| RSD                            |    34 |   0.404 | | USD | 1326721 |   0.706 |
| BRL                            | 10927 |   0.412 | | PLN |   24191 |   0.744 |
| (healthy baseline ≈ 0.68–0.71) |       |         | | CZK |    1336 |   0.794 |

## Volume / money (all-time, Xb+UWP)

| Cur |  Txns | Users | Net USD booked | "Foregone" vs full* | Txns 30d |
|-----|------:|------:|---------------:|--------------------:|---------:|
| ARS |  9580 |  1383 |         $5,305 |           ~$153,158 |       60 |
| TRY |  4621 |  1076 |         $6,694 |            ~$59,682 |       44 |
| BRL | 10927 |  3157 |        $53,776 |             $30,401 |      323 |

\* theoretical (`SUM(base)×0.62 − SUM(EquivalentPrice)`); buyers would not pay full price. Hard number = net booked (~$12k total for ARS+TRY ever).

## Where buyers are (UserCountries.Country = IP/login geo)

- **ARS**: ARGENTINA 7933/1196u; non-AR ≈ 1647 (17%) — CHINA 695/38u, HONG KONG 192/6u, UKRAINE 157, RUSSIA 76, US 74, MEXICO 62 …
- **TRY**: TURKEY 1810/414u; non-TR ≈ 2811 (**61%**) — UKRAINE 1055/303u, INDONESIA 442/55u, MALAYSIA 167/16u, KAZAKHSTAN 122, POLAND 102 …

## "Hunters" (top accounts, CatalogUsd = reference value extracted)

| UserId                                 | Country   | Cur | Txns | Prod | NetUsd | CatalogUsd | Window          |
|----------------------------------------|-----------|-----|-----:|-----:|-------:|-----------:|-----------------|
| `556CF59E-E54D-4BE6-9578-2E1C3750293B` | HONG KONG | ARS |  152 |   28 |    $29 |     $3,054 | 2024-07…2025-08 |
| `ED0A10EA-13F3-4F90-9218-108FDB823173` | CHINA     | ARS |   74 |   11 |    $16 |     $1,665 | 2024-07 (12d)   |
| `F6C63880-909F-43AE-9689-14162B2471F9` | CHINA     | ARS |   61 |   16 |    $12 |     $1,199 | 2024-07…09      |
| `BB0CB894-1A8E-4A83-81D6-F28462C857BE` | CHINA     | ARS |   60 |   37 |    $24 |     $1,197 | 2024-08…2026-02 |
| `E998FB9B-7F19-4C25-861B-82BD8CF7713F` | CHINA     | ARS |   59 |   21 |    $14 |     $1,482 | 2024-07 (6d)    |
| `948BB022-F228-49BC-8CC8-BFDECE69FEC8` | CHINA     | ARS |   51 |    6 |    $14 |     $1,479 | 2024-07 (4d)    |
| `BDD6D57E-E41F-475E-B067-C0D990A5A92C` | MALAYSIA  | TRY |   40 |   24 |   $285 |     $1,127 | 2026-01…05      |
| `D20EEA7B-5D67-40A9-94C7-ADBA1FCF4816` | INDONESIA | TRY |   36 |   18 |    $25 |       $547 | 2025-06         |

Legit Argentine heavy buyers (real local price, not abuse): `FF22A881-…` (40 distinct products), `EDDAE992-…` (63) etc.

## Notes / open

- MS Store Collection/Purchase API (learn.microsoft.com/.../view-and-grant-products-from-a-service) returns ownership, NOT price — useful for refund/ownership reconciliation, not for this price/leak audit.
- Residual near-zero `/1000` ARS subset (FP-42870 #15 literal `1.60` vs `1599`) likely old-parser under-direction (Win10, FP-40470-era) — separate, still open.
- Historical ARS/TRY rows during the misconfig window are correctly-recorded-wrong-price; whether to restate is a separate decision.
