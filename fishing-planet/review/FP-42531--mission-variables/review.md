---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r15972, r15975, r15984, r15986, r15994
jira: https://fishingplanet.atlassian.net/browse/FP-42531
---

# FP-42531: ANNIVERSARY 2026 — Server: Mission Variable Functionality

## Summary

Umbrella story for the Anniversary 2026 (ex. Father's Day) event: make the mission-variable
functionality of the mission system actually work and extend it enough to author the event's
mission scenarios. Per the ticket, variables were non-functional in their current state.

Target scenarios named in JIRA:
- "catch 5 different fish species" (unique-value counting)
- "using the event bobber, catch 5 fish in a row, each heavier than the previous"
- Norwegian missions — buoy approach/departure shown once per state change, without relying on side effects
- persisting interactive-object state across long-start (e.g. a player device cycling `1 => 2 => 3 => 1`)
- broadly: allow variables as `...Condition` parameters

Fix Version: 2026.5 Anniversary (ex.Fathers Day), release date 2026-07-29.

## Scope

### MFT20260325
- **r15972** — Add list variable type (`#l`) and `UniqueBy` to mission system
  - New `MissionListResource` (`List<int>` with `Add`/`AddUnique`/`Remove`/`Contains`), `#l` prefix wired into `GetMissionVariable`
  - `VariableSet`/`VariableReset` moved from `AssembleRodCondition` up to `BaseCondition`, which now implements `IMissionControlObject`
  - `UniqueBy` on `SerialAchievement` — dedups counter increments by a compiled `MissionsContext` property accessor, backed by a hidden `#l_unique_{TaskId}` variable
  - Method-call syntax in `VariableSet` (`#lVar.AddUnique(expr)`) via `VariableAssignment.MethodExecutor` + `IMissionResourceWithMethods`
  - List variables persisted through `StartedMission.ListVariables`
- **r15975** — Add `ResetOnFail` on `SerialAchievement`, dynamic task descriptions with variable patterns
  - `MissionClientUtils.ResolveVariablesInText` — `{#var}`, `{#var:Format}`, `{#var:Format:fallback}`, `[#var?text]`; applied to task `Name`/`Description` on both client-conversion paths and to `TaskName` in mission events
  - `UpdateVariables` split — `ResetVariables` extracted and reused by the `ResetOnFail` path
- **r15984** — Fix `FormatMessageTest_Length` static leak, extract `MissionsTestHelper` to avoid duplicate test runs
- **r15986** — Add `ShowOnTransition` on hints to skip repeated hints on each state change
- **r15994** — Add `VariableSet` on `MissionInteraction` and `InteractiveObject` event bridge
  - `MissionInteraction` implements `IMissionControlObject`; `BaseMissionInteraction.Execute` fires `UpdateVariables`
  - New `InteractWithObjectEventCondition`; `InteractiveAdapter` sets `MissionsContext.Transition`/`ArgumentInt` on a click

> Audited against `svn log -r 15943:HEAD <MFT> | grep FP-42531`. The audit surfaced a sixth commit, **r15996**, whose message carries this task's ID — it is excluded from scope (see Notes).

## Investigation Journal

- Intake from JIRA comments only (Phase 1 invariant): five commits, all on MFT, posted across four comments by the executor.
- Executor field (`customfield_11224`) is populated — Yuriy Burda — matching the commit author in the comments. No hygiene nudge needed.
- Related open reviews by the same executor touch the same subsystem and may overlap in scope — to check in Phase 2: `FP-44392--uniqueby-serial-achievement` (UniqueBy, introduced here at r15972), `FP-44761--fail-task-mission-restart`, `FP-44859--stale-condition-refresh`, `FP-44413--reissued-mission-task-state`, `FP-44667--keep-tracked-on-restart`.
- Executor's closing comment states the task ends here and that further improvements go into separate tickets ("деякі уже написані") — the follow-up reviews above are likely those.
- **r15996 attribution.** `svn blame` on `Shared/ObjectModel/Mission/ConditionsGame/BuoyConditions.cs` shows the `IFishBasicPredicate` declarations on `BaseBuoyCondition`/`HasBuoyCondition` were introduced at **r15995**, and `svn log -r 15995` shows r15995 is `FP-42746 Add fish-aware buoy mission conditions`. r15996 splits `IFishCondition` into `IFishBasicPredicate` + `IFishCondition` and adds `TakeBuoyConditionTests` — i.e. it completes r15995, not r15994. Dropped from scope; belongs to FP-42746.
- **WC freshness.** WC is at r16364, ahead of every reviewed revision, so disk reads are safe for HEAD-state checks but not for reviewed-revision content; diffs were dumped per revision to `artifacts/` and used as the source of truth.
- **`Mission.Clone()` variable sharing.** `svn blame` on `Mission.cs` dates the deep-clone of `boolVariables`/`intVariables`/`floatVariables`/`stringVariables`/`listVariables` to **r16252** (FP-44758). At r15972 none of the variable dictionaries were deep-cloned, so `listVariables` merely joined a pre-existing sharing bug rather than creating one — and it is fixed at HEAD.
- **Delegated review (mandatory independent pass).** Blind defect hunt run in parallel by the `code-reviewer` agent and by Codex (`gpt-5.6-sol`, read-only). They converged on six of the findings below and diverged on three, each resolved by first-hand verification: the `@Resource.Method(...)` unwrap regression (agent only — confirmed by reading `GetMissionResourceProperty` + `BoxGeometry_Server.Value`), the `ResetOnFail`-vs-wait interaction (agent only — confirmed by reading `SerialCondition.Check`), and the `languageId = 0` default (Codex refuted my recon hypothesis — confirmed refuted, see below).
- **`languageId = 0` hypothesis disproven.** Recon flagged `profile?.LanguageId ?? 0` as a wrong default (`SharedConsts.DefaultLanguageId` is 3). The installed formatter — the only production assignment of `HintMessage.FormatValue`, at `GameClientPeer_Missions.cs` — does `measuring.ChangeMeasuringSystem(languageId == 0 ? SharedConsts.DefaultLanguageId : languageId)`. Zero is mapped correctly; not a defect.
- **`#l_unique_{TaskId}` reset on mission fail/restart — hypothesis disproven.** `MissionsManager_Fail.Api_RemoveFailedMission` calls `mission.LoadCountersAndVariablesAndInteractionsFromProfile(new StartedMission())`, and the `listVariables` loop r15972 added to `MissionsProfileUtils` clears `Items` when the profile has no entry. The dedup set does not survive a fail/restart.
- **Method-call exposure query (severity input for F-2).** Counted method-call occurrences across `Missions` / `MissionTasks` / `MissionHintMessages` `ConfigJson`: `.Contains(` 735 total, fully accounted for by `it.CompletedMissions` (372), `it.StartedMissions` (217) and `it.InventoryIds`-style context collections (146 — sampled and confirmed); `.Intersects(`, `.ToString(`, `.Equals(`, `.StartsWith(`, `.EndsWith(`, `.GetProgress(`, `.Check(`, `.Clone(`, `.Any(`, `.IndexOf(` — all zero. `parsePredicateRegex` (`[@#][\w\d_\.]+`) only routes `@`/`#`-prefixed tokens into `GetMissionResourceExpression`, so context-collection calls never reach the changed branch. No content currently exercises it.
- **Test run.** `dotnet test --no-build --filter FullyQualifiedName~ObjectModel.Tests.Mission` on the current local Debug build: 156 passed, 0 failed.
- **Executor documentation claim verified.** Confluence "Mission System Manual" (page 194445313) contains authored sections for `UniqueBy`, `ResetOnFail`, `ShowOnTransition` and `VariableSet` with mission examples. The `#l` list type and the `#lVar.Method(arg)` call syntax are not documented (`AddUnique` has zero occurrences on the page).
- **Duplicate check before filing.** Before creating the follow-up, the epic `Technical Debt - 2026 Q3` (FP-44818) and a keyword JQL sweep were checked against every finding. Two were already filed by earlier reviews of the same subsystem: F-5 matches FP-45261 (from the FP-44392 review) almost verbatim, and F-8 is item 3 of FP-45162 (from the FP-44668 review), down to the same suggested fix. Both were dropped instead of re-filed. FP-45259 and FP-45260, also under that epic, were read and confirmed distinct — FP-45259 covers re-arm boundedness and the test factory (it already names `MissionsTestHelper` from r15984), FP-45260 covers the `FishCategoryId` dependency mapping.
- **Content exposure (local dev copy of `Main`, patches applied through `MFT.M.2026.07.07-026`).** Counted usages in `MissionTasks.ConfigJson` / `Missions.ConfigJson` / `MissionHintMessages.ConfigJson`: `UniqueBy` 1 task; `ResetOnFail` 0; `ShowOnTransition` 0; `#l` list variables 0; `{#…}` text patterns 0; `VariableSet` 48 tasks + 7 missions. Caveat: this binds to the content snapshot at that patch level — the Anniversary event ships 2026-07-29 and its missions may not be in this copy, so a zero here is not proof of zero exposure at release.

## Findings

### F-1: `VariableSet` authored on a condition is a silent no-op unless the condition is a direct child of a `SerialAchievement` [Medium]

**Description:** r15972 moved `VariableSet`/`VariableReset` from `AssembleRodCondition` up to `BaseCondition` and made `BaseCondition` implement `IMissionControlObject`, so every condition type now accepts and round-trips these properties in JSON. But the statements are only executed at four call sites, and only one of them covers conditions: `SerialAchievement.Check` iterating `Conditions.OfType<IMissionControlObject>()` — its **direct** children. A `VariableSet` on a task's top-level `CompleteCondition`, on a predicate nested one level deeper inside an `AndCondition`, on a `DisplayCondition`, or on a `WaitWhileCondition` parses without error and never runs. No warning, no exception.

**Investigation:**
- Grepped `MissionsUtils.UpdateVariables` across the whole branch: four call sites — `HintMessage_Server.UpdateVariables`, `BaseMissionInteraction.Execute`, `AssembleRodCondition` (its own), `SerialAchievement.Check`. Conclusion: no generic condition-level dispatch exists.
- Read `SerialAchievement.Check` at HEAD — the loop is over `Conditions`, not a recursive walk. Conclusion: nesting is not covered.
- Checked `AndCondition`: implements `IComplexMissionCondition`, not `IMissionControlObject`. Conclusion: composite conditions do not forward the call.
- Content query (see journal): 48 tasks and 7 missions carry `VariableSet`; 44 of the 48 co-occur with `SerialAchievement`, 4 with `AssembleRod`. Conclusion: existing content sits on the working paths — the gap is a trap for new authoring, not a live break.

**Resolution:** Filed → FP-45263 (item 1). Either dispatch `UpdateVariables` generically when a condition transitions to satisfied, or reject/warn at parse time when `VariableSet` sits on an unsupported position. The event's own scenarios ("feed each cat the right fish") are exactly the shape that would hit this.

**Discovered by:** skill recon, independently confirmed by code-reviewer agent and Codex.

### F-2: The new `IMissionResourceSingleValue` unwrap branch changes method dispatch for every single-value resource, breaking previously valid `@Resource.Method(...)` expressions [Medium]

**Description:** In `MissionsSerializationUtils.GetMissionResourceExpression`, the `ownMethod` branch previously emitted `Expression.Constant(resource)` — the resource itself as the method receiver. r15972 replaced that with an unconditional unwrap to `((IMissionResourceSingleValue)resource).Value` cast to the runtime type of the current value, for **any** `IMissionResourceSingleValue`, not just the new list type. `GetMissionResourceProperty` sets `ownMethod` for any public method on the resource type, and `BoxGeometry` is both an `IMissionResourceSingleValue` (its `Value` is `Name ?? ResourceKey`, a string) and inherits the public `Box.Contains(Point3)`. So `@Zone.Contains(it.TacklePosition)` now binds against `string`, fails to parse, and throws `MissionParseException` out of `Container_Initialize`, which does not wrap `ParseMissionPredicates` in a try/catch.

**Investigation:**
- Read `GetMissionResourceProperty` — `resource.GetType().GetMethod(propertyName)` sets `ownMethod = true` for any public method. Conclusion: the branch is reachable for every resource type with a public method, not only lists.
- Read `BoxGeometry_Server.cs` — `BoxGeometry : IMissionResource, IMissionResourceSingleValue` with `Value => Name ?? ResourceKey`; `Box.Contains(Point3)` is public. Conclusion: the receiver type changes from `BoxGeometry` to `string`.
- Read `parsePredicateRegex` (`[@#][\w\d_\.]+`) and `PreparePredicateExpresisonWithExpressionVariables` — confirms `@Zone.Contains` is captured as the resource path with the argument list left outside, so `strs[1] == "Contains"` resolves as a method. Conclusion: the trace is complete, not speculative.
- Read `MissionsManager.Container_Initialize` — `ParseMissionPredicates(mission)` is called inside the loop with no try/catch in the method itself. Conclusion: a parse failure escapes past the single mission. (Callers further up the stack were not inspected.)
- Content query (see journal): every `.Contains(` occurrence in shipped mission JSON is on an `it.`-prefixed context collection, which the regex never routes into this method; all other method names score zero. Conclusion: exposure is currently nil, which is why nothing broke when MFT shipped FTUE.

**Resolution:** Filed → FP-45263 (item 3). Restrict the unwrap to `IMissionResourceWithMethods` (or to `MissionListResource`), which is all the feature needed. Latent today, but it silently disarms a documented authoring form.

**Discovered by:** code-reviewer agent (Codex found only the adjacent null-`Value` case).

### F-3: In-place list mutations report `IsChanged == false`, so nothing that depends on a list variable is re-evaluated [Medium]

**Description:** `MissionListResource` exposes its live `Items` list through `IMissionResourceSingleValue.Value`. In `MissionsUtils.UpdateVariables`, the method-executor branch captures `oldValue = variable.Value` **before** `MethodExecutor` mutates that same list in place, then builds `DependencyChange.Updated(oldValue, variable.Value)` from two references to the same object. `ResetVariables` has the same shape (`ResetValue()` calls `Items.Clear()` on the same instance). The resulting `DependencyChange<object>.IsChanged` is `!NewValue.Equals(OldValue)` — false for a self-comparison — and `MissionsContext.OnDependencyChanged` early-outs on `same`, so neither `dependenciesChanged` nor the `DependencyChanged` event fires. A `#lIds.Add(42)` persists to the profile but wakes nothing.

**Investigation:**
- Read `MissionListResource.Value` getter — returns `Items` directly, no copy. Conclusion: `oldValue` aliases the mutated instance.
- Read `DependencyChange.Updated<T>` and `DependencyChange<T>.IsChanged` — with both operands typed `object` the generic overload is selected and `IsChanged` reduces to `!NewValue.Equals(OldValue)`, i.e. reference equality for `List<int>`. Conclusion: always false after in-place mutation.
- Read `MissionsContext.OnDependencyChanged` — `same = !change.IsChanged` gates every subsequent effect (`stateTime`, `changes`, `dependenciesChanged`, `DependencyChanged`). Conclusion: the notification is fully suppressed.
- Scalar variables are unaffected: boxed `int`/`float`/`bool` and immutable `string` produce a genuinely different `oldValue`. Conclusion: the defect is specific to the type introduced here, which is also why the accompanying tests do not catch it.
- Content query: zero `#l` variables in shipped content. Conclusion: latent.

**Resolution:** Filed → FP-45263 (item 2). Snapshot the list (`Items.ToList()`) before mutating, or have `MissionListResource` report change explicitly (e.g. `AddUnique`'s existing bool return).

**Discovered by:** code-reviewer agent and Codex independently (agent rated it Critical, Codex Medium; the zero content exposure is what settles it at Medium).

### F-4: `ShowOnTransition` hints bypass the `TimesToShow` cap [Medium]

**Description:** The `ShowOnTransition` branch in `MissionsManager_Hints.ProcessHints` ends in `continue`, which skips the rest of the loop body — including `if (prev == null && message.TimesToShow > 0) message.Mission.IncrementHintShownTimes(message);`. That call is the only writer of the shown-times counter, and the gate that enforces the cap reads `mission.GetHintShownTimes(message) < message.TimesToShow`. A hint authored with `ShowOnTransition = true` and `TimesToShow = 1` — the natural "show this once on entering the zone" combination, both content-settable — therefore re-fires on every false→true transition forever. The same `continue` also skips `message.ChangedExecutionNextTime = false`, leaving that flag latched.

**Investigation:**
- Read `ProcessHints` at HEAD — confirmed the `continue` precedes both the `IncrementHintShownTimes` call and the `ChangedExecutionNextTime` reset in the same loop body.
- Grepped `IncrementHintShownTimes` / `GetHintShownTimes` across `Shared/ObjectModel` — one writer (the skipped call), one reader (the cap gate). Conclusion: skipping the writer disables the cap entirely.
- Content query: zero hints currently carry `ShowOnTransition`. Conclusion: latent, and the feature is new, so no regression to existing hints.

**Resolution:** Filed → FP-45263 (item 8). Move the counter bookkeeping above the `continue`, or fold the transition check into the existing send condition instead of short-circuiting the loop.

**Discovered by:** skill recon, independently confirmed by code-reviewer agent and Codex.

### F-5: `ResetOnFail` zeroes the counter but leaves the `UniqueBy` dedup set populated [Medium]

**Description:** The reset path in `SerialAchievement.Check` sets `Achieved = 0`, persists the counter and calls `ResetVariables` for the child conditions' authored `VariableReset` lists, but never clears `mission.GetListVariableResource(uniqueByVariableKey)`. With both flags on — `UniqueBy` + `ResetOnFail`, which is exactly the "catch N different fish in a row" shape the ticket asks for — the two halves of the same progress state reset inconsistently: after a reset, previously counted values are still duplicates, so the player must find a full set of brand-new values to finish. For a small value domain the task becomes uncompletable.

**Investigation:**
- Read the r15975 reset block and the r15972 `UniqueBy` block in `SerialAchievement.Check`: the dedup list is written on increment and cleared nowhere in the reset path.
- Checked the other reset route for contrast: `Api_RemoveFailedMission` wipes the list via the empty-`StartedMission` load. Conclusion: the mission-level reset is consistent; the condition-level one is not.
- Content query: `ResetOnFail` is unused in shipped content, `UniqueBy` used once (without `ResetOnFail`). Conclusion: latent, but the combination is a named target scenario of this ticket.

**Resolution:** Filed → FP-45261 — already raised verbatim from the FP-44392 review before this card was written; no duplicate created.

**Discovered by:** code-reviewer agent and Codex independently.

### F-6: `ResetOnFail` cannot distinguish "a later condition failed" from "the serial advanced and is waiting" [Low]

**Description:** The reset guard is `ResetOnFail && Achieved > 0 && LastPassedIndex > passedIndexBeforeCheck`. `SerialCondition.Check` advances `lastPassedIndex` for every condition that passes and returns `false` both when a later condition genuinely failed **and** when it is legitimately waiting (`ShouldWaitSerial` / `WaitWhileCondition` — the engine's own "hold the position" path). A multi-step serial that passes its first condition and then waits for the second therefore satisfies the guard and destroys the accumulated streak.

**Investigation:**
- Read `SerialCondition.Check`: `lastPassedIndex = i` on each pass; the wait branch deliberately leaves the position untouched and falls through to `return false`. Conclusion: `LastPassedIndex > passedIndexBeforeCheck` is true in the wait case, and the guard has no way to tell the two apart.
- Termination of the recursive `return Check(context)` checked separately: `Achieved = 0` is assigned before recursing and the guard requires `Achieved > 0`, so depth is bounded at two. Not a defect.
- The executor's `ResetOnFailTests` all use single-tick serials where both conditions evaluate in the same pass, so the wait path is never exercised. Content exposure is zero.

**Resolution:** Filed → FP-45263 (item 6). Gate the reset on an actual failure signal rather than on positional advance.

**Discovered by:** code-reviewer agent.

### F-7: The `UniqueBy` dedup set is keyed only by `TaskId`, so sibling achievements in one task share it [Low]

**Description:** `SerialAchievement.Init` derives the hidden variable name as `string.Format("#l_unique_{0}", task.TaskId)`, while the counter it guards is keyed by `ResourceKey`. Those two keys agree only by accident: `Init` also auto-fills an empty `ResourceKey` with `@SerialAchievement_{TaskId}`, so unnamed siblings in one task already share a counter and the shared dedup list merely matches that pre-existing behaviour. The genuine defect is the narrow case where an author gives two `SerialAchievement`s in the same task **distinct explicit** `ResourceKey`s: the counters separate, the dedup list does not, and a value counted by one silently blocks the other. An authored variable literally named `#l_unique_<taskId>` would alias the same state.

**Investigation:**
- Read `SerialAchievement.Init` — the dedup key derives from `task.TaskId` only; no `ResourceKey`, `oid` or instance discriminator participates.
- Read the same method's first lines (`svn blame`: r4262, long predating this work) — an empty `ResourceKey` is auto-filled with `@SerialAchievement_{TaskId}` and `mission.AddResource(this)` registers it. Conclusion: same-task siblings without explicit keys already collide on the counter, so the dedup list adds no new limitation there; the defect narrows to the explicit-key case.
- Read `Mission.Init` — the synthetic start/archive/fail tasks use `TaskId` `-1`/`-2`/`-3`, so mission-level conditions do not collide with task-level ones. Conclusion: the collision is confined to same-task siblings.
- Content query: one `UniqueBy` usage overall (mission 3948 / task 15656, no explicit `ResourceKey`). Conclusion: no current collision.
- Migration impact of a future key change, checked because the one live usage is already in production: the counter lives in `StartedMission.Counters[ResourceKey]` and the dedup set in `StartedMission.ListVariables`, restored by separate loops in `LoadCountersAndVariablesAndInteractionsFromProfile`. Renaming the dedup key therefore leaves `Achieved` intact and only empties the dedup set — already-counted values become countable again, i.e. the task gets easier, not broken, and the orphaned entry disappears on the next `SaveToProfile` (which rebuilds the dictionary from `mission.listVariables`). Conclusion: self-healing, no migration measures needed. To be re-verified when the fix is actually implemented.

**Resolution:** Filed → FP-45263 (item 7). Derive the key from `ResourceKey` (guaranteed non-empty after the auto-fill), which makes it agree with the counter's key by construction.

**Discovered by:** skill recon, independently confirmed by code-reviewer agent and Codex.

### F-8: `ResolveVariablesInText` early-returns on text that uses only the conditional-block syntax [Low]

**Description:** The guard is `if (string.IsNullOrEmpty(text) || !text.Contains("{#")) return text;`, but pass 1 of the method handles `[#var?text]`, which contains `[#`, not `{#`. A task name or description written as `"Catch a fish[#bBonusActive? (bonus round!)]"` is returned untouched and the raw authoring markup is rendered to the player, on every path that resolves task text.

**Investigation:** Read `MissionClientUtils.ResolveVariablesInText` at HEAD — the guard tests one prefix while `conditionalBlockRegex` matches the other; nothing else re-enters the method. Content query: zero task texts currently contain either pattern. Conclusion: mechanically certain, currently unreachable.

**Resolution:** Filed → FP-45162 (item 3) — already raised from the FP-44668 review, with the same fix direction; no duplicate created.

**Discovered by:** code-reviewer agent and Codex independently.

### F-9: The method-call detection heuristic misroutes any argument containing `=` [Low]

**Description:** `MissionsParser.ParseVariablesStatements` classifies a statement as a method call with `trimmed.StartsWith("#") && trimmed.Contains("(") && !trimmed.Contains("=")`. An argument with a comparison — `#lIds.Add(it.FishId == 7 ? 1 : 0)` — contains `=`, so it is routed to `ParseVariableStatement`, split at the comparison's first `=`, and fails mission parsing instead of reaching `ParseMethodCallAssignment`.

**Investigation:** Read the r15972 heuristic and `ParseMethodCallAssignment`'s regex (`^(#[\w\d_]+)\.(\w+)\((.+)\)$`), which would have matched the statement correctly had it been routed there. Conclusion: the misroute is in the classifier, not the parser. Content exposure zero (no list-method statements authored).

**Resolution:** Filed → FP-45263 (item 4). Classify by matching the method-call regex first and falling back to assignment parsing.

**Discovered by:** Codex (also flagged in skill recon).

### F-10: `ParseMethodCallAssignment` ignores the predicate cache it is handed [Low]

**Description:** The method takes a `PredicateCache` parameter and never reads or writes it, unlike its siblings `ParsePredicateExpression` and `ParseVariableStatement`, which exist precisely to avoid re-parsing (they clone the cached delegate and rebind its closure). `Container_Initialize` parses predicates for every active mission, and `Mission.Clone()` clears `WasPredicatesParsed`, so every `#lVar.Method(expr)` statement costs a full `DynamicExpressionParser.ParseLambda` plus `Compile()` on each player's login path.

**Investigation:** Read `ParseMethodCallAssignment` in the r15972 diff and at HEAD — the `cache` parameter is unused; compared against the two sibling parsers that do use it. Content exposure zero.

**Resolution:** Filed → FP-45263 (item 5), same method as F-9.

**Discovered by:** code-reviewer agent.

### F-11: A variable change did not refresh already-sent task text [Info]

**Description:** r15975 resolves `{#var}` patterns at DTO-construction time only. Nothing connected a variable change to re-sending an already-delivered task, so a task displaying `Catch {#iTrack}` kept stale text until it happened to progress.

**Investigation:** `svn blame` on `MissionsManager_Processing.cs` dates `ResendTaskNamesForChangedVariables` to **r16273**, and `svn log -r 16273` shows `FP-44668 Resend HUD task names when a rendered variable changes`. Read the method at HEAD: it iterates the active mission's tasks and re-sends when `IsVariableReferencedInText(task.Name, v)` — `task.Description` is not checked. Conclusion: the gap this review would have raised was closed by a later, separately-ticketed change; the residual `Description` gap belongs to that ticket, not this one.

**Resolution:** Skipped — superseded by r16273 (FP-44668).

**Discovered by:** Codex.

## Notes

- r15996 carries `FP-42531` in its commit message and was not posted to JIRA. Its content (splitting `IFishCondition` into `IFishBasicPredicate` + `IFishCondition`, plus `TakeBuoyConditionTests`) completes **r15995 = FP-42746**, and the parenthetical "(add missing files on commit)" points at r15994, which it does not relate to. Wrong task ID and misleading message; excluded from this review's scope.
- The `#l` list variable type and the `#lVar.Method(arg)` call syntax are absent from the Mission System Manual, while `UniqueBy`, `ResetOnFail`, `ShowOnTransition` and `VariableSet` are documented with examples.

## Verdict

Approve.

The five commits deliver what the story asked for: mission variables work, the target authoring forms exist, each feature ships with tests, and the Mission System Manual was extended with examples. Nothing found is blocking, and nothing regresses live content.

Every finding is latent against the current content snapshot: `#l` list variables, `ResetOnFail`, `ShowOnTransition` and `{#...}` text patterns have zero usages, and `UniqueBy` has one (which FP-44392 already covered separately). Routing: F-5 and F-8 turned out to be already filed by earlier reviews (FP-45261 from FP-44392, FP-45162 from FP-44668); the rest went into a single new follow-up, FP-45263. No reopen.

The Anniversary release ships from this branch, and its named scenarios map onto the weakest paths found — F-1 and F-3 sit under "track a set and test a predicate on it", F-5 and F-6 under "N in a row, each heavier". Those pairs become reachable the moment event content adopts list variables or `ResetOnFail`; with the release the next day there is no room for a pre-release check, so they ride on the follow-up.

**Verification scope:** the review verified mechanism, not behaviour in a running game. Findings rest on static traces through the reviewed diffs plus HEAD state, on `svn blame`/`svn log` for provenance, and on content-exposure queries against a local dev copy of `Main` patched through `MFT.M.2026.07.07-026`. The mission test suite passes on the current local build (156 tests). Not verified: the features end-to-end in a live client session, the event scenarios themselves, and content added after that patch level — a zero exposure count here is not proof of zero exposure at release.
