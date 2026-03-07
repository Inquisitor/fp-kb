# Matchmaking Group Budget Algorithm — Design Document

> **Task:** FP-41833 (Phase 6: CFG-005, CFG-006, SUB-001)
> **Date:** 2026-02-23
> **Status:** Approved

---

## 1. Overview

Two new parameters for the matchmaking grouping configuration (`TournamentGroupingRule`):

| Parameter       | Type   | JSON Key          | Description                                                  |
|-----------------|--------|-------------------|--------------------------------------------------------------|
| `MaxGroupCount` | `int?` | `"MaxGroupCount"` | Global cap on total groups across all buckets                |
| `MaxSize`       | `int?` | `"MaxSize"`       | Maximum participants per group (replaces computed `maxSize`) |

> **Naming note:** The GDD uses `MaxGroupSize` (CFG-006) and `"GroupCount"` as the JSON key (CFG-005). This design
> renames them to `MaxSize` and `"MaxGroupCount"` respectively, for consistency with the existing `MinSize` /
`TargetSize`
> naming convention. GDD and TDD must be updated accordingly (see step 10 in Section 7).

**Mutual exclusivity:** If both are set, `MaxGroupCount` takes priority (`MaxSize` is ignored, log warning).

### Parameter summary table

| Parameter       | Scope                | Current state               | After implementation                     |
|-----------------|----------------------|-----------------------------|------------------------------------------|
| `MinSize`       | Per-group floor      | Implemented                 | Unchanged                                |
| `TargetSize`    | Per-group ideal size | Implemented                 | Upper bound validation removed (see 2.3) |
| `MaxSize`       | Per-group ceiling    | Not configurable (implicit) | Configurable, floor `2 * MinSize - 1`    |
| `MaxGroupCount` | Global group cap     | Not implemented             | New                                      |

---

## 2. Parameter Behavior

### 2.1. `MaxSize`

Replaces the hard-coded `maxSize = MinSize * 2 - 1` with a configurable value.

| Condition         | Effective `maxSize`                  |
|-------------------|--------------------------------------|
| `MaxSize == null` | `MinSize * 2 - 1` (current behavior) |
| `MaxSize` is set  | `Math.Max(MaxSize, 2 * MinSize - 1)` |

The floor of `2 * MinSize - 1` ensures that any group exceeding `maxSize` can always be split into two valid groups
(each >= `MinSize`). For example, with `MinSize = 20`: floor = 39. A group of 39 plays together; a group of 40 splits
into 20 + 20.

**Effects on `PartitionBucket` (formerly `CreateGroups`):**

- When `TargetSize == null` and `MaxSize` is set: group count = `ceil(total / effectiveMaxSize)`. This is the minimum
  number of groups needed to keep every group within `MaxSize`. No further optimization (increased/decreased) is
  applied.
  (Currently, `TargetSize == null` always produces 1 group.)
- **Ignored** when `MaxGroupCount` is set.

**Group count computation:** `BuildGroups` computes `groupCount = ceil(total / effectiveMaxSize)` per bucket and passes
it to `PartitionBucket(bucket, groupCount)`. The `effectiveMaxSize` value is not needed in `PartitionBucket`'s
signature.

### 2.2. `MaxGroupCount`

Global upper bound on total groups across all buckets.

- When `TargetSize == null` and `MaxGroupCount` is set: `effectiveTargetSize = MinSize` (maximize group count for better
  win chances)
- When `TargetSize == null` and `MaxGroupCount` is NOT set: no splitting (current behavior, 1 group per bucket)
- When `MaxGroupCount` is set: no upper bound on group sizes (constraint is on count, not size)

**Validation:** `MaxGroupCount >= Brackets.Count` (at configuration level in `CompetetiveActivityBreaksModel`).

### 2.3. `TargetSize` Validation Changes

The existing upper bound on `TargetSize` (`TargetSize < 2 * MinSize`) is **removed entirely** — it was an outdated
constraint. `TargetSize = 100` with `MinSize = 20` is valid: 500 participants split into 5 groups of 100.

**New validation rules:**

