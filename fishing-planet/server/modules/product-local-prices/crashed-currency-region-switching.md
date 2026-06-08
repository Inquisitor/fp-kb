# Crashed-currency region-switching (ARS / TRY) — Xb+UWP

> Investigation started under the FP-43192 branch (2026-06-08), follow-up to FP-42870 finding #15.
> Data: XB PROD MAIN, `PaymentSystemId IN ('XBox','Win10')`, snapshot 2026-06-08. Not yet a JIRA ticket.

## What this is

Not a recording bug. Some Microsoft Store **currencies have crashed** (hyperinflation) so their local prices, converted to USD, are worth almost nothing — and purchases still flow through them, including from **accounts physically outside that region** (region-switching). We record the real (tiny) revenue; the catalog value walks out the door for cents.

This largely explains FP-42870 #15 ("ARS/CLP/COP store a USD-scaled amount … needs investigation"): the **bulk** of the ARS/CLP/COP low values are **not** a USD-substitution code bug — they are real, crashed regional prices (capture ~2–7%).

**Caveat — a separate, smaller subset is still open.** #15's literal example (`ours=1.60` vs `MS=1599`, a clean **/1000**) is a *near-zero-capture* anomaly that region-switching does NOT explain. Most likely an **old UWP-parser under-direction** (Win10 `1.599` with dot-as-thousands read as `1.599`, the under-direction twin of the FP-43192 over-direction bug — fixed forward by FP-40470, but the historical data was never corrected, since our data-fix only handled over-inflation). Could also be a true USD-substitution residual. Not yet isolated — see Open next steps.

## Metric: value capture

`capture = EquivalentPrice / Products.Price` = net USD we actually book ÷ USD catalog (reference) price. It folds together regional cheapness and our 38% fee:

`capture ≈ 0.62 × (regional price as a fraction of USD catalog)`

- Healthy baseline: **~0.68–0.71** (USD/EUR/GBP) — i.e. our ~62% cut minus small VAT/discount effects.
- Crashed: ARS **0.021**, TRY **0.066** — we net 2–7% of the product's reference value.

### Value-capture ladder (Xb+UWP, ≥20 txns, asc)

| Currency | Txns | Capture | Note |
|----------|-----:|--------:|------|
| ARS | 9580 | **0.021** | crashed; region-switched |
| TRY | 4621 | **0.066** | crashed; region-switched |
| COP / CLP | 174 / 379 | ~0.30 | gray tier (cheap region or partial crash) |
| IDR / CNY / UAH / INR / RSD / BRL | … | 0.30–0.41 | gray tier; BRL is high-volume normal-ish |
| … | | | |
| GBP / EUR / USD | huge | 0.67 / 0.68 / 0.71 | healthy baseline |

Clear anomalies = **ARS, TRY**. The 0.30–0.41 tier (incl. BRL, which actually nets us ~$54k) is mostly legitimate cheaper-region pricing, not a leak to chase.

## Volume and money (all-time, Xb+UWP)

| Currency | Txns | Users | Net USD booked | "Foregone" vs full price* | Txns last 30d |
|----------|-----:|------:|---------------:|--------------------------:|--------------:|
| ARS | 9580 | 1383 | **$5,305** | ~$153,158 | 60 |
| TRY | 4621 | 1076 | **$6,694** | ~$59,682 | 44 |

\* "Foregone" = `SUM(base_USD)×0.62 − SUM(EquivalentPrice)` — theoretical (these buyers would not pay full price), shown for magnitude only. The real, hard number is the booked net: **ARS+TRY earned us ~$12k total, ever.** Still live (~100 purchases/month combined).

## Where the buyers actually are (country = IP/login geolocation)

`UserCountries.Country` is set at login from **IP geolocation** (`ProfileAdapter` → `SysProvider.LookupCountryByIpAddress(ip)` in the main paths; the Xbox path uses `xstsData.Country` = Xbox account region). So `Country = AR` while paying ARS is a local; `Country = CHINA` while paying ARS is a **switcher** (real location China, store region Argentina).

- **ARS**: ARGENTINA 7933 / 1196 users (locals); non-Argentina ≈ **1647 txns (17%)** — CHINA 695/38u, HONG KONG 192/6u, UKRAINE 157, RUSSIA 76, US 74, MEXICO 62, GERMANY 38, …
- **TRY**: TURKEY 1810 / 414 users; non-Turkey ≈ **2811 txns (61%!)** — UKRAINE 1055/303u, INDONESIA 442/55u, MALAYSIA 167/16u, KAZAKHSTAN 122, POLAND 102, RUSSIA 96, …

