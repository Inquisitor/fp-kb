# FP-43192 — Backlog

## Immediate (before 2026.4 FTUE rework release cut)
- [x] Reformulate JIRA ticket: KWD -> general "[Win10/UWP] incorrect currency price parsing"
- [x] Pull `tradeLog` original store price strings (root cause confirmed: non-ASCII/unexpected separators)
- [x] Generalize the parser: new `NormalizeSeparatorChars` (role pre-map, `IsWhiteSpace`+`٬`/`'`→drop, `٫`/`$`/`-`→`.`) + rewritten `NormalizeSeparators` (rightmost=decimal if trailing<=maxDecimals, N-occurrence) in both client `UwpManager.cs` and server mirror `ParseCurrencyOnClientTest.cs`. Non-ASCII via `(char)0x066B/0x066C` for ASCII-only source.
- [x] Tests: `Uwp` (ASCII DataRows) + `UwpLocaleSeparators` (Arabic/NBSP/NNBSP built from code points). 37 passed, 0 failed.
- [x] Land parser fix + test mirror + data-fix scripts: committed CLN r55148 (client) + MFT r16148 (server). JIRA commit-note posted to FP-43192 (with @Kyrylo Rovnyi review/merge nudge); rename heads-up posted to FP-39539.

## Data correction
- [x] Author data-fix SQL by magnitude signature (ratio buckets ×100/×1000), idempotent. **Main**: `R202606-ConvertTransactionPrices-UWP-Main.sql` (svn-renamed+broadened from FP-39539's KWD-only R202604). **Stats**: `R202606-ConvertTransactionPrices-UWP-Stats.sql` (TransactionFact + TransactionFactBundle; needs `svn add`).
- [x] Apply to XB PROD MAIN (2026-06-04): 62+2 = 64 rows; post-verify 0 remaining.
- [x] Apply to XB PROD STATS (2026-06-04): 75+3 (TransactionFact) + 2 (TransactionFactBundle); post-verify 0 remaining; `/Stats/Money` spike resolved.
- [ ] **Re-run BOTH scripts (Main + Stats) after the 2026.4 UWP release** — old clients keep producing ×100 until the fixed build ships; idempotent re-run mops them up, then confirm 0 remaining in both DBs.

> **Lesson:** transaction-price data-fixes must cover BOTH Main and Stats DBs and be verified in Stats — `/Stats/Money` + producer reports read Stats (`VW_TransactionFact_Bundled`), not `Main.Transactions`. This gap recurred silently (FP-39539 and earlier fixes were Main-only).

## Deferred / later
- [ ] Under-direction sweep: micro-prices < $0.50 — verify conversion correctness
- [ ] ARS/CLP/COP USD-substitution bug (FP-42870 #15) — separate under-direction issue
- [ ] Inspect LOCAL `RegionalPriceRates` for ARS (>90% MS discounts; $100 bundle ~ $7) to validate expected local prices
- [ ] Confirm DKK parsing genuinely correct now (positive recent samples, not just absence of purchases)

## KB documentation
- [x] Create `review/FP-40470--win10-currency-parser/review.md` (Resolved; r50247 introduced the separator-misparse regression class; closed incrementally by FP-39539 + FP-43192).
- [x] Add `modules/product-local-prices/log.md` Finding (2026-06-06): UWP parser saga, release-cut gotcha, and the Main+Stats data-fix lesson.