| Rule                     | Condition                                  |
|--------------------------|--------------------------------------------|
| `TargetSize >= MinSize`  | Always (if `TargetSize` is set)            |
| `TargetSize <= MaxSize`  | Only when both are explicitly set          |
| No upper bound otherwise | `TargetSize` can be any value >= `MinSize` |

**Code locations to update:**

- `MatchmakingLogic.PartitionBucket()` (was `CreateGroups`): remove `if (targetedSize > maxSize) throw`
- `CompetetiveActivityBreaksModel.CheckGroupingRule()`: remove `TargetSize >= 2 * MinSize` check, add
  `TargetSize <= MaxSize` check (when both are set)

---

## 3. Algorithm

### 3.1. Method Rename

| Old Name         | New Name            | Role                                                              |
|------------------|---------------------|-------------------------------------------------------------------|
| `MakeGroups()`   | `BuildGroups()`     | Orchestrator: all buckets → final groups + re-evaluation + naming |
| `CreateGroups()` | `PartitionBucket()` | Partitioner: 1 bucket → N groups (pure math)                      |

Call chain after rename:

```
ProcessGroupsByRule(groupingRule, buckets)
  → BuildGroups(buckets, grouping)
      → PartitionBucket(bucket, groupCount)  // for each bucket
```

### 3.2. No-Split Rule (NSR)

The bucket of the lowest bracket (`MinRating = 0`) **cannot be split** into groups if participants from stronger
brackets
were moved into it during balancing. If this bucket is empty, the rule does not apply.

**Check:** `bucket.MinRating == 0 && bucket.Participants.Max(p => p.CompetitionRating) > bucket.MaxRating`

**Rationale:** If a strong player is added to the weak group, ALL weak players must face them. Splitting the bucket
would
create a group of weak players that avoid the strong player, violating this rule. The ping-pong balancing traversal
naturally enforces this by forming the weakest bucket first and never pulling players out of it — only adding to it.

**Enforcement:** Evaluated in `BuildGroups` as a **preparatory step** before FFS runs. The no-split flag is stored per
bucket and persists through all subsequent phases. If the condition is true:

- The bucket gets exactly **1 group** (assigned in Phase 1, never modified).
- It is **excluded from all FFS phases**: Phase 2 cannot select it (its `groupCount` is 1, which fails the `> 1`
  candidate filter), Phase 3a Free/Fill and Phase 3b Swap skip it entirely.

**Priority over MaxSize:** If the no-split rule applies, the bucket is not split even if `MaxSize` would require
splitting (e.g., `MinSize = 20`, `MaxSize = 39`, bucket has 40 participants — no-split wins, bucket stays as 1 group
of 40). The no-split rule protects competitive fairness; MaxSize is an organizational constraint that yields to it.

### 3.3. Remainder Distribution Inversion

When distributing participants into groups of unequal size, extra participants go to the **last (stronger) groups**
instead of the first (weaker) groups.

```csharp
// Before (extras to first/weaker):
if (i < remainder) groupSize++;

// After (extras to last/stronger):
if (i >= groupCount - remainder) groupSize++;
```

Example: 33 participants, 2 groups → `16 + 17` (weaker group gets fewer opponents).

This is a separate pre-step, committed before MaxGroupCount/MaxSize implementation.

### 3.4. Weak-Small Rule (WSR)

A universal tie-breaking principle applied throughout the matchmaking algorithm: **when the optimization metric produces
a tie, prefer the outcome that keeps groups in weaker buckets smaller.**

Weaker buckets (lower `MinRating`) represent less experienced players. Keeping their groups smaller gives them fewer
opponents per match, which is a competitive fairness advantage. When the algorithm has no optimization reason to prefer
one outcome over another, this rule breaks the tie in favor of weaker players.

**Applications:**

| Phase                                | Tie condition              | Weak-small action                                                       |
|--------------------------------------|----------------------------|-------------------------------------------------------------------------|
| Remainder Distribution (Section 3.3) | Unequal group sizes        | Extra participants go to stronger (last) groups, keeping weaker smaller |
| Phase 2 — Reduce to Budget           | Equal average group size   | Strongest bucket loses a group first, delaying enlargement of weaker    |
| Phase 3b — Swap                      | Equal positive improvement | Cascading tie-break: 1) prefer weaker recipient, 2) prefer stronger donor |

