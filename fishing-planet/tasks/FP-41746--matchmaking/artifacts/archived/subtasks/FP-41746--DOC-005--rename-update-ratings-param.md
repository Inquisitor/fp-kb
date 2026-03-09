### DOC-005. `TournamentBucket.UpdateRatings` — misleading parameter name

- **Code:** Parameter `isSortedByRatingDescending` was always called with `true` after an **ascending**
  sort (`OrderBy`). The method logic takes `[0]` as Min and `[Count-1]` as Max, which is correct for
  ascending — but the parameter name says "descending", contradicting the actual contract.

**Decision:** Rename parameter to `isSortedByRatingAscending`. Update XML doc accordingly.

| Action                                                                               | Status |
|--------------------------------------------------------------------------------------|--------|
| **Code:** Rename parameter and update XML doc in `TournamentBucket.UpdateRatings()`. | DONE   |

**Priority:** Low (found during TRM-002 review, 2026-02-18)
