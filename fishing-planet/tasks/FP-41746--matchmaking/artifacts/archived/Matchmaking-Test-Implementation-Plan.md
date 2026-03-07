# Matchmaking Test Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement comprehensive test coverage for Phase 6 matchmaking features (FFS algorithm, group budget allocation, reassignment) per [Matchmaking-Test-Plan.md](Matchmaking-Test-Plan.md).

**Architecture:** Extract `PartitionAllBuckets` and `ReassignGroupsToBuckets` from `BuildGroups` for testability, then add unit/integration/e2e tests using `MatchmakingTestCase` notation parser. TableGen test generates designer-facing TSV table.

**Tech Stack:** C# 9 / .NET Framework 4.7.2, MSTest, `MatchmakingTestCase` parser (already built).

**JIRA:** FP-41746 (refactoring), FP-41833 (tests)

**Build note:** CLI build is broken. After code changes, ask the user to rebuild in IDE, then run `dotnet test --no-build`.

---

## Task 1: Extract `PartitionAllBuckets` from `BuildGroups`

**Files:**
- Modify: `Shared/SharedLib/Tournaments/MatchmakingLogic.cs:233-308`

**Step 1: Add `PartitionAllBuckets` method**

Add the following `internal static` method before `BuildGroups` (around line 233):

```csharp
/// <summary>
/// Partitions all non-empty buckets into groups according to the grouping rule.
/// In MaxGroupCount mode, uses the FFS algorithm to allocate group budget.
/// In per-bucket mode, each bucket independently determines its group count.
/// </summary>
internal static List<TournamentGroup> PartitionAllBuckets(
    List<TournamentBucket> nonEmptyBuckets, TournamentGroupingRule grouping)
{
    if (grouping.MaxGroupCount.HasValue)
    {
        // MaxGroupCount mode: FFS algorithm allocates group budget across buckets.
        var groupCounts = AllocateGroupBudget(
            nonEmptyBuckets, grouping.MaxGroupCount.Value,
            grouping.MinSize, grouping.TargetSize);

        return nonEmptyBuckets
            .Select((bucket, i) => PartitionBucket(bucket, groupCounts[i]))
            .SelectMany(g => g)
            .ToList();
    }
    else
    {
        // Per-bucket mode: each bucket independently determines its group count.
        // No-split rule: the lowest bracket cannot be split if it contains moved players.
        return nonEmptyBuckets
            .Select(bucket => PartitionBucket(bucket,
                IsNoSplitBucket(bucket)
                    ? 1
                    : ComputeGroupCount(bucket.Participants.Count,
                        grouping.MinSize, grouping.TargetSize, grouping.MaxSize)))
            .SelectMany(g => g)
            .ToList();
    }
}
```

**Step 2: Update `BuildGroups` to call `PartitionAllBuckets`**

Replace lines 238–261 of `BuildGroups` (the `List<TournamentGroup> groups;` block) with:

```csharp
var groups = PartitionAllBuckets(nonEmptyBuckets, grouping);
```

The full `BuildGroups` method should now look like:

```csharp
internal static TournamentGroup[] BuildGroups(
    IEnumerable<TournamentBucket> buckets, TournamentGroupingRule grouping)
{
    var bucketsList = buckets.ToList();
    var nonEmptyBuckets = bucketsList.Where(b => b.Participants.Count >= 1).ToList();

    var groups = PartitionAllBuckets(nonEmptyBuckets, grouping);

    // Re-evaluate parent buckets for groups after balancing.
    // ... (lines 263-297 unchanged for now) ...

    // Assign group names.
    var index = 0;
    foreach (var group in groups)
    {
        group.Name = GetGroupNameByIndex(index);
        ++index;
    }

    return groups.ToArray();
}
```

**Step 3: Verify — ask user to rebuild, run all existing tests**

```
dotnet test --no-build Shared/SharedLib.Tests/SharedLib.Tests.csproj
```

Expected: ALL existing tests pass (pure extract-method refactoring).

**Step 4: Commit**

Commit message for FP-41746.

---

## Task 2: Extract `ReassignGroupsToBuckets` from `BuildGroups`

**Files:**
- Modify: `Shared/SharedLib/Tournaments/MatchmakingLogic.cs`

**Step 1: Add `ReassignGroupsToBuckets` method**

Add after `PartitionAllBuckets`:

```csharp
/// <summary>
/// Re-evaluates parent buckets for groups based on median participant rating.
/// Clears all bucket participants and reassigns them from groups.
/// Sets <see cref="TournamentGroupParticipant.IsMoved"/> for out-of-range participants.
/// </summary>
/// <param name="groups">Groups produced by <see cref="PartitionAllBuckets"/>.</param>
/// <param name="allBuckets">ALL buckets (including empty), needed because a group's
/// median rating may fall into an empty bucket's range.</param>
internal static void ReassignGroupsToBuckets(
    List<TournamentGroup> groups, List<TournamentBucket> allBuckets)
{
    foreach (var bucket in allBuckets) bucket.Participants.Clear();
    foreach (var group in groups)
    {
        // Get the median rating value of the participants in the group.
        var medianRating = group.Participants.OrderBy(p => p.CompetitionRating)
            .Skip(group.Participants.Count / 2)
            .First()
            .CompetitionRating;

        // Find the bucket where the median rating belongs.
        var parentBucket = allBuckets.First(
            g => g.MinRating <= medianRating && g.MaxRating >= medianRating);

        // Link group with its parent bucket and add participants.
        group.BracketId = parentBucket.BracketId;
        parentBucket.Participants.AddRange(group.Participants);
        parentBucket.Groups.Add(group);

        // Set the IsMoved flag on all participants that don't fit
        // into the parent bucket by rating.
        foreach (var participant in group.Participants)
        {
            if (participant.CompetitionRating < parentBucket.MinRating ||
                participant.CompetitionRating > parentBucket.MaxRating)
                participant.IsMoved = true;
        }
    }

    // Re-sort all bucket participants by rating.
    foreach (var bucket in allBuckets)
    {
        bucket.Participants = bucket.Participants
            .OrderBy(p => p.CompetitionRating)
            .ToList();
        bucket.UpdateRatings(true);
    }
}
```