Note that Phase 3b Swap only applies the weak-small rule among **strictly positive** improvements. Zero-improvement
swaps are rejected entirely to prevent no-op cycles (see Section 5, "Zero-improvement swap cycle").

### 3.5. FFS: Group Budget Allocation Algorithm (MaxGroupCount)

**FFS (Free-Fill-Swap)** — the three-phase optimization algorithm for distributing group slots across buckets when
`MaxGroupCount` is set.

**Input:** Buckets (after `BalanceBuckets`), `MaxGroupCount`, `MinSize`, `TargetSize`.

#### Phase 1 — Maximize

Start with the maximum number of groups per bucket (minimum group size = `MinSize`):

```
for each non-empty bucket:
    groupCount[bucket] = max(1, floor(participants / MinSize))

// Empty buckets get 0 groups.
// No-split-locked buckets get exactly 1 group (see Section 3.2).
```

#### Phase 2 — Reduce to Budget

Reduce total groups to `MaxGroupCount` by removing groups where they are smallest:

```
while sum(groupCounts) > MaxGroupCount:
    candidates = buckets where groupCount > 1
    candidate = min(candidates, by: participants / groupCount)
        // tie-break: strongest bucket (highest MinRating)
    candidate.groupCount -= 1
```

No TargetSize consideration at this stage — purely mechanical reduction.

**Candidate filter:** Only buckets with `groupCount > 1` are eligible. No-split-locked buckets start at 1 (see Section
3.2) and therefore never appear as candidates.

**Tie-break:** Weak-small rule (Section 3.4) — the **strongest** bucket (highest `MinRating`) is reduced first,
keeping weaker groups smaller for longer. If the weaker bucket is the sole minimum-average candidate, it is reduced on
general grounds.

**Termination guarantee:** Each iteration removes exactly 1 group from a bucket with `groupCount > 1`, strictly
decreasing `sum(groupCounts)`. The minimum achievable sum equals the number of non-empty buckets (each at 1 group).
Validation ensures `MaxGroupCount >= Brackets.Count >= non-empty buckets` (Section 6), so the target is always
reachable. No-split-locked buckets consume exactly 1 slot each from the budget, accounted for implicitly.

#### Phase 3 — Rebalance toward TargetSize (FFS optimization)

```
effectiveTargetSize = TargetSize ?? MinSize
```

Two complementary optimization techniques, applied iteratively until convergence:

**Phase 3a — Free + Fill:**

1. **Free:** Process non-locked buckets one at a time, in bucket array order (weakest to strongest by `MinRating`).
   For each bucket where `groupCount >= 2` and
   `avg < effectiveTargetSize`: iteratively reduce `groupCount` by 1 as long as the reduction brings `avg` closer to
   `effectiveTargetSize`. Stop when the next reduction would worsen distance, or when `groupCount` reaches 1. Then move
   to the next bucket. Each successful reduction frees 1 budget slot.
2. **Fill:** Distribute freed slots to buckets where `avg > effectiveTargetSize` (starting with the farthest from
   `effectiveTargetSize`), as long as adding a group brings `avg` closer to `effectiveTargetSize` and the new
   `avg >= MinSize`. Buckets already at `avg == effectiveTargetSize` are skipped — their partition is already ideal.

**Phase 3b — Swap:**

Find the best `(donor, recipient)` pair where transferring 1 group slot improves total distance to
`effectiveTargetSize`:

```
for each pair (donor, recipient) where donor != recipient:
    if donor is no-split-locked or recipient is no-split-locked: skip
    if donor.groupCount <= 1: skip
    if recipient.participants / (recipient.groupCount + 1) < MinSize: skip
    // Note: donor MinSize is not checked — reducing groups only increases avg.

    distBefore = |donor.avg - effectiveTargetSize| + |recipient.avg - effectiveTargetSize|
    distAfter  = |donor.newAvg - effectiveTargetSize| + |recipient.newAvg - effectiveTargetSize|
    improvement = distBefore - distAfter

    if improvement <= 0: skip    // reject non-improving swaps (prevents no-op cycles)

    // Weak-small cascading tie-break: when tied, keep weaker groups smaller.
    //   1) largest improvement wins
    //   2) equal improvement: prefer weaker recipient (more groups → smaller groups for weaker)
    //   3) equal improvement, equal recipient: prefer stronger donor (stronger absorbs the cost)
    if improvement > bestImprovement
       or (improvement == bestImprovement and recipient.MinRating < bestRecipient.MinRating)
       or (improvement == bestImprovement and recipient.MinRating == bestRecipient.MinRating
                                          and donor.MinRating > bestDonor.MinRating):
        bestSwap = (donor, recipient)
```

**Repeat Phase 3a + 3b** until neither produces improvements.

**Convergence:** Guaranteed. Each accepted step strictly decreases total distance (a non-negative metric over a finite
state space). Zero-improvement swaps are rejected (see above), preventing no-op cycles between symmetric bucket pairs.
Safety cap of 100 iterations as a defensive measure. In practice, 1-2 iterations for ≤ 10 buckets.

#### After allocation

Once `groupCount` per bucket is determined, partitioning is trivial: `PartitionBucket` distributes participants evenly
into the allocated number of groups. Log the final allocation at INFO level for production debugging.

---

## 4. Why Both Free+Fill and Swap Are Needed

Neither optimization technique alone covers all cases. Below are two examples demonstrating this, using realistic
parameters (`MinSize = 20`).

### 4.1. Example: Free+Fill Finds Improvement, Swap Does Not

**Setup:** `MinSize = 20`, `TargetSize = 30`, `MaxGroupCount = 10`

Three buckets after balancing:

- Bucket A (weakest): 120 participants
- Bucket B (middle): 80 participants
- Bucket C (strongest): 60 participants

**Phase 1 — Maximize:**

| Bucket    | Participants | Groups | Avg  |
|-----------|--------------|--------|------|
| A         | 120          | 6      | 20.0 |
| B         | 80           | 4      | 20.0 |
| C         | 60           | 3      | 20.0 |
| **Total** | 260          | **13** |      |

**Phase 2 — Reduce to 10:**

| Step | Action                       | Counts         | Avgs               | Distance |
|------|------------------------------|----------------|--------------------|----------|
| 0    | (start)                      | 6 + 4 + 3 = 13 | 20.0 / 20.0 / 20.0 | 30.0     |
| 1    | C 3→2 (strongest at min avg) | 6 + 4 + 2 = 12 | 20.0 / 20.0 / 30.0 | 20.0     |
| 2    | B 4→3 (strongest at min avg) | 6 + 3 + 2 = 11 | 20.0 / 26.7 / 30.0 | 13.3     |
| 3    | A 6→5 (only min avg left)    | 5 + 3 + 2 = 10 | 24.0 / 26.7 / 30.0 | **9.3**  |

**Phase 3a — Free:**

- A: avg = 24.0 < 30. Reduce 5→4: new avg = 30.0. Distance to target: 0 < 6. **Improvement!** Freed: 1 slot. Total = 9.
- B: avg = 26.7 < 30. Reduce 3→2: new avg = 40.0. Distance: 10 > 3.3. Worse, skip.

**Phase 3b — Fill:**

- No bucket has avg > 30. Freed slot stays unused.

**Result:** `4 + 3 + 2 = 9` groups. Avgs: 30.0 / 26.7 / 30.0. **Distance = 3.3** (was 9.3, **-65%**)

**Swap alone on original 5 + 3 + 2 = 10:**

Best candidate — A(5, avg 24) → B(3, avg 26.7):

- A: 4 groups, avg 30.0. Improvement: +6.0
- B: 4 groups, avg 20.0. Worsening: -6.7
- Net: **-0.7** (negative). No swap helps.

> **Free+Fill succeeds by freeing an unproductive group slot. Swap cannot do this because it is budget-neutral — it can
> only move slots between buckets, not release them.**

### 4.2. Example: Swap Finds Improvement, Free+Fill Does Not

**Setup:** `MinSize = 20`, `TargetSize = 25`, `MaxGroupCount = 5`

Three buckets after balancing:

