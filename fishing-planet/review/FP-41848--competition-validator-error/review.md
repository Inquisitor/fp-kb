---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15709
jira: https://fishingplanet.atlassian.net/browse/FP-41848
---

# Review: FP-41848 — Competition validator having an error

## Summary

WebAdmin competition validator threw a NullReferenceException for tournaments whose `Places` list contained a null entry (likely a double-comma artifact in the source JSON). The commit also fixes an unrelated `InitializeGrouping` bug where the bracket-MaxRating auto-population produced inverted intervals, and adds a unit test for the latter. Feature is on Test environment, not yet released — no production impact.

## Scope

- **LBM r15709** — Fix matchmaking places Max rating auto-population logic. Fix/improve competitions validation
  - `MatchmakingLogic.InitializeGrouping`: sort brackets `OrderByDescending(MinRating)` instead of ascending — top bracket now receives `MaxRating = int.MaxValue`, lower brackets get `MaxRating = nextHigher.MinRating - 1`
  - `MatchmakingLogicTests`: new test `InitializeGrouping_sets_max_rating_properly` (3 brackets with MinRating 0/100/50 → asserts MaxRating 49/MaxValue/99)
  - `CompetetiveActivityBreaksModel.CheckPlaces`: added empty-element guard with informative error ("check for double commas in places list"); converted to `out string placesErrorMessage` so the caller surfaces the specific message instead of a generic one; parameter type changed from `TournamentTemplateJsonConfig` to `TournamentTemplate` (sibling-method alignment, no functional impact — `TournamentTemplate : TournamentTemplateJsonConfig`)

## Findings

### F-1: `InitializeGrouping` pre-fix bug had broad impact, but pre-release [Info]

**Description.** The pre-fix `OrderBy(MinRating)` meant the lowest-rating bracket landed at `groups[0]` and got `MaxRating = int.MaxValue` (only the *highest* bracket should be uncapped). Then for every subsequent bracket the loop set `MaxRating = previousBracket.MinRating - 1`, which under ascending sort produces `MaxRating < MinRating` — invalid intervals. Net effect: every tournament whose `TournamentGroupingRule` left `MaxRating` at default `0` would receive broken brackets, causing `CreateBuckets` (`MatchmakingLogic.cs:349`) to leave most participants unmatched.

**Investigation.**
- Read pre-fix file at r15708 — confirmed the loop body `groups[i].MaxRating = groups[i - 1].MinRating - 1` is unchanged; only the `OrderBy` direction was inverted.
- Walked example with MinRatings [0, 50, 100]: ascending → groups[0].MaxRating=MaxValue (wrong), groups[1].MaxRating=-1 (invalid), groups[2].MaxRating=49 (invalid). Descending → groups[0].MaxRating=MaxValue, groups[1].MaxRating=99, groups[2].MaxRating=49 (correct gap-free coverage 0–49 / 50–99 / 100–MaxValue).
- Grep'd callers of `InitializeGrouping`: only `TournamentsHelper.FromDto` (`Shared/SharedLib/Tournaments/TournamentsHelper.cs:31`). Idempotency holds — second call's `if (brackets[i].MaxRating == 0)` short-circuits.
- Release status: per user, feature is on Test environment, not in prod → no production rows / live tournaments affected. Severity collapses from High to Info per pre-release pattern (FP-42164 lesson).

**Resolution.** Accepted. Fix is correct; test catches the exact bug.

### F-2: `tournament.Places == null` still throws NRE [Info]

**Description.** The new guard checks `Places.Any(place => place == null)` for null *elements*, but if `tournament.Places` itself is `null`, the validator still NREs. Pre-existing — pre-fix code also dereferenced `Places.Select(...)` without a null guard.

**Investigation.** File inspection only.

**Resolution.** Pre-existing — not a regression of this commit. Out of scope for the validator-crash fix; would require asking whether `Places` is structurally guaranteed non-null upstream (deserializer/DAL contract). Skipped.

### F-3: Diagnostic message names "double commas" specifically [Info]

**Description.** The error message `"... has empty places, check for double commas in places list."` hard-codes one likely cause. A null entry could also come from explicit `null` in JSON (`[ {…}, null, {…} ]`) or programmatic mutation. The author's diagnostic guess matches the most common Newtonsoft artifact, so the message is useful in practice.

**Investigation.** File inspection only.

**Resolution.** Accepted. The narrower phrasing helps the curator diagnose the typical case faster than a generic "null entry" message.

## Notes

### XML doc on `CheckPlaces` not updated for the new `out` parameter

`<param name="placesErrorMessage">` is missing and `<returns>` doesn't mention that the message is set on `false`. Cosmetic — not flagging.

### No test for `CheckPlaces` null branch

There is no `CompetetiveActivityBreaksModelTests` file at all in WebAdmin tests (verified via `Glob`). Pre-existing gap consistent with how WebAdmin validators are covered today; not raising as a blocker for this commit.

### Bundled unrelated fixes

Commit ships two unrelated fixes (matchmaking grouping + competition validator). Both are reflected in the commit message and both are scoped to the same JIRA ticket via the executor's posting. Not unusual for cleanup work.

## Investigation Journal

- VCS audit: `svn log --search "FP-41848" -r 15000:HEAD` on LBM working copy → exactly one commit (r15709), matches JIRA. No unlisted commits.
- Branch ancestry: per KB `_index.md` → Server Branch Ancestry, MFT20260325 was copied from LBM:15942. r15709 ≤ 15942 → inherited via branch copy. Verified by `svn log https://svn.fishingplanet.com/svn/SRV/branches/MFT20260325/Shared/SharedLib/Tournaments/MatchmakingLogic.cs --search "FP-41848"` — r15709 appears in MFT log. No `Merged → MFT` line in JIRA comment.
- Hypothesis "type change `TournamentTemplateJsonConfig → TournamentTemplate` alters semantics" — disproven. Grep'd the class declarations: `TournamentTemplate : TournamentTemplateJsonConfig` (`Shared/ObjectModel/Tournaments/TournamentTemplate.cs:7`); pre-fix call site already passed a `TournamentTemplate` instance (working via upcast). Change is sibling-method alignment, not behavioral.
- Hypothesis "the diff is too narrow to see the loop body" — disproven by `svn cat -r 15708`: the loop existed unchanged; only the `OrderBy` direction was inverted.
- Did not dispatch code-reviewer agent — 3-file fix with obvious shape; recon was sufficient.
