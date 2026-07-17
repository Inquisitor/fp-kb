---
status: resolved
executor: Yevhenii Shust
branch: NPN20260602 @ r16312,16313,16317 + r16325, merged to MFT20260325 @ r16329, MainClient @ r56438
jira: https://fishingplanet.atlassian.net/browse/FP-44889
---

# Review: FP-44889 — Tournament trophy counters (TourWon/Tour2nd/Tour3rd)

## Summary

The client (FP-42522) displays tournament trophy cups in the Player Profile from
`StatsCounterType.TourWon`/`Tour2nd`/`Tour3rd` counters (added in NPN r16270). Prize places
were recorded per-tournament in `TournamentIndividualResults` for all kinds, but the cumulative
counters were never incremented for Sport finals. The task adds:

1. **Counting** — on finalization of a Sport tournament final stage, increment
   `TourWon`/`Tour2nd`/`Tour3rd` for places 1/2/3 (`GameClientPeer_Tournaments`, next to the
   existing Comp*-counter logic).
2. **Backfill** — conversion of existing users from historical results
   (`TournamentIndividualResults` + `ArchiveTournamentIndividualResults`, KindId=Sport,
   StageTypeId=Final, Place 1..3), precedent: ReleaseTool `Tournaments/StatsUpdater.UpdateCompStats`.

## Scope

Audited against `svn log | grep FP-44889` on NPN20260602, MFT20260325 and client CodeBranch —
matches the JIRA comment exactly; no unlisted commits. Merge to MFT (server) and MainClient
(client) is REQUIRED — the task is on the FPA team and ships with the MFT release
"2026.5 Anniversary" (2026-07-27); blocked on FP-42522's r16270 (enum-key addition) getting its
own review and merge into MFT first.

### NPN20260602
- **r16312** — `[Stats]` Relocate TourWon/Tour2nd/Tour3rd to end of StatsCounterType enum
- **r16313** — `[Tournaments] [Stats]` Count TourWon/Tour2nd/Tour3rd on Sport tournament final results
  - Counting block in `GameClientPeer_Tournaments.ProcessTournamentResult` (Sport + Final stage)
  - `PlayerStats.UpdateTournamentPlaceCounters(int? place)` helper + unit tests
- **r16317** — `[Tournaments] [ProfileConversion]` Backfill TourWon/Tour2nd/Tour3rd from historical Sport finals
  - `SqlTournamentProvider.GetSportTournamentFinalPlaceCounts` (active+archive union, dedup) + DB tests
  - `BackfillTournamentTrophiesConverter` registered as ProfileConversion `BackfillTournamentTrophies`
  - `PlayerStats.RestoreTournamentPlaceCounters` — raise-only restore + unit tests
  - SQL patch `NPN.M.2026.07.15-025 [ProfileConversions] [Data].sql` (idempotent)

### Unity_Fishing_CodeBranch
- **r56379** — mirror of the StatsCounterType enum relocation

### Review-fix commits (reviewer)
- **NPN r16325** — `[Tournaments] [ProfileConversion]` Drop NOLOCK from the trophy backfill query (F-2)

### Cross-branch merges (task ships from MFT / FPA)
- **MFT r16329** — server merge of NPN r16312,16313,16317,16325
- **MainClient r56438** — client merge of CodeBranch r56379 (enum relocation mirror), recorded at branch root
- Prerequisite FP-42522 (r16270 / client r56112) reviewed+merged separately first (user, parallel session)

## Investigation Journal

- Executor field (`customfield_11224`) empty in JIRA; executor identified as Yevhenii Shust
  from the commit comment (detect-only, not auto-filled).
- Open item in JIRA (comment to GD, 2026-07-15): tournament registration snapshots
  `LifetimeGoldAtReg`/`LifetimeSilverAtReg`/`LifetimeBronzeAtReg` are initialized from
  `CompWon`/`Comp2nd`/`Comp3rd` for every tournament kind; what to do with the new Tour*
  counters is undecided (sum, Sport-only init, or a separate client parameter). Relevant
  context for the review — interaction of new counters with registration-time snapshot.
- NPN WC at r16307 (< r16312) and dirty with unrelated ChatServer edits → stale-WC fallback:
  review conducted from `svn diff -c` / `svn cat -r` snapshots; warning propagated to delegated
  reviewers. (WC was updated to r16324 mid-review by the reviewer — disk trustworthy from that
  point; the fallback reads remain valid as they came from the repo.)
