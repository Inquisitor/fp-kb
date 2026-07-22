---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16254, merged to NPN20260602 @ r16255
jira: https://fishingplanet.atlassian.net/browse/FP-44757
---

# Review: FP-44757 — [Anniversary][Missions] Same fish type counted multiple times in LONE STAR LAKE — Worm Wisdom

## Summary

QA bug: during the mission LONE STAR LAKE — Worm Wisdom the same fish species (Redear Sunfish) was counted multiple times toward the mission species counter; expected each species to count once. Per the executor's comment, the root cause is fixed under the linked ticket (FP-44758); this task adds test coverage — "test for per-player UniqueBy dedup isolation".

## Scope

- **MFT20260325 r16254** — Add test for per-player UniqueBy dedup isolation
  - New test `UniqueBy_dedup_should_be_independent_across_player_clones` in `Shared/ObjectModel.Tests/Mission/UniqueByTests.cs`
  - Regression cover for the FP-44758 root-cause fix (r16252: `Mission.Clone()` deep-clones variable dictionaries)
- **NPN20260602 r16255** — Merge of r16254

Post-commit modifications of the reviewed test (context, other tickets):
- **MFT r16257** — merge of NPN r16180 (FP-44392 `SerialAchievement` re-arm fix + two-step tests inserted into the same file)
- **MFT r16259** — "FP-44392 Fix StackOverflowException in UniqueBy dedup isolation test": added the missing `AfterProcessingCycle` wiring to the reviewed test

## Investigation Journal

