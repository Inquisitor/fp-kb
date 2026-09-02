# FP-45122 Pin Tests Implementation Plan

> **STATUS: EXECUTED IN FULL** — SRV r16427 (all five tests), r16428 (contract-pin assert
> strengthening), r16429 (comment revision fix). The contract pin's harness deviated from Task 5
> as planned (temp player instead of the bit-rotted shared PlayAction harness — see the task
> journal, 2026-08-15..17). Kept as the record of what was planned; the journal records what ran.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write the five named pin tests promised in the FP-45122 protocol exchange — four KNOWN_DEFECT pins and one CONTRACT pin — so convention 9 stops being openly unmet.

**Architecture:** All tests land in `LoadBalancing.Tests` on branch NPN20260602. Four are pure Unit tests (FSM table, StrongFishEscapeModel, HitchGenerator, GameProcessor.Rollback via reflection); one is an Integrated wire-level test in `GameLogicTest` using the existing `PlayAction`/`NunitClient` harness. **Inverted TDD:** pin tests must PASS against today's defective code; they fail when someone fixes the pinned behavior, forcing a conscious revisit. Zero production-code changes.

**Tech Stack:** MSTest 2.2.10 (`Assert.ThrowsException` available), .NET Framework 4.7.2, C# 9, SDK-style csproj (new files auto-globbed — no csproj edit).

**Spec:**
- `D:\kb\fishing-planet\tasks\FP-45122--fish-fight-protocol\backlog.md` — the pin-test entry (names, StrongFishEscape toggle requirement)
- `D:\FishingPlanet\Dima\protocol-docs\fish-fight\reviews\2026-08-11-2208-srv-envelope-response.md` §6 — contract wording (both halves: applied = server keys only; swallowed = untouched echo)
- `D:\FishingPlanet\Dima\protocol-docs\fish-fight\design\divergence-policy.md` §4 — contract context (client fix CLN r56959 relies on it)

## Global Constraints

- Branch root: `D:\FishingPlanet\src\server\svn\branches\NPN20260602` — every path below is relative to it.
- Test names are committed verbatim in published exchange documents — do NOT rename or "improve" them.
- Tests must PASS on current code. A failing pin means a published claim is wrong — STOP and report; do not massage the test into passing.
- No production-code changes (no `private`→`internal`, no new hooks).
- Comments in English; Allman braces; 4-space indent; `var` accepted; no `this.`.
- After every Write/Edit on a source file: `unix2dos` (existing files) / `unix2dos --add-bom` (new files) — Write/Edit emit LF, .editorconfig mandates CRLF + UTF-8 BOM.
- Commit is performed by the USER. The plan only stages nothing and hands over a commit message (global convention).
- Verified code facts this plan relies on (all at current NPN working copy, 2026-08-15): `StateTransitions` FishFight row includes `StartDraw`; `TransitionTargets` maps `StartDraw → S.Draw`; `StrongFishEscapeModel.lastEscapeCheckTime` never assigned; `HitchGenerator.Unhitch` guard `lTf < 1f && hTf > 2f` with `Func<float> UnhitchProbability` injectable; `GameProcessor.Rollback` (private, GP:1524) dereferences `Header.IsFakeTransition` at first use and reads no instance state before it; `DoAfterTransition` calls `transitionData.Clear()` (GP:1940) only on the applied client path; `GameActionAdapter` attaches the same Hashtable to the response (GAA:175-176).

---

### Task 1: StartDraw FSM pin

**Files:**
- Modify: `Photon\src-server\Loadbalancing\LoadBalancing.Tests\GameLogicTests\GameStateTest.cs` (append test method before `/* Internal helper methods */`)

**Interfaces:**
- Consumes: existing `DoTransition(Transitions, GameStates)` helper in the same class.
- Produces: test `StartDraw_FromFishFight_EntersDraw_KNOWN_DEFECT_FP45122`.

- [ ] **Step 1: Add the test method**

