---
task: FP-43192
title: "[Win10/UWP] Incorrect currency price parsing"
status: in-progress
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-43192
related:
  - FP-40470
  - FP-39539
  - FP-42870
  - FP-35241
---

## Status

Investigation **complete**, root cause confirmed via Mongo `tradeLog` (production input→output proof). Rescoped from "KWD" to general incorrect UWP price parsing. **Root cause: `UwpManager` parser only recognises ASCII `,`/`.` as separators; any other separator the device locale emits (Arabic `٫`/`٬`, dash `-`, etc.) survives `NormalizeSeparators`, then `CleanupPriceStr` strips it, fusing the fractional part → price inflated ×100/×1000.** Axis is device locale, not currency. JIRA reformulated. Full prod separator inventory captured (708k events) — fix strategy validated against real data. **Parser fix implemented** in both copies (client `UwpManager.cs` + server mirror) and **tests green (37/0)**. Next: SVN-commit on CodeBranch before the **2026.4 FTUE rework** release cut; then data-fix historical rows by magnitude signature post-release (incl. one-off device rows).

## Summary

Microsoft Store on UWP/Win10 returns prices only as locale-formatted strings (`FormattedPrice`, no numeric field), so `UwpManager.GetFloatPrice` parses the string. Its separator heuristic misclassifies decimal vs thousands separators for several currencies, recording prices inflated by ~×100/×1000. The inflated `Price` then flows into `EquivalentPrice` (USD-equivalent, minus 38% fee), so revenue figures for affected transactions are wildly overstated.

Example player `D7926949-4DB7-40DD-9160-34047266A1DF` (XB PROD, 2026-05-31, both Win10):

| Product | Base USD | Store price (KWD) | Recorded `Price` | Recorded `EquivalentPrice` | Should be |
|---------|---------:|------------------:|-----------------:|---------------------------:|----------:|
| 2150    |    $5.99 |         1.800 KWD |             1800 |                   3606.515 |     ~3.61 |
| 15921   |   $59.99 |        18.000 KWD |            18000 |                   36065.15 |    ~36.07 |

Recorded ≈ \$39,672 vs actually paid ≈ $39.7.

### EquivalentPrice formula (verified empirically)

`EquivalentPrice = Price(local) × marketRate(local→USD) × (1 − FeePercent/100)`, FeePercent=38 ⇒ ×0.62.
Check: KWD `1800 × 3.232 × 0.62 = 3606.5` (exact). The fee/conversion math is correct — it is simply applied to an already-inflated `Price`. So **fixing the parser auto-fixes `EquivalentPrice`** (it scales linearly); no separate `EquivalentPrice` correction needed beyond correcting `Price`.

## Diagnosis

### The parser lives only in the client; only UWP is affected

- `UwpManager.UpdatePlatformProductPrice` → `GetFloatPrice(FormattedPrice, currencyCode)` → `NormalizeSeparators`. Parses `Windows.Services.Store` locale strings.
- Xbox uses GDK numeric `XStorePrice.Price` directly → **immune**. Every anomalous row observed is `PaymentSystemId = 'Win10'`.
- Server has **no** parsing code: it stores whatever number the client sends (confirmed in FP-39539 review). So "server fix on prod, client fix not on prod" is moot — the functional fix is 100% client-side.

### Parser timeline (client SVN, repo CLN)

```
r48291  old parser (decimalChar heuristic + explicit "kr." handling for DKK)
r50247  FP-40470 "Fix price parsing on UWP"        2025-10-30  CodeBranch
        -> auto-merge into MainClient r50354 (2025-11-04) -> ON PROD since Nov 2025
        rewrote parser; introduced rule "single separator + exactly 3 trailing digits = thousands"
        with NO currency awareness. This rule turns KWD "1.800" -> 1800.  <-- root of FP-43192
r53528  FP-39539 "Fix UWP price parsing for 3-decimal currencies"  2026-04-28  CodeBranch
        added currencyCode + ThreeDecimalCurrencies exception (BHD/IQD/JOD/KWD/LYD/OMR/TND)
        -> merged into MainClient (content) r54243 (2026-05-18)
        -> NOT in any shipped UWP release yet (see release-cut gap below)
```

### Why the fix is not on prod (release-cut vs trunk-merge)

