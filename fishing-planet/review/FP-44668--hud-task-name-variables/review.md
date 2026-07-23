---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16273, merged to NPN20260602 @ r16274
jira: https://fishingplanet.atlassian.net/browse/FP-44668
---

# Review: FP-44668 — Variables in mission/task names don't appear in HUD properly

## Summary

QA (Andrii Smilianets) reported that variables in mission task names (per Mission System Manual, "Variables in task names" section) render incorrectly in the HUD: after catching a fish the rendered variable shows in HUD/menu, but after un-tracking and re-activating the mission the variable disappears from the name. Executor split the report into two issues:

1. `reset` in the mission task definition — content-side, to be removed from the task definition by the reporter (no code change).
2. Updated task name not reflected in HUD — server does not resend the rendered name to the client when the variable value changes. Fixed on both sides: server resends HUD task names when a rendered variable changes; client applies task name updates from mission progress messages.

## Scope

### MFT20260325
- **r16273** — Server: Resend HUD task names when a rendered variable changes

### NPN20260602 (merged)
- **r16274** — Merge of r16273

### CodeBranch
- **r56131** — Client: Apply task name updates from mission progress messages

## Investigation Journal

- VCS audit: `svn log | grep` on MFT r16131:HEAD, NPN r16131:HEAD, client CodeBranch r56000:HEAD — commit set matches JIRA comment exactly (MFT r16273, NPN r16274 merge, CLN r56131). No unposted commits.
- WC freshness: server WC at r16351 ≥ r16273 — disk reads trustworthy.
- Instrumentation coverage: grepped `StoreVariableInProfile` and `MissionsUtils.Update/ResetVariables` call sites — all scalar-variable mutation paths (hints, interactions, AssembleRodCondition, SerialAchievement control objects) flow through the instrumented `UpdateVariables`/`ResetVariables`. SerialAchievement's `uniqueBy` list variable bypasses recording but is not renderable (`variableInTextRegex` matches only `#[bifs]` scalars) — harmless.
- Lifecycle: `ResetIncrementedCounters()` at ProcessMessagesLoop start clears `changedMissionVariables`; resend runs at loop end after FireEvents; peer sends progress messages after the loop returns. Deferred `dependenciesToRaiseAfterProcessing` changes trigger a new loop via ScheduleProcessing → recorded and resent there. No leak, no missed window.
- Delivery channel: `SendMissionProgressMessages` (GameClientPeer_Missions) already resolved `Name` via `ResolveVariablesInText(t.Name, t.Mission, languageId)` before this change — `MissionTaskOnClient.Name` pre-existing, no protocol change. Old client + new server: extra progress rows applied without Name copy (harmless); new client + old server: no resends, behavior as before. Compatible both ways.
- Executor claim "menu re-resolves names on every open" verified: `ConvertToMissionOnClient` resolves task Name/Description on every conversion.
- ActiveMission-only resend scope matches the peer handler filter (`mission == context.ActiveMission` in `MissionsManager_MissionProgress`) — resending for non-active missions would be dropped anyway; HUD shows only the tracked mission.
- SelfMission save/set/restore in resend follows the established pattern used across MissionsManager (needed for `GetProgress(context)` resource lookups in the peer handler); restore-previous is safer than the prevailing set-null.
- Duplicate MissionProgress for the same task (normal progress + resend) deduped by `.Distinct()` in SendMissionProgressMessages.
- Hypothesis (pre-existing, r15975/FP-42531): `ResolveVariablesInText` early-out `!text.Contains("{#")` skips conditional-block resolution for a name containing only `[#var?...]` with no `{#...}` inside — such a name ships raw everywhere (menu and progress messages alike). New `IsVariableReferencedInText` handles that shape correctly, so the resend would fire but deliver the same raw text. Latent content trap, not aggravated by this commit.
- Cross-repo mirror check: client `Assets/Photon Server Networking/ObjectModel/Mission/` copy is stripped (MissionsContext.cs 357 lines vs server 3395; no MissionsManager_*/MissionsUtils/MissionClientUtils) — server processing machinery has no client mirror to update. Client consumption side covered by paired CLN r56131.
- MainClient (FPA client) content check per bulk-merge caveat: r56131 reached MainClient via bulk merge r56304 (range 56016-56153); all three fix fragments verified present in MainClient WC at r56498 (`updatedTasks[i].Name` copy, `UpdateName(t.Name)` call, `UpdateName` method).
- Branch-copy inheritance: r16273 > NPN base r16130 → explicit merge required; r16274 `--summarize` file set identical to r16273.
- HEAD supersede check: MissionClientUtils.cs / MissionsContext.cs / MissionsUtils.cs last touched at r16273; MissionsManager_Processing.cs touched by r16283 (FP-44716, first-pass re-assertion of active-mission tasks) — different mechanism, resend method intact at HEAD.
- Test at HEAD: `dotnet test --filter TaskNameVariableRefreshTests` — 1/1 passed. Discriminating power confirmed statically: without the fix, no path fires MissionProgress for a task with unchanged progress/completion/visibility (r16283's first-pass re-assertion only covers `isFirstIteration`, while the test's variable change happens on a later loop).
- Delegated independent review launched blind (code-reviewer agent + Codex), recon findings not pre-loaded.
- Delegates disagreed on the interaction path: agent claimed all `UpdateVariables` call sites execute inside the processing loop; Codex claimed the client-op interaction path records before the loop and the record is wiped. Resolved by direct trace: `MissionOperationCode.SendInteraction` handler (GameClientPeer_Missions) calls `interactiveObject.Interact` → `BaseMissionInteraction.Execute` → `UpdateVariables` BEFORE `ProcessMissions` → `ProcessMessagesLoop` → `ResetIncrementedCounters()` clears `changedMissionVariables` at loop entry → resend never sees the record. Codex confirmed; agent's clean-claim refuted. Hint/event-driven interactions (`MissionsManager_Events` during FireEvents) and condition/hint `VariableSet` record in-loop and are covered.
- `InteractionVariableSetTests.cs` predates the fix (r15994, FP-42531 era) — no follow-up commit covers the interaction resend gap at HEAD.
- Empty-name guard finding (client): confirmed both ends statically — server serializer uses `NullValueHandling.Ignore` (drops null Name, keeps `""`), so a fully-conditional name resolving to `""` is sent but discarded by the client's `IsNullOrEmpty` guard. Null part of the guard is legitimate (Name-less payloads); only the Empty half is collateral.
- Content-prevalence settled on the local dev-server copy (SQL, `MissionTasks`/`Missions`/`Translations`): variable-rendering task names exist only in missions 3965/3966 (six names, all with static prefixes and `{#` inside blocks); their variables are set by task-condition `VariableSet` (the covered path). Missions with `VariableSet` in mission-level ConfigJson (interactions/hints) — seven, none of which render variables in task names. Hence F-1/F-2/F-3 exposure with current content: zero (latent). Scope caveat: dev-copy snapshot; future content can change exposure without code changes.

