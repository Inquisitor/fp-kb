# FP-43625 — Backlog

## Done
- [x] KB context read (`fishing-planet/server/modules/matchmaking/_card.md` + log, `tasks/FP-43631--rating-drop-abuse-detection/journal.md` + backlog, `tasks/FP-41746--matchmaking/artifacts/MatchMaking-System-1st-Iteration-GDD-ideal.md`)
- [x] GD docs fetched: Confluence 5561024534 (MatchMaking System - 2nd Iteration, MaxWins spec); 3817603108 (legacy Rating Proposal, context only)
- [x] Code surveyed: `MatchmakingLogic`, `TournamentBracket`, `TournamentGroupingRule`, `TournamentBucket`, `TournamentGroupParticipant`, `SqlTournamentProvider.GetTournamentParticipants`, `GameClientPeer_Tournaments` (counter increment site)
- [x] DB inspection on local + prod (Steam/PS/Xbox via DataGrip MCP): template/tournament inventory, single semantic Grouping shape, `Midles` typo prevalence, absence of `MaxRating` in templates, zero per-row overrides
- [x] `JsonVariablesCache` partial-class pattern researched + research artifact written
- [x] Correlation SQL artifact drafted (post-deploy calibration aid for GD)
- [x] Spin-off JIRA tickets created: FP-43815 (admin/Support visibility), FP-43816 (TournamentParticipants snapshot), FP-43817 (log-level hygiene). Parent FP-26788, Scrum Team = Other
- [x] Data-driven threshold calibration on prod Q1 export. Two methodologies (max-F1 on FP-43631 cohort; KS-distance distribution match). Hybrid recommendation: Newbies `4/3/6` (Method A), Middles `12/13/14` (Method B). Full report + frozen artifacts under `artifacts/`

## Pending — present calibration to GD
- [ ] Present `artifacts/calibration-report.md` to GD. Concrete proposal: change Newbies thresholds from `3/4/5` to `4/3/6`, Middles thresholds from `12/15/20` to `12/13/14`. Push to `dbo.JsonVariables.Tournaments.GroupingDefault` on deploy
- [ ] Establish monthly calibration cadence: re-run `correlation-sql.sql` Q1 on each platform, re-run `joint-calibration.py` and `distribution-match-all.py` scripts, propose threshold updates if metrics shifted by > 10%

## Immediate (implementation)
- [ ] `JsonVariables` wire-up: new `Shared/SharedLib/Config/JsonVariablesCache_Tournaments.cs` exposing `GroupingDefault`, wired into top-level `JsonVariablesCache.UpdateStaticVariables`
- [ ] MaxWins gate: extend `TournamentBracket` with `MaxWins / Max2nd / Max3rd` (nullable); extend `TournamentGroupParticipant` with `LifetimeGold / LifetimeSilver / LifetimeBronze` and `IsPromoted`; extend `SqlTournamentProvider.GetTournamentParticipants` JOIN with three `JSON_VALUE` projections; plug `ExceedsBracketLimits` filter into `MatchmakingLogic.CreateBuckets`
- [ ] Promotion-aware sort in `RefreshBucket`: two-section sort `[non-promoted ASC by CompetitionRating, promoted ASC by LifetimeGold + LifetimeSilver + LifetimeBronze]`. No changes to `BalanceBuckets`; the extreme picks at `[0]` and `[N-1]` already give the right semantics under the new sort
- [ ] Config overlay at `MatchmakingLogic.ProcessGroupingForTournament` entry: `tournament.Grouping ?? JsonVariablesCache.Tournaments.GroupingDefault`, `InitializeGrouping(grouping)`, then persist resolved Grouping back into `Tournament.ConfigJson` on first matchmaking via new `ITournamentProvider.PersistTournamentGrouping`
- [ ] Defensive fallback: when a participant is filtered by every bracket their `CompetitionRating` could reach, keep them in their original bracket (`IsPromoted = false`) and emit a Warning log naming the bracket and triggering counter
- [ ] Tournament logging on every matchmaking action: entry line in `ProcessGrouping` (tournament ID, participant count, Grouping source); per-participant bracket-assignment line in `CreateBuckets` (with `IsPromoted` and trigger when applicable); per-move line in `BalanceBuckets` (donor-fill and merge paths); per-participant final-group line in `AssignGroupsToParticipants` (`BracketId`, bracket name, group name)
- [ ] WebAdmin Tools counter setters: extend `ToolsModel_Profile` / `ToolsModel_Competitions` with input fields and write-paths into `Profiles.StatsJson.$.GenericStats.{CompWon|Comp2nd|Comp3rd}.Count` so QA can construct synthetic test profiles
- [ ] Tests:
  - Unit tests on `CreateBuckets` MaxWins gate: per-participant `(CompetitionRating, gold, silver, bronze)` against brackets+thresholds → `BracketId` + `IsPromoted`. Cases: threshold-on-edge, cascade promotion, `MaxWins=null` regression, defensive Tops fallback
  - Unit tests on `RefreshBucket` ordering: mixed non-promoted + promoted participants → asserted `[non-promoted ASC by rating, promoted ASC by wins]`
  - Integration tests on `BalanceBuckets` extension: donation to weaker neighbour picks lowest-rating non-promoted; donation to stronger neighbour picks highest-wins promoted
  - Integration test on downstream invisibility: promoted player contributes to `ReassignGroupsToBuckets` median computation, sorting and reward assignment identically to a real player of the same `BracketId`
  - Existing `MatchmakingLogicTests` string-notation cases stay untouched — they test bucket counts and group sizes, not within-bucket ordering