```csharp
[TestMethod]
[TestCategory("Unit")]
public void StartDraw_FromFishFight_EntersDraw_KNOWN_DEFECT_FP45122()
{
    // KNOWN DEFECT (FP-45122): the Draw family is dead - the stock client never sends StartDraw
    // (though GameActionCode.StartDraw = 8 is alive on the wire) and no handler exists for any
    // Draw-family transition. Yet the whitelist keeps StartDraw reachable from FishFight, so a
    // modified client can park a fighting slot in Draw where the fight logic never runs.
    // Pins current behavior; protocol v2 removes the Draw family from the whitelist.
    DoTransition(Transitions.Throw, GameStates.Cast);
    DoTransition(Transitions.Water, GameStates.Move);
    DoTransition(Transitions.Move, GameStates.Move);
    DoTransition(Transitions.Attack, GameStates.Attack);
    DoTransition(Transitions.FinishAttack, GameStates.AttackFinished);
    DoTransition(Transitions.HookFish, GameStates.FishFight);
    DoTransition(Transitions.StartDraw, GameStates.Draw);
}
```

- [ ] **Step 2: Line endings**

Run: `unix2dos "<branch>\Photon\src-server\Loadbalancing\LoadBalancing.Tests\GameLogicTests\GameStateTest.cs"`

- [ ] **Step 3: Run (after Task 6 build) and verify PASS**

Run: `dotnet test --no-build Photon\src-server\Loadbalancing\LoadBalancing.Tests\LoadBalancing.Tests.csproj --filter "FullyQualifiedName~StartDraw_FromFishFight"`
Expected: PASS (transition accepted, state == Draw).

---

### Task 2: StrongFishEscape dead-throttle pin (with the feature toggle)

**Files:**
- Modify: `Photon\src-server\Loadbalancing\LoadBalancing.Tests\GameLogicTests\StrongFishEscapeTest.cs` (append test method before `CallAction`)

**Interfaces:**
- Consumes: `StrongFishEscapeModel.InjectGlobals(int, int, int, float)`, `TurnOn()/TurnOff()`, `DT.Helper.Now` injection (existing `TestCleanup` already calls `DT.Helper.Reset()`).
- Produces: test `StrongFishEscape_RollsOnEveryMessage_KNOWN_DEFECT_FP45122`.

- [ ] **Step 1: Add the test method**

```csharp
[TestMethod]
[TestCategory("Unit")]
public void StrongFishEscape_RollsOnEveryMessage_KNOWN_DEFECT_FP45122()
{
    /* Arrange */
    // min == max makes the randomized fishMaxFightTimeout deterministic (Interpolate returns x1)
    StrongFishEscapeModel.InjectGlobals(30, 60, 60, 0.5f);
    var sut = new StrongFishEscapeModel();
    var now = DateTime.UtcNow;
    DT.Helper.Now = () => now;

    sut.SetPlayerForce(1f);
    sut.StartFishFight(4f);      // 1 / 4 = 0.25 < limitForce 0.5 -> strong fish
    now = now.AddSeconds(91);    // past guaranteed fight (30 s) + full timeout (60 s) -> 100% escape branch

    // The IsStrongFishEscapeOn toggle gates every escape: while it is off in the DB the model
    // never fires, so fixing the dead throttle below changes nothing on such an environment.
    StrongFishEscapeModel.TurnOff();
    Assert.IsFalse(sut.TryEscapeFish());
    StrongFishEscapeModel.TurnOn();

    /* Act & Assert */
    // KNOWN DEFECT (FP-45122): lastEscapeCheckTime is never assigned, so the 1-second
    // EscapeCheckTimeout throttle is dead and the escape roll runs on every client message
    // (~5/s) instead of once per second. A working throttle would fail the second assert.
    Assert.IsTrue(sut.TryEscapeFish());
    now = now.AddMilliseconds(200);
    Assert.IsTrue(sut.TryEscapeFish());

    sut.EndFishFight();
}
```

- [ ] **Step 2: Line endings**

Run: `unix2dos "<branch>\...\GameLogicTests\StrongFishEscapeTest.cs"`

- [ ] **Step 3: Run and verify PASS**

Run: `dotnet test --no-build ...\LoadBalancing.Tests.csproj --filter "FullyQualifiedName~StrongFishEscape_RollsOnEveryMessage"`
Expected: PASS. (Static `isOn` left on — same as every existing test in this class; each test arranges the toggle itself; MSTest runs sequentially here, no `[Parallelize]` attribute and no runsettings parallelization.)

