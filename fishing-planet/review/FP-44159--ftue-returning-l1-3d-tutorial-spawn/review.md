---
status: resolved
executor: Yuriy Burda
branch: MFT @ r16135, r16136, r16138, r16143, merged to NPN @ r16142, r16144
jira: https://fishingplanet.atlassian.net/browse/FP-44159
---

# Review: FP-44159 — [FTUE][Tutorial] Place a returning level-1 player into the 3D tutorial

## Summary

Bug fix for the FTUE tutorial flow. A player who was level-1 in the **old** game version and did not finish the tutorial there should, after their profile is carried over to the **new** version, be placed in the designed 3D tutorial spawn and restart the tutorial from the beginning. The observed bug: such a returning player is instead dropped onto the local map with all old-version tutorial progress reset.

Enable criteria confirmed by GD (Marina): **level 1 + located on Lone Star**.

The change also touches the one-time profile conversion machinery (since the import-based test flow exercises it) and adds a WebAdmin page to toggle a player's profile conversions done/not-done for testability.

## Scope

- **MFT r16135** — Place returning level-1 LoneStar players into the 3D tutorial spawn
- **MFT r16136** — Mark enabled profile conversions complete on user registration
- **MFT r16138** — Add WebAdmin page to mark a player's profile conversions done/not done
- **MFT r16143** — Log skipped 3D spawn when TutorialInitialSpawnPoint is not configured (review follow-up to F-1 cosmetic nit)

> Merge note: MFT is the Content branch; commits land at r16135-16138 (> NPN base r16131 from MFT:16130) and are therefore NOT yet inherited by the Code branch (NPN20260602). Explicit merge to Code is a closure-phase concern.

## Findings

### F-1: `ResetLevel1SpawnPointConverter.Execute` commits on the config-absent path; log claims 3D placement that didn't happen [Info — Accepted]

**Description:** In `Execute`, `profile.PersistentData = new PersistentData()` runs first, then `InitialSpawnHelper.ApplyFromConfig(profile)` is called with its return value ignored. If the `TutorialInitialSpawnPoint` GlobalVariable is empty/whitespace, `ApplyFromConfig` no-ops (`IsIn3D` stays `false`), yet `Execute` logs `"...placed into 3D spawn"`, returns `true`, and the conversion is committed (no retry). Originally raised as a Medium destructive-wipe-without-retry concern.

**Investigation:** Read `ResetLevel1SpawnPointConverter.cs`, `InitialSpawnHelper.cs`, `ProfileConversionRunner.cs` (confirmed `Changed`/`Unchanged` both commit; only exception → `Failed`/retry), `ProfileAdapter.RunPendingProfileConversions`. Code-reviewer agent independently flagged it and proposed throw-to-retry. **Discussed with executor (Yuriy Burda) — concern withdrawn on the merits:**
- The `PersistentData` reset to template-clean state is the *intended* outcome of the conversion ("Reset to template state"), not collateral damage — a Level-1 Lone Star player has no scene state worth preserving.
- In a no-config environment the default-profile template itself is `IsIn3D=false` (the new-player path `ApplyTutorialSpawnPoint` is gated on the *same* GlobalVariable), so the migrant lands exactly where a brand-new player would under those settings — a consistent, playable Lone Star local-map state.
- The throw-to-retry alternative is *worse* UX: once config appears later, an already-playing player would be reset and yanked into 3D on an ordinary re-login. The conversion model is meant to fire once in the update window, not lurk and trigger on an arbitrary future logon. A single safe no-op is preferable.

**Resolution:** Accepted. Behavioral design is intentional and sound. Residual nit only: the success log line is unconditional, so it can claim "placed into 3D spawn" when `IsIn3D` ended up `false` — mildly misleading when reading conversion logs. Trivial, non-blocking; make the log conditional only if the file is touched again.

**Discovered by:** skill recon (hypothesis 2), confirmed by code-reviewer agent, resolved via executor discussion.

### F-2: WebAdmin `ProfileConversions` POST has no role gate [Low]

**Description:** `PlayerController.ProfileConversions(PlayerConversionsModel)` (POST) carries only the class-level `[Authorize]`, no `[CustomAuthorize(Roles=...)]`. "Mark Not Done" re-queues a conversion that wipes `PersistentData` on the player's next logon, so a basic WebAdmin user can trigger a destructive effect.

