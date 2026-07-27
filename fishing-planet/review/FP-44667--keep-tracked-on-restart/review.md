---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16271, merged to NPN20260602 @ r16272
jira: https://fishingplanet.atlassian.net/browse/FP-44667
---

# Review: FP-44667 — ANNIVERSARY 2026: Server - Mission Auto-Tracking After Failure

## Summary

Event missions (e.g. `Anniversary8_Falcon`) that fail on a time-window condition must fail, restart, and be re-tracked automatically. Unlike the existing "auto active" behaviour, the re-track must happen only when the mission tracked before the failure is the same mission. Implemented as a `KeepTrackedOnRestart` mission flag, editable in WebAdmin, column default `0`.

## Scope

- **MFT20260325 r16271** — Add `KeepTrackedOnRestart` flag to re-track after fail-restart
  - New `KeepTrackedOnRestart` column on `Missions` (patch `MFT.M.2026.07.07-026`, `bit NOT NULL DEFAULT(0)`)
  - Field threaded through `MissionDto` → `MissionCache` → `Mission`, plus WebAdmin `Entities.Missions`
  - `Core_StartMission` activation block restructured: new `KeepTrackedOnRestart` branch precedes the existing `IsAutoActive` branch
  - `[JsonProperty]` removed from `IsAutoActive`, `IsMultiStart`, `ShowHintsWhenNotActive` in `Mission`
  - Three tests added to `FailedMissionRestartTests`
- **NPN20260602 r16272** — Merge from MFT20260325 r16271

## Findings

### F-1: `KeepTrackedOnRestart` only reclaims tracking when fail and restart land in the same `ProcessMessagesLoop` call [Medium]

**Description:** `Core_StartMission` decides re-tracking by `ReferenceEquals(prevActiveMission, mission)`, but `prevActiveMission` is a snapshot of `context.ActiveMission` taken once per `ProcessMessagesLoop` invocation, before the `while` loop. `Api_FailMission` → `Core_RemoveStartedMission` reassigns `context.ActiveMission` to a replacement (or `null`) the moment the mission fails, so "who was tracked at fail time" survives nowhere else. The flag therefore misses on three routes: (a) timed failures, because `Processing_TryFailTimedMissions` runs before the snapshot is taken; (b) delayed restarts, where `Processing_RemoveFailedMissionsAfterMinutes` restarts the mission in a later invocation; (c) a `StartCondition` that is false at fail time, deferring the restart to a later cycle. Neither the flag name nor the branch expresses this same-cycle constraint, so content that trips any route fails silently.

**Investigation:**
- Read the ordering in `MissionsManager_Processing.ProcessMessagesLoop`: `Processing_TryFailTimedMissions` executes, then `context.CaptureDependencies()`, then `var prevActiveMission = context.ActiveMission`, then the `while` loop containing `Processing_TryFailMissions` and `ProcessStartMissionsAndForwardMissions(prevActiveMission)`. Conclusion: condition-driven failures occur after the snapshot, timed failures before it.
- Traced `Api_FailMission` (`MissionsManager_Fail.cs`) → `Core_RemoveStartedMission` (`MissionsManager_Start.cs`): when the failing mission is the active one, the method picks a successor via `GetPredefinedMissionOnFailure` / `GetFixedMissionForActivationOnComplete` / `GetNextMissionForActivationOnComplete` and calls `ActivateMission`. Conclusion: `context.ActiveMission` no longer identifies the pre-fail mission after the fail.
- Read both fail loops: each calls `Api_RemoveFailedMission` only when `RestartFailedMissionAfterMinutes == 0`; otherwise the restart is deferred to `Processing_RemoveFailedMissionsAfterMinutes` in `MissionsManager_Timed.cs`, which runs from `Processing_EnsureTimedMissions` in a later invocation. Conclusion: route (b) confirmed.
- Read `Api_RemoveFailedMission`: the mission re-enters `MissionsReadyToStart` only when `CanStartAndNotGlobal()` holds, and `Processing_TryStartMissions` starts it only when `StartConditionWrapper` evaluates true. Conclusion: route (c) confirmed.
- `ReferenceEquals` itself checked and found sound: `Api_RemoveFailedMission` re-adds the same `Mission` instance, so identity holds on the covered route.
- Content exposure queried on `[F2P] DEV` (`Main.dbo.Missions`, ten rows with `KeepTrackedOnRestart = 1`): all carry `TimeToComplete = NULL`, `RestartFailedMissionAfterMinutes: 0` and `FailCondition: { type: 'TaskCompletedCondition' }` → routes (a) and (b) have zero current exposure. All carry `StartCondition: ' (it.Level >= 2 and !it.IsCatch) '`, and the `Task_1` fail watcher of mission 3957 fires on `TimeOfDayCondition Hour:5 Range:15 Negate:true` / `it.PondId==0` / `EndOfDayCondition` → route (c) is reachable when the window closes while the player is playing a fish. Caveat: this binds to the current content snapshot.
- Mitigation checked in `GetNextMissionForActivationOnStart`: its first rule returns `newMission` when `activeMission == null`, and all ten missions also set `IsAutoActive = 1`, so a missed branch still re-tracks whenever the fail left no replacement. Degradation is soft — tracking is not restored, progress is not lost.

