---
status: resolved
executor: Yuriy Burda
branch: MFT @ r16162, merged to NPN @ r16163
jira: https://fishingplanet.atlassian.net/browse/FP-44275
---

# FP-44275: There is no history of profile updates in Web Admin/Tools/Test Profiles

## Summary

QA reported that the profile-update history (checkpoints shown in Web Admin → Tools → Test Profiles) was missing for newly created users on QA/Test, while older users had full history. Investigation by executor: the in-game reset path always created a checkpoint, but the user-initiated reset (WebAdmin "Reset to default") path did not. The fix adds automatic checkpoint creation to the WebAdmin reset path as well. Flagged as potentially significant for prod.

## Scope

- **MFT r16162** (yuriy.burda) — Server: Checkpoint profile on WebAdmin Reset to default
  - `ProfileHelper.cs`: extract new public `CheckpointProfile(userId, desc, sourceEnvironment="self", sourceUrl="self")`; checkpoint now copies both profile (`CopyFromProfile`) and ext (`CopyFromProfileExt`) data. `ResetProfileKeepingFriends` gains `resetBy` param driving origin string ("in Game" / "by {Author}") and delegates checkpointing to `CheckpointProfile`.
  - `AdminAction.cs`: add enum value `UserResetToDefault`.
  - `ToolsModel_Profile.cs`: WebAdmin reset-to-default path (`ResetProfileById`) now calls `CheckpointProfile` before reset, wrapped in try/catch with `FailureStatus`; logs `UserResetToDefault` (was mislabeled `UserSilverSet`). KeepFriends path passes `resetBy: Author`. Removed dead commented-out HTTP-checkpoint block.
- **NPN r16163** (yuriy.burda) — Merge of r16162 from MFT

> VCS-audited: `svn log | grep FP-44275` on MFT and NPN returns exactly these two commits; no commits missing from JIRA, no branch mismatch.

## Investigation Journal

- Intake: executor field populated (Yuriy Burda); commit list and branches taken from JIRA comment, not yet VCS-audited.
- Branch ancestry: NPN20260602 created from MFT20260325:16130; r16162 > r16130, so explicit merge to NPN (r16163) was required, not inherited — consistent with executor's comment and with r16163 being a "Merged revision(s) 16162" commit.
- **Stale WC caught**: working copy is at r16150 (file last-changed r16058), i.e. BEFORE the fix r16162. Reading `ToolsModel_Profile.cs` from disk showed the pre-fix `ResetProfileById` (no checkpoint, `UserSilverSet` label) and briefly looked like the change was absent/reverted. Resolved by treating `svn diff -c 16162` as ground truth, not the WC file. (Recurrence of the known stale-WC pitfall.)
- Verified `CopyFromProfileExt` (`TestProfileDto.cs`) and `LoadPlayerProfileExt` (`SqlProfileProvider.cs`) pre-exist r16162 — not in the 3-file diff — so reading them from WC is valid. `LoadPlayerProfileExt` can return null (no Profiles row), but `LoadPlayerProfile`/`CopyFromProfile` read the same table and already had the same null exposure → no new asymmetric NPE class.
- Verified executor's claim "WebAdmin reset did not checkpoint": old `ResetProfileById` had only a commented-out HTTP-based checkpoint block and went straight to `ResetProfileToDefault` — confirmed via diff. QA path WebAdmin "Reset to default" = `ResetProfileToDefault` → `ResetProfileById`, which the fix targets.

## Recon observations

- Fix correctly addresses the reported bug: the exact WebAdmin path QA used (`ResetProfileById`) now creates a checkpoint before reset.
- Incidental positive fixes: (a) `ResetProfileById` previously logged `AdminAction.UserSilverSet` for a reset action — clearly a wrong label, now `UserResetToDefault`; (b) reset-to-default is now wrapped in try/catch surfacing `FailureStatus` (was unguarded).
- Behavioral expansion (not called out in commit msg): the in-game reset checkpoint now also captures ProfileExt fields (BiteSystem, CheatRating, bans, IsGold...) via `CopyFromProfileExt` — previously only base profile fields. Benign/positive; worth noting.
- Minor inefficiency: after refactor, `ResetProfileKeepingFriends` loads `profileDto` once for `GetProfileOutOfDto`, then `CheckpointProfile` re-loads `profileDto` (plus player + ext) — one extra DB round-trip per reset. Acceptable (reset is a rare op).
- Design choice: in WebAdmin path, checkpoint failure aborts the reset (throws before `ResetProfileToDefault`, caught → `FailureStatus`, returns false). Reasonable — don't reset without a snapshot.
- code-reviewer agent dispatched (worked from `svn diff`/`svn cat -r 16162`, not stale WC). Raised a Medium NPE on `CopyFromProfileExt(null)`; verified-refuted as a regression (see F-4).

