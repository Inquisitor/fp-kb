# Matchmaking Test Plan — Phase 6 Step 9+

> **Task:** FP-41833
> **Date:** 2026-03-03
> **Status:** Approved
> **Depends on:** [Matchmaking-Group-Budget-Design.md](Matchmaking-Group-Budget-Design.md) (Phase 6 design)

---

## 1. Overview

Comprehensive test coverage for the new matchmaking features introduced in Phase 6:

- `AllocateGroupBudget` (FFS algorithm) — unit tests
- `ComputeSwapImprovement` — unit tests
- `ReassignGroupsToBuckets` — unit tests (requires refactoring, see Section 2)
- `PartitionAllBuckets` — integration tests (requires refactoring, see Section 2)
- `BuildGroups` — end-to-end tests with MaxGroupCount / MaxGroupSize
- TableGen — designer table generator (68 cases × 3 modes)

### Scope

| Layer | Method | Status |
|-------|--------|--------|
| Unit | `AllocateGroupBudget` | New |
| Unit | `ComputeSwapImprovement` | New |
| Unit | `ReassignGroupsToBuckets` | New (extracted) |
| Integration | `PartitionAllBuckets` | New (extracted) |
| End-to-end | `BuildGroups` | New |
| Generator | TableGen | New |

---

## 2. Prerequisite: Decompose `BuildGroups`

### Problem

`BuildGroups` combines partitioning + reassignment + naming in one method. To test intermediate states (e.g., groups before reassignment), we'd have to copy production code into tests — a fragile test antipattern.

### Solution: Decompose for Testability

Extract two `internal static` methods that `BuildGroups` itself calls:

```
BuildGroups(buckets, grouping)
│
├─ bucketsList = buckets.ToList()                     // all buckets (incl. empty)
├─ nonEmpty = filter(count >= 1)                      // non-empty only
│
├─ groups = PartitionAllBuckets(nonEmpty, grouping)   // NEW internal static
│  ├─ MaxGroupCount → AllocateGroupBudget + PartitionBucket
│  └─ Per-bucket → IsNoSplitBucket / ComputeGroupCount + PartitionBucket
│
├─ ReassignGroupsToBuckets(groups, bucketsList)       // NEW internal static
│  ├─ clear all bucket participants
│  ├─ for each group: median → parentBucket, BracketId, IsMoved
│  └─ re-sort + UpdateRatings
│
└─ naming (A, B, C...)
```

**Key:** `ReassignGroupsToBuckets` needs ALL buckets (including empty), because a group's median rating may fall into an empty bucket's range.

### Test access

| What to test | Call |
|---|---|
| FFS allocation | `AllocateGroupBudget(...)` → `int[]` |
| Partitioning (before reassign) | `PartitionAllBuckets(...)` → `TournamentGroup[]` |
| Reassignment | `ReassignGroupsToBuckets(...)` |
| End-to-end | `BuildGroups(...)` |
| TableGen (both columns) | `PartitionAllBuckets` → snapshot, then `ReassignGroupsToBuckets` → snapshot |

Zero code duplication. All test entry points are production methods.

---

## 3. Test Helper Bridge

A helper method converts `MatchmakingTestCase` notation into `TournamentBucket[]` + `TournamentGroupingRule`:

```csharp
private static (TournamentBucket[] allBuckets, TournamentGroupingRule rule)
    SetupFromTestCase(MatchmakingTestCase testCase)
```

**What it does:**

1. Reads `testCase.Input.Buckets` — participant counts per bucket
2. Creates `TournamentBracket[]` with rating ranges: [0–99], [100–199], ..., [N×100, MaxValue]
3. Fills each bucket with dummy participants (ratings within bracket range)
4. For NoSplit (`!`): one participant gets rating above MaxRating → `IsNoSplitBucket()` returns true
5. Builds `TournamentGroupingRule` from `testCase.GroupingRule`

**Returns ALL buckets** (including empty) for `ReassignGroupsToBuckets`.

### Test method pattern