**Resolution:** `Filed → FP-45235` — fix by recording the mission tracked at fail time (on the mission or its profile entry) instead of relying on the loop-wide snapshot; not blocking, since the shipping content only uses the working route.

**Discovered by:** skill recon | code-reviewer agent | Codex (independently)

### F-2: A same-request restart can override a tracking change the player just made [Low]

**Description:** `SetActiveMission` only writes `context.ActiveMissionCode`; `context.ActiveMission` is updated later, inside the `while` loop, when the `ActiveMissionCode` dependency is handled. Since `prevActiveMission` is captured before the loop, a request in which the player switches tracking from A to B while A's `FailCondition` becomes true leaves `prevActiveMission == A`; A fails, restarts, passes the new identity check and reclaims tracking from B — undoing an explicit player action and contradicting the requirement that the mission be the tracked one at fail time.

**Investigation:**
- Read `SetActiveMission` (both overloads) in `MissionsManager_ActiveMission.cs`: they set `context.DisableMissionActivation = false` and `context.ActiveMissionCode`, and never touch `context.ActiveMission`.
- Read the in-loop handler in `ProcessMessagesLoop`: `if (context.CapturedDependencies.Contains("ActiveMissionCode")) { … ActivateMission(activeMission, activeMissionCodeChanged: true); }` executes after the snapshot and before `Processing_TryFailMissions` and `ProcessStartMissionsAndForwardMissions`. Conclusion: the ordering required by the scenario holds.
- Compared against pre-change behaviour using the diff: the old code reached `GetNextMissionForActivationOnStart(prevActive: A, activeMission: B, newMission: A)`, where `activeMission != null` and no `ActivateAfter`/`ActivateAfterFail` is configured for this content, so it returned `B`. Conclusion: this is a behaviour change introduced by the commit, not pre-existing.
- Reachability for live content: mission 3957's fail watcher includes `it.PondId==0` (player leaves the pond), which can plausibly coincide with a tracking switch in the same request. Not reproduced empirically.

**Resolution:** `Filed → FP-45235` — same root cause and same fix as F-1; carried as a second symptom on that task.

**Discovered by:** Codex

### F-3: `[JsonProperty]` removed from three unrelated fields, outside the commit's stated scope [Info]

**Description:** Alongside the new field, `[JsonProperty]` was dropped from `IsAutoActive`, `IsMultiStart` and `ShowHintsWhenNotActive` in `Mission`. The class is `[JsonObject(MemberSerialization.OptIn)]`, so the attribute is load-bearing in principle, and the change is not mentioned in the commit message. Verified to be functionally neutral.

