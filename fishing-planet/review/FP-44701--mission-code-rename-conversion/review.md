---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16369, r16370, r16375, merged to NPN20260602 @ r16372, r16376
jira: https://fishingplanet.atlassian.net/browse/FP-44701
---

# FP-44701: [Steam] Mission ID = 435 was completed twice by the same user

## Summary

A player completed mission 435 twice — first in 2024, then again in 2026 after the mission had been updated. Root cause established: the mission restart gate is keyed on `Code`, not `MissionId` (`MissionsManager.Container_AddNewMission` / `Container_Refresh` drop a mission from `MissionsReadyToStart` only when `context.CompletedMissions`, a list of codes, contains `mission.Code`). Mission 435 was renamed `Collect_Item_Shell-n-Creatures` -> `Collect_Item_Creatures`, so past completers were re-issued the mission and earned its reward (item 14480, Creatures Trophy) a second time.

The change has three parts: a profile conversion repairing affected profiles (`FixCreaturesMissionRename`), a WebAdmin confirmation gate before a mission `Code` can be changed, and a rework of the ReleaseTool finalizer to key on conversion `Code` instead of the per-database `ConversionId`. No pre-release conversion run has been executed yet.

## Scope

### MFT20260325
- **r16369** — Add profile conversion for renamed Creatures mission
  - `MissionRenameFix` (`CreditRenamedMission` + `DedupExcessRewardItem`) and its parameters type in `SharedLib/ProfileConversion`
  - `CreaturesMissionRenameConverter` binding mission 435 / item 14480 / trophy-plate interaction, registered in `ProfileConversionRunner`
  - SQL patch `MFT.M.2026.07.23-027 [ProfileConversions]` inserting the conversion row with `IsEnabled = 1`
  - `MissionRenameFixTests` (9 tests)
- **r16370** — Require confirmation to change a mission code in WebAdmin
  - Transient `[Skip] CodeChangeConfirmed` on the `Missions` entity
  - `MissionsModel.ValidateCodeChange` throwing on an unconfirmed `Code` change of an existing mission
  - `onMissionCellSave` grid handler raising a browser confirm and setting the flag
- **r16375** — Finalize profile conversion by Code instead of ConversionId
  - `ProfileConversionFinalizer.Run` looks the conversion up by `Code`, returns bool
  - `--finalize-conversion --code <Code>` CLI shape; `GetOption` also accepts `--name=value`

### NPN20260602 (merged)
- **r16372** — Merge of r16369+r16370
- **r16376** — Merge of r16375

## Findings

### F-1: Double completers keep a duplicated completion entry, so the mission still displays twice [Low]

**Description:** `MissionRenameFix.CreditRenamedMission` returns without touching the completion history as soon as the new code is already in `CompletedMissions` — which is exactly the state of the players the ticket is about. Their profile keeps two `CompletedMissionsInProfile` entries with `MissionId = 435` (one with the old code, one with the new), and both the client mission list and the WebAdmin PlayerCard build one row per entry, so the mission still shows as completed twice. The material half of the damage — the duplicate trophy — is repaired by `DedupExcessRewardItem` (see F-3), so what remains is display only.

**Investigation:**
- Read `MissionRenameFix.CreditRenamedMission` at r16369 (`svn diff -c 16369`): early return on `context.CompletedMissions.Contains(parameters.NewCode)`, before any history mutation. Conclusion: double completers are excluded from the credit half by construction.
- Read `MissionsProfileUtils.StoreCompletedMissionInProfile`: the de-duplication of profile entries is `CompletedMissionsInProfile.RemoveAll(m => m.Code == mission.Code)` — keyed on `Code`, not `MissionId`. Instrument: static source inspection, which is the capable instrument for a claim about how the list is maintained. Conclusion: an old-code entry and a new-code entry for the same `MissionId` coexist permanently.
- Read `MissionsManager_Client.GetMissionsCompleted`: projects `context.CompletedMissionsInProfile` one-to-one into `MissionOnClient`, resolving the mission by `MissionId`, with no grouping — so two entries produce two client-visible completed missions. `WebAdmin/Models/Players/PlayerMissionsModel.cs` builds the PlayerCard list from the same collection; that screen is the one the ticket's STR uses.
- Not established: how many prod profiles are in this state, and the current state of the reported profile `71b8fc2a-7fe8-4f7c-8f17-7b2df2efe759`. The capable instrument is the prod Steam `Main` database; it was not queried in this session (prod access needs explicit approval). The mechanism above rests on code only and does not depend on that count.

