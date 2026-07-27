---
status: resolved
executor: Yuriy Burda
branch: NPN20260602 @ r16213, merged to MFT20260325 @ r16256
jira: https://fishingplanet.atlassian.net/browse/FP-44501
---

# Review: FP-44501 — ANNIVERSARY 2026: Server - Fish Dragging Kayak Tracking

## Summary

Mission-side support for tracking the distance a hooked fish drags the player's boat/kayak, by analogy with the existing "Fishy Racing" achievement (id 201). Executor added a per-fish boat-drag distance filter (`MinDistanceSailedWithFish`) to `CatchFishCondition`, so a mission can require the fish to tow the boat a minimum distance before it is landed. Target release: 2026.5 Anniversary.

Task history has a reopen cycle: after the first round (r16213 on NPN) the ticket was reopened on 2026-06-26 with a requirement to also track drag distance for the pedal kayak (it ships in the event DLC), and QA reported on 2026-07-02 that mission 3983 credited a fish caught without any boat drag. The ticket returned to In Review on 2026-07-06 with a comment stating the change had not been merged into MFT, plus the merge revision.

## Scope

- **NPN20260602 r16213** — Add per-fish boat-drag distance filter to `CatchFishCondition`
  - New `MinDistanceSailedWithFish` mission-condition parameter
  - Per-fish drag distance exposed for the currently hooked fish (previously only a cumulative counter existed for the achievement)
- **MFT20260325 r16256** — Merge from NPN20260602 r16213

> Scope is intake-level (JIRA comments at face value); Phase 2 audits it against `svn log`.

## Investigation Journal

- Intake from JIRA: executor field populated (Yuriy Burda), matches the commit author named in the JIRA comments.
- VCS audit: `svn log -r 16100:HEAD | grep FP-44501` on both NPN20260602 and MFT20260325 returns exactly the two commits listed in JIRA — r16213 (code) and r16256 (merge). Confirms that neither reopen-round input (pedal-kayak requirement 2026-06-26, QA report 2026-07-02) produced any code change; the only action between the reopen and the return to In Review was the MFT merge.
- Merge fidelity: `svn diff -c 16256` on MFT is byte-identical in content to `svn diff -c 16213` on NPN — clean merge, nothing dropped.
- WC freshness: repo WC at r16364, ahead of both reviewed revisions — disk reads are trustworthy for HEAD-state checks; diffs read via `svn diff -c`.
- Accumulator lifecycle traced: `BoatManager.Travel` (BoatManager.cs) calls `boatRodRelatedManager.Travel(deltaD, isFishFight)`; the manager is reached from `MultiRodGameProcessor.HandleTravelByBoat` via `handsProcessor.BoatRodRelatedManager`. `ResetFishDistance()` has exactly one call site — `GameProcessor` FinishAttack handling (fish hooked). `GetCaughtFish()` is called at hook time, at catch time, at take-fish time and on session restore; mission processing runs after the operation handler (`ProcessMissions` in `GameClientPeer_Travel`), so `CatchFishCondition` consumes the catch-time instance.
- Anti-cheat semantics verified (`AntiCheatCommonManager.VerifyBoatTravel`): rowing while fighting a fish is flagged as cheating for a plain `Kayak`, and explicitly legal for `PedalKayak` ("pedal kayaks are built for trolling: pedalling (reported as rowing) while fighting a fish is legal"). The same method already computes `isFishFightWithoutDriving = !wasEngineForce && !wasRowing && (isFishFight || hasSnag)` for its fish-driven speed check — the exact predicate the new counter does not use.
- Content exposure queried on the local dev copy of `Main`: mission 3983 `Anniversary24_AmazonianMaze` is the only content using the new parameter (`MissionTasks` where `ConfigJson LIKE '%DistanceSailedWithFish%'` → TaskId 15858 only). Its Task_3 reads `CatchFishCondition FishCategoryId 1690, MinDistanceSailedWithFish 10` combined with `IsOnBoatCondition ItemSubType 'Kayak'`; Task_2 carries the same `ItemSubType 'Kayak'` gate. Older missions (1480/1490/1500/1510) use the inclusive form `ItemSubTypes: ['Kayak','PedalKayak']`, so the inclusive pattern is established content practice.
- `ConditionExtensions.Match` (BoatConditions.cs) compares `ItemSubType` by equality; `ItemSubTypes.Kayak` = 98, `PedalKayak` = 199 (InventoryEnums.cs) — a `'Kayak'` gate excludes the pedal kayak. Note `Inventory_Groups.IsKayak()` does cover both, but the mission condition does not go through it.
- Serializer behaviour verified: `SerializationHelper` never sets `MissingMemberHandling`, so Newtonsoft's default `Ignore` applies — a build without the new property silently drops `MinDistanceSailedWithFish` from mission JSON and the condition degenerates to a plain catch check. This is consistent with the QA report of 2026-07-02 landing before the MFT merge (2026-07-06), but the build the tester actually ran was not established (see Notes).
- Client mirror checked: `Win64_CodeBranch/Assets/Photon Server Networking/ObjectModel/FishCage/FishCageContents.cs` has `IsOnBoat` but no `DistanceSailedWithFish`; no occurrence of the name anywhere under the mirrored ObjectModel tree. `FishConditions.cs` is not mirrored into the client at all, so the condition logic itself needs no mirror.
- Delegated review (per open-skill Step 7) dispatched in parallel: independent blind defect hunt (code-reviewer agent) and targeted verification of the reconnect/stale-value hypotheses (Codex). Both independently landed on the reconnect defect (F-1); Codex additionally refuted the competing "stale value from the previous fish" explanation for the normal same-session path, which had been the leading candidate for the QA report — recorded as hypothesis disproven.
- Reconnect chain re-verified first-hand rather than taken from the delegates: `MultiRodGameProcessor.SetupGameProcessor` constructs a new `GameProcessor` and only then calls `RestoreFish`; the constructor always builds a fresh `BoatRodRelatedManager`; `RestoreFish` restores fish/tire/stamina but never resets the drag accumulator; `stateMachine.SetInitialState(FishFight)` makes `IsFishFight` true immediately, so `Travel` runs on a still-null accumulator. Codex additionally confirmed `CollectPersistedData` stores state/fish/fight-time/stamina and no drag distance.

