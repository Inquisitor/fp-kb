---
status: resolved
executor: Yuriy Burda
branch: CLN/CodeBranch @ r53528, LBM @ r16046, MFT @ r16047
jira: https://fishingplanet.atlassian.net/browse/FP-39539
---

# FP-39539: [Stats] Incorrect KWD currency conversion

## Summary

Microsoft Store (UWP / Win10) returns prices only as locale-formatted strings (`FormattedPrice`) with no numeric counterpart, so `UwpManager.GetFloatPrice` parses the string. Its separator heuristic treated "3 trailing digits after a single separator" as a thousands separator. For 3-decimal currencies (KWD/BHD/JOD/OMR/...) the store formats the decimal part with 3 digits, e.g. "9.000 KWD" = 9 dinars. The old heuristic read that as thousands and parsed 9000, storing the price 1000x too large in stats.

This is the second wave on this ticket. The first fix (KNW @ 15053, 2025-09) removed a server-side KWD-specific divider (opposite bug, 10x too small); LGTM'd and merged. The bug resurfaced on Win10 (Mary Key, 2026-03-31: $9 charged, 9000 stored), root cause now identified as the client-side separator heuristic.

## Scope

- **CLN/CodeBranch r53528** — client fix: add `ThreeDecimalCurrencies` set; thread `currencyCode` into `GetFloatPrice` / `NormalizeSeparators`; the 3-trailing-digits-as-thousands heuristic now has a 3-decimal-currency exception. The core fix.
- **LBM r16046** — server mirror: rename `ParseCurrencyOnUwpTest` -> `ParseCurrencyOnClientTest`, sync the copied parser + add 3-decimal cases; add data-correction script `SQL/Releases/R202604-ConvertKwdTransactionPrices-Uwp.sql`.
- **MFT r16047** — merge of r16046 into Code branch.

> Branch-copy inheritance: MFT (Code) created at r15943 from LBM:15942. r16046 > 15942 -> not inherited; explicit merge to MFT was required and done (r16047). Correct.
> No production server code changes: the parser runs only in the Unity client; the server stores the float the client sends. Verified `NormalizeSeparators`/`GetFloatPrice` exist only in the test + SQL comment, nowhere in server production code.

## Verdict

**LGTM.** No blocking issues. The client logic is correct and the SQL data-fix is precise, idempotent, and correctly scoped. F-1 (dropped parser test cases) is test-only and low-probability; acknowledged and accepted as-is — left as a recommendation, not a change request.

## Findings

### F-1: Parser test dropped ~25 real-world locale cases during the refactor [Medium, test-only]

**Description:** The old `ParseCurrencyOnUwpTest` carried ~31 `DataRow`s copy/pasted from the Xbox store across many locales — including documented historical regressions ("103,00 лв." Bulgarian lev "that's when we failed to parse correctly last time", Indian digits "३२,८०", space-thousands "1 285,00 ₴" / "17 300,00 HUF" / "1 429,00 Kč"). The rewritten `ParseCurrencyOnClientTest` keeps only 15 rows (basics + the new 3-decimal cases). The refactor of `NormalizeSeparators` is exactly when those old cases are most valuable — they are the proof the structural rewrite did not break existing locale handling.

**Investigation:** Manually traced several dropped cases through the new logic — they still pass. So this is a loss of *future* regression protection, not a present defect. The signature gained `currencyCode`, so migration requires assigning each old row its real currency code (inferable from the symbol/format).

**Executor response (Yuriy):** those cases were Xbox-era; Xbox moved to a new SDK and no longer uses this string parser, so they are no longer relevant.

**Reviewer note — source vs applicability:** agreed the *source* (Xbox store) is dead (see verified non-issue below — Xbox now uses numeric prices). But the *formats* are not Xbox-specific: `UwpManager.GetFloatPrice` still runs for UWP/Win10, and `Windows.Services.Store` `FormattedPrice` is formatted for the user's locale/market — so a Bulgarian/Ukrainian/Hungarian/Indian Win10 buyer still produces "103,00 лв." / "1 285,00 ₴" / "17 300,00 HUF" / Indian digits. `NormalizeSeparators` branches only on separator pattern + 3-decimal flag, so for non-3-decimal currencies the exact code is irrelevant — the separator/digit *pattern* is what these cases exercise, and those patterns remain reachable on UWP.

**Recommendation:** not all ~25, but keep a representative subset — one row per distinct separator/digit scenario (space-thousands, comma-decimal, dot-thousands, non-Latin digits) — with any non-3-decimal currency code. Low effort; preserves the UWP regression net. Team's call.

### F-2: Test is a hand-copied mirror of client logic [Low, pre-existing]

**Description:** `ParseCurrencyOnClientTest` duplicates `UwpManager.GetFloatPrice` and helpers verbatim, guarded only by a "keep in sync" comment. A future edit to `UwpManager.cs` that is not mirrored will leave a green test that no longer reflects shipped code. Inherent: the parser lives in the Unity client, which the server test solution cannot reference. Pre-existing pattern, not introduced here. No action required; if ever revisited, the natural home is the client test suite.

## Verified non-issues

- **Win10-only SQL scope is correct.** Initially suspected the script under-corrects by omitting Xbox (the old test cases came from the Xbox store, and platforms pair "XBox + Win10"). Verified `XBoxGamecoreManager` uses the numeric `XStorePrice.Price`/`.BasePrice` from XGamingRuntime directly — it does not string-parse for the numeric price (only for the display string). Xbox is immune to the separator bug; only `UwpManager` (Windows.Services.Store, stored as `Win10`) parses strings. Scope is complete. Confirmed by executor: Xbox moved to a new SDK (GameCore / XGamingRuntime) returning numeric prices, so the string-parse path is no longer used for Xbox at all.
- **Build not broken by the rename.** `LoadBalancing.Tests.csproj` is SDK-style (`Microsoft.NET.Sdk`), auto-globs in-directory `.cs`; the renamed test is picked up with no csproj edit.
- **3-decimal currency list is the complete ISO 4217 set** (BHD, IQD, JOD, KWD, LYD, OMR, TND); code and SQL filter agree.
- **Data-fix is exact and idempotent.** Affected rows are always exactly 1000x (a 3-digit decimal mark stripped as thousands). Guard `EquivalentPrice / NULLIF(p.Price,0) > 100` selects only the ~1000x-inflated rows; after `/1000` the ratio drops to ~1 and a re-run is a no-op. `NULLIF` adds div-by-zero safety the prior R202510 script lacked. Correctly-parsed both-separator rows (ratio ~1) are left untouched.

## Minor edges (Low, negligible)

- A bugged row with an extreme discount (~90%+) could push the inflated ratio near the 100 threshold and be missed; rare on Win10 in the affected window.
- Multi-dot inputs like "1.500.000" parse to null (`double.TryParse` fails); not a realistic store format for these prices.
