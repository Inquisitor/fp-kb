---
status: resolved
executor: Yuriy Burda
branch: MFT @ r16132, r16208, merged to NPN @ r16133, r16209
jira: https://fishingplanet.atlassian.net/browse/FP-43815
---

# Review: FP-43815 — Matchmaking admin/support visibility

## Summary

Admin/Support visibility improvements around the matchmaking MaxWins promotion gate (FP-43625). Four scope items: surface lifetime Competition counters (CompWon / Comp2nd / Comp3rd) on PlayerCard; a Competitions list in admin alongside Tournaments; a per-player Competition participation history page linked from PlayerCard; and a "promoted by MaxWins" column (with triggering counter) on the Group Distribution / Competitive Activity Schedule view. WebAdmin-only change.

## Scope

### MFT (Content)
- **r16132** — Add CompWon/2nd/3rd to PlayerCard, Add Promoted column to TournamentResult, Add per-player Competition participation history, improvements for Competitive Activity Schedule
  - Scope 1: surface CompWon / Comp2nd / Comp3rd lifetime counters on PlayerCard
  - Scope 3: per-player Competition participation history (inverse of per-Competition results page)
  - Scope 4: "Promoted by MaxWins" column + triggering counter on Group Distribution view
  - Scope 2 (Competitions tab/list) — not explicit in commit msg; verify coverage in Phase 2
- **r16208** — Fix TournamentsSchedule crash on null bracket participant counts (follow-up)

### NPN (Code, merged)
- **r16133** — Merge of r16132
- **r16209** — Merge of r16208

## Investigation Journal

- Intake: executor = Yuriy Burda (`customfield_11224` populated, matches commit author). Source branch MFT (Content), merged to NPN (Code) — valid Content→Code direction. Inheritance check: NPN forked from MFT:16130; both commits (r16132, r16208) are after the fork point, so explicit merges (r16133, r16209) are required and present.
- VCS audit (`svn log | grep FP-43815` on MFT and NPN, r16100:HEAD): only r16132 + r16208 on MFT, merges r16133 + r16209 on NPN. No unposted FP-43815 commits → no executor-quality finding. WC at r16227 (ahead of both reviewed revs) — disk reflects post-fix state.
- HEAD divergence: `GetUserCompetitionHistory` + `UserCompetitionHistoryDto` on HEAD carry AtReg/AtStart snapshot columns absent from the r16132 diff. Traced to sibling ticket **FP-43816** (r16149, "Snapshot player params in TournamentParticipants") — NOT an FP-43815 commit. Reviewed FP-43815 against the r16132 diff for those two files.
- Verified `r.Rating AS RatingDelta` is correct: `TournamentIndividualResults.Rating` is written as `CurrentPlayerResult.Rating = ratingGained` (`GameClientPeer_Tournaments.cs`) — a delta. +/- coloring in the history view is valid.
- Verified `TournamentBracket` (ObjectModel) exposes `BracketName/MinRating/MaxRating`; `TemplateId` is bound in the Kendo grid model — Template button works. Both non-findings.
- Independent code-reviewer agent dispatched. It challenged the null-key crash premise (claimed `Dictionary<int?,int>` accepts a null key). **Empirically disproven** via `Add-Type` probe: `new Dictionary<int?,int>()[(int?)null]=5` throws `ArgumentNullException` (boxing a no-value `Nullable<int>` yields null; the dictionary null-key guard fires before the comparer). r16208 fix + its code comment are correct; agent's L-1 rejected.
- Agent's date-Kind concern (my draft F-3) ruled a false positive: SQL Server receives `DateTime` values verbatim regardless of `DateTimeKind`, and the page operates entirely in UTC — no wrong window. F-3 dropped.
- Third opinion via `/ask-codex` (gpt-5.5, read-only). It independently re-confirmed the null-key crash with C# Interactive (`csi`): `new Dictionary<int?,int>()[(int?)null]=1` → `System.ArgumentNullException: key` — second empirical confirmation, agent's L-1 conclusively wrong. Codex also surfaced a finding both prior reviewers missed (F-4 below).
- F-4 archive-omission verified end-to-end: existing `GetTournamentIndividualResultHistory` proc `UNION ALL`s live + `ArchiveTournamentIndividualResults`/`ArchiveTournamentParticipants`. `PerformTournamentArchivation` (called daily 02:03 by `TournamentArchivationJob`, horizon = `UtcNow - 60d`) moves ended/canceled tournaments older than 60 days to the Archive tables and **deletes** them from live. New `GetUserCompetitionHistory` reads live only → competitions older than ~60 days silently vanish from the history page for any date range the operator widens past the horizon. Default window (−30d) and the AC's "last month" stay inside the horizon, so the common case works.