**Step 2: Update `BuildGroups` to call `ReassignGroupsToBuckets`**

Replace lines 263–297 (the reassignment block) with:

```csharp
ReassignGroupsToBuckets(groups, bucketsList);
```

The full `BuildGroups` method is now:

```csharp
internal static TournamentGroup[] BuildGroups(
    IEnumerable<TournamentBucket> buckets, TournamentGroupingRule grouping)
{
    var bucketsList = buckets.ToList();
    var nonEmptyBuckets = bucketsList.Where(b => b.Participants.Count >= 1).ToList();

    var groups = PartitionAllBuckets(nonEmptyBuckets, grouping);

    ReassignGroupsToBuckets(groups, bucketsList);

    // Assign group names.
    var index = 0;
    foreach (var group in groups)
    {
        group.Name = GetGroupNameByIndex(index);
        ++index;
    }

    return groups.ToArray();
}
```

**Step 3: Verify — ask user to rebuild, run all existing tests**

```
dotnet test --no-build Shared/SharedLib.Tests/SharedLib.Tests.csproj
```

Expected: ALL existing tests pass.

**Step 4: Commit**

Commit message for FP-41746.

---

## Task 3: Add `SetupFromTestCase` test helper

**Files:**
- Modify: `Shared/SharedLib.Tests/Tournaments/MatchmakingLogicTests.cs`

**Step 1: Add `SetupFromTestCase` helper method**

Add inside the `#region Helpers and constants` section (after `GetTestGroupingRuleWithFiveBrackets`):

```csharp
/// <summary>
/// Converts <see cref="MatchmakingTestCase"/> notation into tournament objects
/// suitable for calling <see cref="MatchmakingLogic.AllocateGroupBudget"/>,
/// <see cref="MatchmakingLogic.PartitionAllBuckets"/>, and
/// <see cref="MatchmakingLogic.ReassignGroupsToBuckets"/>.
/// </summary>
/// <remarks>
/// Creates N brackets with rating ranges [0–99], [100–199], ..., [(N-1)*100, MaxValue].
/// For NoSplit buckets (marked with <c>!</c>), adds one participant with rating above
/// MaxRating so that <see cref="MatchmakingLogic.IsNoSplitBucket"/> returns true.
/// Returns ALL buckets (including empty) for ReassignGroupsToBuckets.
/// </remarks>
private static (TournamentBucket[] allBuckets, TournamentGroupingRule rule)
    SetupFromTestCase(MatchmakingTestCase testCase)
{
    var inputBuckets = testCase.Input.Buckets;
    int n = inputBuckets.Count;

    // Create brackets with non-overlapping ranges.
    var brackets = new List<TournamentBracket>(n);
    for (int i = 0; i < n; i++)
    {
        brackets.Add(new TournamentBracket
        {
            BracketId = i + 1,
            BracketName = $"Bracket{i + 1}",
            MinRating = i * 100,
            MaxRating = i < n - 1 ? (i + 1) * 100 - 1 : int.MaxValue,
            RatingMultiplier = 1.0,
            RewardMultiplier = 1.0,
        });
    }

    // Create buckets and fill with dummy participants.
    var allBuckets = new TournamentBucket[n];
    for (int i = 0; i < n; i++)
    {
        allBuckets[i] = new TournamentBucket(brackets[i]);
        var count = inputBuckets[i].TotalParticipants;

        if (count <= 0)
            continue;

        // Rating range for test RNG: cap at MinRating+99 to avoid overflow
        // when last bracket has MaxRating=int.MaxValue.
        var minR = brackets[i].MinRating;
        var maxR = Math.Min(brackets[i].MaxRating, minR + 99);

        if (inputBuckets[i].NoSplit)
        {
            // NoSplit: add (count-1) native participants within range,
            // plus 1 participant with rating above MaxRating → IsNoSplitBucket() = true.
            allBuckets[i].Participants
                .AddTestParticipants(count - 1, minR, maxR);
            allBuckets[i].Participants.Add(new TournamentGroupParticipant
            {
                UserId = Guid.NewGuid(),
                CompetitionRating = brackets[i].MaxRating + 100
            });
        }
        else
        {
            allBuckets[i].Participants.AddTestParticipants(count, minR, maxR);
        }

        allBuckets[i].Participants = allBuckets[i].Participants
            .OrderBy(p => p.CompetitionRating)
            .ToList();
        allBuckets[i].UpdateRatings(true);
    }

    // Build grouping rule from test case.
    var spec = testCase.GroupingRule;
    var rule = new TournamentGroupingRule
    {
        MinSize = spec.MinSize,
        TargetSize = spec.TargetSize,
        MaxSize = spec.MaxSize,
        MaxGroupCount = spec.MaxGroupCount,
        Brackets = brackets,
    };

    return (allBuckets, rule);
}
```

**Step 2: Verify — ask user to rebuild**

```
dotnet test --no-build Shared/SharedLib.Tests/SharedLib.Tests.csproj
```

Expected: all existing tests pass (no new tests yet, just a helper method).

---

## Task 4: AllocateGroupBudget unit tests

**Files:**
- Modify: `Shared/SharedLib.Tests/Tournaments/MatchmakingLogicTests.cs`

**Step 1: Add `AllocateGroupBudget_ReturnsExpectedAllocation` test method**

Add after `Test_IsNoSplitBucket`:

```csharp
[DataTestMethod]
#region AllocateGroupBudget test cases (FFS algorithm)
// A1. Phase 1 only — budget sufficient
[DataRow("[100] ~(20+):5 => (5)",                        "Single bucket: floor(100/20)=5, budget=5")]
[DataRow("[60/40/20] ~(20+):6 => (3:2:1)",               "Multiple buckets, sum = MaxGroupCount")]
[DataRow("[40!/60] ~(20+):4 => (1:3)",                    "NoSplit gets 1, remainder floor(60/20)=3")]
// A2. Phase 2 — Reduce to Budget
[DataRow("[100/60] ~(20+):5 => (3:2)",                    "Reduce 8→5: WSR strongest loses first")]
[DataRow("[60/60/60] ~20(20+):7 => (3:2:2)",              "Phase 2 WSR: equal avg → strongest loses first")]
[DataRow("[40/40] ~(20+):2 => (1:1)",                     "Reduce to minimum: each bucket keeps 1")]
// A3. Phase 3 — Free+Fill
[DataRow("[120/80/60] ~30(20+):10 => (4:3:2)",            "Free releases slot, total drops to 9")]
// A4. Phase 3 — Swap
[DataRow("[80/50/40] ~25(20+):5 => (2:2:1)",              "Swap helps: A(3)→B(1), improvement=35/3")]
// A5. Zero-improvement swap
[DataRow("[40/40] ~10(10+):5 => (3:2)",                   "Improvement=0 → rejected (prevents ping-pong)")]
// A7. Edge cases
[DataRow("[40] ~(20+):10 => (2)",                         "Budget > possible groups")]
[DataRow("[100] ~(20+):3 => (3)",                         "Single bucket, budget constrains")]
[DataRow("[40!/80/60] ~(20+):5 => (1:2:2)",               "NoSplit locked at 1, others share 4")]
[DataRow("[20/20/20] ~(20+):3 => (1:1:1)",                "All at MinSize → 1 group each")]
// A8. Exotic — 6 buckets, 10 groups
[DataRow("[180/180/180/180/180/600] ~(20+):10 => (2:2:1:1:1:3)",    "Multi-iteration Swap + WSR recipient tie-break")]
[DataRow("[180/180/180/180/180/600] ~150(20+):10 => (1:1:1:1:1:4)", "Free optimizes to target, freed slot unused")]
[DataRow("[180/180/180/180/180/600] ~200(20+):10 => (1:1:1:1:1:3)", "Double Free, budget underutilized")]
#endregion AllocateGroupBudget test cases (FFS algorithm)
public void AllocateGroupBudget_ReturnsExpectedAllocation(
    string notation, string description)
{
    var testCase = MatchmakingTestCase.FromString(notation);
    var (allBuckets, rule) = SetupFromTestCase(testCase);
    var nonEmpty = allBuckets.Where(b => b.Participants.Count > 0).ToList();

    var result = MatchmakingLogic.AllocateGroupBudget(
        nonEmpty, rule.MaxGroupCount.Value, rule.MinSize, rule.TargetSize);

    CollectionAssert.AreEqual(
        testCase.Allocation.GroupCounts.ToList(),
        result.ToList(),
        $"AllocateGroupBudget for '{description}': {notation}");
}
```

**Step 2: Verify — ask user to rebuild, run the new tests**

```
dotnet test --no-build --filter "FullyQualifiedName~AllocateGroupBudget_ReturnsExpectedAllocation" Shared/SharedLib.Tests/SharedLib.Tests.csproj
```

Expected: all 15 DataRows pass.

> **Note on exotic cases (last 3):** The expected allocations are from manual algorithm tracing
> in the test plan. If any fail, trace the algorithm step-by-step to find the correct value
> and update the DataRow.

**Step 3: Commit**

Commit message for FP-41833.

---

## Task 5: ComputeSwapImprovement unit tests

**Files:**
- Modify: `Shared/SharedLib.Tests/Tournaments/MatchmakingLogicTests.cs`

**Step 1: Add `ComputeSwapImprovement_ReturnsExpectedValue` test method**

Add after the AllocateGroupBudget test:

```csharp
[DataTestMethod]
[DataRow(80, 3, 50, 1, 25,  true,  "Donor above target, recipient far above → positive")]
[DataRow(40, 2, 40, 3, 10, false,  "Symmetric buckets → zero improvement")]
[DataRow(40, 2, 60, 3, 20, false,  "Both near target, swap worsens → negative")]
public void ComputeSwapImprovement_ReturnsExpectedSign(
    int donorP, int donorG, int recipientP, int recipientG,
    int targetSize, bool expectPositive, string description)
{
    var donorBracket = new TournamentBracket { MinRating = 0, MaxRating = 99 };
    var donor = new TournamentBucket(donorBracket);
    donor.Participants.AddTestParticipants(donorP, 0, 99);

    var recipientBracket = new TournamentBracket { MinRating = 100, MaxRating = 199 };
    var recipient = new TournamentBucket(recipientBracket);
    recipient.Participants.AddTestParticipants(recipientP, 100, 199);

    var result = MatchmakingLogic.ComputeSwapImprovement(
        donor, donorG, recipient, recipientG, targetSize);

    if (expectPositive)
        Assert.IsTrue(result > 0, $"{description}: expected positive, got {result}");
    else
        Assert.IsTrue(result <= 0, $"{description}: expected non-positive, got {result}");
}
```

**Step 2: Verify — rebuild and run**

```
dotnet test --no-build --filter "FullyQualifiedName~ComputeSwapImprovement" Shared/SharedLib.Tests/SharedLib.Tests.csproj
```

Expected: 3 tests pass.

**Step 3: Commit**

Commit message for FP-41833.

---

## Task 6: ReassignGroupsToBuckets unit tests

