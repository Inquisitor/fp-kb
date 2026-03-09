### TST-002. Commented-out test cases in 4-group set

- **Code:** 29 test cases are commented out in `Test_MakingTopLevelGroups_With_4_Groups_Min_20_Participants` (cases
  18-31, 39, 47, 48, 54, 61, 64, 66, 69, 77, 80, 88-93).

**Decision:** After fixing Phase B bug (ALG-004), uncomment all cases, recalculate correct expected values, fix and
enable all.

| Action                                                                                                             | Status            |
|--------------------------------------------------------------------------------------------------------------------|-------------------|
| **Code:** Uncomment all 29 cases. Recalculate correct expected output for each. Fix and enable all.                | DONE (2026-02-22) |
| **Code:** Convert 4-bracket test cases from individual int parameters to string notation `[a/b/c/d] => [x/y/z/w]`. | DONE (2026-02-22) |
| **Code:** Write algorithm-trace descriptions for all 29 fixed cases.                                               | DONE (2026-02-22) |

**Priority:** Medium (depends on ALG-004)

**Findings — 4-bracket structural pattern:**

The ping-pong visit order for 4 buckets is **B0 → B3 → B1 → B2** (outside-in). This creates
a structural asymmetry: B2 (Advanced) is always visited **last**, so all its adjacent buckets
(B1 and B3) are already visited by the time it's processed. Consequently:

- B2 can **never** pull players from anyone in Phase A.
- If B2 ends up incomplete after Phase A, it always merges **right into B3** (nearest stronger) in Phase B.
- B2 is the "natural victim" of the 4-bracket layout, analogous to B1 (Beginners) in 3-bracket layout.

**Test case scenario categories (4 brackets):** All 95 test cases fall into these categories:

1. **No-op** — all populated buckets already >= MinSize. No player movement.
   _Examples: [01]-[17]_
2. **Simple pull** — one bucket pulls from one adjacent to reach MinSize.
   _Examples: [47], [49]-[53], [55]-[58], [67], [68], [70], [75], [76], [78]_
3. **Pull through multiple sources** — one bucket exhausts its adjacent, then continues pulling from the next.
   _Examples: [39], [40], [41], [48]_
4. **Multiple buckets pull from one donor** — B3 and B1 both pull from B2 (or other shared donor).
   _Examples: [25]-[27], [29]-[30], [42], [66]/[93], [87]-[90], [92]_
5. **Phase B merge** — after Phase A, a bucket with 0 < count < MinSize merges into nearest non-empty bucket.
   _Examples: [18]-[31], [69], [77], [80], [88]-[90], [92], [94], [95]_
6. **Total consolidation** — all players consolidated into one group (total < 2×MinSize).
   _Examples: [32]-[38], [43]-[46]_
7. **Two-group consolidation** — players form exactly two complete groups (typically B0 and B3).
   _Examples: [59]-[65], [71], [79], [83]-[86], [91]_

**Note:** Case [93] is a duplicate of case [66] (identical input `[19/19/19/19]`).
