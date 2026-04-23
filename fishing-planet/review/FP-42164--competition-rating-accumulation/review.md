---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15933 (inherited by MFT via branch copy @ r15943)
jira: https://fishingplanet.atlassian.net/browse/FP-42164
---

# Review: FP-42164 — [Leaderboards][Rating] Leaderboards update a player's ranking based on the latest result

## Summary

Competition leaderboard (`CompetitiveRatingsCurrent`) showed only the rating from the latest finished competition instead of the accumulated rating over the period. Root cause: `UpdateCompetitiveLeaderboards` stored procedure used `IIF(... @CompetitionRating ...)` — an unconditional replacement — in the `WHEN MATCHED` branch of its `MERGE`, while the sibling counters (`CompetitionsPlayed`, `CompetitionsWon`) correctly used `Target.[X] + @X`. The fix aligns `CompetitionRating` with the accumulative pattern. This also brings the procedure back in line with the documented interface contract in `ILeaderboardsProvider_Competitive` (`"The increments are added to the existing values"`).

## Scope

- **LBM r15933** — Fix competition leaderboard rating replacement instead of accumulation
  - `CompetitionRating` in `MERGE ... WHEN MATCHED` changed from replacement to `Target.[CompetitionRating] + @CompetitionRating`
  - `CompetitiveLeaderboardsTests.Test_CalculateCompetitiveLeaderboardChange`: fixed copy-paste bug where three asserts all checked `standings[0].Change`; now covers `[0], [1], [2]`
  - Same test: added a fourth-competition block that feeds second-round ratings and asserts the resulting reshuffle is consistent with *accumulated* totals (comment inline: `user0=15+15=30, user1=12+20=32, …`)
  - Whitespace cleanup in the SQL file (tabs → spaces, BOM dropped) — no functional changes
- **MFT** — inherited via branch copy (r15943, 2026-03-25) created from LBM after r15933; `svn log` on the SQL file in MFT shows r15933. No `svn merge` needed; JIRA comment will omit `Merged → MFT` to avoid a false audit claim (per KB lesson from FP-42477)

## Findings

### F-1: Accumulative test lives under `[Ignore]`, so the fix has no automated coverage [Medium]

**Description.** `Test_CalculateCompetitiveLeaderboardChange` (the test whose asserts were repaired and extended) is annotated `[Ignore]` because it requires a live SQL database and calls `BackupAndRestore`. It never runs in CI. The copy-paste bug where all three asserts checked `standings[0].Change` survived precisely because the test is ignored — a green CI gives no signal here. The new fourth-competition block which is the only automated evidence the accumulation fix behaves correctly is also ignored.

**Investigation.**
- Grepped callers of `UpdateCompetitiveLeaderboards`: `TournamentEndAdapter` (tournament finish path) and `LeaderboardsAdapter_Competitive.UpdateCompetitiveLeaderboardsAdmin` (admin path via WebAdmin views `CompetitiveLeaderboardHistory` / `CompetitiveLeaderboardExt`).
- `ILeaderboardsProvider_Competitive.UpdateCompetitiveLeaderboards` xmldoc: `"The increments are added to the existing values, but if the result is less than 0, it is set to 0."` — confirms the contract was accumulative; SQL was drifting from contract.
- Read full test body (`CompetitiveLeaderboardsTests.cs` lines 202–366): all neighboring leaderboard tests are also `[Ignore]` — this is the established pattern for this test class, not a regression introduced by the author.

**Resolution.** Pre-existing — not the author's oversight; the class has been `[Ignore]` from the start. Team already has a separate plan to address the broader "DB-dependent tests skipped in CI" pain, so this finding does not go into the JIRA comment.

**Discovered by.** Skill recon.

### F-2: Admin UI path silently changes semantics from "replace" to "increment" [Medium]

**Description.** `UpdateCompetitiveLeaderboardsAdmin(period, userId, playedIncrement, wonIncrement, ratingIncrement)` uses the same `UpdateCompetitiveLeaderboards` SP. Before this fix, passing `ratingIncrement = 500` *replaced* the player's rating with `500`. After the fix, it *adds* 500 to the existing value. Parameter names (`playedIncrement`, `wonIncrement`, `ratingIncrement`) already suggested additive semantics, so the fix aligns behaviour with names — but any admin workflow that relied on the old replace behaviour for `Rating` will now produce different results.

**Investigation.**
- Callers: `WebAdmin/Models/Stats/Leaderboards/CompetitiveLeaderboardHistoryModel.cs` (line 438) and `CompetitiveLeaderboardExtModel.cs` (line 301), both invoked from admin-RW-only pages under `Stats/CompetitiveLeaderboardHistory` and `Stats/CompetitiveLeaderboardExt`.
- Counters `Played` / `Won` were already accumulative in the old SP → admins who edited those already got `+` semantics. Only `Rating` flipped.
- No public caller of `UpdateCompetitiveLeaderboardsAdmin` outside WebAdmin; blast radius is internal admin tooling.

**Resolution.** Accepted — aligns with parameter naming and the interface contract. Admin-facing behaviour change should be called out to QA so they know the rating field in these pages now behaves as a delta, not as an absolute setter. If an absolute-set operation is needed, it would be a separate function.

**Discovered by.** Skill recon.

### F-3: Existing rows in `CompetitiveRatingsCurrent` carry "last-value" numbers, not accumulated totals [High]

**Description.** The bug meant the row for every user who finished at least one competition under the buggy code holds the *last* rating increment, not the accumulated total. After deploy, the fix starts *adding* new increments on top of these stale bases. The visible number on the leaderboard will become `stale_last_value + accumulated_new_increments` — neither the correct accumulation nor the pre-fix behaviour. No data migration / backfill ships with the commit.

**Investigation.**
- `LeaderboardsAdapter_Competitive.UpdateCompetitiveLeaderboards` writes all three period types for every tournament finish: `EnumHelper.GetValues<LeaderboardPeriodType>()` → `Weekly`, `Monthly`, `Yearly` (confirmed via `LeaderboardsHelper.cs:60-62`).
- Period self-heal timelines after deploy (rows repopulate correctly only on next rotation into fresh period): Weekly ≤7 days, Monthly ≤~30 days, **Yearly up to ~8 months** (current Yearly period started 2026-01-01, rolls over 2027-01-01).
- `GameClientPeer_Leaderboards` accepts `periodType` as a request parameter from the client, and the WebAdmin UI `PeriodTypeList` lists all three — Yearly is a real user-facing surface.
- Haven't checked whether client UI currently exposes Yearly Competition rating (would need client-side inspection); but the server-side path is live.

**Resolution.** Skipped — feature has not been released to production; stale rows exist only on QA environments, which will be wiped as part of re-verification. No backfill obligation. Not raised in JIRA.

**Discovered by.** Skill recon.

> Process note: severity was initially drafted as High based on a production-deploy assumption. Pre-release status collapses the impact window entirely. A generalizable rule for the review draft: verify release status before assigning severity to data-integrity / backfill findings.

## Notes

- Procedure deployment model: `SQL/Patches/Main/Procedures/*.sql` files are idempotent DROP+CREATE scripts deployed by the release pipeline, not `AppliedPatches`-numbered patches (project convention). Absence of a numbered patch is expected and not a finding.
- Whitespace normalization in the SQL file (tabs → 4 spaces, BOM removed) obscures the diff slightly but is harmless — visual confirmation of the single functional change is clear in the `[CompetitionRating]` line of the `WHEN MATCHED` branch.
- `INSERT` branch (`WHEN NOT MATCHED`) already uses `@CompetitionRating` directly, which is correct for the first write — no change required there.