- Bucket A (weakest): 80 participants
- Bucket B (middle): 50 participants
- Bucket C (strongest): 40 participants

**Phase 1 — Maximize:**

| Bucket    | Participants | Groups | Avg  |
|-----------|--------------|--------|------|
| A         | 80           | 4      | 20.0 |
| B         | 50           | 2      | 25.0 |
| C         | 40           | 2      | 20.0 |
| **Total** | 170          | **8**  |      |

**Phase 2 — Reduce to 5:**

| Step | Action                       | Counts        | Avgs               | Distance |
|------|------------------------------|---------------|--------------------|----------|
| 0    | (start)                      | 4 + 2 + 2 = 8 | 20.0 / 25.0 / 20.0 | 10.0     |
| 1    | C 2→1 (strongest at min avg) | 4 + 2 + 1 = 7 | 20.0 / 25.0 / 40.0 | 20.0     |
| 2    | A 4→3 (min avg)              | 3 + 2 + 1 = 6 | 26.7 / 25.0 / 40.0 | 16.7     |
| 3    | B 2→1 (min avg)              | 3 + 1 + 1 = 5 | 26.7 / 50.0 / 40.0 | **41.7** |

**Phase 3a — Free+Fill:**

- No bucket has avg < 25. Nothing to free.
- **No improvement.**

**Phase 3b — Swap:**

A(3, avg 26.7) → B(1, avg 50.0):

- A: 2 groups, avg 40.0. Worsening: `|26.7-25| - |40-25|` = 1.7 - 15 = **-13.3**
- B: 2 groups, avg 25.0. Improvement: `|50-25| - |25-25|` = 25 - 0 = **+25.0**
- Net: **+11.7**

**Result:** `2 + 2 + 1 = 5` groups. Avgs: 40.0 / 25.0 / 40.0. **Distance = 30.0** (was 41.7, **-28%**)

> **Swap succeeds by transferring a group slot from a "moderately far" bucket to a "very far" bucket, improving total
> distance even though the donor worsens. Free+Fill cannot do this because both buckets are above TargetSize — there is
> nothing to "free".**

### 4.3. Summary

| Technique     | Mechanism                                              | Blind Spot                                                           |
|---------------|--------------------------------------------------------|----------------------------------------------------------------------|
| **Free+Fill** | Releases unproductive group slots (net total decrease) | Cannot transfer between two above-target or two below-target buckets |
| **Swap**      | Transfers slots between bucket pairs (budget-neutral)  | Cannot release unused budget — total groups stays constant           |
| **Combined**  | Free+Fill → Swap, repeat until convergence             | None known for this class of problems                                |

The combined FFS approach is a form of **local search** with two move operators:

- **1-opt** (Free+Fill): unilateral change to one bucket
- **2-opt** (Swap): pairwise exchange between two buckets

Convergence is guaranteed: total distance is a non-negative metric over a finite state space that strictly decreases on
every step.

---

## 5. Edge Cases

| Scenario                                        | Behavior                                                                                                     |
|-------------------------------------------------|--------------------------------------------------------------------------------------------------------------|
| `MaxGroupCount` and `MaxSize` both set          | `MaxGroupCount` wins, `MaxSize` ignored, log warning                                                         |
| Neither set, `TargetSize` set                   | Split per `TargetSize`, no upper limit on group size                                                         |
| Neither set, `TargetSize` also null             | 1 group per bucket                                                                                           |
| `MaxGroupCount < Brackets.Count`                | Configuration validation error in `CompetetiveActivityBreaksModel`                                           |
| `MaxSize < 2 * MinSize - 1`                     | Clamped to `2 * MinSize - 1`                                                                                 |
| `TargetSize == null`, `MaxGroupCount` set       | `effectiveTargetSize = MinSize`                                                                              |
| `TargetSize == null`, `MaxSize` set             | `groupCount = ceil(total / effectiveMaxSize)`, minimize groups                                               |
| `TargetSize == null`, neither set               | 1 group per bucket (current behavior)                                                                        |
| `MaxGroupCount` > total possible groups         | Budget is underutilized; algorithm produces fewer groups than budget allows                                  |
| Lowest bucket (`MinRating=0`) has moved players | No-split rule: 1 group, excluded from FFS rebalancing                                                        |
| No-split bucket exceeds `MaxSize`               | No-split wins: bucket stays as 1 group even if it exceeds `MaxSize` (competitive fairness > organizational)  |
| Lowest bucket is empty                          | No-split rule does not apply                                                                                 |
| Bucket has 0 participants                       | 0 groups, excluded from all phases                                                                           |
| All buckets have exactly MinSize participants   | 1 group each, no splitting possible (< MinSize after balancing is not expected — tournament would not start) |
| Single non-empty bucket with `MaxGroupCount`    | Full budget goes to that bucket                                                                              |
| Zero-improvement swap cycle                     | Rejected: `improvement <= 0` is skipped. Without this guard, symmetric bucket pairs (equal participant count, mirrored group counts) would ping-pong indefinitely through the WSR tie-break, as each direction is the sole non-negative candidate in alternating iterations. The safety cap (`maxIterations = 100`) prevents a true hang, but wastes 100 × O(n²) iterations. |