**Files:**
- Modify: `Shared/SharedLib.Tests/Tournaments/MatchmakingLogicTests.cs`

**Step 1: Add ReassignGroupsToBuckets tests**

```csharp
[TestMethod]
public void ReassignGroupsToBuckets_NativeParticipants_GroupsStayInOriginalBuckets()
{
    // All participants have ratings within their bracket → no movement.
    var bracket0 = new TournamentBracket { BracketId = 1, MinRating = 0, MaxRating = 99 };
    var bracket1 = new TournamentBracket { BracketId = 2, MinRating = 100, MaxRating = int.MaxValue };
    var bucket0 = new TournamentBucket(bracket0);
    var bucket1 = new TournamentBucket(bracket1);

    bucket0.Participants.AddTestParticipants(20, 0, 99);
    bucket1.Participants.AddTestParticipants(20, 100, 199);

    var groups = new List<TournamentGroup>
    {
        new TournamentGroup { BracketId = 1, Participants = new List<TournamentGroupParticipant>(bucket0.Participants) },
        new TournamentGroup { BracketId = 2, Participants = new List<TournamentGroupParticipant>(bucket1.Participants) },
    };

    var allBuckets = new List<TournamentBucket> { bucket0, bucket1 };
    MatchmakingLogic.ReassignGroupsToBuckets(groups, allBuckets);

    Assert.AreEqual(1, groups[0].BracketId, "Group 0 should stay in bracket 1");
    Assert.AreEqual(2, groups[1].BracketId, "Group 1 should stay in bracket 2");
    Assert.AreEqual(20, bucket0.Participants.Count);
    Assert.AreEqual(20, bucket1.Participants.Count);
    Assert.IsFalse(bucket0.Participants.Any(p => p.IsMoved));
    Assert.IsFalse(bucket1.Participants.Any(p => p.IsMoved));
}

[TestMethod]
public void ReassignGroupsToBuckets_MedianInDifferentBracket_GroupMoves()
{
    // Group has mixed participants: median falls in bracket 1 (rating 100-199).
    var bracket0 = new TournamentBracket { BracketId = 1, MinRating = 0, MaxRating = 99 };
    var bracket1 = new TournamentBracket { BracketId = 2, MinRating = 100, MaxRating = int.MaxValue };

    // Group originally from bracket 0, but most participants have ratings in bracket 1.
    var participants = new List<TournamentGroupParticipant>
    {
        new TournamentGroupParticipant { UserId = Guid.NewGuid(), CompetitionRating = 50 },
        new TournamentGroupParticipant { UserId = Guid.NewGuid(), CompetitionRating = 120 },
        new TournamentGroupParticipant { UserId = Guid.NewGuid(), CompetitionRating = 150 },
    };

    var bucket0 = new TournamentBucket(bracket0);
    var bucket1 = new TournamentBucket(bracket1);
    var groups = new List<TournamentGroup>
    {
        new TournamentGroup { BracketId = 1, Participants = participants },
    };

    var allBuckets = new List<TournamentBucket> { bucket0, bucket1 };
    MatchmakingLogic.ReassignGroupsToBuckets(groups, allBuckets);

    // Median is rating 120 → belongs to bracket 1 (MinRating=100).
    Assert.AreEqual(2, groups[0].BracketId, "Group should move to bracket 2");
    Assert.AreEqual(0, bucket0.Participants.Count);
    Assert.AreEqual(3, bucket1.Participants.Count);
}

[TestMethod]
public void ReassignGroupsToBuckets_OutOfRangeParticipants_IsMovedFlagSet()
{
    var bracket0 = new TournamentBracket { BracketId = 1, MinRating = 0, MaxRating = 99 };
    var bracket1 = new TournamentBracket { BracketId = 2, MinRating = 100, MaxRating = int.MaxValue };

    // Group assigned to bracket 1, but one participant has rating 50 (in bracket 0's range).
    var participants = new List<TournamentGroupParticipant>
    {
        new TournamentGroupParticipant { UserId = Guid.NewGuid(), CompetitionRating = 50 },
        new TournamentGroupParticipant { UserId = Guid.NewGuid(), CompetitionRating = 120 },
        new TournamentGroupParticipant { UserId = Guid.NewGuid(), CompetitionRating = 150 },
    };

    var groups = new List<TournamentGroup>
    {
        new TournamentGroup { BracketId = 1, Participants = participants },
    };

    var allBuckets = new List<TournamentBucket>
    {
        new TournamentBucket(bracket0),
        new TournamentBucket(bracket1),
    };

    MatchmakingLogic.ReassignGroupsToBuckets(groups, allBuckets);

    // Median = 120 → bracket 1. Participant with rating 50 is out of range.
    Assert.IsTrue(participants[0].IsMoved, "Participant with rating 50 should be marked as moved");
    Assert.IsFalse(participants[1].IsMoved);
    Assert.IsFalse(participants[2].IsMoved);
}

[TestMethod]
public void ReassignGroupsToBuckets_MedianFallsInEmptyBucket_EmptyBucketReceivesGroup()
{
    // Three brackets: [0-99], [100-199], [200-MaxValue].
    // Middle bracket is empty. Group median falls in [100-199].
    var bracket0 = new TournamentBracket { BracketId = 1, MinRating = 0, MaxRating = 99 };
    var bracket1 = new TournamentBracket { BracketId = 2, MinRating = 100, MaxRating = 199 };
    var bracket2 = new TournamentBracket { BracketId = 3, MinRating = 200, MaxRating = int.MaxValue };

    var participants = new List<TournamentGroupParticipant>
    {
        new TournamentGroupParticipant { UserId = Guid.NewGuid(), CompetitionRating = 80 },
        new TournamentGroupParticipant { UserId = Guid.NewGuid(), CompetitionRating = 130 },
        new TournamentGroupParticipant { UserId = Guid.NewGuid(), CompetitionRating = 160 },
    };

    var groups = new List<TournamentGroup>
    {
        new TournamentGroup { BracketId = 1, Participants = participants },
    };

    var allBuckets = new List<TournamentBucket>
    {
        new TournamentBucket(bracket0),
        new TournamentBucket(bracket1), // empty
        new TournamentBucket(bracket2),
    };

    MatchmakingLogic.ReassignGroupsToBuckets(groups, allBuckets);

    // Median = 130 → bracket 1 (MinRating=100, MaxRating=199).
    Assert.AreEqual(2, groups[0].BracketId, "Group should land in empty bracket 2");
    Assert.AreEqual(0, allBuckets[0].Participants.Count);
    Assert.AreEqual(3, allBuckets[1].Participants.Count, "Empty bucket should receive the group");
    Assert.AreEqual(0, allBuckets[2].Participants.Count);
}
```

