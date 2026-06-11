---
status: resolved
executor: Yevhenii Shust
branch: MFT20260325 @ r16126
jira: https://fishingplanet.atlassian.net/browse/FP-43844
---

# Review: FP-43844 — Auto-propagate Profile.IsCompetitionsBanned to CompetitiveRatingsCurrent.IsBanned

## Summary

WebAdmin "Set Competitions Banned" flips `Profiles.IsCompetitionsBanned` + `CompetitionsBanEndDate` (blocks future tournament registration) but does NOT propagate to `CompetitiveRatingsCurrent.IsBanned`, the flag the finalizer `SaveCompetitiveLeaderboardHistory` reads at Weekly/Monthly/Yearly period close to decide reward eligibility. A profile-banned player therefore still receives prizes at finalization; the gap was patched manually via `leaderboard-ban-sync.sql` (150 rows on 2026-05-18, per FP-43631).

JIRA proposed two approaches: (1, primary) extend `PlayerModel.SetCompetitionsBanned` in WebAdmin to update `CompetitiveRatingsCurrent.IsBanned` directly at ban time; (2, optional) extend the `UpdateLeaderboardsBanned` SP to OR-in `IsCompetitionsBanned`.

## Scope

- **MFT20260325 r16126** — Implemented (executor comment: option #2 route)
  - `UpdateLeaderboardsBanned`: added `@NowUtc` optional param (GETUTCDATE fallback), appended at end for backward compatibility
  - `CompetitiveRatingsCurrent.IsBanned` now factors in `Profiles.IsCompetitionsBanned` + `CompetitionsBanEndDate`; Global/Fish ratings left on base `IsBanned`

> Branch-copy inheritance: NPN20260602 (Code) was copied from MFT20260325:16130; r16126 ≤ 16130, so the fix is already inherited in Code — no explicit merge to Code needed. (Verify in close phase.)

## Investigation Journal

- Intake: executor = Yevhenii Shust (`customfield_11224`), single commit r16126 on MFT (Content branch) per JIRA comment. `svn log -r 16100:HEAD | grep` confirms r16126 is the only FP-43844 commit on MFT — no missing/extra commits.
- WC at r16168 > r16126 → disk shows post-fix state; read files from disk safely.
- Hypothesis "executor skipped primary route #1; loop may not close" — **DISPROVEN by diff**. The change combines both routes: `PlayerModel.SetCompetitionsBanned` now calls `UpdateLeaderboardsBanned(UserId)` (closes the loop at ban time), AND the SP was extended to OR-in `IsCompetitionsBanned` (single source of truth, benefits the other 3 callers). Cleaner than the literal proposal.
- Hypothesis "ordering/visibility bug: SP reads stale `IsCompetitionsBanned`" — **DISPROVEN**. `SetPlayerBanned` (`SqlTournamentProvider`) is a plain `ExecuteNonQuery` (own connection, autocommit, no ambient transaction) and runs to completion *before* `UpdateLeaderboardsBanned`, which opens its own connection. The committed flag is visible (even under NOLOCK) by the time the SP reads it.
- Hypothesis "ban silently not propagated if `CompetitionsBanEndDate` is a past/min date" — **ruled out for normal flow**. `PlayerController.setCompetitionsBanned` rejects `CompetitionsBanEndDate == null` ("Ban EndDate should be specified!"); date comes from a Kendo DateTimePicker. SP condition `CompetitionsBanEndDate IS NULL OR > @NowUtc` then holds. Degenerate past-date input is user error and matches existing tournament-registration-block semantics (pre-existing, not introduced here).
- Effectiveness verified end-to-end: finalizer `SaveCompetitiveLeaderboardHistory` (`SqlLeaderboardsProvider_Competitive`) MERGEs `FROM CompetitiveRatingsCurrent WITH (NOLOCK) WHERE [r].[IsBanned] = 0`; `CalculateCompetitiveLeaderboardChange.sql` filters identically. So `IsBanned = 1` removes the player from placement → no reward. The fix plugs into the actual reward-exclusion path.
- `GetCurrentLeaderboardPeriods` returns all three required periods (Weekly=1 / Monthly=2 / Yearly=3); `now` is shared between period computation and `@NowUtc`, so they are consistent.
- Branch-copy inheritance: r16126 ≤ MFT:16130 copy-source of NPN (Code) → already inherited in Code; no explicit merge to Code (confirm in close phase). Stable/OldStable inheritance/merge need: assess at close per release target.
- Independent `code-reviewer` agent ran an adversarial pre-release pass (each checklist item read-verified): no critical/blocking issue, verdict corroborated. Independently confirmed `UnBanUser` deliberately leaves `IsCompetitionsBanned` intact (competition ban survives a Users-level unban — correct, two independent bans), and re-derived the F-1 deploy-ordering note. Its other note (`SetCompetitionsBanned` returns `false` when affected rows > 1) is pre-existing and unreachable (`Profiles.UserId` is PK → 0/1 rows).

## Findings

### F-1: SP redeploy is a hard dependency of this commit [Info]

**Description:** `SqlLoginProvider.UpdateLeaderboardsBanned` now always passes `@NowUtc`. If the updated `UpdateLeaderboardsBanned` proc (`SQL/Patches/Main/Procedures/`) is not deployed together with the binaries, every caller (WebAdmin competition ban + general `BanUser`/`BanUsers`/`UnBanUser` + role change) throws "procedure has no parameter @NowUtc". The optional `@NowUtc = NULL` default protects old-caller-vs-new-SP, not new-caller-vs-old-SP, so it does not cover this ordering.

**Investigation:** Confirmed the proc lives in the idempotent `Procedures/` DROP+CREATE source set (team convention: redeployed each release, no dated patch). QA validated bans on a build carrying this task, implying the proc is deployed in that pipeline.

**Resolution:** `Accepted` — standard deployment process; flagged as a release-checklist dependency, not a code defect.

### F-2: Freshly-created rows in a new period after ban are not re-synced [Info]

**Description:** `UpdateLeaderboardsBanned` updates only rows existing in the *current* periods at ban time. A `CompetitiveRatingsCurrent` row created later (new period) would default `IsBanned = 0` until the next ban/role/general-ban event re-runs the proc.

**Investigation:** Largely moot in practice — a competition-banned player is blocked from tournament registration (`IsCompetitionsBanned` gate), so they cannot accrue new competitive rating to create such a row. Same point-in-time-sync limitation as the original `leaderboard-ban-sync.sql`; out of this task's stated scope ("update for all current periods").

**Resolution:** `Pre-existing` — noted, not addressed here.

**Discovered by:** skill recon (manual scan)

### F-3: SP NULL-date semantics diverge from canonical `IsCompetitionsBannedNow()` [Medium]

**Description:** The new SP treats `IsCompetitionsBanned = 1` with `CompetitionsBanEndDate IS NULL` as a permanent ban (`... IS NULL OR > @NowUtc`), excluding the player from rewards. The canonical predicate `IsCompetitionsBannedNow()` (`Shared/ObjectModel/Profile/ProfileLogic.cs` — `IsCompetitionsBanned == true && CompetitionsBanEndDate > UtcNow`, where `null > now` is false) treats a NULL end date as *not banned*. It backs ~15 registration/participation gates (`UGCProcess_*`), plus `TournamentEndAdapter` and WebAdmin `SetInfluencer`. `CalculateTopTournamentPlayer.sql` shares the SP's NULL=banned reading. So a NULL-date row would be contradictory: allowed to register/play, yet denied leaderboard rewards. For all non-null dates (incl. expiry) the two readings agree.

**Investigation:** Enumerated every reader of the pair via grep. Canonical method read at `ProfileLogic.cs`. Confirmed the `IS NULL OR` clause originates verbatim in the JIRA task description (option #2) — executor implemented the spec faithfully; the divergence is a spec-vs-system question, not an implementation slip. Reachability: WebAdmin `setCompetitionsBanned` (PlayerController) rejects a null end date, so the normal support flow cannot produce this state; only generic profile-save / legacy / manual data could. Effect errs safe (denies rewards to someone who could still play).

**Resolution:** `Filed → FP-44395` — drop the `CompetitionsBanEndDate IS NULL OR` branch to match `IsCompetitionsBannedNow()` (optionally align `CalculateTopTournamentPlayer`). Dormant and safe-direction, so deferred out of the release rather than churning the SP pre-release.

**Discovered by:** user question during review (NULL-date semantics), verified by skill recon.

## Verdict

Approve. Resolved — JIRA task closed by assignee. Implementation is correct, complete, and end-to-end verified; it closes the reward-leak loop and is architecturally cleaner than the literal proposal. No blocking issues, no release crit. F-1 deployment dependency handled via the Server Release Checklist. F-2 pre-existing unreachable edge. F-3 (NULL-date semantic divergence) deferred to FP-44395 — dormant, safe-direction. Post-release verification subject (auto-sync works, manual `leaderboard-ban-sync.sql` no longer needed) is recorded in the JIRA comment for whoever monitors the deploy.

## Investigation Journal (closure)

- Independent `code-reviewer` agent corroborated "no crit"; verdict unchanged.
- F-3 surfaced from a user question about NULL `CompetitionsBanEndDate`; enumerated all readers, found the SP/`CalculateTopTournamentPlayer` split from the canonical `IsCompetitionsBannedNow()` on the NULL case only. Filed FP-44395 (Story, Scrum Team "Other", Relates → FP-43844) for alignment.
- JIRA comment posted (dry LGTM + NULL-semantics note citing FP-44395 + waiting-for-release verification subject); comment id 124020. No `Merged →` line — r16126 already inherited in NPN (Code) via branch copy, verified by `svn log` on `UpdateLeaderboardsBanned.sql` in the NPN URL.
- Closed `resolved` (JIRA task closed by assignee, removed from Active Reviews). Post-release auto-sync check lives in the JIRA comment; code follow-up tracked in FP-44395.
