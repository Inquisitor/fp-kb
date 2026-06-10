---
status: resolved
executor: Yuriy Burda
branch: MFT @ r16149, merged to NPN @ r16150
jira: https://fishingplanet.atlassian.net/browse/FP-43816
---

# FP-43816: [Tournaments] Snapshot Level/Rank/CompetitionRating/TournamentRating/lifetime trophies in TournamentParticipants at registration and start

## Summary

Persist a point-in-time snapshot of player parameters into `TournamentParticipants` at two moments — at registration (`...AtReg`) and refreshed at tournament start (`...AtStart`) — so retrospective views and Support investigations see the player's strength as it was, not the current live `Profiles` values.

Snapshotted parameters (×2, AtReg/AtStart):
- `Level`, `Rank`
- `CompetitionRating` (nullable; Competitions only, KindId=3)
- `TournamentRating` (nullable; Tournaments only, KindId=1)
- `LifetimeGold` (StatsJson.GenericStats.CompWon.Count)
- `LifetimeSilver` (Comp2nd.Count)
- `LifetimeBronze` (Comp3rd.Count)

Suffix convention `...AtReg` / `...AtStart` (not `Current...`) is mandatory to avoid ambiguity with the existing `Rank` column on `TournamentIndividualResults` (result-ranking, different meaning) in JOIN queries.

## Scope

- **MFT r16149** — FP-43816 Snapshot player params in TournamentParticipants at reg and start
  - DAL: new snapshot columns on DTOs + `SqlTournamentProvider` write/read paths
  - GameServer: `TournamentAdapter` wiring
  - SQL: patch `MFT.M.2026.06.04-024 [TournamentParticipants]` (DDL) + release backfill `R202606-TournamentParticipantRatingBackfill`
  - WebAdmin: `ParticipantSnapshotFormat` helper, `ReviewTournamentModel`, two views (PlayerCompetitionHistory, TournamentResult), csproj registration
- **NPN r16150** — Clean merge of r16149 (paths copied from MFT@16149)

VCS audit: commit list matches JIRA; branch correct; r16150 is a verbatim merge of r16149. No missing/extra commits.

## Findings

### F-1: Forward path captures both ratings regardless of KindId; backfill gates by KindId [Low]

**Description:** `TournamentAdapter` (registration ~line 226, start-snapshot ~line 476) writes `CompetitionRatingAtReg/AtStart` and `TournamentRatingAtReg/AtStart` unconditionally from `profile.CompetitionRating`/`profile.TournamentRating`, regardless of the tournament's KindId. The ticket spec wanted these KindId-gated (Competition rating only for KindId=3, Tournament rating only for KindId=1), and the backfill script honors that gating. Result: the cross-kind rating column is populated for new rows but NULL for historical (backfilled) rows of the same KindId — a silent cohort split for any future "rating at reg/start" analytics query. No display impact: both WebAdmin views gate the rating/trophy columns by Kind, so the extra-captured cross-kind value is never shown.

**Investigation:** Read full r16149 diff; confirmed `profile.CompetitionRating`/`TournamentRating` are `int?` (Profile.cs:179-180), so cross-kind capture yields NULL only for players with no such rating, a value otherwise. Verified backfill CASE expressions gate strictly by KindId (1↔TournamentRating*, 3↔CompetitionRating*). DTO comment ("Both ratings are captured regardless of KindId") shows the deviation is deliberate. Independent code-reviewer agent confirmed (confidence 90, Low).

**Resolution:** Accepted — deliberate, documented, display-gated. Non-blocking note to author: forward vs backfill divergence for cross-kind rating; either accept or align (gate the adapter, or note the divergence in the backfill header). Author's call.

**Discovered by:** skill recon (confirmed by code-reviewer agent).

## Notes

- **Backfill rating math** (`R202606-...Backfill.sql`): reconstructs "rating carried into tournament" via the Lindley reflected-walk closed form `A_{k-1} = S_{k-1} - min(0, min S_1..S_{k-1})` using running SUM/MIN window functions (live engine floors rating at 0 per event, so plain SUM is wrong). Math verified correct (window boundaries `ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING`). Default `@DryRun = 1` (safe). Idempotent via `COALESCE(existing, reconstructed)`.
- **UNION ALL double-count hypothesis (ruled out):** live + archive tournament tables are unioned in the backfill; a TournamentId existing in both would corrupt the running sum. Verified archive is a fallback (cache reads live first, archive only when absent) — no TournamentId overlap. Not a risk.
- **JOIN audit (the spec's named risk):** snapshot columns correctly table-qualified in all 3 inline SELECTs — `tp.` where `p`=Profiles (GetTournament/UserCompetitionOnReviewParticipants), `p.` where `p`=TournamentParticipants (GetUserCompetitionHistory). No ambiguity with `TournamentIndividualResults.Rank`.
- **cshtml column alignment:** header colspan/rowspan grid width matches body `<td>` count in both Competition and Tournament branches of `TournamentResult.cshtml`, and in the Competition-only `PlayerCompetitionHistory.cshtml`. Promoted `<td>` correctly guarded inside the same `@if (Competition)` block.
- **Quality positives:** archive table mirror columns covered in the patch; 2 DB integration tests added (AtReg populated / AtStart null on register; AtStart set on snapshot); `RegisterForTournament` SqlException now logged (was silently swallowed); AtStart snapshot wrapped in try/catch so analytics failure never blocks tournament entry.
- **Deploy ordering (Info):** DDL patch adds nullable columns with no defaults — must run before the new code deploys (release checklist already tags "DB Migrations" + "Custom DB scripts"). Standard, not a defect.

## Verdict

**Approve.** Single Low finding (F-1) is an intentional, documented, display-gated deviation — non-blocking note to author, not a blocker. JOIN audit (the spec's explicit risk) passes; backfill math correct and safe-by-default; archive mirror and tests present.

## Investigation Journal

- Intake: executor = Yuriy Burda (commit author per JIRA comment); JIRA assignee is the reviewer (Stanislav). `customfield_11224` (Executor) empty — detect-only flag, not blocking.
- Branch path: MFT (Content) → NPN (Code) merge already done by executor at r16150. NPN created from MFT@r16130; r16149 > r16130, so not inherited via branch copy — explicit merge was required and present. Close phase: no further upward merge needed (Code is the top role).
- Verified DTO mapping is reflection-by-column-name (`DtoExtensions.RestoreObjectFromReader`) — new columns auto-map, no manual reader wiring needed. Insert params via `MsSqlHelper.ExtractParamsFromDto` (reflection) — AtReg params auto-supplied.
- Verified `TournamentParticipants.IsStarted` exists (AddTournamentParticipants.sql, SqlTournamentTestProvider) — backfill's `tp.IsStarted` gating is valid; initial "missing column → backfill crash" hypothesis disproven.
- F-1 confirmed independently by code-reviewer agent (a6025bc8); UNION-ALL double-count hypothesis raised to and ruled out by the agent.
