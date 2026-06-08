---
status: resolved
executor: Yuriy Burda
branch: CLN/CodeBranch @ r50247 (+ KNW @ r15239 server parser tests)
jira: https://fishingplanet.atlassian.net/browse/FP-40470
related:
  - FP-39539
  - FP-43192
---

# FP-40470: [Win10] Update currency parser

> Retrospective, written under FP-43192. FP-40470 rewrote the UWP price parser — a real improvement over the old brittle heuristic, but it introduced the separator-misparse regression class later completed by FP-39539 and FP-43192.

## Summary

Driver: a BGN (Bulgarian lev) mis-parse — stotinki (1/100 lev) not handled — plus the question of whether the numeric price/currency could be obtained directly like on Xbox. Outcome: for UWP the answer was no (string parsing stayed; numeric prices arrived only later for Xbox via GDK), so the parser was rewritten instead. Shipped in 2026.2 Norway Consoles Release (released 2026-02-26).

UWP/Win10 gets no numeric store price; `UwpManager.GetFloatPrice` parses the locale-formatted `FormattedPrice` string. r50247 replaced the old `decimalChar` heuristic (with an explicit "kr." Danish special case) with a cleaner pipeline: `NormalizeDigits` (Arabic-Indic etc. digits → ASCII), `TrimCurrency` (strip leading/trailing non-digits), `NormalizeSeparators`, `CleanupPriceStr`.

## Scope

- **CLN/CodeBranch r50247** — parser rewrite. Auto-merged to MainClient r50354 (2025-11-04) → on UWP prod since Nov 2025.
- **KNW @ r15239** — server-side parser test mirror (`ParseCurrencyOnUwpTest`, later renamed `ParseCurrencyOnClientTest`).
- Reviewer trail: Yuriy posted the commits; Stanislav LGTM'd 2025-12-17 with "to be checked on Prod after the Norway release on UWP" — a **deferred prod verification**.

## What it improved

Removed the fragile per-symbol `decimalChar` logic; added digit normalization and clean currency trimming; covered more locale formats than before.

## Finding: introduced the separator-misparse regression class [High, historical]

`NormalizeSeparators` recognised only ASCII `,`/`.` and applied "single separator + exactly 3 trailing digits ⇒ thousands" with **no currency / locale-separator awareness**:

- 3-decimal currencies ("9.000 KWD" → 9000) — ×1000. → fixed by **FP-39539** (`ThreeDecimalCurrencies` exception, r53528).
- Non-ASCII / locale separators (Arabic `٫` U+066B / `٬` U+066C, cifrão `$`, dash, NBSP) survived `NormalizeSeparators` and were stripped by `CleanupPriceStr` → ×100/×1000. → fixed by **FP-43192** (role-based `NormalizeSeparatorChars` + N-occurrence rewrite).
- Multiple same-char separators ("130.000.00" IDR) → multiple dots → `double.TryParse` fails → 0. → fixed by **FP-43192**.

Not caught at the time because UWP volume is low and exotic-locale buyers rarely complete purchases (mostly browse) — surfaced only via FP-43192's `tradeLog` analysis (~150 exposed devices, 64 inflated purchases in Main).

## Verdict

**LGTM-in-context.** A net improvement that didn't fully account for locale-driven separators; the gap is inherent to string-parsing a locale-formatted price without locale data, and was closed incrementally (FP-39539 → FP-43192). No action on FP-40470 itself.

The deferred "verify on Prod after the Norway release" check (LGTM comment) was effectively carried out under **FP-43192** — prod `tradeLog`/`Transactions` analysis (Feb–May 2026, post-Norway-release): the parser runs as intended, but the analysis surfaced the broader separator-regression class this card describes. BGN confirmed correct on prod (stotinki preserved, ratios ~0.70, no inflation/zeroing); **FP-40470 transitioned Resolved → Closed 2026-06-08** with a verification comment.