```csharp
[DataTestMethod]
[DataRow("[120/80/60] ~30(20+):10 => (4:3:2)", "Design doc 4.1: Free+Fill helps, Swap can't")]
public void AllocateGroupBudget_ReturnsExpectedAllocation(string notation, string description)
{
    var testCase = MatchmakingTestCase.FromString(notation);
    var (allBuckets, rule) = SetupFromTestCase(testCase);
    var nonEmpty = allBuckets.Where(b => b.Participants.Count > 0).ToList();

    var result = MatchmakingLogic.AllocateGroupBudget(
        nonEmpty, rule.MaxGroupCount.Value, rule.MinSize, rule.TargetSize);

    CollectionAssert.AreEqual(
        testCase.Allocation.GroupCounts.ToList(), result.ToList());
}
```

---

## 4. Test Case Inventory

### A. AllocateGroupBudget (FFS algorithm)

#### A1. Phase 1 only — budget sufficient

| # | Notation | Verifies |
|---|----------|----------|
| 1 | `[100] ~(20+):5 => (5)` | Single bucket: floor(100/20)=5, budget=5 |
| 2 | `[60/40/20] ~(20+):6 => (3:2:1)` | Multiple buckets, sum = MaxGroupCount |
| 3 | `[40!/60] ~(20+):4 => (1:3)` | NoSplit gets 1, other floor(60/20)=3 |

#### A2. Phase 2 — Reduce to Budget

| # | Notation | Verifies |
|---|----------|----------|
| 4 | `[100/60] ~(20+):5 => (TBD)` | Simple reduction: 5+3=8→5 |
| 5 | `[60/60/60] ~20(20+):7 => (3:2:2)` | **Phase 2 WSR**: equal avg → strongest loses first |
| 6 | `[40/40] ~(20+):2 => (1:1)` | Reduce to minimum |

**Case 5 trace:**
```
Phase 1: [3:3:3]=9. Phase 2 reduce 9→7:
  All avg=20 → strongest (C, MR=200) loses → [3:3:2]
  A/B tied avg=20 → strongest (B, MR=100) loses → [3:2:2] ✓
Phase 3: all at/above target → no changes.
```

#### A3. Phase 3 — Free+Fill (design doc 4.1)

| # | Notation | Verifies |
|---|----------|----------|
| 7 | `[120/80/60] ~30(20+):10 => (4:3:2)` | Free releases slot, total drops to 9 |

**Trace:**
```
Phase 2: [5:3:2]=10. Phase 3 Free: A 5→4 (avg 24→30, closer to T=30).
Freed slot unused (nobody above target). All swaps negative. Result: (4:3:2)=9.
```

#### A4. Phase 3 — Swap (design doc 4.2)

| # | Notation | Verifies |
|---|----------|----------|
| 8 | `[80/50/40] ~25(20+):5 => (2:2:1)` | Swap helps, Free+Fill can't |

**Trace:**
```
Phase 2: [3:1:1]=5. All above target → no Free.
Swap A(3)→B(1): improvement=+11.67. Apply → (2:2:1).
```

#### A5. Zero-improvement swap

| # | Notation | Verifies |
|---|----------|----------|
| 9 | `[40/40] ~10(10+):5 => (3:2)` | Improvement=0 → rejected (prevents ping-pong) |

**Trace:**
```
Phase 2: [3:2]=5. Swap A(3)→B(2):
  before = |13.3-10| + |20-10| = 13.33
  after  = |20-10| + |13.3-10| = 13.33
  improvement = 0 → rejected.
```

#### A6. WSR tie-breaks (Swap phase)

| # | Scenario | Verifies |
|---|----------|----------|
| 10 | Two donors with same P, G, different MinRating → one recipient | **Donor tie-break**: stronger donor chosen |
| 11 | One donor → two recipients with equal improvement | **Recipient tie-break**: weaker recipient chosen |

Exact values TBD during implementation. Principle: two buckets with equal P and G (⇒ equal improvement) but different MinRating.

#### A7. Edge cases

| # | Notation | Verifies |
|---|----------|----------|
| 12 | `[40] ~(20+):10 => (2)` | Budget > possible groups |
| 13 | `[100] ~(20+):3 => (3)` | Single bucket, budget constrains |
| 14 | `[40!/80/60] ~(20+):5 => (1:TBD:TBD)` | NoSplit locked at 1, others share 4 |
| 15 | `[20/20/20] ~(20+):3 => (1:1:1)` | All at MinSize → 1 group each |

#### A8. Exotic — 6 buckets, 10 groups

Input: `[180/180/180/180/180/600]` (1500 participants)