## Findings

### F-1: Reconnect during a fish fight permanently zeroes that catch's drag distance [Low]

**Description:** `BoatRodRelatedManager.distanceSailedByThisFish` is a `float?` and `Travel()` accumulates with a lifted `+=`, so while the field is null the accumulation is a no-op that leaves it null. The only `ResetFishDistance()` call site is the hook handling in `GameProcessor`, and the session-restore path never calls it — so after a mid-fight reconnect the accumulator stays null for the rest of that fish, `CaughtFish.DistanceSailedWithFish` is 0, and a mission requiring `MinDistanceSailedWithFish` rejects the catch. Not just the pre-reconnect distance is lost: distance sailed *after* the reconnect is not counted either, so the player cannot recover the objective by continuing to fight. It matters because a network drop silently and irrecoverably invalidates mission progress the player is actively earning.

**Investigation:**
- Read `BoatRodRelatedManager.cs` at the reviewed revision: field is `float?`, getter returns `?? 0f`, `Travel` does `distanceSailedByThisFish += deltaD` under `if (hasFish)`. C# lifted `+=` yields null when either operand is null, so the no-op is permanent until an explicit reset.
- Grepped the whole server tree for `ResetFishDistance` — exactly one production call site, in `GameProcessor` FinishAttack handling (fish hooked); the rest are the new unit tests.
- Traced restore: `MultiRodGameProcessor.SetupGameProcessor` builds a new `GameProcessor`, sets the FSM initial state from `savedState.State`, then calls `RestoreFish`. The `GameProcessor` constructor unconditionally allocates a fresh `BoatRodRelatedManager`. `RestoreFish` handles the `FishFight`/`BiteConfirmed` branch with `InitFishTire` / `InitElectricOverload` / `InitHugeFishDisplay` / `InitStamina` / `FishFightRestarted` — nothing touches the drag accumulator.
- Confirmed the post-reconnect ticks do reach `Travel` with `hasFish: true`: `IsFishFight` is `StateMachine.State == GameStates.FishFight`, and the restored FSM starts in that state; `MultiRodGameProcessor.HandleTravelByBoat` passes `handsProcessor.IsFishFight` and `handsProcessor.BoatRodRelatedManager` into `BoatManager.Travel`, which calls `boatRodRelatedManager.Travel(deltaD, isFishFight)`.
- `BiteConfirmed` restore is not affected: the fish is not hooked yet, so the subsequent FinishAttack runs the reset normally.
- Independently reported by both delegates; Codex additionally verified `MultiRodGameProcessor.CollectPersistedData` persists state/fish identity/fight time/stamina and no drag distance, i.e. there is no stored value to restore from.
- Pre-existing scope check: the accumulator's absence from persisted state predates this commit and previously only under-reported the `MaxXmasKayakFishDist` achievement counter. The commit does not create the storage gap, but it turns a silent counter shortfall into an outright mission rejection.