- 2026.3 Leaderboards prod branch `Unity_Fishing_MainClient_LeaderboardsStable` was snapshotted **2026-05-14** (r54163) — its `UwpManager.cs` carries the **old FP-40470 parser** (no `ThreeDecimalCurrencies`).
- FP-39539 (r53528) landed in content trunk **2026-05-18** — 4 days after the release cut.
- Norway prod branch (`Unity_Fishing_CodeBranch_Norway2`, cut 2025-10-01) is older still — no fix.
- A release branch is a snapshot; a commit merged to trunk after the cut is not in that release. The KWD fix will reach prod only with the **next** UWP release cut after r54243 — that is **2026.4 FTUE rework** (no cherry-pick planned; release in ~1-2 weeks per executor).

### Root cause confirmed — tradeLog production evidence

Client price-load telemetry is forwarded to server Mongo `tradeLog` (collection `main2.tradeLog`, prefix `[CLN]: CLIENT uwp:`), logging the raw store string AND the parse result in one line. Examples (input → recorded):

```
190٫00 TRY   -> 19000     (٫ = U+066B Arabic decimal separator)
1٬900٫00 TRY -> 190000    (٬ = U+066C Arabic thousands separator + ٫ decimal)
2٫99 EUR     -> 299       (same Arabic-locale user, even on EUR)
209-95 BRL   -> 20995     (separator is a dash "-", not comma — Brazil is NOT Arabic-locale)
34-95 BRL    -> 3495
```

The parse result in parentheses is the client's own output — this is production proof, stronger than a unit-test repro. Two distinct non-ASCII/unexpected separators already confirmed (`٫`/`٬` and `-`), so the bug is **separator-class-general**, not Arabic-specific, and **locale-driven, not currency-driven** (the EUR line proves currency is incidental).

**Confirmed only for exotic device locales.** A normal-locale buyer parses fine: top-volume Brazilian `9495F883-…` shows `34,95 BRL (34,95/)` (comma → 34.95, correct). The anomalous BRL user `659B4C44-…` uses a dash and gets `87-45 → 8745` — same product `9NXS1D19TS32`, same currency, different device locale. So mass locales (comma/dot) are safe; only minority exotic-locale users are hit → tiny volume.

**Case UserIds** (raw log copies saved in `artifacts/tradelog-price-samples.md`, before 90-day purge):
- TRY `816B7D4A-3914-43A6-8DE9-5AE4FD9E489F` — Arabic `٫`/`٬`, ×100 (all 12 TRY anomalies are this one player)
- SAR `375FD85C-147F-4BA6-9AB2-12E7C7084275`, `E732D34A-E950-4D03-8F16-76DE9E0D5B57`, `9E42DA4A-F988-45C6-81ED-05001E42CD42` — Arabic `٫`, ×100 (incl. discounted rows)
- BRL `659B4C44-96E8-4DB0-BFA4-4A881A2053D9` — dash `-`, ×100 (logs at retention edge, ~03-05)
- KWD `D7926949-4DB7-40DD-9160-34047266A1DF` — ASCII `.` 3-decimal, ×1000 (FP-39539 class)
- Control (correct): BRL `9495F883-A579-4502-91FC-0EA7A0B96DFA` — normal comma

### Affected currencies — full history (ratio detector `EquivalentPrice / BaseUsd`)

Currency-agnostic detector: legit ratio ≈ 0.4–1.0 (even regional-premium ARS ≈ 2.5); ×100 ⇒ ≈ 62; ×1000 ⇒ ≈ 620. Threshold `> 3` cleanly isolates misparses. This supersedes the earlier `$80.6` ceiling, which structurally missed ×100 of cheap items.

| Currency | Bad rows | ×1000 | ×100 | Period       | Parser era / status                                            |
|----------|---------:|------:|-----:|--------------|----------------------------------------------------------------|
| DKK      |       39 |     2 |   37 | 2024-01…05   | old parser; fixed forward by FP-40470, **data still corrupt**  |
| TRY      |       12 |     0 |   12 | 2026-04…05   | **current parser, unfixed** (separator class)                  |
| ZAR      |        4 |     0 |    4 | 2023-11      | old parser; data corrupt                                       |
| SAR      |        3 |     0 |    3 | 2026-04…05   | **current parser, unfixed**                                    |
| KWD      |        2 |     2 |    0 | 2026-05      | current parser; fix written (FP-39539), waiting 2026.4 release |
| BRL      |        2 |     0 |    2 | 2026-02      | **current parser, unfixed**                                    |
| CZK      |        2 |     0 |    2 | 2023-12…2024 | old parser; data corrupt                                       |

