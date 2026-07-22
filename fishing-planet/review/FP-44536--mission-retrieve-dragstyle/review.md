---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16289, merged to NPN20260602 @ r16290
jira: https://fishingplanet.atlassian.net/browse/FP-44536
---

# Review: FP-44536 — Daily mission retrieve-type task completable by bottom rod

## Summary

Prod bug: daily mission tasks conditioned on a retrieve technique (popping/walking) could be completed by landing a fish on a different rod slot (e.g., a bottom rod on a rod stand). Root cause per executor: the mission was built from separate steps, and the "correct retrieve detected" step did not reset until the end of the fishing cycle, so a fish caught later on another slot satisfied the mission.

Fix per executor: reworked to a single step — the fish must be generated or hooked with the DragStyle specified in the mission. Side capability: `CatchFishCondition`/`RoomCatchFishCondition` now support a DragStyle condition for mission design.

## Scope

- **MFT20260325 r16289** — Bind mission catch-by-retrieve to the fish that was hooked
  - Rework retrieve-type daily mission from separate steps to a single catch step conditioned on DragStyle
  - Fish qualifies if generated or hooked with the mission's DragStyle
  - `CatchFishCondition`/`RoomCatchFishCondition` gain DragStyle condition support
- **NPN20260602 r16290** — Merge from MFT r16289

## Investigation Journal

- Intake: commit list taken from JIRA comment at face value (MFT r16289, NPN r16290).
- MFT20260325 = Content branch (ships FTUE + FPA), NPN20260602 = Code branch; NPN base is MFT:16130 < 16289, so the explicit merge to NPN was required.
- VCS audit: `svn log 15943:HEAD` (MFT) and `16131:HEAD` (NPN) grepped for FP-44536 — exactly r16289 (yuriy.burda) + merge r16290 with proper TortoiseSVN message; no unposted commits. WC at r16351 >= 16289 — disk reads trustworthy.
- Verified per-slot isolation (core of the fix): `GameProcessor` is a per-rod-slot processor; `dragStyle` is its field parsed from per-slot `transitionData`, and `context = peer.Profile.MissionsContext[Slot]`. A bottom rod's slot cannot observe the spinning slot's popping style; instrument: Read of `GameProcessor.cs` transition parsing + all `MissionsContext[Slot]` call sites.
- Verified attack->hook transfer: `GenerateHookingForLure/Float/Bottom` return a NEW `Fish`, and `FishExtensions.CopyFishingCycleProperties` carries `AttackDragStyle`/`HookDragStyle` from the attack-phase fish (same pattern as sibling `[NoClone]` fishing-cycle props); `HookDragStyle` then overwritten from slot context at hook. Attack-site sets `AttackDragStyle` on each fresh `GenerateAttack` result — no stale carry between cycles.
- Verified room-catch serialization path: broadcast at `GameProcessor.HandleCatchFish` serializes `CaughtFish` with `SerializationHelper.JsonSerializerSettings` (DefaultContractResolver); `Fish` is `[JsonObject(OptOut)]` so the new fields serialize (StringEnumConverter), and `GameClientPeer_Travel` deserializes with the same settings — fields survive peer-to-peer transfer. `[NoClone]` does NOT strip them here (`JsonSkipInventoryContractResolver` is a different, unused-on-this-path resolver that for `Fish` inversely serializes ONLY `[NoClone]` props).
- Verified NRE safety: `MatchFishBasic(condition, null fish)` returns false, gating `CheckAdditional` of both conditions before the new DragStyle dereferences; room condition additionally uses `RoomCaughtFish?.Fish`.
- Verified `DailyMissionUtils` rework: Trolling still maps to `DragStyle.Undefined` -> no DragStyle condition, only `FishWasHookedWithTrolling` (behavior preserved); switch exhaustive with throw. `new DragStyleCondition` has no remaining programmatic creators — class stays for data-driven (tutorial) missions; `IsSimilarTo` extension refactor is logic-equivalent to the removed private method.
- Verified deploy semantics: daily mission condition trees are NOT persisted — rebuilt via `ConvertToMission` on every profile load (`MissionHelper`, `DailyMissionAdapter` call sites), so the fix applies to in-flight dailies immediately.
- Verified progress carry-over across the structure change: `SerialAchievement.Init` auto-assigns `ResourceKey = "@SerialAchievement_{TaskId}"`; persisted `StartedMission.Counters` restore by that key (`LoadCountersAndVariablesAndInteractionsFromProfile`), and TaskIds are unchanged — caught-fish count survives; only the old non-persisted retrieve-step state disappears (intended).
- Verified client-mirror not needed (Step 6): client source copy `Assets/Photon Server Networking/ObjectModel` has no `FishConditions.cs`/`DragStyleCondition.cs` (catch conditions are server-only), and client `Fish.cs` contains none of the mission-predicate fields (`FishWasHookedOnRodStand`, `HookDepth` absent) — established pattern, new fields follow it. No paired client commit expected; none posted in JIRA.
- Tests: built `ObjectModel.Tests` (MSBuild exit 0) and ran filter `CatchFishCondition|RoomCatchFishCondition|DragStyle` — 30/30 passed.
- Unresolved (instrument: client repo/runtime, not settled from server repo): the doc-comment claim "Undefined for non-lure rigs" — whether the client ever reports a DragStyle for non-lure rigs (e.g. steady reel-in of a bottom rig). Bounded impact: per-slot isolation still holds; worst case a Simple/SlowSimple-style task could credit a bottom-rod catch hooked during rig retrieval.
- Codex delegate (blind hunt) returned 2 findings; both re-verified before acceptance:
  - Relogin-mid-fight loss (-> F-1): confirmed by own Read of `RodState` (`PersistentData.cs` — no drag-style fields; `RodState.Fish` not populated on this save path), `MultiRodGameProcessor` save block (persists only FishId/InstanceId/Weight/Source/FightTime/Stamina), and `GameProcessor.RestoreFish` (rebuilds Fish via `fishGenerator.RestoreFish` -> styles default Undefined). Sibling mission-predicate fields (`FishWasHookedWithTrolling`, `FishWasHookedOnRodStand`, `HookDepth`) are equally absent from `RodState` — the restore gap is a pre-existing class, new fields inherit it.
  - Crafted-client drag style on non-lure rig (-> F-2): server side confirmed by own Read (`transitionData[DragStyle]` cast without rig validation; unconditional assignment at attack/hook). Pre-existing trust-the-client class: the removed `DragStyleCondition` trusted the same client-reported `context.DragStyle`, so the cheat surface existed before the fix and is narrower after it.
  - Codex's mixed-version room hypothesis dismissed: room broadcast is intra-node (single game room), and no missions with RoomCatch DragStyle exist yet (capability is new).
  - Codex independently confirmed clean: lifecycle copy points, escape/re-attack reset, room JSON transport, progress carry-over, dropped `DragStyleTime` was never effective in dailies (never assigned -> `>= 0` always true).