- Hypothesis "fixVersion 2026.5 Anniversary vs Code-branch commit is a mismatch" — first judged
  disproven from sibling NPN tasks (FP-44994, FP-44680 carry the same fixVersion), then
  CORRECTED by the reviewer: the task is on the FPA team and must ship via MFT (Content) —
  merge to MFT/MainClient required. Lesson: fixVersion-of-siblings is a weak proxy for the
  branch↔release mapping; confirm with the user / team-release mapping instead.
- Merge attempt stopped by the reviewer before commit: r16270 (FP-42522, enum-key addition) is
  a hard dependency of the MFT merge, but it belongs to another task — bundling it inside this
  task's merge would bypass that task's review. FP-42522 gets its own review + merge first (user
  runs it in a parallel session); the applied-but-uncommitted r16270 merge in the MFT WC is to
  be reverted. FP-44889 merge set once unblocked: server r16312,16313,16317,16325 → MFT; client
  r56379 → MainClient (client mirror of r16270 = r56112 is already present in MainClient,
  mid-enum).
- Persistence check: `PlayerStats.GenericStats` is `IDictionary<StatsCounterType, StatsCounter>`;
  Json.NET serializes enum dictionary keys by NAME → profile StatsJson immune to enum reorder;
  the r16312 relocation matters for numeric/wire surfaces and server-client consistency only.
  Pre-relocation shifted values (r16270..r16311) existed only on TEST2 (pre-release).
- Enum tail comparison: normalized `StatsCounterType` bodies at server r16317 vs client r56379
  are identical (member order and names).
- SQL literals verified: `TournamentKinds.Sport = 1`, `StageType.Final = 3` (Photon.Interfaces /
  TournamentSerieInstance enums) — `t.KindId = 1 AND t.StageTypeId = 3` correct.
- `RestoreCounter` sets absolute value, `UpdateCounter` default branch increments →
  `RaiseCounterIfHigher` raise-only semantics verified against PlayerStats at r16317.
- Conversion execution point: `ProfileAdapter.GetProfileForMaster` →
  `RunPendingProfileConversions` (master profile load). Queued tournament final results are
  processed later by `GameClientPeer.ProcessTournamentResult` (game peer, chat-message
  delivery, `MarkRewardReceived`) → a result finalized pre-conversion but delivered
  post-conversion is counted twice (backfill + live increment); raise-only does not protect
  against a subsequent increment.
- Precedent comparison (`ReleaseTool StatsUpdater.GetWinsCount`): precedent has NO NOLOCK, no
  active/archive dedup, no StageTypeId filter (Competitions are single-stage). New query adds
  NOLOCK + dedup + stage filter. NOLOCK on a read that drives a profile mutation is the
  exception case of the team NOLOCK rule; conversion commits as done even when Unchanged, so an
  under-read during a concurrent archivation window would be permanent.
- Delegated independent review launched (code-reviewer agent + Codex, blind — no recon findings
  pre-shared), stale-WC warning included in both prompts. First Codex run died on model
  capacity; retried on a lower tier successfully.
- Codex (blind) returned: NOLOCK-on-backfill-read (Medium; converges with recon, adds
  dirty-read-of-uncommitted-Place scenario), two test-gap Lows (no dispatch-condition test, no
  converter/lifecycle test). Codex marked live/backfill interaction "clean" — disagrees with
  recon double-count window; its argument (chat message-ID dedup + raise-only) does not cover
  the backfill-plus-first-delivery interleaving.
- Disagreement resolved by code: `OutgoingChatServerPeer` routes `ChatRequests.TournamentResult`
  (persistent chat-message delivery, same machinery as gifts/product delivery) →
  `ProcessTournamentResult`; offline players receive queued results on next session, strictly
  after master-login conversions → double-count window confirmed against Codex's "clean".
- code-reviewer agent (blind) returned: no high-confidence defects. Deep-verified enum
  relocation safety (`StatsCounter.Type`, `CounterCondition.CounterType`,
  `AchievementStageConfig.CounterType` all `[JsonConverter(StringEnumConverter)]` — name-based
  matching; `GenericStats` keys serialize by name). Narrowed the NOLOCK risk: archival batch is
  a single transaction (`PerformTournamentArchivation`, UGC.M.2019.06.27-407.sql), so
  both-visible is handled by dedup and rollback leaves the live row intact. Flagged NOLOCK
  policy tension, missing `RaiseCheckAchivement` on the restore path, and the gating test gap.