---

### Task 3: Jerk-unhitch guard pin

**Files:**
- Create: `Photon\src-server\Loadbalancing\LoadBalancing.Tests\GameLogicTests\HitchGeneratorTest.cs`

**Interfaces:**
- Consumes: `HitchGenerator(CurrentGameConfig, RodInGameConfig, Random, Action<HintCode, string>, Func<SplatMap>, Action<string>)`; `CurrentGameConfig.UnhitchProbability` is a settable `Func<float>`; `HitchBox { CanBreak, MaxLoad }` from `ObjectModel.Game`; `GenerateHitch(HitchBox)` leaves `hitchTime` at `default(DateTime)`, so the `MinHitchTime` (0.5 s) window is already over.
- Produces: test `JerkUnhitch_RollsWithoutLowTerminalForce_KNOWN_DEFECT_FP45122`.

- [ ] **Step 1: Create the file**

```csharp
using System;
using GameModel;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using ObjectModel.Game;
using Photon.LoadBalancing.GameLogic;

namespace LoadBalancing.Tests.GameLogicTests
{
    [TestClass]
    public class HitchGeneratorTest
    {
        [TestMethod]
        [TestCategory("Unit")]
        public void JerkUnhitch_RollsWithoutLowTerminalForce_KNOWN_DEFECT_FP45122()
        {
            /* Arrange */
            // Probability 1 removes the RNG from the roll: the outcome depends on the force guard alone.
            var config = new CurrentGameConfig { UnhitchProbability = () => 1f };
            var sut = new HitchGenerator(config, new RodInGameConfig(config), new Random(1), (code, message) => { }, () => null, null);
            sut.GenerateHitch(new HitchBox { CanBreak = false, MaxLoad = 100f });

            /* Act & Assert */
            // No pull above HighHitchForce (2f) - the jerk branch stays closed.
            Assert.IsFalse(sut.Unhitch(0f, 1.5f));

            // KNOWN DEFECT (FP-45122): the jerk guard is lowTerminalTackleForce < LowHitchForce (1f)
            // && highTerminalTackleForce > HighHitchForce (2f). Production clients always send
            // lowTerminalTackleForce == 0 (client lTf bug, dead for 10 years), which satisfies the
            // slack half trivially - "unhitch by jerk" degenerates into "unhitch by pulling hard".
            // A guard demanding a real measured slack would fail this assert.
            Assert.IsTrue(sut.Unhitch(0f, 2.5f));
        }
    }
}
```

- [ ] **Step 2: Line endings + BOM (new file)**

Run: `unix2dos --add-bom "<branch>\...\GameLogicTests\HitchGeneratorTest.cs"`

- [ ] **Step 3: Run and verify PASS**

Run: `dotnet test --no-build ...\LoadBalancing.Tests.csproj --filter "FullyQualifiedName~JerkUnhitch_RollsWithoutLowTerminalForce"`
Expected: PASS. If `CurrentGameConfig`'s parameterless ctor or log4net's unconfigured `DebugUtility` surprises at runtime, report — do not stub production classes.

---

### Task 4: Rollback armed-NRE pin

**Files:**
- Create: `Photon\src-server\Loadbalancing\LoadBalancing.Tests\GameLogicTests\GameProcessorRollbackTest.cs`

**Interfaces:**
- Consumes: private `GameProcessor.Rollback(TransitionContext, out string)` via reflection; `FormatterServices.GetUninitializedObject` (net472, fine) — legitimate here because `Rollback` reads no instance state before the pinned throw (verified: static `TryExtractFishingCycleFromRequest`, then `Header` deref at GP:1531).
- Produces: test `Rollback_ServerTransitionWithoutHeader_KNOWN_DEFECT_FP45122`.

- [ ] **Step 1: Create the file**

