### TST-001. "Potentially false" test cases in 3-bucket/min-20 set

- **Code:** Multiple test cases in `Test_MakingBuckets_With_3_Brackets_Min_20_Participants_WorksProperly` were annotated
  "Potentially false case"
  (cases [008], [016], [022]-[026], [031]-[033], [038], [045]-[050], [051]-[053], [057]-[059], [067]). Expected values
  needed review.

**Decision:** After fixing Phase B bug (ALG-004), recalculate correct expected values for all "potentially false" cases.
Fix and enable all of them.

| Action                                                                                                                                | Status            |
|---------------------------------------------------------------------------------------------------------------------------------------|-------------------|
| **Code:** After ALG-004 fix, recalculate correct expected output for every "potentially false" case. Fix expected values, enable all. | DONE (2026-02-22) |
| **Code:** Unify all 68 test case descriptions to algorithm-trace pattern with exact player counts.                                    | DONE (2026-02-22) |

**Priority:** High (depends on ALG-004)

**Test case scenario categories (3 brackets):** All 68 test cases fall into 5 categories.
Use these when updating GDD (ALG-001, ALG-003) to describe typical balancing scenarios:

1. **No-op** — all populated buckets already >= MinSize. No player movement.
   _Examples: [001]-[015], [017], [055]_
2. **Simple pull** — one bucket pulls N players from one adjacent bucket to reach MinSize.
   _Examples: [039], [040], [054], [056], [061], [062]_
3. **Pull through two sources** — one bucket exhausts its first adjacent, then continues pulling from the next.
   _Examples: [018], [063], [064]_
4. **Two buckets pull from one donor** — first and third both pull from second (the "natural donor" in ping-pong).
   _Examples: [020], [027], [037], [066], [067]_
5. **Phase B merge** — after Phase A, a bucket with 0 < count < MinSize merges into the nearest non-empty bucket
   (stronger preferred, fallback to weaker).
   _Examples: [019], [021], [022], [041], [042], [044], and all cases combining pull + merge_