- Both delegates judged the live/backfill interaction safe on raise-only grounds; both missed
  the backfill-plus-first-delivery interleaving (raise-only protects the restore side, not a
  subsequent live increment). F-1 upheld against both by the code chain above.
- Course change: F-2 resolution switched from "return to executor" to fixed-by-reviewer at the
  user's call. NOLOCK dropped in the NPN WC; verification — Sql.MsSql.Tests builds clean, the
  modified query runs clean on local Main, the method's DB tests are blocked locally by a
  pre-existing fixture issue (`FK_Tournaments_Images`; identical failure on a pre-r16317 test).
- Merges performed (server merges only because MFT hosts the FPA/2026.5 release and the task
  was routed there): server r16312,16313,16317,16325 → MFT r16329; client r56379 → MainClient
  r56438. LoadBalancing.sln rebuilt clean in MFT post-merge; server/client enum bodies compared
  identical after both merges.
- Client merge hygiene: file-target merge of r56379 tree-conflicted (svn quirk); directory-level
  merge would have created NEW subtree mergeinfo on `Stats`; used root-level
  `--allow-mixed-revisions` so mergeinfo lands only at MainClient root (extends the existing
  consolidated CodeBranch list). A no-op mergeinfo touch on `Assets\Scripts` was reverted before
  commit. Pre-existing stale `Assets\Scripts` subtree mergeinfo (origin CLN r17041, sk,
  2018-10-09) logged to `<kb>/fishing-planet/client/backlog.md` — separate cleanup, out of scope.
- F-4 refuted mid-discussion by the user's domain note (login-time achievement re-trigger);
  verified: `CheckAllAchivements()` → `EnumerateCounters()` yields `GenericStats.Values`,
  called from the travel/game-start path and on achievement-cache refresh.

## Findings

### F-1: Backfill + post-conversion delivery of a pending result double-counts that tournament [Low]

**Description:** A Sport final result finalized before the player's conversion runs but
delivered after it is counted twice: `GetSportTournamentFinalPlaceCounts` already sees the
`TournamentIndividualResults` row (written at finalization), and the queued
`ChatRequests.TournamentResult` message later drives `ProcessTournamentResult` →
`UpdateTournamentPlaceCounters` → `+1` on top of the restored total. Raise-only restore does not
protect against a subsequent increment. Permanent cosmetic over-count of one cup; cohort is
narrow (top-3 finishers of pre-release-finalized Sport finals whose result message is delivered
after their first post-release login conversion; the `--finalize-conversion` offline sweep widens
it slightly).

**Investigation:** Conversion execution point verified (`ProfileAdapter.GetProfileForMaster` →
`RunPendingProfileConversions`, master login); delivery path verified
(`OutgoingChatServerPeer` → `ProcessTournamentResult`, persistent queue, offline delivery on
next session); result row written at finalization (before delivery, `MarkRewardReceived` happens
at delivery). Both delegates initially judged the interaction safe (raise-only); refuted by the
interleaving above. Alternative design (filter backfill by delivered results) has worse failure
modes: rows whose queued message expired would then be counted by neither path — permanent
under-count; archive rows' delivered-flag reliability unknown.

**Resolution:** Accepted — precedent parity (the Comp* backfill had the same window), cosmetic
counter, exact-fix alternatives are worse or disproportionate.

**Discovered by:** skill recon (upheld against both delegates).

### F-2: NOLOCK on the backfill read that drives a permanent one-shot profile mutation [Low]

**Description:** `SqlTournamentProvider.GetSportTournamentFinalPlaceCounts` uses `WITH (NOLOCK)`
on all four table references, but its result feeds `RestoreTournamentPlaceCounters` and the
conversion then commits as done even when `Unchanged` — the exception case of the team NOLOCK
rule (read that drives a data mutation). Residual risk after the agent's archival-transaction
analysis: NOLOCK allocation-scan row skips on the live table during concurrent writes
(permanent under-count), dirty read of an uncommitted finalization that rolls back (phantom cup).
Both rare; both permanent due to one-shot conversion semantics. Precedent
`StatsUpdater.GetWinsCount` uses no NOLOCK.

