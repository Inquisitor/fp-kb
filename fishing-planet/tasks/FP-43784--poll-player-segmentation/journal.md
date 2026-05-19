---
status: completed
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-43784
---

# FP-43784: Distinguish poll respondents by country, level and payer/non-payer

## Status

Delivered. Sheet filled by executor across 2749 responses with 5 columns (Matched nick / Level /
Country / Is Payer / Duplicate?). Match coverage 86% (2373 / 2749 rows). JIRA comment posted
([id `120470`](https://fishingplanet.atlassian.net/browse/FP-43784?focusedCommentId=120470)) with
methodology, per-platform coverage table, audience profile and unmatched-category breakdown.

## Summary

### Goal

Enrich the responses of the "Next Fishing Planet Map" form (2749 rows) with three player attributes from
Prod — `Level`, `Country`, `IsPayer` — so the marketing/design team can segment poll answers by audience.
The three columns already exist in the working Google Sheet but are empty.

### Source

- Survey CSV (snapshot): `2026-05-19 - Next Fishing Planet Map (Responses) - Form Responses 1.csv`
  - 2749 records, columns: `Timestamp, Enter your nickname, Level, Country, Is Payer?, Platform, ...`
  - 2699 unique nicknames after case-insensitive collapse (`Users.Username` collation is `_CI_AS`).
  - No empty nicks.
  - Platform distribution: Steam 1840, PlayStation 496, Xbox 234, Mobile (Android) 91, Epic Games 44,
    Mobile (iOS) 23, Nintendo Switch 15, UWP 5, "PS" 1 (typo for PlayStation).
- Working Sheet (executor's personal copy):
  `https://docs.google.com/spreadsheets/d/1PPJtlH3iqYYpVkc1oUNtBBR8bXPaCAsH22dcU5gXtmI/edit`
- Original Sheet (out of agent's Drive access):
  `https://docs.google.com/spreadsheets/d/1kHE0vi5v_3T2nfvA6HjVoUaT4e4O34Bn8C9TRJ_vF2I/edit`

### Schema mapping

| Output column | Prod table.column | Notes |
|---------------|-------------------|-------|
| Level         | `Profiles.Level`               | 1:1 with `Users.UserId` |
| Country       | `UserCountries.Country`        | 1:1 with `Users.UserId` (verified on local) |
| IsPayer       | derived from `Transactions`    | rule below |

Match key: `Users.Username` (unique, `_CI_AS` — case-insensitive auto-match).

### Payer rule

Mirrors `SqlMonetizationProvider.GetHasPaidTransactions()`
(`Dal\Sql.MsSql\Monetization\SqlMonetizationProvider.cs`):

```sql
EXISTS (
    SELECT 1 FROM Transactions WITH (NOLOCK)
    WHERE UserId = @uid
      AND Status = 'Complete'
      AND PaymentSystemId <> 'WebAdmin'
      AND Price <> 0
)
```

`PaymentSystemId <> 'WebAdmin'` filters out admin-granted compensations and test purchases issued via
WebAdmin tools — those are not real money. `Price <> 0` is an additional guard against zero-priced
service rows.

### Decisions (poll-source choices)

- **Duplicates**: case-insensitive (matches DB collation). List of duplicate-row positions in the source
  CSV will be produced as a side artifact for executor's review (handling decided separately).
- **Invalid / unmatched nicknames**: leave the three columns blank rather than delete the row. Handling
  of unmatched / fuzzy-matchable nicknames deferred to a separate discussion.

## Plan

1. **[done]** Read JIRA, identify source Sheet, locate replacement CSV via executor.
2. **[done]** Map schema on Local DB (`Main`):
   - Confirmed `Users.Username` unique + CI collation.
   - Confirmed `UserCountries` 1:1 with users.
   - Located `Profiles.Level`.
   - Selected `Transactions`-based payer rule.
3. **[done]** Generate `artifacts/01_lookup_on_prod.sql`: stage 2699 unique nicks (3 batches of
   1000 + 699), then single LEFT-JOIN query.
4. **[blocked]** Executor runs the script on Prod (DataGrip / SSMS), exports result as CSV
   to `artifacts/02_prod_result.csv`.
5. **[pending]** Agent joins result back to source CSV (key: lowered nickname); produces:
   - `artifacts/03_filled_columns.tsv` — three columns aligned with source row order, ready to paste
     into the Sheet's `Level / Country / Is Payer?` columns.
   - `artifacts/04_duplicates.csv` — case-insensitive duplicate-nickname row positions.
   - `artifacts/05_unmatched.csv` — nicknames not found in `Users.Username`.
6. **[pending]** Post results to JIRA, await marketing-side confirmation, then close.

## Milestones

- 2026-05-19: Task opened. Schema mapped on local. Prod lookup SQL generated at
  `artifacts/01_lookup_on_prod.sql` (48.8 KB, 2699 staged nicks). Validated JOIN structure on local
  with a 3-nick probe (1 fake + 2 real lowered) — matched rows fill correctly, unmatched return NULLs,
  no collation conflict.
- 2026-05-19: Architecture reworked into per-platform CTE queries (no temp tables) against the
  per-stack F2P Prod MAIN DBs via DataGrip MCP. Platform → DB mapping: Steam+Epic →
  `[F2P] STEAM PROD MAIN`, PS+PS-typo → `[F2P] PS PROD MAIN`, Xbox+UWP → `[F2P] XB PROD MAIN`,
  Mobile (Android+iOS) → `[F2P] MOB PROD MAIN`, Switch → `[F2P] NX PROD MAIN+STATS`. Generated 5
  per-bucket queries at `artifacts/01_query_<bucket>.sql`. Ran on Prod, saved results at
  `artifacts/02_prod_result_<bucket>.csv`. Pass-1 match rates: steam 85.7%, ps 81.6%, xb 80.2%,
  mob 82.6%, nx 60.0%. Total 2275 / 2701 unique nicks matched directly.
- 2026-05-19: Pass-2 fuzz variant discovery. 5 parallel general-purpose agents read the 420 unmatched
  nicks per bucket (`artifacts/05_unmatched.txt`) and proposed variant strings + email lookups,
  classifying each by transformation type (taxonomy: trimmed_suffix, parens_extracted,
  brackets_removed, unicode_normalized, multi_word_compacted, email_extracted, free_form_extracted,
  free_form_no_nick, location_only, possible_real_name, alt_id_only, special_chars_normalized,
  cjk_or_cyrillic, discriminator_stripped, other). Agent outputs at `artifacts/04_variants_<bucket>.tsv`.
  TSV column-shift bug in agent output for Steam + XB (missing tab for empty `email`) auto-repaired
  into `*_fixed.tsv`. Generated CTE queries with `PollPairs(OriginalNick, Variant, Source)`
  supporting both `Users.Username` and `Users.Email` joins. Ran on Prod per bucket; results at
  `artifacts/02b_prod_result_<bucket>_pass2.csv`. 75 originals matched via variant.
- 2026-05-19: Ambiguous + low-level matches resolved via `LastActivityDate` freshness signal.
  Fetched `LastActivityDate` for all 88 pass-2 matched users (`02c_lastactivity_<bucket>.csv`).
  Re-classified with freshness rule (>365 days = drop as false-positive, ≤30 days = keep): 53 confident
  auto-keeps, 18 dropped as stale false-matches (e.g. `Tom` / `water` last seen 2015), 4 in the
  30-365 day gray zone. Executor verdict on the 4 gray cases: KEEP Ivakis_Solo / Jekyll_Hyde /
  Br00ther7 (high-level payers with explicit name evidence), DROP FurryNetThief. Net: 56 rescued.
- 2026-05-19: Final TSV assembled at `artifacts/07_final_tsv.tsv` — 2749 rows in source CSV order,
  4 columns (Matched nick / Level / Country / Is Payer). Country normalized to ISO-2 UPPERCASE
  (`pycountry` for full-name → code; the only unresolved values are 3 rows where Prod stored
  `'eN'` — left blank). Fill rate 86.3% (2373 filled, 376 blank).
- 2026-05-19: Added 5th column `Duplicate?` (per executor instruction — flag instead of remove, marketing
  decides). 50 rows marked DUPLICATE (case-insensitive nickname dedup; first occurrence wins by file
  order = timestamp ascending). Source CSV is form-export-ordered: 12 string-compare "out-of-order"
  timestamps are only string artifacts (e.g. "5/10" < "5/9" lexically), chronologically monotonic.
- 2026-05-19: Sheet pasted by executor. JIRA comment posted (id `120470`,
  [permalink](https://fishingplanet.atlassian.net/browse/FP-43784?focusedCommentId=120470)) — methodology
  (3-pass match), coverage table per platform, audience profile (66% Lvl 61+, 83% payer share),
  top-15 countries, unmatched-category breakdown. Executor instruction on 370 still-unmatched: leave
  as-is (no further fuzz pass).
