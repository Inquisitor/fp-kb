---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16252, merged to NPN20260602 @ r16253
jira: https://fishingplanet.atlassian.net/browse/FP-44758
---

# Review: FP-44758 — Mission variables sometimes being assigned with random values

## Summary

QA bug (ANNIVERSARY 2026): mission variables in mission 3966 receive seemingly random values (9/10/11 — fish weights another person assigned in the test config for a different mission's catches). Values survived a profile reset. No clear repro. Executor's diagnosis per JIRA comment: mission variables became shared between players on the same server ("shared across player clones"); fix landed on MFT and was merged to NPN.

## Scope

- **MFT20260325 r16252** — Fix mission variables shared across player clones (per JIRA comment; pending Phase 2 VCS audit)
- **NPN20260602 r16253** — Merge of r16252

## Investigation Journal

- Intake from JIRA: single fix commit r16252 (MFT) + merge r16253 (NPN) taken at face value from executor's comment; commit list pending `svn log | grep` audit.
- Executor field populated (Yuriy Burda), matches commit author claimed in JIRA comment.
- Branch-copy inheritance: NPN20260602 based on MFT20260325:16130; r16252 > 16130, so explicit merge to NPN was required — executor's merge r16253 consistent with ancestry.
- VCS audit (`svn log -r 16000:HEAD <branch-URL> | grep FP-44758` on MFT and NPN): exactly r16252 (fix) + r16253 (merge, confirmed via `svn log -r 16253`) — matches JIRA, no unposted commits. Adjacent r16254 is FP-44757 (separate related task adding a `UniqueBy` dedup isolation test) — out of scope here.
- WC freshness: `svn info --show-item revision` = 16351 ≥ 16252 — disk reads trustworthy.
- Root-cause mechanism verified in Mission.cs: `Clone()` is `MemberwiseClone`-based; the five variable dictionaries (`boolVariables`..`listVariables`, fields initialized inline, never null) were reference-copied → all per-player clones AND the cached definition shared the same `Mission*Resource` objects. `Set*Variable` on any clone wrote into the shared objects — explains both cross-player bleed and survival of profile reset (server-side `MissionCache` held the mutated definition).
- Per-player reachability verified: GameClientPeer_Missions.cs (`missionsManager` setup) → `MissionCache.GetAllMissions` → `Missions.Cache[languageId].Values.Select(m => (Mission)m.Clone())` — every player's regular mission is a `Clone()` of the cached definition, so the fix covers the bug path. `MissionCache.GetMission` returns the cached instance un-cloned but has no external callers (grep `MissionCache.GetMission(`) — only internal name-translation reads.
- Daily missions checked separately: `DailyMissionAdapter.GetCurrentMissions` builds missions from `Profile.DailyMissionContext.CurrentMissions` (per-player profile data, `ConvertToMission` creates fresh objects) — not affected by the shared-definition bug.
- Restore-after-clone order verified (fix does not break per-player variable persistence): `MissionsManager.Container_Initialize` runs `Init` + `ParseMissionPredicates` per mission (parser resolves `#`-variables via `MissionsSerializationUtils.GetMissionVariable` → `Get*VariableResource` lazily creates dictionary entries on the clone) BEFORE `Api_ResumeMission` → `LoadCountersAndVariablesAndInteractionsFromProfile`, which iterates existing keys and writes per-player values. Cache definition dictionaries stay empty (MissionCache.LoadAllMissions transfers conditions/resources/hints into the cached instance but not variable dictionaries).
- Resource `Clone()` depth verified: all five `Mission*Resource.Clone()` are `MemberwiseClone`-based; scalar payloads (bool/int/float/string) are immutable — sufficient; `MissionListResource.Clone()` additionally deep-copies `Items` via `ToList()` — sound.
- New test validity verified: `SetIntVariable` lazily adds to the dictionary; before the fix the add landed in the shared dictionary so clone B would read 42 (test fails), after the fix clones hold independent dictionaries (test passes). `ObjectModel.Tests.csproj` is SDK-style — the new file compiles without an explicit `<Compile Include>`.
- Cross-repo mirror check (diff touches `Shared/ObjectModel/`): client tree `Win64_MainClient/Assets/Photon Server Networking/ObjectModel/Mission/` contains only `MissionsContext.cs` + `MissionsResponse.cs` (DTOs); the server `Mission` class with `Clone()` is not source-duplicated to the client — no client mirror needed.
- Executor claims sweep: "variables shared between players on same server" (verified via shared-dictionary mechanism + GetAllMissions trace), "MFT @ r16252" and "Merged => NPN @ r16253" (verified via svn log) — all covered.
- Step 7 delegation: blind defect hunt dispatched to code-reviewer agent and Codex in parallel. Both independently confirmed the root-cause mechanism, the per-player reachability via `GetAllMissions`, test validity, and that no legitimate feature relied on the old sharing.
- Thread-safety (agent, accepted after reviewing its cited chain): cache refresh is a double-buffered swap under `refreshLock` (`Caches.RefreshCore`), `CachedEntity.Cache` special-cases loading-thread reads, and `WasPredicatesParsed` guards incremental re-parse — dictionary mutation on a shared master always completes before the instance is visible to `GetAllMissions`/`Clone()`. Codex independently found no in-repo concurrent-mutation path (its residual race hypothesis requires an external assembly mutating `MissionCache.GetMission` results — no such consumer exists in this repo).
- Re-verified Codex finding "BuyItemsHint shares lazy-init state": confirmed by reading BuyItemsHint.cs (five `readonly HashSet<int>` fields; `EnsureConfiguration` does Clear+repopulate with per-player context; `Clone()` resets only `RodResource`), BaseHint.cs (`Clone()` = MemberwiseClone), BuyItemsCondition.cs (`Clone()` re-clones the hint but sets stay shared). Pre-existing, unrelated to r16252's dictionaries → F-1.
- Re-verified Codex finding "TasksToCheck not remapped in Clone()": `TasksToCheck` is assigned only at runtime (`MissionsUtils.UpdateTasksToCheck`, `MissionsManager_Start`); the cached definition never starts, so it is null on the bug path — pre-existing contract gap only → F-2.
- Re-verified Codex finding "RandomArray shallow-clones Selected/Values": confirmed `Clone()` = MemberwiseClone, but both write paths (`Generate`, `IMissionResourceSerializable.Value` setter) REPLACE the array rather than mutate in place — no practical cross-clone effect today → F-3.
- Re-verified agent's unresolved "translations shared across clones": grep for `Translations.(Add|Remove|Clear|Insert|Sort)` in Shared — no mutating call sites; `SetTranslations` replaces the reference per-instance. Safe by design; hypothesis closed, no finding.
- TaskCreate tool unavailable in this environment — findings discussion round run inline instead (matches user's point-by-point preference).
- Findings discussion: F-1 and F-2 routed to missions module backlog (Clone Isolation section); user flagged possible escalation of F-1+F-2 into a single Filed JIRA — decision deferred to the end of the round. Sibling-hints shared-state audit dispatched to Codex in background per user request.
- Findings routing finalized: FP-45154 created (Bug, parent FP-44818 Technical Debt 2026 Q3, Scrum Team FPA, linked Relates to FP-44758) covering F-1 (+AssembleRodHint follow-up), F-2, F-3, and the F-4 test extension; missions backlog entries condensed to pointers at FP-45154.
- Sibling audit (Codex) returned: one new CONFIRMED — `AssembleRodHint.Clone()` leaves component `InventoryCondition` properties shared; `CheckRodComponent` → `condition.Hints` → `BaseHint.CheckCached` lazily writes `checkResult` into the shared hint (cross-player context-dependent cache bleed). Re-verified by reading AssembleRodHint.cs (`Clone` resets only `RodResource`; `CheckRodComponent` calls `condition.Hints.SelectMany(h => h.CheckCached(context))`) and BaseHint.cs (`CheckCached` lazy-caches). Carriers of the BuyItemsHint defect: AssembleRodCondition / BuyItemsCondition / HaveItemsCondition (own a constructor-created hint). All other BaseHint subclasses and condition classes clean, no unresolved. Backlog item extended accordingly (folded into F-1's routing rather than a new finding — same defect family, same fix locus).

## Findings

### F-1: `BuyItemsHint.Clone()` shares mutable lazy-init state across all clones [Medium]

**Description:** `BaseHint.Clone()` is a bare `MemberwiseClone`, so the five `readonly HashSet<int>` index fields of `BuyItemsHint` (rod/reel/line/leader/chum) remain shared between the cached definition's hint and every per-player clone; `BuyItemsHint.Clone()` resets only `RodResource`, not `configurationInitialized` and not the sets. `EnsureConfiguration` lazily does Clear+repopulate of those shared sets using the calling player's context, so two players initializing concurrently race on the same HashSets (undefined behavior on concurrent read/write; transiently wrong hint filters). Practical impact is bounded: the classification content is item-type-based and should be identical across players, so the harm window is concurrent initialization, not persistent corruption. Pre-existing — not introduced by r16252 and orthogonal to the variable dictionaries.

**Investigation:** Read BuyItemsHint.cs (fields, `EnsureConfiguration`, `Clone`), BaseHint.cs (`Clone` = MemberwiseClone), BuyItemsCondition.cs (`Clone` re-clones the hint; sets still shared) — confirmed statically. Reachability: `Mission.Clone()` clones Hints and Conditions per player; `BuyItemsCondition` embeds a generated `BuyItemsHint`. Race window recurs per clone: the cached definition never runs `Check`, so every fresh clone copies `ItemIds = null` + `configurationInitialized = false` and re-enters the Clear+repopulate branch on its first `BuyItemsHint.Check` — concurrently with other players' `Check` reading the same sets via `GetFilter`/`GetInitMessage` (`Contains`). Set content is config-deterministic: `EnumerateRequiredItems` yields the condition's configured `ItemId`/`ItemIds`, and `MissionInventoryContext.IsRod`/`IsReel`/etc. classify via the global item catalog (`ResolveItemGloablly`), not the player's inventory — so all players compute identical content and the harm is the concurrent mutation itself (possible corrupted-HashSet state persisting until the next mission-cache refresh, or a transient exception in the hint pipeline), not persistent wrong data. Sibling hints with `EnsureConfiguration` (TimeOfDayHint, GotoPondHint, MoveTimeWeatherHint, AssembleRodHint/AssembleRodCondition) not audited — flagged in the backlog item. Which live missions actually configure BuyItems hints not established (would need mission config data).

**Resolution:** Filed → FP-45154 (item 1; includes the follow-up audit's `AssembleRodHint` finding as item 2 and the carrier conditions).

**Discovered by:** Codex.

### F-2: `Mission.Clone()` neither resets nor remaps `TasksToCheck` [Low]

**Description:** `Clone()` deep-clones `Tasks` but leaves `TasksToCheck` pointing at the SOURCE mission's task objects (MemberwiseClone reference copy), so cloning a started mission would produce a clone whose check-list references foreign tasks. Unreachable on the current production path — only cached definitions are cloned and `TasksToCheck` is assigned exclusively at runtime (`MissionsUtils.UpdateTasksToCheck`, `MissionsManager_Start`), so it is null on the definition. Pre-existing contract gap of `Clone()`.

**Investigation:** Grep `TasksToCheck` across the repo — all writes are in runtime manager code, none in cache-load code; definition never starts. Codex flagged it; agent independently classified the field as always-null-on-template — both consistent with my grep.

**Resolution:** Filed → FP-45154 (item 3).

**Discovered by:** Codex.

### F-3: `RandomArray.Clone()` shallow-copies `Selected`/`Values` arrays [Info]

**Description:** `RandomArray.Clone()` is a bare `MemberwiseClone`, so clones initially share the `Selected` array (per-player persisted state via `IMissionResourceSerializable`). No practical effect today: both write paths (`Generate`, the serialization setter) replace the array reference instead of mutating in place, so a write on one clone cannot leak into siblings.

**Investigation:** Read RandomArray_Server.cs — `Generate` builds a new array (`result.Select(...).ToArray()`), the `Value` setter likewise (`Split(...).ToArray()`); no in-place element writes found.

**Resolution:** Filed → FP-45154 (item 4; latent-only, included for contract completeness).

**Discovered by:** Codex.

### F-4: New clone-isolation test covers only int/float scalars [Low]

**Description:** `MissionCloneTests.Clone_scalar_variables_should_not_be_shared_between_clones` guards int/float dictionary isolation but not bool/string/list, not definition-cache pollution (neither clone affecting the definition), and not nested-list mutation in `MissionListResource.Items`. Partially compensated: sibling task FP-44757 (r16254, out of this review's scope) adds a per-player `UniqueBy` dedup isolation test exercising list variables through the real mission pipeline.

**Investigation:** Read the test file; verified it fails pre-fix (lazy `Set*Variable` add landed in the shared dictionary, visible via clone B) and passes post-fix. Confirmed r16254 exists on MFT via `svn log` during the Phase 2 audit.

**Resolution:** Accepted for this review (non-blocking); test-extension work Filed → FP-45154 (test-coverage section).

**Discovered by:** Codex.

## Verdict

**approve.**

- The fix is correct, complete, and targeted: deep-cloning the five variable dictionaries in `Mission.Clone()` removes the only sharing path for per-player mission variable state. Root cause fully established (not symptom-level): `MemberwiseClone` reference-copied the dictionaries, so every per-player clone AND the cached definition shared the same `Mission*Resource` objects — explaining both the cross-player value bleed and the survival of a profile reset (the in-memory cache held the mutated definition). Confirmed independently by skill recon, the code-reviewer agent, and Codex.
- Reachability verified: `MissionCache.GetAllMissions` → `Clone()` is the only production hand-off of regular missions to players; daily missions are built per-player from the profile; `MissionCache.GetMission` has no gameplay callers.
- No regression risk found: predicate parsing repopulates clone-local dictionary keys before profile restore; resource `Clone()` depth is sound; thread-safety of cloning vs cache refresh verified (double-buffered swap under `refreshLock`).
- Regression test valid (fails pre-fix); list-variable isolation additionally exercised by sibling FP-44757 (r16254).
- Merge state: MFT r16252 → NPN r16253 already done by the executor, consistent with branch ancestry. No client mirror needed (server `Mission` class is not source-duplicated to the client).
- All findings (F-1..F-4) are pre-existing and out of the commit's scope — filed as FP-45154 (Technical Debt epic); none blocks approval.

**Verification scope:** mechanism proven statically plus by unit test; the original in-game QA scenario (mission 3966) was not re-reproduced — unnecessary, as the verified mechanism accounts for every reported symptom.