```csharp
using System;
using System.Collections;
using System.Reflection;
using System.Runtime.Serialization;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Photon.LoadBalancing.GameLogic;

namespace LoadBalancing.Tests.GameLogicTests
{
    [TestClass]
    public class GameProcessorRollbackTest
    {
        [TestMethod]
        [TestCategory("Unit")]
        public void Rollback_ServerTransitionWithoutHeader_KNOWN_DEFECT_FP45122()
        {
            // KNOWN DEFECT (FP-45122): Rollback dereferences transitionContext.Header.IsFakeTransition
            // unconditionally, while every server-initiated PerformTransition passes header == null.
            // The NRE is unreachable today only because all eight server-side callers are guarded;
            // it arms the moment one more server transition is added without a guard, and the NRE
            // then masks the InvalidTransition it was supposed to explain.
            // Rollback reads no instance state before the throw, so an uninitialized instance suffices.
            var processor = (GameProcessor)FormatterServices.GetUninitializedObject(typeof(GameProcessor));
            var rollback = typeof(GameProcessor).GetMethod("Rollback", BindingFlags.NonPublic | BindingFlags.Instance);
            Assert.IsNotNull(rollback);

            var context = new TransitionContext
            {
                FormerState = GameStates.FishFight,
                Transition = Transitions.UnHitch,   // a live rollback-table row: returns Move once Header is guarded
                TransitionData = new Hashtable(),
                Header = null,                      // how every server-internal transition arrives
            };

            var ex = Assert.ThrowsException<TargetInvocationException>(
                () => rollback.Invoke(processor, new object[] { context, null }));
            Assert.IsInstanceOfType(ex.InnerException, typeof(NullReferenceException));
        }
    }
}
```

- [ ] **Step 2: Line endings + BOM (new file)**

Run: `unix2dos --add-bom "<branch>\...\GameLogicTests\GameProcessorRollbackTest.cs"`

- [ ] **Step 3: Run and verify PASS**

Run: `dotnet test --no-build ...\LoadBalancing.Tests.csproj --filter "FullyQualifiedName~Rollback_ServerTransitionWithoutHeader"`
Expected: PASS (TargetInvocationException wrapping NullReferenceException).

---

### Task 5: transitionData contract pin (Integrated)

**Files:**
- Modify: `Photon\src-server\Loadbalancing\LoadBalancing.Tests\GameLogicTests\GameLogicTest.cs` (append test method after `ResetScenario`; the single-arg `PlayAction(Action<NunitClient>)` helper lives in this class at line ~391)

**Interfaces:**
- Consumes: `PlayAction(Action<NunitClient>)` (this class); `NunitClient.SendGameAction(GameActionCode, Hashtable, ErrorCode)` returning `OperationResponse`; `client.RodSlot`; wire keys `"sN"` (slot; the client sends it in every request, the server never writes it into a rebuilt table) and `"pP"` (player position); `client.Reset()`.
- Produces: test `TransitionDataClear_AppliedTransitionIsNotEcho_CONTRACT_FP45122`.

- [ ] **Step 1: Add the test method**

```csharp
[TestMethod]
[TestCategory("Integrated")]
public void TransitionDataClear_AppliedTransitionIsNotEcho_CONTRACT_FP45122()
{
    // CONTRACT (FP-45122, declared in the protocol exchange 2026-08-12): the response to an
    // APPLIED client transition consists of server keys only - DoAfterTransition clears the
    // request table before calling the handlers. The response to a silently SWALLOWED
    // transition is the untouched echo of the request. The client distinguishes the two
    // outcomes by exactly this difference (client fix CLN r56959), so this behavior is
    // load-bearing until the v2 envelope ships an explicit receipt.
    PlayAction(client =>
    {
        const string canary = "__fp45122Canary";

        // Applied transition: Initial -> Throw -> Cast
        var appliedData = new Hashtable();
        appliedData["sN"] = client.RodSlot;
        appliedData["pP"] = new Point3(0, 0, 0);
        appliedData[canary] = "sent-by-client";
        var applied = client.SendGameAction(GameActionCode.Throw, appliedData);
        var appliedResponse = (Hashtable)applied.Parameters[(byte)ParameterCode.GameActionData];
        Assert.IsFalse(appliedResponse.ContainsKey(canary), "applied response must be rebuilt by the server, not echo the request");
        Assert.IsFalse(appliedResponse.ContainsKey("sN"), "client-sent sN must not survive the rebuild");

        // Swallowed transition: a second Throw from Cast is eaten by the ignore window
        // (budget 3) and comes back ReturnCode 0 with the client's own table, verbatim.
        var echoData = new Hashtable();
        echoData["sN"] = client.RodSlot;
        echoData["pP"] = new Point3(0, 0, 0);
        echoData[canary] = "sent-by-client";
        var swallowed = client.SendGameAction(GameActionCode.Throw, echoData);
        var swallowedResponse = (Hashtable)swallowed.Parameters[(byte)ParameterCode.GameActionData];
        Assert.AreEqual("sent-by-client", swallowedResponse[canary], "swallowed response must be the untouched request echo");
        Assert.IsTrue(swallowedResponse.ContainsKey("sN"));

        // Return the slot to Initial for the tests that follow
        client.Reset();
    });
}
```