**Resolution:** Pre-existing. Mid-fight state restore does not work at all, so every consequence downstream of it — including this one — is masked by that larger breakage and is not this commit's to carry. The accumulator is unreachable in a null state outside the restore path (the hook handler resets it on every fish), so no non-restore scenario is affected. Severity lowered from Medium accordingly. If the fight restore is ever fixed, the cheapest correction here is to drop the nullability (`private float distanceSailedByThisFish;`): the null state carries no meaning today because the getter already collapses it to 0, and `hasFish` alone already prevents pre-hook accumulation.

**Discovered by:** skill recon (hypothesis), confirmed independently by code-reviewer agent and Codex.

### F-2: Drag distance does not distinguish fish-towing from self-propulsion, so on a pedal kayak the objective is satisfied by pedalling [Medium]

**Description:** `BoatManager.Travel` feeds every boat displacement into the counter as `boatRodRelatedManager.Travel(deltaD, isFishFight)` — the only gate is "a fish is on". Anti-cheat in the same call path treats this asymmetrically by boat type: rowing while fighting a fish is flagged for a plain `Kayak` but is explicitly legal for `PedalKayak` ("pedal kayaks are built for trolling: pedalling (reported as rowing) while fighting a fish is legal"). So on the pedal kayak a player satisfies "let the fish tow you N metres" by pedalling those metres. This is the exact objection the executor raised in the ticket before implementation; the reopen requirement to support the pedal kayak makes it load-bearing rather than hypothetical.

**Investigation:**
- Read `BoatManager.Travel`: `deltaD` is the raw position delta; `wasRowing` and `wasEngineForce` are both in scope at the call site but are not passed to `boatRodRelatedManager.Travel`.
- Read `AntiCheatCommonManager.VerifyBoatTravel`: the rowing-while-fighting cheat check is `((wasRowing && boatType != ItemSubTypes.PedalKayak) || (wasEngineForce && boatType == ItemSubTypes.Kayak)) && isFishFight`, with the comment stating pedalling during a fight is legal. That establishes the plain kayak's inability to self-propel during a fight as an enforced rule, and the pedal kayak's ability as a sanctioned exception.
- Same method already computes the predicate this feature needs: `isFishFightWithoutDriving = !wasEngineForce && !wasRowing && (isFishFight || hasSnag)`, used to bound the "boat driven by fish" speed check.
- Boats with rod stands / trolling motors are affected by the same gap for the engine case; the counter is boat-type agnostic.

**Resolution:** Accepted as a deliberate trade-off — counting any movement is the price of supporting the pedal kayak at all, which the reopen required. Surfaced to the feature owner (the author of the reopen requirement) as a warning in the closing JIRA comment so the product side can decide whether the objective should require actual towing. If it should, the concrete change is to pass `isFishFight && !wasRowing && !wasEngineForce` into `boatRodRelatedManager.Travel`, mirroring the anti-cheat's existing `isFishFightWithoutDriving`. Not urgent: the shortcut is currently unreachable because the only content using the parameter excludes the pedal kayak (F-3) — the warning and the F-3 decision therefore belong together.

**Discovered by:** skill recon.

### F-3: Mission 3983 gates on `ItemSubType: 'Kayak'`, which excludes the pedal kayak the reopen explicitly required [Medium]