| # | Rule | Result | What it shows |
|---|------|--------|---------------|
| 16 | `~(20+):10` | `(2:2:1:1:1:3)` | Multi-iteration Swap + WSR recipient tie-break |
| 17 | `~150(20+):10` | `(1:1:1:1:1:4)` = 9 groups | Free optimizes B5 to target, freed slot unused |
| 18 | `~200(20+):10` | `(1:1:1:1:1:3)` = 8 groups | Double Free, budget underutilized |

**Case 16 trace:**
```
Phase 2: [1:1:1:1:1:5]=10.
Swap iter 1: B5(5)→B0(1), improvement=60. WSR weakest recipient → B0. [2:1:1:1:1:4]
Swap iter 2: B5(4)→B1(1), improvement=40. WSR weakest recipient → B1. [2:2:1:1:1:3]
Swap iter 3: all ≤ 0. Done.
```

Same input, three TargetSize values → three distinct FFS behaviors.

---

### B. ComputeSwapImprovement (unit)

| # | Scenario | Verifies |
|---|----------|----------|
| 19 | Donor above target, recipient far above | Positive improvement |
| 20 | Symmetric buckets (equal P, mirrored G) | Zero improvement |
| 21 | Both near target, swap worsens | Negative improvement |

---

### C. ReassignGroupsToBuckets (unit)

| # | Scenario | Verifies |
|---|----------|----------|
| 22 | All participants native (rating within bracket) | Groups stay in original buckets |
| 23 | Group median falls in different bracket | Group moves to correct bucket |
| 24 | Participants outside parent bucket range | IsMoved flag set correctly |
| 25 | Median falls into empty bucket's range | Empty bucket receives group |

---

### D. PartitionAllBuckets (integration)

| # | Scenario | Verifies |
|---|----------|----------|
| 26 | MaxGroupCount mode | AllocateGroupBudget → PartitionBucket pipeline |
| 27 | Per-bucket mode with MaxSize | ComputeGroupCount with MaxSize → PartitionBucket |
| 28 | Per-bucket mode with NoSplit | IsNoSplitBucket → 1 group for locked bucket |

---

### E. BuildGroups end-to-end

| # | Scenario | Verifies |
|---|----------|----------|
| 29 | Full pipeline with MaxGroupCount | Partitioning + reassign + naming |
| 30 | Full pipeline with MaxGroupSize | Per-bucket mode through BuildGroups |
| 31 | Without MaxGroupCount/MaxGroupSize | Existing behavior regression |

---

### F. TableGen — Designer Table

| # | Scenario | Verifies |
|---|----------|----------|
| 32 | `[TestCategory("TableGen")]` test | 68 cases × 3 modes → TSV output |

**Modes:** base (TargetSize=null), MaxGroupCount=5, MaxGroupSize=50.

**Table format (Excel):**

| Case # | Noobs | Middles | Tops | Output (balance) ||| Output (groups, base) ||| Output if MGC=5 ||| comment | Output if MGS=50 ||| Details |
|--------|-------|---------|------|---|---|---|---|---|---|---|---|---|---|---|---|---|---|

- Cell values use `Bucket.ToString()` notation: `15+15` (2 groups), `30` (1 group), `0` (empty)
- "Output (groups, base)" = `PartitionAllBuckets` result (before reassignment), new column
- MaxGroupCount/MaxGroupSize columns show final result after reassignment

**Implementation:** A `[TestCategory("TableGen")]` test runs all 68 cases through `PartitionAllBuckets` and `ReassignGroupsToBuckets` for each mode, outputs TSV to `TestContext.WriteLine` for copy-paste into Excel.

---

## 5. Summary

| Category | Test points | DataRow-heavy? |
|----------|-------------|----------------|
| A. AllocateGroupBudget | 18 | Yes (A1-A5, A7-A8 as DataRows) |
| B. ComputeSwapImprovement | 3 | Yes |
| C. ReassignGroupsToBuckets | 4 | No (individual methods) |
| D. PartitionAllBuckets | 3 | No |
| E. BuildGroups e2e | 3 | No |
| F. TableGen | 1 generator | N/A |
| **Total** | **~32** | |

### Prerequisites (before tests)

1. Extract `PartitionAllBuckets` from `BuildGroups`
2. Extract `ReassignGroupsToBuckets` from `BuildGroups`
3. Verify all existing tests still pass (pure extract method refactoring)

### JIRA

- **FP-41833** — tests and test infrastructure
- **FP-41746** — refactoring (BuildGroups decomposition)