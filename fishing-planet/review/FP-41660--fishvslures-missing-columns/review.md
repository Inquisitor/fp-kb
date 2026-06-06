---
status: resolved
executor: Dmytro Kurylovych (r15667), Yuriy Burda (r15743, r15744)
branch: LBM @ r15667, r15743, r15744
jira: https://fishingplanet.atlassian.net/browse/FP-41660
---

# Review: FP-41660 — [WebAdmin] [GdTools] missed columns in PondFish VS TackleLures report

## Summary

Bug fix: the WebAdmin GdTools "PondFish vs TackleLures" (Fish vs Lures) report was missing lure-category columns. Reported missing: SpinnerTail and Boil Bait. After reopen, also flagged: TrollingSkirt column not populated, and BarblessSpoons / BarblessSpinner categories missing.

## Scope

All three commits touch a single file: `WebAdmin/WebAdmin/Models/Stats/PondFishTackleLuresModel.cs`. Verified against `svn log | grep` on LBM — matches intake exactly.

- **LBM r15667** (Dmytro Kurylovych) — add Tail/BoilBait columns
  - `ItemSubTypes.Tail` (146) + `ItemSubTypes.BoilBait` (43) appended to `FreshwaterColumns`
- **LBM r15743** (Yuriy Burda) — Add BarblessSpoons and BarblessSpinners
  - `ItemSubTypes.BarblessSpoons` (94) + `ItemSubTypes.BarblessSpinners` (95) inserted into `FreshwaterColumns`
- **LBM r15744** (Yuriy Burda) — Add trolling skirts
  - SQL `ParentCategoryId IN (10, 12, 155)` -> `(10, 12, 14, 155)` (added 14 = Saltwater Skirts) in `LoadItemCategoryAttractionStats`

Inherited into Content (MFT) and Code (NPN) via branch copy — no merge needed (see Journal).

## Findings

No blocking or non-trivial findings. The fix is correct, complete, and well-targeted. Verification below.

### How the report populates a column (mechanism)

A column appears only if its `ItemSubTypes` is in `FreshwaterColumns`/`SaltwaterColumns` AND the SQL's `LoadItemCategoryAttractionStats` returns rows for it. The SQL has two UNION branches keyed on the item's `ParentCategoryId`:
- Branch 1 — `ParentCategoryId = 11` (Lure), reads attraction from `$.Bait.Attraction`
- Branch 2 — `ParentCategoryId IN (10, 12, 14, 155)` (Bait/JigBait/Saltwater Skirts/SaltwaterTeaser), reads `$.Attraction`

The original bug was a broken link in this chain (column present but parent category absent from the SQL filter -> empty column).

### Verification (MainLBM, local copy of LBM dev data)

| Subtype | CatId | ParentCatId | SQL branch | Active items / with attraction | JSON path matches branch |
|---------|-------|-------------|-----------|-------------------------------|--------------------------|
| BoilBait        | 43  | 10 (Bait)            | 2 (always covered) | 152 / 152 | `$.Attraction` ✓ |
| Tail            | 146 | 12 (JigBait)         | 2 (always covered) | 15 / 15   | `$.Attraction` ✓ |
| BarblessSpoons  | 94  | 11 (Lure)            | 1 (always covered) | 20 / 20   | `$.Bait.Attraction` ✓ |
| BarblessSpinners| 95  | 11 (Lure)            | 1 (always covered) | 15 / 15   | `$.Bait.Attraction` ✓ |
| TrollingSkirt   | 162 | 14 (Saltwater Skirts)| 2 (added by r15744)| 28 / 28   | `$.Attraction` ✓ |

Every added column maps to a parent category covered by the SQL filter, and every column's items store attraction under exactly the JSON path its branch reads. All five columns will populate with real data.

Key confirmation of the reopen diagnosis: TrollingSkirt (parent 14) was the only one needing the SQL change — parent 14 was not in the filter, so the column existed but stayed empty. Parent 14 contains exactly one active subtype (162, TrollingSkirt, 28 items, all with attraction), so adding 14 is precise: no orphan columns, no other missed subtypes.

### Exhaustive coverage check (is anything still missing?)

Queried every subtype under the covered parents (10, 11, 12, 14, 155) that has active items with attraction (41 categories), and diffed against the union of `FreshwaterColumns` + `SaltwaterColumns`. **Every active-with-attraction subtype has a corresponding column** — no remaining "missed column with real data". After this fix the report is exhaustive for categories that actually carry attraction data.

The code-reviewer agent flagged `SaltwaterSiliconeOctopus` (196, parent 12) and `SpreaderBar` (164, parent 155) as absent from `SaltwaterColumns`. Verified and dismissed: both have **zero** active items with attraction in MainLBM, so they carry no data — adding columns would render permanently empty cells. Not a real gap, no follow-up ticket warranted. (`SquidChain` 163 and `Torch` 190 — the other parent-155 subtypes — are already present in `SaltwaterColumns` and do have data.)

### Independent code-reviewer agent

Spawned (`feature-dev:code-reviewer`). Confirmed all conclusions across 8 angles: correct enum IDs, no dictionary-key collision, no UNION double-counting (parents are mutually exclusive: branch 1 is `=11`, branch 2 excludes 11), correct fresh/salt array placement, GROUP-BY redundancy is pre-existing/harmless. Only net-new observation was the 196/164 omission, dismissed above with data.

## Verdict

**Approve (LGTM).** All three commits are correct, minimal, and well-targeted. Every added/fixed column is confirmed (via MainLBM) to populate with real data; JSON paths match their SQL branch; parent-14 addition is precise. Fix already present in Stable/Content/Code via branch copy — no merge step needed. No blocking or non-trivial findings.

Closed with handoff: posted LGTM + reassigned to analyst Mary Key, asking her to confirm the added columns are the expected set and to decide whether the two column-less-but-covered categories warrant columns. These two were routed to the analyst (a content/product call), NOT filed as our backlog item: `SaltwaterSiliconeOctopus` (196) is the only `SaltwaterJigBaits` member without a column while its 4 siblings have one (covered by SQL parent 12, code-referenced in tournaments/jigbait-groups/daily-missions, but no items with attraction in DB yet); `SpreaderBar` (164) is a teaser subtype (`class SpreaderBar : SquidChain`) with no attraction items. Both are latent (would silently drop data once content adds items), not active bugs.

## Investigation Journal

- Phase 1 intake: JIRA read; `customfield_11224` (Executor) empty — nudge surfaced. Commit authors are two: Dmytro Kurylovych (r15667), Yuriy Burda (r15743/r15744).
- Branch-copy inheritance VERIFIED: all three revs (15667/15743/15744) ≤ 15942 (MFT base = LBM@15942). MFT working-copy file already contains every change; `svn log` on the file in the NPN (Code) branch URL shows all three FP-41660 revisions in history (NPN <- MFT <- LBM copy chain). Fix present in Stable/Content/Code automatically — close phase skips merge.
- Reopen history: Mary Key reopened 2026-01-15 (TrollingSkirt not populated + BarblessSpoons/Spinner missing); Yuriy Burda's r15743/r15744 addressed those; Yuriy struck through the "trolling skirt has no attractions" concern on 2026-02-02 before moving back to In Review.
- Correctness verified against MainLBM (local copy of LBM dev data): category->parent mapping + per-column active-item/attraction counts + JSON-path-vs-SQL-branch match. All five added/fixed columns confirmed to populate. See Findings table.