**Step 2: Verify — rebuild and run**

```
dotnet test --no-build --filter "FullyQualifiedName~ReassignGroupsToBuckets" Shared/SharedLib.Tests/SharedLib.Tests.csproj
```

Expected: 4 tests pass.

**Step 3: Commit**

Commit message for FP-41833.

---

## Task 7: PartitionAllBuckets integration tests

**Files:**
- Modify: `Shared/SharedLib.Tests/Tournaments/MatchmakingLogicTests.cs`

**Step 1: Add PartitionAllBuckets tests**

```csharp
[TestMethod]
public void PartitionAllBuckets_MaxGroupCountMode_UsesFFSAlgorithm()
{
    // [60/40] ~(20+):4 — MaxGroupCount mode
    var testCase = MatchmakingTestCase.FromString("[60/40] ~(20+):4 => (3:2)");
    var (allBuckets, rule) = SetupFromTestCase(testCase);
    var nonEmpty = allBuckets.Where(b => b.Participants.Count > 0).ToList();

    var groups = MatchmakingLogic.PartitionAllBuckets(nonEmpty, rule);

    // AllocateGroupBudget should give (3:2) → 3+2=5 groups total
    // But budget=4, so actual allocation might differ.
    // Verify total groups ≤ MaxGroupCount and participants are preserved.
    Assert.IsTrue(groups.Count <= rule.MaxGroupCount.Value,
        $"Total groups ({groups.Count}) exceeds MaxGroupCount ({rule.MaxGroupCount.Value})");
    Assert.AreEqual(100, groups.Sum(g => g.Participants.Count),
        "All participants must be assigned to groups");
}

[TestMethod]
public void PartitionAllBuckets_PerBucketModeWithMaxSize_UsesComputeGroupCount()
{
    // [100] ~20(20-50) — per-bucket mode, MaxSize=50
    var testCase = MatchmakingTestCase.FromString("[100] ~20(20-50) => [100]");
    var (allBuckets, rule) = SetupFromTestCase(testCase);
    var nonEmpty = allBuckets.Where(b => b.Participants.Count > 0).ToList();

    var groups = MatchmakingLogic.PartitionAllBuckets(nonEmpty, rule);

    // ComputeGroupCount(100, 20, 20, 50) → check effective max size
    Assert.IsTrue(groups.Count >= 1);
    Assert.AreEqual(100, groups.Sum(g => g.Participants.Count));
    Assert.IsTrue(groups.All(g => g.Participants.Count >= rule.MinSize),
        "All groups must meet MinSize");
}

[TestMethod]
public void PartitionAllBuckets_PerBucketModeWithNoSplit_LockedBucketGets1Group()
{
    // [40!/60] ~(20+) — NoSplit on first bucket, per-bucket mode
    var testCase = MatchmakingTestCase.FromString("[40!/60] ~20(20+) => [40/60]");
    var (allBuckets, rule) = SetupFromTestCase(testCase);
    var nonEmpty = allBuckets.Where(b => b.Participants.Count > 0).ToList();

    var groups = MatchmakingLogic.PartitionAllBuckets(nonEmpty, rule);

    // First bucket (NoSplit) should have exactly 1 group with 40 participants.
    var noSplitGroups = groups.Where(g => g.BracketId == 1).ToList();
    Assert.AreEqual(1, noSplitGroups.Count, "NoSplit bucket must have exactly 1 group");
    Assert.AreEqual(40, noSplitGroups[0].Participants.Count);

    // Second bucket should be split into groups.
    var otherGroups = groups.Where(g => g.BracketId == 2).ToList();
    Assert.IsTrue(otherGroups.Count >= 2, "Non-NoSplit bucket with 60 participants should split");
}
```

**Step 2: Verify — rebuild and run**

```
dotnet test --no-build --filter "FullyQualifiedName~PartitionAllBuckets" Shared/SharedLib.Tests/SharedLib.Tests.csproj
```

Expected: 3 tests pass.

**Step 3: Commit**

Commit message for FP-41833.

---

## Task 8: BuildGroups end-to-end tests

**Files:**
- Modify: `Shared/SharedLib.Tests/Tournaments/MatchmakingLogicTests.cs`

**Step 1: Add BuildGroups e2e tests**