- [ ] **Step 2: Line endings**

Run: `unix2dos "<branch>\...\GameLogicTests\GameLogicTest.cs"`

- [ ] **Step 3: Run and verify PASS — needs the local stack**

`TestCategory=Integrated` connects a real `NunitClient` to the local Master/Game servers with the local `Main` DB. Run only with the local stack up:
`dotnet test --no-build ...\LoadBalancing.Tests.csproj --filter "FullyQualifiedName~TransitionDataClear_AppliedTransitionIsNotEcho"`
Expected: PASS. If the stack is not running, hand the test to the user to run in their usual local loop — do NOT mark the task complete on compilation alone; say explicitly the Integrated pin is unverified.

---

### Task 6: Build, full-suite sanity, review, commit-message handoff

- [ ] **Step 1: Build the solution (background, takes minutes)**

Run: `MSBuild.exe Photon\src-server\Loadbalancing\LoadBalancing.sln -restore -p:Configuration=Debug -p:NuGetAudit=false -m -v:minimal`
Expected: exit 0 (capture the real msbuild exit code, not the pipeline tail's).

- [ ] **Step 2: Run all five pins + the full Unit suite**

Run: `dotnet test --no-build ...\LoadBalancing.Tests.csproj --filter "FullyQualifiedName~FP45122&TestCategory=Unit"`
Expected: 4 passed (the Integrated pin runs per Task 5 Step 3).
Run: `dotnet test --no-build ...\LoadBalancing.Tests.csproj --filter "TestCategory=Unit"`
Expected: no regressions vs a pre-change baseline run (capture the baseline BEFORE editing).

- [ ] **Step 3: Verify encodings**

Run: `unix2dos -i` on all five touched files. Expected: CRLF, BOM present on every file.

- [ ] **Step 4: Adversarial review before the user reads**

Dispatch the reviewer agent on the full diff (task: refute, not confirm — check every pinned claim against the code, check the tests would actually FAIL under the corresponding fix). Try Codex as the second reviewer; if workspace credits are still exhausted, proceed single-reviewer and say so.

- [ ] **Step 5: Hand over the commit message (user commits; svn add for new files may be staged only if the user asks)**

```
[FP-45122] Pin tests for known fight defects and the transitionData contract
+ Added StartDraw_FromFishFight_EntersDraw_KNOWN_DEFECT_FP45122 to GameStateTest: dead Draw family reachable from FishFight
+ Added StrongFishEscape_RollsOnEveryMessage_KNOWN_DEFECT_FP45122 to StrongFishEscapeTest: dead 1s throttle plus the IsStrongFishEscapeOn gate
+ Added HitchGeneratorTest with JerkUnhitch_RollsWithoutLowTerminalForce_KNOWN_DEFECT_FP45122: lTf == 0 satisfies the slack half of the jerk guard
+ Added GameProcessorRollbackTest with Rollback_ServerTransitionWithoutHeader_KNOWN_DEFECT_FP45122: armed NRE on unguarded server transitions
+ Added TransitionDataClear_AppliedTransitionIsNotEcho_CONTRACT_FP45122 to GameLogicTest: applied responses are server-rebuilt, swallowed ones echo the request
```

**Follow-ups (post-commit, not part of this plan):** short letter to `protocol-docs` announcing the pins exist (with the SVN revision) so the exchange documents' "the test itself is not in the tree yet" clauses can be retired; JIRA comment per the merge-comment standard; journal/backlog update in the KB card.
