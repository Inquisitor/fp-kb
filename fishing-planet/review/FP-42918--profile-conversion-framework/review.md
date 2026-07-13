---
status: reopened
executor: Yuriy Burda
branch: MFT @ r15956, r16172, merged to NPN @ r16173
jira: https://fishingplanet.atlassian.net/browse/FP-42918
---

# Review: FP-42918 — Profile conversion framework + LoneStar buoys removal

## Summary

The new Lonestar pond ships with a different terrain, so every player's marker buoys from the old Lonestar would land on invalid positions. They must be removed. The team chose a **profile-conversion framework** rather than a one-shot release migration:

- A conversions registry with per-conversion on/off flags.
- A per-user tracking table so each conversion runs exactly once per profile.
- Conversion executes on profile load; players offline at release are converted in the background ("offline conversion") at any time. When all profiles are converted, the conversion is switched off.

The LoneStar buoys removal is the first conversion built on this framework.

## Scope

### MFT (Content branch)
- **r15956** — Add profile conversion framework for new-release conversion logic when all profiles affected; add conversion for LoneStar buoys removal
  - Conversion registry with enable/disable flags
  - Per-user execution-tracking table (run once per profile)
  - On-profile-load conversion + offline (background) conversion for players offline at release
- **r16172** — Fix offline conversion finalizer parameters and queue deadlocks

### NPN (Code branch)
- **r15956** — inherited via branch copy (NPN forked from MFT @ r16130, and 15956 ≤ 16130)
- **r16173** — Merge of r16172 from MFT

## Findings

### F-1: `GetPendingConversions` missing `WITH(NOLOCK)` on read-only query [Low]

**Description:** `SqlProfileConversionProvider.GetPendingConversions` (introduced in r15956) is a pure read but carries no `WITH(NOLOCK)` on either `dbo.ProfileConversions` or the `dbo.ProfileConversionUserStatus` NOT-EXISTS subquery. The project rule (`<kb>/feedback/sql-nolock.md`) makes NOLOCK mandatory on every table reference in read-only SQL (the only exception is a read whose result drives a SQL mutation — not the case here; the result drives in-memory conversion). The query runs on the hot path — once per master profile load (first op after logon). Runtime impact is negligible (`ProfileConversions` is a few rows; the subquery seeks the `(UserId,ConversionId)` PK), so this is a rule-compliance cleanup, not a correctness bug.

**Investigation:** Read r15956 diff (no NOLOCK on either table originally). Read HEAD `SqlProfileConversionProvider.cs` — still no NOLOCK on `GetPendingConversions`. code-reviewer agent reported the subquery already had `WITH(NOLOCK)`; verified false against HEAD (line 17 has no hint) — finding is fully in FP-42918 scope. Confirmed hot-path via `GetProfileForMaster` → `RunPendingProfileConversions` (code comment: "first op done after logon").

**Resolution:** Recommend one-word fix per table reference (non-blocking). Sibling-added `GetConversionStatuses` in the same file has the same omission — out of FP-42918 scope; fix together if the executor touches the file.

**Discovered by:** code-reviewer agent (NOLOCK omission); scope-corrected and verified by skill.

### F-2: Online-path failure parks a user until manual `--retry` [Info]

**Description:** On the online path, `GetPendingConversions` excludes any user with ANY status row, including `HasError = 1` (documented in the provider comment). A conversion that fails once on profile load is never retried online — only ReleaseTool `--finalize-conversion <id> --retry` re-runs it. For `RemoveLoneStarBuoys` the converter is deterministic in-memory list ops; the only realistic failure surface is the SQL status write, and the impact is cosmetic (stale buoys remain). Accepted design, noted because the framework is reused by other converters that may do I/O.

**Investigation:** Traced `ProfileConversionRunner.ExecuteConversion` (catches converter exceptions → `LogConversionError` → returns `Failed`) and the online loop (skips `CommitConversion` on `Failed`, but the error row itself excludes future online runs).

**Resolution:** Accepted — intentional, with ReleaseTool `--retry` as the escape hatch.

### F-3: Conversion enabled immediately on patch apply — release sequencing [Info]

**Description:** Patch `-004` inserts `RemoveLoneStarBuoys` with `IsEnabled` defaulting to 1, so the conversion is live the moment the patch is applied. The lazy-conversion design decouples it from a release migration, but the removal only makes sense once the new LoneStar terrain is live. If the patch lands before the new-terrain content ships, players logging in during that window lose still-valid buoys.

**Investigation:** Read patches `-003`/`-004`; `DF_ProfileConversions_IsEnabled DEFAULT(1)` + plain INSERT with no `IsEnabled` override.

**Resolution:** Operational note for the release checklist — confirm patch-apply is coordinated with the new-terrain deploy. No code change.