```csharp
[TestMethod]
public void BuildGroups_WithMaxGroupCount_FullPipeline()
{
    // Full pipeline: partitioning + reassignment + naming.
    var testCase = MatchmakingTestCase.FromString("[60/40/20] ~(20+):5 => (3:2:1)");
    var (allBuckets, rule) = SetupFromTestCase(testCase);

    var groups = MatchmakingLogic.BuildGroups(allBuckets, rule);

    Assert.IsTrue(groups.Length <= rule.MaxGroupCount.Value,
        $"Group count {groups.Length} exceeds MaxGroupCount {rule.MaxGroupCount.Value}");
    Assert.AreEqual(120, groups.Sum(g => g.Participants.Count),
        "All participants must be in groups");

    // Verify groups have names (A, B, C, ...)
    for (int i = 0; i < groups.Length; i++)
    {
        Assert.IsNotNull(groups[i].Name, $"Group {i} must have a name");
    }
    Assert.AreEqual("A", groups[0].Name);
}

[TestMethod]
public void BuildGroups_WithMaxGroupSize_PerBucketMode()
{
    // Per-bucket mode through BuildGroups.
    var testCase = MatchmakingTestCase.FromString("[100] ~20(20-50) => [100]");
    var (allBuckets, rule) = SetupFromTestCase(testCase);

    var groups = MatchmakingLogic.BuildGroups(allBuckets, rule);

    Assert.AreEqual(100, groups.Sum(g => g.Participants.Count));
    Assert.IsTrue(groups.Length >= 1);
    Assert.AreEqual("A", groups[0].Name);
}

[TestMethod]
public void BuildGroups_WithoutMaxGroupCountOrMaxSize_ExistingBehavior()
{
    // Existing behavior regression test: no MaxGroupCount/MaxGroupSize.
    var candidates = new List<TournamentGroupParticipant>()
        .AddTestParticipants(60, NewbiesMinRating, NewbiesMaxRating)
        .AddTestParticipants(40, MiddlesMinRating, MiddlesMaxRating)
        .AddTestParticipants(20, TopsMinRating, TopsMaxRatingForTests);

    var groupingRule = GetTestGroupingRuleWithGroups();
    var buckets = MatchmakingLogic.ProcessBucketsByRule(groupingRule, candidates);

    var groups = MatchmakingLogic.BuildGroups(buckets, groupingRule);

    Assert.AreEqual(120, groups.Sum(g => g.Participants.Count),
        "All participants must be in groups");
    Assert.IsTrue(groups.Length >= 1);
    // Verify naming is sequential
    for (int i = 0; i < groups.Length; i++)
    {
        Assert.IsNotNull(groups[i].Name);
    }
}
```

**Step 2: Verify — rebuild and run**

```
dotnet test --no-build --filter "FullyQualifiedName~BuildGroups_With" Shared/SharedLib.Tests/SharedLib.Tests.csproj
```

Expected: 3 tests pass.

**Step 3: Commit**

Commit message for FP-41833.

---

## Task 9: TableGen — Designer Table Generator

**Files:**
- Modify: `Shared/SharedLib.Tests/Tournaments/MatchmakingLogicTests.cs`

**Step 1: Add the TableGen test**

This test runs all 68 existing 3-bracket test cases through `PartitionAllBuckets` and
`ReassignGroupsToBuckets` for 3 modes (base, MaxGroupCount=5, MaxGroupSize=50)
and outputs TSV for copy-paste into Excel.