## Findings

### F-1: "Promoted" column is a live-rating heuristic, not the MaxWins triggering counter [Medium]

**Description:** `Views/Tools/TournamentResult.cshtml` adds a "Promoted" column whose cell shows "↕ rebalanced" when a participant's `CompetitionRating` falls outside their bracket's `[MinRating..MaxRating]`. The JIRA scope item 4 / acceptance criterion asked Support to read "which counter triggered the promotion (e.g. Gold=15 >= 12)". The implementation surfaces no counter; it is a rating-vs-bracket proxy. Three sub-issues: (a) it uses the player's **live** `CompetitionRating` (current profile value), not the rating at bracket-assignment time, so the indicator drifts as the player's rating changes after the competition; (b) header label "Promoted" vs cell text "rebalanced" are inconsistent vocabulary; (c) any out-of-range rating trips it (post-tournament drift, demotion), not only MaxWins promotions.

**Investigation:** Read r16132 diff; confirmed cell logic compares `i.CompetitionRating` (live, sourced from `Profiles.CompetitionRating`). At r16132 no per-participant rating snapshot existed. Sibling FP-43816 (r16149) later added `CompetitionRatingAtReg/AtStart` (+ Lifetime medal AtReg/AtStart) snapshots, now shown as adjacent columns on HEAD — exactly the data needed to make the indicator accurate and to surface the actual triggering medal counter.

**Resolution:** Author decision (you own the ticket). Defensible as an interim heuristic given data availability at r16132. Recommended follow-up (now that FP-43816 persists snapshots): base the indicator on `CompetitionRatingAtStart` rather than live rating, reconcile the "Promoted"/"rebalanced" labels, and surface the triggering Lifetime-medal counter to fully satisfy AC4.

**Prod-verified context (STEAM PROD MAIN, 2026-07):** FP-43816 snapshots are deployed and populated — `LifetimeGold/Silver/BronzeAtReg` filled for all participants, `CompetitionRatingAtStart` for those who started. FP-43625 MaxWins gate is NOT deployed — of 502 competitions in the last 30 days, zero carry `MaxWins` in `ConfigJson.Grouping`; no real MaxWins promotions occur in prod. Per FP-43625 KB journal, promotion is **not persisted** per participant (`IsPromoted` is a transient matchmaking flag; the triggering counter is emitted only to the Mongo `TournamentLog`). Consequences: (1) AC4's "triggering counter" is premature — blocked on FP-43625 Cluster 2 shipping the thresholds; (2) the current column fires only on post-tournament rating drift (no promotions exist yet), so it presently shows near-noise mislabeled "Promoted". Cleanest design: have FP-43625 persist `IsPromoted` (+ triggering counter) as a `TournamentParticipants` column during matchmaking; FP-43815's admin column then reads it exactly instead of inferring. Short term: relabel/hide until FP-43625 lands.

**Discovered by:** skill recon, sharpened by code-reviewer agent, prod-verified via DB MCP.

### F-2: `TournamentsSchedule` GET/POST runs two schedule queries whose result is discarded [Low]

**Description:** `StatsController.TournamentsSchedule()` (GET and POST) calls `model.Fill()`, which runs `GetTournamentsSchedule` + `GetBracketCountsByTournament` into `model.Data`. The view renders a Kendo grid that immediately ajax-reloads via `ReadTournamentsSchedule` (its own `Fill()`), so `model.Data` is never read. Net: two SQL queries per page load (and per form submit) for nothing. `Fill()` is only needed here to default `StartDate/EndDate/KindId` for the date pickers. The `GetBracketCountsByTournament` query is the new r16132 cost; the `GetTournamentsSchedule` waste predates it.

**Investigation:** Read `TournamentsScheduleModel.Fill()` + `ConfigureGrid()` (ajax `.Read`). Confirmed view does not iterate `Model.Data`. Pre-r16132 GET did not call `Fill()` at all.