**Investigation:**
- Confirmed the serialization mode by reading the class attribute: `[JsonObject(MemberSerialization.OptIn)]` on `Mission`.
- Enumerated deserialization entry points via grep for `DeserializeMission`: `MissionCache.LoadAllMissions`, `WebAdmin MissionsModel.ParseMission`, and tests. Read the `MissionCache` block: it copies a fixed list out of the deserialised object (`StartCondition`, `ArchiveCondition`, `FailCondition`, `Resources`, `Prototypes`, `Hints`, `CompleteInteractions`, `FailInteractions`, `Version`, `IsSerialTracking`, `Restart*AfterMinutes`, `ActivateAfter`, `ActivateAfterFail`, `*MissionStartMessage`, `SuppressMissionEndMessage`) — never these three. Conclusion: their values have always come from DB columns; the attributes were inert.
- Searched for serialization of `Mission` to JSON: none. Profile persistence uses `StartedMission` (separate class in `Mission/Profile/`); the client receives `MissionOnClient`, whose `[JsonProperty]` set — including `IsMultiStart` — is untouched by this commit.
- Read `JsonKeyValidator`: it validates key characters against a regex, not against a schema, so existing `ConfigJson` blobs cannot begin failing WebAdmin validation.
- Grepped the test projects: these flags are set through object initialisers, not JSON.

**Resolution:** `Accepted` — no behaviour change; the attributes matched no real consumer.

**Discovered by:** skill recon (delegates concurred)

### F-4: New tests omit the flag combination the live content actually uses [Low]

**Description:** All three tests build a mission with `IsAutoActive = false`, whereas every mission that enables `KeepTrackedOnRestart` in the database also has `IsAutoActive = true`. The new branch matters precisely in that combination, because it pre-empts `GetNextMissionForActivationOnStart`; that interaction is untested.

**Investigation:**
- Read the added tests: `CreateKeepTrackedMission` fixes `IsAutoActive = false`, `RestartFailedMissionAfterMinutes = 0`, `FailCondition = TaskCompletedCondition`.
- Mutation sensitivity assessed against the diff: reverting the production hunk restores the `&& mission.IsAutoActive` gate, which the positive test's `IsAutoActive = false` would then fail — so the positive test does discriminate the change. The two negative tests would pass either way.
- Executed the tests at HEAD (`dotnet test --filter FullyQualifiedName~KeepTrackedOnRestart`): 3 passed, 0 failed.
- Compared with the DEV content rows (see F-1): the untested combination is the only one shipping.

**Resolution:** `Filed → FP-45235` — add coverage for `IsAutoActive = true` + `KeepTrackedOnRestart = true` with a replacement mission available after the fail, alongside the F-1 fix.

**Discovered by:** skill recon | Codex (independently)

### F-5: With the live content markup the "only if it was the tracked one" restriction does not hold [Info]

**Description:** The requirement frames the feature as distinct from auto-active: re-tracking should happen only when the failed mission was the tracked one. The implementation places the new branch before, not instead of, the `IsAutoActive` branch, and all ten missions that enable `KeepTrackedOnRestart` also keep `IsAutoActive = 1`. When the new branch misses, the fallback still auto-tracks the mission whenever no replacement was activated at fail time — the case the requirement asked to exclude.

**Investigation:**
- Read the restructured block: `if (KeepTrackedOnRestart && …) … else if (IsAutoActive) …` — the second branch remains reachable.
- Read `GetNextMissionForActivationOnStart`: its first rule is `if (activeMission == null) return newMission`, so with `IsAutoActive = 1` the mission re-tracks regardless of what was tracked before the fail.
- Queried `[F2P] DEV`: all ten rows carry both `IsAutoActive = 1` and `KeepTrackedOnRestart = 1`.
- Two readings are consistent with the evidence and the code cannot settle which was intended: `IsAutoActive` may be deliberately retained for the mission's initial activation, or its retention alongside the new flag may be an oversight in the content markup.

**Resolution:** `Accepted` — card only, per reviewer decision: the tasks already went through QA, and content behaviour is for the content owners to validate. Note that the retained `IsAutoActive` also softens F-1's misses.

**Discovered by:** skill recon

## Verdict

**Approve.** The change is mechanically sound and complete along the route the shipping content uses: the data path is wired end to end, the WebAdmin surface follows the framework's reflection-based conventions, the SQL patch is idempotent and correctly numbered, the merge into NPN is content-identical, and the new tests pass and discriminate the change. F-1/F-2/F-4 share one root cause — the loop-wide `prevActiveMission` snapshot standing in for "tracked at fail time" — and are filed rather than blocking, since the ten missions shipping with the flag all use the working route.