- Intake: executor's comment claims root cause is handled in the linked FP-44758 ("Root cause - linked") — confirmed: MFT r16252 (FP-44758) deep-clones `boolVariables`/`intVariables`/`floatVariables`/`stringVariables`/`listVariables` in `Mission.Clone()`; FP-44757 carries only the test.
- VCS audit: `svn log -r 16000:HEAD <MFT-URL> | grep FP-44757` → only r16254; `svn log -r 16131:HEAD <NPN-URL> | grep FP-44757` → only r16255 (merge). Matches JIRA comment exactly; no unposted FP-44757-tagged commits.
- WC freshness: `svn info --show-item revision` → r16351 ≥ r16254 — disk reads trustworthy.
- File history check (`svn log -r 16254:HEAD` on `UniqueByTests.cs`): the reviewed test was modified after the reviewed commit by r16257 (FP-44392 merge) and r16259 (StackOverflow fix, tagged FP-44392) — HEAD version differs from the r16254 diff by the `AfterProcessingCycle` subscription on both managers.
- Dedup mechanism traced (target: does the test exercise the fixed path; instrument: source read of `SerialAchievement.cs`, `MissionListResource.cs`, `Mission.cs` r16252 diff): `SerialAchievement.Init` registers `#l_unique_{taskId}` via `mission.GetListVariableResource` (stored in `Mission.listVariables`); `Check()` calls `listVar.AddUnique` inside the `ProcessMessagesLoop` evaluation path (not in `AfterProcessingCycle`); `MissionListResource.Clone()` deep-copies `Items` (`Items.ToList()`). Conclusion: pre-r16252 both player clones share one `MissionListResource` → player A's `AddUnique(101)` suppresses player B's increment → final assert fails; post-r16252 dictionaries and resources are per-clone → test passes. The test verifies the isolation property it claims.
- StackOverflow mechanism traced (target: why r16254's version broke after the FP-44392 merge; instrument: source read of `MissionsManager_Processing.cs`, `MissionsContext.ReArm`/`AfterProcessingCycle`, `MissionsTestHelper.cs`): FP-44392 added `context.ReArm(...)` on every completed occurrence; re-arm deps drain after the processing loop and trigger `ScheduleProcessing`, which `MissionsTestHelper` wires as a synchronous recursive `ProcessMessagesLoop()`. Without the `AfterProcessingCycle` handler clearing `Transition`/`Fish`, the serial re-completes on every recursion (duplicate re-arms without counting) → unbounded recursion → `StackOverflowException`. r16259 added the handler, matching every other test in the file.
- Empirical run at HEAD (target: "tests added" implies passing; instrument: MSBuild Debug + `dotnet test --no-build --filter FullyQualifiedName~UniqueByTests` at WC r16351): 7/7 passed.
- Revert experiment (target: regression value — the test must fail on pre-fix code; instrument: `svn merge -c -16252` on `Mission.cs` in WC, rebuild, same test run; user-approved WC mutation): reviewed test failed exactly at player B's assert (`Expected:<1>. Actual:<0>`), other 6 tests stayed green — the isolation property is covered only by this test. `svn revert` + rebuild + rerun → 7/7 green, WC clean.
- Delegation round (code-reviewer agent + Codex, blind, parallel). Disagreements resolved by instrument, not majority:
  - Codex finding "definition cloned uninitialized, resource-level isolation untested" (Medium) — refuted: `OrderHintsAndInteractions` calls `mission.Init(visitor)` (`MissionsSerializationUtils.cs`), so `#l_unique_1` exists on the definition pre-clone; agent's independent trace concurs. Considered-and-rejected.
  - Codex claim "r16254 method materially unchanged at HEAD" — refuted by the r16259 diff (two `AfterProcessingCycle` lines added inside the method body).
  - Codex recount-path mechanism — verified: `LoadCountersAndVariablesAndInteractionsFromProfile` replaces or clears listVariable `Items` (`MissionsProfileUtils.cs`); called with `new StartedMission()` from `MissionsManager_Complete`/`_Fail`, so pre-fix any player's mission start/resume cleared the shared dedup set → the QA "counted again" symptom.
  - Agent production-topology claim — verified: `MissionCache.GetAllMissions` clones the cached master; `ResolveFish` runs `mission.Init(visitor)` on the master at load (`MissionCache.cs`). Test mirrors Init-before-Clone.
- Findings discussion round (user, per finding): F-1 kept Low / Skipped — superseded by r16259; F-2 downgraded Low → Info (recount ⇒ shared instance ⇒ suppression assert trips — coverage transitively complete) / Accepted; F-3 Skipped; F-4 Accepted.

## Findings

### F-1: Test as committed broke under the already-pending FP-44392 re-arm change [Low]

**Description:** The r16254 version of `UniqueBy_dedup_should_be_independent_across_player_clones` omitted the `AfterProcessingCycle` subscription that every sibling test in `UniqueByTests.cs` wires. Pre-FP-44392 this was benign, but the executor's own FP-44392 fix (NPN r16180, merged to MFT as r16257 sixteen minutes after r16254) made `SerialAchievement.Check` re-arm on every completed occurrence; with `MissionsTestHelper` wiring `ScheduleProcessing` as a synchronous recursive `ProcessMessagesLoop()` and no handler clearing `Transition`/`Fish`, the serial re-completes on every recursion → `StackOverflowException`. Patched same day by r16259 under the FP-44392 tag.

**Investigation:** r16254 vs HEAD file compare exposed the added subscription; `svn log -r 16254:HEAD` on the file attributed it to r16259 "Fix StackOverflowException in UniqueBy dedup isolation test"; recursion mechanism traced through `SerialAchievement.Check` (`ReArm`), `MissionsManager_Processing` (post-loop drain → `ScheduleProcessing`), `MissionsTestHelper` (synchronous recursive wiring), `MissionsContext.AfterProcessingCycle` (clears `Transition`/`Fish`).

**Resolution:** Skipped — superseded by r16259 (fixed before this review).

**Discovered by:** skill recon.

### F-2: The literal QA symptom (species counted again) is described in the test comment but not exercised [Info]

**Description:** The test comment promises two pre-fix failure modes — cross-player suppression AND "when a concurrent load clears the shared set, letting already-counted species count again" (the actual FP-44757 QA symptom). The body exercises only suppression (player B's first catch must count). The recount direction — pre-fix, `LoadCountersAndVariablesAndInteractionsFromProfile` clearing/replacing the shared `Items` on another player's mission start/resume — is not reproduced. Both symptoms share the one root cause (shared clone state) that the test does cover empirically, and any regression re-enabling recount requires a shared resource instance, which necessarily also trips the tested suppression assert — coverage is transitively complete; the residual issue is comment precision only.

**Investigation:** Comment text vs body compared in the r16254 diff; recount mechanism verified in `MissionsProfileUtils.LoadCountersAndVariablesAndInteractionsFromProfile` (listVariables loop replaces `Items` from profile or clears them) and its `new StartedMission()` call sites in `MissionsManager_Complete`/`_Fail`; suppression direction empirically proven by the revert experiment.

**Resolution:** Accepted — severity settled at Info in the discussion round (Codex's Medium rejected: it did not account for recount implying suppression).

**Discovered by:** code-reviewer agent + Codex (independently); mechanism verified by skill recon.

### F-3: Isolation test is not self-contained against a disabled-dedup regression [Info]

**Description:** The test's observable outcome (A=1, B=1) also holds if `UniqueBy` dedup stops working entirely — neither player catches a duplicate of their own, and player A's state is never re-asserted after B acts. Sibling tests in the class (`UniqueBy_same_fish_should_not_increment` etc.) cover dedup-off regressions suite-wide, so this is hardening, not a gap in practice. Cheap fix if ever desired: B catches #101 twice (assert still 1) and A's counter re-asserted at the end.

**Investigation:** Body inspection of the r16254 diff (no same-player duplicate, no trailing A assert); sibling coverage confirmed by the HEAD run (7/7, includes same-player dedup tests).

**Resolution:** Skipped — sibling tests in the class cover dedup-off regressions; no action needed.

**Discovered by:** Codex (self-containment) + code-reviewer agent (bidirectional re-assert).

### F-4: Fixture shape diverges from the reported mission (FishId vs FishCategoryId, single-step serial) [Info]

**Description:** The isolation test dedups by `FishId` on a single-condition serial, while the real Worm Wisdom mission is a two-step serial deduping by `FishCategoryId` (per the FP-44392 tests in the same file). The clone-sharing mechanism is key-agnostic (same `#l_unique_{taskId}` list-variable machinery), so the regression cover is valid; the literal production shape combined with two player clones remains uncovered.

**Investigation:** `UniqueBy = "FishId"` in `CreateUniqueFishMission` vs `FishCategoryId` in `CreateTwoStepUniqueFishMission` (same file); key-agnosticism confirmed in `SerialAchievement.Init` (uniform accessor compilation + list-variable registration regardless of key).

**Resolution:** Accepted — deliberate unit-test tradeoff, consistent with the rest of the file.

**Discovered by:** code-reviewer agent + Codex.

## Notes

- FP-44757's JIRA comment does not mention that the reviewed test was subsequently patched (r16259, tagged FP-44392) — a reviewer walking only FP-44757's commits reviews a stale version of the test. (executor-quality)

## Verdict

**Approve.**

- The commit does what it claims: adds a regression test for per-player `UniqueBy` dedup isolation — the property broken by the shared root cause and fixed under FP-44758 (r16252).
- Regression value proven empirically: 7/7 at HEAD; with r16252 reverted the test fails precisely at player B's assert and is the only test in the suite that does.
- Production fidelity verified: Init-before-Clone topology mirrors `MissionCache` (master `Init` at load, `Clone` per player fetch).
- Findings: F-1 Low (r16254 fragility, superseded by r16259 same day), F-2/F-4 Info accepted, F-3 Info skipped — none blocking, no rework requested.

Verification scope: the test's discriminating power and the isolation property were verified empirically (HEAD run + revert experiment); the literal QA recount symptom has no direct repro but is transitively covered (any sharing regression trips the suppression assert). The root-cause fix itself (r16252) is FP-44758's review scope, not covered by this verdict.
- Client-mirror check (Step 6): diff touches only `Shared/ObjectModel.Tests/` (test project, not distributed to the client) — no mirror needed.