```csharp
[TestMethod]
[TestCategory("TableGen")]
public void TableGen_3Brackets_GenerateDesignerTable()
{
    // Column headers
    TestContext.WriteLine(string.Join("\t",
        "Case#",
        "Noobs", "Middles", "Tops",
        "Output (balance)",     "", "",
        "Output (groups, base)", "", "",
        "Output if MGC=5",       "", "",
        "comment",
        "Output if MGS=50",      "", "",
        "Details"));

    // 68 test cases from 3-bracket min-20 suite
    var testCases = new (string caseNum, string notation)[]
    {
        ("[001]", "[ 30 /   0 /   0]   =>   [ 30 /   0 /   0]"),
        ("[002]", "[ 70 /   0 /   0]   =>   [ 70 /   0 /   0]"),
        ("[003]", "[600 /   0 /   0]   =>   [600 /   0 /   0]"),
        ("[004]", "[  0 /  30 /   0]   =>   [  0 /  30 /   0]"),
        ("[005]", "[  0 /  70 /   0]   =>   [  0 /  70 /   0]"),
        ("[006]", "[  0 / 500 /   0]   =>   [  0 / 500 /   0]"),
        ("[007]", "[  0 /   0 /  30]   =>   [  0 /   0 /  30]"),
        ("[008]", "[  0 /   0 /  55]   =>   [  0 /   0 /  55]"),
        ("[009]", "[  0 /   0 / 600]   =>   [  0 /   0 / 600]"),
        ("[010]", "[  0 / 160 /  30]   =>   [  0 / 160 /  30]"),
        ("[011]", "[  0 /  25 / 120]   =>   [  0 /  25 / 120]"),
        ("[012]", "[ 30 /   0 /  20]   =>   [ 30 /   0 /  20]"),
        ("[013]", "[ 80 /   0 / 105]   =>   [ 80 /   0 / 105]"),
        ("[014]", "[ 45 /  85 /   0]   =>   [ 45 /  85 /   0]"),
        ("[015]", "[ 85 /  45 /   0]   =>   [ 85 /  45 /   0]"),
        ("[016]", "[ 20 /  20 /  15]   =>   [ 20 /   0 /  35]"),
        ("[017]", "[351 / 350 / 399]   =>   [351 / 350 / 399]"),
        ("[018]", "[ 12 /   2 /  26]   =>   [ 20 /   0 /  20]"),
        ("[019]", "[ 26 /   2 /  12]   =>   [ 40 /   0 /   0]"),
        ("[020]", "[  2 /  26 /  12]   =>   [ 20 /   0 /  20]"),
        ("[021]", "[ 30 /  15 /   0]   =>   [ 45 /   0 /   0]"),
        ("[022]", "[ 30 /   0 /  15]   =>   [ 45 /   0 /   0]"),
        ("[023]", "[ 15 /   9 /   8]   =>   [ 32 /   0 /   0]"),
        ("[024]", "[ 15 /   9 /   9]   =>   [ 33 /   0 /   0]"),
        ("[025]", "[ 10 /  10 /  10]   =>   [ 30 /   0 /   0]"),
        ("[026]", "[ 19 /  19 /  19]   =>   [ 20 /   0 /  37]"),
        ("[027]", "[ 18 /  31 /  16]   =>   [ 20 /  25 /  20]"),
        ("[028]", "[  0 /  11 /  14]   =>   [  0 /   0 /  25]"),
        ("[029]", "[  4 /   9 /  13]   =>   [ 26 /   0 /   0]"),
        ("[030]", "[ 11 /   1 /   9]   =>   [ 21 /   0 /   0]"),
        ("[031]", "[  9 /  11 /   1]   =>   [ 21 /   0 /   0]"),
        ("[032]", "[ 15 /   9 /   5]   =>   [ 29 /   0 /   0]"),
        ("[033]", "[  9 /  15 /   5]   =>   [ 29 /   0 /   0]"),
        ("[034]", "[ 15 /  24 /   6]   =>   [ 20 /   0 /  25]"),
        ("[035]", "[  5 /  10 /  19]   =>   [ 34 /   0 /   0]"),
        ("[036]", "[  1 /   1 /  19]   =>   [ 21 /   0 /   0]"),
        ("[037]", "[  1 /  60 /   1]   =>   [ 20 /  22 /  20]"),
        ("[038]", "[  1 /  21 /  19]   =>   [ 20 /   0 /  21]"),
        ("[039]", "[  1 /   0 /  75]   =>   [ 20 /   0 /  56]"),
        ("[040]", "[  0 / 250 /   1]   =>   [  0 / 231 /  20]"),
        ("[041]", "[  0 /   1 / 100]   =>   [  0 /   0 / 101]"),
        ("[042]", "[100 /   0 /   1]   =>   [101 /   0 /   0]"),
        ("[043]", "[100 /   1 /   1]   =>   [102 /   0 /   0]"),
        ("[044]", "[ 20 /  20 /   1]   =>   [ 20 /   0 /  21]"),
        ("[045]", "[  7 /   7 /   7]   =>   [ 21 /   0 /   0]"),
        ("[046]", "[  8 /   8 /   8]   =>   [ 24 /   0 /   0]"),
        ("[047]", "[  9 /   9 /   9]   =>   [ 27 /   0 /   0]"),
        ("[048]", "[  7 /   7 /   8]   =>   [ 22 /   0 /   0]"),
        ("[049]", "[  7 /   8 /   7]   =>   [ 22 /   0 /   0]"),
        ("[050]", "[  8 /   7 /   7]   =>   [ 22 /   0 /   0]"),
        ("[051]", "[ 14 /  15 /  15]   =>   [ 20 /   0 /  24]"),
        ("[052]", "[ 15 /  14 /  15]   =>   [ 20 /   0 /  24]"),
        ("[053]", "[ 15 /  15 /  14]   =>   [ 20 /   0 /  24]"),
        ("[054]", "[ 45 /  25 /  16]   =>   [ 45 /  21 /  20]"),
        ("[055]", "[127 /  20 /  20]   =>   [127 /  20 /  20]"),
        ("[056]", "[ 20 /  87 /  17]   =>   [ 20 /  84 /  20]"),
        ("[057]", "[ 12 /  13 /   9]   =>   [ 34 /   0 /   0]"),
        ("[058]", "[ 10 /  16 /   9]   =>   [ 35 /   0 /   0]"),
        ("[059]", "[ 10 /  16 /  10]   =>   [ 36 /   0 /   0]"),
        ("[060]", "[ 10 /  21 /  10]   =>   [ 20 /   0 /  21]"),
        ("[061]", "[ 19 /  21 /   0]   =>   [ 20 /  20 /   0]"),
        ("[062]", "[ 14 /  45 /   0]   =>   [ 20 /  39 /   0]"),
        ("[063]", "[ 10 /   4 /  50]   =>   [ 20 /   0 /  44]"),
        ("[064]", "[  4 /  10 /  50]   =>   [ 20 /   0 /  44]"),
        ("[065]", "[ 50 /  10 /   4]   =>   [ 64 /   0 /   0]"),
        ("[066]", "[ 10 /  50 /   4]   =>   [ 20 /  24 /  20]"),
        ("[067]", "[  4 /  50 /  10]   =>   [ 20 /  24 /  20]"),
        ("[068]", "[ 50 /   4 /  10]   =>   [ 64 /   0 /   0]"),
    };

    foreach (var (caseNum, notation) in testCases)
    {
        var testCase = MatchmakingTestCase.FromString(notation);
        var inputBuckets = testCase.Input.Buckets;

        // --- Run balance (already computed in testCase.Output) ---
        var balanceCandidates = new List<TournamentGroupParticipant>()
            .AddTestParticipants(inputBuckets[0].TotalParticipants, NewbiesMinRating, NewbiesMaxRating)
            .AddTestParticipants(inputBuckets[1].TotalParticipants, MiddlesMinRating, MiddlesMaxRating)
            .AddTestParticipants(inputBuckets[2].TotalParticipants, TopsMinRating, TopsMaxRatingForTests);

        var groupingBase = GetTestGroupingRule();
        groupingBase.MinSize = 20;
        groupingBase.TargetSize = 20;

        var balancedBuckets = MatchmakingLogic.ProcessBucketsByRule(groupingBase, balanceCandidates);
        var balanceLayout = MatchmakingTestCase.ParticipantDistributionLayout.FromTournamentBuckets(balancedBuckets);

        // --- Base mode (TargetSize=20, no MaxGroupCount/MaxSize) ---
        var baseGroups = MatchmakingLogic.PartitionAllBuckets(
            balancedBuckets.Where(b => b.Participants.Count > 0).ToList(), groupingBase);
        var baseSnapshot = SnapshotGroups(baseGroups, balancedBuckets);

        // --- MGC=5 mode ---
        var mgcCandidates = new List<TournamentGroupParticipant>()
            .AddTestParticipants(inputBuckets[0].TotalParticipants, NewbiesMinRating, NewbiesMaxRating)
            .AddTestParticipants(inputBuckets[1].TotalParticipants, MiddlesMinRating, MiddlesMaxRating)
            .AddTestParticipants(inputBuckets[2].TotalParticipants, TopsMinRating, TopsMaxRatingForTests);

        var groupingMgc = GetTestGroupingRule();
        groupingMgc.MinSize = 20;
        groupingMgc.TargetSize = 20;
        groupingMgc.MaxGroupCount = 5;

        var mgcBuckets = MatchmakingLogic.ProcessBucketsByRule(groupingMgc, mgcCandidates);
        var mgcGroups = MatchmakingLogic.BuildGroups(mgcBuckets, groupingMgc);
        var mgcLayout = MatchmakingTestCase.ParticipantDistributionLayout.FromTournamentBuckets(mgcBuckets);

        // --- MGS=50 mode ---
        var mgsCandidates = new List<TournamentGroupParticipant>()
            .AddTestParticipants(inputBuckets[0].TotalParticipants, NewbiesMinRating, NewbiesMaxRating)
            .AddTestParticipants(inputBuckets[1].TotalParticipants, MiddlesMinRating, MiddlesMaxRating)
            .AddTestParticipants(inputBuckets[2].TotalParticipants, TopsMinRating, TopsMaxRatingForTests);

        var groupingMgs = GetTestGroupingRule();
        groupingMgs.MinSize = 20;
        groupingMgs.TargetSize = 20;
        groupingMgs.MaxSize = 50;

        var mgsBuckets = MatchmakingLogic.ProcessBucketsByRule(groupingMgs, mgsCandidates);
        var mgsGroups = MatchmakingLogic.BuildGroups(mgsBuckets, groupingMgs);
        var mgsLayout = MatchmakingTestCase.ParticipantDistributionLayout.FromTournamentBuckets(mgsBuckets);

        // Output TSV row
        TestContext.WriteLine(string.Join("\t",
            caseNum,
            inputBuckets[0].TotalParticipants,
            inputBuckets[1].TotalParticipants,
            inputBuckets[2].TotalParticipants,
            FormatBucketCell(balanceLayout, 0),
            FormatBucketCell(balanceLayout, 1),
            FormatBucketCell(balanceLayout, 2),
            baseSnapshot[0], baseSnapshot[1], baseSnapshot[2],
            FormatBucketCell(mgcLayout, 0),
            FormatBucketCell(mgcLayout, 1),
            FormatBucketCell(mgcLayout, 2),
            "", // comment column (filled by designer)
            FormatBucketCell(mgsLayout, 0),
            FormatBucketCell(mgsLayout, 1),
            FormatBucketCell(mgsLayout, 2),
            "" // details column
        ));
    }
}

/// <summary>
/// Snapshots group distribution per bucket after PartitionAllBuckets (before reassignment).
/// Returns an array of Bucket.ToString() values per bracket.
/// </summary>
private static string[] SnapshotGroups(
    List<TournamentGroup> groups,
    TournamentBucket[] allBuckets)
{
    var result = new string[allBuckets.Length];
    for (int i = 0; i < allBuckets.Length; i++)
    {
        var bracketId = allBuckets[i].BracketId;
        var bracketGroups = groups
            .Where(g => g.BracketId == bracketId)
            .Select(g => g.Participants.Count)
            .ToList();

        result[i] = bracketGroups.Count > 0
            ? string.Join("+", bracketGroups)
            : "0";
    }
    return result;
}

private static string FormatBucketCell(
    MatchmakingTestCase.ParticipantDistributionLayout layout, int index)
{
    if (index >= layout.Buckets.Count) return "0";
    return layout.Buckets[index].ToString();
}
```