- code-reviewer agent (blind hunt) returned 1 finding (same relogin-mid-fight gap, independently) + deepened the mechanism: `CreateFightingFishInstance` has 7 call sites, 6 followed by `CopyFishingCycleProperties`, only the `FishGenerator.RestoreFish` path is not; no `GameProcessor`/`RestoreFish` test harness exists (grep zero). Also verified `IsSimilarTo` C# 9 pattern precedence parses as intended, and `GenerateCatch` mutates in place (self-copy harmless). Agent's side observation: same-rod "style flick at hook instant" loophole is documented intentional ("forgiving" comment) — kept as a Note, not a finding.
- Phase 3 executor-claim sweep: root-cause statement (old separate step, `ShouldResetSerial = !IsFishingCycle` sticky until cycle end) — confirmed in pre-change `DragStyleCondition`; single-step rework — confirmed in diff; "drag style is in the logs for both generation and hooking" — confirmed (`Fish attack generated ... DragStyle:` and `Fish hooked ... DragStyle:` messages in `GameProcessor` fishingLog); commits/branches — confirmed by svn log audit.

## Findings

### F-1: Relogin mid-fight zeroes AttackDragStyle/HookDragStyle — legitimate retrieve catch not credited [Medium]

**Description:** `RodState` persistence (save on disconnect/exit in `MultiRodGameProcessor`) stores only FishId/InstanceId/Weight/Source/FightTime/Stamina; `GameProcessor.RestoreFish` rebuilds the fighting fish via `fishGenerator.RestoreFish` without re-applying fishing-cycle properties, so both new fields come back `Undefined`. A player who hooks a fish with the required retrieve, disconnects during the fight, reconnects and lands it will not get mission credit (silent false negative). Severity-justifying: legitimate-play mission loss, though in a narrow window (disconnect mid-fight).