China/HK/SE-Asia/CIS are classic region-switching hubs. TRY is majority non-Turkish.

## Concrete "hunters" (top accounts, 2026-06-08)

High purchase count + non-local country + lots of distinct products = deliberate exploitation. `CatalogUsd` = reference value extracted; `NetUsd` = what we booked.

| UserId | Country | Cur | Txns | Distinct prod | NetUsd | CatalogUsd | Window |
|--------|---------|-----|-----:|----:|-------:|-----------:|--------|
| `556CF59E-E54D-4BE6-9578-2E1C3750293B` | HONG KONG | ARS | 152 | 28 | $29 | **$3,054** | 2024-07 … 2025-08 |
| `ED0A10EA-13F3-4F90-9218-108FDB823173` | CHINA | ARS | 74 | 11 | $16 | $1,665 | 2024-07 (12 days) |
| `F6C63880-909F-43AE-9689-14162B2471F9` | CHINA | ARS | 61 | 16 | $12 | $1,199 | 2024-07…09 |
| `BB0CB894-1A8E-4A83-81D6-F28462C857BE` | CHINA | ARS | 60 | 37 | $24 | $1,197 | 2024-08 … 2026-02 |
| `E998FB9B-7F19-4C25-861B-82BD8CF7713F` | CHINA | ARS | 59 | 21 | $14 | $1,482 | 2024-07 (6 days) |
| `948BB022-F228-49BC-8CC8-BFDECE69FEC8` | CHINA | ARS | 51 | 6 | $14 | $1,479 | 2024-07 (4 days) |
| `BDD6D57E-E41F-475E-B067-C0D990A5A92C` | MALAYSIA | TRY | 40 | 24 | $285 | $1,127 | 2026-01 … 2026-05 |
| `D20EEA7B-5D67-40A9-94C7-ADBA1FCF4816` | INDONESIA | TRY | 36 | 18 | $25 | $547 | 2025-06 |

Contrast — legitimate Argentine heavy buyers (real local price, not abuse): `FF22A881-…` (40 distinct products, $1,997 catalog), `EDDAE992-…` (63 distinct products) etc. — they live in AR, so it's their actual regional price.

## Why it matters / business framing

Not fixable in code — the data is correct. This is **liveops / MS Partner Center pricing**:

- **Raise ARS/TRY catalog prices** in Partner Center to track current FX (so they aren't 2–7% of value). Cleanest, but hits legit locals too.
- **Delist / stop offering** products in crashed-currency regions. Blunt; collateral on locals.
- **Accept** — absolute $ is tiny (~$12k booked ever), but it's a standing leak + a known abuse channel that can scale.
- Real-world context: **Steam removed ARS and TRY as currencies in 2023** (moved Argentina/Turkey to USD pricing) precisely because of this; Xbox/MS still carry them.

## Open next steps (start points)

- Confirm switching per platform: split the non-local ARS/TRY rows by `PaymentSystemId` — Win10 → `Country` is IP (definitive switch); Xbox → `xstsData.Country` (account region, still anomalous).
- Per-hunter drill: what exactly the top accounts buy (expensive packs/DLC?), burst timing, whether any resell.
- Gray tier (COP/CLP/IDR/CNY/UAH/INR/RSD): decide legit-cheap-region vs partial-crash; don't act blindly.
- Cross-platform: do Steam/PS/Mobile stacks still carry ARS/TRY? (Steam dropped them 2023.)
- **Isolate the near-zero /1000 subset** (capture < ~0.005): split by `PaymentSystemId` + era. If Win10 pre-2025-11 → old-parser under-direction (FP-40470-era), and the historical rows need an under-direction data-fix (÷ not applicable — these are too-small; would need recompute from the real store price, which we don't store). This is the genuine recording-error remnant of #15.
- Decide ticketing: this warrants its own liveops ticket (FP-42870 #15 successor).

## Reproduce

- Value capture: `AVG(EquivalentPrice/NULLIF(Products.Price,0))` per Currency, `PaymentSystemId IN ('XBox','Win10')`, `Status='Complete'`, `Products.Price>0`.
- Country: `LEFT JOIN UserCountries c ON c.UserId = t.UserId`.
- Hunters: group by `UserId, Country, Currency` order by `COUNT(*)` desc.