**Step 2: Verify — rebuild and run**

```
dotnet test --no-build --filter "FullyQualifiedName~TableGen" Shared/SharedLib.Tests/SharedLib.Tests.csproj
```

Expected: test passes and outputs TSV table to test output.

**Step 3: Review output**

Copy TSV output from test results, verify it makes sense, paste into Excel for designer review.

**Step 4: Commit**

Commit message for FP-41833.

---

## Summary

| Task | What | JIRA | Tests |
|------|------|------|-------|
| 1 | Extract `PartitionAllBuckets` | FP-41746 | Existing (regression) |
| 2 | Extract `ReassignGroupsToBuckets` | FP-41746 | Existing (regression) |
| 3 | `SetupFromTestCase` helper | FP-41833 | — |
| 4 | `AllocateGroupBudget` tests | FP-41833 | 15 DataRows |
| 5 | `ComputeSwapImprovement` tests | FP-41833 | 3 DataRows |
| 6 | `ReassignGroupsToBuckets` tests | FP-41833 | 4 methods |
| 7 | `PartitionAllBuckets` tests | FP-41833 | 3 methods |
| 8 | `BuildGroups` e2e tests | FP-41833 | 3 methods |
| 9 | TableGen | FP-41833 | 1 generator |
| **Total** | | | **~29 tests** |

### Dependencies

```
Task 1 ──→ Task 2 ──→ Task 3 ──→ Task 4 ──→ Task 5
                            │           ↘
                            ├──→ Task 6    Task 9
                            ├──→ Task 7
                            └──→ Task 8
```

Tasks 4–9 all depend on Task 3 (SetupFromTestCase helper).
Tasks 4–8 are independent of each other and can be done in any order.
Task 9 (TableGen) depends on both Task 1 (PartitionAllBuckets) and Task 2 (ReassignGroupsToBuckets).