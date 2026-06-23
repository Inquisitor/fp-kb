---
status: resolved
executor: Yevhenii Shust
branch: NPN20260602 @ r16179, merged to MFT20260325 @ r16228
jira: https://fishingplanet.atlassian.net/browse/FP-44396
---

# Review: FP-44396 — [Leaderboards] Competitive leaderboard update aborts whole batch on first excluded-role participant (return vs continue)

## Summary

Pre-existing bug in `SharedLib/Leaderboards/LeaderboardsAdapter_Competitive.cs` →
`UpdateCompetitiveLeaderboards(TournamentKinds, IEnumerable<TournamentIndividualResultsDto>)`.
The per-participant loop used `return false` on a failed `CheckRole(result.Role)` check,
aborting the entire batch instead of skipping the single excluded-role participant.
Result: every participant after the first excluded-role account silently lost their
CompetitionsPlayed / CompetitionsWon / CompetitionRating increments, leaving the
leaderboard in a partial/inconsistent state. Fix: `return false` -> `continue`.

Bug found during FP-43817 review; not introduced there. Parent FP-43213.

## Scope

- **NPN20260602 r16179** — Fixed: per-participant role check now skips the excluded
  participant (`continue`) instead of aborting the whole batch
  - Replace `return false` with `continue` in the role-check branch
  - Unit tests added (`CompetitiveLeaderboardsUpdateTests`, mocked provider, no DB)

> Release note (per task owner): this fix must be merged under release into the Content
> branch (MFT20260325). Merge NPN -> MFT pending; branch-copy inheritance check in Phase 2.

## Notes

The fix is correct, minimal, and matches the proposed fix in the ticket exactly. No blocking
findings. Diff touches three files:

- `LeaderboardsAdapter_Competitive.cs` — `return false` -> `continue` in the role-check branch;
  TODO marker (left by FP-43817) removed. Method end returns `true` (normal path verified).
- `ProfileRole.cs` — `Insider` comment "(not listed in leaderboards)" -> "(listed in leaderboards)",
  now consistent with `CheckRole` (which admits None/Insider/Moderator); also adds the missing
  final newline. Tangential doc correction, harmless.
- `CompetitiveLeaderboardsUpdateTests.cs` (new) — three tests: excluded-role mid-list (regression),
  all-excluded, feature-off. Mocked provider, no DB.

Minor observations (Info, non-blocking):

- **N-1** Test included-role coverage uses only `ProfileRole.None`; it does not assert that
  `Insider`/`Moderator` are admitted, which is the more interesting boundary (esp. given the
  `Insider` comment change). Strengthening suggestion only.
- **N-2** Behavior change: when *all* participants are excluded (or the first one is), the method
  now returns `true` instead of `false`. Verified harmless — both production callers
  (`TournamentEndAdapter` x2) invoke it as a statement and discard the return value.
- **N-3** JIRA comment names the kind-guard class "CompetitiveLeaderboardsHelper"; the actual class
  is `LeaderboardsHelper` (partial, `LeaderboardsHelper_Competitive.cs`). Text-only imprecision.

## Merge to MFT (Content, under release)

Per task owner, this fix must ship in the MFT release. r16179 is a native NPN commit
(r16179 > NPN base r16131) and is NOT inherited by MFT (NPN was forked *from* MFT@16130, so the
commit lives on the child branch only). Explicit merge NPN -> MFT required. Bug confirmed still
present in MFT (`return false` + TODO at the same site); region is structurally identical to NPN
r16178, so the cherry-pick should apply cleanly. Merge is performed in the close phase.

## Investigation Journal

- Intake: commit r16179 (NPN, executor Yevhenii Shust) taken from JIRA comment at face value.
- Phase 2 audit: `svn log | grep FP-44396` on NPN confirms single commit r16179; same grep on MFT
  returns nothing -> not yet merged. WC at r16227 >= r16179, disk fresh; NPN files read from disk,
  diff read via `svn diff -c 16179`.
- Verified method returns `true` at normal end (line 113); `CheckRole` admits None/Insider/Moderator.
- Verified both production callers (`TournamentEndAdapter.cs` :115, :315) discard the bool return ->
  the false->true change on the excluded path is inert.
- Verified executor's UGC claim: `GetSupportedTournamentKinds()` = `CompetitiveActivityDimensionFieldNameMapping.Keys`
  = `{ Competition }` only; the line-76 kind guard returns false for any non-Competition kind before
  the loop, so UserGenerated results never reach this path.
- Verified test validity: `LeaderboardsAdapter` ctor stores the passed `ILogBase` in `_logger`; the
  test passes a non-null `Mock<ILogBase>`, so the skip-branch `_logger.LogAsync` is a loose-mock
  no-op (no NRE) — the mid-list test genuinely exercises the skip path.
- Branch-copy inheritance: r16179 not inherited by MFT; explicit merge required (see Merge section).
- Executor field (`customfield_11224`) empty on the ticket — flagged, not blocking.
- Independent `feature-dev:code-reviewer` agent run (deep delegation): no high-confidence issues;
  confirmed all five recon checks. Added confirmation that `EndUserCompetition` in
  `TournamentEndAdapter` has no `UpdateCompetitiveLeaderboards` call at all, so UGC is bypassed
  twice over. Only observation = same Info-level test-coverage gap (N-1).

## Verdict

**APPROVE.** The fix is correct, minimal, and exactly matches the proposed remediation. Normal path
returns `true`; both production callers discard the bool, so the excluded-path false->true change is
inert; the regression is directly covered by a mid-list excluded-role test; the executor's UGC claim
is verified in code. Independent agent review found no high-confidence issues. The lone observation
(N-1, Insider/Moderator not exercised in the allowed path) is Info-only and does not block.

Backported to the MFT release branch via cherry-pick `svn merge -c 16179` (committed r16228);
applied cleanly. Release-step field gate satisfied trivially (code-only change, no
`customfield_11323` options derived).