**ARS and CHF deliberately excluded** — ratio ≈ 2.5 / 1.3, below threshold. ARS over-ceiling values are regional/inflation distortion (+ separate USD-substitution bug FP-42870 #15), **not** a separator misparse. CHF $81.4 is a legit top-product purchase.

Key conclusions:
- The current parser misparses **TRY/SAR/BRL** (separator class) on top of **KWD** (3-decimal/ASCII, FP-39539). FP-39539 alone does not cover them.
- **EUR (and any currency) can be hit** by an exotic-locale user — confirmed in tradeLog (`2٫99 EUR → 299`). No *completed* EUR purchase happened to be mis-recorded (no EUR rows over ratio>3), but the parser path is the same.
- Volume is tiny (≈64 rows all-time), financial impact negligible — but data correctness is the goal.

### Empirical separator inventory (prod tradeLog export, 2026-06-02)

Exported all distinct price strings for products #2230 ($9.99) and #2190 ($99.99) across all users (708,096 events, 665 distinct formats), distilled to `artifacts/price-format-analysis.md` (raw export not retained). This replaced guesswork with the full format spectrum (prior two fixes were guess-based and incomplete).

Decimal separators seen in prod (rightmost separator):

| Decimal sep                         | Codepoint | Events | Currencies                                                 | Effect       |
|-------------------------------------|-----------|-------:|------------------------------------------------------------|--------------|
| `.`                                 | U+002E    |   359k | USD, AUD, …                                                | OK           |
| `,`                                 | U+002C    |   347k | EUR, PLN, BRL, …                                           | OK           |
| `٫` Arabic decimal                  | U+066B    |   1610 | SAR, TRY, JOD, EGP, ILS, GBP, KWD, EUR, USD, MXN, BHD, OMR | ×100 / ×1000 |
| `$` cifrão (decimal!)               | U+0024    |    152 | USD, BRL                                                   | ×100         |
| `-` hyphen                          | U+002D    |      6 | BRL                                                        | ×100         |
| space/NBSP as decimal (mangled ZAR) | U+00A0    |     ~4 | ZAR                                                        | ×100         |

Thousands separators seen: `.` `,` `٬` (U+066C) NBSP (U+00A0) NNBSP (U+202F) plain space `'` (U+0027, Swiss `1'679,00`). Structures incl. Indian grouping `1,30,000.00` (parses OK), multi-level `1.310.000,00`.

Two more failure modes beyond ×100 inflation:
- **IDR `130.000.00` → 0** (~94 events): dot used for BOTH thousands and decimal → multiple dots → `double.TryParse` fails → null → 0 (under-direction, lost revenue).
- **FP-39539 gap (important):** its `ThreeDecimalCurrencies` exception only triggers on ASCII `.`. Arabic-locale users of the very same currencies break ×1000 anyway: `9٫500 JOD`, `3٫000 KWD`, `38٫000 BHD`, `39٫000 OMR`. **So even after 2026.4 ships FP-39539, Arabic-locale KWD/JOD/BHD/OMR remain broken.** The separator fix is required on top of FP-39539, not instead of it.

### Fix strategy — validated by data

Generalise: treat **any non-digit char** (after `TrimCurrency`) as a separator; **rightmost = decimal, the rest = thousands**; generalise to N grouping separators. This one pass covers every observed breaker (`٫` `$` `-`, the IDR multi-dot → 0, mangled space-decimal). The **only** heuristic that must be kept is the existing "single separator + exactly 3 trailing digits ⇒ thousands, unless currency ∈ ThreeDecimalCurrencies" — needed to disambiguate `67.999 CLP` (=67999) from `9.500 JOD` (=9.5). Net: FP-39539 logic (3-trailing + ThreeDecimalCurrencies) **on top of** broadened separator recognition. Test corpus = the distinct formats in `price-format-analysis.md`.

## Considerations / decisions (2026-06-02)

- **Data accuracy is a goal in itself.** Even for historical rows we will not re-charge, wrong data in the DB is unacceptable. The existing data-fix patch (FP-39539 `R202604-ConvertKwdTransactionPrices-Uwp.sql`) only divides 3-decimal (KWD) rows by 1000. It must be **extended (or a new patch authored)** to also correct the ×100 cases.
- **Data-fix must target by magnitude signature, NOT by currency list.** The bug is locale-driven, so any currency can be affected (EUR included). Select rows by the inflation signature (`EquivalentPrice / Products.Price` ratio buckets: ~×100 vs ~×1000), divide accordingly. Keep idempotent. A pure `Currency IN (...)` filter would miss future/other-currency cases and is fragile.
- **DKK** — parsing regression already resolved by FP-40470 (0 anomalies since Nov 2025), but 2024 data is still ×100-ish wrong and must be corrected. *(To confirm parsing is genuinely correct now with positive recent DKK samples, not just absence of purchases.)*
- **ARS (Argentine peso)** — chronically problematic "junk" currency. Argentina has extreme MS regional discounts (>90%); reflected in `RegionalPriceRates` (e.g. a $100 bundle ~ $7-ish equivalent). The **local** `RegionalPriceRates` copy is more current than prod — that table runs on the DEV server to set Steam microtransaction prices; on prod it appears unused for calculations. Inspect the local copy. The 2023 over-direction anomalies are old-parser misparses; separately there is an under-direction bug (FP-42870 #15: ARS/CLP/COP store USD-scaled amount instead of local, ~1/1000 for ARS). Over-direction is the immediate target; under-direction handled later.
- **Micro-prices (<$0.50)** — almost certainly exist; conversion correctness for them (under-direction distortion) to be checked **later**. Current focus: over-direction (inflation).
- **TRY/SAR/BRL mechanism** — CONFIRMED via tradeLog (see Root cause section): non-ASCII/unexpected decimal separators (`٫` U+066B, `٬` U+066C, `-`) emitted by the device locale, stripped by `CleanupPriceStr`. Fix should generalise separator handling rather than enumerate symbols.
- **Time pressure** — patch the parser before the 2026.4 FTUE rework release cut so the fix ships, then run data-fix scripts cleanly post-release and re-verify historical data.
- **`tradeLog` access gotcha** — `UserId` is stored **lowercase** in `main2.tradeLog`; uppercase exact/regex match returns 0 rows (cost a detour). Fields: `UserId`, `Message`, `Timestamp`, `RequestId`. Retention 90 days (`TradesStoreHorizon`), so pre-~03-2026 price-loads are already purged (BRL Feb rows un-loggable now). Client logs ARE forwarded to prod (`[CLN]:` prefix) — staging-only assumption was wrong.

## Plan

1. **Journal these findings** (this file). ✓
2. **Reformulate the JIRA ticket** from "KWD" to general "[Win10/UWP] incorrect currency price parsing". ✓
3. **Investigate parse-break mechanism** via Mongo `tradeLog`. ✓ — confirmed: non-ASCII/unexpected separators.
4. **Fix the parser** — generalise `NormalizeSeparators` to treat **any non-digit char** (after `TrimCurrency`) as a separator, keeping the "rightmost = decimal, rest = thousands" logic (+ the 3-decimal-currency exception). Handles `209-95`→`209.95`, `1٬900٫00`→`1900.00`, `190٫00`→`190.00`, and legit `1,299.00`/`104.900` CLP in one branch. Add those as test cases in `ParseCurrencyOnClientTest`. Land before the 2026.4 release cut. *(code approach under discussion)*
5. **Author/extend the data-fix SQL** — correct historical inflated rows **by magnitude signature** (ratio buckets ×100 / ×1000), not by currency list. Idempotent.
6. **Post-release**: re-run verification queries on XB PROD, then apply data-fix cleanly.
7. *(Later)* under-direction sweep: micro-prices <$0.50, ARS/CLP/COP USD-substitution bug.

### Reference: data source

- XB PROD MAIN connection (DataGrip): `[F2P] XB PROD MAIN`, DB `Main`, schema `dbo`, table `Transactions` (`Price`, `Currency`, `EquivalentPrice` all `decimal(19,3)`; `PaymentSystemId` 'Win10'/'XBox').
- `RegionalPriceRates` (`Currency`, `Country`, `Rate`, `ExchangeRate`, ...) — inspect **local** copy (DEV), more current than prod.
- Mongo `tradeLog` (XB PROD Mongo, db `main2`, collection `tradeLog`) — client price-load telemetry `[CLN]: CLIENT uwp: Price found ...` carries raw store string + parse result. `UserId` lowercase; 90-day retention.
- No `PatchHistory` table; the data-fix patch writes nothing but the correction itself (cannot check "was it applied" via a log — must infer from data state).

## Milestones

### 2026-06-02 — Investigation + KB journal

Diagnosed root cause (FP-40470 parser rewrite without currency awareness), reconstructed parser timeline across client SVN, proved release-cut vs trunk-merge gap (Leaderboards cut 05-14 < FP-39539 merge 05-18), and mapped affected currencies by parser era. Established that FP-39539 covers only 3-decimal currencies and TRY/SAR/BRL remain broken under the current parser. Task rescoped from KWD to general UWP price parsing. JIRA ticket reformulated.

### 2026-06-02 — Root cause confirmed via tradeLog

Pulled production price-load telemetry from `main2.tradeLog` for the anomalous players. Confirmed the misparse is a **separator class** bug: parser only handles ASCII `,`/`.`; other locale separators (`٫` U+066B, `٬` U+066C, dash `-`) are stripped by `CleanupPriceStr` → ×100/×1000. Proven currency-incidental (same Arabic-locale user mis-parses EUR too). Replaced the `$80.6` ceiling detector with a currency-agnostic ratio detector (`EquivalentPrice/BaseUsd`); full affected set all-time: DKK, TRY, ZAR, SAR, KWD, BRL, CZK (ARS/CHF excluded as non-misparse). Raw case logs saved to `artifacts/tradelog-price-samples.md`.

### 2026-06-04 — /Stats/Money still spiked: Stats DB needed the same fix (recurring gap)

After the Main fix, admin `/Stats/Money` on XB prod still showed the spike. Traced the source: `StatsController.Money` -> `MoneyModel` -> `SqlMonetizationProvider.GetStatsTransactions` reads the **Stats DB** (`SqlAnalyticsConnectionString`), view `VW_TransactionFact_Bundled` over `TransactionFact` + `TransactionFactBundle`, column `EquivalentPrice` — a separate ETL copy, NOT `Main.Transactions`.

Stats was uncorrected: `TransactionFact` 75 ×100 + 3 ×1000 = 78 rows, `TransactionFactBundle` 2 ×100. Reconciled by `TransactionId` (Stats has synonym `MainDbTransactions`): **all 78 had an already-fixed Main twin** (75 "Main fixed /100, Stats lagged" + 3 "/1000, Stats lagged"; 0 "Main not fixed"; 0 "no Main row"). So the 78 = our 64 + ~14 from older Main-only fixes (FP-39539 etc.) — **every historical price data-fix hit Main only and never Stats, and was never verified in Stats.**

Fix: `R202606-ConvertTransactionPrices-UWP-Stats.sql` (signature `EquivalentPrice/ProductPriceUsd`, self-contained — both columns live in the fact row; only `EquivalentPrice` is inflated). Applied to XB PROD STATS in one transaction: 75+3 (TransactionFact) + 2 (TransactionFactBundle) corrected. Post-verify: ratio>10 = 0 in both tables; player `D7926949` Stats EqPrice sum = 39.672 (matches Main). Main script renamed `...-UWP.sql` -> `...-UWP-Main.sql` for symmetry.

**Lesson (recorded):** a transaction-price data-fix MUST cover **both Main and Stats** DBs and be verified in Stats — `/Stats/Money` and producer reports read Stats, not Main. This gap recurred silently across multiple tickets.

### 2026-06-04 — Data-fix applied to XB PROD (Main)

Ran `SQL/Releases/R202606-ConvertTransactionPrices-UWP.sql` (renamed from R202604 since the release slipped to June) on XB PROD MAIN: **62 rows /100 + 2 rows /1000 = 64 corrected**. Post-verify (read-only): 0 remaining inflated rows (`EquivalentPrice/base > 10`) across all currencies; example player `D7926949` KWD now 1.8/3.607 and 18/36.065. MCP prod connection is read-only (good guardrail) — executor ran the UPDATEs on a writable connection. **Must re-run after the 2026.4 UWP client release** to catch rows that accrue from un-updated clients until then (idempotent: a re-run on already-corrected rows is a no-op via the ratio guard). Parser fix + test mirror reviewed (superpowers subagent; Codex blocked by a broken Windows sandbox) — one Important finding (client em-dashes) fixed, SQL semicolons added. **Committed: CLN r55148 (client) + MFT r16148 (server, test mirror + both data-fix scripts + svn rename).** JIRA commit-note on FP-43192 (+@Kyrylo Rovnyi review/merge nudge); rename heads-up on FP-39539. Remaining: re-run both data-fix scripts after the 2026.4 UWP release; deferred KB docs (FP-40470 review, product-local-prices log).

### 2026-06-03 — Device exposure (prod tradeLog, all weird locales)

Exported price-load formats with device samples, distilled to `artifacts/culprit-devices.md` (raw export not retained). **Exposure is far larger than DB money impact:** ~150 distinct devices use a non-ASCII/exotic decimal separator (Arabic `٫` U+066B dominant — SAR 77, USD 26, IQD 12, EGP 11, JOD 6, ILS 5, KWD 4, …; cifrao `$` USD 3 / BRL 1; dash BRL 1; NBSP-decimal ZAR 1). But only **64 became purchases** (the Transactions over-inflation set) — most exotic-locale users browse, don't buy. Implication: current money impact is tiny, but the bug is systemic and would scale with audience/sales; the fix is justified by exposure, not current revenue. USD-with-Arabic-`٫` (26 devices) reconfirms the axis is device locale, not currency. Data-fix scope unchanged (64 rows by signature); the device list is "who muddies", not "what to correct in money".

### 2026-06-03 — Parser fix implemented + tests green

Implemented the agreed design in both copies (client `UwpManager.cs` on CodeBranch + server mirror `ParseCurrencyOnClientTest.cs`):
- New `NormalizeSeparatorChars` pre-map: `char.IsWhiteSpace` ∨ `٬`(U+066C) ∨ `'` → drop (thousands); `٫`(U+066B) ∨ `$` ∨ `-` → `.` (decimal); unknown char → drop + log (the post-release monitoring hook). Non-ASCII expressed as `(char)0x066B`/`(char)0x066C` to keep source ASCII-only.
- Rewritten `NormalizeSeparators`: rightmost `,`/`.` is decimal iff trailing group is `1..maxDecimals` (3 for `ThreeDecimalCurrencies`, else 2); all other separators dropped. Generalised to N occurrences → also fixes IDR `130.000.00 → 0`.
- Tests: `Uwp` (ASCII DataRows) + `UwpLocaleSeparators` (Arabic/NBSP/NNBSP from code points). **37 passed, 0 failed.**

ZAR resolution: `169<NBSP>00`/`1,679<NBSP>00` (NBSP-as-decimal) is a single device `f93e13a5-…` (nUsers=1, 4 events) — like the BRL dash user. Accepted: parser drops whitespace, so that device stays ×100 going forward (silent — NBSP is a recognised whitespace, won't hit the unexpected-separator log). Per user direction, **historical data-fix corrects one-off device rows too** (signature detector catches them); that device's future rows would need the periodic signature sweep, not the parser.

### 2026-06-02 — Full separator inventory (prod export)

Exported all distinct price strings for #2230/#2190 across all users (708k events, 665 formats), parsed to `artifacts/price-format-analysis.md` (raw export not retained). Found additional breakers beyond the initial cases: `$` cifrão decimal (U+0024, 152 ev), and the IDR multi-dot `130.000.00` → 0 (TryParse fail). Critical: FP-39539's `ThreeDecimalCurrencies` exception is ASCII-`.`-only, so Arabic-locale KWD/JOD/BHD/OMR (`9٫500` etc.) still break ×1000 even after 2026.4. Fix strategy validated against the full format spectrum: broaden separator recognition to any non-digit (rightmost=decimal, rest=thousands) + keep the 3-trailing/ThreeDecimalCurrencies disambiguation. Test corpus = the distinct formats in the analysis artifact.