**Investigation:** Independently raised by Codex (Medium, dirty-read scenario) and the
code-reviewer agent (policy tension, could not construct concrete corruption); recon raised the
under-count-during-archivation variant, narrowed by the agent's single-transaction archival
evidence (UGC.M.2019.06.27-407.sql). Team rule (sql-nolock) explicitly exempts mutation-driving
reads from the NOLOCK mandate. One-line fix; release is 2026-07-27.

**Resolution:** Fixed by reviewer — NOLOCK dropped from all four table references of
`GetSportTournamentFinalPlaceCounts`, committed as NPN r16325. Verified: project builds;
the modified query executes cleanly against local Main. The method's four DB tests fail on the
local DB in test arrange (`FK_Tournaments_Images` — AutoFixture image IDs missing from
`dbo.Images`) — pre-existing environmental issue, reproduced identically on a pre-r16317 test
(`RegisterForTournament_populates_AtReg...`), unrelated to the change.

**Discovered by:** skill recon + Codex + code-reviewer agent (independent convergence).

### F-3: No test pins the Sport/Final gating or the converter lifecycle [Low]

**Description:** r16313 tests only the extracted `UpdateTournamentPlaceCounters` helper; the
`KindId == Sport && StageTypeId == Final` dispatch condition inside `ProcessTournamentResult` is
untested (a regression there passes all new tests). r16317 tests the DAL query and the
raise-only helper but not `BackfillTournamentTrophiesConverter.Execute` or its runner
registration.

**Investigation:** Raised by Codex (two separate Lows); agent noted the gating gap as
pre-existing-parity (Comp* gating equally untested; `GameClientPeer` is not unit-testable in
this codebase). Converter is a thin delegation over tested pieces.

**Resolution:** Skipped — consistent with codebase test architecture (`GameClientPeer` is not
unit-testable, Comp* gating equally untested); the meaningful logic (dedup, raise-only, filters)
is covered at helper/DAL level.

**Discovered by:** Codex (+ code-reviewer agent for the gating half).

### F-4: Backfill restore path does not raise achievement checks [Info — refuted]

**Description:** `RestoreTournamentPlaceCounters` → `RestoreCounter` never calls
`RaiseCheckAchivement`; the agent hypothesized backfilled players would get achievement credit
(if a Tour* achievement ever exists) only on their next live increment. Refuted: the codebase
re-triggers achievement checks over all counters on every game entry.

**Investigation:** Raised by code-reviewer agent (speculative). Refuted after the reviewer's
domain note — `GameClientPeer_Game.CheckAllAchivements()` iterates
`Profile.Stats.EnumerateCounters()` (which yields `GenericStats.Values`, i.e. Tour* counters)
and calls `CheckForAchivement` per counter; invoked from the travel/game-start path
(`GameClientPeer_Travel`) and on achievement-cache refresh for all online peers. Backfilled
values are therefore picked up at the next game entry regardless of the restore path.

**Resolution:** Refuted, no issue — login-time `CheckAllAchivements()` re-trigger covers
restored counters; additionally no Tour* achievement exists today.

**Discovered by:** code-reviewer agent; refuted by reviewer's domain knowledge + code check.

## Verdict

**Approved** (LGTM posted, comment 130657). Release-step field set: DB Migrations, Online
Profile Conversion, Post-Release Checks.

Approve; the one non-blocking cleanup (F-2) was fixed by the reviewer as r16325 and shipped with
the merge rather than returned to the executor. The implementation matches the
requirement (Sport+Final gating next to the Comp* logic; raise-only backfill over active+archive
with dedup; exact server/client enum mirror; idempotent conversion registration patch) and
improves on the `UpdateCompStats` precedent (dedup, stage filter, per-profile conversion instead
of a one-off tool run). Findings: F-1 double-count window Accepted (precedent parity, cosmetic),
F-2 NOLOCK on the mutation-driving backfill read — fixed by the reviewer during the review
(NPN r16325), F-3 test gaps Skipped, F-4 refuted (login-time `CheckAllAchivements()` covers
restored counters). Merges pending: server r16312,16313,16317,16325 → MFT and client r56379 →
MainClient, blocked on FP-42522 (r16270) review + merge first.

## Notes

- Pre-relocation shifted enum values (r16270..r16311) were only ever live on TEST2 —
  pre-release, no data surface to remediate.
- Executor-tracked open item with GD (registration-time `Lifetime*AtReg` snapshot semantics for
  the new counters) predates the review and stays with the task/JIRA thread — not a review
  finding.