**Resolution:** Skipped — cosmetic. Worth knowing at re-test: the ticket's STR opens the PlayerCard and looks for ID 435, which will still be listed twice for the reported player.

**Discovered by:** skill recon.

### F-2: A conversion that no-ops still marks the player done, closing the door before the rename reaches the remaining platforms [Info]

**Description:** The conversion is enabled by the SQL patch (`IsEnabled = 1`) and runs on Master at logon for every player. When it finds nothing to do it still commits a status row, and both the logon path and the ReleaseTool finalizer treat any status row as "handled". On a platform whose content still carries the old mission code, every player who logs in is stamped done for nothing; whoever completes the old edition after that stamp and before the rename arrives will be re-issued the mission when the rename lands, and the conversion will never come back to them. The executor's own JIRA note states this is the situation on Nintendo and Mobile ("new completers will be added until release").

**Investigation:**
- Read `SqlProfileConversionProvider.GetPendingConversions`: `WHERE c.IsEnabled = 1 AND NOT EXISTS (SELECT 1 FROM dbo.ProfileConversionUserStatus s WHERE s.UserId = @UserId AND s.ConversionId = c.ConversionId)` — a status row of any kind permanently removes the conversion from that player's pending set.
- Read `ProfileAdapter.RunPendingProfileConversions`: `CommitConversion` is called for `Unchanged` results too, not only for `Changed`. Conclusion: a no-op run consumes the player's single shot.
- Read `ProfileConversionFinalizer.Run` at r16375 (`svn cat -r 16375`): the user list is `SELECT p.UserId FROM Profiles p WHERE NOT EXISTS (status row ...)`, and `--retry` only widens it to rows with `HasError = 1`. Conclusion: players stamped by the logon path are not reachable by the finalizer.
- Read the patch body in `svn diff -c 16369`: the row is inserted with `IsEnabled = 1`, so the conversion is live from the moment the patch is applied on a platform.
- `IProfileConversionProvider.ResetConversion(userId, conversionId)` exists, so a remedy is available, but nothing in this change schedules it.
- Deploy-regime check: Mobile and Nintendo are still on the Maldives release and have received none of 2026.2 Norway, 2026.3 Leaderboards, 2026.4 FTUE, 2026.5 FPA. The auto-conversion lives in the same code that has not arrived, so the conversion cannot be enabled ahead of the release, and the content rename has not arrived either. The window is therefore not open today.

**Resolution:** Accepted — latent, not live. It would revive only if the mission-435 rename is applied to Mobile/Nintendo content as a separate, later content edit rather than arriving with the release that carries the patch; in that case players completing the old edition inside the gap are unreachable for the conversion, and `ResetConversion` would be needed. Committing the status only on `Changed` would remove the class outright, but that is a change to the FP-42918 framework, not to this ticket.

**Discovered by:** skill recon.

### F-3: The trophy de-duplication runs on every profile, not only on profiles the rename touched [Low]

**Description:** `CreaturesMissionRenameConverter.Execute` calls `DedupExcessRewardItem` unconditionally, independently of whether `CreditRenamedMission` matched anything, trimming item 14480 down to a single copy (counting the one installed in the trophy room). Any player holding two copies for a reason unrelated to the rename — an admin grant, a support compensation — silently loses one.