### F-4: Conversion committed even when the profile save was rejected (silent miss) [High]

**Description:** Both paths commit the per-user conversion status **without checking that the profile save actually persisted**.

- Online (`ProfileAdapter.RunPendingProfileConversions`): on `Changed` it calls `peer.SaveProfileWithLog(...)` (returns `void`) then `CommitConversion`. `SaveProfileWithLog` → `LogProfileSave` runs `SetProfile` → `SavePlayerProfile(dto, overwrite:false)`. The stored proc `SavePlayerProfile` (with `@Overwrite=0`) only updates `Profiles` `WHERE Experience + ISNULL(RankExperience,0) <= @Experience + ISNULL(@RankExperience,0)` and the DAL returns `rowsAffected == 2`; a stale (lower-XP) snapshot updates 0 Profiles rows → returns `false`. `LogProfileSave` swallows that `false` when the session is still valid (no throw), so the loop proceeds to `CommitConversion`.
- Offline (`ProfileConversionFinalizer.ConvertUser`): `SavePlayerProfile(updatedDto, false)` return value is ignored outright, then `CommitConversion` runs.

**Why it matters:** When the save is rejected (the DB already holds a newer profile — e.g., the user logged in / gained XP during the offline sweep, or a concurrent session saved), the status row is written as success while the LoneStar buoys are still in the DB. The online path then permanently excludes that user (any status row), and `--retry` cannot recover it (it only re-runs `HasError = 1`). The conversion silently misses an unknown subset of users with no error signal and no easy remediation (would need a manual `ResetConversion`). Probability per user is bounded by a short race window, but over a multi-hour all-profiles sweep it is realistic; the failure is silent and defeats the feature's guarantee.

**Investigation:** Verified the full chain on HEAD: `RunPendingProfileConversions` → `IGenericPeerExtensions.SaveProfileWithLog` → `ProfileAdapter.LogProfileSave` (else-branch swallows `false` when `OnlineCacheAdaper.ValidateSession` is true) → `SetProfile`/`SqlProfileProvider.SavePlayerProfile` (`return ExecuteNonQuery(...) == 2`) → proc `SavePlayerProfile.sql` (XP-monotonicity guard on `@Overwrite=0`). Offline path: `ConvertUser` ignores the `SavePlayerProfile` bool. Discovered by the Codex pass; both the skill recon and the first code-reviewer agent missed it.

**Resolution:** Blocking — gate `CommitConversion` on actual save success. Online needs a save call that surfaces the boolean (or a check that the row persisted) before committing; offline must check the `SavePlayerProfile` return and skip commit on `false` (leaving the user for a later offline iteration / the online path). On rejection, do NOT mark done.

**Discovered by:** Codex pass; verified by skill.

### F-5: Offline updater can overwrite a concurrent same-XP online change [Medium / Pre-existing]

**Description:** The XP-monotonicity guard in `SavePlayerProfile` blocks stale saves only when incoming total XP is strictly lower. A concurrent online change that does NOT raise XP (settings, coin spend, other buoy edits) leaves stored XP equal, so the offline tool's `<=` save passes and overwrites it. This is a property of `SmartOfflineProfileUpdater` (pre-existing, shared by all offline conversions), exposed by the finalizer's load-mutate-save pattern; the pre/post `IsUserOffLine`/`IsUserOffLineEx` checks narrow but don't close the window (the post-check only gates queue removal, not the save).

**Investigation:** Read `SmartOfflineProfileUpdater.ConvertSingleProfile` (offline check before converter; `IsUserOffLineEx` gates only `DeleteProfileFromQueue`) and the proc's `<=` guard.

**Resolution:** Pre-existing — note, not a blocker for this task. Mitigated in practice by the finalizer's per-user full-`Profiles`-row backup (manual restore possible) and the dedicated buoy backup/restore work in FP-44598. Codex framed this as profile data loss; the XP guard prevents the strictly-lower-XP case, so the dominant real consequence is the missed conversion (F-4), not wholesale overwrite.

### F-6: `LogConversionError` MERGE can downgrade a completed row; no HOLDLOCK on first insert [Low]

**Description:** `SqlProfileConversionProvider.LogConversionError` does `MERGE ... WHEN MATCHED THEN UPDATE SET HasError = 1`; if online and offline process the same user concurrently and one errors after the other committed success, the success row is downgraded to `HasError = 1` (false-error reporting; harmless re-run on `--retry`). Separately the `LogConversion`/`LogConversionError` MERGEs lack `HOLDLOCK`, so two concurrent first-time MERGEs on the same `(UserId, ConversionId)` can both take `WHEN NOT MATCHED` and collide on the PK (one throws, gets caught/logged).

