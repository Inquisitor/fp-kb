---
status: reopened
executor: Yevhenii Shust
branch: MFT @ r16114
jira: https://fishingplanet.atlassian.net/browse/FP-43817
---

# Review: FP-43817 — [Tournaments] Demote tournament-start and other log entries from Warning to Info

## Summary
The Warning log channel is dominated by routine tournament/competition/club lifecycle "start" events that were historically emitted at Warn level, drowning out actual warnings (matchmaking misconfig, empty buckets, swallowed exceptions). Task: demote those routine start events from Warn to Info so the Warning channel carries only true warning-class events, while keeping start traffic queryable from Info.

Per executor's JIRA comment, the change went beyond a literal Warn→Info swap: it is a case-by-case re-classification of log severity (some Warn→Info, some kept Warn, some Warn→Error), message-text improvements, and removal of an "unused" logging callback from `RandomizeCompetitions` / `GenerateRandomCompetitionInstances`.

Release context: ships in the MFT (Content) release scheduled for 2026-06-12.

## Scope
- **MFT r16114** — FP-43817 log-level re-classification in tournament/competition/club areas
  - Warn → Info for successful lifecycle / expected-state logs
  - Kept Warn for suspicious states, invalid transitions, missing-config-with-fallback
  - Warn → Error for actual failures/exceptions
  - Improved a few log message texts
  - Removed unused logging callback passed through `RandomizeCompetitions` / `GenerateRandomCompetitionInstances`

