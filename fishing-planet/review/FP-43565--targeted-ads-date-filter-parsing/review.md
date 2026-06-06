---
status: resolved
executor: Yevhenii Shust
branch: MFT20260325 @ r16098
jira: https://fishingplanet.atlassian.net/browse/FP-43565
---

# Review: FP-43565 — WebAdmin: Settings not working in new Targeted Ads: Summary by Design table

## Summary

Bug (High): changing any setting (Type, Auditory, Platform, etc.) of the new
**Targeted Ads: Summary by Design** stats table threw an error. Root cause per
executor comment: empty date filter values were passed to `DateTime.ParseExact`,
which throws on an empty string. Fix parses empty/whitespace dates as `null` and
centralizes the nullable-date filter parsing in `DateTimeHelper`.

Test views named by executor: `/Stats/TargetedAdsByCampaign`,
`/Stats/TargetedAdsByDesign`, `/Player/DenuvoBans`.

## Scope

> Intake-level, from JIRA comment. To be confirmed by `svn log | grep` in Phase 2.

- **MFT20260325 r16098** — FP-43565: [WebAdmin] Fix nullable date filter parsing
  - Empty date values handled as `null` instead of being passed to `DateTime.ParseExact`
  - Shared nullable-date parsing moved to `DateTimeHelper` to dedupe the `AllowedDateFormats` array across filter binders

## Findings

### F-1: Malformed (non-empty) date still throws `FormatException` [Low]

**Description:** `DateTimeHelper.ParseNullableDateTimeFilter` returns `null` for
empty/whitespace but still calls `DateTime.ParseExact` for any non-empty value,
which throws on a malformed string (e.g. a hand-crafted query string). The
reported crash (empty value) is fixed, but the malformed-input crash path
remains. Low real-world impact: internal admin tool, dates normally supplied by
pickers in a known format.

**Investigation:** Read diff of r16098 + HEAD of `DateTimeHelper.cs`; confirmed
`ParseExact` (not `TryParseExact`) is still used. Executor explicitly scoped this
out in the JIRA comment ("handle incorrect formats correctly for all field types
... that's a separate task").

**Resolution:** Pre-existing — not filed. Out of scope for this fix; a broader
date-handling task likely already exists. Reprioritize if it resurfaces elsewhere
(user decision, 2026-06-04).

**Discovered by:** executor's comment + manual scan.

### F-2: Date parsing not unified across WebAdmin [Info]

**Description:** Other date parsing sites (`PlayerController`, `PlayerLicensesModel`,
`ChatModel`, `LogsModel`, `Stats/ModelBase`, `DenuvoBansModel`) use their own
single-format `ParseExact`/`TryParseExact` and were intentionally left untouched.
Not a defect of this fix — the binder paths in scope are now consistent.

**Investigation:** Grep of `ParseExact`/`AllowedDateFormats` across `WebAdmin/WebAdmin`.
Other sites use single formats (mostly guarded by `IsNullOrEmpty`/`TryParseExact`),
none carried the empty-string `(null == x) ? null : ParseExact` pattern that caused
this bug. That pattern existed only in `TargetedAdsStatsFilter`, now fixed.

**Resolution:** Pre-existing — not filed. Same rationale as F-1.

**Discovered by:** skill recon + executor's comment.

### F-3: Cosmetic — trailing whitespace + redundant guard [Low]

**Description:** r16098 introduced trailing whitespace after opening braces
(`DateTimeHelper.cs` in `ParseNullableDateTimeFilter`; both branches of
`DenuvoBansFilter`; `TargetedAdsStatsFilter.cs:78`). Also in `DenuvoBansFilter`
the outer `if (!string.IsNullOrEmpty(...))` is now redundant — `ParseNullableDateTimeFilter`
re-checks `IsNullOrWhiteSpace` internally. Both harmless.

**Investigation:** File inspection of the diff.

**Resolution:** Skipped — too minor to block; can be swept in a later touch.

**Discovered by:** manual scan.

## Verdict

**Approve.** Root cause (empty date string → `DateTime.ParseExact("")` → `FormatException`)
is correctly fixed via `IsNullOrWhiteSpace` guard, and the shared parsing is
sensibly centralized in `DateTimeHelper`. Fix covers all three reported views:
`/Stats/TargetedAdsByCampaign` and `/Stats/TargetedAdsByDesign` share
`TargetedAdsStatsFilter`; `/Player/DenuvoBans` via `DenuvoBansFilter`. No blocking
findings. F-1/F-2 are author-acknowledged out-of-scope follow-ups → not filed
(deferred per user, likely covered by an existing date-handling task).

## Investigation Journal

- Executor field (`customfield_11224`) = Yevhenii Shust — populated; matches commit author per JIRA comment. No hygiene nudge.
- Branch-copy inheritance confirmed (Step 5): NPN20260602 (Code) copied from MFT20260325:16130; r16098 ≤ 16130, and `svn log` on NPN shows r16098 in inherited history → fix already present on Code, no explicit merge needed.
- Root cause verified at `TargetedAdsStatsFilter.cs:90` — `startDate` sourced from `Form ?? QueryString`; empty form field yields `""`, which the old `null == startDate` guard missed.
- Coverage verified: all `StatsController.TargetedAds.cs` actions (incl. ByCampaign and ByDesign) bind a single `TargetedAdsStatsFilter` → one binder fix covers both views.
- Completeness check: grep of `ParseExact` across WebAdmin — the unsafe empty-string pattern existed only in `TargetedAdsStatsFilter`; other sites use single formats and are guarded. No missed binder.
- Findings routing: F-1/F-2 → not filed, deferred per user (2026-06-04) — too out of scope, likely an existing date-handling task covers it; F-3 → skipped (cosmetic).
- Code-reviewer agent delegation declined by user — recon deemed sufficient for a single-commit, 3-file fix with verified root cause.