---

## 6. Validation Rules (CompetetiveActivityBreaksModel)

### New validations

| Rule                  | Condition                                            | Action                               |
|-----------------------|------------------------------------------------------|--------------------------------------|
| MaxGroupCount range   | `MaxGroupCount >= Brackets.Count` (if set)           | **Reject**                           |
| TargetSize vs MaxSize | `TargetSize <= MaxSize` (if both are explicitly set) | **Reject**                           |
| MaxSize range         | `MaxSize < 2 * MinSize - 1` (if set)                 | **Clamp** + warn                     |
| Mutual exclusivity    | Both `MaxGroupCount` and `MaxSize` are set           | **Clamp** (`MaxSize` ignored) + warn |

### Existing validations to update

| Location                                             | Change                                         |
|------------------------------------------------------|------------------------------------------------|
| `CompetetiveActivityBreaksModel.CheckGroupingRule()` | **Remove** `TargetSize >= 2 * MinSize` check   |
| `MatchmakingLogic.PartitionBucket()`                 | **Remove** `if (targetedSize > maxSize) throw` |
| Both locations                                       | **Keep** `TargetSize >= MinSize` check         |

Runtime resilience: algorithm should handle invalid configs gracefully (clamp values, log warnings) rather than
crashing.

---

## 7. Implementation Plan

| #  | Step                                                                                                                                                     | Commit   | JIRA     | Status |
|----|----------------------------------------------------------------------------------------------------------------------------------------------------------|----------|----------|--------|
| 1  | Convert `CreateGroups` DataRow tests to `MatchmakingTestCase` string notation                                                                            | Separate | FP-41833 | DONE   |
| 2  | Invert remainder distribution (extras to stronger groups) + recalculate tests                                                                            | Separate | FP-41833 | DONE   |
| 3  | Rename `MakeGroups` → `BuildGroups`, `CreateGroups` → `PartitionBucket`                                                                                  | Separate | FP-41746 | DONE   |
| 4  | Add `MaxGroupCount`, `MaxSize` properties to `TournamentGroupingRule`                                                                                    | Separate | FP-41746 | DONE   |
| 5  | Implement `MaxSize` in `PartitionBucket` (signature + logic + remove old validation)                                                                     | Separate | FP-41746 | DONE   |
| 6  | Implement no-split rule in `BuildGroups`                                                                                                                 | Separate | FP-41746 | DONE   |
| 7  | Implement `MaxGroupCount` with FFS algorithm                                                                                                             | Separate | FP-41746 | DONE   |
| 8  | Add/update validation in `CompetetiveActivityBreaksModel`                                                                                                | Separate | FP-41746 | DONE   |
| 9  | Write tests for all new features (extend `MatchmakingTestCase` notation or test method design to encode `MaxGroupCount`/`MaxSize`/`TargetSize` per case) | Separate | FP-41833 | DONE   |
| 10 | Update GDD and TDD: rename `MaxGroupSize`→`MaxSize`, `"GroupCount"`→`"MaxGroupCount"`, add parameter descriptions                                        | Separate | FP-41746 | DONE   |