**Resolution:** Skipped (admin tool, low traffic) — optional cleanup: extract a defaults-only path used by GET/POST, keep the full `Fill()` only on the ajax `ReadTournamentsSchedule`.

**Discovered by:** skill recon, confirmed by code-reviewer agent.

### F-3: `BracketCounts` column rendered for all activity kinds [Info]

**Description:** `ConfigureGrid()` always adds the `BracketCounts` ("Brackets") column regardless of `KindId`. Only Competitions (KindId=3) populate brackets; for Sport Tournaments/Events/UGC the column is always empty. Minor clutter; default view is Competitions so rarely seen. Could guard with `if (KindId == 3)` like the existing `KindId == 1` serie-column guard.

**Investigation:** File inspection only.

**Resolution:** Skipped — cosmetic.

**Discovered by:** code-reviewer agent.

### F-4: per-player history reads live tables only — archived (>60-day) competitions silently omitted [Medium]

**Description:** `SqlTournamentProvider.GetUserCompetitionHistory` (the r16132 inline SQL backing the new history page) queries only live `Tournaments` / `TournamentParticipants` / `TournamentIndividualResults`. Tournaments are archived by `PerformTournamentArchivation` (daily 02:03 job `TournamentArchivationJob`, horizon = `UtcNow - 60 days`): ended/canceled tournaments older than 60 days are copied to `ArchiveTournaments*` and **deleted** from the live tables. So once a competition crosses the 60-day horizon it disappears from this page. The established analogous proc `GetTournamentIndividualResultHistory` deliberately `UNION ALL`s the live and archive tables to avoid exactly this. The page's date pickers allow any range; querying older than 60 days returns an empty list with no indication the data exists in archive.

**Investigation:** Read `GetTournamentIndividualResultHistory.sql` (live + archive UNION). Traced archival: `PerformTournamentArchivation` proc copies via generic `PerformArchivation` helper (dynamic column list from `INFORMATION_SCHEMA.COLUMNS`, `INSERT INTO Archive<table> SELECT <same cols>`), then deletes live rows; condition `StartDate < @horizon AND (IsEnded=1 OR IsCanceled=1)`; called by `TournamentArchivationJob` (`TournamentArchivationHorizon = 60` days, daily 02:03). Confirmed default model window (−30d..+7d) sits inside the horizon, so the AC's "last month" works; only widened ranges hit the gap. **DB schema check (local Main):** every column of `TournamentParticipants` / `TournamentIndividualResults` / `Tournaments` exists in its `Archive*` twin (zero missing) — archival is healthy and the archive tables already carry FP-43816's AtReg/AtStart snapshots → the fix needs no schema/backfill.

**Resolution:** Follow-up (owner-approved design). **Conditional archive UNION** — surface archived participation only when the request actually reaches into archived territory, else stay live-only:
- Include a `UNION ALL` branch over `ArchiveTournamentParticipants` + `ArchiveTournamentIndividualResults` + `ArchiveTournaments` (same join shape; `Translations` stays live) **only when** the requested `@startDate < now - <horizon>` (range crosses the archive boundary).
- Short-circuit the archive branch entirely when the account is younger than the horizon (profile registration date `> now - <horizon>` ⇒ zero archived competitions possible). The profile DTO is already loaded in `PlayerCompetitionHistoryModel.Fill` (`LoadPlayerProfile`), so no extra query.
- Correctness note: live and archive are **disjoint by TournamentId** (`PerformTournamentArchivation` copies then deletes in one transaction — confirmed in FP-43816 review "no TournamentId overlap"), so `UNION ALL` needs no dedup and the conditional is a pure performance optimization, never a correctness lever.
- Caveats for the ticket: (1) `<horizon>` is the C# const `TournamentArchivationHorizon = 60` in `TournamentArchivationJob` — not DB config; hardcode-with-margin or hoist to shared config, and allow slack for the batched daily archival (top-10, ended/canceled only, so the boundary drifts). (2) Pre-deploy archived rows carry NULL `Lvl/Rank/Trophies` snapshots (unreconstructable) and a backfill-only `Rating`; core columns (Place/Δ/Bracket/Reward) are correct. So enabling the archive branch is only "pretty" once the rating backfill is correct — hence F-4 rides in the blocked follow-up alongside F-1, not shipped standalone.

**Discovered by:** /ask-codex (gpt-5.5), verified by skill.

### Note — r16208 is a correct crash fix