## Findings

### F-1: Interaction-driven variable changes are recorded but wiped before resend [Medium]

**Description:** `RecordChangedMissionVariable` is called from `MissionsUtils.UpdateVariables` for interactive-object interactions (`BaseMissionInteraction.Execute`), but the `SendInteraction` operation executes the interaction before `ProcessMissions` invokes `ProcessMessagesLoop`, whose first action (`ResetIncrementedCounters`) clears `changedMissionVariables`. A task name rendering a variable set by an interactive-object interaction therefore still goes stale in the HUD — the exact bug class this fix targets, on a supported content mechanism. The reported repro (task-condition `VariableSet`) is covered; this sibling path is not.

**Investigation:** Traced `SendInteraction` case in `HandleMissionManagerOperation` (GameClientPeer_Missions) → `MissionInteractiveObject.Interact` → `BaseMissionInteraction.Execute` → `UpdateVariables` → record; `ProcessMissions` runs after the switch → `ProcessMessagesLoop` clears at entry (single `ResetIncrementedCounters` call site, verified by grep). In-loop interaction path (`MissionsManager_Events.Execute` during FireEvents) records after the clear and is covered. HEAD check: no follow-up commit touches this (resend method intact at HEAD; `InteractionVariableSetTests.cs` predates the fix, r15994). Content prevalence of interaction-set variables rendered in task names not verified (instrument: prod mission definitions) — mechanism gap confirmed regardless.

**Resolution:** Filed → FP-45162 (single ticket bundling F-1/F-2/F-3; executor confirmed at sync). Severity recalibrated Medium → Low (latent): dev-copy content query showed zero missions that both set variables via interactions and render variables in task names.