**Investigation:**
- Read `PersistentData.cs` `RodState` — no drag-style fields; sibling mission-predicate fields (`FishWasHookedWithTrolling`, `FishWasHookedOnRodStand`, `HookDepth`) equally absent, so the restore gap is a pre-existing class that the new fields inherit.
- Read `MultiRodGameProcessor` save block — persists only the scalar fish fields listed above; `RodState.Fish` is not populated on this path (grep of assignments in `MultiRodGameProcessor` — zero).
- Read `GameProcessor.RestoreFish` — `fishGenerator.RestoreFish(fishId, instanceId, weight, source)` with no `CopyFishingCycleProperties` and no manual style re-stamp.
- Both delegates surfaced the same mechanism independently (Codex; code-reviewer agent with the 7-call-site enumeration).

**Resolution:** Skipped — reviewer decision: fish restore after relogin is a known broken area (the fish is effectively not restored at all), so the drag-style loss is subsumed by a wider known issue; not worth time now. The fishing rework epic (FP-45122) — which save-player-state work depends on — is expected to address this class.

**Discovered by:** Codex + code-reviewer agent (independently); re-verified by skill recon.

### F-2: Server trusts client-reported drag style with no rig-type validation [Low]

**Description:** `dragStyle` is taken from client `transitionData` (`(DragStyle)(byte)` cast, no enum/rig validation) and stamped unconditionally onto the fish at attack and hook in `GameProcessor`. A modified client can report a retrieve style on a non-lure rig and satisfy a retrieve daily. Pre-existing trust-the-client class: the removed `DragStyleCondition` trusted the same client-reported value, so this surface existed before the fix and is narrower after it (style must now be present at the specific slot's attack/hook moment).

**Investigation:**
- Read `GameProcessor` transition parsing — cast without validation; attack/hook assignment sites unconditional (own Read during recon).
- Compared with pre-change behavior: old daily step checked live `context.DragStyle` from the same client input — cheat surface not introduced by this commit.
- Codex raised it (crafted-request variant); confirmed server-side by own reads.

**Resolution:** Skipped — pre-existing trust-the-client surface, narrowed (not widened) by this commit; anti-cheat hardening is out of this bugfix's scope. Reviewer: the current anti-cheat approach is slated to be discarded and redone within the fishing rework (FP-45122 epic).

**Discovered by:** Codex; server side re-verified by skill recon.

### F-3: No integration-level coverage of the drag-style lifecycle; restore path untested [Info]

**Description:** New tests cover `CheckAdditional` matching logic in isolation (both conditions, similarity, negatives) but no test exercises the `GameProcessor` attack->hook->catch->restore population of `Fish.AttackDragStyle`/`HookDragStyle`; no `GameProcessor`/`FishGenerator.RestoreFish` test harness exists in the repo at all, which is why F-1's gap is structurally uncatchable by the current suite.

**Investigation:**
- Read both new test files — unit-level `MissionsContext` injection only.
- code-reviewer agent grepped `RestoreFish` references across test projects — zero.
- Ran the affected test filter on built `ObjectModel.Tests` — 30/30 passed.

**Resolution:** Accepted — unit level is the architecturally available test layer in this repo; a `GameProcessor` harness is far beyond this fix's scope, and the fishing gameplay code is slated for a near-complete rewrite under the FP-45122 epic.

**Discovered by:** skill recon + both delegates (independently noted).

## Notes

- Same-rod loophole "flick the required style at the hook instant" is documented as intentional forgiving behavior in the `CatchFishCondition` code comment — design decision, no code issue.
- Unresolved client-contract claim ("Undefined for non-lure rigs") fails closed on the server (`dragStyle = 0` when the key is absent) — worst case is a false negative, not a false positive; actual client send behavior not verifiable from the server repo.

## Verdict

Approve. The core fix is verified correct end-to-end: per-slot drag-style capture bound to the hooked fish closes the rod-stand cross-rod exploit; recon and both independent delegates (code-reviewer agent, Codex) converge with no unresolved disagreements. Serialization (room path), daily-progress carry-over, Trolling mapping, tutorials (`DragStyleCondition` untouched semantics), and client-mirror non-applicability all verified clean; affected tests built and run (30/30 passed). Findings: F-1 [Medium] Skipped (known-broken fish-restore area; superseded by FP-45122 rework), F-2 [Low] Skipped (pre-existing trust-the-client surface, narrowed by the commit; anti-cheat redo planned in FP-45122), F-3 [Info] Accepted. Merge state: MFT r16289 already merged to NPN as r16290 by the executor; further (downward) targets to be decided at close per release mapping.

Verification scope: root cause verified at source level (old separate `DragStyleCondition` step with `ShouldResetSerial = !IsFishingCycle` sticky until cycle end); fix mechanism traced through attack/hook/catch and persistence paths. Unresolved: client-side send contract for non-lure rigs (fails closed server-side — cannot produce false positives).