**Investigation:** Code-reviewer agent flagged this as a convention violation. **Refuted as a violation** — grep of `PlayerController.cs` shows the majority of mutating `[HttpPost]` actions (`Unlocks`, `PaidUnlocks`, `AbTestStats`, `Achievements`, `Missions`, `Inventory`, `UpdateDurability`, ...) also rely only on class-level `[Authorize]`; `[CustomAuthorize(Roles=...)]` is applied selectively (`Eulas`, `Active`). `ProfileConversions` matches the prevailing pattern.

**Resolution:** Accepted as consistent with siblings. Optional hardening only — gating to `AdvancedPlayers` is defensible given the destructive re-queue, but it's the executor's call and not a deviation from the codebase.

**Discovered by:** code-reviewer agent (recalibrated by skill verification).

### F-3: `int.Parse(ConversionId)` throws `FormatException` on empty submit [Low]

**Description:** `PlayerConversionsModel.ExecuteAction` calls `int.Parse(ConversionId)` before the `Action` switch. `ConversionId` is a hidden field populated by JS on button click; an empty/malformed POST yields an unhandled `FormatException` (500 page) rather than a graceful redirect. No data risk.

**Investigation:** Read the WebAdmin model, view, controller. Trigger requires a submit without clicking a button (direct POST / browser quirk).

**Resolution:** Minor robustness — `int.TryParse` + guard on empty `Action`. Skipped/optional; executor's call.

**Discovered by:** code-reviewer agent.

## Notes

- Verified **no shared-template aliasing**: `GetProfileModel()` returns a shared instance, but the converter copies only value-type/immutable fields (`PondTimeSpent: TimeSpan?`, `CurrentWeather: string`, `LastPinId: int`); `Position`/`Rotation` come from a fresh JSON deserialization in `InitialSpawnHelper.Apply`, not from the template. Confirmed independently by code-reviewer agent.
- Verified **r16135 ↔ r16136 interaction is correct**: `RegisterUser` = brand-new account creation (`CreateProfile`); migrants are existing profiles that hit the logon path (`RunPendingProfileConversions`), so their pending `ResetLevel1SpawnPoint` runs. `MarkAllEnabledConversionsComplete` only stamps genuinely-new accounts, which are born compliant (new LoneStar L1 players get `IsIn3D=true` via `NewPlayerProfileFactory`, so they'd be ineligible anyway).
- Conventions respected: WebAdmin csproj `Compile`+`Content` includes both added; `AdminActionLog` on both admin actions; SQL patch idempotent with `AppliedPatches` guard; unit tests for converter eligibility and spawn helper.

## Verdict (draft — not yet published)

**Approve.** The change is well-structured, tested, and follows project conventions; the core migration logic and the new-account/migrant interaction are correct. F-1 (config-absent commit/no-retry) was discussed with the executor and accepted as an intentional, sound design choice — the single safe no-op is preferable to a retry that could surprise-reset an active player on a later logon. F-2/F-3 are Low and optional. No blocking issues. Residual: one trivial cosmetic log-message nit (F-1), non-blocking.

## Investigation Journal

- Intake from JIRA comment 122889 (Yuriy Burda, 2026-06-03): 3 commits on MFT, executor = Yuriy Burda.
- Executor field (`customfield_11224`) empty — surfaced as hygiene nudge, not blocking.
- Feature is pre-release (QA/test environment per reporter note) — relevant for severity of any data-integrity/backfill findings.
- Hypotheses 2 (template aliasing) and "r16136 breaks the fix" both disproven by source reading (value-type copies; RegisterUser ≠ migrant logon path).
- Spawned code-reviewer agent (Phase 2 Step 6): confirmed F-1, raised F-2/F-3. F-2 verified against `PlayerController` and recalibrated from "convention violation" to "consistent with siblings / optional hardening".
- F-1 discussed with executor: withdrew the behavioral concern after verifying the no-config path leaves the migrant in the same consistent `IsIn3D=false` state a new player gets under those settings, and that retry-on-config-appearance is worse UX than a single safe no-op. Downgraded Medium → Info/Accepted; only a cosmetic log-message nit remains.
- Cross-branch state: executor had already merged r16135-16138 to Code (NPN) at r16142 (verified via `svn log` on the converter file + `mergeinfo --show-revs eligible`). Only the review follow-up r16143 needed merging — done at NPN r16144.