**Discovered by:** Codex (agent's contrary clean-claim refuted by manual trace).

### F-2: Client discards a legitimately empty resolved name [Medium]

**Description:** `ClientMissionsManager.UpdateCurrentMissionTasks` applies the incoming name only when `!string.IsNullOrEmpty(updatedTasks[i].Name)`. A task name consisting entirely of conditional blocks (e.g. `[#iCount?Count {#iCount}]`) legitimately resolves to `""` when the variable returns to its default — the server sends `"Name":""` (serializer drops only null, not empty), the client skips it, and the HUD keeps the stale non-empty name. Null must stay guarded (Name-less payloads are dropped by `NullValueHandling.Ignore`); only the empty-string half is collateral.

**Investigation:** Client guard read in both CodeBranch and MainClient copies; server serializer settings checked (`NullValueHandling.Ignore` — agent-verified, settings clone in SerializationHelper); `ResolveVariablesInText` returns `""` for a fully-conditional name at default value (pass-1 replace with empty). Exposure requires fully-conditional task-name content — prevalence unresolved (instrument: prod mission definitions). Pre-fix behavior was identical (names never applied), so this is a partial-fix gap, not a regression.

**Resolution:** Filed → FP-45162 (bundled with F-1; executor confirmed at sync). Severity recalibrated Medium → Low (latent): every variable-rendering task name in dev-copy content has a static prefix — an empty resolved name is unreachable with current data.

**Discovered by:** Codex + code-reviewer agent (independently).

### F-3: `ResolveVariablesInText` never resolves conditional-only names [Low]

**Description:** The early-out `!text.Contains("{#")` skips both resolution passes, so a name containing only `[#var?...]` blocks with no `{#...}` placeholder ships to the client as raw markup — everywhere (menu snapshots and progress messages alike). The new `IsVariableReferencedInText` correctly matches such names, so the resend fires but delivers the same raw text. Pre-existing since r15975 (FP-42531); content using this shape would be visibly broken immediately, so it is a latent trap rather than a live bug.

**Investigation:** Early-out read in `ResolveVariablesInText`; conditional regex `\[(#[bifs][\w\d_]+)\?([^\]]*)\]` matches without `{#`; file history checked — early-out present since r15975, untouched by this commit.

**Resolution:** Filed → FP-45162 — one-line fix (`!text.Contains("{#") && !text.Contains("[#")`) folded into the F-1/F-2 follow-up ticket (executor confirmed at sync).

**Discovered by:** skill recon + Codex (independently).

### F-4: Resend iterates all `mission.Tasks` including invisible/completed [Info]

**Description:** `ResendTaskNamesForChangedVariables` scans every task of the active mission rather than `TasksToCheck`/visible ones; invisible tasks produce progress rows the client cannot match (menu snapshot filters `!t.IsInvisible`), so it no-ops — minor unnecessary traffic, no functional defect.

**Investigation:** Resend loop read; client-side lookup no-op confirmed by agent (`UpdateCurrentMissionTasks` matches by TaskId against the filtered task list).

**Resolution:** Skipped — micro-optimization, no functional defect; fix not worth a commit.

**Discovered by:** code-reviewer agent.

### Unresolved hypotheses (not promoted to findings)

- **HUD geometry on name change (client):** `HudMissionTask.UpdateName` only assigns text; initial creation performs manual wrap/height sizing. A resolved name crossing the resize threshold may clip/overlap until HUD rebuild. Instrument: Unity runtime measurement (prefab/TMP overflow settings decide) — not verifiable from code alone. Raised by Codex. **Routing decision:** dropped — HUD UI is another team's code; missions are QA-tested and visual defects get filed through that channel (per don't-track-other-teams'-bugs rule).
- **Executor claim, issue #1 (out of code scope):** `reset` present in mission 3965 task definition causes the variable to blank after re-track; content-side removal delegated to the reporter (acknowledged 👍 in JIRA). Instrument: prod mission definition — not queried. **Routing decision:** out of review scope, content-side ownership.

## Verdict

**Approve.** The fix is correct for the reported repro: variables set by task-condition `VariableSet` now re-push the rendered names of referencing tasks to the HUD; delivery reuses the pre-existing `MissionTaskOnClient.Name` channel (no protocol change, mixed-version safe both ways). Root cause of issue #2 verified (names were only delivered on organic MissionProgress and the client never applied them); issue #1 is content-side (out of code scope, owner acknowledged). Test discriminates the fix and passes at HEAD. Merges verified: server NPN @ r16274; client CodeBranch r56131 reached MainClient via bulk merge r56304 (content-verified from repo HEAD; merge was unposted in JIRA — noted in the closure comment). Findings F-1/F-2/F-3 are latent (zero exposure in current content, verified by dev-copy DB query), filed as FP-45162 (Tech Debt 2026 Q3); F-4 skipped. Closure comment posted 2026-07-23 (LGTM + MainClient merge note + follow-up reference).
