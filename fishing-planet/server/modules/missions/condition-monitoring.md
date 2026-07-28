---
module: missions
title: 'Missions - condition monitoring and re-arming'
status: draft
---

# Missions — condition monitoring and re-arming

Why this doc exists: a whole family of mission bugs ("the task stopped reacting", "the counter froze at 1/5", "the achievement never completes") is invisible in any single file. It lives in *which dependencies a condition is currently watching*, and that set is **dynamic** — it shrinks and grows as a sequence walks forward and resets. This captures the mechanism, the contract that keeps it terminating, and the traps around it.

> **Draft.** Written from the FP-44392 review, which covered the condition-monitoring subsystem only. Everything below was verified by reading the code at the time of writing, by querying mission content, or empirically (build + test run, one reverse-merge experiment). NOT covered here and not verified: daily-mission generation, interactions, hints, profile persistence, the client mirror. Treat statements about those as absent, not as implied.

## The core idea

A condition is not polled. It is re-evaluated only when the processing loop decides the condition is *affected*, and that decision is a **string-key lookup**. `ConditionMonitoringSurface` holds a map from dependency key to the wrappers watching it; a raised key that matches nothing simply does nothing, silently.

So "the task stopped reacting" almost always decomposes into one of:

- the key that would have woken it is never raised;
- the key is raised but under a different string than the one registered;
- the condition is no longer watching that key at all, because its watched set narrowed.

The third is the one that produced FP-44392.

## Dependency keys

`ConditionMonitoringSurface.RegisterMonitoringDependecies` registers each dependency under either its bare name or, for **mission-bound** dependencies, `<dependency>/<missionId>` — where the mission id comes from the wrapper's own mission.

`IsMissionBoundDependency` decides by the *shape of the string*: an explicit list of mission-bound property names, anything starting with `#` (mission variables), and anything starting with `@` that contains no `/` (mission resources). Raising and registration must agree on this or the wake-up is lost.

Two normalisations matter:

- `Mission.AddResource` prepends `@` to a `ResourceKey` that lacks it. Content may therefore declare `ResourceKey: 'BluegillCounter'` and still end up mission-bound. Do not reason about a raw config value — reason about the normalised one.
- `MissionsContext.OnMissionDependencyChanged` appends `/<SelfMission.MissionId>` for you; `MissionsContext.OnDependencyChanged` does not. Raising a mission-bound key through the wrong one is a silent no-op.

## The dynamic watched set (this is the trap)

`SerialCondition.GetMonitoringDependencies` behaves differently before and after its dependency map is initialised. Once initialised, it reports the dependencies of steps `0 .. lastPassedIndex + 1` only — the step already reached, plus the one being waited for. Everything further down the sequence is *not* watched.

`SerialCondition.Reset()` sets `lastPassedIndex` back to `-1`. So immediately after a sequence completes an occurrence, the watched set collapses to the dependencies of **step 0 alone**.

Consequence, and the whole point of this document:

- If step 0 is the triggering event itself (a single-step `CatchFishCondition` serial, the shape in the manual's example), the collapsed set still contains the event, and the next event re-enters the sequence naturally.
- If step 0 is a *prerequisite* — `TaskCompletedCondition`, a level predicate, anything that does not change again — then after the collapse nothing the player does touches the task any more. It stalls permanently, showing whatever progress it had.

Multi-step sequences of exactly this shape are the norm in shipped content, not an edge case.

## Re-arming

To escape the collapse, `SerialAchievement` and `StepByStepAchievement` add one dependency to their watched set that is *always* present regardless of position: their own `ResourceKey` plus a suffix — `_SA` for `SerialAchievement` (a named constant), `_PA` for `StepByStepAchievement` (a repeated string literal, see backlog).

`MissionsContext.ReArm(mission, monitoringDependency)` schedules that key to be re-raised after the current processing cycle: it writes `<key>/<missionId>` into `dependenciesToRaiseAfterProcessing` with a synthetic `DependencyChange.Updated(0, 1)`. The value is a trigger only — no consumer reads `CurrentValue`/`OldValue`/`NewValue` anywhere in the repository; `OnDependencyChanged` reads only `IsChanged` (and `Name`, for idle-time bookkeeping). What the re-raise achieves is a pass in which the sequence walks step 0 again, which re-widens the watched set to include step 1 — the event — before the next event arrives.

**Re-arming must be unconditional.** Until FP-44392 it was a side effect of a successful counter increment, so an occurrence that completed *without* incrementing — a `UniqueBy` duplicate — completed, reset, and never re-armed. That is the FP-44392 stall: not "the duplicate wasn't counted" (correct behaviour) but "everything after the duplicate was lost".

## Order inside one processing pass

`MissionsManager.ProcessMessagesLoop`, in order:

1. `context.ResetIncrementedCounters()` — clears the per-pass counter sets **and** `dependenciesToRaiseAfterProcessing`. Anything pending from a previous pass that never drained is gone.
2. The cycle loop: affected missions → `ProcessForwardMissions` → per task, `RegisterProcessed(wrapper)` enforces **one check per request**; `ConditionMonitoringSurface.OnDependencyChanged` calls `UnregisterProcessed`, which is how a raised dependency earns a task a second look.
3. Hints, `FireEvents`.
4. `AfterProcessingCycle` event → transient state cleared (next section).
5. **Then** the drain: every pending re-arm key is raised via `OnDependencyChanged`.
6. `ScheduleProcessing?.Invoke()` if anything changed.

The ordering of 4 before 5 is load-bearing. It is what makes the re-raise land on a context where the triggering event is already gone, so the sequence walks forward instead of completing the same occurrence again.

Note the drain is not inside a `finally`. If hint processing or event firing throws, pending re-arms are dropped and then wiped by step 1 of the next pass — which reproduces the FP-44392 symptom from a different direction.

## The transient-state contract

`MissionsContext.AfterProcessingCycle()` clears `Transition`, `FormerTransition`, `Operation`, `ArgumentInt`/`ArgumentInt2`/`ArgumentString`, `Buoy`, `NavBuoy`, `InventoryItem`, `CaughtFish`, `RoomCaughtFish`, chum fields and the end-of-day / line-break flags.

It does **not** clear `Fish`, `IsInGame`, pond/boat state, inventory, mission variables or task-completed flags. A condition that can be satisfied purely from those survives the clear.

Who calls it in production:

- the game peer's missions wiring subscribes `AfterProcessingCycle` and calls it on the main context;
- the per-rod path clears each `RodInGameMissionsContext` (and restores that rod's `Fish`), wired per rod processor by the multi-rod processor.

There is exactly one production `new MissionsManager` — the game peer. Everything else that constructs one is a test.

## Termination, and why it is fragile

The re-arm edge is a feedback loop: `ReArm` → drain → dependency raised → task affected → `ScheduleProcessing` → another pass → possibly another `ReArm`.

It terminates because step 4 above removed the event that let the sequence complete. Nothing else bounds it — there is no iteration cap and no assertion of the contract.

The cost of getting that wrong is not a slow tick. Production `ScheduleProcessing` sets a flag, and the missions entry point ends with `if (executePostProcessing) { executePostProcessing = false; ProcessMissions(); }` — synchronous self-recursion on the same stack, the same shape as the test harness. An unbounded loop is therefore a `StackOverflowException`, which .NET does not let the surrounding `catch (Exception)` handle: the process dies, taking every player on the node.

Reachability at time of writing is content-limited: an unbounded loop needs an occurrence that re-completes without advancing the counter, i.e. a `UniqueBy` achievement whose terminal step survives `AfterProcessingCycle`. Content has one `UniqueBy` task and its terminal step is a `CatchFishCondition`, which returns false immediately when the context transition does not match. Without `UniqueBy` the counter advances and `Achieved >= Count` short-circuits. So: latent, and latent by content rather than by construction.

## Testing this subsystem

`MissionsTestHelper.CreateMissionsManager` sets `ScheduleProcessing` to call `ProcessMessagesLoop` directly — synchronous recursion — and does **not** subscribe `AfterProcessingCycle`. A test that exercises a re-arming achievement without adding

```csharp
manager.AfterProcessingCycle += (_, _, ctx) => ctx.AfterProcessingCycle();
```

models a server that never clears its transition, and will loop until the test host dies. That is not a red assertion — it is an aborted run, which reads as infrastructure flakiness.

The same omission also makes tests *silently wrong* rather than dead: without the clear, a single simulated catch can satisfy the same sequence several times in one pass, so a counter test "passes" by counting an event that would count once in production.

## Reading the traces

`SerialCondition.Check` emits a debug custom event on every position change, and the achievements emit one per increment. In a test run's standard output this is enough to diagnose a stall directly:

```
SerialPROGRESS: 0,  to 0 (PredicateCondition, ... "CatchFish"), TaskId: 1 ...   <- walked to step 0, waiting on the catch
SerialPROGRESS: 1,  to 1 (DONE), TaskId: 1 ...                                  <- sequence completed an occurrence
CounterIncremented: 1, ResourceKey: @SerialAchievement_1, Achieved: 1 ...       <- and it counted
```

A completed occurrence with **no** following `SerialPROGRESS: 0, to 0` is the signature of a missing re-arm — the sequence finished and was never walked back to its first step. If the `CounterIncremented` line is also absent, the occurrence was a `UniqueBy` duplicate.

## Known gaps in this area

All found during the FP-44392 review, all latent against content at time of writing, all routed to JIRA rather than to [backlog](backlog.md) — a reasonable configuration that silently does not work is an engine defect whether or not current content happens to use it:

- **FP-45259** — unconditional re-arm has no bound and no assertion of the transient-state contract; the test factory ships the crash-prone default (no `AfterProcessingCycle` subscription); `StepByStepAchievement` repeats its `_PA` suffix as a literal instead of a constant, where a mismatch would silently disable re-arming.
- **FP-45260** — `it.FishCategoryId` predicates register under a key nothing raises (`dependenciesMap` maps the other derived fish properties to `Fish`, not this one).
- **FP-45261** — `ResetOnFail` zeroes the counter but keeps the `UniqueBy` dedup list, making such a task unwinnable.

Full analysis, evidence and severities: [FP-44392 review](../../../review/FP-44392--uniqueby-serial-achievement/review.md).
