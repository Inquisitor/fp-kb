---
status: in-progress
executor: Yuriy Burda
branch: KNW20250723 @ r15367, LBM20251201 @ r15624
jira: https://fishingplanet.atlassian.net/browse/FP-40921
---

# Review: FP-40921 — [Chums] [BiteSystem] Missing detraction for fish with changed form due to weight increase with chums

## Summary

Bug: when chums boost fish weight enough to change form (e.g. trophy → unique), detraction logic was incomplete — uniques kept generating without limit. Original fix (KNW r15367) added detraction for the changed form. Reopen fix (LBM r15624) corrects fetching of temporary detractors to use the generated form (pre-form-change), plus a sign-handling fix in detractor logging.

## Scope

### KNW20250723
- **r15367** — Add detraction for fish with changed form due to weight increase with chums

### LBM20251201
- **r15624** — Get temporary detractors for correct fish form when calculating bite rate. Fix sign for detractors logging (* 0.000 => - 0.000) when no active detractors

## Investigation Journal

- Phase 1 intake: 2 commits across 2 branches. KNW was Code at time of original fix (2025-11-26); LBM was Code at time of reopen fix (2025-12-29). Branch ancestry suggests both should be inherited in current Code (MFT) via branch copy — verification deferred to Phase 2.
- Executor field empty in JIRA; commit author (Yuriy Burda, per JIRA comments id:95876 and id:98903) recorded as executor.
- VCS audit: r15367 present on KNW + LBM + MFT (last two via branch copy). r15624 present on LBM + MFT (MFT via branch copy). Neither commit reaches IMV (OldStable). r15624 not merged to KNW (Stable) — expected for a forward-fix on Code; reaches Stable naturally via the LBM release flow.
- Coverage scan via grep: no remaining `data.Fish.Form == ...` filters; `GeneratedFish` and `RandomWeight` constructions all populate `OriginalForm`; `Settings.GetFishId(name, OriginalForm)` keying is consistent across all sites. Fix is exhaustive.
- Independent code-reviewer agent: confirmed factory correctness, call-site coverage, edge-case `OriginalForm == Form` falls back to pre-fix behavior. Surfaced a divergence between two log surfaces (`DetractionStr` vs `ToStrings`) for `DetractionType.None`. Verified manually — divergence is intentional (tabular alignment vs prose suppression).

## Findings

### F-1: Log-surface divergence on `DetractionType.None` between `DetractionStr` and `ToStrings()` [Low]

**Description:** In `FishSelector.cs::ProbabilityDetails`, prose log `DetractionStr` returns `""` for `None`, while tabular log `ToStrings()` (after r15624) outputs `"- 0.000"`. Two log views show different shapes for the same "no detraction" state.

**Investigation:** Read `FishSelector.cs` lines 104-147. Confirmed `DetractionStr` has explicit `None` early-return for prose suppression; `ToStrings()` has no `None`-guard because tabular format requires fixed columns. Pre-r15624 the divergence already existed (`""` vs `"* 0.000"`); r15624 swapped the tabular default to `'-'` to read more naturally for the None case, which is the stated intent in the commit message.

**Resolution:** Accepted. Divergence is intentional: tabular log cannot suppress the column without misaligning, prose log can. The change makes the tabular display cleaner. No action required.

**Discovered by:** code-reviewer agent (verified manually).

## Verdict

LGTM — approve.

- r15367 design matches the JIRA spec exactly: detraction strength from changed-to form; duration / type / radius from original bait-map form. New `OriginalForm` field plus dictionary re-keying covers the form-change case end-to-end.
- r15624 closes a missed call site (`AllGeneratedFish` filter on `Fish.Form`) that left temporary detractors invisible for form-changed fish — directly explains the QA reopen ("uniques sypaľ on stand"). Logging fix is a small readability improvement.
- No call-site gaps, no unsafe edge cases, no merge-discipline issues.