**Description:** The reopen of 2026-06-26 requires drag distance to be trackable on the pedal kayak because it ships in the event DLC. The only content using the new parameter — mission 3983 `Anniversary24_AmazonianMaze` — pairs `CatchFishCondition MinDistanceSailedWithFish: 10` with `IsOnBoatCondition ItemSubType: 'Kayak'` (its Task_2 carries the same gate), and `ConditionExtensions.Match` compares the subtype by equality, with `Kayak` = 98 and `PedalKayak` = 199. The mission is therefore impossible on the pedal kayak, so the reopen requirement is not met end to end even though the server counter itself is boat-type agnostic. The configuration example the executor posted in the ticket before the reopen uses the same exclusive form and was evidently copied into the content verbatim.

**Investigation:**
- Queried the local dev copy of `Main`: `MissionTasks` rows whose `ConfigJson` mentions `DistanceSailedWithFish` → exactly one, TaskId 15858 of mission 3983, containing `{ type: 'CatchFishCondition', FishCategoryId: 1690, MinDistanceSailedWithFish: 10 }` and `{ type: 'IsOnBoatCondition', ItemSubType: 'Kayak' }`. Task_2 (TaskId 15857) repeats the `ItemSubType: 'Kayak'` gate. Mission row is `IsActive = true`.
- Read `ConditionExtensions.Match` in `BoatConditions.cs`: `ItemSubType` is matched by equality against the active boat, with a separate inclusive `ItemSubTypes` array option.
- Read `InventoryEnums.cs`: `Kayak = 98`, `PedalKayak = 199`. Note `Inventory_Groups.IsKayak()` covers both, but the mission condition does not use it, so the grouping does not apply here.
- Established that the inclusive form is existing content practice: `MissionTasks` rows mentioning `PedalKayak` (missions 1480/1490/1500/1510) all use `ItemSubTypes: [ 'Kayak', 'PedalKayak' ]`.
- Scope caveat: this binds to the current local content snapshot; the production/test content may differ, and future content changes can alter exposure without any code change.

**Resolution:** Accepted — mission configuration is content, outside the server team's remit, so this is routed to the feature owner in the same closing-comment warning as F-2 rather than back to the executor. The two belong together: switching the gate to `ItemSubTypes: ['Kayak','PedalKayak']` is what satisfies the reopen requirement and simultaneously opens the pedalling shortcut, so the owner decides both at once.

**Discovered by:** skill recon.

### F-4: Client ObjectModel mirror not updated with the new `CaughtFish` field [Info]

**Description:** `Shared/ObjectModel/FishCage/FishCageContents.cs` is one of the source-duplicated files mirrored into the client tree, and the commit adds `DistanceSailedWithFish` to `CaughtFish` without a matching client-side edit. No functional impact was found — the field is server-produced and server-consumed, and Newtonsoft's default missing-member handling makes the client ignore it — but the mirror is out of sync with the server definition.

**Investigation:**
- Checked the paired client checkout `Win64_CodeBranch` (`Assets/Photon Server Networking/ObjectModel/FishCage/FishCageContents.cs`): the mirrored `CaughtFish` has `IsOnBoat` but no `DistanceSailedWithFish`; a search for the name across the whole mirrored ObjectModel tree returns nothing.
- Confirmed the other changed shared file needs no mirror at all: `Mission/ConditionsGame/FishConditions.cs` has no counterpart in the client tree, so mission-condition evaluation is server-only.
- Confirmed the field's consumers are all server-side: written in `GameProcessor.GetCaughtFish`, read by `CatchFishCondition`, and carried in the fishing-together broadcast that is sent with `sendToClient: false`.

**Resolution:** Accepted. The divergence from the mirroring rule is real but has no consumer on the client side, so a separate client revision for a field the client never reads is not worth the paired-commit overhead.

**Discovered by:** skill recon.

### F-5: New tests cover the units in isolation and miss the accumulate-without-reset path [Info]

**Description:** `BoatRodRelatedManagerTests` always calls `ResetFishDistance()` before exercising `Travel`, and `CatchFishConditionTests` builds `MissionsContext`/`CaughtFish` by hand, so nothing covers the seam where F-1 lives — `Travel(hasFish: true)` on a manager that was never reset, which is exactly the post-reconnect state. A single test asserting the intended behaviour of that case would have pinned the nullable-accumulator semantics.