**Verification scope:** the working route was verified empirically (tests executed at HEAD) and the content population was verified by querying `[F2P] DEV`. The three miss routes in F-1 and the race in F-2 were established by static trace through `ProcessMessagesLoop` / `MissionsManager_Fail` / `MissionsManager_Timed`, not reproduced at runtime; no test or live run was constructed for them.

## Investigation Journal

- VCS audit: `svn log -r 16200:HEAD | grep FP-44667` on both MFT and NPN returns exactly the two commits listed in JIRA — no unposted commits, branch attribution in the JIRA comment matches commit metadata.
- Merge completeness verified by normalising and diffing the bodies of `svn diff -c 16271` (MFT) and `svn diff -c 16272` (NPN): identical apart from `svn:mergeinfo` property lines.
- WC is at r16364, ahead of the reviewed revisions — disk state is trustworthy for context reads. HEAD-verification (commit is 20 days old): `svn log -r 16272:HEAD` on `MissionsManager_Start.cs` and `Mission.cs` returns no later commits, so the reviewed logic is still what HEAD carries.
- SQL patch numbering: `MFT.M.2026.07.07-026` follows `…-025` with no collision; the NPN copy keeps the MFT `PatchName`, as the convention requires.
- Data path verified end to end rather than assumed: `SqlMissionProvider` selects `m.*`, `DtoExtensions.RestoreObjectFromReader` maps reader columns to DTO properties by reflection, `SerializationHelper.MakeEqualTo` copies DTO→DTO by reflection, and `MissionCache` carries the explicit assignment added in this commit. No further DAL edit is needed for the new column.
- WebAdmin claim verified: `Shared/DataEditing/CrudHelper` composes INSERT/UPDATE from the entity type's columns (`ColumnDesc` enumerates properties in declaration order), so adding the property to `Entities.Missions` is sufficient for both grid and persistence — matching the sibling flags that also carry no `UIHint`.
- Step 6 cross-repo check: the diff touches `Shared/ObjectModel/`, but `Mission.cs` and `MissionsManager_*.cs` are not part of the client's source-copied subset (`find` over `Win64_MainClient/Assets/Photon Server Networking` returns only the `Mission/Client/*` DTOs and `MissionsContext.cs`). No client mirror required.
- Hypothesis "the flag misses on relogin, because `prevActiveMission` is captured before `ActiveMissionCode` is resolved" — disproven. `MissionsManager.Container_Load` resolves `context.ActiveMission` from `context.ActiveMissionCode` before any `ProcessMessagesLoop` call, so the first cycle after login already carries the restored reference.
- Delegated claim "the target content uses delayed restarts, making F-1 a live High-severity bug" (code-reviewer agent) — disproven by the DEV query: all ten rows use `RestartFailedMissionAfterMinutes: 0`.
- Delegated claim "the patch's `INFORMATION_SCHEMA.COLUMNS` guard is ambiguous without `TABLE_SCHEMA`" (Codex) — rejected: `Main` exposes only `dbo.Missions`, and all 73 patches in the tree that use this guard omit `TABLE_SCHEMA`, so the patch follows the established convention.
- Delegated claim "some external or legacy consumer may JSON-serialise `Mission` directly" (Codex, held as unresolved) — searched and none found; recorded under F-3.
- Findings routing: F-1/F-2/F-4 → FP-45235 (one task, shared root cause; parented to the Technical Debt 2026 Q3 epic, Relates to this task and to FP-45233, which touches the same fail-plus-immediate-restart path); F-3/F-5 → accepted, card only. F-3's "should have been a separate commit" remark deliberately left out of the JIRA comment per reviewer decision.
- Release-step gate: `customfield_11323` already carried `DB Migrations`, which is the only option the diff derives (`SQL/Patches/**`); no edit needed. The content markup that enables the flag lives in the DB, outside this diff, so it derives no `DataPump` tag here.