## Investigation Journal
- 2026-06-11: Card created from JIRA intake (Phase 1). Executor = Yevhenii Shust (`customfield_11224`, also commit author per JIRA comment). Branch/commit taken from executor's comment as-is: MFT @ r16114. Phase-2 VCS audit pending.
- 2026-06-11: Release-context flag — task ships in tomorrow's (2026-06-12) MFT Content release. Review priority is crit-risk: a behavioral/signature change that could break runtime, not log-level cosmetics. Primary suspect = the removed logging callback in `RandomizeCompetitions` / `GenerateRandomCompetitionInstances` (the only non-log code change described). Secondary concern = scope expansion beyond ticket (Warn→Error promotions, message edits) on a release-bound change.
- 2026-06-11: Inheritance note (to verify Phase 2) — per `_index.md` ancestry, NPN (Code) was branched from MFT:16130 ≥ r16114, so r16114 should be inherited into Code via branch copy; no explicit Code merge expected. Verify against `svn log` on a touched file before closure. Backport to LBM (Stable) / KNW / IMV (OldStable) likely unnecessary (logging cosmetics, no functional fix) — decide at close.
- 2026-06-11: VCS audit done — single commit r16114 (`svn log | grep`), no unposted commits. WC at r16168 is AHEAD of r16114 (not stale-behind), so disk contains the fix; diff read via `svn diff -c 16114`. 21 files: AsyncProcessor (2), LoadBalancing (3), SharedLib (15), WebAdmin (1).
- 2026-06-11: Recon — change is broader than the ticket ("demote Warn→Info"). It is a case-by-case severity re-classification (Warn→Info, Warn→Error, Error→Warn, Debug→Info), several message-text edits, two control-flow refactors (split combined null/canceled/ended checks into separate branches in `TournamentEndAdapter` + `UserCompetitionStartAdapter`), parameter renames, brace-style normalization, removal of a dead logging callback, and a latent log-content bugfix in `FishRadarManager`.
- 2026-06-11: Crit-risk hypothesis 1 (removed `errorLogger` callback) — VERIFIED SAFE. Read full body of `GenerateRandomCompetitionInstances` (TournamentSchedulingAdapter.cs:573-690): no logger reference anywhere; the only error path `throw`s `InvalidOperationException`. The callback was genuinely dead (executor's "passed through but not used" claim confirmed). Removing it loses no logging.
- 2026-06-11: Crit-risk hypothesis 2 (WebAdmin `err` regression) — VERIFIED NO REGRESSION. `ToolsModel_Competitions.cs` two `RandomizeCompetitions(s => err.Append(s))` sites lost the callback, but `err` was always empty for those paths anyway (callback never fired). The thrown `InvalidOperationException` still propagates to the WebAdmin try/catch which appends `ex.Message`/`StackTrace` to `err` → `Details`, so admin error feedback is preserved.
- 2026-06-11: Latent bugfix verified — `FishRadarManager.CanCalculateBiteRates`: rotation-invalid and boat-speed-invalid branches previously called `Log.Warn(reason)` with `reason == null` (out-param null at entry; real text went only to `host.Log` inline). Now `reason` is assigned before logging, which also corrects `prevNotEnabledReason` state-change tracking in `RefreshFishRadarData`. Genuine improvement; no test added; outside ticket scope.
- 2026-06-11: Conclusion on release safety — all changes are logging level/text + behavior-preserving refactors + one defensive behavior change (new `IsEnded` skip) + verified-safe callback removal. No runtime-breaking change found. QA validated the build. No crit, no rollback warranted.

- 2026-06-11: Independent code-reviewer agent run (adversarial, crit-hunt). Verdict: **CRIT = NO**, safe to ship. All six crit-risk hypotheses independently confirmed safe (dead-callback removal — grep-verified all `RandomizeCompetitions` call sites, none pass an arg; WebAdmin `err` preserved via catch; `IsEnded` guard = correctness improvement, `StartCompetition` would have rejected it downstream anyway; `TournamentEndAdapter` split preserves all three returns; `FishRadarManager` reason fix has no null-deref in `RefreshFishRadarData`; `using static WriteConcern` inert — MongoDB.Driver transitively reachable via `AsyncProcessor->SharedLib->DalAbstraction->Dal.Log->NoSql.Mongo`, members `W1/W2/W3/WMajority/Unacknowledged/Acknowledged` don't collide). Agent elevated F-1 to Med citing latent name-collision risk if a future local var shadows a `WriteConcern` static member; no new findings beyond mine. Convergence with skill recon — no missed crit.

## Findings

### F-1: Accidental `using static MongoDB.Driver.WriteConcern;` in `CompetitionSchedulingJob.cs` [Info]

**Description:** r16114 reorders the usings in `AsyncProcessor/Jobs/CompetitionSchedulingJob.cs` and introduces `using static MongoDB.Driver.WriteConcern;`. Nothing in the file references any `WriteConcern` member — the only added code is a `Log.Info(...)`. This is an accidental IDE auto-import. Harmless (compiles, no runtime effect) but dead.

**Investigation:** Diff inspection + confirmed the only added statement is the `Log.Info` line; no `WriteConcern` usage in the changed hunk.

**Resolution:** Skipped — cosmetic, can be removed in a later cleanup pass. Not blocking for release.

**Discovered by:** skill recon

### F-2: Inconsistent severity classification for "missing config + fallback" [Low]

**Description:** Missing-configuration-with-graceful-fallback is classified two opposite ways. `DailyMissionGenerator` (missing `ExpPerHourSettings` / `SilverPerHourSettings` → falls back to empty `new ...Row()`) is promoted Warn→**Error**, while `TournamentSchedulingAdapter` scheduling failures (`DaysOfWeek`/`DaysOfMonth` null → `yield break`, no tournaments generated) are demoted Error→**Warn** (via `ScheduleTournements(Log.Warn)` in `TournamentSchedulingJob`). By the executor's own stated rule ("keep Warn for missing config that uses fallback"), the DailyMissions case fits Warn; and the scheduling failures, which actually abort generation, are closer to Error. The two similar-severity conditions ended up on opposite channels.

**Investigation:** Diff inspection across `DailyMissionGenerator.cs`, `TournamentSchedulingJob.cs`, `TournamentSchedulingAdapter.cs`.

**Resolution:** Accepted for release (logging only, no functional impact). Recommend a consistency pass on config-fallback severity.

**Discovered by:** skill recon

### F-3: Unrequested behavior change — new `IsEnded` skip in `UserCompetitionStartAdapter.StartCompetitionAsync` [Low]

**Description:** Old guard: `if (reloadedTournamentDto == null || reloadedTournamentDto.IsCanceled)`. New code splits this into three branches and adds a **new** `if (reloadedTournamentDto.IsEnded) { ...; return; }` that did not exist before. So an already-ended competition is now skipped at start time where previously it would have proceeded. Defensive and likely correct, but it is a behavior change bundled into a "log levels" commit, with no test.

**Investigation:** Diff inspection — confirmed old combined condition had no `IsEnded` term; the End-path adapter (`TournamentEndAdapter`) already checked `IsEnded`, so this aligns the Start path with it.

**Resolution:** Accepted — low risk, defensive. Noted as scope expansion.

**Discovered by:** skill recon

### F-4: Latent log-content bug fixed in `FishRadarManager` (positive) [Info]

**Description:** In `CanCalculateBiteRates`, the rotation-invalid and boat-speed-invalid branches previously called `Log.Warn(reason)` where `reason` (an `out` param) was still `null` — the real text went only to `host.Log(...)` via an inline string. The fix assigns `reason` before logging, correcting both the server-side Warn and the `prevNotEnabledReason` state-change detection in `RefreshFishRadarData` (which compares `reason != prevNotEnabledReason`).

**Investigation:** Read `FishRadarManager.cs:125-190` — confirmed `reason` flows out to `RefreshFishRadarData` and gates the "FishRadar: Disabled. Reason: ..." host log and the state-change save.

**Resolution:** Accepted — genuine improvement. Scope creep relative to ticket; no test added.

**Discovered by:** skill recon

### F-5: Committed `TODO` flags a pre-existing potential bug in `LeaderboardsAdapter_Competitive` [Info]

**Description:** r16114 adds `// TODO: Check if this should be 'continue'. Currently one skipped user stops processing all remaining results.` next to a `return false` that fires when `CheckRole` rejects a result. If accurate, one role-skipped user aborts processing of all remaining results in the batch — a pre-existing functional concern, not introduced here. The executor flagged it but left it as an in-code TODO rather than a filed ticket.

**Investigation:** Diff inspection only — underlying return-vs-continue behavior not traced this round (pre-existing, out of this commit's scope).

**Resolution:** Filed -> FP-44396 (Story, High, Tech Debt 2026 Q2 epic, team Other, Fix Version Next Server Hotfix). Verified the bug is real and pre-existing: `UpdateCompetitiveLeaderboards` does `return false` on `!CheckRole(result.Role)`, aborting the whole participant loop instead of skipping the one excluded-role account — every participant after the first excluded account loses their leaderboard increment, and earlier participants are already persisted (partial/inconsistent state). The FP-43817 commit only added the TODO, no behavior change. Recommend `continue`. Not blocking this release.

**Discovered by:** executor's in-code TODO; verified by skill recon (read `LeaderboardsAdapter_Competitive.UpdateCompetitiveLeaderboards`)

### F-6: `CompetitionSchedulingJob` still emits a success-path Warn + adds a duplicate Info [Info]

**Description:** The new `Log.Info("Randomized {N} competitions")` is added inside `if (competitionsCount > 0)`, but the pre-existing `Log.WarnIf(competitionsCount + " competition instances generated.", important: competitionsCount > 0)` is left untouched — so a successful generation (count > 0) still produces a Warning line plus the new Info, partly defeating the ticket's goal for this job and double-logging the same event.

**Investigation:** Diff inspection of `CompetitionSchedulingJob.cs`.

**Resolution:** Accepted for release. Minor; revisit the `WarnIf` on the success path in a cleanup.

**Discovered by:** skill recon

### F-7: Possible duplicate exception log in `FishRadarManager` catch [Info]

**Description:** The refresh catch now calls `Log.Error($"Error refreshing fish radar data. PondId: {host.PondId}", e)` immediately before the existing `host.LogException(e, Log)`. If `host.LogException` also writes the exception to the server `Log`, this duplicates the server-side entry (the new line does add useful `PondId` context).

**Investigation:** Diff inspection; `host.LogException` internals not read this round.

**Resolution:** Accepted — at worst a duplicate line with added context. Not blocking.

**Discovered by:** skill recon

## Verdict (draft — not yet published)

**Approve for release.** No crit, no runtime-breaking change, no rollback warranted. The two highest-risk items (dead-callback removal, WebAdmin `err` feedback) were verified safe. Remaining findings are Info/Low: severity-classification inconsistencies, scope-expansion items (refactors, an added `IsEnded` guard, a latent bugfix), one accidental dead `using`, and an in-code TODO. F-5 (competitive leaderboard `return` vs `continue`) filed as **FP-44396** (High, Tech Debt 2026 Q2, team Other, Next Server Hotfix). Recommend a follow-up cleanup pass (F-1, F-2, F-6); none gate tomorrow's release.

Outcome: task reopened (executor had requested it); F-1..F-7 returned to the executor via JIRA comment for a cleanup pass; FP-44396 filed for the leaderboard bug. Release ships on r16114 as-is. Card stays `reopened` and listed in Active Reviews pending the executor's round-2 cleanup — close via `jira-review-close` once that lands and is verified.