The follow-up fixes a real `ArgumentNullException` from r16132 (`Dictionary<int?,int>` null-key set on un-matchmade participants), with extracted `BuildBracketCounts()`, unit tests, and `InternalsVisibleTo`. Null-key throw confirmed empirically. Consumer (`FormatBracketCounts`) updated consistently. No other consumers of `GetBracketCountsByTournament`.

## Verdict — Approve (resolved)

Approve the shipped code with two follow-up decision items. The change is functionally sound for its stated acceptance criteria and the crash is fixed (r16208, empirically confirmed twice). Scope 1 (CompWon/2nd/3rd on PlayerCard) and the schedule rework are clean; scope 3 (per-player history) works within the 60-day live window. Three independent reviews (skill recon, code-reviewer agent, /ask-codex) converged on two substantive gaps:

- **F-4 [Medium] — data completeness:** the history page omits competitions older than the 60-day archive horizon (live-only query vs the sibling proc's live+archive UNION). Default window is safe; widened ranges silently lose data. Recommend fixing via archive UNION (option a). This is the headline finding — neither earlier reviewer caught it.
- **F-1 [Medium] — AC4 coverage:** the "Promoted" column ships a live-rating-vs-bracket heuristic, not the requested MaxWins triggering counter; uses live (drift-prone) rating rather than the now-available FP-43816 `CompetitionRatingAtStart` snapshot; "Promoted"/"rebalanced" label mismatch.

F-2 (Fill double-query) and F-3 (BracketCounts column for all kinds) are non-blocking cleanups. Recommendation: approve r16132+r16208 as-is (no regression, crash fixed), and either reopen for the F-4 archive UNION or file it as a tracked follow-up; F-1 is an owner decision (accept interim heuristic vs. wire the snapshot/counter).

Three-reviewer agreement log: null-key crash real (me + codex empirical; agent's denial refuted) · Promoted heuristic insufficient (all three) · Fill double-query (all three) · archive omission (codex only, verified).

## Follow-up plan & dependencies (decided with owner)

Follow-up filed: **FP-44945** — `[Matchmaking] Admin visibility follow-up: accurate Promoted indicator + archived competition history` (Story, parent FP-30856; `is blocked by` FP-43625 + FP-43816, `relates to` FP-43815). Carries F-1(1)/(2), F-4, and the F-2/F-3 cleanups.


- **F-1(3) — triggering-counter → moves to FP-43625 (MaxWins gate).** That ticket already computes `IsPromoted` + the triggering counter during matchmaking (currently transient / Mongo-log only). Correct home is FP-43625 persisting `IsPromoted` (+ counter) as a `TournamentParticipants` column; the admin column then reads it exactly instead of inferring. Not actionable in an FP-43815 follow-up until FP-43625 ships.
- **Blocking follow-up** (needs FP-43625 and/or a correct backfill before it can be built well):
  - F-1(1) — base the Promoted indicator on `CompetitionRatingAtStart`, not live rating.
  - F-1(2) — reconcile "Promoted"/"rebalanced" labels.
  - F-4 — conditional archive `UNION` in `GetUserCompetitionHistory` (design in the F-4 Resolution above): union archive only when the range crosses the ~60-day horizon, short-circuit for accounts younger than the horizon. Rides here (not standalone) because archived rows' rating snapshots are backfill-dependent.
- **Non-blocking follow-up** (cosmetic, no dependency): F-2 (Fill double-query), F-3 (BracketCounts column shown for all kinds).
- **Blockers:**
  1. **FP-43625 (MaxWins) deployment** — verified not in prod (0 of 502 recent competitions carry `MaxWins`); no real promotions exist to display yet. F-1(3) already handled inside FP-43625 (owner confirmed done, ships when ready).
  2. **A correct rating-snapshot backfill = FP-43816.** The backfill (`SQL/Releases/R202606-TournamentParticipantRatingBackfill.sql`, r16149) shipped and FP-43816 is Resolved, but the owner is dissatisfied with how it works and intends to **reopen** FP-43816 (not yet reopened as of 2026-07, so it does not currently surface as a blocker). Until the backfill is redone correctly, pre-FP-43816 participant rows carry NULL/incorrect `...AtReg`/`...AtStart`, so archived history and the Promoted indicator render incomplete/misleading rating data. The follow-up links `is blocked by FP-43816`.