**Investigation:**
- Read `CreaturesMissionRenameConverter.Execute`: `credited` and `deduped` are computed independently; the dedup does not depend on the credit result.
- Content exposure, `[!] Local` dev copy of `Main`, snapshot 2026-07-28: `InventoryItems` 14480 has `IsUnstockable = 0` (stacks) and `IsActive = 1`; the only `Rewards` row referencing it is 50890 `Collect_Item_Creatures` (mission 435's reward); `LocalShop` and `Auctions` return zero rows for the item. Conclusion: on this snapshot the mission is the sole source, so legitimate double ownership does not arise. Scope caveat: this is the dev copy, not prod, and it binds to the current content.
- Hardcoded installed-copy identifiers verified against content and code: `Missions.ConfigJson` for 3941 contains `@collectionPlate_ghost_13` with state `Visible14` whose `DestroyItemInteraction` consumes `ItemId 14480`, and `MissionInteractiveObject_Server` sets `state.Interaction.Interaction = state.State + "Interaction"`, so `Visible14Interaction` is the right value. Conclusion: the installed-copy detection is correct, not merely plausible.
- Read `Inventory.AddItemCount` and `RaiseInventoryChange`: the change event is a plain delegate invocation with no subscriber offline, so the comment's claim that these are safe outside a live session holds.
- State-coverage walk over `DedupExcessRewardItem` (`excess = held + installed - 1`), which is the half that repairs the actual player-visible damage: one completion with the trophy held (1/0) and one with it placed (0/1) both no-op; two completions with both copies stacked (2/0), with one placed and one held (1/1), or as two separate instances (2/0 across instances) all leave exactly one; two completions with nothing left (0/1) no-ops. Placing both is impossible — the plate's single `Visible14` state carries `DestroyItemInteraction { ItemId: 14480, Count: 1, TimesToComplete: 1 }`. Conclusion: every reachable intermediate state resolves to exactly one trophy.
- `IsRewardItemInstalled` scans `Started` / `Completed` / `Archived` in-profile lists but not `Failed`; mission 3941's `ConfigJson` contains neither `FailCondition` nor `ArchiveCondition`, so its entry cannot land in `FailedMissionsInProfile`. Had it been able to, a player who placed the plate would have had the placed copy go uncounted and their last held trophy removed.

**Resolution:** Accepted — zero exposure on current content; the scope caveat above is the reason it is not lower.

**Discovered by:** skill recon.

### F-4: The comment explaining `[Skip]` states the opposite of what the attribute does [Low]

**Description:** The new comment on `Missions.CodeChangeConfirmed` says "`[Skip]` keeps it off the grid, but it still round-trips in the posted row". `SkipAttribute` in fact excludes the property from the edit model entirely; the attribute that keeps a field in the model while hiding it is `HiddenAttribute`. The round-trip survives for an unrelated reason, so the comment misidentifies what the mechanism rests on.

**Investigation:**
- Read `Shared/DataEditing/Metadata/Attributes.cs`: `HiddenAttribute` is documented as "Unlike `SkipAttribute`, does not exclude field from model, only hides it in UI".
- Read `ColumnDesc.GetColumnsDesc`: `if (skipAttribute != null) continue;` — skipped properties never become a `ColumnDesc`, and `TableEditModel.ConfigureGrid` builds both the grid columns and the Kendo DataSource `.Model(...)` fields from that same `Columns` collection. Conclusion: the property is not a declared model field.
- Read `TableEditModel.Data` (typed `IEnumerable<T>`) and `HomeController.Read`, which serialises those entity instances directly: the property is therefore present in each row's JSON, which is what actually carries it to the client and back. `EntitySerializer.DeserializeFromWebRequest` iterates all public instance properties of the entity, so the posted value binds. Conclusion: the round-trip works, but through JSON serialisation of the entity, not through `[Skip]`.
- Not established by this review: the browser-side behaviour of `e.model.set(...)` on an undeclared field in this Kendo version. The capable instrument is a running WebAdmin; it was not exercised here. Codex reports the grid path works end to end in this version; that report is recorded, not relied on, and the manual check belongs in QA.

**Resolution:** Skipped — reword when the file is next touched; card only.

**Discovered by:** skill recon.

### F-5: The Code-keyed restart gate is left in place, so the next rename repeats the incident [Info]

**Description:** Both halves of the change treat the consequences: the conversion repairs profiles, and the WebAdmin confirm makes the dangerous edit deliberate. The gate itself still keys on `Code`, so renaming any live mission will re-issue it to past completers again, and the repair is per-mission bespoke code. The code acknowledges this — `CreditRenamedMission` is documented as doing "as a MissionId-keyed restart gate would have".

**Investigation:**
- Read `MissionsManager.Container_AddNewMission` and the `Container_Refresh` block: `MissionsReadyToStart.RemoveAll(m => context.CompletedMissions.Contains(m.Code))` and the sibling `StartedMissions` / `ArchivedMissions` / `FailedMissions` checks are all code-keyed; nothing consults `MissionId`.
- Read `MissionsManager.Container_Initialize` "Cleanup missions": started missions whose code no longer matches any mission are cancelled and their in-profile progress removed, which is the second, already-realised consequence of a rename (progress loss for players mid-mission). The conversion does not and cannot restore that — the data was dropped at the affected players' first logon after the rename.

**Resolution:** Missions module backlog, no ticket — renaming a live mission is an exceptional operation and the new WebAdmin confirmation lowers the odds further.

**Discovered by:** skill recon (mechanism confirmed independently by Codex for the progress-loss half).

### F-6: Removing the re-issued active copy leaves `ActiveMissionCode` pointing at it, and nothing clears it [Low]

**Description:** When `CreditRenamedMission` drops the re-issued copy it mutates `StartedMissions` / `StartedMissionsInProfile` directly, bypassing `Core_RemoveStartedMission`, which is the path that normally re-points the active mission. If the re-issued copy was the player's active mission, `context.ActiveMissionCode` keeps its code — which after the credit is also the code of the completed entry — so the completed mission is sent to the client with `IsActiveMission = true` and nothing on the server side clears it. The consequence is confined to one card's label (see the client trace below).

**Investigation:**
- Read `Core_RemoveStartedMission`: on every ordinary removal it runs `if (updateActiveMission && ReferenceEquals(context.ActiveMission, mission))` and activates the next mission via `GetPredefinedMissionOnFailure` / `GetFixedMissionForActivationOnComplete` / `GetNextMissionForActivationOnComplete`. The converter reaches none of this.
- Traced the self-heal path claimed during recon and found it blocked by two independent guards: `Container_Refresh` resolves `activeMission` out of `StartedMissions` (now `null`) and calls `ActivateMission(null, fireEvent: false)`, whose body is gated by `if (!ReferenceEquals(context.ActiveMission, mission))` — on a freshly loaded container `context.ActiveMission` is already `null`, so the guard is true-equal and the body is skipped; and `MissionsContext.ActiveMission`'s setter starts with `if (activeMission == null && value == null) return;`, so even reaching it would not clear `ActiveMissionCode`. My earlier recon conclusion that this self-heals was wrong.
- Read `MissionClientUtils.ConvertToMissionOnClient`: `IsActiveMission = mission.Code == context.ActiveMissionCode`, and `MissionsManager_Client.GetMissionsCompleted` runs that conversion over the completed entries — so the stale code surfaces on the completed mission.
- Recovery path: any explicit activation calls `ActivateMission(mission)` with a non-null mission, which passes both guards and rewrites `ActiveMissionCode`. So the state persists until the player picks an active mission, rather than forever.
- `MissionRenameFixTests` never sets or asserts `ActiveMissionCode`, so the scenario is uncovered; the primary test passes with the defect present.
- Blast-radius trace, server side: `GetActiveMissionId` and `GetActiveMissionForClient` (`MissionsManager_ActiveMission.cs`) both key off `context.ActiveMission`, the runtime object, which is `null` after the converter removed the copy — so the HUD active-mission request and the `ActiveMissionId` field of the missions response return empty rather than the completed mission. Only the string comparison in `MissionClientUtils.ConvertToMissionOnClient` sees the stale code.
- Blast-radius trace, client side (`Win64_MainClient`, Content branch): `MissionItemVH.RefreshState` tests `IsActiveMission` before `IsCompleted`, so the completed card renders with the "active" title and `ItemState.Active`; `MissionsHolder` sorts on `IsActiveMission && !IsCompleted`, so its position in the list stays correct; `MissionsHolder` clears `IsActiveMission` on the previous mission when the player activates another one. Conclusion: the visible effect is one mislabelled card, self-correcting on the next activation.

**Resolution:** Skipped — the stale code never reaches the HUD path, and the one mislabelled card clears as soon as the player activates any mission. A one-line clear of `context.ActiveMissionCode` in `CreditRenamedMission` would remove it if the file is touched again.

**Discovered by:** code-reviewer agent (re-verified independently; it corrects a recon conclusion of mine).

## Notes

- Executor field (`customfield_11224`) was empty at intake and carried the intake nudge; at close it is filled with the commit author, Yuriy Burda.
- Release-step field (`customfield_11323`) held only `DB Migrations` at close; `Online Profile Conversion` (the conversion row is inserted enabled and applies on logon) and `Post-Release Checks` (the executor plans the ReleaseTool catch-up run after the release) were added on the user's decision.
- The WebAdmin gate lives in `MissionsModel.UpdateEntity`, so direct-SQL routes (the super-user Data Pump script generator, manual DB edits) bypass it by construction. Expected for a model-level guard, listed for completeness.
- `MissionRenameFixTests`: 9 passed, 0 failed (`dotnet test --filter FullyQualifiedName~MissionRenameFixTests`, 2026-07-28). No test covers `CreaturesMissionRenameConverter.Execute` itself or a repeated run over an already-converted profile.

## Verdict

Approve. Nothing blocking: the material damage the ticket is about — the extra Creatures Trophy the second completion granted, which the player cannot discard — is repaired by `DedupExcessRewardItem` across every reachable intermediate state (one completion held or placed, two completions stacked, split across instances, or with one already placed), always converging on exactly one trophy. The credit half restores the completion under the new code and clears the re-issued copy, so the mission cannot be earned a third time. The WebAdmin confirmation makes the operation that caused this deliberate rather than accidental, and the ReleaseTool switch from `ConversionId` to the `UNIQUE` `Code` column is the correct key for a per-database identity.

Everything found is Low or Info and resolved without rework: F-1 (duplicate completion entry still displayed) and F-4 (misleading `[Skip]` comment) skipped as cosmetic, F-3 (unconditional dedup) accepted with zero content exposure, F-6 (stale `ActiveMissionCode`) skipped once the client trace showed it costs one mislabelled card that clears on the next activation, F-2 accepted as latent under the current deploy regime, F-5 recorded in the missions module backlog.

Root cause is established, not merely the symptom: the restart gate keys on the mission `Code` string, so the rename put mission 435 back into `MissionsReadyToStart` for everyone who had completed it. That mechanism was read directly in `MissionsManager`, and the reward path was confirmed in content (`Rewards` 50890 -> item 14480).

Verification scope: the fix and the conversion were verified by code and by content data; no conversion pass has been executed anywhere yet (per the executor), so the conversion's behaviour on real profiles is unverified by this review and needs a post-run check. The rename event itself is taken from the ticket and from the current content state (mission 435 now carries the new code, the converter carries the old one) — the WebAdmin audit trail on prod Steam was not inspected.

## Investigation Journal

- VCS audit: `svn log | grep FP-44701` over MFT20260325 and NPN20260602 from r16300 returns exactly the commits named in JIRA (MFT r16369/r16370/r16375, NPN merges r16372/r16376) — no unposted commits, no branch mismatch.
- Working copy is at r16373 and dirty, i.e. behind r16375, so `svn diff -c` / `svn cat -r 16375` were used as the source of truth for the ReleaseTool files instead of disk reads; the same warning was passed to both delegated reviewers. Files added by r16369/r16370 predate the WC revision and were read from disk.
- Branch-copy inheritance check: NPN20260602 was created at r16131 from MFT20260325:16130, so all three commits needed the explicit merges that are present. No further merge target: FTUE and 2026.5 Anniversary both ship from MFT20260325.
- Cross-repo client-mirror check: the diff does not touch `Shared/ObjectModel`, so no client mirror is required. The client checkout was still consulted for F-6, where the severity depended on what the client does with a server-set flag rather than on the server diff alone.
- Hypothesis "the converter leaves a dangling `ActiveMissionCode` after deleting the active copy" was formed during recon and dismissed on a shallow read of `ActivateMission`; the code-reviewer agent raised it independently and re-verification confirmed it — the two null-guards documented in F-6 block the self-heal. Recorded as a recon error, not a delegate red herring.
- Delegated claims re-verified rather than accepted: the agent's hypothesis that the hardcoded trophy-plate identifiers might be wrong is refuted by the content evidence in F-3; its hypothesis about `Failed`/`Archived` old-code states is unreachable for mission 435 specifically (no `FailCondition`, no `ArchiveCondition`) but would matter if `MissionRenameFix` is reused for a mission that has them; its cross-reference to FP-42918 F-4 ("offline path commits status without checking the save result") no longer holds at r16375 — `ProfileConversionFinalizer.ConvertUser` returns `false` and requeues the user when `SavePlayerProfile` rejects the snapshot. The agent could not `svn cat` and read only the diff hunks there.
- Hypothesis "a completed old-edition mission could sit in `ArchivedMissionsInProfile`, where the converter would not find it" — refuted for this mission: archiving runs only over started missions with an `ArchiveCondition` (`Processing_TryArchiveMissions`), and mission 435's `ConfigJson` on the dev copy carries only a `StartCondition`.
- `GetOption` regression audit (r16375): all five call sites at that revision (`--code`, `--ponds`, `--stream`, `--out`, `--users`) take values that cannot collide with the new `--name=value` form.
- Executor-claim sweep: "ConversionId is a per-database IDENTITY ... Code is UNIQUE, so this resolves at most one row" holds — `sys.indexes` on `dbo.ProfileConversions` shows `UQ_ProfileConversions_Code` (unique, single column `Code`) alongside the `ConversionId` primary key. "There was no pre-release conversion executed" is unverified: the capable instrument is `ProfileConversionUserStatus` on each prod database, which was not queried in this session; the dev copy has not even received the patch (its `ProfileConversions` holds only conversions 1-3), so it cannot stand in for prod.