**Investigation:**
- Read both test files as added in the diff: three manager tests (pre-reset zero, accumulate after reset, ignore travel without fish) and five condition tests (min/max boundaries and a fractional case). The pre-reset test asserts the getter returns 0 but never calls `Travel` first, so the permanent-null behaviour is not observed.
- No integration-level test exists for `GetCaughtFish` / hook-time reset ordering / restore path — confirmed by grepping the test projects for `BoatRodRelatedManager` and `GetCaughtFish`.

**Resolution:** Skipped. Once F-1 is accepted as pre-existing, a test pinning the accumulate-without-reset behaviour would only lock in the semantics of a scenario that is already broken higher up the stack.

**Discovered by:** code-reviewer agent.

## Verdict

Approve. The change does what the ticket asked: a per-fish drag distance is exposed to `CatchFishCondition` through `MinDistanceSailedWithFish` / `MaxDistanceSailedWithFish`, the accumulator is reset on every hook, the mission condition consumes the catch-time `CaughtFish`, and the merge into MFT is byte-clean. Nothing blocking survived verification — F-1 is masked by the known-broken mid-fight restore, F-4/F-5 are cosmetic, and F-2/F-3 are product decisions rather than code defects.

Carried into the closing JIRA comment as a single warning to the feature owner: supporting the pedal kayak means accepting that the required distance can be pedalled, because the counter accumulates any boat movement while a fish is on and anti-cheat explicitly legalises pedalling during a fight. Until the mission's boat gate switches from `ItemSubType: 'Kayak'` to the inclusive form, the reopen requirement is not met in content and the shortcut is unreachable — both change together.

**Verification scope:** the implementation was verified statically (diff, call-chain traces, condition evaluation order, content query on the local dev copy of `Main`). The QA report of 2026-07-02 was explained but not root-caused — the build the tester ran was never established, and no instrument available from the repo can settle it. The approval therefore covers the mechanics of the change, not a demonstrated repro of the reported symptom.

## Notes

1. The QA report of 2026-07-02 (mission 3983 credited a fish caught while anchored) is consistent with the fix not yet being in the branch the tester ran: MFT received the code only on 2026-07-06 (r16256), and `SerializationHelper` never sets `MissingMemberHandling`, so Newtonsoft's default `Ignore` silently drops `MinDistanceSailedWithFish` from the mission JSON on a build without the property, degenerating the condition into a plain catch check. The build actually under test was not established — no instrument available from the repo — so this stays an explanation, not a verified cause. The competing explanation (a value left over from a previous fish) was refuted: `CatchFishCondition` is gated on the `CatchFish` transition and consumes the catch-time `CaughtFish`, which `HandleCatchFish` rebuilds after the hook-time reset.
2. Side-effect improvement worth noting: the getter previously cast a `float?` to `int` directly, which would have thrown on a null accumulator. `UpdateXmas2017Stats` reads it on every kayak catch of an event fish category, so the null state was a latent crash during a New Year event; the `?? 0f` rewrite removes it. Reachable only through the same mid-fight restore path as F-1, so it is a hardening improvement rather than a fix for a live crash.
3. Unresolved hypothesis carried over from the delegated hunt, not promoted to a finding: in a fishing-together room a guest peer might not emit its own boat-travel transitions, which would leave the guest's accumulator at zero. Settling this needs runtime/protocol observation, which is unavailable here.
4. Cross-branch merge: none performed at close. The source is the Code-role branch, which has no upward targets, and the downward merge into the branch the 2026.5 release ships from was already done by the executor (MFT r16256) — so no `Merged →` line was claimed in the JIRA comment.
5. Release-step field (`customfield_11323`) left empty by user waiver: the reviewed diff is code-only (no `SQL/Patches`, `NoSql`, WebHooks/Twitch projects, or profile-conversion artifacts), so no option is derivable from it. The feature is inert until mission 3983 travels from QA to production, but mission content moves with the standard per-release DataPump step and is outside the server team's remit, so tagging this task with DataPump was judged noise rather than signal.
6. Considered and rejected: `RoomCatchFishCondition` has no drag-distance filter although `RoomCaughtFish` carries the value. Room conditions describe a catch made by another player in the room, where a drag-distance requirement has no meaning for the observer, and the ticket scopes the parameter to `CatchFishCondition`.
