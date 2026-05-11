### RES-002. Investigate additional edge-case categories

- After RES-001, review if the combined 3-bracket + 4-bracket category list is exhaustive.
- Consider: are there scenarios only possible with 5+ brackets? Degenerate inputs (all zeros, all equal,
  exactly MinSize)? Can we derive a general category taxonomy independent of bracket count?
- **Depends on:** RES-001.

| Action                                                                                                   | Status |
|----------------------------------------------------------------------------------------------------------|--------|
| Research if more scenario categories exist beyond those found in TST-001 and RES-001. Document findings. | DEFERRED — bubbled up |

**Priority:** Low (research)

---

**Status update (2026-04-15):** Bubbled up to [matchmaking module backlog](../../../../../server/modules/matchmaking/backlog.md) on FP-41746 closure. Depends on RES-001. Currently no 5+ bracket tests exist; this work would require constructing them. Revisit alongside RES-001 after the upcoming bucket-evaluation change.
