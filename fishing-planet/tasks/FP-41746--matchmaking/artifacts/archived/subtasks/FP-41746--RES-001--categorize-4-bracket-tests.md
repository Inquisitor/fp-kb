### RES-001. Categorize 4-bracket test cases

- After TST-002 (uncomment and fix 4-bracket test cases), analyze all test cases and categorize them into
  scenario types — similar to the 5 categories identified for 3 brackets in TST-001.
- Compare: do the same 5 categories cover 4 brackets, or do new patterns emerge (e.g. multi-hop pulls across
  3+ adjacents, multiple Phase B merges)?
- **Depends on:** TST-002 (DONE).

| Action                                                                                   | Status |
|------------------------------------------------------------------------------------------|--------|
| Categorize all 4-bracket test cases. Document categories and compare with 3-bracket set. | DEFERRED — bubbled up |

**Priority:** Low (research — useful for GDD documentation)

---

**Status update (2026-04-15):** Bubbled up to [matchmaking module backlog](../../../../../server/modules/matchmaking/backlog.md) on FP-41746 closure. Initial scan over the 94 enabled 4-bracket cases (`MatchmakingLogicTests.cs` lines 250–344) shows ~9 candidate categories — base 5 from TST-001 still apply, with three new patterns specific to 4+ brackets: multi-hop pulls across non-adjacent buckets, "no unvisited adjacent source" (closed-bucket constraint), and Phase B merge direction (stronger-first vs weaker-fallback both exercised). Recommended revisit timing: after the upcoming bucket-evaluation change — if classifier logic shifts, the categorization should reflect new behavior rather than current.