**Investigation:** Read both MERGE statements; cross-checked with the dual online/offline execution model. Edge-case (offline queue is an Init-time snapshot, so it can process a user the online path just completed).

**Resolution:** Low — accept or fold into the F-4 fix. If addressed, add `HOLDLOCK` to the MERGE target and guard the error-downgrade against an existing success row.

## Notes

- pondId 119 = active `USA_TX_LoneStar` (verified via DB); pond 2 shares the asset but is inactive/invisible (legacy, inaccessible) — correctly out of scope. Converter target is correct and the only one needed.
- Converter covers all five persisted pond-keyed buoy collections (`Buoys`, `NavBuoys`, `BuoyShareRequests`, `BuoyRecolorCount`, `FreeBuoyRecolorCount`); `AcceptedBuoys`/`DeclinedBuoys`/`SharedBuoys` are `[JsonIgnore]` transient — correctly untouched. Null-safe and idempotent (unit-tested).
- `BuoyRecolorCount`/`FreeBuoyRecolorCount` are "used" counters (`+= 1` per recolor; free compared to `FreeBuoyRecolorPerPond` cap); reset to 0 on buoy removal = restoring the player's recolor allowance on the reterrained pond — intended, mirrors sibling `RemoveDeprecatedBuoysConverter`.
- r16172 deadlock fix (clustered PK on temp table) is correctly targeted: `SmartOfflineProfileUpdater` issues concurrent `DELETE ... WHERE UserId=@UserId` from `Settings.Parallelizm` workers; heap → page-latch deadlocks, clustered PK → seek + rowlock.
- Per-user full-Profiles-row backup in the finalizer is a crude safety net; dedicated buoy backup/restore is handled separately under FP-44598.
- Framework already adopted by sibling converters (`RemoveDeprecatedBuoys`, `ResetLevel1SpawnPoint`) — validates the reusable design.

## Verdict

**Reopen (request changes).** The framework design, completeness, branch-copy inheritance, pondId target, and the r16172 deadlock fix all check out — but F-4 is a real correctness gap: both paths mark a conversion done even when the profile save was rejected by the XP-monotonicity guard, silently leaving buoys in place for an unknown subset of users with no error signal and no `--retry` recovery. The fix is small (gate `CommitConversion` on actual save success). Blocking on F-4; F-1 (NOLOCK) and F-6 (status MERGE) are cheap cleanups worth bundling; F-5 is pre-existing; F-2/F-3 are info/operational.

(Initial verdict was Approve after skill recon + first code-reviewer agent; reversed when the Codex pass surfaced F-4, which was then independently verified through the save chain and the stored proc.)

## Investigation Journal

- Intake: commits taken from JIRA comments at face value (r15956, r16172 on MFT; r16173 merge on NPN). Executor field (`customfield_11224`) = Yuriy Burda, matches commit author — no executor-hygiene warning.
- Branch-copy inheritance (per `_index.md` ancestry): NPN20260602 forked from MFT @ r16130. r15956 ≤ 16130 → already inherited in NPN, no explicit merge expected (and JIRA shows none — consistent). r16172 > 16130 → needs explicit merge, done as r16173. Verified.
- VCS audit (`svn log | grep FP-42918`): MFT shows only r15956, r16172; NPN shows only r16173 — matches intake, no unposted commits.
- WC at r16227 (ahead of all reviewed revs) → disk reads trustworthy for HEAD-verification; no stale-WC fallback needed.
- r16172 `ParametersJson` read appeared inconsistent with r15956 (DTO had no such field, SELECT had 2 columns). HEAD-verification resolved it: a sibling task (framework generalization) added the DTO field + SELECT column + other converters; r16172 only synced the finalizer reader. No compile/index bug.
- code-reviewer agent delegated for independent check. Confirmed recon on all points; surfaced the NOLOCK omission. Agent's detail "subquery already has WITH(NOLOCK)" verified FALSE against HEAD — corrected; finding stays fully in FP-42918 scope. Agent also flagged out-of-scope sibling methods (`GetConversionStatuses`) — noted, not attributed to this task.
- Codex (gpt-5.5) pass run as a second independent reviewer. Surfaced F-4 (commit-after-rejected-save durability gap) — missed by both skill recon and the first agent. Verified the full chain (`LogProfileSave` swallows `false`; proc `SavePlayerProfile` XP-guard) before accepting → verdict reversed Approve → Reopen. Also raised stale-overwrite (F-5) and status-MERGE concurrency (F-6); F-5 down-graded after confirming the XP guard blocks the strictly-lower-XP overwrite and the per-user backup mitigates the rest. Lesson: the swallowed save-result was the load-bearing miss; multi-reviewer cross-check earned its keep here.