- [ ] Deployment SQL (one idempotent transaction per platform):
  - `MERGE` insert into `dbo.JsonVariables` the `Tournaments.GroupingDefault` row with `MinSize=20`, three brackets at 0/101/1001, `Middles` spelling, GD-spec `MaxWins/Max2nd/Max3rd`
  - `JSON_MODIFY(ConfigJson, '$.Grouping', NULL)` on all `KindId=3` templates carrying `Grouping` (103 active rows per platform)
  - `JSON_MODIFY(ConfigJson, '$.Grouping', NULL)` on all `KindId=3` future tournaments (`EndDate > SYSUTCDATETIME()`, 151/151/152 rows on Steam/PS/Xbox)
  - Already-played tournaments left untouched (audit trail of what they actually ran on)
- [ ] Per-platform rollout: Steam/EGS → PlayStation → Xbox. MS-side patches applied before each platform binary deploy
- [ ] Post-deploy verification: confirm overlay resolution and `ConfigJson` bake-back on an upcoming Competition per platform; check `TournamentLog` shows expected bracket/bucket/promotion entries; cross-check against FP-43631 candidate cohort

## Out of Scope

Items surfaced during discovery that do not belong in FP-43625. Listed here so they do not get lost; spawn separate JIRA tickets when capacity allows.

### Admin/Support visibility — FP-43815
- [ ] FP-43815: Restore `CompWon/Comp2nd/Comp3rd` on PlayerCard; add Competitions tab in admin; per-player Competitions history page; "promoted by MaxWins" column on Group Distribution view

### Result snapshotting — FP-43816
- [ ] FP-43816: Snapshot `Level / Rank / CompetitionRating / TournamentRating / LifetimeGold / LifetimeSilver / LifetimeBronze` in `TournamentParticipants` at registration; refresh at start. `...AtReg` / `...AtStart` suffix naming to avoid `Rank` ambiguity with `TournamentIndividualResults`. JOIN audit on existing stored procs required

### MMR (continuous rating) — speculative
- [ ] Replace the discrete MaxWins gate with a continuous `effective_rating = f(CompetitionRating, wins)` and classify by `effective_rating`. Likely depends on the correlation field collected post-deploy. Future iteration; cite as the next structural step after MaxWins

### Calibration dashboard (optional, low priority)
- [ ] Long-lived admin page with `(CompetitionRating, CompWon/2nd/3rd)` scatter, bracket boundary overlays, NOLOCK queries. Cheaper alternative: keep using the one-shot SQL + Sheets export pattern from FP-43631; only build the dashboard if calibration becomes a recurring need

### Log-level hygiene — FP-43817
- [ ] FP-43817: Demote tournament-start log entries from Warning to Info so the Warning channel surfaces actual problems only

### Cosmetic — bundled with FP-43625 deployment
- [ ] Rename `Midles` → `Middles` in `BracketName`. Internal name only (never shown to players). Folded into the `JsonVariables` insert at zero cost — the default uses the correct spelling, and templates / tournaments shed their per-row `Grouping` via `JSON_MODIFY(..., NULL)` in the same migration

## Cross-references
- FP-43631 (closed): detection + reactive ban for the same abuse vector. This task is the structural counterpart
- FP-43717 (open): eliminate persisted `MaxRating`. Not a blocker; the empirical absence of `MaxRating` in any template config makes Option A (drop the field) safe
- FP-43815 (open): admin/Support visibility spin-off
- FP-43816 (open): TournamentParticipants snapshot spin-off
- FP-43817 (open): tournament-start log-level hygiene spin-off
- FP-41595 (in-progress): leaderboards release support — same per-platform deploy choreography
- FP-41746 (closed): prior matchmaking work, terminology rename, FFS algorithm