## Findings

### F-1: Fix covers the exact WebAdmin reset path QA used [Info]

**Description:** WebAdmin "Reset to default" = `ToolsModel_Profile.ResetProfileToDefault` → `ResetProfileById`, which the fix modifies to call `CheckpointProfile` before `ResetProfileToDefault`. Checkpoint is taken before the reset, capturing pre-reset state. Directly resolves the reported bug.
**Investigation:** Confirmed call chain in `ToolsModel_Profile.cs` (`ResetProfileToDefault` line ~141 → `ResetProfileById`); diff shows checkpoint inserted at top of the try block, before `ResetProfileToDefault`.
**Resolution:** Accepted.
**Discovered by:** skill recon.

### F-2: Incidental correctness improvements [Info]

**Description:** (a) `ResetProfileById` previously logged `AdminAction.UserSilverSet` for a reset-to-default action — a clear mislabel; now logs the new `UserResetToDefault`. (b) The reset is now wrapped in try/catch surfacing `FailureStatus` (was unguarded). Both are positive side effects of the fix.
**Investigation:** Diff comparison of `ResetProfileById` old vs new.
**Resolution:** Accepted.
**Discovered by:** skill recon.

### F-3: In-game reset checkpoint now also captures ProfileExt fields [Info]

**Description:** Pre-fix in-game checkpoint copied only base profile (`CopyFromProfile`). The shared `CheckpointProfile` now also `CopyFromProfileExt` (BiteSystem, CheatRating, bans, IsGold...). Behavioral expansion not called out in commit msg, but it aligns the in-game checkpoint with every other checkpoint call site (manual/import/restore all already copy ext) — net positive (more complete snapshots).
**Investigation:** Compared `CheckpointProfile` (diff) against `CheckPointMyProfile`/`ImportProfile` in `TestProfilesModel.cs` — all copy both profile + ext.
**Resolution:** Accepted.
**Discovered by:** skill recon.

### F-4: `CopyFromProfileExt`/`CopyFromProfile` lack null guards [Low]

**Description:** `LoadPlayerProfileExt` returns null when no `Profiles` row exists; `CopyFromProfileExt` dereferences its arg without a guard. code-reviewer agent flagged this as a Medium NPE regression introduced on the new-user population the fix targets.
**Investigation:** Verified-refuted as a regression on three grounds: (1) the identical un-guarded `CopyFromProfile`+`CopyFromProfileExt` pattern already exists at 5+ pre-existing call sites (`CheckPointMyProfile`, `CheckPointMyProfileOver`, `ImportProfile`, `RestoreProfile` in `TestProfilesModel.cs`); (2) the targeted new users demonstrably have valid `Profiles` rows — the bug report states their *manual* checkpoints (which run the same `LoadPlayerProfileExt`+`CopyFromProfileExt` path) succeed; (3) `LoadPlayerProfile` and `LoadPlayerProfileExt` resolve to the same player profile row (treated as a pair everywhere — loaded and saved together), and on a truly missing row `CopyFromProfile(null)` throws first, so the ext call adds no new failure class. Not introduced by r16162; not triggerable by the reported scenario.
**Resolution:** Pre-existing — optional one-line null guard (`if (profileExtDto == null) return this;`) is cheap hardening across all call sites; route to profile module backlog if pursued. Not blocking.
**Discovered by:** code-reviewer agent.

### F-5: Double load of `profileDto` in `ResetProfileKeepingFriends` [Low]

**Description:** After the refactor, `ResetProfileKeepingFriends` loads `profileDto` for `GetProfileOutOfDto`, then `CheckpointProfile` re-loads `profileDto` (plus player + ext) — one extra DB round-trip per reset.
**Investigation:** File inspection (diff).
**Resolution:** Skipped — reset is a rare admin/occasional operation; negligible cost.
**Discovered by:** skill recon.

## Verdict

**APPROVE.** Clean, well-scoped 3-file fix that resolves the reported bug on the exact WebAdmin reset-to-default path (`ResetProfileById`), with checkpoint correctly taken before the reset. Incidental improvements: corrected the mislabeled `UserSilverSet` admin-action log and added exception handling around the reset. No blocking issues. The code-reviewer agent's NPE concern (F-4) was verified as a pre-existing, non-regression robustness gap consistent with the codebase convention, not triggerable by the targeted scenario. Merge to NPN (r16163) was required (r16162 > NPN base r16130) and is present.
